-- 2026-05-11 — Streak tracking + push token registry
--
-- Adds streak columns to user_profiles, an idempotent streak-update RPC,
-- and a push_tokens table for FCM/APNS device registration.

-- ── Streak columns ──────────────────────────────────────────────────
ALTER TABLE public.user_profiles
  ADD COLUMN IF NOT EXISTS streak_days int NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS streak_longest int NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS streak_freeze_available int NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS last_activity_date date;

-- ── update_streak RPC ───────────────────────────────────────────────
-- Idempotent: call after every saved activity. Same-day calls keep the
-- current streak; next-day calls increment; gap > 1 day (without freeze)
-- resets to 1.
CREATE OR REPLACE FUNCTION public.update_streak(p_activity_date date)
RETURNS TABLE(streak_days int, streak_longest int)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  caller uuid := auth.uid();
  prev_date date;
  prev_streak int;
  prev_longest int;
  prev_freezes int;
  new_streak int;
  new_longest int;
  diff int;
BEGIN
  IF caller IS NULL THEN
    RAISE EXCEPTION 'update_streak: not authenticated';
  END IF;

  SELECT last_activity_date, streak_days, streak_longest, streak_freeze_available
    INTO prev_date, prev_streak, prev_longest, prev_freezes
  FROM public.user_profiles
  WHERE id = caller
  FOR UPDATE;

  IF NOT FOUND THEN
    -- Profile row doesn't exist yet (first run before onboarding) — bail.
    RETURN QUERY SELECT 0, 0;
    RETURN;
  END IF;

  IF prev_date IS NULL THEN
    new_streak := 1;
  ELSE
    diff := p_activity_date - prev_date;
    IF diff = 0 THEN
      new_streak := GREATEST(prev_streak, 1);
    ELSIF diff = 1 THEN
      new_streak := prev_streak + 1;
    ELSIF diff = 2 AND prev_freezes > 0 THEN
      new_streak := prev_streak + 1;
      prev_freezes := prev_freezes - 1;
    ELSIF diff < 0 THEN
      -- activity dated in the past relative to last; keep current streak
      new_streak := prev_streak;
    ELSE
      new_streak := 1;
    END IF;
  END IF;

  new_longest := GREATEST(new_streak, COALESCE(prev_longest, 0));

  UPDATE public.user_profiles
  SET streak_days = new_streak,
      streak_longest = new_longest,
      streak_freeze_available = prev_freezes,
      last_activity_date = GREATEST(COALESCE(prev_date, p_activity_date), p_activity_date)
  WHERE id = caller;

  RETURN QUERY SELECT new_streak, new_longest;
END;
$$;

REVOKE ALL ON FUNCTION public.update_streak(date) FROM public;
GRANT EXECUTE ON FUNCTION public.update_streak(date) TO authenticated;

-- ── push_tokens ─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.push_tokens (
  user_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  token      text NOT NULL,
  platform   text NOT NULL CHECK (platform IN ('ios', 'android', 'web')),
  app_version text,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, token)
);

CREATE INDEX IF NOT EXISTS push_tokens_user_idx ON public.push_tokens(user_id);

ALTER TABLE public.push_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users manage own push tokens"
ON public.push_tokens
FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);
