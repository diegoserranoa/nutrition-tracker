#!/usr/bin/env node

/**
 * Test script to check what fields are available in Parse FoodLog objects
 * This helps us understand what photo data is available for migration
 */

const Parse = require('parse/node');

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

async function testFoodLogFields() {
    console.log('🔍 Testing Parse FoodLog fields...');

    try {
        const ParseFoodLog = Parse.Object.extend('FoodLog');
        const query = new Parse.Query(ParseFoodLog);
        query.limit(10); // Test more items to find photos

        const foodLogs = await query.find({ useMasterKey: true });

        console.log(`Found ${foodLogs.length} food log items to analyze`);

        let photoCount = 0;

        foodLogs.forEach((foodLog, index) => {
            console.log(`\n📋 FoodLog ${index + 1}:`);

            // Check for photo-related fields
            const photo = foodLog.get('photo');
            const image = foodLog.get('image');
            const picture = foodLog.get('picture');
            const attachment = foodLog.get('attachment');

            console.log(`   photo: ${photo ? 'EXISTS' : 'null'}`);
            console.log(`   image: ${image ? 'EXISTS' : 'null'}`);
            console.log(`   picture: ${picture ? 'EXISTS' : 'null'}`);
            console.log(`   attachment: ${attachment ? 'EXISTS' : 'null'}`);

            if (photo || image || picture || attachment) {
                photoCount++;
                console.log(`   ✅ Has photo data!`);

                // Show details of the photo field
                if (photo) {
                    console.log(`   Photo details: ${JSON.stringify(photo, null, 2)}`);
                }
                if (image) {
                    console.log(`   Image details: ${JSON.stringify(image, null, 2)}`);
                }
            }

            // Show all available fields for the first item
            if (index === 0) {
                console.log(`\n🔍 All fields for FoodLog ${index + 1}:`);
                const attributes = foodLog.attributes;
                Object.keys(attributes).sort().forEach(key => {
                    const value = attributes[key];
                    if (value !== null && value !== undefined) {
                        if (typeof value === 'object' && value._type === 'File') {
                            console.log(`   ${key}: [Parse File] ${value._name || value.name()}`);
                        } else {
                            console.log(`   ${key}: ${value}`);
                        }
                    }
                });
            }
        });

        // Check if any food logs have photos
        const photoQuery = new Parse.Query(ParseFoodLog);
        photoQuery.exists('photo');
        const foodLogsWithPhotos = await photoQuery.count({ useMasterKey: true });

        console.log(`\n📊 Summary:`);
        console.log(`   Total food logs with photos: ${foodLogsWithPhotos}`);
        console.log(`   Food logs with photos in sample: ${photoCount}/${foodLogs.length}`);

    } catch (error) {
        console.error('❌ Error testing FoodLog fields:', error.message);
    }
}

// Load environment variables if available
try {
    require('dotenv').config();
} catch (e) {
    // dotenv not available, use hardcoded config
}

testFoodLogFields().catch(error => {
    console.error('❌ Test failed:', error);
    process.exit(1);
});