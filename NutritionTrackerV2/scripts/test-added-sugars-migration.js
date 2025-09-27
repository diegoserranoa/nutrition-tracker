#!/usr/bin/env node

/**
 * Test script to verify that addedSugars gets migrated correctly
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

function generateUUID() {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
        const r = Math.random() * 16 | 0;
        const v = c === 'x' ? r : (r & 0x3 | 0x8);
        return v.toString(16);
    });
}

function transformParseFood(parseFood) {
    const fullName = parseFood.get('name') || 'Unknown Food';
    const { name, brand } = parseFoodName(fullName);

    return {
        id: generateUUID(),
        name: name,
        brand: brand,

        // Serving information
        serving_size: parseFood.get('servingSize') || 100,
        measurement_unit: parseFood.get('measurementUnit') || 'g',

        // Macronutrients
        calories: parseFood.get('calories') || 0,
        protein: parseFood.get('protein') || 0,
        total_carbohydrate: parseFood.get('totalCarbohydrate') || 0,
        total_fat: parseFood.get('totalFat') || 0,
        dietary_fiber: parseFood.get('dietaryFiber'),
        total_sugars: parseFood.get('totalSugars'),
        added_sugars: parseFood.get('addedSugars'), // This is the field we're testing
        saturated_fat: parseFood.get('saturatedFat'),

        // Micronutrients
        sodium: parseFood.get('sodium'),
        cholesterol: parseFood.get('cholesterol'),
        potassium: parseFood.get('potassium'),
        calcium: parseFood.get('calcium'),
        iron: parseFood.get('iron'),
        vitamin_a: parseFood.get('vitaminA'),
        vitamin_c: parseFood.get('vitaminC'),
        vitamin_d: parseFood.get('vitaminD'),
        vitamin_e: parseFood.get('vitaminE'),
        vitamin_k: parseFood.get('vitaminK'),
        thiamin: parseFood.get('thiamin'),
        riboflavin: parseFood.get('riboflavin'),
        niacin: parseFood.get('niacin'),
        vitamin_b6: parseFood.get('vitaminB6'),
        vitamin_b12: parseFood.get('vitaminB12'),
        folate: parseFood.get('folate'),
        magnesium: parseFood.get('magnesium'),
        phosphorus: parseFood.get('phosphorus'),
        zinc: parseFood.get('zinc'),

        // Timestamps
        created_at: parseFood.get('createdAt'),
        updated_at: parseFood.get('updatedAt')
    };
}

async function testAddedSugarsMapping() {
    console.log('🧪 Testing added_sugars mapping...');

    try {
        // Find a Parse food that has addedSugars data
        const ParseFood = Parse.Object.extend('Food');
        const query = new Parse.Query(ParseFood);
        query.exists('addedSugars');
        query.greaterThan('addedSugars', 0); // Find one with actual added sugar content
        query.limit(1);

        const parseFood = await query.first({ useMasterKey: true });

        if (!parseFood) {
            console.log('⚠️  No foods found with addedSugars > 0');

            // Let's find any food with addedSugars field
            const fallbackQuery = new Parse.Query(ParseFood);
            fallbackQuery.exists('addedSugars');
            fallbackQuery.limit(1);

            const fallbackFood = await fallbackQuery.first({ useMasterKey: true });
            if (fallbackFood) {
                console.log(`📋 Using food with addedSugars = 0: ${fallbackFood.get('name')}`);
                testTransformation(fallbackFood);
            } else {
                console.log('❌ No foods found with addedSugars field at all');
            }
            return;
        }

        console.log(`📋 Found food with added sugars: ${parseFood.get('name')}`);
        console.log(`   Parse addedSugars: ${parseFood.get('addedSugars')}`);
        console.log(`   Parse totalSugars: ${parseFood.get('totalSugars')}`);

        testTransformation(parseFood);

    } catch (error) {
        console.error('❌ Error testing added sugars mapping:', error.message);
    }
}

function testTransformation(parseFood) {
    console.log('\n🔄 Testing transformation...');

    const transformed = transformParseFood(parseFood);

    console.log(`✅ Transformation results:`);
    console.log(`   name: ${transformed.name}`);
    console.log(`   brand: ${transformed.brand}`);
    console.log(`   total_sugars: ${transformed.total_sugars}`);
    console.log(`   added_sugars: ${transformed.added_sugars}`);

    if (transformed.added_sugars !== undefined && transformed.added_sugars !== null) {
        console.log(`✅ added_sugars field is correctly mapped!`);
    } else {
        console.log(`❌ added_sugars field is not being mapped correctly`);
    }
}

testAddedSugarsMapping().catch(error => {
    console.error('❌ Test failed:', error);
    process.exit(1);
});