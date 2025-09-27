#!/usr/bin/env node

/**
 * Test script to migrate just a few food logs with photos as a verification
 */

const Parse = require('parse/node');
const { createClient } = require('@supabase/supabase-js');
const { parseFoodName } = require('./parse-to-supabase-migration.js');

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

async function testLimitedPhotoMigration() {
    console.log('🧪 Testing limited food log photo migration...');

    try {
        // Check how many food logs with photos already exist in Supabase
        const { data: existingFoodLogs, error: existingError } = await supabase
            .from('food_logs')
            .select('id, photo_url')
            .not('photo_url', 'is', null);

        if (existingError) {
            console.log('Note: Could not check existing food logs:', existingError.message);
        } else {
            console.log(`📊 Existing food logs with photos in Supabase: ${existingFoodLogs?.length || 0}`);
        }

        // Check total food logs in Supabase
        const { count: totalCount, error: countError } = await supabase
            .from('food_logs')
            .select('*', { count: 'exact', head: true });

        if (!countError) {
            console.log(`📊 Total food logs in Supabase: ${totalCount}`);
        }

        // Get one Parse food log with photo to verify our migration logic
        const ParseFoodLog = Parse.Object.extend('FoodLog');
        const query = new Parse.Query(ParseFoodLog);
        query.exists('photo');
        query.limit(1);

        const parseLogWithPhoto = await query.first({ useMasterKey: true });

        if (parseLogWithPhoto) {
            console.log(`\n🔍 Found Parse food log with photo:`);
            const photo = parseLogWithPhoto.get('photo');
            console.log(`   Photo URL: ${photo.url()}`);
            console.log(`   Date: ${parseLogWithPhoto.get('date')}`);
            console.log(`   Serving size: ${parseLogWithPhoto.get('servingSize')}`);

            // Test if this food log already exists in Supabase
            const loggedAt = parseLogWithPhoto.get('date') || parseLogWithPhoto.get('createdAt');
            const { data: existingLog, error: searchError } = await supabase
                .from('food_logs')
                .select('id, photo_url, logged_at')
                .eq('logged_at', loggedAt.toISOString())
                .limit(1);

            if (!searchError && existingLog && existingLog.length > 0) {
                console.log(`   📋 Found matching food log in Supabase:`);
                console.log(`      ID: ${existingLog[0].id}`);
                console.log(`      Photo URL: ${existingLog[0].photo_url}`);
                console.log(`      Logged at: ${existingLog[0].logged_at}`);

                if (existingLog[0].photo_url) {
                    console.log(`   ✅ This food log already has photo data!`);
                } else {
                    console.log(`   ❌ This food log is missing photo data`);
                }
            } else {
                console.log(`   📋 No matching food log found in Supabase (may need to migrate)`);
            }
        }

        console.log(`\n💡 To migrate photos for existing food logs:`);
        console.log(`   1. Clear existing food logs: DELETE FROM food_logs;`);
        console.log(`   2. Re-run migration: npm run migrate:foodlogs`);
        console.log(`   3. Or run full migration: npm run migrate`);

    } catch (error) {
        console.error('❌ Error testing limited photo migration:', error.message);
    }
}

testLimitedPhotoMigration().catch(error => {
    console.error('❌ Test failed:', error);
    process.exit(1);
});