-- ========================================
-- Food Logs Table Test Data
-- ========================================
-- This script inserts sample food log data for testing the food_logs table
-- Prerequisites: profiles and foods tables must exist with test data

-- ========================================
-- Test Food Logs Data
-- ========================================
-- Note: Replace the UUIDs below with actual IDs from your profiles and foods tables

-- Sample variables (replace with actual UUIDs from your database)
-- To get actual UUIDs, run these queries:
-- SELECT id, username FROM profiles LIMIT 3;
-- SELECT id, name FROM foods LIMIT 6;

-- ========================================
-- Helper to Insert Test Logs
-- ========================================
-- This approach uses subqueries to reference existing test data

-- Food Log 1: User had chicken breast for lunch yesterday
INSERT INTO food_logs (user_id, food_id, date, serving_size)
SELECT
    p.id as user_id,
    f.id as food_id,
    (CURRENT_DATE - INTERVAL '1 day' + TIME '12:30:00') as date,
    1.5 as serving_size
FROM profiles p, foods f
WHERE p.username IS NOT NULL  -- Get any test user
AND f.name ILIKE '%chicken%breast%'
LIMIT 1;

-- Food Log 2: Same user had brown rice with lunch yesterday
INSERT INTO food_logs (user_id, food_id, date, serving_size)
SELECT
    p.id as user_id,
    f.id as food_id,
    (CURRENT_DATE - INTERVAL '1 day' + TIME '12:35:00') as date,
    1.0 as serving_size
FROM profiles p, foods f
WHERE p.username IS NOT NULL  -- Get same test user
AND f.name ILIKE '%brown%rice%'
LIMIT 1;

-- Food Log 3: User had banana for breakfast today
INSERT INTO food_logs (user_id, food_id, date, serving_size)
SELECT
    p.id as user_id,
    f.id as food_id,
    (CURRENT_DATE + TIME '08:15:00') as date,
    1.0 as serving_size
FROM profiles p, foods f
WHERE p.username IS NOT NULL  -- Get same test user
AND f.name ILIKE '%banana%'
LIMIT 1;

-- Food Log 4: User had spinach salad for lunch today
INSERT INTO food_logs (user_id, food_id, date, serving_size)
SELECT
    p.id as user_id,
    f.id as food_id,
    (CURRENT_DATE + TIME '13:00:00') as date,
    2.0 as serving_size
FROM profiles p, foods f
WHERE p.username IS NOT NULL  -- Get same test user
AND f.name ILIKE '%spinach%'
LIMIT 1;

-- Food Log 5: User had salmon for dinner today
INSERT INTO food_logs (user_id, food_id, date, serving_size)
SELECT
    p.id as user_id,
    f.id as food_id,
    (CURRENT_DATE + TIME '19:30:00') as date,
    1.2 as serving_size
FROM profiles p, foods f
WHERE p.username IS NOT NULL  -- Get same test user
AND f.name ILIKE '%salmon%'
LIMIT 1;

-- Food Log 6: User had apple for snack this afternoon
INSERT INTO food_logs (user_id, food_id, date, serving_size)
SELECT
    p.id as user_id,
    f.id as food_id,
    (CURRENT_DATE + TIME '15:45:00') as date,
    1.0 as serving_size
FROM profiles p, foods f
WHERE p.username IS NOT NULL  -- Get same test user
AND f.name ILIKE '%apple%'
LIMIT 1;

-- ========================================
-- Alternative: Manual Insert with Explicit UUIDs
-- ========================================
-- Uncomment and modify these if you want to use specific UUIDs

-- INSERT INTO food_logs (user_id, food_id, date, serving_size) VALUES
-- ('550e8400-e29b-41d4-a716-446655440000', '123e4567-e89b-12d3-a456-426614174000', CURRENT_DATE + TIME '08:00:00', 1.0),
-- ('550e8400-e29b-41d4-a716-446655440000', '123e4567-e89b-12d3-a456-426614174001', CURRENT_DATE + TIME '12:30:00', 1.5),
-- ('550e8400-e29b-41d4-a716-446655440000', '123e4567-e89b-12d3-a456-426614174002', CURRENT_DATE + TIME '19:00:00', 1.2);

-- ========================================
-- Test Queries and Validation
-- ========================================

-- Query to verify inserted food logs
-- SELECT
--     fl.id,
--     p.username,
--     f.name as food_name,
--     fl.date,
--     fl.serving_size,
--     fl.created_at
-- FROM food_logs fl
-- JOIN profiles p ON fl.user_id = p.id
-- JOIN foods f ON fl.food_id = f.id
-- ORDER BY fl.date DESC;

-- Query to test daily nutrition calculation
-- SELECT * FROM get_daily_nutrition(
--     (SELECT id FROM profiles WHERE username IS NOT NULL LIMIT 1),
--     CURRENT_DATE
-- );

-- Query to test recent food logs function
-- SELECT * FROM get_recent_food_logs(
--     (SELECT id FROM profiles WHERE username IS NOT NULL LIMIT 1),
--     7,  -- last 7 days
--     20  -- limit 20 results
-- );

-- Query to test nutrition totals by date
-- SELECT
--     DATE(fl.date) as log_date,
--     SUM(fl.serving_size * f.calories) as total_calories,
--     SUM(fl.serving_size * f.protein) as total_protein,
--     COUNT(*) as food_count
-- FROM food_logs fl
-- JOIN foods f ON fl.food_id = f.id
-- WHERE fl.date >= CURRENT_DATE - INTERVAL '7 days'
-- GROUP BY DATE(fl.date)
-- ORDER BY log_date DESC;

-- Query to test user-specific data isolation (RLS)
-- This should only return logs for the authenticated user
-- SELECT COUNT(*) as my_logs FROM food_logs;

-- ========================================
-- Data Validation Tests
-- ========================================

-- Check foreign key constraints are working
-- SELECT
--     COUNT(*) as total_logs,
--     COUNT(DISTINCT user_id) as unique_users,
--     COUNT(DISTINCT food_id) as unique_foods
-- FROM food_logs;

-- Verify serving sizes are positive
-- SELECT COUNT(*) as invalid_servings
-- FROM food_logs
-- WHERE serving_size IS NOT NULL AND serving_size <= 0;

-- Check date constraints
-- SELECT COUNT(*) as future_dates
-- FROM food_logs
-- WHERE date > NOW() + INTERVAL '1 day';

-- Verify all logs have valid foreign keys
-- SELECT
--     (SELECT COUNT(*) FROM food_logs WHERE user_id NOT IN (SELECT id FROM profiles)) as orphaned_users,
--     (SELECT COUNT(*) FROM food_logs WHERE food_id NOT IN (SELECT id FROM foods)) as orphaned_foods;

-- ========================================
-- Performance Test Queries
-- ========================================

-- Test index performance on user queries
-- EXPLAIN (ANALYZE, BUFFERS)
-- SELECT * FROM food_logs
-- WHERE user_id = (SELECT id FROM profiles LIMIT 1)
-- AND date >= CURRENT_DATE - INTERVAL '30 days';

-- Test index performance on date range queries
-- EXPLAIN (ANALYZE, BUFFERS)
-- SELECT fl.*, f.name
-- FROM food_logs fl
-- JOIN foods f ON fl.food_id = f.id
-- WHERE DATE(fl.date) = CURRENT_DATE;

-- ========================================
-- Cleanup (Optional)
-- ========================================
-- Uncomment to remove test data:
-- DELETE FROM food_logs WHERE created_at >= CURRENT_DATE;