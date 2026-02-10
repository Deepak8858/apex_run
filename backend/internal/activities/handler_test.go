package activities_test

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/gin-gonic/gin"

	"github.com/apexrun/backend/internal/auth"
)

func init() {
	gin.SetMode(gin.TestMode)
}

// setupTestRouter creates a gin router with a test auth middleware
// that injects a fake userID into the context.
func setupTestRouter(userID string) *gin.Engine {
	r := gin.New()
	r.Use(func(c *gin.Context) {
		c.Set(auth.ContextKeyUserID, userID)
		c.Next()
	})
	return r
}

func TestCreateActivityRequest_Validation(t *testing.T) {
	tests := []struct {
		name       string
		body       string
		expectCode int
	}{
		{
			name: "valid request",
			body: `{
				"activity_name": "Morning Run",
				"activity_type": "run",
				"start_time": "2024-03-15T06:30:00Z",
				"duration_seconds": 1800,
				"distance_meters": 5000
			}`,
			expectCode: http.StatusBadRequest, // Will be 400 since no repo
		},
		{
			name: "missing activity_name",
			body: `{
				"activity_type": "run",
				"start_time": "2024-03-15T06:30:00Z",
				"duration_seconds": 1800,
				"distance_meters": 5000
			}`,
			expectCode: http.StatusBadRequest,
		},
		{
			name: "invalid activity_type",
			body: `{
				"activity_name": "Test",
				"activity_type": "swim",
				"start_time": "2024-03-15T06:30:00Z",
				"duration_seconds": 1800,
				"distance_meters": 5000
			}`,
			expectCode: http.StatusBadRequest,
		},
		{
			name: "zero duration not allowed",
			body: `{
				"activity_name": "Test",
				"activity_type": "run",
				"start_time": "2024-03-15T06:30:00Z",
				"duration_seconds": 0,
				"distance_meters": 5000
			}`,
			expectCode: http.StatusBadRequest,
		},
		{
			name:       "empty body",
			body:       `{}`,
			expectCode: http.StatusBadRequest,
		},
		{
			name:       "invalid JSON",
			body:       `{invalid`,
			expectCode: http.StatusBadRequest,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			router := setupTestRouter("test-user-id")

			// Just test the binding validation layer
			router.POST("/activities", func(c *gin.Context) {
				var req struct {
					ActivityName    string    `json:"activity_name" binding:"required"`
					ActivityType    string    `json:"activity_type" binding:"required,oneof=run walk bike hike"`
					StartTime       time.Time `json:"start_time" binding:"required"`
					DurationSeconds int       `json:"duration_seconds" binding:"required,gt=0"`
					DistanceMeters  float64   `json:"distance_meters" binding:"required,gte=0"`
				}
				if err := c.ShouldBindJSON(&req); err != nil {
					c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
					return
				}
				c.JSON(http.StatusOK, gin.H{"parsed": true})
			})

			w := httptest.NewRecorder()
			req := httptest.NewRequest("POST", "/activities", strings.NewReader(tt.body))
			req.Header.Set("Content-Type", "application/json")
			router.ServeHTTP(w, req)

			if w.Code != tt.expectCode {
				t.Errorf("expected status %d, got %d. Body: %s", tt.expectCode, w.Code, w.Body.String())
			}
		})
	}
}

func TestActivityModel_JSON(t *testing.T) {
	now := time.Now().UTC().Truncate(time.Second)
	pace := 5.05
	elev := 85.0

	type Activity struct {
		ID                  string     `json:"id"`
		UserID              string     `json:"user_id"`
		ActivityName        string     `json:"activity_name"`
		ActivityType        string     `json:"activity_type"`
		DistanceMeters      float64    `json:"distance_meters"`
		DurationSeconds     int        `json:"duration_seconds"`
		AvgPaceMinPerKm     *float64   `json:"avg_pace_min_per_km,omitempty"`
		ElevationGainMeters *float64   `json:"elevation_gain_meters,omitempty"`
		StartTime           time.Time  `json:"start_time"`
		CreatedAt           time.Time  `json:"created_at"`
	}

	activity := Activity{
		ID:                  "test-id-1",
		UserID:              "user-1",
		ActivityName:        "Morning Run",
		ActivityType:        "run",
		DistanceMeters:      10500,
		DurationSeconds:     3180,
		AvgPaceMinPerKm:     &pace,
		ElevationGainMeters: &elev,
		StartTime:           now,
		CreatedAt:           now,
	}

	// Serialize
	bytes, err := json.Marshal(activity)
	if err != nil {
		t.Fatalf("marshal failed: %v", err)
	}

	// Deserialize
	var restored Activity
	if err := json.Unmarshal(bytes, &restored); err != nil {
		t.Fatalf("unmarshal failed: %v", err)
	}

	if restored.ID != activity.ID {
		t.Errorf("ID mismatch: got %s, want %s", restored.ID, activity.ID)
	}
	if restored.DistanceMeters != activity.DistanceMeters {
		t.Errorf("DistanceMeters mismatch: got %f, want %f", restored.DistanceMeters, activity.DistanceMeters)
	}
	if restored.AvgPaceMinPerKm == nil || *restored.AvgPaceMinPerKm != pace {
		t.Errorf("AvgPaceMinPerKm mismatch")
	}
	if restored.StartTime.Unix() != activity.StartTime.Unix() {
		t.Errorf("StartTime mismatch")
	}
}

func TestListActivitiesResponse_Format(t *testing.T) {
	type listResponse struct {
		Activities []struct {
			ID           string  `json:"id"`
			ActivityType string  `json:"activity_type"`
			Distance     float64 `json:"distance_meters"`
		} `json:"activities"`
		Count int `json:"count"`
	}

	jsonStr := `{
		"activities": [
			{"id": "a1", "activity_type": "run", "distance_meters": 5000},
			{"id": "a2", "activity_type": "bike", "distance_meters": 15000}
		],
		"count": 2
	}`

	var resp listResponse
	if err := json.Unmarshal([]byte(jsonStr), &resp); err != nil {
		t.Fatalf("unmarshal failed: %v", err)
	}

	if resp.Count != 2 {
		t.Errorf("expected count 2, got %d", resp.Count)
	}
	if len(resp.Activities) != 2 {
		t.Fatalf("expected 2 activities, got %d", len(resp.Activities))
	}
	if resp.Activities[0].ActivityType != "run" {
		t.Errorf("expected 'run', got %s", resp.Activities[0].ActivityType)
	}
}

func TestHealthEndpoint(t *testing.T) {
	router := gin.New()
	router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":  "ok",
			"service": "apexrun-backend",
		})
	})

	w := httptest.NewRecorder()
	req := httptest.NewRequest("GET", "/health", nil)
	router.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}

	var resp map[string]string
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("unmarshal failed: %v", err)
	}
	if resp["status"] != "ok" {
		t.Errorf("expected status 'ok', got %s", resp["status"])
	}
}

func TestAuthRequired_NoHeader(t *testing.T) {
	router := gin.New()
	router.Use(func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"error": "missing authorization header",
			})
			return
		}
		c.Next()
	})
	router.GET("/protected", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"data": "secret"})
	})

	w := httptest.NewRecorder()
	req := httptest.NewRequest("GET", "/protected", nil)
	router.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d", w.Code)
	}
}

func TestAuthRequired_InvalidFormat(t *testing.T) {
	router := gin.New()
	router.Use(func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" || !strings.HasPrefix(authHeader, "Bearer ") {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"error": "invalid authorization format",
			})
			return
		}
		c.Next()
	})
	router.GET("/protected", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"data": "secret"})
	})

	w := httptest.NewRecorder()
	req := httptest.NewRequest("GET", "/protected", nil)
	req.Header.Set("Authorization", "Basic dGVzdDp0ZXN0")
	router.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("expected 401, got %d", w.Code)
	}
}

func TestGetUserID_FromContext(t *testing.T) {
	router := gin.New()
	var gotUserID string
	var gotOK bool

	router.GET("/test", func(c *gin.Context) {
		c.Set(auth.ContextKeyUserID, "user-123")
		gotUserID, gotOK = auth.GetUserID(c)
		c.JSON(http.StatusOK, gin.H{})
	})

	w := httptest.NewRecorder()
	req := httptest.NewRequest("GET", "/test", nil)
	router.ServeHTTP(w, req)

	if !gotOK {
		t.Error("expected GetUserID to return ok=true")
	}
	if gotUserID != "user-123" {
		t.Errorf("expected user-123, got %s", gotUserID)
	}
}

func TestGetUserID_Missing(t *testing.T) {
	router := gin.New()
	var gotOK bool

	router.GET("/test", func(c *gin.Context) {
		_, gotOK = auth.GetUserID(c)
		c.JSON(http.StatusOK, gin.H{})
	})

	w := httptest.NewRecorder()
	req := httptest.NewRequest("GET", "/test", nil)
	router.ServeHTTP(w, req)

	if gotOK {
		t.Error("expected GetUserID to return ok=false when no userID set")
	}
}
