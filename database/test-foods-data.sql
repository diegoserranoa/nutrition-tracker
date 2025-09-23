-- ========================================
-- Foods Table Test Data
-- ========================================
-- This script inserts sample food data for testing the foods table
-- Uses realistic nutritional values based on USDA food data

-- ========================================
-- Sample Foods Data
-- ========================================

-- Sample Food 1: Chicken Breast (cooked, skinless)
INSERT INTO foods (
    name, measurement_unit, serving_size,
    calories, protein, total_fat, saturated_fat, cholesterol, sodium,
    total_carbohydrate, dietary_fiber, total_sugars, added_sugars,
    vitamin_d, calcium, iron, potassium,
    vitamin_a, vitamin_c, vitamin_b6, vitamin_e, vitamin_k,
    thiamin, vitamin_b12, riboflavin, folate, niacin,
    choline, biotin, chloride, chromium, copper,
    fluoride, iodine, magnesium, manganese, molybdenum,
    phosphorus, selenium, zinc
) VALUES (
    'Chicken Breast, Skinless, Cooked', 'grams', 100.0,
    -- Macronutrients
    165.0, 31.0, 3.6, 1.0, 85.0, 74.0,
    0.0, 0.0, 0.0, 0.0,
    -- Essential vitamins/minerals
    0.2, 15.0, 1.0, 256.0,
    -- Extended vitamins
    6.0, 0.0, 0.5, 0.3, 2.6,
    0.07, 0.3, 0.10, 4.0, 10.9,
    -- Extended minerals
    85.3, 1.5, 77.0, 0.0, 0.1,
    0.0, 0.0, 25.0, 0.02, 0.0,
    228.0, 22.0, 1.0
);

-- Sample Food 2: Brown Rice (cooked)
INSERT INTO foods (
    name, measurement_unit, serving_size,
    calories, protein, total_fat, saturated_fat, cholesterol, sodium,
    total_carbohydrate, dietary_fiber, total_sugars, added_sugars,
    vitamin_d, calcium, iron, potassium,
    vitamin_a, vitamin_c, vitamin_b6, vitamin_e, vitamin_k,
    thiamin, vitamin_b12, riboflavin, folate, niacin,
    choline, biotin, chloride, chromium, copper,
    fluoride, iodine, magnesium, manganese, molybdenum,
    phosphorus, selenium, zinc
) VALUES (
    'Brown Rice, Cooked', 'grams', 100.0,
    -- Macronutrients
    123.0, 2.3, 0.9, 0.2, 0.0, 5.0,
    23.0, 1.8, 0.4, 0.0,
    -- Essential vitamins/minerals
    0.0, 10.0, 0.4, 43.0,
    -- Extended vitamins
    0.0, 0.0, 0.15, 0.1, 0.9,
    0.09, 0.0, 0.04, 4.0, 1.5,
    -- Extended minerals
    9.2, 2.3, 11.0, 0.2, 0.14,
    0.0, 0.0, 44.0, 1.1, 27.0,
    77.0, 9.8, 0.6
);

-- Sample Food 3: Banana (fresh)
INSERT INTO foods (
    name, measurement_unit, serving_size,
    calories, protein, total_fat, saturated_fat, cholesterol, sodium,
    total_carbohydrate, dietary_fiber, total_sugars, added_sugars,
    vitamin_d, calcium, iron, potassium,
    vitamin_a, vitamin_c, vitamin_b6, vitamin_e, vitamin_k,
    thiamin, vitamin_b12, riboflavin, folate, niacin,
    choline, biotin, chloride, chromium, copper,
    fluoride, iodine, magnesium, manganese, molybdenum,
    phosphorus, selenium, zinc
) VALUES (
    'Banana, Fresh', 'grams', 100.0,
    -- Macronutrients
    89.0, 1.1, 0.3, 0.1, 0.0, 1.0,
    22.8, 2.6, 12.2, 0.0,
    -- Essential vitamins/minerals
    0.0, 5.0, 0.3, 358.0,
    -- Extended vitamins
    3.0, 8.7, 0.4, 0.1, 0.5,
    0.03, 0.0, 0.07, 20.0, 0.7,
    -- Extended minerals
    9.8, 2.0, 103.0, 0.0, 0.08,
    0.0, 0.0, 27.0, 0.27, 5.0,
    22.0, 1.0, 0.2
);

-- Sample Food 4: Spinach (fresh)
INSERT INTO foods (
    name, measurement_unit, serving_size,
    calories, protein, total_fat, saturated_fat, cholesterol, sodium,
    total_carbohydrate, dietary_fiber, total_sugars, added_sugars,
    vitamin_d, calcium, iron, potassium,
    vitamin_a, vitamin_c, vitamin_b6, vitamin_e, vitamin_k,
    thiamin, vitamin_b12, riboflavin, folate, niacin,
    choline, biotin, chloride, chromium, copper,
    fluoride, iodine, magnesium, manganese, molybdenum,
    phosphorus, selenium, zinc
) VALUES (
    'Spinach, Fresh', 'grams', 100.0,
    -- Macronutrients
    23.0, 2.9, 0.4, 0.1, 0.0, 79.0,
    3.6, 2.2, 0.4, 0.0,
    -- Essential vitamins/minerals
    0.0, 99.0, 2.7, 558.0,
    -- Extended vitamins
    469.0, 28.1, 0.2, 2.0, 483.0,
    0.08, 0.0, 0.19, 194.0, 0.7,
    -- Extended minerals
    19.3, 6.8, 96.0, 14.0, 0.13,
    0.0, 2.0, 79.0, 0.90, 1.0,
    49.0, 1.0, 0.5
);

-- Sample Food 5: Salmon (Atlantic, cooked)
INSERT INTO foods (
    name, measurement_unit, serving_size,
    calories, protein, total_fat, saturated_fat, cholesterol, sodium,
    total_carbohydrate, dietary_fiber, total_sugars, added_sugars,
    vitamin_d, calcium, iron, potassium,
    vitamin_a, vitamin_c, vitamin_b6, vitamin_e, vitamin_k,
    thiamin, vitamin_b12, riboflavin, folate, niacin,
    choline, biotin, chloride, chromium, copper,
    fluoride, iodine, magnesium, manganese, molybdenum,
    phosphorus, selenium, zinc
) VALUES (
    'Salmon, Atlantic, Cooked', 'grams', 100.0,
    -- Macronutrients
    206.0, 22.1, 12.4, 3.1, 63.0, 59.0,
    0.0, 0.0, 0.0, 0.0,
    -- Essential vitamins/minerals
    11.0, 12.0, 0.8, 384.0,
    -- Extended vitamins
    12.0, 0.0, 0.6, 1.2, 0.1,
    0.23, 2.8, 0.38, 25.0, 7.9,
    -- Extended minerals
    91.0, 4.5, 75.0, 0.0, 0.25,
    0.0, 0.0, 27.0, 0.02, 1.0,
    214.0, 36.5, 0.6
);

-- Sample Food 6: Apple (fresh, with skin)
INSERT INTO foods (
    name, measurement_unit, serving_size,
    calories, protein, total_fat, saturated_fat, cholesterol, sodium,
    total_carbohydrate, dietary_fiber, total_sugars, added_sugars,
    vitamin_d, calcium, iron, potassium,
    vitamin_a, vitamin_c, vitamin_b6, vitamin_e, vitamin_k,
    thiamin, vitamin_b12, riboflavin, folate, niacin,
    choline, biotin, chloride, chromium, copper,
    fluoride, iodine, magnesium, manganese, molybdenum,
    phosphorus, selenium, zinc
) VALUES (
    'Apple, Fresh with Skin', 'grams', 100.0,
    -- Macronutrients
    52.0, 0.3, 0.2, 0.0, 0.0, 1.0,
    13.8, 2.4, 10.4, 0.0,
    -- Essential vitamins/minerals
    0.0, 6.0, 0.1, 107.0,
    -- Extended vitamins
    3.0, 4.6, 0.04, 0.2, 2.2,
    0.02, 0.0, 0.03, 3.0, 0.1,
    -- Extended minerals
    3.4, 0.1, 2.0, 0.0, 0.03,
    3.3, 1.0, 5.0, 0.04, 0.0,
    11.0, 0.0, 0.04
);

-- ========================================
-- Test Queries
-- ========================================

-- Query to verify inserted data
-- SELECT
--     name,
--     calories,
--     protein,
--     total_fat,
--     total_carbohydrate,
--     vitamin_c,
--     calcium,
--     iron
-- FROM foods
-- ORDER BY name;

-- Query to test search functionality
-- SELECT * FROM search_foods('chicken');

-- Query to test nutritional filtering
-- SELECT name, calories, protein
-- FROM foods
-- WHERE protein > 20
-- ORDER BY protein DESC;

-- Query to test high-vitamin foods
-- SELECT name, vitamin_c, vitamin_a, vitamin_k
-- FROM foods
-- WHERE vitamin_c > 5 OR vitamin_a > 100 OR vitamin_k > 50
-- ORDER BY vitamin_c DESC;

-- ========================================
-- Data Validation
-- ========================================

-- Check that all constraints are working
-- SELECT
--     table_name,
--     constraint_name,
--     constraint_type
-- FROM information_schema.table_constraints
-- WHERE table_name = 'foods';

-- Count total foods inserted
-- SELECT COUNT(*) as total_foods FROM foods;

-- Verify no negative nutritional values
-- SELECT name, calories, protein, total_fat
-- FROM foods
-- WHERE calories < 0 OR protein < 0 OR total_fat < 0;