-- ========================================
-- Real-time Subscriptions Test Script
-- ========================================
-- This script tests real-time functionality for all tables in NutritionTrackerV2
-- Run these commands to verify real-time subscriptions are working

-- ========================================
-- Prerequisites Check
-- ========================================

-- Verify that real-time is enabled for all tables
SELECT * FROM check_realtime_status();

-- Expected output:
-- table_name  | realtime_enabled
-- profiles    | t
-- foods       | t
-- food_logs   | t

-- ========================================
-- Test 1: Real-time Publication Status
-- ========================================

-- Check which tables are included in the real-time publication
SELECT
    schemaname,
    tablename,
    pubname
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
ORDER BY tablename;

-- Expected: All three tables (profiles, foods, food_logs) should be listed

-- ========================================
-- Test 2: Real-time Configuration Verification
-- ========================================

-- Check publication configuration
SELECT
    pubname,
    puballtables,
    pubinsert,
    pubupdate,
    pubdelete,
    pubtruncate
FROM pg_publication
WHERE pubname = 'supabase_realtime';

-- Expected: pubinsert, pubupdate, pubdelete should all be true

-- ========================================
-- Test 3: Replication Slot Status
-- ========================================

-- Check replication slots (requires superuser or replication role)
-- This may not work in Supabase hosted environment, but useful for local testing
-- SELECT
--     slot_name,
--     plugin,
--     slot_type,
--     database,
--     active,
--     restart_lsn
-- FROM pg_replication_slots
-- WHERE database = current_database();

-- ========================================
-- Test 4: Simulate Real-time Changes
-- ========================================

-- These operations should trigger real-time events
-- Run each block separately and monitor for real-time events

-- Test 4a: Profile Changes
-- (Replace with actual user ID from your profiles table)
/*
-- Get a test profile ID
SELECT id, username FROM profiles LIMIT 1;

-- Update profile (should trigger real-time event)
UPDATE profiles
SET custom_key = 'realtime_test_' || EXTRACT(EPOCH FROM NOW())::TEXT
WHERE id = 'YOUR_PROFILE_ID_HERE';

-- Insert new profile (should trigger real-time event)
INSERT INTO profiles (id, username, custom_key)
VALUES (
    gen_random_uuid(),
    'realtime_test_user',
    'test_value'
);
*/

-- Test 4b: Food Changes
/*
-- Insert new food (should trigger real-time event)
INSERT INTO foods (name, calories, protein, measurement_unit, serving_size)
VALUES (
    'Realtime Test Food',
    100.0,
    10.0,
    'grams',
    100.0
);

-- Update food (should trigger real-time event)
UPDATE foods
SET calories = calories + 1
WHERE name = 'Realtime Test Food';
*/

-- Test 4c: Food Log Changes
/*
-- Get test IDs
SELECT u.id as user_id, f.id as food_id
FROM profiles u, foods f
WHERE u.username IS NOT NULL
AND f.name IS NOT NULL
LIMIT 1;

-- Insert food log (should trigger real-time event)
INSERT INTO food_logs (user_id, food_id, date, serving_size)
VALUES (
    'YOUR_USER_ID_HERE',
    'YOUR_FOOD_ID_HERE',
    NOW(),
    1.0
);

-- Update food log (should trigger real-time event)
UPDATE food_logs
SET serving_size = serving_size + 0.1
WHERE created_at >= NOW() - INTERVAL '1 minute';
*/

-- ========================================
-- Test 5: Real-time Function Tests
-- ========================================

-- Test real-time with analytics functions
-- These should also trigger events if the underlying data changes

-- Test daily nutrition calculation in real-time context
/*
SELECT * FROM get_daily_nutrition(
    'YOUR_USER_ID_HERE',
    CURRENT_DATE
);
*/

-- Test recent food logs in real-time context
/*
SELECT * FROM get_recent_food_logs(
    'YOUR_USER_ID_HERE',
    1,  -- last 1 day
    5   -- limit 5 results
);
*/

-- ========================================
-- Test 6: Real-time Event Monitoring
-- ========================================

-- Monitor WAL (Write Ahead Log) activity
-- This shows database activity that generates real-time events
SELECT
    pg_current_wal_lsn() as current_wal_location,
    pg_wal_lsn_diff(pg_current_wal_lsn(), '0/0') as wal_bytes;

-- Monitor active connections and subscriptions
-- (May require elevated privileges)
-- SELECT
--     pid,
--     usename,
--     application_name,
--     client_addr,
--     state,
--     query_start,
--     query
-- FROM pg_stat_activity
-- WHERE state = 'active'
-- AND application_name LIKE '%realtime%';

-- ========================================
-- Test 7: Row Level Security with Real-time
-- ========================================

-- Verify RLS policies work with real-time subscriptions
-- These queries should only return data for the authenticated user

-- Test with profiles
-- SET LOCAL rls.check_user_id = 'YOUR_USER_ID_HERE';
-- SELECT * FROM profiles;

-- Test with food_logs
-- SELECT * FROM food_logs WHERE user_id = auth.uid();

-- ========================================
-- Test 8: Performance Impact
-- ========================================

-- Check if real-time subscriptions impact query performance
SELECT * FROM test_query_performance();

-- Monitor table activity
SELECT
    schemaname,
    tablename,
    n_tup_ins as inserts,
    n_tup_upd as updates,
    n_tup_del as deletes,
    n_tup_hot_upd as hot_updates
FROM pg_stat_user_tables
WHERE schemaname = 'public'
ORDER BY tablename;

-- ========================================
-- Cleanup Test Data
-- ========================================

-- Remove test data created during testing
-- DELETE FROM profiles WHERE username = 'realtime_test_user';
-- DELETE FROM foods WHERE name = 'Realtime Test Food';
-- DELETE FROM food_logs WHERE created_at >= NOW() - INTERVAL '1 hour' AND serving_size < 2.0;

-- ========================================
-- Real-time Testing Guidelines
-- ========================================

/*
To properly test real-time subscriptions:

1. Client-side Testing:
   - Use Supabase JavaScript client to subscribe to table changes
   - Monitor for INSERT, UPDATE, DELETE events
   - Verify events are received in real-time

2. iOS App Testing:
   - Use Supabase Swift SDK real-time subscriptions
   - Subscribe to changes in FoodListView, DailyStatsView
   - Test cross-device synchronization

3. Performance Testing:
   - Monitor subscription overhead
   - Test with multiple concurrent subscribers
   - Verify RLS policies filter events correctly

4. Event Verification:
   - Each table operation should generate appropriate events
   - Events should respect RLS policies
   - Events should contain expected data payloads

Example JavaScript subscription test:
```javascript
const subscription = supabase
  .channel('nutrition-tracker')
  .on('postgres_changes', {
    event: '*',
    schema: 'public',
    table: 'food_logs'
  }, (payload) => {
    console.log('Real-time event:', payload)
  })
  .subscribe()
```

Example Swift subscription test:
```swift
let subscription = supabase.realtime
  .channel("nutrition-tracker")
  .on(.insert) { message in
    print("New food log inserted: \(message)")
  }
  .subscribe()
```
*/

-- ========================================
-- Expected Results Summary
-- ========================================

/*
After running this test script, you should verify:

✅ All tables (profiles, foods, food_logs) are in supabase_realtime publication
✅ Real-time publication is configured for INSERT, UPDATE, DELETE
✅ Test operations generate real-time events
✅ RLS policies properly filter real-time events
✅ Query performance remains acceptable with real-time enabled
✅ Client applications can subscribe to and receive events
✅ Cross-device synchronization works correctly

Any failures indicate real-time setup issues that need to be resolved.
*/