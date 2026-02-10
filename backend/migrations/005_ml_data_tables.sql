-- Phase 5: ML/AI Data Tables
-- Form analysis results, HRV data, and training load tracking

-- Form Analysis Results (from MediaPipe pose estimation)
CREATE TABLE IF NOT EXISTS form_analysis_results (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    activity_id UUID REFERENCES activities(id) ON DELETE SET NULL,
    ground_contact_time_ms FLOAT NOT NULL,
    vertical_oscillation_cm FLOAT NOT NULL,
    cadence_spm INTEGER NOT NULL,
    stride_length_m FLOAT NOT NULL,
    forward_lean_degrees FLOAT,
    knee_lift_angle_degrees FLOAT,
    arm_swing_symmetry FLOAT,
    hip_drop_degrees FLOAT,
    foot_strike TEXT DEFAULT 'midfoot',
    form_score INTEGER NOT NULL CHECK (form_score >= 0 AND form_score <= 100),
    coaching_tips JSONB DEFAULT '[]'::jsonb,
    frames_analyzed INTEGER DEFAULT 0,
    avg_landmark_confidence FLOAT DEFAULT 0.0,
    analyzed_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- HRV Data (from HealthKit/Health Connect)
CREATE TABLE IF NOT EXISTS hrv_readings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    rmssd FLOAT NOT NULL,
    sdnn FLOAT,
    resting_heart_rate INTEGER NOT NULL,
    hrv_score INTEGER NOT NULL CHECK (hrv_score >= 0 AND hrv_score <= 100),
    recovery_status TEXT NOT NULL DEFAULT 'moderate',
    sleep_quality_score INTEGER,
    sleep_duration_minutes INTEGER,
    deep_sleep_ratio FLOAT,
    readiness_score INTEGER,
    weekly_avg_rmssd FLOAT,
    source TEXT DEFAULT 'manual',
    measured_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Training Load History (for ACWR calculation)
CREATE TABLE IF NOT EXISTS training_load_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    week_start DATE NOT NULL,
    weekly_distance_km FLOAT NOT NULL DEFAULT 0,
    weekly_duration_minutes INTEGER NOT NULL DEFAULT 0,
    run_count INTEGER NOT NULL DEFAULT 0,
    avg_pace_min_per_km FLOAT,
    acute_load FLOAT,
    chronic_load FLOAT,
    acute_chronic_ratio FLOAT,
    training_status TEXT DEFAULT 'optimal',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (user_id, week_start)
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_form_analysis_user ON form_analysis_results(user_id, analyzed_at DESC);
CREATE INDEX IF NOT EXISTS idx_hrv_user ON hrv_readings(user_id, measured_at DESC);
CREATE INDEX IF NOT EXISTS idx_training_load_user ON training_load_history(user_id, week_start DESC);

-- Row Level Security
ALTER TABLE form_analysis_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE hrv_readings ENABLE ROW LEVEL SECURITY;
ALTER TABLE training_load_history ENABLE ROW LEVEL SECURITY;

-- Policies: Users can only read/write their own data
CREATE POLICY "Users can manage their form analysis"
    ON form_analysis_results FOR ALL
    USING (auth.uid() = user_id);

CREATE POLICY "Users can manage their HRV data"
    ON hrv_readings FOR ALL
    USING (auth.uid() = user_id);

CREATE POLICY "Users can manage their training load"
    ON training_load_history FOR ALL
    USING (auth.uid() = user_id);
