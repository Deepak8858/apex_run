package coaching

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"

	"github.com/apexrun/backend/internal/auth"
)

// Handler serves AI coaching HTTP endpoints.
type Handler struct {
	repo   *Repository
	logger *zap.Logger
}

// NewHandler creates a new coaching handler.
func NewHandler(repo *Repository, logger *zap.Logger) *Handler {
	return &Handler{repo: repo, logger: logger}
}

// RegisterRoutes mounts coaching routes on the given RouterGroup.
func (h *Handler) RegisterRoutes(rg *gin.RouterGroup) {
	rg.GET("/daily", h.DailyWorkout)
	rg.POST("/analyze", h.Analyze)
}

// DailyWorkout handles GET /api/v1/coaching/daily
// Returns today's planned workout and the user's weekly training summary.
func (h *Handler) DailyWorkout(c *gin.Context) {
	userID, ok := auth.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	ctx := c.Request.Context()

	workout, err := h.repo.GetTodaysWorkout(ctx, userID)
	if err != nil {
		h.logger.Error("get todays workout", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		return
	}

	weekSummary, err := h.repo.GetWeekSummary(ctx, userID)
	if err != nil {
		h.logger.Error("get week summary", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		return
	}

	c.JSON(http.StatusOK, DailyWorkoutResponse{
		HasWorkout:  workout != nil,
		Workout:     workout,
		WeekSummary: weekSummary,
	})
}

// Analyze handles POST /api/v1/coaching/analyze
// Returns the user's weekly training summary for client-side AI analysis.
// Note: Actual Gemini LLM calls happen on the Flutter client (CoachingDataSource).
// This endpoint provides the structured data the AI model needs.
func (h *Handler) Analyze(c *gin.Context) {
	userID, ok := auth.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	var req AnalyzeRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	weekSummary, err := h.repo.GetWeekSummary(c.Request.Context(), userID)
	if err != nil {
		h.logger.Error("get week summary for analysis", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		return
	}

	c.JSON(http.StatusOK, AnalyzeResponse{
		Analysis:    req.Question, // Echo back; actual LLM processing is client-side
		WeekSummary: weekSummary,
	})
}
