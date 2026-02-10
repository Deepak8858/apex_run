package segments

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"

	"github.com/apexrun/backend/internal/auth"
	"github.com/apexrun/backend/internal/database"
)

// Handler serves segment HTTP endpoints.
type Handler struct {
	repo                *Repository
	redis               *database.Redis
	segmentMatchBuffer  int
	logger              *zap.Logger
}

// NewHandler creates a new segments handler.
func NewHandler(repo *Repository, redis *database.Redis, segmentMatchBuffer int, logger *zap.Logger) *Handler {
	return &Handler{
		repo:               repo,
		redis:              redis,
		segmentMatchBuffer: segmentMatchBuffer,
		logger:             logger,
	}
}

// RegisterRoutes mounts segment routes on the given RouterGroup.
func (h *Handler) RegisterRoutes(rg *gin.RouterGroup) {
	rg.GET("", h.List)
	rg.GET("/:id", h.GetByID)
	rg.GET("/:id/leaderboard", h.Leaderboard)
	rg.POST("", h.Create)
	rg.POST("/match", h.Match)
}

// List handles GET /api/v1/segments
func (h *Handler) List(c *gin.Context) {
	var nearLat, nearLng, radiusKm *float64

	if v := c.Query("near_lat"); v != "" {
		f, err := strconv.ParseFloat(v, 64)
		if err == nil {
			nearLat = &f
		}
	}
	if v := c.Query("near_lng"); v != "" {
		f, err := strconv.ParseFloat(v, 64)
		if err == nil {
			nearLng = &f
		}
	}
	if v := c.Query("radius_km"); v != "" {
		f, err := strconv.ParseFloat(v, 64)
		if err == nil {
			radiusKm = &f
		}
	}

	segments, err := h.repo.ListSegments(c.Request.Context(), nearLat, nearLng, radiusKm)
	if err != nil {
		h.logger.Error("list segments", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		return
	}

	if segments == nil {
		segments = []Segment{}
	}
	c.JSON(http.StatusOK, gin.H{"segments": segments})
}

// GetByID handles GET /api/v1/segments/:id
func (h *Handler) GetByID(c *gin.Context) {
	segmentID := c.Param("id")

	segment, err := h.repo.GetByID(c.Request.Context(), segmentID)
	if err != nil {
		h.logger.Error("get segment", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		return
	}
	if segment == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "segment not found"})
		return
	}

	c.JSON(http.StatusOK, segment)
}

// Leaderboard handles GET /api/v1/segments/:id/leaderboard
func (h *Handler) Leaderboard(c *gin.Context) {
	segmentID := c.Param("id")
	limit := 50
	if v := c.Query("limit"); v != "" {
		if l, err := strconv.Atoi(v); err == nil && l > 0 {
			limit = l
		}
	}

	efforts, err := h.repo.GetLeaderboard(c.Request.Context(), segmentID, limit)
	if err != nil {
		h.logger.Error("get leaderboard", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		return
	}

	if efforts == nil {
		efforts = []SegmentEffort{}
	}
	c.JSON(http.StatusOK, gin.H{"leaderboard": efforts})
}

// Create handles POST /api/v1/segments
func (h *Handler) Create(c *gin.Context) {
	userID, ok := auth.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	var req CreateSegmentRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	segment, err := h.repo.Create(c.Request.Context(), userID, &req)
	if err != nil {
		h.logger.Error("create segment", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to create segment"})
		return
	}

	c.JSON(http.StatusCreated, segment)
}

// Match handles POST /api/v1/segments/match
// Finds all segments that overlap with a given activity's route.
func (h *Handler) Match(c *gin.Context) {
	userID, ok := auth.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	var req MatchSegmentsRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	matchedIDs, err := h.repo.MatchActivityToSegments(
		c.Request.Context(), req.ActivityID, h.segmentMatchBuffer,
	)
	if err != nil {
		h.logger.Error("match segments", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "segment matching failed"})
		return
	}

	if matchedIDs == nil {
		matchedIDs = []string{}
	}

	c.JSON(http.StatusOK, gin.H{
		"matches":     matchedIDs,
		"match_count": len(matchedIDs),
		"user_id":     userID,
	})
}
