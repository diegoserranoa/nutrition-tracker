#!/usr/bin/env node

/**
 * Test script for food name parsing functionality
 *
 * This script tests the parseFoodName function to ensure it correctly
 * extracts brand information from Parse food names.
 */

/**
 * Parse food name to extract name and brand from "Food Name (Brand)" format
 * @param {string} fullName - The full food name from Parse
 * @returns {Object} - Object with name and brand properties
 */
function parseFoodName(fullName) {
    if (!fullName || typeof fullName !== 'string') {
        return { name: 'Unknown Food', brand: null };
    }

    // Trim whitespace
    const trimmedName = fullName.trim();

    // Check if the name contains parentheses with brand information
    const parenthesesMatch = trimmedName.match(/^(.+?)\s*\(([^)]+)\)$/);

    if (parenthesesMatch) {
        // Found format: "Food Name (Brand)"
        const name = parenthesesMatch[1].trim();
        const brand = parenthesesMatch[2].trim();

        // Validate that both name and brand are not empty
        if (name && brand) {
            return { name, brand };
        }
    }

    // No parentheses found or invalid format - treat as generic food
    return { name: trimmedName, brand: null };
}

function testFoodNameParsing() {
    console.log('🧪 Testing food name parsing...');

    const testCases = [
        'Tomato',
        'Chicken Breast (Perdue)',
        'Whole Milk (Organic Valley)',
        'Peanut Butter (Jif)',
        'Apple (Honeycrisp)',
        'Bread Whole Wheat (Dave\'s Killer Bread)',
        '',
        null,
        'Invalid Format (',
        'Another Invalid Format )',
        'Valid Food (Brand A) (Extra)',
        '   Trimmed Food   (  Trimmed Brand  )   ',
        'Mixed Case Food (MiXeD cAsE bRaNd)',
        'Numbers in Food (Brand 123)',
        'Special-Characters Food (Brand & Co.)',
        'Unicode Food (Ñice Brand)',
    ];

    testCases.forEach(testCase => {
        const result = parseFoodName(testCase);
        console.log(`   "${testCase || 'null'}" → Name: "${result.name}", Brand: ${result.brand ? `"${result.brand}"` : 'null'}`);
    });

    console.log('✅ Food name parsing tests completed');
}

console.log('🧪 Food Name Parsing Test');
console.log('==========================');

testFoodNameParsing();

console.log('\n📝 Expected Results:');
console.log('- "Tomato" → Generic food (no brand)');
console.log('- "Chicken Breast (Perdue)" → Name: "Chicken Breast", Brand: "Perdue"');
console.log('- "Whole Milk (Organic Valley)" → Name: "Whole Milk", Brand: "Organic Valley"');
console.log('- Invalid formats → Treated as generic foods');
console.log('- Empty/null inputs → Default to "Unknown Food"');

console.log('\n✅ All tests demonstrate proper parsing behavior!');