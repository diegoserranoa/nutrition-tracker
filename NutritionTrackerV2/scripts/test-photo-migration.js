#!/usr/bin/env node

/**
 * Test script to verify that photo URLs get migrated correctly from Parse FoodLogs
 */

const Parse = require('parse/node');
const { createClient } = require('@supabase/supabase-js');

// Configuration
const PARSE_CONFIG = {
    applicationId: 'Cxml0IqeRVKxbBXNWrNEOoIDQ82bvZYsHtbdvUo2',
    masterKey: 'CmtS4p8Wcrhg71Z9AYcEdbeV9e0i5iXuTT3vsoDd',
    serverURL: 'https://parseapi.back4app.com',
};

// Initialize Parse
Parse.initialize(PARSE_CONFIG.applicationId);
Parse.masterKey = PARSE_CONFIG.masterKey;
Parse.serverURL = PARSE_CONFIG.serverURL;

function generateUUID() {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
        const r = Math.random() * 16 | 0;
        const v = c === 'x' ? r : (r & 0x3 | 0x8);
        return v.toString(16);
    });
}

function transformParseFoodLogPhoto(parseFoodLog) {
    // Extract photo URL if available
    const photo = parseFoodLog.get('photo');
    let photoUrl = null;
    if (photo && photo.url && typeof photo.url === 'function') {
        photoUrl = photo.url();
    } else if (photo && photo._url) {
        photoUrl = photo._url;
    }

    return {
        id: generateUUID(),
        user_id: 'test-user-id',
        food_id: 'test-food-id',
        quantity: parseFoodLog.get('servingSize') || 1,
        unit: 'serving',
        total_grams: null,
        meal_type: 'other',
        logged_at: parseFoodLog.get('date') || parseFoodLog.get('createdAt'),
        created_at: parseFoodLog.get('createdAt'),
        updated_at: parseFoodLog.get('updatedAt'),
        notes: null,
        brand: null,
        custom_name: null,
        is_deleted: false,
        sync_status: 'synced',
        photo_url: photoUrl, // This is what we're testing
    };
}

async function testPhotoMigration() {
    console.log('🧪 Testing photo migration...');

    try {
        // Find food logs with photos
        const ParseFoodLog = Parse.Object.extend('FoodLog');
        const query = new Parse.Query(ParseFoodLog);
        query.exists('photo');
        query.limit(3);

        const foodLogsWithPhotos = await query.find({ useMasterKey: true });

        console.log(`Found ${foodLogsWithPhotos.length} food logs with photos to test`);

        foodLogsWithPhotos.forEach((foodLog, index) => {
            console.log(`\n📋 Testing FoodLog ${index + 1}:`);

            const photo = foodLog.get('photo');
            console.log(`   Parse photo object:`, photo);
            console.log(`   Parse photo URL: ${photo.url()}`);

            const transformed = transformParseFoodLogPhoto(foodLog);
            console.log(`   Transformed photo_url: ${transformed.photo_url}`);

            if (transformed.photo_url) {
                console.log(`   ✅ Photo URL successfully extracted!`);

                // Verify it's a valid URL
                try {
                    new URL(transformed.photo_url);
                    console.log(`   ✅ Photo URL is valid!`);
                } catch (e) {
                    console.log(`   ❌ Photo URL is not valid: ${e.message}`);
                }
            } else {
                console.log(`   ❌ Photo URL not extracted`);
            }
        });

        // Test food log without photo
        const noPhotoQuery = new Parse.Query(ParseFoodLog);
        noPhotoQuery.doesNotExist('photo');
        noPhotoQuery.limit(1);

        const foodLogWithoutPhoto = await noPhotoQuery.first({ useMasterKey: true });
        if (foodLogWithoutPhoto) {
            console.log(`\n📋 Testing FoodLog without photo:`);
            const transformed = transformParseFoodLogPhoto(foodLogWithoutPhoto);
            console.log(`   Photo URL: ${transformed.photo_url}`);
            if (transformed.photo_url === null) {
                console.log(`   ✅ Correctly handles missing photo (null)`);
            } else {
                console.log(`   ❌ Should be null for missing photo`);
            }
        }

        console.log(`\n📊 Photo migration test completed!`);

    } catch (error) {
        console.error('❌ Error testing photo migration:', error.message);
    }
}

testPhotoMigration().catch(error => {
    console.error('❌ Test failed:', error);
    process.exit(1);
});