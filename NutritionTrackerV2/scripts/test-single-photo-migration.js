#!/usr/bin/env node

/**
 * Test script to migrate a single food log with photo to verify the complete workflow
 */

const Parse = require('parse/node');
const { createClient } = require('@supabase/supabase-js');

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

// Import functions from main migration script
const { migratePhotoToSupabase } = require('./parse-to-supabase-migration.js');

async function testSinglePhotoMigration() {
    console.log('🧪 Testing single photo migration...');

    try {
        // Find one food log with photo
        const ParseFoodLog = Parse.Object.extend('FoodLog');
        const query = new Parse.Query(ParseFoodLog);
        query.exists('photo');
        query.limit(1);

        const foodLogWithPhoto = await query.first({ useMasterKey: true });

        if (!foodLogWithPhoto) {
            console.log('❌ No food logs with photos found');
            return;
        }

        console.log(`\n📋 Found FoodLog with photo:`);
        console.log(`   FoodLog ID: ${foodLogWithPhoto.id}`);
        console.log(`   Date: ${foodLogWithPhoto.get('date')}`);

        const photo = foodLogWithPhoto.get('photo');
        const parsePhotoUrl = photo.url();
        console.log(`   Parse photo URL: ${parsePhotoUrl}`);

        // Generate unique filename
        const timestamp = foodLogWithPhoto.get('createdAt').getTime();
        const fileName = `test_foodlog_${foodLogWithPhoto.id}_${timestamp}.jpg`;

        // Migrate photo
        console.log(`\n🚀 Starting photo migration...`);
        const supabasePhotoUrl = await migratePhotoToSupabase(parsePhotoUrl, supabase, fileName);

        if (supabasePhotoUrl) {
            console.log(`\n✅ Photo migration successful!`);
            console.log(`   Original Parse URL: ${parsePhotoUrl}`);
            console.log(`   New Supabase URL: ${supabasePhotoUrl}`);

            // Test accessing the Supabase URL
            try {
                console.log(`\n🌐 Testing Supabase URL accessibility...`);
                const response = await fetch(supabasePhotoUrl, { method: 'HEAD' });
                if (response.ok) {
                    console.log(`✅ Supabase photo is accessible (Status: ${response.status})`);
                } else {
                    console.log(`⚠️ Supabase photo returned status: ${response.status}`);
                }
            } catch (fetchError) {
                console.log(`❌ Error testing Supabase URL: ${fetchError.message}`);
            }
        } else {
            console.log(`\n❌ Photo migration failed!`);
        }

    } catch (error) {
        console.error('❌ Test failed:', error.message);
    }
}

testSinglePhotoMigration().catch(error => {
    console.error('❌ Test error:', error);
    process.exit(1);
});