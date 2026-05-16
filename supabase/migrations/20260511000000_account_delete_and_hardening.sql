-- 2026-05-11 — Apex Run hardening
--
-- 1. Tighten user_profiles SELECT (current policy exposes private columns
--    like email/weight/age to all authenticated users).
-- 2. Add explicit DELETE policies where missing (no current way to delete
--    your own activities/segment_efforts/planned_workouts via RLS).
-- 3. Add a single `delete_my_account()` SECURITY DEFINER function the
--    Edge Function calls after verifying the caller's JWT.

-- ── 1. user_profiles: restrict the broad SELECT ─────────────────────
DROP POLICY IF EXISTS "Anyone can view public user profiles" ON public.user_profiles;

-- Only owner sees the full row...
CREATE POLICY "users read own profile full"
ON public.user_profiles
FOR SELECT
USING (auth.uid() = id);

-- ...and a public view exposes only safe columns.
CREATE OR REPLACE VIEW public.user_profiles_public AS
SELECT
  id,
  display_name,
  username,
  avatar_url,
  bio
FROM public.user_profiles;

GRANT SELECT ON public.user_profiles_public TO authenticated, anon;

-- ── 2. Missing DELETE policies ──────────────────────────────────────
DROP POLICY IF EXISTS "Users can delete own efforts" ON public.segment_efforts;
CREATE POLICY "Users can delete own efforts"
ON public.segment_efforts
FOR DELETE
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own workouts" ON public.planned_workouts;
CREATE POLICY "Users can delete own workouts"
ON public.planned_workouts
FOR DELETE
USING (auth.uid() = user_id);

-- ── 3. delete_my_account RPC ────────────────────────────────────────
-- Called by the `delete-account` Edge Function. SECURITY DEFINER lets it
-- delete rows owned by the caller across tables, but the function still
-- asserts auth.uid() = the target user so a JWT is required.
CREATE OR REPLACE FUNCTION public.delete_my_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  caller uuid := auth.uid();
BEGIN
  IF caller IS NULL THEN
    RAISE EXCEPTION 'delete_my_account: not authenticated';
  END IF;

  -- Cascade-style cleanup. Each table is filtered by user_id/owner_id.
  DELETE FROM public.segment_efforts   WHERE user_id    = caller;
  DELETE FROM public.planned_workouts  WHERE user_id    = caller;
  DELETE FROM public.activities        WHERE user_id    = caller;
  -- Segments authored by user become orphans (kept for leaderboard history).
  UPDATE public.segments SET creator_id = NULL WHERE creator_id = caller;
  DELETE FROM public.user_profiles     WHERE id         = caller;

  -- auth.users row deleted by the Edge Function using the service role key.
END;
$$;

REVOKE ALL ON FUNCTION public.delete_my_account() FROM public;
GRANT EXECUTE ON FUNCTION public.delete_my_account() TO authenticated;
