#!/usr/bin/env node

/**
 * Test script to specifically examine FoodLog items that have photos
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

async function testFoodLogPhotos() {
    console.log('🔍 Testing Parse FoodLog photos specifically...');

    try {
        const ParseFoodLog = Parse.Object.extend('FoodLog');

        // Query for food logs that have photos
        const query = new Parse.Query(ParseFoodLog);
        query.exists('photo');
        query.limit(5); // Just get a few examples

        const foodLogsWithPhotos = await query.find({ useMasterKey: true });

        console.log(`Found ${foodLogsWithPhotos.length} food log items with photos`);

        foodLogsWithPhotos.forEach((foodLog, index) => {
            console.log(`\n📋 FoodLog with Photo ${index + 1}:`);

            const photo = foodLog.get('photo');
            console.log(`   Photo object:`, photo);

            if (photo && photo._name) {
                console.log(`   Photo name: ${photo._name}`);
            }
            if (photo && photo._url) {
                console.log(`   Photo URL: ${photo._url}`);
            }
            if (photo && typeof photo.url === 'function') {
                console.log(`   Photo URL (method): ${photo.url()}`);
            }

            // Show basic food log info
            console.log(`   Date: ${foodLog.get('date')}`);
            console.log(`   Serving size: ${foodLog.get('servingSize')}`);

            // Show all fields to understand structure
            if (index === 0) {
                console.log(`\n🔍 All fields for first photo food log:`);
                const attributes = foodLog.attributes;
                Object.keys(attributes).sort().forEach(key => {
                    const value = attributes[key];
                    if (value !== null && value !== undefined) {
                        if (typeof value === 'object' && value._type === 'File') {
                            console.log(`   ${key}: [Parse File] name=${value._name}, url=${value._url}`);
                        } else if (typeof value === 'object' && value.className) {
                            console.log(`   ${key}: [Parse Object] ${value.className}:${value.id}`);
                        } else {
                            console.log(`   ${key}: ${value}`);
                        }
                    }
                });
            }
        });

        // Get total count of food logs with photos
        const totalCount = await query.count({ useMasterKey: true });
        console.log(`\n📊 Summary:`);
        console.log(`   Total food logs with photos: ${totalCount}`);

    } catch (error) {
        console.error('❌ Error testing FoodLog photos:', error.message);
    }
}

testFoodLogPhotos().catch(error => {
    console.error('❌ Test failed:', error);
    process.exit(1);
});