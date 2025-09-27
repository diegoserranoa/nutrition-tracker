#!/usr/bin/env node

/**
 * Test script to verify the updated serving_size field mapping
 */

const Parse = require('parse/node');
const { createClient } = require('@supabase/supabase-js');
const { transformParseFoodLog, generateUUID } = require('./parse-to-supabase-migration.js');

// Configuration
const PARSE_CONFIG = {
    applicationId: 'Cxml0IqeRVKxbBXNWrNEOoIDQ82bvZYsHtbdvUo2',
    masterKey: 'CmtS4p8Wcrhg71Z9AYcEdbeV9e0i5iXuTT3vsoDd',
    serverURL: 'https://parseapi.back4app.com',
};

const SUPABASE_CONFIG = {
    url: 'https://hcskwwdqmgilvasqeqxh.supabase.co',
    serviceKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhjc2t3d2RxbWdpbHZhc3FlcXhoIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1ODU4NTIzNSwiZXhwIjoyMDc0MTYxMjM1fQ.9HYTSYaZOspxMqHEnv31BLoXVxGaz95VNjZ_L7fW21k',
};

// Initialize clients
Parse.initialize(PARSE_CONFIG.applicationId);
Parse.masterKey = PARSE_CONFIG.masterKey;
Parse.serverURL = PARSE_CONFIG.serverURL;

const supabase = createClient(SUPABASE_CONFIG.url, SUPABASE_CONFIG.serviceKey);

async function testServingSizeMapping() {
    console.log('🧪 Testing serving_size field mapping...');

    try {
        // Get a few Parse food logs with different serving sizes
        const ParseFoodLog = Parse.Object.extend('FoodLog');
        const query = new Parse.Query(ParseFoodLog);
        query.limit(5);

        const parseFoodLogs = await query.find({ useMasterKey: true });

        console.log(`📊 Found ${parseFoodLogs.length} Parse food logs to test`);

        // Create mock user and food mappings for testing
        const mockUserMap = {};
        const mockFoodMap = {};

        // Populate mock mappings
        for (const foodLog of parseFoodLogs) {
            const userId = foodLog.get('user')?.id;
            const foodId = foodLog.get('food')?.id;

            if (userId && !mockUserMap[userId]) {
                mockUserMap[userId] = generateUUID();
            }
            if (foodId && !mockFoodMap[foodId]) {
                mockFoodMap[foodId] = generateUUID();
            }
        }

        console.log('\n📋 Testing field mapping transformation:');

        for (let i = 0; i < parseFoodLogs.length; i++) {
            const parseFoodLog = parseFoodLogs[i];
            const originalServingSize = parseFoodLog.get('servingSize');

            try {
                console.log(`\n${i + 1}. Testing FoodLog ${parseFoodLog.id}:`);
                console.log(`   Original Parse servingSize: ${originalServingSize}`);

                const transformed = await transformParseFoodLog(parseFoodLog, mockUserMap, mockFoodMap, supabase);

                console.log(`   Transformed Supabase fields:`);
                console.log(`     quantity: ${transformed.quantity} (should be 1 for default)`);
                console.log(`     serving_size: ${transformed.serving_size} (should match Parse servingSize: ${originalServingSize})`);
                console.log(`     unit: ${transformed.unit}`);

                // Verify mapping is correct
                if (transformed.serving_size === originalServingSize) {
                    console.log(`     ✅ serving_size mapping is correct!`);
                } else {
                    console.log(`     ❌ serving_size mapping is incorrect!`);
                    console.log(`        Expected: ${originalServingSize}, Got: ${transformed.serving_size}`);
                }

                if (transformed.quantity === 1) {
                    console.log(`     ✅ quantity default is correct!`);
                } else {
                    console.log(`     ⚠️ quantity is not default value (expected 1, got ${transformed.quantity})`);
                }

            } catch (error) {
                console.log(`     ❌ Transformation failed: ${error.message}`);
            }
        }

        console.log('\n📊 Field Mapping Summary:');
        console.log('   Parse servingSize → Supabase serving_size (actual consumed amount)');
        console.log('   Default quantity = 1 (number of servings)');
        console.log('   Default unit = "serving"');

    } catch (error) {
        console.error('❌ Test failed:', error.message);
    }
}

testServingSizeMapping().catch(error => {
    console.error('❌ Test error:', error);
    process.exit(1);
});