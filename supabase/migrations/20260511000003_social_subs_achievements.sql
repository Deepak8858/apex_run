-- 2026-05-11 — Social graph, subscriptions, achievements
--
-- Adds:
--   * subscriptions       — RevenueCat entitlement mirror (server of truth)
--   * friendships         — pairwise friend requests + accept/block states
--   * kudos               — likes on activities
--   * achievements        — catalog of unlockable badges
--   * user_achievements   — which user unlocked which badge + when

-- ── Subscriptions ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.subscriptions (
  user_id          uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  tier             text NOT NULL DEFAULT 'free'
                     CHECK (tier IN ('free', 'pro', 'pro_plus')),
  status           text NOT NULL DEFAULT 'inactive'
                     CHECK (status IN ('inactive', 'trial', 'active', 'in_grace', 'cancelled', 'expired')),
  revenue_cat_app_user_id text,
  product_id       text,
  current_period_ends_at  timestamptz,
  trial_ends_at    timestamptz,
  updated_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS subscriptions_tier_idx ON public.subscriptions(tier);

ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;

-- Users read their own row only. Writes happen via RevenueCat webhook
-- (service role) — no client-side INSERT/UPDATE/DELETE policies.
CREATE POLICY "users read own subscription"
ON public.subscriptions
FOR SELECT USING (auth.uid() = user_id);

-- Helper: current tier of a user (free if no row).
CREATE OR REPLACE FUNCTION public.current_user_tier()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    (SELECT tier FROM public.subscriptions
     WHERE user_id = auth.uid()
       AND status IN ('trial', 'active', 'in_grace')
       AND (current_period_ends_at IS NULL OR current_period_ends_at > now())),
    'free'
  );
$$;
GRANT EXECUTE ON FUNCTION public.current_user_tier() TO authenticated;

-- ── Friendships ─────────────────────────────────────────────────────
-- Two rows per friendship (A→B + B→A) keeps queries simple; status mirrored.
-- Enforced via trigger so we never end up half-friends.
CREATE TABLE IF NOT EXISTS public.friendships (
  user_id   uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  friend_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status    text NOT NULL CHECK (status IN ('pending', 'accepted', 'blocked')),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, friend_id),
  CHECK (user_id <> friend_id)
);

CREATE INDEX IF NOT EXISTS friendships_friend_idx
  ON public.friendships(friend_id) WHERE status = 'accepted';

ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users read own friendships"
ON public.friendships
FOR SELECT USING (auth.uid() = user_id OR auth.uid() = friend_id);

CREATE POLICY "users insert own outbound"
ON public.friendships
FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users update own friendships"
ON public.friendships
FOR UPDATE USING (auth.uid() = user_id OR auth.uid() = friend_id);

CREATE POLICY "users delete own friendships"
ON public.friendships
FOR DELETE USING (auth.uid() = user_id OR auth.uid() = friend_id);

-- ── Kudos ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.kudos (
  activity_id uuid NOT NULL REFERENCES public.activities(id) ON DELETE CASCADE,
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (activity_id, user_id)
);

CREATE INDEX IF NOT EXISTS kudos_activity_idx ON public.kudos(activity_id);

ALTER TABLE public.kudos ENABLE ROW LEVEL SECURITY;

-- Anyone can read kudos for activities they can read (RLS on activities
-- already filters private). Insert/delete only for own row.
CREATE POLICY "kudos read all"
ON public.kudos
FOR SELECT USING (true);

CREATE POLICY "kudos insert own"
ON public.kudos
FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "kudos delete own"
ON public.kudos
FOR DELETE USING (auth.uid() = user_id);

-- Optional denormalized counter on activities for the feed.
ALTER TABLE public.activities
  ADD COLUMN IF NOT EXISTS kudos_count int NOT NULL DEFAULT 0;

CREATE OR REPLACE FUNCTION public._kudos_increment()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  UPDATE public.activities SET kudos_count = kudos_count + 1
    WHERE id = NEW.activity_id;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public._kudos_decrement()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  UPDATE public.activities SET kudos_count = GREATEST(0, kudos_count - 1)
    WHERE id = OLD.activity_id;
  RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS kudos_after_insert ON public.kudos;
CREATE TRIGGER kudos_after_insert
AFTER INSERT ON public.kudos
FOR EACH ROW EXECUTE FUNCTION public._kudos_increment();

DROP TRIGGER IF EXISTS kudos_after_delete ON public.kudos;
CREATE TRIGGER kudos_after_delete
AFTER DELETE ON public.kudos
FOR EACH ROW EXECUTE FUNCTION public._kudos_decrement();

-- ── Achievements ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.achievements (
  code        text PRIMARY KEY,
  name        text NOT NULL,
  description text NOT NULL,
  icon        text,
  rarity      text NOT NULL DEFAULT 'common'
                CHECK (rarity IN ('common', 'rare', 'epic', 'legendary')),
  threshold   numeric,
  category    text NOT NULL
                CHECK (category IN ('distance', 'streak', 'pr', 'social', 'special'))
);

ALTER TABLE public.achievements ENABLE ROW LEVEL SECURITY;
CREATE POLICY "achievements public read"
ON public.achievements FOR SELECT USING (true);

CREATE TABLE IF NOT EXISTS public.user_achievements (
  user_id        uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  achievement_code text NOT NULL REFERENCES public.achievements(code) ON DELETE CASCADE,
  unlocked_at    timestamptz NOT NULL DEFAULT now(),
  activity_id    uuid REFERENCES public.activities(id) ON DELETE SET NULL,
  PRIMARY KEY (user_id, achievement_code)
);

CREATE INDEX IF NOT EXISTS user_achievements_unlocked_idx
  ON public.user_achievements(user_id, unlocked_at DESC);

ALTER TABLE public.user_achievements ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users read own achievements"
ON public.user_achievements
FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "users insert own achievements"
ON public.user_achievements
FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ── Seed achievements catalog ───────────────────────────────────────
INSERT INTO public.achievements (code, name, description, icon, rarity, threshold, category)
VALUES
  ('first_run',       'First Steps',        'Complete your first activity.',                   'directions_run', 'common',    1,      'distance'),
  ('five_km',         '5K Crusher',         'Run 5 kilometers in a single activity.',          'flag',           'common',    5000,   'distance'),
  ('ten_km',          '10K Finisher',       'Run 10 kilometers in a single activity.',         'emoji_events',   'common',    10000,  'distance'),
  ('half_marathon',   'Half Marathon',      'Run 21.1 kilometers in a single activity.',       'workspace_premium','rare',    21097,  'distance'),
  ('marathon',        'Marathon',           'Run 42.2 kilometers in a single activity.',       'military_tech',  'epic',      42195,  'distance'),
  ('ultra',           'Ultra',              'Run 50 kilometers in a single activity.',         'star',           'legendary', 50000,  'distance'),
  ('streak_3',        'Heating Up',         '3-day activity streak.',                          'local_fire_department','common',  3,    'streak'),
  ('streak_7',        'Week On',            '7-day activity streak.',                          'local_fire_department','rare',    7,    'streak'),
  ('streak_30',       'Monthly Beast',      '30-day activity streak.',                         'local_fire_department','epic',   30,   'streak'),
  ('streak_100',      'Centurion',          '100-day activity streak.',                        'local_fire_department','legendary',100, 'streak'),
  ('early_bird',      'Early Bird',         'Complete an activity before 7am local time.',     'wb_sunny',       'rare',      NULL,   'special'),
  ('night_owl',       'Night Owl',          'Complete an activity after 10pm local time.',     'bedtime',        'rare',      NULL,   'special')
ON CONFLICT (code) DO UPDATE
SET name = EXCLUDED.name,
    description = EXCLUDED.description,
    icon = EXCLUDED.icon,
    rarity = EXCLUDED.rarity,
    threshold = EXCLUDED.threshold,
    category = EXCLUDED.category;
