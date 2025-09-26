-- Comprehensive migration to add ALL missing food log fields at once
-- This ensures the database schema matches exactly what the iOS app expects

-- Add all potentially missing food log columns
-- (Using IF NOT EXISTS for safety in case some already exist)

-- Basic consumption fields
DO $$
BEGIN
    -- Check and add unit column
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'food_logs' AND column_name = 'unit') THEN
        ALTER TABLE food_logs ADD COLUMN unit TEXT NOT NULL DEFAULT 'serving';
    END IF;

    -- Check and add total_grams column
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'food_logs' AND column_name = 'total_grams') THEN
        ALTER TABLE food_logs ADD COLUMN total_grams DOUBLE PRECISION;
    END IF;

    -- Check and add meal_type column
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'food_logs' AND column_name = 'meal_type') THEN
        ALTER TABLE food_logs ADD COLUMN meal_type TEXT NOT NULL DEFAULT 'other';
    END IF;

    -- Check and add notes column
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'food_logs' AND column_name = 'notes') THEN
        ALTER TABLE food_logs ADD COLUMN notes TEXT;
    END IF;

    -- Check and add logged_at column (from previous migration, but ensuring it exists)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'food_logs' AND column_name = 'logged_at') THEN
        ALTER TABLE food_logs ADD COLUMN logged_at TIMESTAMPTZ DEFAULT now() NOT NULL;
    END IF;

    -- Check and add metadata columns (from previous migration, but ensuring they exist)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'food_logs' AND column_name = 'brand') THEN
        ALTER TABLE food_logs ADD COLUMN brand TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'food_logs' AND column_name = 'custom_name') THEN
        ALTER TABLE food_logs ADD COLUMN custom_name TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'food_logs' AND column_name = 'is_deleted') THEN
        ALTER TABLE food_logs ADD COLUMN is_deleted BOOLEAN DEFAULT FALSE NOT NULL;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'food_logs' AND column_name = 'sync_status') THEN
        ALTER TABLE food_logs ADD COLUMN sync_status TEXT DEFAULT 'synced' NOT NULL;
    END IF;
END $$;

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_food_logs_unit ON food_logs(unit);
CREATE INDEX IF NOT EXISTS idx_food_logs_meal_type ON food_logs(meal_type);
CREATE INDEX IF NOT EXISTS idx_food_logs_logged_at ON food_logs(logged_at);
CREATE INDEX IF NOT EXISTS idx_food_logs_brand ON food_logs(brand);
CREATE INDEX IF NOT EXISTS idx_food_logs_custom_name ON food_logs(custom_name);
CREATE INDEX IF NOT EXISTS idx_food_logs_is_deleted ON food_logs(is_deleted);
CREATE INDEX IF NOT EXISTS idx_food_logs_sync_status ON food_logs(sync_status);

-- Composite indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_food_logs_user_logged_at ON food_logs(user_id, logged_at);
CREATE INDEX IF NOT EXISTS idx_food_logs_user_meal_date ON food_logs(user_id, meal_type, logged_at);
CREATE INDEX IF NOT EXISTS idx_food_logs_active ON food_logs(user_id, is_deleted, logged_at) WHERE is_deleted = FALSE;

-- Add comprehensive comments for documentation
COMMENT ON COLUMN food_logs.unit IS 'Unit of measurement for the quantity (e.g., cups, pieces, grams)';
COMMENT ON COLUMN food_logs.total_grams IS 'Actual weight consumed in grams (for nutrition calculations)';
COMMENT ON COLUMN food_logs.meal_type IS 'Type of meal (breakfast, lunch, dinner, snack, other)';
COMMENT ON COLUMN food_logs.logged_at IS 'Timestamp when the food was actually consumed';
COMMENT ON COLUMN food_logs.notes IS 'Optional notes about this food log entry';
COMMENT ON COLUMN food_logs.brand IS 'Brand override if different from the associated food item';
COMMENT ON COLUMN food_logs.custom_name IS 'Custom name override for this specific food log entry';
COMMENT ON COLUMN food_logs.is_deleted IS 'Soft delete flag - TRUE if this log entry has been deleted';
COMMENT ON COLUMN food_logs.sync_status IS 'Synchronization status (synced, pending, error, etc.)';