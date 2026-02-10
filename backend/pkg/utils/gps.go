package utils

import (
	"fmt"
	"math"
	"strings"
)

const earthRadiusKm = 6371.0

// GPSPoint represents a single latitude/longitude coordinate.
type GPSPoint struct {
	Lat       float64 `json:"lat"`
	Lng       float64 `json:"lng"`
	Elevation float64 `json:"elevation,omitempty"`
	Timestamp int64   `json:"timestamp,omitempty"` // unix ms
}

// HaversineDistance returns the distance in meters between two GPS points.
func HaversineDistance(a, b GPSPoint) float64 {
	dLat := degToRad(b.Lat - a.Lat)
	dLng := degToRad(b.Lng - a.Lng)
	lat1 := degToRad(a.Lat)
	lat2 := degToRad(b.Lat)

	h := math.Sin(dLat/2)*math.Sin(dLat/2) +
		math.Cos(lat1)*math.Cos(lat2)*math.Sin(dLng/2)*math.Sin(dLng/2)
	c := 2 * math.Atan2(math.Sqrt(h), math.Sqrt(1-h))
	return earthRadiusKm * c * 1000 // meters
}

// TotalDistance returns the cumulative distance in meters for a route.
func TotalDistance(route []GPSPoint) float64 {
	var total float64
	for i := 1; i < len(route); i++ {
		total += HaversineDistance(route[i-1], route[i])
	}
	return total
}

// ElevationGain sums up only positive elevation changes.
func ElevationGain(route []GPSPoint) float64 {
	var gain float64
	for i := 1; i < len(route); i++ {
		diff := route[i].Elevation - route[i-1].Elevation
		if diff > 0 {
			gain += diff
		}
	}
	return gain
}

// RouteToWKTLineString converts a slice of GPSPoints to a WKT LINESTRING(lng lat, ...).
func RouteToWKTLineString(route []GPSPoint) string {
	if len(route) < 2 {
		return ""
	}
	parts := make([]string, len(route))
	for i, p := range route {
		parts[i] = fmt.Sprintf("%f %f", p.Lng, p.Lat)
	}
	return fmt.Sprintf("SRID=4326;LINESTRING(%s)", strings.Join(parts, ", "))
}

// PointToWKT converts a single GPS point to a WKT POINT(lng lat).
func PointToWKT(p GPSPoint) string {
	return fmt.Sprintf("SRID=4326;POINT(%f %f)", p.Lng, p.Lat)
}

// BlurRoute removes points within `radiusMeters` of a center point.
// This is the "privacy shroud" that hides the user's start/end near home.
func BlurRoute(route []GPSPoint, center GPSPoint, radiusMeters float64) []GPSPoint {
	out := make([]GPSPoint, 0, len(route))
	for _, p := range route {
		if HaversineDistance(p, center) > radiusMeters {
			out = append(out, p)
		}
	}
	return out
}

// PaceMinPerKm returns pace as "mm:ss /km" from distance (m) and duration (seconds).
func PaceMinPerKm(distanceMeters, durationSeconds float64) string {
	if distanceMeters <= 0 {
		return "--:--"
	}
	secPerKm := durationSeconds / (distanceMeters / 1000.0)
	mins := int(secPerKm) / 60
	secs := int(secPerKm) % 60
	return fmt.Sprintf("%d:%02d", mins, secs)
}

// SpeedKmh returns speed in km/h.
func SpeedKmh(distanceMeters, durationSeconds float64) float64 {
	if durationSeconds <= 0 {
		return 0
	}
	return (distanceMeters / 1000.0) / (durationSeconds / 3600.0)
}

func degToRad(deg float64) float64 {
	return deg * math.Pi / 180
}
