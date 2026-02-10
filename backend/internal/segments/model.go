package segments

import (
	"time"
)

// Segment represents a fixed GPS route for community competition (matches DB schema).
type Segment struct {
	ID                  string    `json:"id"`
	CreatorID           *string   `json:"creator_id,omitempty"`
	Name                string    `json:"name"`
	Description         *string   `json:"description,omitempty"`
	DistanceMeters      float64   `json:"distance_meters"`
	ElevationGainMeters *float64  `json:"elevation_gain_meters,omitempty"`
	IsVerified          bool      `json:"is_verified"`
	ActivityType        string    `json:"activity_type"`
	TotalAttempts       int       `json:"total_attempts"`
	UniqueAthletes      int       `json:"unique_athletes"`
	CreatedAt           time.Time `json:"created_at"`
}

// SegmentEffort represents a user's attempt on a segment (matches DB schema).
type SegmentEffort struct {
	ID              string    `json:"id"`
	SegmentID       string    `json:"segment_id"`
	ActivityID      string    `json:"activity_id"`
	UserID          string    `json:"user_id"`
	ElapsedSeconds  int       `json:"elapsed_seconds"`
	AvgPaceMinPerKm float64   `json:"avg_pace_min_per_km"`
	AvgHeartRate    *int      `json:"avg_heart_rate,omitempty"`
	MaxSpeedKmh     *float64  `json:"max_speed_kmh,omitempty"`
	RecordedAt      time.Time `json:"recorded_at"`
	// Computed fields (not in DB)
	Rank        *int    `json:"rank,omitempty"`
	DisplayName *string `json:"display_name,omitempty"`
}

// CreateSegmentRequest is the request body for creating a segment.
type CreateSegmentRequest struct {
	Name                string   `json:"name" binding:"required,min=3,max=100"`
	Description         *string  `json:"description"`
	DistanceMeters      float64  `json:"distance_meters" binding:"required,gt=0"`
	ElevationGainMeters *float64 `json:"elevation_gain_meters"`
	RouteWKT            string   `json:"route_wkt" binding:"required"` // EWKT LineString
}

// MatchSegmentsRequest is the request body for matching segments to an activity.
type MatchSegmentsRequest struct {
	ActivityID string `json:"activity_id" binding:"required"`
}
