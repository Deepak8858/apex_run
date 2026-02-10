-- ============================================================
-- ApexRun Database Migration - Complete Setup
-- Run this in Supabase SQL Editor
-- ============================================================

-- Step 1: Enable PostGIS
CREATE EXTENSION IF NOT EXISTS postgis SCHEMA extensions;

-- Step 2: Create Tables
-- User Profiles (extends Supabase auth.users)
CREATE TABLE IF NOT EXISTS public.user_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT,
  avatar_url TEXT,
  bio TEXT,
  home_location extensions.geography(Point, 4326),
  privacy_radius_meters INT DEFAULT 200,
  preferred_distance_unit TEXT DEFAULT 'km' CHECK (preferred_distance_unit IN ('km', 'mi')),
  preferred_pace_format TEXT DEFAULT 'min_per_km' CHECK (preferred_pace_format IN ('min_per_km', 'min_per_mi')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Activities (GPS tracked runs with full route data)
CREATE TABLE IF NOT EXISTS public.activities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  activity_name TEXT NOT NULL,
  activity_type TEXT DEFAULT 'run' CHECK (activity_type IN ('run', 'walk', 'bike', 'hike')),
  description TEXT,
  route_path extensions.geography(LineString, 4326) NOT NULL,
  distance_meters FLOAT NOT NULL CHECK (distance_meters >= 0),
  duration_seconds INT NOT NULL CHECK (duration_seconds > 0),
  avg_pace_min_per_km FLOAT,
  max_speed_kmh FLOAT,
  elevation_gain_meters FLOAT,
  elevation_loss_meters FLOAT,
  avg_heart_rate INT,
  max_heart_rate INT,
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ,
  raw_gps_points JSONB,
  heart_rate_stream JSONB,
  form_analysis_data JSONB,
  is_private BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Segments (fixed routes for community competition)
CREATE TABLE IF NOT EXISTS public.segments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  segment_path extensions.geography(LineString, 4326) NOT NULL,
  distance_meters FLOAT NOT NULL CHECK (distance_meters > 0),
  elevation_gain_meters FLOAT,
  creator_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  is_verified BOOLEAN DEFAULT FALSE,
  activity_type TEXT DEFAULT 'run' CHECK (activity_type IN ('run', 'walk', 'bike', 'hike')),
  total_attempts INT DEFAULT 0,
  unique_athletes INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Segment Efforts (leaderboard entries)
CREATE TABLE IF NOT EXISTS public.segment_efforts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  segment_id UUID NOT NULL REFERENCES public.segments(id) ON DELETE CASCADE,
  activity_id UUID NOT NULL REFERENCES public.activities(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  elapsed_seconds INT NOT NULL CHECK (elapsed_seconds > 0),
  avg_pace_min_per_km FLOAT NOT NULL,
  avg_heart_rate INT,
  max_speed_kmh FLOAT,
  recorded_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(segment_id, activity_id)
);

-- Planned Workouts (from AI Coach)
CREATE TABLE IF NOT EXISTS public.planned_workouts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  workout_type TEXT NOT NULL CHECK (workout_type IN ('easy', 'tempo', 'intervals', 'long_run', 'recovery', 'race')),
  description TEXT NOT NULL,
  target_distance_meters FLOAT,
  target_duration_minutes INT,
  coaching_rationale TEXT,
  planned_date DATE NOT NULL,
  is_completed BOOLEAN DEFAULT FALSE,
  completed_activity_id UUID REFERENCES public.activities(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Step 3: Create Spatial Indexes
CREATE INDEX IF NOT EXISTS idx_activities_route ON public.activities USING GIST (route_path);
CREATE INDEX IF NOT EXISTS idx_segments_path ON public.segments USING GIST (segment_path);
CREATE INDEX IF NOT EXISTS idx_user_home_location ON public.user_profiles USING GIST (home_location);

-- Step 4: Create Standard Indexes
CREATE INDEX IF NOT EXISTS idx_activities_user_id ON public.activities(user_id, start_time DESC);
CREATE INDEX IF NOT EXISTS idx_activities_recent ON public.activities(start_time DESC) WHERE is_private = FALSE;
CREATE INDEX IF NOT EXISTS idx_segment_efforts_leaderboard ON public.segment_efforts(segment_id, elapsed_seconds ASC);
CREATE INDEX IF NOT EXISTS idx_segment_efforts_user ON public.segment_efforts(user_id, segment_id, elapsed_seconds ASC);
CREATE INDEX IF NOT EXISTS idx_planned_workouts_user_date ON public.planned_workouts(user_id, planned_date DESC);

-- Step 5: Enable Row Level Security
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.segments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.segment_efforts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.planned_workouts ENABLE ROW LEVEL SECURITY;

-- Step 6: RLS Policies are created in migration 20260209000001_fix_rls_policies.sql

-- Step 7: Create Triggers
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_user_profiles_updated_at ON public.user_profiles;
CREATE TRIGGER update_user_profiles_updated_at BEFORE UPDATE ON public.user_profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_activities_updated_at ON public.activities;
CREATE TRIGGER update_activities_updated_at BEFORE UPDATE ON public.activities FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_segments_updated_at ON public.segments;
CREATE TRIGGER update_segments_updated_at BEFORE UPDATE ON public.segments FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_planned_workouts_updated_at ON public.planned_workouts;
CREATE TRIGGER update_planned_workouts_updated_at BEFORE UPDATE ON public.planned_workouts FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- Migration Complete!
-- Verify by running: SELECT table_name FROM information_schema.tables WHERE table_schema='public';
-- ============================================================
