package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"

	"github.com/apexrun/backend/internal/activities"
	"github.com/apexrun/backend/internal/auth"
	"github.com/apexrun/backend/internal/coaching"
	"github.com/apexrun/backend/internal/config"
	"github.com/apexrun/backend/internal/database"
	"github.com/apexrun/backend/internal/segments"
	"github.com/apexrun/backend/pkg/logger"
)

const version = "1.0.0"

func main() {
	// ----------------------------------------------------------------
	// 1. Load configuration
	// ----------------------------------------------------------------
	cfg, err := config.Load()
	if err != nil {
		fmt.Fprintf(os.Stderr, "config: %v\n", err)
		os.Exit(1)
	}

	// ----------------------------------------------------------------
	// 2. Initialize structured logger
	// ----------------------------------------------------------------
	log, err := logger.New(cfg.LogFormat, cfg.LogLevel)
	if err != nil {
		fmt.Fprintf(os.Stderr, "logger: %v\n", err)
		os.Exit(1)
	}
	defer log.Sync()

	log.Info("starting ApexRun API",
		zap.String("version", version),
		zap.String("port", cfg.Port),
		zap.String("gin_mode", cfg.GinMode),
	)

	// ----------------------------------------------------------------
	// 3. Connect to PostgreSQL (non-fatal: allows container to stay alive)
	// ----------------------------------------------------------------
	log.Info("connecting to database...",
		zap.Int("db_url_len", len(cfg.DatabaseURL)),
		zap.Bool("db_url_empty", cfg.DatabaseURL == ""),
	)
	db := database.New(
		cfg.DatabaseURL,
		cfg.DBMaxOpenConns,
		cfg.DBMaxIdleConns,
		cfg.DBConnMaxLifetime,
		log,
	)
	defer db.Close()

	// ----------------------------------------------------------------
	// 4. Connect to Redis (graceful degradation if unavailable)
	// ----------------------------------------------------------------
	rds, err := database.NewRedis(
		cfg.RedisURL,
		cfg.RedisPassword,
		cfg.RedisDB,
		cfg.RedisPoolSize,
		log,
	)
	if err != nil {
		log.Warn("redis init error — continuing without cache", zap.Error(err))
	}
	if rds != nil {
		defer rds.Close()
	}

	// ----------------------------------------------------------------
	// 5. Build repositories (pool may be nil if DATABASE_URL is empty/invalid)
	// ----------------------------------------------------------------
	dbPool := db.GetPool()
	if dbPool == nil {
		log.Error("database pool is nil — API endpoints requiring DB will return errors. " +
			"Set a valid DATABASE_URL environment variable.")
	}
	activityRepo := activities.NewRepository(dbPool, log)
	segmentRepo := segments.NewRepository(dbPool, log)
	coachingRepo := coaching.NewRepository(dbPool, log)

	// ----------------------------------------------------------------
	// 6. Build handlers
	// ----------------------------------------------------------------
	activityHandler := activities.NewHandler(activityRepo, log)
	segmentHandler := segments.NewHandler(segmentRepo, rds, cfg.SegmentMatchBufferMeters, log)
	coachingHandler := coaching.NewHandler(coachingRepo, log)

	// ----------------------------------------------------------------
	// 7. Setup Gin router
	// ----------------------------------------------------------------
	gin.SetMode(cfg.GinMode)
	router := gin.New()

	// Global middleware
	router.Use(gin.Recovery())
	router.Use(requestLogger(log))
	router.Use(corsMiddleware(cfg.AllowedOrigins))
	router.Use(rateLimiter(cfg.RateLimitRPM))

	// Health check (no auth required)
	router.GET("/health", healthHandler(db, rds))

	// Protected API routes
	api := router.Group("/api/v1")
	api.Use(auth.Middleware(cfg.SupabaseURL, cfg.SupabaseJWTSecret, log))
	{
		activityHandler.RegisterRoutes(api.Group("/activities"))
		segmentHandler.RegisterRoutes(api.Group("/segments"))
		coachingHandler.RegisterRoutes(api.Group("/coaching"))
	}

	// ----------------------------------------------------------------
	// 8. Start HTTP server with graceful shutdown
	// ----------------------------------------------------------------
	srv := &http.Server{
		Addr:         ":" + cfg.Port,
		Handler:      router,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 30 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// Start server in goroutine
	go func() {
		log.Info("server listening", zap.String("addr", srv.Addr))
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatal("server error", zap.Error(err))
		}
	}()

	// Wait for interrupt signal
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Info("shutting down server...")
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := srv.Shutdown(ctx); err != nil {
		log.Fatal("server forced shutdown", zap.Error(err))
	}
	log.Info("server stopped")
}

// ================================================================
// Middleware
// ================================================================

// requestLogger logs each request with Zap.
func requestLogger(log *zap.Logger) gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		path := c.Request.URL.Path

		c.Next()

		log.Info("request",
			zap.String("method", c.Request.Method),
			zap.String("path", path),
			zap.Int("status", c.Writer.Status()),
			zap.Duration("latency", time.Since(start)),
			zap.String("client_ip", c.ClientIP()),
		)
	}
}

// corsMiddleware handles CORS headers.
func corsMiddleware(allowedOrigins []string) gin.HandlerFunc {
	return func(c *gin.Context) {
		origin := c.Request.Header.Get("Origin")
		allowed := false
		for _, pattern := range allowedOrigins {
			if matchOrigin(origin, strings.TrimSpace(pattern)) {
				allowed = true
				break
			}
		}

		if allowed {
			c.Header("Access-Control-Allow-Origin", origin)
		}
		c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Authorization, Content-Type, Accept")
		c.Header("Access-Control-Max-Age", "86400")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}
		c.Next()
	}
}

// matchOrigin checks if an origin matches a pattern (supports trailing wildcard *).
func matchOrigin(origin, pattern string) bool {
	if pattern == "*" {
		return true
	}
	if strings.HasSuffix(pattern, "*") {
		prefix := strings.TrimSuffix(pattern, "*")
		return strings.HasPrefix(origin, prefix)
	}
	return origin == pattern
}

// rateLimiter is a simple per-IP token-bucket rate limiter.
// For production, use a distributed limiter backed by Redis.
type ipBucket struct {
	tokens    int
	lastReset time.Time
}

var (
	ipBuckets  = make(map[string]*ipBucket)
	bucketsMu  sync.Mutex
)

func rateLimiter(rpm int) gin.HandlerFunc {
	return func(c *gin.Context) {
		ip := c.ClientIP()
		now := time.Now()

		bucketsMu.Lock()
		bucket, exists := ipBuckets[ip]
		if !exists || now.Sub(bucket.lastReset) > time.Minute {
			ipBuckets[ip] = &ipBucket{tokens: rpm, lastReset: now}
			bucket = ipBuckets[ip]
		}

		if bucket.tokens <= 0 {
			bucketsMu.Unlock()
			c.Header("Retry-After", "60")
			c.AbortWithStatusJSON(http.StatusTooManyRequests, gin.H{
				"error": "rate limit exceeded",
			})
			return
		}

		bucket.tokens--
		bucketsMu.Unlock()
		c.Next()
	}
}

// ================================================================
// Health check handler
// ================================================================

func healthHandler(db *database.DB, rds *database.Redis) gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(c.Request.Context(), 3*time.Second)
		defer cancel()

		dbStatus := "not_configured"
		dbConnType := "none"
		dbLastError := ""
		if db != nil {
			dbConnType = db.ConnType()
			if db.GetPool() != nil {
				dbStatus = "connected"
				if err := db.HealthCheck(ctx); err != nil {
					dbStatus = "error"
					dbLastError = err.Error()
				}
			} else {
				dbStatus = "no_pool"
				dbLastError = db.LastError()
			}
		}

		redisStatus := "disabled"
		if rds != nil {
			if err := rds.HealthCheck(ctx); err != nil {
				redisStatus = "error"
			} else {
				redisStatus = "connected"
			}
		}

		// Always return 200 so the container stays alive.
		// The "status" field indicates true health for monitoring.
		overallStatus := "ok"
		if dbStatus != "connected" {
			overallStatus = "degraded"
		}

		response := gin.H{
			"status":       overallStatus,
			"version":      version,
			"database":     dbStatus,
			"db_conn_type": dbConnType,
			"redis":        redisStatus,
		}
		if dbLastError != "" {
			response["db_error"] = dbLastError
		}

		c.JSON(http.StatusOK, response)
	}
}
