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

// New opens a PostgreSQL connection pool and verifies connectivity.
func New(dsn string, maxOpen, maxIdle int, maxLifetime time.Duration, logger *zap.Logger) (*DB, error) {
	pool, err := sql.Open("postgres", dsn)
	if err != nil {
		return nil, fmt.Errorf("database: open: %w", err)
	}

	pool.SetMaxOpenConns(maxOpen)
	pool.SetMaxIdleConns(maxIdle)
	pool.SetConnMaxLifetime(maxLifetime)

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := pool.PingContext(ctx); err != nil {
		return nil, fmt.Errorf("database: ping: %w", err)
	}

	logger.Info("database connected",
		zap.Int("max_open", maxOpen),
		zap.Int("max_idle", maxIdle),
	)

	return &DB{Pool: pool, logger: logger}, nil
}

// Close shuts down the connection pool.
func (db *DB) Close() error {
	return db.Pool.Close()
}

// HealthCheck pings the database and returns nil if healthy.
func (db *DB) HealthCheck(ctx context.Context) error {
	return db.Pool.PingContext(ctx)
}
