package activities

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"

	"go.uber.org/zap"
)

// Repository provides data access for activities.
type Repository struct {
	db     *sql.DB
	logger *zap.Logger
}

// NewRepository creates a new activities repository.
func NewRepository(db *sql.DB, logger *zap.Logger) *Repository {
	return &Repository{db: db, logger: logger}
}

// Create inserts a new activity and returns it with populated ID and timestamps.
func (r *Repository) Create(ctx context.Context, userID string, req *CreateActivityRequest) (*Activity, error) {
	var gpsJSON interface{} // nil interface{} will be SQL NULL
	if req.RawGPSPoints != nil {
		data, err := json.Marshal(req.RawGPSPoints)
		if err != nil {
			return nil, fmt.Errorf("marshal gps data: %w", err)
		}
		gpsJSON = string(data) // pass as string for jsonb column
	}

	query := `
		INSERT INTO activities (
			user_id, activity_name, activity_type, description,
			start_time, end_time, duration_seconds, distance_meters,
			avg_pace_min_per_km, max_speed_kmh,
			elevation_gain_meters, elevation_loss_meters,
			avg_heart_rate, max_heart_rate,
			raw_gps_points, is_private
		` + routeInsertColumn(req.RouteWKT) + `
		) VALUES (
			$1, $2, $3, $4,
			$5, $6, $7, $8,
			$9, $10,
			$11, $12,
			$13, $14,
			$15, $16
		` + routeInsertValue(req.RouteWKT) + `
		)
		RETURNING id, created_at, updated_at`

	a := &Activity{
		UserID:              userID,
		ActivityName:        req.ActivityName,
		ActivityType:        req.ActivityType,
		Description:         req.Description,
		StartTime:           req.StartTime,
		EndTime:             req.EndTime,
		DurationSeconds:     req.DurationSeconds,
		DistanceMeters:      req.DistanceMeters,
		AvgPaceMinPerKm:     req.AvgPaceMinPerKm,
		MaxSpeedKmh:         req.MaxSpeedKmh,
		ElevationGainMeters: req.ElevationGainMeters,
		ElevationLossMeters: req.ElevationLossMeters,
		AvgHeartRate:        req.AvgHeartRate,
		MaxHeartRate:        req.MaxHeartRate,
		IsPrivate:           req.IsPrivate,
	}

	args := []interface{}{
		userID, req.ActivityName, req.ActivityType, req.Description,
		req.StartTime, req.EndTime, req.DurationSeconds, req.DistanceMeters,
		req.AvgPaceMinPerKm, req.MaxSpeedKmh,
		req.ElevationGainMeters, req.ElevationLossMeters,
		req.AvgHeartRate, req.MaxHeartRate,
		gpsJSON, req.IsPrivate,
	}
	if req.RouteWKT != "" {
		args = append(args, req.RouteWKT)
	}

	err := r.db.QueryRowContext(ctx, query, args...).Scan(&a.ID, &a.CreatedAt, &a.UpdatedAt)
	if err != nil {
		return nil, fmt.Errorf("insert activity: %w", err)
	}

	return a, nil
}

// activitySelectColumns is the standard column list for activity queries.
const activitySelectColumns = `id, user_id, activity_name, activity_type, description,
	start_time, end_time, duration_seconds, distance_meters,
	avg_pace_min_per_km, max_speed_kmh,
	elevation_gain_meters, elevation_loss_meters,
	avg_heart_rate, max_heart_rate,
	is_private, created_at, updated_at`

// scanActivity scans a row into an Activity struct.
func scanActivity(scanner interface{ Scan(...interface{}) error }, a *Activity) error {
	return scanner.Scan(
		&a.ID, &a.UserID, &a.ActivityName, &a.ActivityType, &a.Description,
		&a.StartTime, &a.EndTime, &a.DurationSeconds, &a.DistanceMeters,
		&a.AvgPaceMinPerKm, &a.MaxSpeedKmh,
		&a.ElevationGainMeters, &a.ElevationLossMeters,
		&a.AvgHeartRate, &a.MaxHeartRate,
		&a.IsPrivate, &a.CreatedAt, &a.UpdatedAt,
	)
}

// GetByID retrieves a single activity by its ID, scoped to the user.
func (r *Repository) GetByID(ctx context.Context, userID, activityID string) (*Activity, error) {
	query := `SELECT ` + activitySelectColumns + `
		FROM activities
		WHERE id = $1 AND user_id = $2`

	a := &Activity{}
	err := scanActivity(r.db.QueryRowContext(ctx, query, activityID, userID), a)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("get activity: %w", err)
	}
	return a, nil
}

// List returns paginated activities for a user, newest first.
func (r *Repository) List(ctx context.Context, userID string, limit, offset int) ([]Activity, error) {
	if limit <= 0 || limit > 100 {
		limit = 20
	}

	query := `SELECT ` + activitySelectColumns + `
		FROM activities
		WHERE user_id = $1
		ORDER BY start_time DESC
		LIMIT $2 OFFSET $3`

	rows, err := r.db.QueryContext(ctx, query, userID, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("list activities: %w", err)
	}
	defer rows.Close()

	var activities []Activity
	for rows.Next() {
		var a Activity
		if err := scanActivity(rows, &a); err != nil {
			return nil, fmt.Errorf("scan activity: %w", err)
		}
		activities = append(activities, a)
	}
	return activities, rows.Err()
}

// Update applies partial updates to an activity.
func (r *Repository) Update(ctx context.Context, userID, activityID string, req *UpdateActivityRequest) (*Activity, error) {
	setClauses := []string{}
	args := []interface{}{}
	argIdx := 1

	if req.ActivityName != nil {
		setClauses = append(setClauses, fmt.Sprintf("activity_name = $%d", argIdx))
		args = append(args, *req.ActivityName)
		argIdx++
	}
	if req.Description != nil {
		setClauses = append(setClauses, fmt.Sprintf("description = $%d", argIdx))
		args = append(args, *req.Description)
		argIdx++
	}
	if req.IsPrivate != nil {
		setClauses = append(setClauses, fmt.Sprintf("is_private = $%d", argIdx))
		args = append(args, *req.IsPrivate)
		argIdx++
	}

	if len(setClauses) == 0 {
		return r.GetByID(ctx, userID, activityID)
	}

	query := fmt.Sprintf(`
		UPDATE activities SET %s
		WHERE id = $%d AND user_id = $%d
		RETURNING `+activitySelectColumns,
		joinStrings(setClauses, ", "), argIdx, argIdx+1)

	args = append(args, activityID, userID)

	a := &Activity{}
	err := scanActivity(r.db.QueryRowContext(ctx, query, args...), a)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("update activity: %w", err)
	}
	return a, nil
}

// Delete removes an activity.
func (r *Repository) Delete(ctx context.Context, userID, activityID string) error {
	result, err := r.db.ExecContext(ctx,
		`DELETE FROM activities WHERE id = $1 AND user_id = $2`,
		activityID, userID,
	)
	if err != nil {
		return fmt.Errorf("delete activity: %w", err)
	}
	rows, _ := result.RowsAffected()
	if rows == 0 {
		return sql.ErrNoRows
	}
	return nil
}

// --- helpers ---

func routeInsertColumn(wkt string) string {
	if wkt != "" {
		return ", route_path"
	}
	return ""
}

func routeInsertValue(wkt string) string {
	if wkt != "" {
		return ", ST_GeomFromEWKT($17)"
	}
	return ""
}

func joinStrings(s []string, sep string) string {
	result := ""
	for i, v := range s {
		if i > 0 {
			result += sep
		}
		result += v
	}
	return result
}
