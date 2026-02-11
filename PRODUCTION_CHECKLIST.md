# ApexRun Production Readiness Checklist

> Generated for full production deployment audit.
> ✅ = Done | 🔧 = Needs work | ❌ = Missing/Blocked

---

## 1. Backend (Go 1.22+ / Gin)

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1.1 | Health endpoint (`/health`) | ✅ | Returns 200 + JSON |
| 1.2 | Activities CRUD (`/api/v1/activities`) | ✅ | GET/POST with auth |
| 1.3 | Segments CRUD (`/api/v1/segments`) | ✅ | GET with auth |
| 1.4 | AI Coaching daily (`/api/v1/coaching/daily`) | ✅ | Gemini 2.5 Flash integration |
| 1.5 | AI Coaching analyze (`/api/v1/coaching/analyze`) | ✅ | Activity analysis endpoint |
| 1.6 | JWT auth middleware (ES256 + HS256) | ✅ | JWKS cache with 5-min TTL |
| 1.7 | CORS configuration | ✅ | Set in main.go |
| 1.8 | Rate limiting | ✅ | Configured in main.go |
| 1.9 | Graceful shutdown | ✅ | Signal handler in main.go |
| 1.10 | Request logging middleware | ✅ | Custom logger pkg |
| 1.11 | Database connection pool | ✅ | PostgreSQL via pgx |
| 1.12 | Redis connection | ✅ | Leaderboards + caching |
| 1.13 | Environment variable config | ✅ | internal/config/config.go |
| 1.14 | Unit tests | 🔧 | handler_test.go exists for activities + segments; add more coverage |
| 1.15 | Docker build | ✅ | Dockerfile present |
| 1.16 | Production binary build | ✅ | `CGO_ENABLED=0 go build` |
| 1.17 | Error handling & recovery | 🔧 | Add panic recovery middleware |
| 1.18 | API versioning | ✅ | `/api/v1/` prefix |
| 1.19 | Request validation | 🔧 | Add struct tag validation |
| 1.20 | Structured logging (JSON) | 🔧 | Switch from text to JSON logger for production |

---

## 2. Frontend (Flutter 3.19+)

| # | Item | Status | Notes |
|---|------|--------|-------|
| 2.1 | `dart analyze` — 0 errors | ✅ | Clean — only info-level style warnings |
| 2.2 | `flutter pub get` — all deps resolved | ✅ | All packages available |
| 2.3 | Supabase auth flow | ✅ | Login, sign-up, session management |
| 2.4 | Home screen | ✅ | Dashboard with stats |
| 2.5 | Record screen (GPS tracking) | ✅ | Background geolocation |
| 2.6 | AI Coach screen | ✅ | Gemini integration via backend |
| 2.7 | Form analysis screen (MediaPipe) | ✅ | 33-landmark pose detection |
| 2.8 | Leaderboard screen | ✅ | Segment leaderboards |
| 2.9 | Profile screen | ✅ | User settings/stats |
| 2.10 | Route map widget (Mapbox) | ✅ | Mapbox SDK with Impeller |
| 2.11 | Riverpod state management | ✅ | All providers wired |
| 2.12 | Dio HTTP client with auth interceptor | ✅ | Auto-attaches JWT |
| 2.13 | Dark mode theme (#0A0A0A / #CCFF00) | ✅ | ApexRun design system |
| 2.14 | Bottom navigation | ✅ | 5-tab persistent nav |
| 2.15 | Privacy shroud (200m home blur) | ✅ | Feature flag enabled |
| 2.16 | Background GPS tracking | ✅ | flutter_background_geolocation |
| 2.17 | TFLite model service | ✅ | Server inference + rule-based fallback |
| 2.18 | Gait metrics calculator | ✅ | GCT, vertical osc, cadence, etc. |
| 2.19 | HRV service | ✅ | Health data integration |
| 2.20 | Widget tests | 🔧 | 4 widget tests exist; expand coverage |
| 2.21 | Integration tests | 🔧 | data_flow_test.dart exists; add more |
| 2.22 | Unit tests | ✅ | env, gait_metrics, models, weekly_stats tests |
| 2.23 | Android build (`flutter build apk --release`) | 🔧 | Not yet built — needs signing key |
| 2.24 | iOS build (`flutter build ipa`) | 🔧 | Not yet built — needs Apple certs |
| 2.25 | App icon & splash screen | 🔧 | Configure flutter_launcher_icons |
| 2.26 | Feature flags | ✅ | 6 flags in env.dart |
| 2.27 | `--dart-define` env injection | ✅ | All config externalized |
| 2.28 | Deprecation warnings (withOpacity) | 🔧 | ~80 info-level, replace with `Color.withValues()` |

---

## 3. ML Service (Python FastAPI)

| # | Item | Status | Notes |
|---|------|--------|-------|
| 3.1 | Health endpoint (`/health`) | ✅ | FastAPI app |
| 3.2 | Gait injury risk endpoint | ✅ | Rule-based scoring |
| 3.3 | Performance forecast endpoint | ✅ | Riegel's formula |
| 3.4 | Training load endpoint | ✅ | ACWR calculation |
| 3.5 | TFLite model builder | ✅ | 3 models: gait_form, injury_risk, performance |
| 3.6 | TFLite model list API | ✅ | GET /api/v1/models |
| 3.7 | TFLite model download API | ✅ | GET /api/v1/models/{filename} |
| 3.8 | TFLite server inference API | ✅ | POST /api/v1/inference |
| 3.9 | Model build trigger API | ✅ | POST /api/v1/models/build |
| 3.10 | Normalization params API | ✅ | GET /api/v1/models/{name}/normalization |
| 3.11 | Dockerfile with TensorFlow | ✅ | Updated with system deps |
| 3.12 | Healthcheck in Dockerfile | ✅ | Configured |
| 3.13 | Train models with real data | 🔧 | Currently uses synthetic data — swap when real data available |
| 3.14 | Model versioning | 🔧 | Add version tags to model files |
| 3.15 | API authentication | 🔧 | Add JWT/API-key auth to ML endpoints |

---

## 4. Database (Supabase PostgreSQL + PostGIS)

| # | Item | Status | Notes |
|---|------|--------|-------|
| 4.1 | PostGIS extension enabled | ✅ | `CREATE EXTENSION postgis` |
| 4.2 | Initial schema migration | ✅ | 20260209000000_apexrun_initial_schema.sql |
| 4.3 | RLS policies | ✅ | 20260209000001_fix_rls_policies.sql |
| 4.4 | Activity insert function | ✅ | 20260210000000_activity_insert_function.sql |
| 4.5 | Profile location function | ✅ | 20260210000001_profile_location_function.sql |
| 4.6 | Spatial indexes (GIST) | ✅ | On activities.route_path + segments.segment_path |
| 4.7 | Connection pooling (PgBouncer) | ✅ | Supabase provides this |
| 4.8 | Backups | ✅ | Supabase auto-backup |
| 4.9 | SSL/TLS for DB connections | ✅ | sslmode=require in connection string |
| 4.10 | Migration versioning | ✅ | Dated migration files |
| 4.11 | DB performance monitoring | 🔧 | Enable Supabase Dashboard monitoring |

---

## 5. Supabase Edge Functions

| # | Item | Status | Notes |
|---|------|--------|-------|
| 5.1 | `process-activity` function | ✅ | Activity processing pipeline |
| 5.2 | `process-coaching` function | ✅ | Gemini coaching integration |
| 5.3 | Edge function deployment | 🔧 | Deploy via `supabase functions deploy` |

---

## 6. Infrastructure & Deployment

| # | Item | Status | Notes |
|---|------|--------|-------|
| 6.1 | DigitalOcean App Platform | ✅ | App ID: 61e5e2ce-c9d7-4c03-9326-7bbfac8889f9 |
| 6.2 | Docker Compose (local dev) | ✅ | docker-compose.yml |
| 6.3 | Docker Compose (prod) | ✅ | docker-compose.prod.yml |
| 6.4 | Deploy script | ✅ | deploy.sh |
| 6.5 | Droplet setup script | ✅ | setup-droplet.sh |
| 6.6 | Nginx reverse proxy | ✅ | nginx/ directory |
| 6.7 | CI/CD documentation | ✅ | CICD.md |
| 6.8 | Deploy documentation | ✅ | DEPLOY_DIGITALOCEAN.md |
| 6.9 | Production build docs | ✅ | PRODUCTION_BUILD.md |
| 6.10 | Database migration guide | ✅ | DATABASE_MIGRATION_GUIDE.md |
| 6.11 | SSL certificates (HTTPS) | 🔧 | Configure via DO App Platform or Let's Encrypt |
| 6.12 | Custom domain | 🔧 | Not yet configured |
| 6.13 | Environment secrets management | 🔧 | Move secrets to DO App Platform env vars |

---

## 7. Security

| # | Item | Status | Notes |
|---|------|--------|-------|
| 7.1 | JWT authentication | ✅ | ES256 (JWKS) + HS256 |
| 7.2 | Supabase RLS policies | ✅ | Row-level security on all tables |
| 7.3 | CORS restrictions | ✅ | Configured in backend |
| 7.4 | Rate limiting | ✅ | Middleware in main.go |
| 7.5 | Input validation | 🔧 | Add comprehensive request validation |
| 7.6 | SQL injection prevention | ✅ | Parameterized queries via pgx |
| 7.7 | Secrets in .env (not committed) | 🔧 | Ensure .gitignore includes .env |
| 7.8 | HTTPS enforcement | 🔧 | Configure redirect HTTP → HTTPS |
| 7.9 | API key rotation plan | 🔧 | Document rotation procedure |
| 7.10 | Dependency vulnerability scan | 🔧 | Run `go vet`, `flutter pub audit` |

---

## 8. Monitoring & Observability

| # | Item | Status | Notes |
|---|------|--------|-------|
| 8.1 | Health check endpoints | ✅ | Backend + ML service |
| 8.2 | Request logging | ✅ | Backend middleware |
| 8.3 | Error tracking (Sentry/Crashlytics) | 🔧 | Add crash reporting |
| 8.4 | APM / performance monitoring | 🔧 | Add DigitalOcean monitoring or Datadog |
| 8.5 | Uptime monitoring | 🔧 | Configure health check alerts |
| 8.6 | Log aggregation | 🔧 | Configure centralized logging |

---

## 9. Performance

| # | Item | Status | Notes |
|---|------|--------|-------|
| 9.1 | Redis caching for leaderboards | ✅ | Sorted sets |
| 9.2 | PostGIS spatial indexes | ✅ | GIST indexes |
| 9.3 | Impeller rendering for maps | ✅ | 120fps target |
| 9.4 | Background GPS battery optimization | ✅ | Configurable interval (1.5s default) |
| 9.5 | TFLite quantized models | ✅ | float16 + int8 + dynamic range |
| 9.6 | Connection pooling | ✅ | PgBouncer via Supabase |
| 9.7 | Flutter tree shaking (release) | 🔧 | Verify with `--release` build |
| 9.8 | Image/asset optimization | 🔧 | Compress assets for APK size |
| 9.9 | API response caching | 🔧 | Add Redis cache layer for coaching responses |

---

## 10. Pre-Launch Final Steps

| # | Priority | Task | Status |
|---|----------|------|--------|
| 10.1 | P0 | Sign Android APK with production keystore | 🔧 |
| 10.2 | P0 | Configure iOS signing & provisioning | 🔧 |
| 10.3 | P0 | Set all production env vars in DO App Platform | 🔧 |
| 10.4 | P0 | Deploy edge functions to Supabase | 🔧 |
| 10.5 | P0 | Run full integration test suite | 🔧 |
| 10.6 | P0 | Verify all RLS policies with real users | 🔧 |
| 10.7 | P1 | Train ML models with real running data | 🔧 |
| 10.8 | P1 | Add Sentry/Crashlytics for crash reporting | 🔧 |
| 10.9 | P1 | Set up uptime/health monitoring alerts | 🔧 |
| 10.10 | P1 | Configure custom domain + SSL | 🔧 |
| 10.11 | P2 | App Store / Play Store listing assets | 🔧 |
| 10.12 | P2 | Privacy policy & terms of service | 🔧 |
| 10.13 | P2 | Performance load testing | 🔧 |

---

## Summary

| Category | Done | Needs Work | Total |
|----------|------|------------|-------|
| Backend | 16 | 4 | 20 |
| Frontend | 21 | 7 | 28 |
| ML Service | 12 | 3 | 15 |
| Database | 10 | 1 | 11 |
| Edge Functions | 2 | 1 | 3 |
| Infrastructure | 10 | 3 | 13 |
| Security | 5 | 5 | 10 |
| Monitoring | 2 | 4 | 6 |
| Performance | 6 | 3 | 9 |
| Pre-Launch | 0 | 13 | 13 |
| **TOTAL** | **84** | **44** | **128** |

**Production readiness: ~66%** — Core functionality is complete. Remaining items are primarily deployment config, security hardening, monitoring, and app store prep.
