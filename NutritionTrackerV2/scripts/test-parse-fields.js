#!/usr/bin/env node

/**
 * Test script to check what fields are available in Parse Food objects
 * This helps us understand what data is actually available for migration
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

async function testParseFields() {
    console.log('🔍 Testing Parse Food fields...');

    try {
        const ParseFood = Parse.Object.extend('Food');
        const query = new Parse.Query(ParseFood);
        query.limit(5); // Just test a few items

        const foods = await query.find({ useMasterKey: true });

        console.log(`Found ${foods.length} food items to analyze`);

        foods.forEach((food, index) => {
            console.log(`\n📋 Food ${index + 1}: ${food.get('name')}`);

            // Check sugar-related fields
            const totalSugars = food.get('totalSugars');
            const addedSugars = food.get('addedSugars');

            console.log(`   totalSugars: ${totalSugars}`);
            console.log(`   addedSugars: ${addedSugars}`);

            // Check if addedSugars has any value
            if (addedSugars !== undefined && addedSugars !== null) {
                console.log(`   ✅ Has addedSugars data: ${addedSugars}`);
            } else {
                console.log(`   ❌ No addedSugars data`);
            }

            // Show all available fields for the first item
            if (index === 0) {
                console.log(`\n🔍 All fields for "${food.get('name')}":`);
                const attributes = food.attributes;
                Object.keys(attributes).sort().forEach(key => {
                    const value = attributes[key];
                    if (value !== null && value !== undefined) {
                        console.log(`   ${key}: ${value}`);
                    }
                });
            }
        });

        // Check if any foods have addedSugars
        const addedSugarsQuery = new Parse.Query(ParseFood);
        addedSugarsQuery.exists('addedSugars');
        const foodsWithAddedSugars = await addedSugarsQuery.count({ useMasterKey: true });

        console.log(`\n📊 Summary:`);
        console.log(`   Total foods with addedSugars field: ${foodsWithAddedSugars}`);

    } catch (error) {
        console.error('❌ Error testing Parse fields:', error.message);
    }
}

// Load environment variables if available
try {
    require('dotenv').config();
} catch (e) {
    // dotenv not available, use hardcoded config
}

testParseFields().catch(error => {
    console.error('❌ Test failed:', error);
    process.exit(1);
});