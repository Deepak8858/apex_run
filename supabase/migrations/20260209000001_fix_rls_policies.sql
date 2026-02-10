-- Fix RLS Policies - Drop and Recreate
-- This migration handles existing policies by dropping them first

-- Drop existing policies if they exist
DO $$ 
BEGIN
    -- User Profiles policies
    DROP POLICY IF EXISTS "Anyone can view public user profiles" ON public.user_profiles;
    DROP POLICY IF EXISTS "Users can update own profile" ON public.user_profiles;
    DROP POLICY IF EXISTS "Users can insert own profile" ON public.user_profiles;
    
    -- Activities policies
    DROP POLICY IF EXISTS "Users can view public activities" ON public.activities;
    DROP POLICY IF EXISTS "Users can insert own activities" ON public.activities;
    DROP POLICY IF EXISTS "Users can update own activities" ON public.activities;
    DROP POLICY IF EXISTS "Users can delete own activities" ON public.activities;
    
    -- Segments policies
    DROP POLICY IF EXISTS "Anyone can view segments" ON public.segments;
    DROP POLICY IF EXISTS "Authenticated users can create segments" ON public.segments;
    DROP POLICY IF EXISTS "Creators can update own segments" ON public.segments;
    
    -- Segment Efforts policies
    DROP POLICY IF EXISTS "Anyone can view segment efforts" ON public.segment_efforts;
    DROP POLICY IF EXISTS "Users can create own efforts" ON public.segment_efforts;
    
    -- Planned Workouts policies
    DROP POLICY IF EXISTS "Users can view own workouts" ON public.planned_workouts;
    DROP POLICY IF EXISTS "Users can manage own workouts" ON public.planned_workouts;
END $$;

-- Recreate RLS Policies
-- User Profiles
CREATE POLICY "Anyone can view public user profiles" ON public.user_profiles FOR SELECT USING (true);
CREATE POLICY "Users can update own profile" ON public.user_profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can insert own profile" ON public.user_profiles FOR INSERT WITH CHECK (auth.uid() = id);

-- Activities
CREATE POLICY "Users can view public activities" ON public.activities FOR SELECT USING (is_private = FALSE OR auth.uid() = user_id);
CREATE POLICY "Users can insert own activities" ON public.activities FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own activities" ON public.activities FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own activities" ON public.activities FOR DELETE USING (auth.uid() = user_id);

-- Segments
CREATE POLICY "Anyone can view segments" ON public.segments FOR SELECT USING (true);
CREATE POLICY "Authenticated users can create segments" ON public.segments FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "Creators can update own segments" ON public.segments FOR UPDATE USING (auth.uid() = creator_id);

-- Segment Efforts
CREATE POLICY "Anyone can view segment efforts" ON public.segment_efforts FOR SELECT USING (true);
CREATE POLICY "Users can create own efforts" ON public.segment_efforts FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Planned Workouts
CREATE POLICY "Users can view own workouts" ON public.planned_workouts FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can manage own workouts" ON public.planned_workouts FOR ALL USING (auth.uid() = user_id);
