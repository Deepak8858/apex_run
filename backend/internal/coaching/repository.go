package coaching

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	"go.uber.org/zap"
)

// DailyWorkoutResponse contains the daily workout recommendation data.
type DailyWorkoutResponse struct {
	HasWorkout  bool             `json:"has_workout"`
	Workout     *PlannedWorkout  `json:"workout,omitempty"`
	WeekSummary *WeekSummary     `json:"week_summary"`
}

// PlannedWorkout mirrors the database table for API responses.
type PlannedWorkout struct {
	ID                    string    `json:"id"`
	UserID                string    `json:"user_id"`
	WorkoutType           string    `json:"workout_type"`
	PlannedDate           time.Time `json:"planned_date"`
	Description           string    `json:"description"`
	TargetDistanceMeters  *float64  `json:"target_distance_meters,omitempty"`
	TargetDurationMinutes *int      `json:"target_duration_minutes,omitempty"`
	IsCompleted           bool      `json:"is_completed"`
	CoachingRationale     *string   `json:"coaching_rationale,omitempty"`
	CreatedAt             time.Time `json:"created_at"`
}

// WeekSummary provides training context for the AI coach.
type WeekSummary struct {
	RunCount       int     `json:"run_count"`
	TotalDistanceM float64 `json:"total_distance_meters"`
	TotalDurationS float64 `json:"total_duration_seconds"`
	AvgPaceSecKm   float64 `json:"avg_pace_sec_per_km"`
}

// AnalyzeRequest is the request body for the training analysis endpoint.
type AnalyzeRequest struct {
	Question string `json:"question" binding:"required,min=5"`
}

// AnalyzeResponse is the response from training analysis.
type AnalyzeResponse struct {
	Analysis    string       `json:"analysis"`
	WeekSummary *WeekSummary `json:"week_summary"`
}

// Repository provides data access for coaching features.
type Repository struct {
	db     *sql.DB
	logger *zap.Logger
}

// NewRepository creates a new coaching repository.
func NewRepository(db *sql.DB, logger *zap.Logger) *Repository {
	return &Repository{db: db, logger: logger}
}

// GetTodaysWorkout returns the user's planned workout for today (if any).
func (r *Repository) GetTodaysWorkout(ctx context.Context, userID string) (*PlannedWorkout, error) {
	today := time.Now().Format("2006-01-02")
	query := `
		SELECT id, user_id, workout_type, planned_date, description,
		       target_distance_meters, target_duration_minutes,
		       is_completed, coaching_rationale, created_at
		FROM planned_workouts
		WHERE user_id = $1 AND planned_date = $2
		ORDER BY created_at DESC
		LIMIT 1`

	w := &PlannedWorkout{}
	err := r.db.QueryRowContext(ctx, query, userID, today).Scan(
		&w.ID, &w.UserID, &w.WorkoutType, &w.PlannedDate, &w.Description,
		&w.TargetDistanceMeters, &w.TargetDurationMinutes,
		&w.IsCompleted, &w.CoachingRationale, &w.CreatedAt,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("get todays workout: %w", err)
	}
	return w, nil
}

// GetWeekSummary returns aggregated training stats for the current week.
func (r *Repository) GetWeekSummary(ctx context.Context, userID string) (*WeekSummary, error) {
	now := time.Now()
	weekday := int(now.Weekday())
	if weekday == 0 {
		weekday = 7
	}
	weekStart := now.AddDate(0, 0, -(weekday - 1))
	weekStartDate := time.Date(weekStart.Year(), weekStart.Month(), weekStart.Day(), 0, 0, 0, 0, time.UTC)

	query := `
		SELECT COUNT(*), COALESCE(SUM(distance_meters), 0),
		       COALESCE(SUM(duration_seconds), 0)
		FROM activities
		WHERE user_id = $1 AND start_time >= $2`

	ws := &WeekSummary{}
	var totalDist, totalDur float64
	err := r.db.QueryRowContext(ctx, query, userID, weekStartDate).Scan(
		&ws.RunCount, &totalDist, &totalDur,
	)
	if err != nil {
		return nil, fmt.Errorf("get week summary: %w", err)
	}

	ws.TotalDistanceM = totalDist
	ws.TotalDurationS = totalDur
	if totalDist > 0 {
		ws.AvgPaceSecKm = totalDur / (totalDist / 1000.0)
	}

	return ws, nil
}
