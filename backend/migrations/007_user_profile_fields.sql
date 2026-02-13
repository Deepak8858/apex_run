-- Migration: Add user profile fields for onboarding
-- Adds username, height, weight, age, gender, fitness goal, step goal, and profile completion flag

-- Add new columns to user_profiles
ALTER TABLE public.user_profiles
  ADD COLUMN IF NOT EXISTS username TEXT UNIQUE,
  ADD COLUMN IF NOT EXISTS height_cm NUMERIC,
  ADD COLUMN IF NOT EXISTS weight_kg NUMERIC,
  ADD COLUMN IF NOT EXISTS age INT,
  ADD COLUMN IF NOT EXISTS gender TEXT CHECK (gender IN ('male', 'female', 'other', 'prefer_not_to_say')),
  ADD COLUMN IF NOT EXISTS fitness_goal TEXT CHECK (fitness_goal IN ('lose_weight', 'build_endurance', 'stay_active', 'run_faster', 'general_fitness')),
  ADD COLUMN IF NOT EXISTS daily_step_goal INT DEFAULT 10000,
  ADD COLUMN IF NOT EXISTS profile_completed BOOLEAN DEFAULT FALSE;

-- Create index on username for fast lookups
CREATE INDEX IF NOT EXISTS idx_user_profiles_username ON public.user_profiles (username);

-- Update existing profiles to mark as completed if they have a display_name
UPDATE public.user_profiles
SET profile_completed = TRUE
WHERE display_name IS NOT NULL AND display_name != '';
