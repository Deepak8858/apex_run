package auth

import (
	"crypto/ecdsa"
	"crypto/elliptic"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"math/big"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"go.uber.org/zap"
)

// ContextKeyUserID is the gin context key for the authenticated user's UUID.
const ContextKeyUserID = "userID"

// Claims represents the JWT claims from a Supabase token.
type Claims struct {
	jwt.RegisteredClaims
	Email        string                 `json:"email"`
	Role         string                 `json:"role"`
	AppMetadata  map[string]interface{} `json:"app_metadata,omitempty"`
	UserMetadata map[string]interface{} `json:"user_metadata,omitempty"`
}

// jwksCache stores cached JWKS keys to avoid hitting the endpoint per request.
type jwksCache struct {
	mu          sync.RWMutex
	keys        map[string]*ecdsa.PublicKey
	fetchedAt   time.Time
	ttl         time.Duration
	refreshing  bool
	refreshCond *sync.Cond
}

func newJWKSCache(ttl time.Duration) *jwksCache {
	c := &jwksCache{
		keys: make(map[string]*ecdsa.PublicKey),
		ttl:  ttl,
	}
	c.refreshCond = sync.NewCond(&c.mu)
	return c
}

func (c *jwksCache) get(kid string, supabaseURL string, logger *zap.Logger) (*ecdsa.PublicKey, error) {
	c.mu.RLock()
	key, ok := c.keys[kid]
	fresh := time.Since(c.fetchedAt) < c.ttl
	c.mu.RUnlock()

	if ok && fresh {
		return key, nil
	}

	// Lock for refresh logic
	c.mu.Lock()
	// Check again in case someone else refreshed while we were waiting for lock
	if key, ok := c.keys[kid]; ok && time.Since(c.fetchedAt) < c.ttl {
		c.mu.Unlock()
		return key, nil
	}

	// If already refreshing, wait
	if c.refreshing {
		for c.refreshing {
			c.refreshCond.Wait()
		}
		// Try again after waiting
		key, ok := c.keys[kid]
		c.mu.Unlock()
		if !ok {
			return nil, errors.New("unknown signing key after refresh")
		}
		return key, nil
	}

	// We are the lucky one to refresh
	c.refreshing = true
	c.mu.Unlock()

	defer func() {
		c.mu.Lock()
		c.refreshing = false
		c.refreshCond.Broadcast()
		c.mu.Unlock()
	}()

	keys, err := fetchJWKS(supabaseURL)
	if err != nil {
		logger.Error("JWKS refresh failed", zap.Error(err))
		// Return existing key even if stale if it matches the kid
		c.mu.RLock()
		key, ok := c.keys[kid]
		c.mu.RUnlock()
		if ok {
			return key, nil
		}
		return nil, fmt.Errorf("unable to verify token (JWKS unavailable): %w", err)
	}

	c.mu.Lock()
	c.keys = keys
	c.fetchedAt = time.Now()
	key, ok = c.keys[kid]
	c.mu.Unlock()

	if !ok {
		return nil, errors.New("unknown signing key after refresh")
	}
	return key, nil
}

// jwksResponse represents the JSON Web Key Set response.
type jwksResponse struct {
	Keys []jwkKey `json:"keys"`
}

type jwkKey struct {
	Kty string `json:"kty"`
	Crv string `json:"crv"`
	X   string `json:"x"`
	Y   string `json:"y"`
	Kid string `json:"kid"`
	Alg string `json:"alg"`
}

// fetchJWKS retrieves the JWKS from the Supabase auth endpoint.
func fetchJWKS(supabaseURL string) (map[string]*ecdsa.PublicKey, error) {
	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Get(supabaseURL + "/auth/v1/.well-known/jwks.json")
	if err != nil {
		return nil, fmt.Errorf("fetch JWKS: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("fetch JWKS: status %d", resp.StatusCode)
	}

	var jwks jwksResponse
	if err := json.NewDecoder(resp.Body).Decode(&jwks); err != nil {
		return nil, fmt.Errorf("decode JWKS: %w", err)
	}

	keys := make(map[string]*ecdsa.PublicKey)
	for _, k := range jwks.Keys {
		if k.Kty != "EC" || k.Crv != "P-256" {
			continue
		}
		xBytes, err := base64.RawURLEncoding.DecodeString(k.X)
		if err != nil {
			continue
		}
		yBytes, err := base64.RawURLEncoding.DecodeString(k.Y)
		if err != nil {
			continue
		}
		keys[k.Kid] = &ecdsa.PublicKey{
			Curve: elliptic.P256(),
			X:     new(big.Int).SetBytes(xBytes),
			Y:     new(big.Int).SetBytes(yBytes),
		}
	}

	if len(keys) == 0 {
		return nil, errors.New("no valid EC P-256 keys found in JWKS")
	}
	return keys, nil
}

// Middleware returns a Gin middleware that validates Supabase JWT tokens.
// It supports both ES256 (via JWKS) and HS256 (via JWT secret) verification.
// It injects the user ID into the gin context under ContextKeyUserID.
func Middleware(supabaseURL, jwtSecret string, logger *zap.Logger) gin.HandlerFunc {
	hmacSecret := []byte(jwtSecret)
	cache := newJWKSCache(5 * time.Minute)

	// Pre-fetch JWKS at startup
	if keys, err := fetchJWKS(supabaseURL); err != nil {
		logger.Warn("initial JWKS fetch failed — will retry on first request", zap.Error(err))
	} else {
		cache.mu.Lock()
		cache.keys = keys
		cache.fetchedAt = time.Now()
		cache.mu.Unlock()
		logger.Info("JWKS loaded", zap.Int("keys", len(keys)))
	}

	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"error": "missing authorization header",
			})
			return
		}

		tokenString := strings.TrimPrefix(authHeader, "Bearer ")
		if tokenString == authHeader {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"error": "invalid authorization format, expected 'Bearer <token>'",
			})
			return
		}

		// Parse without verification first to inspect header
		parser := jwt.NewParser()
		unverified, _, err := parser.ParseUnverified(tokenString, &Claims{})
		if err != nil {
			logger.Debug("jwt parse failed", zap.Error(err))
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"error": "malformed token",
			})
			return
		}

		var claims *Claims
		var token *jwt.Token

		switch unverified.Method.Alg() {
		case "ES256":
			kid, _ := unverified.Header["kid"].(string)
			pubKey, err := cache.get(kid, supabaseURL, logger)
			if err != nil {
				c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
					"error": err.Error(),
				})
				return
			}

			claims = &Claims{}
			token, err = jwt.ParseWithClaims(tokenString, claims, func(t *jwt.Token) (interface{}, error) {
				if _, ok := t.Method.(*jwt.SigningMethodECDSA); !ok {
					return nil, fmt.Errorf("unexpected signing method: %v", t.Header["alg"])
				}
				return pubKey, nil
			})

		case "HS256":
			claims = &Claims{}
			token, err = jwt.ParseWithClaims(tokenString, claims, func(t *jwt.Token) (interface{}, error) {
				if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
					return nil, fmt.Errorf("unexpected signing method: %v", t.Header["alg"])
				}
				return hmacSecret, nil
			})

		default:
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"error": fmt.Sprintf("unsupported signing algorithm: %s", unverified.Method.Alg()),
			})
			return
		}

		if err != nil || !token.Valid {
			logger.Debug("jwt validation failed", zap.Error(err))
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"error": "invalid or expired token",
			})
			return
		}

		userID := claims.Subject
		if userID == "" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"error": "token missing subject (user id)",
			})
			return
		}

		c.Set(ContextKeyUserID, userID)
		c.Next()
	}
}

// GetUserID extracts the authenticated user ID from the gin context.
func GetUserID(c *gin.Context) (string, bool) {
	id, exists := c.Get(ContextKeyUserID)
	if !exists {
		return "", false
	}
	return id.(string), true
}
