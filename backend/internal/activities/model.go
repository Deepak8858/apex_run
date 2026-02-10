package activities

import (
	"time"
)

// Activity represents a recorded GPS activity (matches DB schema).
type Activity struct {
	ID                  string     `json:"id"`
	UserID              string     `json:"user_id"`
	ActivityName        string     `json:"activity_name"`
	ActivityType        string     `json:"activity_type"`
	Description         *string    `json:"description,omitempty"`
	DistanceMeters      float64    `json:"distance_meters"`
	DurationSeconds     int        `json:"duration_seconds"`
	AvgPaceMinPerKm     *float64   `json:"avg_pace_min_per_km,omitempty"`
	MaxSpeedKmh         *float64   `json:"max_speed_kmh,omitempty"`
	ElevationGainMeters *float64   `json:"elevation_gain_meters,omitempty"`
	ElevationLossMeters *float64   `json:"elevation_loss_meters,omitempty"`
	AvgHeartRate        *int       `json:"avg_heart_rate,omitempty"`
	MaxHeartRate        *int       `json:"max_heart_rate,omitempty"`
	StartTime           time.Time  `json:"start_time"`
	EndTime             *time.Time `json:"end_time,omitempty"`
	IsPrivate           bool       `json:"is_private"`
	CreatedAt           time.Time  `json:"created_at"`
	UpdatedAt           time.Time  `json:"updated_at"`
}

// CreateActivityRequest is the request body for creating a new activity.
type CreateActivityRequest struct {
	ActivityName        string      `json:"activity_name" binding:"required"`
	ActivityType        string      `json:"activity_type" binding:"required,oneof=run walk bike hike"`
	Description         *string     `json:"description"`
	StartTime           time.Time   `json:"start_time" binding:"required"`
	EndTime             *time.Time  `json:"end_time"`
	DurationSeconds     int         `json:"duration_seconds" binding:"required,gt=0"`
	DistanceMeters      float64     `json:"distance_meters" binding:"required,gte=0"`
	AvgPaceMinPerKm     *float64    `json:"avg_pace_min_per_km"`
	MaxSpeedKmh         *float64    `json:"max_speed_kmh"`
	ElevationGainMeters *float64    `json:"elevation_gain_meters"`
	ElevationLossMeters *float64    `json:"elevation_loss_meters"`
	AvgHeartRate        *int        `json:"avg_heart_rate"`
	MaxHeartRate        *int        `json:"max_heart_rate"`
	RawGPSPoints        interface{} `json:"raw_gps_points"`
	RouteWKT            string      `json:"route_wkt"`
	IsPrivate           bool        `json:"is_private"`
}

// UpdateActivityRequest allows partial updates.
type UpdateActivityRequest struct {
	ActivityName *string `json:"activity_name"`
	Description  *string `json:"description"`
	IsPrivate    *bool   `json:"is_private"`
}

// ListActivitiesParams are query parameters for listing activities.
type ListActivitiesParams struct {
	Limit  int `form:"limit,default=20"`
	Offset int `form:"offset,default=0"`
}
