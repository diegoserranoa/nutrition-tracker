-- ========================================
-- Database Optimization Script
-- ========================================
-- This script adds final performance optimizations, monitoring capabilities,
-- and database-wide configurations for NutritionTrackerV2

-- ========================================
-- Additional Performance Indexes
-- ========================================

-- Cross-table indexes for complex queries

-- Index for joining food_logs with foods for nutrition calculations
-- (Already handled by individual foreign key indexes, but adding composite for optimization)
CREATE INDEX IF NOT EXISTS idx_food_logs_join_optimization
ON food_logs(food_id, user_id, date DESC);

-- Index for username lookups in profiles (case-insensitive)
CREATE INDEX IF NOT EXISTS idx_profiles_username_lower
ON profiles(LOWER(username));

-- Partial index for foods with photos only
CREATE INDEX IF NOT EXISTS idx_foods_with_photos
ON foods(id) WHERE photo_url IS NOT NULL;

-- Partial index for recent food logs (last 90 days)
CREATE INDEX IF NOT EXISTS idx_food_logs_recent
ON food_logs(user_id, date DESC)
WHERE date >= NOW() - INTERVAL '90 days';

-- ========================================
-- Advanced Database Constraints
-- ========================================

-- Create immutable function for case-insensitive username comparison
CREATE OR REPLACE FUNCTION lower_immutable(text) RETURNS text AS $$
    SELECT lower($1);
$$ LANGUAGE sql IMMUTABLE;

-- Ensure username uniqueness is case-insensitive
CREATE UNIQUE INDEX IF NOT EXISTS idx_profiles_username_unique_lower
ON profiles(lower_immutable(username))
WHERE username IS NOT NULL;

-- Add constraint to prevent duplicate food logs (same user, food, exact timestamp)
-- This helps prevent accidental double-logging
CREATE UNIQUE INDEX IF NOT EXISTS idx_food_logs_duplicate_prevention
ON food_logs(user_id, food_id, date)
WHERE date IS NOT NULL;

-- ========================================
-- Database-wide Performance Settings
-- ========================================

-- Optimize for read-heavy workload (nutrition tracking apps are mostly reads)
-- Note: These settings may require superuser privileges

-- Set up statistics for better query planning
ALTER TABLE profiles ALTER COLUMN username SET STATISTICS 1000;
ALTER TABLE foods ALTER COLUMN name SET STATISTICS 1000;
ALTER TABLE food_logs ALTER COLUMN date SET STATISTICS 1000;

-- ========================================
-- Monitoring and Analytics Views
-- ========================================

-- View for database performance monitoring
CREATE OR REPLACE VIEW database_performance AS
SELECT
    schemaname,
    tablename,
    attname as column_name,
    n_distinct,
    correlation,
    most_common_vals::text as most_common_vals_text,
    most_common_freqs::text as most_common_freqs_text
FROM pg_stats
WHERE schemaname = 'public'
AND tablename IN ('profiles', 'foods', 'food_logs')
ORDER BY tablename, attname;

-- View for index usage statistics
CREATE OR REPLACE VIEW index_usage_stats AS
SELECT
    sui.schemaname,
    sui.relname as tablename,
    sui.indexrelname as indexname,
    sui.idx_tup_read,
    sui.idx_tup_fetch,
    sui.idx_scan,
    CASE
        WHEN sui.idx_scan = 0 THEN 'UNUSED'
        WHEN sui.idx_scan < 100 THEN 'LOW_USAGE'
        WHEN sui.idx_scan < 1000 THEN 'MEDIUM_USAGE'
        ELSE 'HIGH_USAGE'
    END as usage_level
FROM pg_stat_user_indexes sui
WHERE sui.schemaname = 'public'
ORDER BY sui.idx_scan DESC;

-- View for table size monitoring
CREATE OR REPLACE VIEW table_sizes AS
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as total_size,
    pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) as table_size,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename)) as index_size,
    pg_stat_get_tuples_returned(c.oid) as rows_read,
    pg_stat_get_tuples_fetched(c.oid) as rows_fetched,
    pg_stat_get_tuples_inserted(c.oid) as rows_inserted,
    pg_stat_get_tuples_updated(c.oid) as rows_updated,
    pg_stat_get_tuples_deleted(c.oid) as rows_deleted
FROM pg_tables t
JOIN pg_class c ON c.relname = t.tablename
WHERE t.schemaname = 'public'
AND t.tablename IN ('profiles', 'foods', 'food_logs')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- View for nutrition tracking analytics
CREATE OR REPLACE VIEW nutrition_analytics AS
SELECT
    COUNT(DISTINCT fl.user_id) as active_users,
    COUNT(fl.id) as total_logs,
    COUNT(DISTINCT fl.food_id) as unique_foods_logged,
    AVG(fl.serving_size) as avg_serving_size,
    DATE_TRUNC('day', fl.date) as log_date,
    SUM(CASE WHEN f.calories IS NOT NULL AND fl.serving_size IS NOT NULL
        THEN fl.serving_size * f.calories ELSE 0 END) as total_calories,
    AVG(CASE WHEN f.calories IS NOT NULL AND fl.serving_size IS NOT NULL
        THEN fl.serving_size * f.calories ELSE NULL END) as avg_calories_per_log
FROM food_logs fl
JOIN foods f ON fl.food_id = f.id
WHERE fl.date >= NOW() - INTERVAL '30 days'
GROUP BY DATE_TRUNC('day', fl.date)
ORDER BY log_date DESC;

-- ========================================
-- Database Maintenance Functions
-- ========================================

-- Function to analyze table statistics
CREATE OR REPLACE FUNCTION analyze_nutrition_tables()
RETURNS TEXT AS $$
BEGIN
    ANALYZE profiles;
    ANALYZE foods;
    ANALYZE food_logs;

    RETURN 'Table statistics updated for profiles, foods, and food_logs';
END;
$$ LANGUAGE plpgsql;

-- Function to get database health summary
CREATE OR REPLACE FUNCTION get_database_health()
RETURNS TABLE(
    metric TEXT,
    value TEXT,
    status TEXT
) AS $$
BEGIN
    RETURN QUERY
    WITH health_metrics AS (
        SELECT 'Total Users' as metric, COUNT(*)::TEXT as value,
               CASE WHEN COUNT(*) > 0 THEN 'OK' ELSE 'WARNING' END as status
        FROM profiles
        UNION ALL
        SELECT 'Total Foods', COUNT(*)::TEXT,
               CASE WHEN COUNT(*) > 0 THEN 'OK' ELSE 'WARNING' END
        FROM foods
        UNION ALL
        SELECT 'Total Food Logs', COUNT(*)::TEXT,
               CASE WHEN COUNT(*) > 0 THEN 'OK' ELSE 'WARNING' END
        FROM food_logs
        UNION ALL
        SELECT 'Active Users (7 days)', COUNT(DISTINCT user_id)::TEXT,
               CASE WHEN COUNT(DISTINCT user_id) > 0 THEN 'OK' ELSE 'INFO' END
        FROM food_logs
        WHERE date >= NOW() - INTERVAL '7 days'
        UNION ALL
        SELECT 'Average Logs per User per Day',
               ROUND(COUNT(*)::NUMERIC / GREATEST(COUNT(DISTINCT user_id), 1) / 7, 2)::TEXT,
               'INFO'
        FROM food_logs
        WHERE date >= NOW() - INTERVAL '7 days'
    )
    SELECT * FROM health_metrics;
END;
$$ LANGUAGE plpgsql;

-- ========================================
-- Real-time Subscription Verification
-- ========================================

-- Function to check real-time subscription status
CREATE OR REPLACE FUNCTION check_realtime_status()
RETURNS TABLE(
    table_name TEXT,
    realtime_enabled BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        t.table_name::TEXT,
        EXISTS(
            SELECT 1 FROM pg_publication_tables pt
            WHERE pt.pubname = 'supabase_realtime'
            AND pt.tablename = t.table_name
        ) as realtime_enabled
    FROM (
        VALUES ('profiles'), ('foods'), ('food_logs')
    ) AS t(table_name);
END;
$$ LANGUAGE plpgsql;

-- ========================================
-- Query Performance Testing
-- ========================================

-- Function to test common query performance
CREATE OR REPLACE FUNCTION test_query_performance()
RETURNS TABLE(
    query_name TEXT,
    execution_time_ms NUMERIC,
    status TEXT
) AS $$
DECLARE
    start_time TIMESTAMP;
    end_time TIMESTAMP;
    test_user_id UUID;
BEGIN
    -- Get a test user ID
    SELECT id INTO test_user_id FROM profiles LIMIT 1;

    IF test_user_id IS NULL THEN
        RETURN QUERY SELECT 'No test data available'::TEXT, 0::NUMERIC, 'SKIP'::TEXT;
        RETURN;
    END IF;

    -- Test 1: User's food logs for today
    start_time := clock_timestamp();
    PERFORM COUNT(*) FROM food_logs
    WHERE user_id = test_user_id AND DATE(date) = CURRENT_DATE;
    end_time := clock_timestamp();

    RETURN QUERY SELECT
        'Daily food logs query'::TEXT,
        EXTRACT(MILLISECONDS FROM (end_time - start_time))::NUMERIC,
        CASE WHEN EXTRACT(MILLISECONDS FROM (end_time - start_time)) < 100
             THEN 'GOOD' ELSE 'SLOW' END::TEXT;

    -- Test 2: Food search query
    start_time := clock_timestamp();
    PERFORM * FROM search_foods('chicken') LIMIT 10;
    end_time := clock_timestamp();

    RETURN QUERY SELECT
        'Food search query'::TEXT,
        EXTRACT(MILLISECONDS FROM (end_time - start_time))::NUMERIC,
        CASE WHEN EXTRACT(MILLISECONDS FROM (end_time - start_time)) < 200
             THEN 'GOOD' ELSE 'SLOW' END::TEXT;

    -- Test 3: Daily nutrition calculation
    start_time := clock_timestamp();
    PERFORM * FROM get_daily_nutrition(test_user_id, CURRENT_DATE);
    end_time := clock_timestamp();

    RETURN QUERY SELECT
        'Daily nutrition calculation'::TEXT,
        EXTRACT(MILLISECONDS FROM (end_time - start_time))::NUMERIC,
        CASE WHEN EXTRACT(MILLISECONDS FROM (end_time - start_time)) < 300
             THEN 'GOOD' ELSE 'SLOW' END::TEXT;
END;
$$ LANGUAGE plpgsql;

-- ========================================
-- Comments for Documentation
-- ========================================

COMMENT ON VIEW database_performance IS 'Monitor query planner statistics for optimization';
COMMENT ON VIEW index_usage_stats IS 'Track index usage to identify unused or underused indexes';
COMMENT ON VIEW table_sizes IS 'Monitor table and index sizes for capacity planning';
COMMENT ON VIEW nutrition_analytics IS 'High-level nutrition tracking analytics for the last 30 days';

COMMENT ON FUNCTION analyze_nutrition_tables() IS 'Update table statistics for better query planning';
COMMENT ON FUNCTION get_database_health() IS 'Get overview of database health and usage metrics';
COMMENT ON FUNCTION check_realtime_status() IS 'Verify real-time subscriptions are properly configured';
COMMENT ON FUNCTION test_query_performance() IS 'Test performance of common queries and identify slow operations';

-- ========================================
-- Final Optimizations
-- ========================================

-- Update table statistics for optimal query planning
-- Note: This will be called after views are created
-- SELECT analyze_nutrition_tables();

-- Vacuum analyze for better performance (optional, can be run manually)
-- VACUUM ANALYZE profiles;
-- VACUUM ANALYZE foods;
-- VACUUM ANALYZE food_logs;

-- ========================================
-- Post-Setup Analysis
-- ========================================
-- Update table statistics now that all objects are created
SELECT analyze_nutrition_tables();

-- ========================================
-- Verification Queries
-- ========================================
-- Run these to verify optimizations:

-- Check index usage
-- SELECT * FROM index_usage_stats;

-- Check table sizes
-- SELECT * FROM table_sizes;

-- Check database health
-- SELECT * FROM get_database_health();

-- Check real-time status
-- SELECT * FROM check_realtime_status();

-- Test query performance
-- SELECT * FROM test_query_performance();