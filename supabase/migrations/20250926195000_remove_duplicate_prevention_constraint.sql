-- Remove the problematic unique constraint that prevents users from logging the same food multiple times
-- The constraint from database/04-indexes-constraints.sql line 47-49 is too restrictive:
-- CREATE UNIQUE INDEX idx_food_logs_duplicate_prevention ON food_logs(user_id, food_id, date)
-- This prevents users from eating the same food multiple times per day, which is a common use case

DO $$
BEGIN
    -- Drop the unique index that's preventing multiple logs of same food per day
    IF EXISTS (
        SELECT 1
        FROM pg_indexes
        WHERE tablename = 'food_logs'
        AND indexname = 'idx_food_logs_duplicate_prevention'
    ) THEN
        DROP INDEX IF EXISTS idx_food_logs_duplicate_prevention;
        RAISE NOTICE 'Dropped unique index idx_food_logs_duplicate_prevention';
    ELSE
        RAISE NOTICE 'Index idx_food_logs_duplicate_prevention does not exist';
    END IF;

    -- Create a new non-unique index for performance on the same columns
    -- This maintains query performance without the uniqueness constraint
    CREATE INDEX IF NOT EXISTS idx_food_logs_user_food_date
    ON food_logs(user_id, food_id, date);

    RAISE NOTICE 'Created non-unique index idx_food_logs_user_food_date for performance';

EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Error while modifying indexes: %', SQLERRM;
END $$;

-- Add comment explaining the change
COMMENT ON TABLE food_logs IS 'Food consumption logs - users can log the same food multiple times per day. Duplicate prevention removed to allow multiple servings.';