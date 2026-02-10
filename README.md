# ApexRun - Performance Running Platform

AI-powered running app with GPS tracking, segment leaderboards, and personalized coaching.

## 🚀 Build Status

| Phase | Description | Status |
|-------|-------------|--------|
| 1 | Core Infrastructure & Database | ✅ Complete |
| 2 | Flutter Presentation Layer | ✅ Complete |
| 3 | Go Backend API | ✅ Complete |
| 4 | Maps, Real-Time GPS & Edge Functions | ⏳ Next |
| 5 | ML/AI — MediaPipe Pose & HRV | 🔜 Planned |
| 6 | Testing, CI/CD & Store Deployment | 🔜 Planned |

---

## Phase 1 — Core Infrastructure

#### Flutter App Architecture
- ✅ Clean architecture (data / domain / presentation layers)
- ✅ Riverpod state management
- ✅ Supabase authentication integration
- ✅ Design system (Dark #0A0A0A, Electric Lime #CCFF00)
- ✅ Navigation with 5 bottom tabs
- ✅ Login / signup screens with email authentication
- ✅ Environment configuration system

#### Database (Supabase + PostGIS)
- ✅ 5 tables: user_profiles, activities, segments, segment_efforts, planned_workouts
- ✅ 14 indexes (including 3 GIST spatial indexes)
- ✅ 12 RLS policies
- ✅ 4 triggers (auto profile creation, counter updates, timestamps)
- ✅ Migrations pushed via Supabase CLI

## Phase 2 — Flutter Screens

All 5 main screens fully implemented with real data bindings:

- ✅ **Home** — weekly stats cards, recent activities, upcoming workouts
- ✅ **Record** — live GPS tracking with pace / distance / elevation metrics
- ✅ **Coach** — Gemini AI coaching with workout generation & insights
- ✅ **Leaderboard** — segment list with proximity filter + leaderboard view
- ✅ **Profile** — profile editing, lifetime stats, preferences, sign out
- ✅ Riverpod providers wiring all screens to data layer

## Phase 3 — Go Backend API

15 Go source files across 7 packages — compiles cleanly:

- ✅ `cmd/api/main.go` — Gin server with CORS, rate limiter, graceful shutdown
- ✅ `internal/config/` — Environment configuration loader
- ✅ `internal/database/` — PostgreSQL pool + Redis client with leaderboard helpers
- ✅ `internal/auth/` — Supabase JWT validation middleware
- ✅ `internal/activities/` — Full CRUD (model + repository + handler)
- ✅ `internal/segments/` — PostGIS spatial queries, leaderboard, segment matching
- ✅ `internal/coaching/` — Daily workout + analysis endpoints
- ✅ `pkg/logger/` — Zap structured logging
- ✅ `pkg/utils/` — GPS calculations (Haversine, WKT, elevation, privacy blur)

## 📋 Next Steps

### 1. Install Go (Required for Backend)

Download and install Go 1.22+:
- Windows: https://go.dev/dl/
- Verify: `go version`

After installing Go:
```bash
cd backend
go mod download  # Install dependencies
```

### 2. Set Up Supabase Project

1. Create account at https://supabase.com
2. Create new project (name it "apexrun")
3. Save credentials:
   - Project URL
   - Anon key (public)
   - Service role key (private)
   - JWT secret

4. Run database migration:
   - Go to Supabase Dashboard → SQL Editor
   - Copy contents of `backend/migrations/001_initial_schema.sql`
   - Paste and run

5. Enable PostGIS:
   ```sql
   CREATE EXTENSION IF NOT EXISTS postgis SCHEMA extensions;
   ```

### 3. Configure Environment Variables

#### Flutter App
Create a run configuration or use dart-defines:
```bash
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key \
  --dart-define=MAPBOX_ACCESS_TOKEN=your-mapbox-token
```

#### Backend API
```bash
cd backend
cp .env.example .env
# Edit .env with your actual credentials
```

### 4. Start Local Redis (Optional for Development)

Using Docker Compose:
```bash
docker-compose up -d
```

Or use Memurai (Windows) / Redis (Linux/Mac)

### 5. Run the App

#### Start Backend (once Go is installed):
```bash
cd backend
go run cmd/api/main.go
```

#### Start Flutter App:
```bash
flutter run --dart-define=SUPABASE_URL=xxx --dart-define=SUPABASE_ANON_KEY=xxx
```

## 🏗️ Project Structure

```
apex_run/
├── lib/                          # Flutter app
│   ├── core/
│   │   ├── config/              # Environment config
│   │   ├── theme/               # Design system
│   │   └── network/             # API clients
│   ├── data/
│   │   ├── datasources/         # Supabase, local storage
│   │   ├── repositories/        # Repo implementations
│   │   └── models/              # Data models
│   ├── domain/
│   │   ├── entities/            # Business entities
│   │   ├── repositories/        # Repo interfaces
│   │   └── usecases/            # Business logic
│   └── presentation/
│       ├── screens/             # UI screens
│       ├── providers/           # Riverpod providers
│       └── widgets/             # Reusable widgets
│
├── backend/                      # Go API
│   ├── cmd/api/                 # Main entry point
│   ├── internal/                # Business logic
│   ├── pkg/                     # Shared utilities
│   ├── migrations/              # SQL migrations
│   └── .env.example             # Config template
│
├── docker-compose.yml           # Local Redis setup
└── pubspec.yaml                 # Flutter dependencies
```

## 🎨 Design System

- **Background**: #0A0A0A (near black)
- **Primary**: #CCFF00 (electric lime)
- **Card Background**: #1A1A1A
- **Text Primary**: White
- **Text Secondary**: #B0B0B0

## 🔐 Authentication

Currently implemented:
- ✅ Email/password sign up
- ✅ Email/password sign in
- ✅ Sign out
- ⏳ Google Sign In (placeholder)
- ⏳ Apple Sign In (placeholder)

## 📱 Features Status

| Feature | Status | Phase |
|---------|--------|-------|
| Authentication (email/password) | ✅ Complete | 1 |
| Navigation (5-tab bottom nav) | ✅ Complete | 1 |
| Design System (dark mode) | ✅ Complete | 1 |
| Database Schema (PostGIS) | ✅ Complete | 1 |
| Foreground GPS Tracking | ✅ Complete | 2 |
| Activity CRUD (screens + API) | ✅ Complete | 2-3 |
| Segment Matching (PostGIS) | ✅ Complete | 3 |
| AI Coaching (client-side Gemini) | ✅ Complete | 2 |
| Leaderboards (Redis + UI) | ✅ Complete | 2-3 |
| Backend API (Go/Gin) | ✅ Complete | 3 |
| Mapbox Route Visualization | ✅ Complete | 4 |
| Background GPS (OS Doze) | ✅ Complete | 4 |
| Gemini Edge Function (server-side) | ✅ Complete | 4 |
| Privacy Shroud Integration | ✅ Complete | 4 |
| Activity Detail Screen | ✅ Complete | 4 |
| MediaPipe Pose Estimation | 🔜 Phase 5 | 5 |
| HRV / Sleep Data Integration | 🔜 Phase 5 | 5 |
| Social Auth (Google, Apple) | 🔜 Phase 6 | 6 |
| Deep Linking & Route Sharing | 🔜 Phase 6 | 6 |
| Push Notifications | 🔜 Phase 6 | 6 |
| Unit & Integration Tests | 🔜 Phase 6 | 6 |
| CI/CD Pipeline | 🔜 Phase 6 | 6 |

## 🧪 Testing the Setup

1. **Run Flutter app** (even without Supabase configured):
   ```bash
   flutter run
   ```
   - You should see a configuration error screen with instructions

2. **Configure Supabase and test auth**:
   - Add dart-defines with real Supabase credentials
   - App should show login screen
   - Sign up with email/password
   - You should be redirected to the Home screen

3. **Verify database**:
   - Check Supabase dashboard → Authentication → Users
   - Your test user should appear
   - Check "user_profiles" table for profile entry

## 📚 Additional Resources

- **Flutter Documentation**: `/lib` folder with clean architecture
- **Backend Documentation**: `/backend/README.md`
- **Database Schema**: `/backend/migrations/001_initial_schema.sql`
- **Design Spec**: `APEXRUN_APP_SPEC.md`

## 🐛 Troubleshooting

### "SUPABASE_URL not configured"
- Run with `--dart-define=SUPABASE_URL=...` flags
- Or update `lib/core/config/env.dart` to use a config file

### "Go command not found"
- Install Go from https://go.dev/dl/
- Add Go to your PATH
- Restart terminal

### "Redis connection failed"
- Start Redis: `docker-compose up -d`
- Or install Memurai (Windows) / Redis (Linux/Mac)
- Backend will still work without Redis (with warnings)

## 🎯 Phase 4 — Maps, Real-Time GPS & Edge Functions

The next phase focuses on the core running experience:

### 4a. Mapbox Route Visualization
- Integrate `mapbox_maps_flutter` (already in pubspec) into Record screen
- Live route drawing during GPS tracking (polyline overlay)
- Activity detail screen with full route map replay
- Route preview thumbnails on Home screen activity cards
- 120fps rendering target with Impeller engine

### 4b. Background GPS Tracking
- Add `flutter_background_geolocation` to survive OS Doze mode
- Upgrade `GpsTrackingService` from foreground-only `geolocator` to background-capable
- Battery-efficient 1-2 second ping intervals
- WKT LINESTRING conversion before Supabase upsert

### 4c. Supabase Edge Function — Gemini Coaching
- Create `supabase/functions/process-coaching/` Edge Function
- Move Gemini 1.5 Flash API calls server-side (eliminates API key exposure on client)
- Input: `current_hrv`, `last_7_days_load`
- Output: JSON training plan adjustment
- Update `CoachingDataSource` to call Edge Function instead of client-side Gemini

### 4d. Privacy Shroud Integration
- Wire existing `blurNearHome()` (in `gps_utils.dart`) into activity save pipeline
- Blur first/last 200m of routes near user's `home_location`
- Apply blur before WKT upload to Supabase

### 4e. Activity Detail Screen
- New screen with full-screen Mapbox map showing completed route
- Pace / elevation / heart-rate charts overlaid on timeline
- Segment effort highlights on the route
- Share route as image or deep link

## 🔮 Phase 5 — ML/AI (MediaPipe & HRV)

- Create `lib/ml/` directory for on-device ML
- MediaPipe pose estimation (33 body landmarks) via camera
- Ground Contact Time & Vertical Oscillation calculation
- Form analysis data stored in `activities.form_analysis_data`
- HRV / Sleep data integration for coaching recalibration
- `ml-service/` Python FastAPI scaffold for custom model serving

## 🚢 Phase 6 — Testing, CI/CD & Deployment

- Unit tests for Go backend (repository, handler, middleware)
- Widget tests for Flutter screens
- Integration tests for auth flow and activity CRUD
- GitHub Actions CI/CD pipeline
- Social auth (Google Sign-In, Apple Sign-In)
- Deep linking & route sharing
- Push notifications (workout reminders)
- Fastlane for App Store / Play Store deployment

## 📞 Support

For issues or questions:
- Check `APEXRUN_APP_SPEC.md` for original requirements
- Review `/backend/README.md` for API details
- Check Flutter console for detailed error messages

---

**Built with**: Flutter 3.19+ | Go 1.22+ | Supabase | PostGIS | Redis | Gemini AI
