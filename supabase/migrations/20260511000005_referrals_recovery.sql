-- 2026-05-11 — Referral codes + redemption tracking + recovery snapshots
--
-- Each user gets a stable 8-char referral code on first call. Redemption
-- inserts a row in `referrals` and grants 30 days of Pro tier to BOTH
-- referrer and referee. RLS prevents anyone from inserting redemptions
-- they did not perform; the grant runs SECURITY DEFINER under the caller.

-- ── Referral codes ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.referral_codes (
  user_id    uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  code       text UNIQUE NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.referral_codes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "referral_codes read own"
ON public.referral_codes
FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "referral_codes public lookup"
ON public.referral_codes
FOR SELECT USING (true);

-- Generates a base32-ish 8-char code, retries on collision (≤5 attempts).
CREATE OR REPLACE FUNCTION public.get_or_create_referral_code()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  caller uuid := auth.uid();
  existing text;
  candidate text;
  attempts int := 0;
BEGIN
  IF caller IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  SELECT code INTO existing FROM public.referral_codes WHERE user_id = caller;
  IF existing IS NOT NULL THEN
    RETURN existing;
  END IF;

  LOOP
    candidate := upper(
      translate(
        encode(gen_random_bytes(6), 'base64'),
        '/+=O0I1',
        'ABCDXYZ'
      )
    );
    candidate := substring(candidate FROM 1 FOR 8);
    BEGIN
      INSERT INTO public.referral_codes (user_id, code) VALUES (caller, candidate);
      RETURN candidate;
    EXCEPTION WHEN unique_violation THEN
      attempts := attempts + 1;
      IF attempts >= 5 THEN
        RAISE EXCEPTION 'referral_code_generation_failed';
      END IF;
    END;
  END LOOP;
END;
$$;
REVOKE ALL ON FUNCTION public.get_or_create_referral_code() FROM public;
GRANT EXECUTE ON FUNCTION public.get_or_create_referral_code() TO authenticated;

-- ── Redemptions ─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.referrals (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_id  uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  referee_id   uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  code         text NOT NULL,
  redeemed_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (referee_id),                -- a user can only be referred once
  CHECK (referrer_id <> referee_id)
);

CREATE INDEX IF NOT EXISTS referrals_referrer_idx ON public.referrals(referrer_id);

ALTER TABLE public.referrals ENABLE ROW LEVEL SECURITY;

CREATE POLICY "referrals read involved"
ON public.referrals
FOR SELECT USING (auth.uid() IN (referrer_id, referee_id));

-- Inserts handled via RPC only.

-- Redeem a code. Returns referrer_id when successful. Grants 30 days of Pro
-- tier to both parties via `subscriptions` upsert.
CREATE OR REPLACE FUNCTION public.redeem_referral_code(p_code text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  caller uuid := auth.uid();
  referrer uuid;
  existing uuid;
  new_expiry timestamptz := now() + interval '30 days';
BEGIN
  IF caller IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  SELECT user_id INTO referrer
  FROM public.referral_codes
  WHERE code = upper(p_code);

  IF referrer IS NULL THEN
    RAISE EXCEPTION 'invalid_code';
  END IF;
  IF referrer = caller THEN
    RAISE EXCEPTION 'cannot_redeem_own_code';
  END IF;

  SELECT id INTO existing FROM public.referrals WHERE referee_id = caller;
  IF existing IS NOT NULL THEN
    RAISE EXCEPTION 'already_redeemed';
  END IF;

  INSERT INTO public.referrals (referrer_id, referee_id, code)
  VALUES (referrer, caller, upper(p_code));

  -- Grant 30 days of Pro to BOTH parties. Extends current_period_ends_at
  -- when an active subscription already exists.
  INSERT INTO public.subscriptions (user_id, tier, status, current_period_ends_at, updated_at)
  VALUES (referrer, 'pro', 'active', new_expiry, now())
  ON CONFLICT (user_id) DO UPDATE
    SET tier = CASE WHEN public.subscriptions.tier = 'pro_plus'
                    THEN public.subscriptions.tier
                    ELSE 'pro' END,
        status = 'active',
        current_period_ends_at = GREATEST(
          COALESCE(public.subscriptions.current_period_ends_at, now()),
          new_expiry
        ),
        updated_at = now();

  INSERT INTO public.subscriptions (user_id, tier, status, current_period_ends_at, updated_at)
  VALUES (caller, 'pro', 'active', new_expiry, now())
  ON CONFLICT (user_id) DO UPDATE
    SET tier = CASE WHEN public.subscriptions.tier = 'pro_plus'
                    THEN public.subscriptions.tier
                    ELSE 'pro' END,
        status = 'active',
        current_period_ends_at = GREATEST(
          COALESCE(public.subscriptions.current_period_ends_at, now()),
          new_expiry
        ),
        updated_at = now();

  RETURN referrer;
END;
$$;
REVOKE ALL ON FUNCTION public.redeem_referral_code(text) FROM public;
GRANT EXECUTE ON FUNCTION public.redeem_referral_code(text) TO authenticated;

-- ── Recovery score snapshots ────────────────────────────────────────
-- Computed daily by an Edge Function (or client) from HRV + sleep + load.
CREATE TABLE IF NOT EXISTS public.recovery_scores (
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  date        date NOT NULL,
  score       int  NOT NULL CHECK (score BETWEEN 0 AND 100),
  hrv_ms      numeric,
  sleep_hours numeric,
  load_acwr   numeric,
  notes       text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, date)
);

ALTER TABLE public.recovery_scores ENABLE ROW LEVEL SECURITY;

CREATE POLICY "recovery_scores own all"
ON public.recovery_scores
FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- ── Expanded achievement catalog (additive, ON CONFLICT DO UPDATE) ───
INSERT INTO public.achievements (code, name, description, icon, rarity, threshold, category)
VALUES
  -- Distance (more rungs)
  ('three_km',         '3K Starter',       'Run 3 km in a single activity.',                'flag',           'common',    3000,    'distance'),
  ('fifteen_km',       '15K Strong',       'Run 15 km in a single activity.',               'flag',           'rare',      15000,   'distance'),
  ('thirty_km',        '30K Tough',        'Run 30 km in a single activity.',               'emoji_events',   'rare',      30000,   'distance'),
  ('lifetime_100km',   'Century Club',     '100 km lifetime distance.',                     'workspace_premium','common',  100000,  'distance'),
  ('lifetime_500km',   '500 Club',         '500 km lifetime distance.',                     'workspace_premium','rare',    500000,  'distance'),
  ('lifetime_1000km',  '1000 Club',        '1000 km lifetime distance.',                    'workspace_premium','epic',    1000000, 'distance'),
  ('lifetime_5000km',  '5K Mile Club',     '5000 km lifetime distance.',                    'workspace_premium','legendary',5000000,'distance'),

  -- Streak (extra rungs)
  ('streak_14',        'Fortnight',        '14-day activity streak.',                       'local_fire_department','rare',    14,    'streak'),
  ('streak_60',        '60-Day Beast',     '60-day activity streak.',                       'local_fire_department','epic',   60,   'streak'),
  ('streak_365',       'Year of Running',  '365-day activity streak.',                      'local_fire_department','legendary',365, 'streak'),

  -- PRs
  ('pr_5k',            '5K PR',            'Set a new personal best over 5 km.',            'speed',          'rare',      NULL,    'pr'),
  ('pr_10k',           '10K PR',           'Set a new personal best over 10 km.',           'speed',          'rare',      NULL,    'pr'),
  ('pr_half',          'Half PR',          'Set a new personal best over half marathon.',  'speed',          'epic',      NULL,    'pr'),
  ('pr_marathon',      'Marathon PR',      'Set a new personal best over marathon.',       'speed',          'legendary', NULL,    'pr'),

  -- Pace milestones
  ('sub_5_min_km',     'Sub-5',            'Average pace under 5:00/km for 5+ km.',         'bolt',           'rare',      NULL,    'pr'),
  ('sub_4_min_km',     'Sub-4',            'Average pace under 4:00/km for 5+ km.',         'bolt',           'epic',      NULL,    'pr'),

  -- Social
  ('first_friend',     'Squad Up',         'Add your first friend.',                        'group_add',      'common',    NULL,    'social'),
  ('first_kudos_given','Hype Mode',        'Give your first kudos.',                        'thumb_up',       'common',    NULL,    'social'),
  ('first_kudos_received','Crowd Pleaser','Receive your first kudos.',                     'favorite',       'common',    NULL,    'social'),
  ('ten_friends',      'Crew',             'Add 10 friends.',                               'groups',         'rare',      10,      'social'),
  ('referral_made',    'Recruiter',        'Refer a friend who joins Apex Run.',            'card_giftcard',  'rare',      NULL,    'social'),

  -- Special
  ('rain_runner',      'Rain Runner',      'Complete an activity in rain conditions.',      'water_drop',     'rare',      NULL,    'special'),
  ('hill_climber',     'Hill Climber',     'Gain 500 m of elevation in one activity.',     'trending_up',    'rare',      500,     'elevation'),
  ('mountain_goat',    'Mountain Goat',    'Gain 1500 m of elevation in one activity.',    'landscape',      'epic',      1500,    'elevation'),
  ('weekend_warrior',  'Weekend Warrior',  'Run every weekend in a month.',                'event_available','rare',      NULL,    'streak'),
  ('challenge_first',  'First Challenge',  'Complete your first challenge.',               'flag_circle',    'common',    NULL,    'special'),
  ('challenge_ten',    'Challenge Veteran','Complete 10 challenges.',                      'flag_circle',    'rare',      10,      'special')
ON CONFLICT (code) DO UPDATE
SET name = EXCLUDED.name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    rarity = EXCLUDED.rarity,
    threshold = EXCLUDED.threshold,
    category = EXCLUDED.category;

-- Add 'elevation' to the category check constraint (additive)
DO $$
BEGIN
  ALTER TABLE public.achievements DROP CONSTRAINT IF EXISTS achievements_category_check;
EXCEPTION WHEN undefined_object THEN
  -- ignore
END $$;

ALTER TABLE public.achievements
  ADD CONSTRAINT achievements_category_check
  CHECK (category IN ('distance', 'streak', 'pr', 'social', 'special', 'elevation'));
