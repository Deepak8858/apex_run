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
}

// IsConnected returns whether the database is currently connected.
func (db *DB) IsConnected() bool {
	db.mu.RLock()
	defer db.mu.RUnlock()
	return db.connected
}

func (db *DB) setConnected(v bool) {
	db.mu.Lock()
	defer db.mu.Unlock()
	db.connected = v
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
// It no longer returns an error for failed connections — instead it starts background
// reconnection and returns a DB handle that callers can check with IsConnected().
func New(dsn string, maxOpen, maxIdle int, maxLifetime time.Duration, logger *zap.Logger) (*DB, error) {
	dsn = ensureSSLMode(dsn)

	logger.Info("database: attempting connection",
		zap.String("dsn_masked", maskDSN(dsn)),
		zap.Int("max_open", maxOpen),
		zap.Int("max_idle", maxIdle),
	)

	pool, err := sql.Open("postgres", dsn)
	if err != nil {
		return nil, fmt.Errorf("database: open: %w", err)
	}

	pool.SetMaxOpenConns(maxOpen)
	pool.SetMaxIdleConns(maxIdle)
	pool.SetConnMaxLifetime(maxLifetime)

	db := &DB{Pool: pool, logger: logger}

	// Try initial connection with retries (up to 5 attempts)
	for attempt := 1; attempt <= 5; attempt++ {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		pingErr := pool.PingContext(ctx)
		cancel()

		if pingErr == nil {
			logger.Info("database connected",
				zap.Int("attempt", attempt),
				zap.Int("max_open", maxOpen),
				zap.Int("max_idle", maxIdle),
			)
			db.setConnected(true)
			return db, nil
		}

		logger.Warn("database: ping failed, retrying...",
			zap.Int("attempt", attempt),
			zap.Error(pingErr),
		)

		if attempt < 5 {
			time.Sleep(time.Duration(attempt*2) * time.Second)
		}
	}

	// All initial attempts failed — start background reconnection loop
	logger.Error("database: initial connection failed after 5 attempts, starting background reconnection")
	go db.reconnectLoop()

	return db, nil
}

// reconnectLoop tries to reconnect to the database every 15 seconds.
func (db *DB) reconnectLoop() {
	ticker := time.NewTicker(15 * time.Second)
	defer ticker.Stop()

	for range ticker.C {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		err := db.Pool.PingContext(ctx)
		cancel()

		if err == nil {
			db.setConnected(true)
			db.logger.Info("database: reconnected successfully")
			return
		}
		db.logger.Warn("database: reconnection attempt failed", zap.Error(err))
	}
}

// Close shuts down the connection pool.
func (db *DB) Close() error {
	return db.Pool.Close()
}

// HealthCheck pings the database and returns nil if healthy.
func (db *DB) HealthCheck(ctx context.Context) error {
	err := db.Pool.PingContext(ctx)
	if err == nil {
		db.setConnected(true)
	} else {
		db.setConnected(false)
	}
	return err
}
