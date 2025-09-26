-- Comprehensive migration to ensure ALL food_logs columns exist
-- This migration checks for and adds every single column the iOS app expects

DO $$
BEGIN
    -- Core required columns that should definitely exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'food_logs' AND column_name = 'id') THEN
        ALTER TABLE food_logs ADD COLUMN id UUID PRIMARY KEY DEFAULT gen_random_uuid();
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'food_logs' AND column_name = 'user_id') THEN
        ALTER TABLE food_logs ADD COLUMN user_id UUID NOT NULL REFERENCES auth.users(id);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'food_logs' AND column_name = 'food_id') THEN
        ALTER TABLE food_logs ADD COLUMN food_id UUID NOT NULL REFERENCES foods(id);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'food_logs' AND column_name = 'quantity') THEN
        ALTER TABLE food_logs ADD COLUMN quantity DOUBLE PRECISION NOT NULL DEFAULT 1.0;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'food_logs' AND column_name = 'created_at') THEN
        ALTER TABLE food_logs ADD COLUMN created_at TIMESTAMPTZ DEFAULT now() NOT NULL;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'food_logs' AND column_name = 'updated_at') THEN
        ALTER TABLE food_logs ADD COLUMN updated_at TIMESTAMPTZ DEFAULT now() NOT NULL;
    END IF;

    -- All the additional columns we know are needed
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'food_logs' AND column_name = 'unit') THEN
        ALTER TABLE food_logs ADD COLUMN unit TEXT NOT NULL DEFAULT 'serving';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'food_logs' AND column_name = 'total_grams') THEN
        ALTER TABLE food_logs ADD COLUMN total_grams DOUBLE PRECISION;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'food_logs' AND column_name = 'meal_type') THEN
        ALTER TABLE food_logs ADD COLUMN meal_type TEXT NOT NULL DEFAULT 'other';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'food_logs' AND column_name = 'logged_at') THEN
        ALTER TABLE food_logs ADD COLUMN logged_at TIMESTAMPTZ DEFAULT now() NOT NULL;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'food_logs' AND column_name = 'notes') THEN
        ALTER TABLE food_logs ADD COLUMN notes TEXT;
    END IF;

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

    -- Log what we're doing
    RAISE NOTICE 'Food logs table structure check and creation completed';
END $$;

-- Create all necessary indexes
CREATE INDEX IF NOT EXISTS idx_food_logs_id ON food_logs(id);
CREATE INDEX IF NOT EXISTS idx_food_logs_user_id ON food_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_food_logs_food_id ON food_logs(food_id);
CREATE INDEX IF NOT EXISTS idx_food_logs_quantity ON food_logs(quantity);
CREATE INDEX IF NOT EXISTS idx_food_logs_unit ON food_logs(unit);
CREATE INDEX IF NOT EXISTS idx_food_logs_meal_type ON food_logs(meal_type);
CREATE INDEX IF NOT EXISTS idx_food_logs_logged_at ON food_logs(logged_at);
CREATE INDEX IF NOT EXISTS idx_food_logs_created_at ON food_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_food_logs_updated_at ON food_logs(updated_at);
CREATE INDEX IF NOT EXISTS idx_food_logs_brand ON food_logs(brand);
CREATE INDEX IF NOT EXISTS idx_food_logs_custom_name ON food_logs(custom_name);
CREATE INDEX IF NOT EXISTS idx_food_logs_is_deleted ON food_logs(is_deleted);
CREATE INDEX IF NOT EXISTS idx_food_logs_sync_status ON food_logs(sync_status);

-- Composite indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_food_logs_user_logged_at ON food_logs(user_id, logged_at);
CREATE INDEX IF NOT EXISTS idx_food_logs_user_meal_date ON food_logs(user_id, meal_type, logged_at);
CREATE INDEX IF NOT EXISTS idx_food_logs_active ON food_logs(user_id, is_deleted, logged_at) WHERE is_deleted = FALSE;

-- Add RLS policies if the table exists but doesn't have them
DO $$
BEGIN
    -- Enable RLS if not already enabled
    IF NOT EXISTS (
        SELECT 1 FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE c.relname = 'food_logs' AND c.relrowsecurity = true
    ) THEN
        ALTER TABLE food_logs ENABLE ROW LEVEL SECURITY;
    END IF;
END $$;

-- Add comprehensive comments
COMMENT ON TABLE food_logs IS 'User food consumption logs with full metadata support';
COMMENT ON COLUMN food_logs.id IS 'Primary key for the food log entry';
COMMENT ON COLUMN food_logs.user_id IS 'Reference to the user who logged this food';
COMMENT ON COLUMN food_logs.food_id IS 'Reference to the food item that was consumed';
COMMENT ON COLUMN food_logs.quantity IS 'Amount of food consumed in the specified unit';
COMMENT ON COLUMN food_logs.unit IS 'Unit of measurement for the quantity (e.g., cups, pieces, grams)';
COMMENT ON COLUMN food_logs.total_grams IS 'Actual weight consumed in grams (for nutrition calculations)';
COMMENT ON COLUMN food_logs.meal_type IS 'Type of meal (breakfast, lunch, dinner, snack, other)';
COMMENT ON COLUMN food_logs.logged_at IS 'Timestamp when the food was actually consumed';
COMMENT ON COLUMN food_logs.created_at IS 'Timestamp when this log entry was created';
COMMENT ON COLUMN food_logs.updated_at IS 'Timestamp when this log entry was last updated';
COMMENT ON COLUMN food_logs.notes IS 'Optional notes about this food log entry';
COMMENT ON COLUMN food_logs.brand IS 'Brand override if different from the associated food item';
COMMENT ON COLUMN food_logs.custom_name IS 'Custom name override for this specific food log entry';
COMMENT ON COLUMN food_logs.is_deleted IS 'Soft delete flag - TRUE if this log entry has been deleted';
COMMENT ON COLUMN food_logs.sync_status IS 'Synchronization status (synced, pending, error, etc.)';