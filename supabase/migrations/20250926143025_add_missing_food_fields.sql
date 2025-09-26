-- Migration to add missing food fields that are currently commented out in iOS app
-- This enables full food metadata support including brands, categories, and additional nutrition info

-- Add basic food metadata fields
ALTER TABLE foods ADD COLUMN brand TEXT;
ALTER TABLE foods ADD COLUMN barcode TEXT;
ALTER TABLE foods ADD COLUMN description TEXT;
ALTER TABLE foods ADD COLUMN serving_size_grams DOUBLE PRECISION;

-- Add additional fat nutrition fields
ALTER TABLE foods ADD COLUMN unsaturated_fat DOUBLE PRECISION;
ALTER TABLE foods ADD COLUMN trans_fat DOUBLE PRECISION;

-- Add food categorization and metadata
ALTER TABLE foods ADD COLUMN category TEXT;
ALTER TABLE foods ADD COLUMN is_verified BOOLEAN DEFAULT FALSE;
ALTER TABLE foods ADD COLUMN source TEXT DEFAULT 'manual';
ALTER TABLE foods ADD COLUMN created_by UUID REFERENCES auth.users(id);

-- Add indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_foods_brand ON foods(brand);
CREATE INDEX IF NOT EXISTS idx_foods_barcode ON foods(barcode);
CREATE INDEX IF NOT EXISTS idx_foods_category ON foods(category);
CREATE INDEX IF NOT EXISTS idx_foods_is_verified ON foods(is_verified);
CREATE INDEX IF NOT EXISTS idx_foods_source ON foods(source);
CREATE INDEX IF NOT EXISTS idx_foods_created_by ON foods(created_by);

-- Add comments for documentation
COMMENT ON COLUMN foods.brand IS 'Brand name of the food product';
COMMENT ON COLUMN foods.barcode IS 'Barcode/UPC code for the food product';
COMMENT ON COLUMN foods.description IS 'Detailed description of the food';
COMMENT ON COLUMN foods.serving_size_grams IS 'Serving size in grams for conversion';
COMMENT ON COLUMN foods.unsaturated_fat IS 'Unsaturated fat content in grams';
COMMENT ON COLUMN foods.trans_fat IS 'Trans fat content in grams';
COMMENT ON COLUMN foods.category IS 'Food category (fruits, vegetables, etc.)';
COMMENT ON COLUMN foods.is_verified IS 'Whether the nutrition data has been verified';
COMMENT ON COLUMN foods.source IS 'Data source (manual, usda, nutrition_api, etc.)';
COMMENT ON COLUMN foods.created_by IS 'User who created this food entry';