package config

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/joho/godotenv"
)

// Config holds all application configuration
type Config struct {
	// Server
	Port           string
	GinMode        string
	AllowedOrigins []string
	RateLimitRPM   int

	// Supabase
	SupabaseURL       string
	SupabaseAnonKey   string
	SupabaseServiceKey string
	SupabaseJWTSecret string

	// Database
	DatabaseURL            string
	DBMaxOpenConns         int
	DBMaxIdleConns         int
	DBConnMaxLifetime      time.Duration

	// Redis
	RedisURL      string
	RedisPassword string
	RedisDB       int
	RedisPoolSize int

	// GPS / Segments
	SegmentMatchBufferMeters int
	MaxGPSPointsPerActivity  int

	// Logging
	LogLevel  string
	LogFormat string

	// Development
	EnableMockData     bool
	EnableDebugLogging bool
}

// Load reads environment variables and returns a populated Config.
// It attempts to load a .env file but does not fail if one is missing.
func Load() (*Config, error) {
	// Best-effort load of .env
	_ = godotenv.Load()

	cfg := &Config{
		// Server
		Port:           getEnv("PORT", "8080"),
		GinMode:        getEnv("GIN_MODE", "debug"),
		AllowedOrigins: strings.Split(getEnv("ALLOWED_ORIGINS", "http://localhost:*"), ","),
		RateLimitRPM:   getEnvInt("RATE_LIMIT_REQUESTS_PER_MINUTE", 60),

		// Supabase
		SupabaseURL:       mustGetEnv("SUPABASE_URL"),
		SupabaseAnonKey:   mustGetEnv("SUPABASE_ANON_KEY"),
		SupabaseServiceKey: getEnv("SUPABASE_SERVICE_KEY", ""),
		SupabaseJWTSecret: mustGetEnv("SUPABASE_JWT_SECRET"),

		// Database
		DatabaseURL:       mustGetEnv("DATABASE_URL"),
		DBMaxOpenConns:    getEnvInt("DB_MAX_OPEN_CONNS", 25),
		DBMaxIdleConns:    getEnvInt("DB_MAX_IDLE_CONNS", 10),
		DBConnMaxLifetime: time.Duration(getEnvInt("DB_CONN_MAX_LIFETIME_MINUTES", 30)) * time.Minute,

		// Redis
		RedisURL:      getEnv("REDIS_URL", "localhost:6379"),
		RedisPassword: getEnv("REDIS_PASSWORD", ""),
		RedisDB:       getEnvInt("REDIS_DB", 0),
		RedisPoolSize: getEnvInt("REDIS_POOL_SIZE", 10),

		// GPS
		SegmentMatchBufferMeters: getEnvInt("SEGMENT_MATCH_BUFFER_METERS", 20),
		MaxGPSPointsPerActivity:  getEnvInt("MAX_GPS_POINTS_PER_ACTIVITY", 10000),

		// Logging
		LogLevel:  getEnv("LOG_LEVEL", "info"),
		LogFormat: getEnv("LOG_FORMAT", "json"),

		// Development
		EnableMockData:     getEnvBool("ENABLE_MOCK_DATA", false),
		EnableDebugLogging: getEnvBool("ENABLE_DEBUG_LOGGING", true),
	}

	return cfg, nil
}

// --- helpers ---

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func mustGetEnv(key string) string {
	v := os.Getenv(key)
	if v == "" {
		// Log clearly which required variable is missing
		fmt.Printf("CRITICAL: required env var %s is not set — set it in .env or environment\n", key)
		return ""
	}
	// Log that we found the env var (mask sensitive values)
	masked := v
	if len(v) > 8 {
		masked = v[:4] + "****" + v[len(v)-4:]
	}
	fmt.Printf("CONFIG: %s = %s (len=%d)\n", key, masked, len(v))
	return v
}

func getEnvInt(key string, fallback int) int {
	v := os.Getenv(key)
	if v == "" {
		return fallback
	}
	i, err := strconv.Atoi(v)
	if err != nil {
		return fallback
	}
	return i
}

func getEnvBool(key string, fallback bool) bool {
	v := os.Getenv(key)
	if v == "" {
		return fallback
	}
	b, err := strconv.ParseBool(v)
	if err != nil {
		return fallback
	}
	return b
}
