# ApexRun Database Migration Guide

## ✅ Quick Migration Steps

### 1. Open Supabase SQL Editor
Go to: **https://app.supabase.com/project/voddddmmiarnbvwmgzgo/sql/new**

### 2. Copy & Run Migration SQL

Open the file: **`backend/migrations/MIGRATE_TO_SUPABASE.sql`**

Copy the ENTIRE file contents and paste into Supabase SQL Editor, then click **RUN**.

**What this creates:**
- ✅ PostGIS extension (for GPS data)
- ✅ 5 tables (user_profiles, activities, segments, segment_efforts, planned_workouts)
- ✅ 8 indexes (3 spatial GIST indexes + 5 standard indexes)
- ✅ Row Level Security (RLS) on all tables
- ✅ 12 security policies
- ✅ 4 auto-update triggers

### 3. Verify Migration

After running the migration, run this verification query:

```sql
-- Quick verification
SELECT table_name FROM information_schema.tables
WHERE table_schema='public'
ORDER BY table_name;
```

**Expected output (5 tables):**
- activities
- planned_workouts
- segment_efforts
- segments
- user_profiles

### 4. Test from Flutter App

Run the Flutter app with your Supabase credentials:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://voddddmmiarnbvwmgzgo.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGc...
```

Once the app loads:
1. Sign up with a test email
2. Tap the **beaker icon** (🧪) in the Home screen top-right
3. Click **"Run Tests"**
4. You should see ✅ for all 5 tables

---

## 📊 What Was Created

### Tables

| Table | Purpose | Key Features |
|-------|---------|--------------|
| **user_profiles** | User data & preferences | Home location (Point), privacy settings |
| **activities** | GPS tracked runs | Route (LineString), metrics, heart rate |
| **segments** | Competition routes | Fixed paths (LineString), verified flag |
| **segment_efforts** | Leaderboard entries | Times, rankings per segment |
| **planned_workouts** | AI coach workouts | Workout types, completion tracking |

### Indexes Created

**Spatial Indexes (GIST):**
- `idx_activities_route` - Fast GPS route queries
- `idx_segments_path` - Fast segment matching
- `idx_user_home_location` - Privacy radius calculations

**Standard Indexes:**
- `idx_activities_user_id` - User activity timeline
- `idx_activities_recent` - Public activity feed
- `idx_segment_efforts_leaderboard` - Segment rankings
- `idx_segment_efforts_user` - User personal bests
- `idx_planned_workouts_user_date` - Training calendar

### Security (RLS Policies)

All tables have Row Level Security enabled with policies:
- Users can only modify their own data
- Public activities visible to all
- Private activities only visible to owner
- Segments are public (anyone can view)
- Leaderboards are public

---

## 🧪 Testing Database Connection

### Option 1: Use Built-in Test Screen

1. Run the app
2. Sign in
3. Tap the beaker icon (🧪) in Home screen
4. Click "Run Tests"

### Option 2: Manual SQL Test

In Supabase SQL Editor, run:

```sql
-- Test PostGIS
SELECT PostGIS_version();

-- Test RLS
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public';

-- Count policies
SELECT COUNT(*) as total_policies
FROM pg_policies
WHERE schemaname = 'public';
```

---

## ⚠️ Troubleshooting

### Error: "relation does not exist"
**Solution**: Re-run the migration SQL script

### Error: "permission denied"
**Solution**: Make sure you're using the SQL Editor in Supabase Dashboard (not psql)

### Error: "PostGIS extension not found"
**Solution**: Run this first:
```sql
CREATE EXTENSION IF NOT EXISTS postgis SCHEMA extensions;
```

### Flutter app shows "Table not found"
**Solution**:
1. Check migration ran successfully in Supabase
2. Verify your .env has correct SUPABASE_URL
3. Re-run the app with dart-defines

---

## 📁 Migration Files Reference

- **`backend/migrations/MIGRATE_TO_SUPABASE.sql`** - Complete migration
- **`backend/migrations/VERIFY_MIGRATION.sql`** - Verification queries
- **`backend/migrations/001_initial_schema.sql`** - Original schema (same content)

---

## ✅ Success Checklist

- [ ] PostGIS extension enabled
- [ ] 5 tables created in Supabase
- [ ] 8 indexes created
- [ ] RLS enabled on all tables
- [ ] User can sign up via Flutter app
- [ ] Database test screen shows all ✅

---

**🎉 Once complete, your database is ready for Phase 2: GPS tracking & activity recording!**
