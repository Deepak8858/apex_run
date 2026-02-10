-- ApexRun Database Schema Migration v001
-- PostGIS-enabled schema for GPS tracking, segments, and leaderboards

--================================================================================
-- EXTENSIONS
--================================================================================

-- Enable PostGIS for spatial operations
CREATE EXTENSION IF NOT EXISTS postgis SCHEMA extensions;

--================================================================================
-- TABLES
--================================================================================

-- User Profiles (extends Supabase auth.users)
CREATE TABLE IF NOT EXISTS public.user_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT,
  avatar_url TEXT,
  bio TEXT,
  -- Privacy: Home location for route blurring
  home_location extensions.geography(Point, 4326),
  privacy_radius_meters INT DEFAULT 200,
  -- Preferences
  preferred_distance_unit TEXT DEFAULT 'km' CHECK (preferred_distance_unit IN ('km', 'mi')),
  preferred_pace_format TEXT DEFAULT 'min_per_km' CHECK (preferred_pace_format IN ('min_per_km', 'min_per_mi')),
  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Activities (GPS tracked runs with full route data)
CREATE TABLE IF NOT EXISTS public.activities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Activity Details
  activity_name TEXT NOT NULL,
  activity_type TEXT DEFAULT 'run' CHECK (activity_type IN ('run', 'walk', 'bike', 'hike')),
  description TEXT,

  -- GPS Data (stored as PostGIS LineString)
  route_path extensions.geography(LineString, 4326) NOT NULL,

  -- Performance Metrics
  distance_meters FLOAT NOT NULL CHECK (distance_meters >= 0),
  duration_seconds INT NOT NULL CHECK (duration_seconds > 0),
  avg_pace_min_per_km FLOAT,
  max_speed_kmh FLOAT,
  elevation_gain_meters FLOAT,
  elevation_loss_meters FLOAT,

  -- Heart Rate Data (if available)
  avg_heart_rate INT,
  max_heart_rate INT,

  -- Timing
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ,

  -- Raw Data (for detailed analysis)
  raw_gps_points JSONB, -- Array of {lat, lng, timestamp, altitude, accuracy}
  heart_rate_stream JSONB, -- Array of {timestamp, bpm}

  -- Form Analysis (from MediaPipe)
  form_analysis_data JSONB, -- {knee_angle, vertical_oscillation, cadence, etc.}

  -- Privacy
  is_private BOOLEAN DEFAULT FALSE,

  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Segments (fixed routes for community competition)
CREATE TABLE IF NOT EXISTS public.segments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Segment Details
  name TEXT NOT NULL,
  description TEXT,

  -- GPS Path (PostGIS LineString for matching)
  segment_path extensions.geography(LineString, 4326) NOT NULL,

  -- Metrics
  distance_meters FLOAT NOT NULL CHECK (distance_meters > 0),
  elevation_gain_meters FLOAT,

  -- Segment Metadata
  creator_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  is_verified BOOLEAN DEFAULT FALSE, -- Verified by admins for accuracy
  activity_type TEXT DEFAULT 'run' CHECK (activity_type IN ('run', 'walk', 'bike', 'hike')),

  -- Statistics (updated periodically)
  total_attempts INT DEFAULT 0,
  unique_athletes INT DEFAULT 0,

  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Segment Efforts (leaderboard entries for segment completions)
CREATE TABLE IF NOT EXISTS public.segment_efforts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Relations
  segment_id UUID NOT NULL REFERENCES public.segments(id) ON DELETE CASCADE,
  activity_id UUID NOT NULL REFERENCES public.activities(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Performance Metrics
  elapsed_seconds INT NOT NULL CHECK (elapsed_seconds > 0),
  avg_pace_min_per_km FLOAT NOT NULL,
  avg_heart_rate INT,
  max_speed_kmh FLOAT,

  -- Timing
  recorded_at TIMESTAMPTZ NOT NULL,

  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),

  -- Ensure one effort per activity per segment
  UNIQUE(segment_id, activity_id)
);

-- Planned Workouts (from AI Coach)
CREATE TABLE IF NOT EXISTS public.planned_workouts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Workout Details
  workout_type TEXT NOT NULL CHECK (workout_type IN ('easy', 'tempo', 'intervals', 'long_run', 'recovery', 'race')),
  description TEXT NOT NULL,
  target_distance_meters FLOAT,
  target_duration_minutes INT,

  -- AI Coach Rationale
  coaching_rationale TEXT, -- Why Gemini recommended this workout

  -- Scheduling
  planned_date DATE NOT NULL,
  is_completed BOOLEAN DEFAULT FALSE,
  completed_activity_id UUID REFERENCES public.activities(id) ON DELETE SET NULL,

  -- Metadata
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

--================================================================================
-- SPATIAL INDEXES (Critical for Performance)
--================================================================================

-- Activities: Fast route queries and segment matching
CREATE INDEX IF NOT EXISTS idx_activities_route
  ON public.activities USING GIST (route_path);

-- Segments: Fast segment lookup by location
CREATE INDEX IF NOT EXISTS idx_segments_path
  ON public.segments USING GIST (segment_path);

-- User profiles: Privacy radius calculations
CREATE INDEX IF NOT EXISTS idx_user_home_location
  ON public.user_profiles USING GIST (home_location);

--================================================================================
-- STANDARD INDEXES
--================================================================================

-- Activities: User timeline queries
CREATE INDEX IF NOT EXISTS idx_activities_user_id
  ON public.activities(user_id, start_time DESC);

-- Activities: Public feed
CREATE INDEX IF NOT EXISTS idx_activities_recent
  ON public.activities(start_time DESC) WHERE is_private = FALSE;

-- Segment efforts: Leaderboards (sorted by time)
CREATE INDEX IF NOT EXISTS idx_segment_efforts_leaderboard
  ON public.segment_efforts(segment_id, elapsed_seconds ASC);

-- Segment efforts: User's personal bests
CREATE INDEX IF NOT EXISTS idx_segment_efforts_user
  ON public.segment_efforts(user_id, segment_id, elapsed_seconds ASC);

-- Planned workouts: User's schedule
CREATE INDEX IF NOT EXISTS idx_planned_workouts_user_date
  ON public.planned_workouts(user_id, planned_date DESC);

--================================================================================
-- ROW LEVEL SECURITY (RLS)
--================================================================================

-- Enable RLS on all tables
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.segments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.segment_efforts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.planned_workouts ENABLE ROW LEVEL SECURITY;

-- User Profiles
CREATE POLICY "Anyone can view public user profiles"
  ON public.user_profiles
  FOR SELECT
  USING (true);

CREATE POLICY "Users can update own profile"
  ON public.user_profiles
  FOR UPDATE
  USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
  ON public.user_profiles
  FOR INSERT
  WITH CHECK (auth.uid() = id);

-- Activities
CREATE POLICY "Users can view public activities"
  ON public.activities
  FOR SELECT
  USING (is_private = FALSE OR auth.uid() = user_id);

CREATE POLICY "Users can insert own activities"
  ON public.activities
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own activities"
  ON public.activities
  FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own activities"
  ON public.activities
  FOR DELETE
  USING (auth.uid() = user_id);

-- Segments
CREATE POLICY "Anyone can view segments"
  ON public.segments
  FOR SELECT
  USING (true);

CREATE POLICY "Authenticated users can create segments"
  ON public.segments
  FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Creators can update own segments"
  ON public.segments
  FOR UPDATE
  USING (auth.uid() = creator_id);

-- Segment Efforts
CREATE POLICY "Anyone can view segment efforts"
  ON public.segment_efforts
  FOR SELECT
  USING (true);

CREATE POLICY "Users can create own efforts"
  ON public.segment_efforts
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Planned Workouts
CREATE POLICY "Users can view own workouts"
  ON public.planned_workouts
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own workouts"
  ON public.planned_workouts
  FOR ALL
  USING (auth.uid() = user_id);

--================================================================================
-- FUNCTIONS
--================================================================================

-- Function to auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for updated_at
CREATE TRIGGER update_user_profiles_updated_at
  BEFORE UPDATE ON public.user_profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_activities_updated_at
  BEFORE UPDATE ON public.activities
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_segments_updated_at
  BEFORE UPDATE ON public.segments
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_planned_workouts_updated_at
  BEFORE UPDATE ON public.planned_workouts
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

--================================================================================
-- SAMPLE SEGMENT MATCHING QUERY
--================================================================================

-- To find segments that match an activity's route:
--
-- SELECT s.id, s.name, s.distance_meters
-- FROM segments s
-- WHERE extensions.ST_DWithin(s.segment_path, :activity_route_path, 20) -- Within 20m buffer
--   AND extensions.ST_CoveredBy(
--         s.segment_path,
--         extensions.ST_Buffer(:activity_route_path, 15)
--       ); -- Segment is covered by activity route

--================================================================================
-- VERIFICATION QUERIES
--================================================================================

-- Verify PostGIS is installed:
-- SELECT PostGIS_version();

-- View all tables:
-- SELECT table_name FROM information_schema.tables WHERE table_schema='public';

-- Check spatial indexes:
-- SELECT tablename, indexname FROM pg_indexes WHERE tablename IN ('activities', 'segments', 'user_profiles');
