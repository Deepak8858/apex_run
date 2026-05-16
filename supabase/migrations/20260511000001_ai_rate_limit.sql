-- 2026-05-11 — AI rate-limit infrastructure
--
-- Caps Gemini token spend per user per day. Called by every Edge Function
-- that fans out to a model provider. Hard ceiling per tier.

CREATE TABLE IF NOT EXISTS public.ai_usage (
  user_id     uuid    NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  usage_date  date    NOT NULL DEFAULT (now() AT TIME ZONE 'utc')::date,
  endpoint    text    NOT NULL,
  call_count  int     NOT NULL DEFAULT 0,
  updated_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, usage_date, endpoint)
);

ALTER TABLE public.ai_usage ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users read own ai_usage"
ON public.ai_usage
FOR SELECT
USING (auth.uid() = user_id);

-- No INSERT/UPDATE policy: writes happen via RPC under SECURITY DEFINER.

CREATE OR REPLACE FUNCTION public.check_and_increment_ai_quota(
  p_endpoint text,
  p_daily_limit int DEFAULT 25
)
RETURNS TABLE(allowed boolean, remaining int)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  caller uuid := auth.uid();
  today date := (now() AT TIME ZONE 'utc')::date;
  current_count int;
BEGIN
  IF caller IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  INSERT INTO public.ai_usage (user_id, usage_date, endpoint, call_count)
  VALUES (caller, today, p_endpoint, 0)
  ON CONFLICT (user_id, usage_date, endpoint) DO NOTHING;

  SELECT call_count INTO current_count
  FROM public.ai_usage
  WHERE user_id = caller AND usage_date = today AND endpoint = p_endpoint
  FOR UPDATE;

  IF current_count >= p_daily_limit THEN
    RETURN QUERY SELECT false, 0;
    RETURN;
  END IF;

  UPDATE public.ai_usage
  SET call_count = call_count + 1,
      updated_at = now()
  WHERE user_id = caller AND usage_date = today AND endpoint = p_endpoint;

  RETURN QUERY SELECT true, GREATEST(0, p_daily_limit - (current_count + 1));
END;
$$;

REVOKE ALL ON FUNCTION public.check_and_increment_ai_quota(text, int) FROM public;
GRANT EXECUTE ON FUNCTION public.check_and_increment_ai_quota(text, int) TO authenticated;
