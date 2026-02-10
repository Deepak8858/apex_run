"""
ApexRun ML Service — Custom Model Training & Inference

FastAPI service for:
- Running gait analysis model training
- Injury risk prediction
- Performance forecasting
- Custom TFLite model generation for on-device inference
"""
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, List
import numpy as np

app = FastAPI(
    title="ApexRun ML Service",
    description="Machine Learning models for running performance analysis",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ================================================================
# Request/Response Models
# ================================================================

class GaitAnalysisRequest(BaseModel):
    """Request for gait analysis prediction."""
    ground_contact_time_ms: float
    vertical_oscillation_cm: float
    cadence_spm: int
    stride_length_m: float
    forward_lean_degrees: Optional[float] = None
    hip_drop_degrees: Optional[float] = None
    avg_pace_min_per_km: float


class InjuryRiskResponse(BaseModel):
    """Injury risk prediction result."""
    risk_score: float  # 0.0 - 1.0
    risk_level: str  # low, moderate, high
    risk_factors: List[str]
    recommendations: List[str]


class PerformanceForecast(BaseModel):
    """Performance prediction for upcoming race."""
    predicted_5k_seconds: int
    predicted_10k_seconds: int
    predicted_half_marathon_seconds: int
    predicted_marathon_seconds: int
    confidence: float
    training_suggestions: List[str]


class TrainingLoadRequest(BaseModel):
    """Weekly training data for load analysis."""
    weekly_distance_km: float
    weekly_duration_minutes: int
    run_count: int
    avg_pace_min_per_km: float
    intensity_distribution: Optional[dict] = None  # {easy: 0.8, moderate: 0.15, hard: 0.05}
    resting_heart_rate: Optional[int] = None
    hrv_rmssd: Optional[float] = None


class TrainingLoadResponse(BaseModel):
    """Training load analysis result."""
    acute_load: float
    chronic_load: float
    acute_chronic_ratio: float  # ACWR — ideal 0.8-1.3
    training_status: str  # optimal, overreaching, detraining, overtraining
    recommendation: str


# ================================================================
# Health Check
# ================================================================

@app.get("/health")
async def health():
    return {"status": "ok", "service": "ml-service", "version": "1.0.0"}


# ================================================================
# Gait Analysis & Injury Risk
# ================================================================

@app.post("/api/v1/gait/injury-risk", response_model=InjuryRiskResponse)
async def predict_injury_risk(request: GaitAnalysisRequest):
    """
    Predict injury risk based on gait biomechanics.
    
    Uses a rule-based model as baseline; can be replaced with trained ML model.
    Key risk factors:
    - Low cadence + long stride → higher impact forces
    - Excessive hip drop → ITB issues  
    - High vertical oscillation → energy waste + joint stress
    """
    risk_factors = []
    recommendations = []
    risk_score = 0.0

    # Cadence analysis
    if request.cadence_spm < 160:
        risk_score += 0.2
        risk_factors.append("Very low cadence increases impact forces")
        recommendations.append("Increase step rate by 5-10% over 4 weeks")
    elif request.cadence_spm < 170:
        risk_score += 0.1
        risk_factors.append("Below-optimal cadence")

    # Ground contact time
    if request.ground_contact_time_ms > 300:
        risk_score += 0.15
        risk_factors.append("Extended ground contact time → overstriding risk")
        recommendations.append("Focus on quick, light steps")

    # Vertical oscillation
    if request.vertical_oscillation_cm > 12:
        risk_score += 0.15
        risk_factors.append("High vertical oscillation increases joint stress")
        recommendations.append("Run 'quiet' — minimize up-down motion")

    # Hip drop
    if request.hip_drop_degrees and request.hip_drop_degrees > 8:
        risk_score += 0.2
        risk_factors.append("Excessive hip drop — glute weakness indicator")
        recommendations.append("Add single-leg glute bridges and clamshells 3x/week")

    # Overstriding
    if request.stride_length_m > 1.3 and request.cadence_spm < 170:
        risk_score += 0.15
        risk_factors.append("Long stride + low cadence = overstriding pattern")
        recommendations.append("Shorten stride and increase turnover")

    risk_score = min(risk_score, 1.0)
    risk_level = "low" if risk_score < 0.3 else "moderate" if risk_score < 0.6 else "high"

    if not recommendations:
        recommendations.append("Good biomechanics! Maintain current form focus.")

    return InjuryRiskResponse(
        risk_score=round(risk_score, 2),
        risk_level=risk_level,
        risk_factors=risk_factors if risk_factors else ["No significant risk factors detected"],
        recommendations=recommendations,
    )


# ================================================================
# Performance Forecasting
# ================================================================

@app.post("/api/v1/performance/forecast", response_model=PerformanceForecast)
async def forecast_performance(request: TrainingLoadRequest):
    """
    Predict race times based on training data.
    
    Uses Riegel's formula with training-adjusted corrections:
    T2 = T1 * (D2/D1)^1.06
    """
    # Estimate a reference 5K time from training pace
    # Training easy pace is ~70-75% of race pace for most runners
    reference_pace_sec_per_km = request.avg_pace_min_per_km * 60
    race_5k_pace = reference_pace_sec_per_km * 0.85  # ~15% faster than easy pace

    # Riegel's formula for distance predictions
    t_5k = int(race_5k_pace * 5)
    t_10k = int(t_5k * (10 / 5) ** 1.06)
    t_half = int(t_5k * (21.1 / 5) ** 1.06)
    t_marathon = int(t_5k * (42.2 / 5) ** 1.06)

    # Confidence based on training volume
    base_confidence = 0.5
    if request.weekly_distance_km >= 50:
        base_confidence += 0.2
    elif request.weekly_distance_km >= 30:
        base_confidence += 0.15
    elif request.weekly_distance_km >= 20:
        base_confidence += 0.1

    if request.run_count >= 5:
        base_confidence += 0.1
    if request.run_count >= 4:
        base_confidence += 0.05

    suggestions = []
    if request.weekly_distance_km < 30:
        suggestions.append("Increase weekly mileage gradually to improve endurance")
    if request.run_count < 4:
        suggestions.append("Add 1-2 more easy runs per week for consistency")
    if request.avg_pace_min_per_km > 7:
        suggestions.append("Include one tempo run per week to improve speed")

    return PerformanceForecast(
        predicted_5k_seconds=t_5k,
        predicted_10k_seconds=t_10k,
        predicted_half_marathon_seconds=t_half,
        predicted_marathon_seconds=t_marathon,
        confidence=round(min(base_confidence, 0.95), 2),
        training_suggestions=suggestions if suggestions else ["Great training — maintain consistency!"],
    )


# ================================================================
# Training Load Analysis (ACWR)
# ================================================================

@app.post("/api/v1/training/load", response_model=TrainingLoadResponse)
async def analyze_training_load(request: TrainingLoadRequest):
    """
    Analyze training load using Acute:Chronic Workload Ratio (ACWR).
    
    ACWR Guidelines:
    - < 0.8: Detraining / under-load
    - 0.8-1.3: Sweet spot (minimal injury risk)
    - 1.3-1.5: Overreaching (caution)
    - > 1.5: Danger zone (high injury risk)
    """
    # Calculate acute load (this week's training stress)
    acute_load = request.weekly_distance_km * (1 + (1 / request.avg_pace_min_per_km))

    # Estimate chronic load (assume ~80% of acute for a typical training block)
    # In production, this would use 4-week rolling average from database
    chronic_load = acute_load * 0.85

    # ACWR
    acwr = acute_load / chronic_load if chronic_load > 0 else 1.0

    # Determine training status
    if acwr < 0.8:
        status = "detraining"
        recommendation = "Your training load has decreased significantly. Gradually increase volume to maintain fitness."
    elif acwr <= 1.3:
        status = "optimal"
        recommendation = "Training load is in the sweet spot. Maintain current progression rate."
    elif acwr <= 1.5:
        status = "overreaching"
        recommendation = "Training load spike detected. Consider an easy week to allow adaptation."
    else:
        status = "overtraining"
        recommendation = "High injury risk! Reduce volume by 30-40% this week and focus on recovery."

    # Adjust for HRV if available
    if request.hrv_rmssd is not None and request.hrv_rmssd < 30:
        if status == "optimal":
            status = "overreaching"
            recommendation = "Low HRV detected despite normal load. Prioritize recovery this week."

    return TrainingLoadResponse(
        acute_load=round(acute_load, 1),
        chronic_load=round(chronic_load, 1),
        acute_chronic_ratio=round(acwr, 2),
        training_status=status,
        recommendation=recommendation,
    )


# ================================================================
# Entry Point
# ================================================================

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)
