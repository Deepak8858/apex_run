package activities

import (
	"database/sql"
	"net/http"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"

	"github.com/apexrun/backend/internal/auth"
)

// Handler serves activity HTTP endpoints.
type Handler struct {
	repo   *Repository
	logger *zap.Logger
}

// NewHandler creates a new activities handler.
func NewHandler(repo *Repository, logger *zap.Logger) *Handler {
	return &Handler{repo: repo, logger: logger}
}

// RegisterRoutes mounts activity routes on the given RouterGroup.
func (h *Handler) RegisterRoutes(rg *gin.RouterGroup) {
	rg.POST("", h.Create)
	rg.GET("", h.List)
	rg.GET("/:id", h.GetByID)
	rg.PUT("/:id", h.Update)
	rg.DELETE("/:id", h.Delete)
}

// Create handles POST /api/v1/activities
func (h *Handler) Create(c *gin.Context) {
	userID, ok := auth.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	var req CreateActivityRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	activity, err := h.repo.Create(c.Request.Context(), userID, &req)
	if err != nil {
		h.logger.Error("create activity", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to create activity"})
		return
	}

	c.JSON(http.StatusCreated, activity)
}

// GetByID handles GET /api/v1/activities/:id
func (h *Handler) GetByID(c *gin.Context) {
	userID, ok := auth.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	activityID := c.Param("id")
	activity, err := h.repo.GetByID(c.Request.Context(), userID, activityID)
	if err != nil {
		h.logger.Error("get activity", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		return
	}
	if activity == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "activity not found"})
		return
	}

	c.JSON(http.StatusOK, activity)
}

// List handles GET /api/v1/activities
func (h *Handler) List(c *gin.Context) {
	userID, ok := auth.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	var params ListActivitiesParams
	if err := c.ShouldBindQuery(&params); err != nil {
		params.Limit = 20
		params.Offset = 0
	}

	activities, err := h.repo.List(c.Request.Context(), userID, params.Limit, params.Offset)
	if err != nil {
		h.logger.Error("list activities", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		return
	}

	if activities == nil {
		activities = []Activity{}
	}
	c.JSON(http.StatusOK, gin.H{"activities": activities, "count": len(activities)})
}

// Update handles PUT /api/v1/activities/:id
func (h *Handler) Update(c *gin.Context) {
	userID, ok := auth.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	activityID := c.Param("id")
	var req UpdateActivityRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	activity, err := h.repo.Update(c.Request.Context(), userID, activityID, &req)
	if err != nil {
		h.logger.Error("update activity", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		return
	}
	if activity == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "activity not found"})
		return
	}

	c.JSON(http.StatusOK, activity)
}

// Delete handles DELETE /api/v1/activities/:id
func (h *Handler) Delete(c *gin.Context) {
	userID, ok := auth.GetUserID(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}

	activityID := c.Param("id")
	err := h.repo.Delete(c.Request.Context(), userID, activityID)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusNotFound, gin.H{"error": "activity not found"})
		return
	}
	if err != nil {
		h.logger.Error("delete activity", zap.Error(err))
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "activity deleted"})
}
