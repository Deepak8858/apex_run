package database

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	_ "github.com/lib/pq"
	"go.uber.org/zap"
)

// DB wraps *sql.DB with a logger.
type DB struct {
	Pool   *sql.DB
	logger *zap.Logger
}

// New opens a PostgreSQL connection pool and verifies connectivity with retry logic.
func New(dsn string, maxOpen, maxIdle int, maxLifetime time.Duration, logger *zap.Logger) (*DB, error) {
	// Log DSN host (not password) for debugging
	logger.Info("database: attempting connection",
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

	// Retry connection up to 5 times with backoff
	var pingErr error
	for attempt := 1; attempt <= 5; attempt++ {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		pingErr = pool.PingContext(ctx)
		cancel()

		if pingErr == nil {
			logger.Info("database connected",
				zap.Int("attempt", attempt),
				zap.Int("max_open", maxOpen),
				zap.Int("max_idle", maxIdle),
			)
			return &DB{Pool: pool, logger: logger}, nil
		}

		logger.Warn("database: ping failed, retrying...",
			zap.Int("attempt", attempt),
			zap.Error(pingErr),
		)

		if attempt < 5 {
			time.Sleep(time.Duration(attempt*2) * time.Second)
		}
	}

	return nil, fmt.Errorf("database: ping failed after 5 attempts: %w", pingErr)
}

// Close shuts down the connection pool.
func (db *DB) Close() error {
	return db.Pool.Close()
}

// HealthCheck pings the database and returns nil if healthy.
func (db *DB) HealthCheck(ctx context.Context) error {
	return db.Pool.PingContext(ctx)
}
