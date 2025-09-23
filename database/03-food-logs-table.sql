-- ========================================
-- Food Logs Table Creation Script
-- ========================================
-- This script creates the food_logs table that records user food consumption
-- with proper foreign key relationships to profiles and foods tables

-- Create food_logs table
CREATE TABLE IF NOT EXISTS food_logs (
    -- Primary key
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,

    -- Foreign key relationships
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    food_id UUID NOT NULL REFERENCES foods(id) ON DELETE CASCADE,

    -- Core log information
    date TIMESTAMPTZ NOT NULL,
    serving_size DOUBLE PRECISION,

    -- Photo storage (Supabase Storage URL)
    photo_url TEXT,

    -- Timestamps for tracking
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- ========================================
-- Constraints and Validation
-- ========================================

-- Ensure serving size is positive when provided
ALTER TABLE food_logs ADD CONSTRAINT check_serving_size_positive
    CHECK (serving_size IS NULL OR serving_size > 0);

-- Ensure date is not in the future (with some tolerance for timezone differences)
ALTER TABLE food_logs ADD CONSTRAINT check_date_not_future
    CHECK (date <= NOW() + INTERVAL '1 day');

-- Ensure date is not too far in the past (reasonable bounds)
ALTER TABLE food_logs ADD CONSTRAINT check_date_not_too_old
    CHECK (date >= '2020-01-01'::date);

-- ========================================
-- Indexes for Performance
-- ========================================

-- Index on user_id for user-specific queries (most common)
CREATE INDEX IF NOT EXISTS idx_food_logs_user_id ON food_logs(user_id);

-- Index on date for daily/weekly/monthly aggregations
CREATE INDEX IF NOT EXISTS idx_food_logs_date ON food_logs(date);

-- Composite index on user_id and date (optimal for daily stats queries)
CREATE INDEX IF NOT EXISTS idx_food_logs_user_date ON food_logs(user_id, date);

-- Index on food_id for food popularity queries
CREATE INDEX IF NOT EXISTS idx_food_logs_food_id ON food_logs(food_id);

-- Index on created_at for recent activity
CREATE INDEX IF NOT EXISTS idx_food_logs_created_at ON food_logs(created_at);

-- Composite index for date range queries per user
CREATE INDEX IF NOT EXISTS idx_food_logs_user_date_range ON food_logs(user_id, date DESC);

-- ========================================
-- Automatic Timestamps Function
-- ========================================

-- Reuse the function from previous tables or create if it doesn't exist
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger to call the function before any UPDATE
CREATE TRIGGER update_food_logs_updated_at
    BEFORE UPDATE ON food_logs
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ========================================
-- Row Level Security (RLS)
-- ========================================

-- Enable RLS on food_logs table
ALTER TABLE food_logs ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their own food logs only
CREATE POLICY "Users can view own food logs"
ON food_logs FOR SELECT
USING (auth.uid() = user_id);

-- Policy: Users can insert their own food logs
CREATE POLICY "Users can insert own food logs"
ON food_logs FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own food logs
CREATE POLICY "Users can update own food logs"
ON food_logs FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Policy: Users can delete their own food logs
CREATE POLICY "Users can delete own food logs"
ON food_logs FOR DELETE
USING (auth.uid() = user_id);

-- ========================================
-- Helper Functions for Analytics
-- ========================================

-- Function to get daily nutrition totals for a user
CREATE OR REPLACE FUNCTION get_daily_nutrition(
    target_user_id UUID,
    target_date DATE
)
RETURNS TABLE(
    total_calories DOUBLE PRECISION,
    total_protein DOUBLE PRECISION,
    total_fat DOUBLE PRECISION,
    total_carbohydrate DOUBLE PRECISION,
    total_fiber DOUBLE PRECISION,
    total_sodium DOUBLE PRECISION,
    log_count INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(SUM(
            CASE
                WHEN fl.serving_size IS NOT NULL AND f.calories IS NOT NULL
                THEN fl.serving_size * f.calories
                ELSE 0
            END
        ), 0) as total_calories,
        COALESCE(SUM(
            CASE
                WHEN fl.serving_size IS NOT NULL AND f.protein IS NOT NULL
                THEN fl.serving_size * f.protein
                ELSE 0
            END
        ), 0) as total_protein,
        COALESCE(SUM(
            CASE
                WHEN fl.serving_size IS NOT NULL AND f.total_fat IS NOT NULL
                THEN fl.serving_size * f.total_fat
                ELSE 0
            END
        ), 0) as total_fat,
        COALESCE(SUM(
            CASE
                WHEN fl.serving_size IS NOT NULL AND f.total_carbohydrate IS NOT NULL
                THEN fl.serving_size * f.total_carbohydrate
                ELSE 0
            END
        ), 0) as total_carbohydrate,
        COALESCE(SUM(
            CASE
                WHEN fl.serving_size IS NOT NULL AND f.dietary_fiber IS NOT NULL
                THEN fl.serving_size * f.dietary_fiber
                ELSE 0
            END
        ), 0) as total_fiber,
        COALESCE(SUM(
            CASE
                WHEN fl.serving_size IS NOT NULL AND f.sodium IS NOT NULL
                THEN fl.serving_size * f.sodium
                ELSE 0
            END
        ), 0) as total_sodium,
        COUNT(*)::INTEGER as log_count
    FROM food_logs fl
    JOIN foods f ON fl.food_id = f.id
    WHERE fl.user_id = target_user_id
    AND DATE(fl.date) = target_date;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get user's recent food logs with nutrition info
CREATE OR REPLACE FUNCTION get_recent_food_logs(
    target_user_id UUID,
    days_back INTEGER DEFAULT 7,
    log_limit INTEGER DEFAULT 50
)
RETURNS TABLE(
    log_id UUID,
    food_name TEXT,
    serving_size DOUBLE PRECISION,
    log_date TIMESTAMPTZ,
    calories_consumed DOUBLE PRECISION,
    protein_consumed DOUBLE PRECISION,
    photo_url TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        fl.id as log_id,
        f.name as food_name,
        fl.serving_size,
        fl.date as log_date,
        CASE
            WHEN fl.serving_size IS NOT NULL AND f.calories IS NOT NULL
            THEN fl.serving_size * f.calories
            ELSE NULL
        END as calories_consumed,
        CASE
            WHEN fl.serving_size IS NOT NULL AND f.protein IS NOT NULL
            THEN fl.serving_size * f.protein
            ELSE NULL
        END as protein_consumed,
        fl.photo_url
    FROM food_logs fl
    JOIN foods f ON fl.food_id = f.id
    WHERE fl.user_id = target_user_id
    AND fl.date >= NOW() - (days_back || ' days')::INTERVAL
    ORDER BY fl.date DESC, fl.created_at DESC
    LIMIT log_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ========================================
-- Real-time Subscriptions
-- ========================================

-- Enable real-time for food_logs table
ALTER PUBLICATION supabase_realtime ADD TABLE food_logs;

-- ========================================
-- Comments for Documentation
-- ========================================

COMMENT ON TABLE food_logs IS 'Food consumption logs linking users to foods with serving sizes and timestamps';
COMMENT ON COLUMN food_logs.id IS 'Primary key UUID for the food log entry';
COMMENT ON COLUMN food_logs.user_id IS 'Foreign key to profiles table - which user logged this food';
COMMENT ON COLUMN food_logs.food_id IS 'Foreign key to foods table - which food was consumed';
COMMENT ON COLUMN food_logs.date IS 'When the food was consumed (user-specified)';
COMMENT ON COLUMN food_logs.serving_size IS 'How many servings of the food were consumed';
COMMENT ON COLUMN food_logs.photo_url IS 'Optional photo of the consumed food (Supabase Storage URL)';
COMMENT ON COLUMN food_logs.created_at IS 'When this log entry was created in the database';
COMMENT ON COLUMN food_logs.updated_at IS 'When this log entry was last modified (auto-updated by trigger)';

-- Function comments
COMMENT ON FUNCTION get_daily_nutrition(UUID, DATE) IS 'Calculate total nutrition consumed by a user on a specific date';
COMMENT ON FUNCTION get_recent_food_logs(UUID, INTEGER, INTEGER) IS 'Get recent food logs for a user with calculated nutrition';

-- ========================================
-- Verification Queries
-- ========================================
-- Uncomment these to verify the table structure after creation:

-- Check table structure
-- SELECT table_name, column_name, data_type, is_nullable, column_default
-- FROM information_schema.columns
-- WHERE table_name = 'food_logs'
-- ORDER BY ordinal_position;

-- Check foreign key constraints
-- SELECT
--     tc.table_name,
--     kcu.column_name,
--     ccu.table_name AS foreign_table_name,
--     ccu.column_name AS foreign_column_name
-- FROM information_schema.table_constraints AS tc
-- JOIN information_schema.key_column_usage AS kcu
--     ON tc.constraint_name = kcu.constraint_name
--     AND tc.table_schema = kcu.table_schema
-- JOIN information_schema.constraint_column_usage AS ccu
--     ON ccu.constraint_name = tc.constraint_name
--     AND ccu.table_schema = tc.table_schema
-- WHERE tc.constraint_type = 'FOREIGN KEY'
-- AND tc.table_name = 'food_logs';

-- Check indexes
-- SELECT indexname, indexdef
-- FROM pg_indexes
-- WHERE tablename = 'food_logs';

-- Check RLS policies
-- SELECT policyname, permissive, roles, cmd, qual, with_check
-- FROM pg_policies
-- WHERE tablename = 'food_logs';