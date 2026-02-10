-- ============================================================
-- ApexRun Database Verification
-- Run this after migration to confirm everything is set up
-- ============================================================

-- Check PostGIS version
SELECT 'PostGIS Version:' as check_name, PostGIS_version() as result
UNION ALL

-- List all created tables
SELECT 'Tables Created:' as check_name,
       string_agg(table_name, ', ' ORDER BY table_name) as result
FROM information_schema.tables
WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
UNION ALL

-- Count spatial indexes (should be 3)
SELECT 'Spatial Indexes:' as check_name,
       COUNT(*)::text as result
FROM pg_indexes
WHERE indexdef LIKE '%USING gist%'
  AND schemaname = 'public'
UNION ALL

-- Check RLS is enabled (should be 5 tables)
SELECT 'RLS Enabled Tables:' as check_name,
       COUNT(*)::text as result
FROM pg_tables
WHERE schemaname = 'public'
  AND rowsecurity = true
UNION ALL

-- Count RLS policies (should be ~12)
SELECT 'RLS Policies:' as check_name,
       COUNT(*)::text as result
FROM pg_policies
WHERE schemaname = 'public';

-- Show table details
SELECT
    table_name,
    (SELECT COUNT(*) FROM information_schema.columns c WHERE c.table_name = t.table_name AND c.table_schema = 'public') as column_count,
    (SELECT COUNT(*) FROM pg_indexes i WHERE i.tablename = t.table_name AND i.schemaname = 'public') as index_count
FROM information_schema.tables t
WHERE t.table_schema = 'public'
  AND t.table_type = 'BASE TABLE'
ORDER BY t.table_name;
