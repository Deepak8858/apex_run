package segments

import (
	"context"
	"database/sql"
	"fmt"

	"go.uber.org/zap"
)

// Repository provides data access for segments and segment efforts.
type Repository struct {
	db     *sql.DB
	logger *zap.Logger
}

// NewRepository creates a new segments repository.
func NewRepository(db *sql.DB, logger *zap.Logger) *Repository {
	return &Repository{db: db, logger: logger}
}

// ListSegments returns all segments, optionally filtered by proximity.
func (r *Repository) ListSegments(ctx context.Context, nearLat, nearLng, radiusKm *float64) ([]Segment, error) {
	var query string
	var args []interface{}

	if nearLat != nil && nearLng != nil && radiusKm != nil {
		// Spatial proximity query using PostGIS
		query = `
			SELECT id, creator_id, name, description, distance_meters,
			       elevation_gain_meters, is_verified, activity_type,
			       total_attempts, unique_athletes, created_at
			FROM segments
			WHERE ST_DWithin(
				segment_path::geography,
				ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography,
				$3
			)
			ORDER BY distance_meters ASC
			LIMIT 100`
		args = []interface{}{*nearLng, *nearLat, *radiusKm * 1000}
	} else {
		query = `
			SELECT id, creator_id, name, description, distance_meters,
			       elevation_gain_meters, is_verified, activity_type,
			       total_attempts, unique_athletes, created_at
			FROM segments
			ORDER BY total_attempts DESC
			LIMIT 100`
	}

	rows, err := r.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("list segments: %w", err)
	}
	defer rows.Close()

	var segments []Segment
	for rows.Next() {
		var s Segment
		if err := rows.Scan(
			&s.ID, &s.CreatorID, &s.Name, &s.Description, &s.DistanceMeters,
			&s.ElevationGainMeters, &s.IsVerified, &s.ActivityType,
			&s.TotalAttempts, &s.UniqueAthletes, &s.CreatedAt,
		); err != nil {
			return nil, fmt.Errorf("scan segment: %w", err)
		}
		segments = append(segments, s)
	}
	return segments, rows.Err()
}

// GetByID returns a single segment.
func (r *Repository) GetByID(ctx context.Context, segmentID string) (*Segment, error) {
	query := `
		SELECT id, creator_id, name, description, distance_meters,
		       elevation_gain_meters, is_verified, activity_type,
		       total_attempts, unique_athletes, created_at
		FROM segments
		WHERE id = $1`

	s := &Segment{}
	err := r.db.QueryRowContext(ctx, query, segmentID).Scan(
		&s.ID, &s.CreatorID, &s.Name, &s.Description, &s.DistanceMeters,
		&s.ElevationGainMeters, &s.IsVerified, &s.ActivityType,
		&s.TotalAttempts, &s.UniqueAthletes, &s.CreatedAt,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("get segment: %w", err)
	}
	return s, nil
}

// Create inserts a new segment with its PostGIS path.
func (r *Repository) Create(ctx context.Context, userID string, req *CreateSegmentRequest) (*Segment, error) {
	query := `
		INSERT INTO segments (
			creator_id, name, description, distance_meters,
			elevation_gain_meters, segment_path
		) VALUES ($1, $2, $3, $4, $5, ST_GeomFromEWKT($6))
		RETURNING id, created_at`

	s := &Segment{
		CreatorID:           &userID,
		Name:                req.Name,
		Description:         req.Description,
		DistanceMeters:      req.DistanceMeters,
		ElevationGainMeters: req.ElevationGainMeters,
	}

	err := r.db.QueryRowContext(ctx, query,
		userID, req.Name, req.Description, req.DistanceMeters,
		req.ElevationGainMeters, req.RouteWKT,
	).Scan(&s.ID, &s.CreatedAt)
	if err != nil {
		return nil, fmt.Errorf("create segment: %w", err)
	}
	return s, nil
}

// GetLeaderboard returns segment efforts ordered fastest first, with display names.
func (r *Repository) GetLeaderboard(ctx context.Context, segmentID string, limit int) ([]SegmentEffort, error) {
	if limit <= 0 || limit > 200 {
		limit = 50
	}

	query := `
		SELECT se.id, se.segment_id, se.activity_id, se.user_id,
		       se.elapsed_seconds, se.avg_pace_min_per_km,
		       se.avg_heart_rate, se.max_speed_kmh, se.recorded_at,
		       up.display_name
		FROM segment_efforts se
		LEFT JOIN user_profiles up ON up.id = se.user_id
		WHERE se.segment_id = $1
		ORDER BY se.elapsed_seconds ASC
		LIMIT $2`

	rows, err := r.db.QueryContext(ctx, query, segmentID, limit)
	if err != nil {
		return nil, fmt.Errorf("get leaderboard: %w", err)
	}
	defer rows.Close()

	var efforts []SegmentEffort
	rank := 1
	for rows.Next() {
		var e SegmentEffort
		if err := rows.Scan(
			&e.ID, &e.SegmentID, &e.ActivityID, &e.UserID,
			&e.ElapsedSeconds, &e.AvgPaceMinPerKm,
			&e.AvgHeartRate, &e.MaxSpeedKmh, &e.RecordedAt,
			&e.DisplayName,
		); err != nil {
			return nil, fmt.Errorf("scan effort: %w", err)
		}
		e.Rank = &rank
		efforts = append(efforts, e)
		rank++
	}
	return efforts, rows.Err()
}

// MatchActivityToSegments uses PostGIS to find segments traversed by an activity.
func (r *Repository) MatchActivityToSegments(ctx context.Context, activityID string, bufferMeters int) ([]string, error) {
	query := `
		SELECT s.id
		FROM segments s
		JOIN activities a ON a.id = $1
		WHERE a.route_path IS NOT NULL
		  AND s.segment_path IS NOT NULL
		  AND ST_Contains(
		      ST_Buffer(a.route_path::geography, $2)::geometry,
		      s.segment_path
		  )`

	rows, err := r.db.QueryContext(ctx, query, activityID, bufferMeters)
	if err != nil {
		return nil, fmt.Errorf("match segments: %w", err)
	}
	defer rows.Close()

	var ids []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, fmt.Errorf("scan match: %w", err)
		}
		ids = append(ids, id)
	}
	return ids, rows.Err()
}

// CreateEffort inserts a segment effort record.
func (r *Repository) CreateEffort(ctx context.Context, e *SegmentEffort) (*SegmentEffort, error) {
	query := `
		INSERT INTO segment_efforts (
			segment_id, activity_id, user_id, elapsed_seconds,
			avg_pace_min_per_km, avg_heart_rate, max_speed_kmh,
			recorded_at
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
		RETURNING id`

	err := r.db.QueryRowContext(ctx, query,
		e.SegmentID, e.ActivityID, e.UserID, e.ElapsedSeconds,
		e.AvgPaceMinPerKm, e.AvgHeartRate, e.MaxSpeedKmh,
		e.RecordedAt,
	).Scan(&e.ID)
	if err != nil {
		return nil, fmt.Errorf("create effort: %w", err)
	}

	// Update segment counters
	_, _ = r.db.ExecContext(ctx, `
		UPDATE segments
		SET total_attempts = total_attempts + 1,
		    unique_athletes = (
		        SELECT COUNT(DISTINCT user_id)
		        FROM segment_efforts
		        WHERE segment_id = $1
		    )
		WHERE id = $1`, e.SegmentID)

	return e, nil
}
