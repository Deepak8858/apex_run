# ApexRun Production Build & Deployment Guide

## Prerequisites
- Flutter 3.19+ with Dart SDK ^3.10.8
- Go 1.22+ (for backend)
- Docker & Docker Compose (for services)
- Supabase CLI (for local dev/migrations)

## Environment Variables

### Flutter App (pass via --dart-define)
```bash
flutter run \
  --dart-define=SUPABASE_URL=https://voddddmmiarnbvwmgzgo.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<your-anon-key> \
  --dart-define=MAPBOX_ACCESS_TOKEN=<your-mapbox-token> \
  --dart-define=BACKEND_API_URL=https://your-backend.com \
  --dart-define=GEMINI_API_KEY=<your-gemini-key> \
  --dart-define=GEMINI_MODEL=gemini-2.5-flash
```

### Go Backend
```bash
DATABASE_URL=postgresql://user:pass@host:5432/postgres
REDIS_URL=redis://:password@host:6379/0
SUPABASE_JWT_SECRET=your-jwt-secret
PORT=8080
```

### Supabase Edge Functions
Set these in Supabase Dashboard > Edge Functions > Secrets:
- `GEMINI_API_KEY` — Google Gemini API key
- `GEMINI_MODEL` — Model name (gemini-2.5-flash)

## Build Commands

### Android Release APK
```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://voddddmmiarnbvwmgzgo.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<key> \
  --dart-define=MAPBOX_ACCESS_TOKEN=<token> \
  --dart-define=BACKEND_API_URL=https://api.apexrun.app \
  --dart-define=GEMINI_API_KEY=<key>
```

### Android App Bundle (Play Store)
```bash
flutter build appbundle --release \
  --dart-define=SUPABASE_URL=https://voddddmmiarnbvwmgzgo.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<key> \
  --dart-define=MAPBOX_ACCESS_TOKEN=<token> \
  --dart-define=BACKEND_API_URL=https://api.apexrun.app \
  --dart-define=GEMINI_API_KEY=<key>
```

### iOS Release
```bash
flutter build ios --release \
  --dart-define=SUPABASE_URL=https://voddddmmiarnbvwmgzgo.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<key> \
  --dart-define=MAPBOX_ACCESS_TOKEN=<token> \
  --dart-define=BACKEND_API_URL=https://api.apexrun.app \
  --dart-define=GEMINI_API_KEY=<key>
```

### Go Backend Docker
```bash
cd backend
docker build -t apexrun-backend:latest .
docker run -p 8080:8080 --env-file .env apexrun-backend:latest
```

### ML Service Docker
```bash
cd ml-service
docker build -t apexrun-ml:latest .
docker run -p 8001:8001 apexrun-ml:latest
```

### Full Stack (Docker Compose)
```bash
docker-compose up -d
```

## Database

### Apply Migrations
```bash
# Via Supabase CLI
supabase db push

# Or via MCP (already applied):
# - Initial schema (tables, indexes, RLS)
# - RLS policies
# - insert_activity RPC function
# - update_home_location RPC function
# - ML data tables (form_analysis_results, hrv_readings, training_load_history)
# - Segment matching functions (match_segments_for_activity, process_segment_efforts)
# - Privacy shroud function (get_privacy_shrouded_route)
# - Training load functions (get_weekly_training_load, calculate_acwr)
# - Leaderboard functions (get_segment_leaderboard, refresh_leaderboard, get_personal_best)
# - User stats function (get_user_stats)
# - Production optimizations (materialized view, auto-profile trigger)
```

### Deployed Edge Functions
1. **process-coaching** — Gemini AI workout generation (JWT required)
2. **process-activity** — Post-activity segment matching & ACWR calculation (JWT required)

## Production Checklist

### Security
- [x] RLS enabled on all tables
- [x] Service key NOT embedded in client
- [x] JWT verification on Edge Functions
- [x] CORS headers configured
- [x] Gemini API key only in Edge Function secrets (not client)
- [x] Privacy shroud for home location (200m radius)

### Performance
- [x] PostGIS spatial indexes on route_path, segment_path, home_location
- [x] Composite indexes on frequently queried columns
- [x] Materialized view for leaderboard (with concurrent refresh)
- [x] GPS accuracy filtering (20m threshold)
- [x] Android foreground service for background GPS
- [x] iOS background location updates enabled
- [x] ProGuard/R8 minification for Android release

### Monitoring
- [x] Go backend structured logging
- [x] Edge Function error logging
- [x] DioClient request/response logging (debug only)
- [x] GPS stream error handling (non-fatal)

### Testing
- [x] Unit tests for models & calculators
- [x] Widget tests for screens
- [x] Integration tests for data flow
- [x] Go backend handler tests
- [x] CI/CD via GitHub Actions
