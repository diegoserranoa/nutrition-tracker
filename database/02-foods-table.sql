-- ========================================
-- Foods Table Creation Script
-- ========================================
-- This script creates the foods table with comprehensive nutritional data
-- matching the original Parse Food model with 25+ micronutrient fields

-- Create foods table
CREATE TABLE IF NOT EXISTS foods (
    -- Primary key
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,

    -- Core food information
    name TEXT,
    measurement_unit TEXT,
    serving_size DOUBLE PRECISION,

    -- Macronutrients (10 fields)
    calories DOUBLE PRECISION,
    protein DOUBLE PRECISION,
    total_fat DOUBLE PRECISION,
    saturated_fat DOUBLE PRECISION,
    cholesterol DOUBLE PRECISION,
    sodium DOUBLE PRECISION,
    total_carbohydrate DOUBLE PRECISION,
    dietary_fiber DOUBLE PRECISION,
    total_sugars DOUBLE PRECISION,
    added_sugars DOUBLE PRECISION,

    -- Essential vitamins and minerals (4 fields)
    vitamin_d DOUBLE PRECISION,
    calcium DOUBLE PRECISION,
    iron DOUBLE PRECISION,
    potassium DOUBLE PRECISION,

    -- Extended micronutrients - Vitamins (10 fields)
    vitamin_a DOUBLE PRECISION,
    vitamin_c DOUBLE PRECISION,
    vitamin_b6 DOUBLE PRECISION,
    vitamin_e DOUBLE PRECISION,
    vitamin_k DOUBLE PRECISION,
    thiamin DOUBLE PRECISION,
    vitamin_b12 DOUBLE PRECISION,
    riboflavin DOUBLE PRECISION,
    folate DOUBLE PRECISION,
    niacin DOUBLE PRECISION,

    -- Extended micronutrients - Minerals and others (12 fields)
    choline DOUBLE PRECISION,
    biotin DOUBLE PRECISION,
    chloride DOUBLE PRECISION,
    chromium DOUBLE PRECISION,
    copper DOUBLE PRECISION,
    fluoride DOUBLE PRECISION,
    iodine DOUBLE PRECISION,
    magnesium DOUBLE PRECISION,
    manganese DOUBLE PRECISION,
    molybdenum DOUBLE PRECISION,
    phosphorus DOUBLE PRECISION,
    selenium DOUBLE PRECISION,
    zinc DOUBLE PRECISION,

    -- Photo storage (Supabase Storage URL)
    photo_url TEXT,

    -- Timestamps for tracking
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- ========================================
-- Constraints and Validation
-- ========================================

-- Add check constraints for reasonable nutritional values
ALTER TABLE foods ADD CONSTRAINT check_calories_positive
    CHECK (calories IS NULL OR calories >= 0);

ALTER TABLE foods ADD CONSTRAINT check_protein_positive
    CHECK (protein IS NULL OR protein >= 0);

ALTER TABLE foods ADD CONSTRAINT check_fat_positive
    CHECK (total_fat IS NULL OR total_fat >= 0);

ALTER TABLE foods ADD CONSTRAINT check_carbs_positive
    CHECK (total_carbohydrate IS NULL OR total_carbohydrate >= 0);

ALTER TABLE foods ADD CONSTRAINT check_serving_size_positive
    CHECK (serving_size IS NULL OR serving_size > 0);

-- Ensure food name is not empty when provided
ALTER TABLE foods ADD CONSTRAINT check_name_not_empty
    CHECK (name IS NULL OR LENGTH(TRIM(name)) > 0);

-- ========================================
-- Extensions Required for Advanced Features
-- ========================================

-- Enable pg_trgm extension for fuzzy text search
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ========================================
-- Indexes for Performance
-- ========================================

-- Index on name for food searches (most common query)
CREATE INDEX IF NOT EXISTS idx_foods_name ON foods(name);

-- Index on name with text search capabilities (requires pg_trgm extension)
CREATE INDEX IF NOT EXISTS idx_foods_name_trgm ON foods USING gin (name gin_trgm_ops);

-- Index on calories for filtering/sorting
CREATE INDEX IF NOT EXISTS idx_foods_calories ON foods(calories);

-- Index on protein for high-protein food searches
CREATE INDEX IF NOT EXISTS idx_foods_protein ON foods(protein);

-- Index on created_at for sorting by newest
CREATE INDEX IF NOT EXISTS idx_foods_created_at ON foods(created_at);

-- Composite index for common nutritional searches
CREATE INDEX IF NOT EXISTS idx_foods_nutrition_summary ON foods(calories, protein, total_fat, total_carbohydrate);

-- ========================================
-- Full-Text Search Setup
-- ========================================

-- Create function for food name search
CREATE OR REPLACE FUNCTION search_foods(search_term TEXT)
RETURNS TABLE(
    id UUID,
    name TEXT,
    calories DOUBLE PRECISION,
    protein DOUBLE PRECISION,
    similarity REAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        f.id,
        f.name,
        f.calories,
        f.protein,
        similarity(f.name, search_term) as sim
    FROM foods f
    WHERE f.name % search_term
    ORDER BY sim DESC, f.name
    LIMIT 50;
END;
$$ LANGUAGE plpgsql;

-- ========================================
-- Automatic Timestamps Function
-- ========================================

-- Reuse the function from profiles table or create if it doesn't exist
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger to call the function before any UPDATE
CREATE TRIGGER update_foods_updated_at
    BEFORE UPDATE ON foods
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ========================================
-- Real-time Subscriptions
-- ========================================

-- Enable real-time for foods table
ALTER PUBLICATION supabase_realtime ADD TABLE foods;

-- ========================================
-- Row Level Security (RLS)
-- ========================================

-- Enable RLS on foods table
ALTER TABLE foods ENABLE ROW LEVEL SECURITY;

-- Policy: Allow read access to all authenticated users
CREATE POLICY "Authenticated users can view foods"
ON foods FOR SELECT
TO authenticated
USING (true);

-- Policy: Allow insert for authenticated users
CREATE POLICY "Authenticated users can add foods"
ON foods FOR INSERT
TO authenticated
WITH CHECK (true);

-- Policy: Allow update for authenticated users
CREATE POLICY "Authenticated users can update foods"
ON foods FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

-- Policy: Allow delete for authenticated users (optional - might want to restrict)
CREATE POLICY "Authenticated users can delete foods"
ON foods FOR DELETE
TO authenticated
USING (true);

-- ========================================
-- Comments for Documentation
-- ========================================

COMMENT ON TABLE foods IS 'Foods table with comprehensive nutritional data from USDA standards';
COMMENT ON COLUMN foods.id IS 'Primary key UUID for the food item';
COMMENT ON COLUMN foods.name IS 'Name of the food item';
COMMENT ON COLUMN foods.measurement_unit IS 'Unit of measurement (grams, cups, ounces, etc.)';
COMMENT ON COLUMN foods.serving_size IS 'Standard serving size in the measurement unit';

-- Macronutrient comments
COMMENT ON COLUMN foods.calories IS 'Calories per serving size';
COMMENT ON COLUMN foods.protein IS 'Protein in grams per serving size';
COMMENT ON COLUMN foods.total_fat IS 'Total fat in grams per serving size';
COMMENT ON COLUMN foods.saturated_fat IS 'Saturated fat in grams per serving size';
COMMENT ON COLUMN foods.cholesterol IS 'Cholesterol in milligrams per serving size';
COMMENT ON COLUMN foods.sodium IS 'Sodium in milligrams per serving size';
COMMENT ON COLUMN foods.total_carbohydrate IS 'Total carbohydrates in grams per serving size';
COMMENT ON COLUMN foods.dietary_fiber IS 'Dietary fiber in grams per serving size';
COMMENT ON COLUMN foods.total_sugars IS 'Total sugars in grams per serving size';
COMMENT ON COLUMN foods.added_sugars IS 'Added sugars in grams per serving size';

-- Essential vitamins and minerals comments
COMMENT ON COLUMN foods.vitamin_d IS 'Vitamin D in micrograms per serving size';
COMMENT ON COLUMN foods.calcium IS 'Calcium in milligrams per serving size';
COMMENT ON COLUMN foods.iron IS 'Iron in milligrams per serving size';
COMMENT ON COLUMN foods.potassium IS 'Potassium in milligrams per serving size';

-- Extended micronutrients comments
COMMENT ON COLUMN foods.vitamin_a IS 'Vitamin A in micrograms RAE per serving size';
COMMENT ON COLUMN foods.vitamin_c IS 'Vitamin C in milligrams per serving size';
COMMENT ON COLUMN foods.vitamin_b6 IS 'Vitamin B6 in milligrams per serving size';
COMMENT ON COLUMN foods.vitamin_e IS 'Vitamin E in milligrams per serving size';
COMMENT ON COLUMN foods.vitamin_k IS 'Vitamin K in micrograms per serving size';
COMMENT ON COLUMN foods.thiamin IS 'Thiamin (B1) in milligrams per serving size';
COMMENT ON COLUMN foods.vitamin_b12 IS 'Vitamin B12 in micrograms per serving size';
COMMENT ON COLUMN foods.riboflavin IS 'Riboflavin (B2) in milligrams per serving size';
COMMENT ON COLUMN foods.folate IS 'Folate in micrograms DFE per serving size';
COMMENT ON COLUMN foods.niacin IS 'Niacin (B3) in milligrams per serving size';
COMMENT ON COLUMN foods.choline IS 'Choline in milligrams per serving size';
COMMENT ON COLUMN foods.biotin IS 'Biotin in micrograms per serving size';
COMMENT ON COLUMN foods.chloride IS 'Chloride in milligrams per serving size';
COMMENT ON COLUMN foods.chromium IS 'Chromium in micrograms per serving size';
COMMENT ON COLUMN foods.copper IS 'Copper in milligrams per serving size';
COMMENT ON COLUMN foods.fluoride IS 'Fluoride in milligrams per serving size';
COMMENT ON COLUMN foods.iodine IS 'Iodine in micrograms per serving size';
COMMENT ON COLUMN foods.magnesium IS 'Magnesium in milligrams per serving size';
COMMENT ON COLUMN foods.manganese IS 'Manganese in milligrams per serving size';
COMMENT ON COLUMN foods.molybdenum IS 'Molybdenum in micrograms per serving size';
COMMENT ON COLUMN foods.phosphorus IS 'Phosphorus in milligrams per serving size';
COMMENT ON COLUMN foods.selenium IS 'Selenium in micrograms per serving size';
COMMENT ON COLUMN foods.zinc IS 'Zinc in milligrams per serving size';

COMMENT ON COLUMN foods.photo_url IS 'URL to food photo in Supabase Storage';
COMMENT ON COLUMN foods.created_at IS 'Timestamp when food was created';
COMMENT ON COLUMN foods.updated_at IS 'Timestamp when food was last updated (auto-updated by trigger)';

-- ========================================
-- Verification Queries
-- ========================================
-- Uncomment these to verify the table structure after creation:

-- SELECT table_name, column_name, data_type, is_nullable, column_default
-- FROM information_schema.columns
-- WHERE table_name = 'foods'
-- ORDER BY ordinal_position;

-- SELECT indexname, indexdef
-- FROM pg_indexes
-- WHERE tablename = 'foods';

-- SELECT policyname, permissive, roles, cmd, qual, with_check
-- FROM pg_policies
-- WHERE tablename = 'foods';