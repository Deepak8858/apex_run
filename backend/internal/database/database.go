package database

import (
	"context"
	"database/sql"
	"fmt"
	"net/url"
	"strings"
	"sync"
	"time"

	_ "github.com/lib/pq"
	"go.uber.org/zap"
)

// DB wraps *sql.DB with a logger and tracks connection state.
type DB struct {
	Pool      *sql.DB
	logger    *zap.Logger
	mu        sync.RWMutex
	connected bool
	lastError string
	connType  string // "pooler-session", "pooler-transaction", "direct", "unknown"
}

// IsConnected returns whether the database is currently connected.
func (db *DB) IsConnected() bool {
	db.mu.RLock()
	defer db.mu.RUnlock()
	return db.connected
}

// LastError returns the last connection error message (safe for diagnostics).
func (db *DB) LastError() string {
	db.mu.RLock()
	defer db.mu.RUnlock()
	return db.lastError
}

// ConnType returns the detected connection type.
func (db *DB) ConnType() string {
	db.mu.RLock()
	defer db.mu.RUnlock()
	return db.connType
}

func (db *DB) setConnected(v bool) {
	db.mu.Lock()
	defer db.mu.Unlock()
	db.connected = v
}

func (db *DB) setLastError(err string) {
	db.mu.Lock()
	defer db.mu.Unlock()
	db.lastError = err
}

// ensureSSLMode appends sslmode=require to DSN if not already present.
func ensureSSLMode(dsn string) string {
	if strings.Contains(dsn, "sslmode=") {
		return dsn
	}
	if strings.Contains(dsn, "?") {
		return dsn + "&sslmode=require"
	}
	return dsn + "?sslmode=require"
}

// detectConnType returns the connection type based on the DSN.
func detectConnType(dsn string) string {
	if strings.Contains(dsn, "pooler.supabase.com") {
		if strings.Contains(dsn, ":6543") {
			return "pooler-transaction"
		}
		return "pooler-session"
	}
	if strings.Contains(dsn, ".supabase.co") {
		return "direct"
	}
	return "unknown"
}

// maskDSN returns a safe-to-log version of the DSN.
func maskDSN(dsn string) string {
	u, err := url.Parse(dsn)
	if err != nil {
		if len(dsn) > 20 {
			return dsn[:10] + "****" + dsn[len(dsn)-6:]
		}
		return "****"
	}
	return fmt.Sprintf("%s://%s@%s%s", u.Scheme, u.User.Username(), u.Host, u.Path)
}

// New opens a PostgreSQL connection pool and verifies connectivity with retry logic.
// It ALWAYS returns a non-nil *DB so callers never need to nil-check.
// If the initial connection fails, it starts background reconnection.
// Callers can check db.IsConnected() to determine if the database is available.
func New(dsn string, maxOpen, maxIdle int, maxLifetime time.Duration, logger *zap.Logger) *DB {
	if dsn == "" {
		logger.Error("database: DATABASE_URL is empty — set it in environment variables")
		// Return a stub DB that will never connect but won't crash
		return &DB{logger: logger, connType: "none", lastError: "DATABASE_URL is empty"}
	}

	dsn = ensureSSLMode(dsn)
	connType := detectConnType(dsn)

	logger.Info("database: attempting connection",
		zap.String("dsn_masked", maskDSN(dsn)),
		zap.String("conn_type", connType),
		zap.Int("max_open", maxOpen),
		zap.Int("max_idle", maxIdle),
	)

	pool, err := sql.Open("postgres", dsn)
	if err != nil {
		logger.Error("database: failed to open pool (bad DSN format?)", zap.Error(err))
		return &DB{logger: logger, connType: connType, lastError: fmt.Sprintf("open: %v", err)}
	}

	pool.SetMaxOpenConns(maxOpen)
	pool.SetMaxIdleConns(maxIdle)
	pool.SetConnMaxLifetime(maxLifetime)

	db := &DB{Pool: pool, logger: logger, connType: connType}

	// Try initial connection with retries (up to 3 attempts with exponential backoff)
	var lastPingErr error
	for attempt := 1; attempt <= 3; attempt++ {
		ctx, cancel := context.WithTimeout(context.Background(), 8*time.Second)
		pingErr := pool.PingContext(ctx)
		cancel()

		if pingErr == nil {
			logger.Info("database connected successfully",
				zap.Int("attempt", attempt),
				zap.String("conn_type", connType),
				zap.Int("max_open", maxOpen),
				zap.Int("max_idle", maxIdle),
			)
			db.setConnected(true)
			return db
		}

		lastPingErr = pingErr
		errMsg := pingErr.Error()

		// Detect specific Supabase errors
		if strings.Contains(errMsg, "Tenant or user not found") {
			logger.Error("database: Supavisor 'Tenant or user not found' — the Supabase connection pooler does not recognize this project. "+
				"FIX: Reset the database password in Supabase Dashboard → Project Settings → Database → Reset Password. "+
				"Then update DATABASE_URL in DigitalOcean App Platform with the new pooler connection string.",
				zap.String("conn_type", connType),
			)
			db.setLastError("Supavisor: Tenant or user not found (reset DB password in Supabase Dashboard)")
			break // Don't retry, this won't resolve on its own
		}

		if strings.Contains(errMsg, "ETIMEDOUT") || strings.Contains(errMsg, "connect: network is unreachable") ||
			strings.Contains(errMsg, "no route to host") || strings.Contains(errMsg, "i/o timeout") {
			logger.Error("database: network timeout — this may be an IPv6 connectivity issue. "+
				"DigitalOcean App Platform does NOT support IPv6 outbound connections. "+
				"FIX: Use the Supavisor pooler URL (aws-0-REGION.pooler.supabase.com) instead of the direct connection URL.",
				zap.String("conn_type", connType),
				zap.Error(pingErr),
			)
			db.setLastError("Network timeout — likely IPv6 issue (use pooler URL instead of direct)")
			break // Don't retry, networking issue won't resolve
		}

		logger.Warn("database: ping failed, retrying...",
			zap.Int("attempt", attempt),
			zap.Int("max_attempts", 3),
			zap.Error(pingErr),
		)

		if attempt < 3 {
			time.Sleep(time.Duration(attempt*3) * time.Second)
		}
	}

	// All initial attempts failed — start background reconnection loop
	if lastPingErr != nil {
		db.setLastError(lastPingErr.Error())
		logger.Error("database: initial connection failed, starting background reconnection (every 30s)",
			zap.Error(lastPingErr),
			zap.String("conn_type", connType),
		)
	}
	go db.reconnectLoop()

	return db
}

// reconnectLoop tries to reconnect to the database every 30 seconds.
// It runs indefinitely until a connection succeeds.
func (db *DB) reconnectLoop() {
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	attempt := 0
	for range ticker.C {
		attempt++
		if db.Pool == nil {
			db.logger.Warn("database: reconnect skipped — no pool available (empty DATABASE_URL?)")
			return
		}

		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		err := db.Pool.PingContext(ctx)
		cancel()

		if err == nil {
			db.setConnected(true)
			db.setLastError("")
			db.logger.Info("database: reconnected successfully", zap.Int("attempt", attempt))
			return
		}

		db.setLastError(err.Error())

		// Log at different levels depending on how long we've been trying
		if attempt%10 == 0 {
			db.logger.Error("database: still unable to connect after prolonged period",
				zap.Int("attempts", attempt),
				zap.Error(err),
			)
		} else {
			db.logger.Warn("database: reconnection attempt failed",
				zap.Int("attempt", attempt),
				zap.Error(err),
			)
		}
	}
}

// Close shuts down the connection pool.
func (db *DB) Close() error {
	if db.Pool == nil {
		return nil
	}
	return db.Pool.Close()
}

// HealthCheck pings the database and returns nil if healthy.
func (db *DB) HealthCheck(ctx context.Context) error {
	if db.Pool == nil {
		return fmt.Errorf("database pool not initialized")
	}
	err := db.Pool.PingContext(ctx)
	if err == nil {
		db.setConnected(true)
		db.setLastError("")
	} else {
		db.setConnected(false)
		db.setLastError(err.Error())
	}
	return err
}

// GetPool returns the underlying sql.DB pool. May be nil if DSN was empty/invalid.
func (db *DB) GetPool() *sql.DB {
	return db.Pool
}
