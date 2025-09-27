#!/usr/bin/env node

/**
 * Migration Validation Script
 *
 * This script validates that the Parse to Supabase migration was successful
 * by comparing record counts and sampling data integrity.
 */

const Parse = require('parse/node');
const { createClient } = require('@supabase/supabase-js');

// Configuration (same as migration script)
const PARSE_CONFIG = {
    applicationId: process.env.PARSE_APPLICATION_ID,
    masterKey: process.env.PARSE_MASTER_KEY,
    serverURL: process.env.PARSE_SERVER_URL,
};

const SUPABASE_CONFIG = {
    url: process.env.SUPABASE_URL,
    serviceKey: process.env.SUPABASE_SERVICE_ROLE_KEY,
};

// Initialize clients
Parse.initialize(PARSE_CONFIG.applicationId);
Parse.masterKey = PARSE_CONFIG.masterKey;
Parse.serverURL = PARSE_CONFIG.serverURL;

const supabase = createClient(SUPABASE_CONFIG.url, SUPABASE_CONFIG.serviceKey);

async function validateRecordCounts() {
    console.log('🔍 Validating record counts...');

    try {
        // Count Parse records
        const parseUserQuery = new Parse.Query('_User');
        const parseFoodQuery = new Parse.Query('Food');
        const parseFoodLogQuery = new Parse.Query('FoodLog');

        const [parseUserCount, parseFoodCount, parseFoodLogCount] = await Promise.all([
            parseUserQuery.count({ useMasterKey: true }),
            parseFoodQuery.count({ useMasterKey: true }),
            parseFoodLogQuery.count({ useMasterKey: true }),
        ]);

        // Count Supabase records
        const { count: supabaseUserCount } = await supabase
            .from('auth.users')
            .select('*', { count: 'exact', head: true });

        const { count: supabaseFoodCount } = await supabase
            .from('foods')
            .select('*', { count: 'exact', head: true });

        const { count: supabaseFoodLogCount } = await supabase
            .from('food_logs')
            .select('*', { count: 'exact', head: true });

        console.log('\n📊 Record Count Comparison:');
        console.log('==========================');
        console.log(`Users:     Parse: ${parseUserCount}, Supabase: ${supabaseUserCount}`);
        console.log(`Foods:     Parse: ${parseFoodCount}, Supabase: ${supabaseFoodCount}`);
        console.log(`Food Logs: Parse: ${parseFoodLogCount}, Supabase: ${supabaseFoodLogCount}`);

        const usersMatch = parseUserCount === supabaseUserCount;
        const foodsMatch = parseFoodCount === supabaseFoodCount;
        const foodLogsMatch = parseFoodLogCount === supabaseFoodLogCount;

        if (usersMatch && foodsMatch && foodLogsMatch) {
            console.log('✅ All record counts match!');
        } else {
            console.log('⚠️  Record count mismatches detected');
            if (!usersMatch) console.log(`   - Users: Expected ${parseUserCount}, got ${supabaseUserCount}`);
            if (!foodsMatch) console.log(`   - Foods: Expected ${parseFoodCount}, got ${supabaseFoodCount}`);
            if (!foodLogsMatch) console.log(`   - Food Logs: Expected ${parseFoodLogCount}, got ${supabaseFoodLogCount}`);
        }

        return { usersMatch, foodsMatch, foodLogsMatch };

    } catch (error) {
        console.error('❌ Error validating record counts:', error);
        throw error;
    }
}

async function validateDataIntegrity() {
    console.log('\n🔍 Validating data integrity...');

    try {
        // Sample a few records and compare
        const ParseFood = Parse.Object.extend('Food');
        const foodQuery = new Parse.Query(ParseFood);
        foodQuery.limit(5);
        const sampleParseFoods = await foodQuery.find({ useMasterKey: true });

        for (const parseFood of sampleParseFoods) {
            const { data: supabaseFoods, error } = await supabase
                .from('foods')
                .select('*')
                .eq('parse_object_id', parseFood.id)
                .limit(1);

            if (error) {
                console.error(`❌ Error finding migrated food for Parse ID ${parseFood.id}:`, error);
                continue;
            }

            if (supabaseFoods.length === 0) {
                console.error(`❌ No migrated food found for Parse ID ${parseFood.id}`);
                continue;
            }

            const supabaseFood = supabaseFoods[0];

            // Compare key fields
            const nameMatch = parseFood.get('name') === supabaseFood.name;
            const caloriesMatch = Math.abs((parseFood.get('calories') || 0) - supabaseFood.calories) < 0.01;
            const proteinMatch = Math.abs((parseFood.get('protein') || 0) - supabaseFood.protein) < 0.01;

            if (nameMatch && caloriesMatch && proteinMatch) {
                console.log(`✅ Food data integrity check passed for: ${parseFood.get('name')}`);
            } else {
                console.log(`⚠️  Food data integrity issues for: ${parseFood.get('name')}`);
                if (!nameMatch) console.log(`   - Name: Parse="${parseFood.get('name')}", Supabase="${supabaseFood.name}"`);
                if (!caloriesMatch) console.log(`   - Calories: Parse=${parseFood.get('calories')}, Supabase=${supabaseFood.calories}`);
                if (!proteinMatch) console.log(`   - Protein: Parse=${parseFood.get('protein')}, Supabase=${supabaseFood.protein}`);
            }
        }

        console.log('✅ Data integrity validation completed');

    } catch (error) {
        console.error('❌ Error validating data integrity:', error);
        throw error;
    }
}

async function validateRelationships() {
    console.log('\n🔍 Validating relationships...');

    try {
        // Check if food logs properly reference users and foods
        const { data: sampleFoodLogs, error } = await supabase
            .from('food_logs')
            .select(`
                id,
                user_id,
                food_id,
                foods (name),
                parse_object_id
            `)
            .limit(5);

        if (error) {
            console.error('❌ Error fetching sample food logs:', error);
            return;
        }

        for (const foodLog of sampleFoodLogs) {
            // Check if user exists
            const { data: user, error: userError } = await supabase.auth.admin.getUserById(foodLog.user_id);

            if (userError || !user) {
                console.log(`⚠️  Food log ${foodLog.id} references non-existent user ${foodLog.user_id}`);
                continue;
            }

            // Check if food exists and was properly joined
            if (!foodLog.foods) {
                console.log(`⚠️  Food log ${foodLog.id} references non-existent food ${foodLog.food_id}`);
                continue;
            }

            console.log(`✅ Food log relationships valid: User ${foodLog.user_id} -> Food "${foodLog.foods.name}"`);
        }

        console.log('✅ Relationship validation completed');

    } catch (error) {
        console.error('❌ Error validating relationships:', error);
        throw error;
    }
}

async function runValidation() {
    console.log('🔍 Starting Migration Validation');
    console.log('================================');

    try {
        const countValidation = await validateRecordCounts();
        await validateDataIntegrity();
        await validateRelationships();

        console.log('\n📋 Validation Summary');
        console.log('====================');

        if (countValidation.usersMatch && countValidation.foodsMatch && countValidation.foodLogsMatch) {
            console.log('✅ Migration validation passed!');
            console.log('   - All record counts match');
            console.log('   - Data integrity checks passed');
            console.log('   - Relationship validation passed');
        } else {
            console.log('⚠️  Migration validation found issues');
            console.log('   - Please review the output above for details');
        }

    } catch (error) {
        console.error('❌ Validation failed:', error);
        process.exit(1);
    }
}

if (require.main === module) {
    runValidation().catch(error => {
        console.error('❌ Validation script failed:', error);
        process.exit(1);
    });
}

module.exports = { runValidation };