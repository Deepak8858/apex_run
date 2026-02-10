package database

import (
	"context"
	"fmt"
	"time"

	"github.com/go-redis/redis/v8"
	"go.uber.org/zap"
)

// Redis wraps the go-redis client.
type Redis struct {
	Client *redis.Client
	logger *zap.Logger
}

// NewRedis opens a Redis connection and verifies connectivity.
func NewRedis(addr, password string, db, poolSize int, logger *zap.Logger) (*Redis, error) {
	client := redis.NewClient(&redis.Options{
		Addr:     addr,
		Password: password,
		DB:       db,
		PoolSize: poolSize,
	})

	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	if err := client.Ping(ctx).Err(); err != nil {
		logger.Warn("redis not available — leaderboard caching disabled", zap.Error(err))
		// We return the client anyway; callers should degrade gracefully.
		return &Redis{Client: client, logger: logger}, nil
	}

	logger.Info("redis connected", zap.String("addr", addr))
	return &Redis{Client: client, logger: logger}, nil
}

// Close shuts down the Redis client.
func (r *Redis) Close() error {
	return r.Client.Close()
}

// HealthCheck pings Redis and returns nil if healthy.
func (r *Redis) HealthCheck(ctx context.Context) error {
	return r.Client.Ping(ctx).Err()
}

// --- Leaderboard helpers (Redis Sorted Sets) ---

// LeaderboardKey returns the Redis key for a segment leaderboard.
func LeaderboardKey(segmentID string) string {
	return fmt.Sprintf("leaderboard:%s", segmentID)
}

// SetLeaderboardEntry adds or updates a user's best time on a segment.
// Score = elapsed_time_seconds (lower is better).
func (r *Redis) SetLeaderboardEntry(ctx context.Context, segmentID, userID string, elapsedSeconds float64) error {
	return r.Client.ZAdd(ctx, LeaderboardKey(segmentID), &redis.Z{
		Score:  elapsedSeconds,
		Member: userID,
	}).Err()
}

// GetLeaderboard returns the top N entries for a segment (fastest first).
func (r *Redis) GetLeaderboard(ctx context.Context, segmentID string, limit int64) ([]redis.Z, error) {
	return r.Client.ZRangeWithScores(ctx, LeaderboardKey(segmentID), 0, limit-1).Result()
}

// InvalidateLeaderboard removes the cached leaderboard for a segment.
func (r *Redis) InvalidateLeaderboard(ctx context.Context, segmentID string) error {
	return r.Client.Del(ctx, LeaderboardKey(segmentID)).Err()
}
