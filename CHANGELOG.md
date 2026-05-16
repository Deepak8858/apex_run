# Changelog

All notable changes to Apex Run are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/) + semver.

## [Unreleased — soft launch candidate]

### Added
- Onboarding rewritten as `Value-prop → Permissions → Auth → Profile`
- Push notifications via FCM; streak-warn schedules at 20:00 local when streak ≥ 3
- Audio coach with TTS — per-km / per-mi splits, start/pause/resume cues, post-run summary
- Recovery score (0-100) on home, weighted from HRV + sleep + ACWR
- Streaks system w/ idempotent server-side update; home badge
- Social — friends, kudos, friends feed, friend discovery search
- Challenges — weekly auto-enrol, progress tracking, completion detection
- 39-code achievement catalog (distance, streak, pace, elevation, lifetime, PR, social, special)
- Achievement evaluator: PRs over 5K/10K/half/marathon, lifetime distance rungs, hill+mountain
- Confetti celebration + share button on activity-saved sheet
- Highlight reel generator — 1080×1920 canvas-rendered PNG, shareable
- Subscriptions — RevenueCat init + paywall screen, server-side entitlement mirror via webhook
- Referrals — 8-char codes, redemption RPC that grants 30 days Pro to both parties
- Deep links — `apexrun://r/CODE`, `apexrun://challenge/CODE`, `apexrun://friend/UID`, `apexrun://activity/ID` + universal-link variants
- Localization scaffolding for English / Spanish / German / French
- Responsive layout helper + accessibility text-scale clamp

### Changed
- Bottom nav: `Home / Feed / Record / Challenges / Profile` (Coach + Leaderboard moved to Home tiles)
- Activity feed and detail use cursor pagination + projection (no `raw_gps_points` overfetch)
- Token refresh single-flight mutex in Dio interceptor
- Gemini calls moved fully server-side via Edge Functions w/ per-user daily quota

### Security
- Removed all hardcoded secrets from source (`env.dart`, `seed_data.ps1`, `DEPLOY_DIGITALOCEAN.md`, `gradle.properties`)
- Sentry crash + performance reporting with PII strip
- Hive encrypted at rest via Keystore-stored AES key
- Certificate pinning in Dio (when `BACKEND_CERT_SHA256_FINGERPRINTS` provided)
- Logger with email/JWT/Bearer/UUID redaction; removed every `print()` in lib/
- Account deletion via Edge Function (RPC purge + `auth.admin.deleteUser`)
- RLS hardening migration — `user_profiles` SELECT now own-only, public columns via view
- Android 13+ POST_NOTIFICATIONS via permission_handler (handles permanently-denied state)

### Infrastructure
- Supabase migrations:
  - `20260511000000_account_delete_and_hardening.sql`
  - `20260511000001_ai_rate_limit.sql`
  - `20260511000002_streaks_and_push.sql`
  - `20260511000003_social_subs_achievements.sql`
  - `20260511000004_challenges_and_reels.sql`
  - `20260511000005_referrals_recovery.sql`
- Supabase Edge Functions:
  - `delete-account`
  - `coach-insight`
  - `revenuecat-webhook`
  - Plus `process-coaching` quota-gated
