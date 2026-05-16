-- 2026-05-11 — Challenges + activity highlight reels
--
-- `challenges`            global catalog of timed challenges (weekly auto-enrol, etc.)
-- `challenge_participants` enrolment + per-user progress snapshot

CREATE TABLE IF NOT EXISTS public.challenges (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code          text UNIQUE NOT NULL,
  name          text NOT NULL,
  description   text NOT NULL,
  category      text NOT NULL
                  CHECK (category IN ('distance', 'duration', 'count', 'elevation')),
  goal_value    numeric NOT NULL,                  -- meters / seconds / count / meters
  starts_at     timestamptz NOT NULL,
  ends_at       timestamptz NOT NULL,
  auto_enroll   boolean NOT NULL DEFAULT false,    -- weekly/monthly system challenges
  reward_xp     int NOT NULL DEFAULT 100,
  reward_badge_code text REFERENCES public.achievements(code) ON DELETE SET NULL,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS challenges_active_idx
  ON public.challenges(ends_at)
  WHERE ends_at > now();

ALTER TABLE public.challenges ENABLE ROW LEVEL SECURITY;
CREATE POLICY "challenges public read"
ON public.challenges FOR SELECT USING (true);

CREATE TABLE IF NOT EXISTS public.challenge_participants (
  challenge_id  uuid NOT NULL REFERENCES public.challenges(id) ON DELETE CASCADE,
  user_id       uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  progress      numeric NOT NULL DEFAULT 0,
  completed_at  timestamptz,
  joined_at     timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (challenge_id, user_id)
);

CREATE INDEX IF NOT EXISTS cp_user_idx
  ON public.challenge_participants(user_id);

ALTER TABLE public.challenge_participants ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users read all participants in joined challenges"
ON public.challenge_participants
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.challenge_participants cp2
    WHERE cp2.challenge_id = challenge_participants.challenge_id
      AND cp2.user_id = auth.uid()
  )
);

CREATE POLICY "users insert own enrollment"
ON public.challenge_participants
FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users update own progress"
ON public.challenge_participants
FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "users delete own enrollment"
ON public.challenge_participants
FOR DELETE USING (auth.uid() = user_id);

-- Auto-enroll caller into every active auto_enroll challenge they're not in.
CREATE OR REPLACE FUNCTION public.auto_enroll_active_challenges()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  caller uuid := auth.uid();
  inserted_count int := 0;
BEGIN
  IF caller IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  WITH inserted AS (
    INSERT INTO public.challenge_participants (challenge_id, user_id)
    SELECT c.id, caller
    FROM public.challenges c
    WHERE c.auto_enroll = true
      AND c.starts_at <= now()
      AND c.ends_at > now()
      AND NOT EXISTS (
        SELECT 1 FROM public.challenge_participants cp
        WHERE cp.challenge_id = c.id AND cp.user_id = caller
      )
    RETURNING 1
  )
  SELECT COUNT(*) INTO inserted_count FROM inserted;

  RETURN inserted_count;
END;
$$;
REVOKE ALL ON FUNCTION public.auto_enroll_active_challenges() FROM public;
GRANT EXECUTE ON FUNCTION public.auto_enroll_active_challenges() TO authenticated;

-- Roll caller's progress on every active enrolled challenge against an activity.
-- Called after activity insert. Increments by activity contribution + marks
-- completed_at when goal reached.
CREATE OR REPLACE FUNCTION public.apply_activity_to_challenges(
  p_distance_meters numeric,
  p_duration_seconds numeric,
  p_elevation_meters numeric
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  caller uuid := auth.uid();
BEGIN
  IF caller IS NULL THEN RETURN; END IF;

  UPDATE public.challenge_participants cp
  SET progress = cp.progress + CASE c.category
        WHEN 'distance'  THEN p_distance_meters
        WHEN 'duration'  THEN p_duration_seconds
        WHEN 'count'     THEN 1
        WHEN 'elevation' THEN p_elevation_meters
        ELSE 0
      END,
      completed_at = CASE
        WHEN cp.completed_at IS NULL
         AND cp.progress + CASE c.category
              WHEN 'distance'  THEN p_distance_meters
              WHEN 'duration'  THEN p_duration_seconds
              WHEN 'count'     THEN 1
              WHEN 'elevation' THEN p_elevation_meters
              ELSE 0
             END >= c.goal_value
        THEN now()
        ELSE cp.completed_at
      END
  FROM public.challenges c
  WHERE cp.challenge_id = c.id
    AND cp.user_id = caller
    AND c.starts_at <= now()
    AND c.ends_at > now();
END;
$$;
REVOKE ALL ON FUNCTION public.apply_activity_to_challenges(numeric, numeric, numeric) FROM public;
GRANT EXECUTE ON FUNCTION public.apply_activity_to_challenges(numeric, numeric, numeric) TO authenticated;

-- Seed two evergreen weekly challenges (auto-enrol)
INSERT INTO public.challenges (code, name, description, category, goal_value, starts_at, ends_at, auto_enroll, reward_xp)
VALUES
  (
    'weekly_25k',
    '25 km this week',
    'Cover 25 km between Monday and Sunday.',
    'distance',
    25000,
    date_trunc('week', now()),
    date_trunc('week', now()) + interval '7 days',
    true,
    150
  ),
  (
    'weekly_3runs',
    '3 runs this week',
    'Log 3 activities between Monday and Sunday.',
    'count',
    3,
    date_trunc('week', now()),
    date_trunc('week', now()) + interval '7 days',
    true,
    100
  )
ON CONFLICT (code) DO NOTHING;
