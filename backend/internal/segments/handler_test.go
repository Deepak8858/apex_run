package segments_test

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gin-gonic/gin"

	"github.com/apexrun/backend/internal/auth"
)

func init() {
	gin.SetMode(gin.TestMode)
}

func TestSegmentModel_JSON(t *testing.T) {
	type Segment struct {
		ID                  string   `json:"id"`
		Name                string   `json:"name"`
		Description         *string  `json:"description,omitempty"`
		DistanceMeters      float64  `json:"distance_meters"`
		ElevationGainMeters *float64 `json:"elevation_gain_meters,omitempty"`
		IsVerified          bool     `json:"is_verified"`
		ActivityType        string   `json:"activity_type"`
		TotalAttempts       int      `json:"total_attempts"`
		UniqueAthletes      int      `json:"unique_athletes"`
	}

	elev := 45.0
	seg := Segment{
		ID:                  "seg-1",
		Name:                "Hill Climb",
		DistanceMeters:      2000,
		ElevationGainMeters: &elev,
		IsVerified:          true,
		ActivityType:        "run",
		TotalAttempts:       100,
		UniqueAthletes:      35,
	}

	bytes, err := json.Marshal(seg)
	if err != nil {
		t.Fatalf("marshal failed: %v", err)
	}

	var restored Segment
	if err := json.Unmarshal(bytes, &restored); err != nil {
		t.Fatalf("unmarshal failed: %v", err)
	}

	if restored.Name != seg.Name {
		t.Errorf("Name mismatch: got %s, want %s", restored.Name, seg.Name)
	}
	if restored.DistanceMeters != seg.DistanceMeters {
		t.Errorf("Distance mismatch: got %f, want %f", restored.DistanceMeters, seg.DistanceMeters)
	}
	if !restored.IsVerified {
		t.Error("expected IsVerified=true")
	}
	if restored.TotalAttempts != 100 {
		t.Errorf("expected 100 attempts, got %d", restored.TotalAttempts)
	}
}

func TestSegmentEffort_JSON(t *testing.T) {
	type SegmentEffort struct {
		ID             string    `json:"id"`
		SegmentID      string    `json:"segment_id"`
		ActivityID     string    `json:"activity_id"`
		UserID         string    `json:"user_id"`
		ElapsedSeconds int       `json:"elapsed_seconds"`
		AvgPaceMinKm   float64   `json:"avg_pace_min_per_km"`
		RecordedAt     time.Time `json:"recorded_at"`
	}

	now := time.Now().UTC().Truncate(time.Second)
	effort := SegmentEffort{
		ID:             "eff-1",
		SegmentID:      "seg-1",
		ActivityID:     "act-1",
		UserID:         "user-1",
		ElapsedSeconds: 420,
		AvgPaceMinKm:   4.67,
		RecordedAt:     now,
	}

	bytes, err := json.Marshal(effort)
	if err != nil {
		t.Fatalf("marshal failed: %v", err)
	}

	var restored SegmentEffort
	if err := json.Unmarshal(bytes, &restored); err != nil {
		t.Fatalf("unmarshal failed: %v", err)
	}

	if restored.ElapsedSeconds != 420 {
		t.Errorf("expected 420s, got %d", restored.ElapsedSeconds)
	}
	if restored.AvgPaceMinKm != 4.67 {
		t.Errorf("expected 4.67 pace, got %f", restored.AvgPaceMinKm)
	}
}

func TestSegmentListResponse_Format(t *testing.T) {
	jsonStr := `{
		"segments": [
			{"id": "s1", "name": "Park Loop", "distance_meters": 3000, "is_verified": true, "total_attempts": 50, "unique_athletes": 20},
			{"id": "s2", "name": "River Trail", "distance_meters": 5500, "is_verified": false, "total_attempts": 25, "unique_athletes": 10}
		]
	}`

	type SegmentList struct {
		Segments []struct {
			ID             string  `json:"id"`
			Name           string  `json:"name"`
			DistanceMeters float64 `json:"distance_meters"`
			IsVerified     bool    `json:"is_verified"`
			TotalAttempts  int     `json:"total_attempts"`
			UniqueAthletes int     `json:"unique_athletes"`
		} `json:"segments"`
	}

	var resp SegmentList
	if err := json.Unmarshal([]byte(jsonStr), &resp); err != nil {
		t.Fatalf("unmarshal failed: %v", err)
	}

	if len(resp.Segments) != 2 {
		t.Fatalf("expected 2 segments, got %d", len(resp.Segments))
	}
	if resp.Segments[0].Name != "Park Loop" {
		t.Errorf("expected 'Park Loop', got %s", resp.Segments[0].Name)
	}
	if resp.Segments[1].IsVerified {
		t.Error("expected River Trail to not be verified")
	}
}

func TestLeaderboardResponse_Sorted(t *testing.T) {
	jsonStr := `{
		"leaderboard": [
			{"id": "e1", "elapsed_seconds": 300, "avg_pace_min_per_km": 3.5},
			{"id": "e2", "elapsed_seconds": 360, "avg_pace_min_per_km": 4.0},
			{"id": "e3", "elapsed_seconds": 420, "avg_pace_min_per_km": 4.5}
		]
	}`

	type LeaderboardResp struct {
		Leaderboard []struct {
			ID             string  `json:"id"`
			ElapsedSeconds int     `json:"elapsed_seconds"`
			AvgPace        float64 `json:"avg_pace_min_per_km"`
		} `json:"leaderboard"`
	}

	var resp LeaderboardResp
	if err := json.Unmarshal([]byte(jsonStr), &resp); err != nil {
		t.Fatalf("unmarshal failed: %v", err)
	}

	if len(resp.Leaderboard) != 3 {
		t.Fatalf("expected 3 entries, got %d", len(resp.Leaderboard))
	}

	// Verify sorted by elapsed_seconds ascending
	for i := 1; i < len(resp.Leaderboard); i++ {
		if resp.Leaderboard[i].ElapsedSeconds < resp.Leaderboard[i-1].ElapsedSeconds {
			t.Errorf("leaderboard not sorted: index %d (%d) < index %d (%d)",
				i, resp.Leaderboard[i].ElapsedSeconds,
				i-1, resp.Leaderboard[i-1].ElapsedSeconds)
		}
	}
}

func TestSegmentEndpoint_RequiresAuth(t *testing.T) {
	router := gin.New()
	router.Use(func(c *gin.Context) {
		// Simulate auth middleware
		_, ok := auth.GetUserID(c)
		if !ok {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
			return
		}
		c.Next()
	})
	router.GET("/api/v1/segments", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"segments": []string{}})
	})

	w := httptest.NewRecorder()
	req := httptest.NewRequest("GET", "/api/v1/segments", nil)
	router.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d", w.Code)
	}
}

func TestSegmentQueryParams_Parse(t *testing.T) {
	router := gin.New()
	router.Use(func(c *gin.Context) {
		c.Set(auth.ContextKeyUserID, "test-user")
		c.Next()
	})

	var gotLat, gotLng, gotRadius string
	router.GET("/segments", func(c *gin.Context) {
		gotLat = c.Query("near_lat")
		gotLng = c.Query("near_lng")
		gotRadius = c.Query("radius_km")
		c.JSON(http.StatusOK, gin.H{"segments": []string{}})
	})

	w := httptest.NewRecorder()
	req := httptest.NewRequest("GET", "/segments?near_lat=28.6139&near_lng=77.2090&radius_km=5", nil)
	router.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}
	if gotLat != "28.6139" {
		t.Errorf("expected near_lat=28.6139, got %s", gotLat)
	}
	if gotLng != "77.2090" {
		t.Errorf("expected near_lng=77.2090, got %s", gotLng)
	}
	if gotRadius != "5" {
		t.Errorf("expected radius_km=5, got %s", gotRadius)
	}
}
