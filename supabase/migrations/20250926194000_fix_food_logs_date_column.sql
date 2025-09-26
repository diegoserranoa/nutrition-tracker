-- Fix the date column issue in food_logs table
-- This migration handles the existing 'date' column that has a NOT NULL constraint

DO $$
BEGIN
    -- Check if the 'date' column exists and handle it
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'food_logs' AND column_name = 'date') THEN
        -- If the date column exists, we have a few options:
        -- Option 1: Drop the date column if it's not needed (since we have logged_at)
        -- Option 2: Make it nullable
        -- Option 3: Set a default value

        -- Let's make it nullable first to avoid breaking existing functionality
        ALTER TABLE food_logs ALTER COLUMN date DROP NOT NULL;

        -- Add a comment explaining this column
        COMMENT ON COLUMN food_logs.date IS 'Legacy date column - use logged_at for new implementations';

        RAISE NOTICE 'Made date column nullable in food_logs table';
    ELSE
        RAISE NOTICE 'No date column found in food_logs table';
    END IF;

    -- Also ensure our expected columns have proper defaults
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'food_logs' AND column_name = 'logged_at') THEN
        -- Ensure logged_at has a proper default
        ALTER TABLE food_logs ALTER COLUMN logged_at SET DEFAULT now();
        RAISE NOTICE 'Ensured logged_at has default value';
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'food_logs' AND column_name = 'created_at') THEN
        -- Ensure created_at has a proper default
        ALTER TABLE food_logs ALTER COLUMN created_at SET DEFAULT now();
        RAISE NOTICE 'Ensured created_at has default value';
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'food_logs' AND column_name = 'updated_at') THEN
        -- Ensure updated_at has a proper default
        ALTER TABLE food_logs ALTER COLUMN updated_at SET DEFAULT now();
        RAISE NOTICE 'Ensured updated_at has default value';
    END IF;
END $$;

-- Create an index on the date column if it exists (for performance)
CREATE INDEX IF NOT EXISTS idx_food_logs_date ON food_logs(date);

COMMENT ON TABLE food_logs IS 'Food consumption logs - supports both date and logged_at columns for backward compatibility';