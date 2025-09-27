#!/usr/bin/env node

/**
 * Connection Test Script
 *
 * This script tests connections to both Parse and Supabase
 * to ensure the migration environment is properly configured.
 */

const Parse = require('parse/node');
const { createClient } = require('@supabase/supabase-js');

// Configuration
const PARSE_CONFIG = {
    applicationId: process.env.PARSE_APPLICATION_ID,
    masterKey: process.env.PARSE_MASTER_KEY,
    serverURL: process.env.PARSE_SERVER_URL,
};

const SUPABASE_CONFIG = {
    url: process.env.SUPABASE_URL,
    serviceKey: process.env.SUPABASE_SERVICE_ROLE_KEY,
};

async function testParseConnection() {
    console.log('🔍 Testing Parse connection...');

    try {
        // Initialize Parse
        Parse.initialize(PARSE_CONFIG.applicationId);
        Parse.masterKey = PARSE_CONFIG.masterKey;
        Parse.serverURL = PARSE_CONFIG.serverURL;

        // Test with a simple query
        const TestQuery = Parse.Object.extend('Food');
        const query = new Parse.Query(TestQuery);
        query.limit(1);

        const results = await query.find({ useMasterKey: true });

        console.log('✅ Parse connection successful');
        console.log(`   - Server: ${PARSE_CONFIG.serverURL}`);
        console.log(`   - App ID: ${PARSE_CONFIG.applicationId}`);
        console.log(`   - Sample query returned ${results.length} result(s)`);

        // Get rough counts
        const userQuery = new Parse.Query('_User');
        const foodQuery = new Parse.Query('Food');
        const foodLogQuery = new Parse.Query('FoodLog');

        const [userCount, foodCount, foodLogCount] = await Promise.all([
            userQuery.count({ useMasterKey: true }).catch(() => 0),
            foodQuery.count({ useMasterKey: true }).catch(() => 0),
            foodLogQuery.count({ useMasterKey: true }).catch(() => 0),
        ]);

        console.log('📊 Parse data overview:');
        console.log(`   - Users: ${userCount}`);
        console.log(`   - Foods: ${foodCount}`);
        console.log(`   - Food Logs: ${foodLogCount}`);

        return true;

    } catch (error) {
        console.error('❌ Parse connection failed:', error.message);
        console.error('   Please check your Parse configuration');
        return false;
    }
}

async function testSupabaseConnection() {
    console.log('\n🔍 Testing Supabase connection...');

    try {
        const supabase = createClient(SUPABASE_CONFIG.url, SUPABASE_CONFIG.serviceKey);

        // Test basic connection
        const { data, error } = await supabase
            .from('foods')
            .select('id')
            .limit(1);

        if (error && error.code !== 'PGRST116') { // PGRST116 is "no rows found" which is OK
            throw error;
        }

        console.log('✅ Supabase connection successful');
        console.log(`   - URL: ${SUPABASE_CONFIG.url}`);
        console.log(`   - Service role access: ✓`);

        // Test auth admin access
        try {
            const { data: authData, error: authError } = await supabase.auth.admin.listUsers();
            if (authError) {
                console.log('⚠️  Auth admin access limited:', authError.message);
            } else {
                console.log(`   - Auth admin access: ✓ (${authData.users.length} users)`);
            }
        } catch (authError) {
            console.log('⚠️  Auth admin access test failed:', authError.message);
        }

        // Check table existence and get counts
        const tables = ['foods', 'food_logs'];
        console.log('📊 Supabase table status:');

        for (const table of tables) {
            try {
                const { count, error: countError } = await supabase
                    .from(table)
                    .select('*', { count: 'exact', head: true });

                if (countError) {
                    console.log(`   - ${table}: ❌ ${countError.message}`);
                } else {
                    console.log(`   - ${table}: ✅ (${count || 0} records)`);
                }
            } catch (tableError) {
                console.log(`   - ${table}: ❌ ${tableError.message}`);
            }
        }

        return true;

    } catch (error) {
        console.error('❌ Supabase connection failed:', error.message);
        console.error('   Please check your Supabase configuration');
        return false;
    }
}

async function testEnvironmentVariables() {
    console.log('\n🔍 Testing environment variables...');

    const requiredVars = {
        'PARSE_APPLICATION_ID': process.env.PARSE_APPLICATION_ID,
        'PARSE_MASTER_KEY': process.env.PARSE_MASTER_KEY,
        'PARSE_SERVER_URL': process.env.PARSE_SERVER_URL,
        'SUPABASE_URL': process.env.SUPABASE_URL,
        'SUPABASE_SERVICE_ROLE_KEY': process.env.SUPABASE_SERVICE_ROLE_KEY,
    };

    let allSet = true;

    for (const [varName, value] of Object.entries(requiredVars)) {
        if (!value) {
            console.log(`❌ ${varName}: Not set`);
            allSet = false;
        } else {
            // Mask sensitive values
            let displayValue = value;
            if (varName.includes('KEY') || varName.includes('MASTER')) {
                displayValue = value.substring(0, 8) + '...' + value.substring(value.length - 4);
            }
            console.log(`✅ ${varName}: ${displayValue}`);
        }
    }

    return allSet;
}

async function runConnectionTests() {
    console.log('🧪 Parse to Supabase Migration - Connection Tests');
    console.log('=================================================');

    try {
        const envOk = await testEnvironmentVariables();
        if (!envOk) {
            console.log('\n❌ Environment variable check failed');
            console.log('Please set all required environment variables and try again.');
            process.exit(1);
        }

        const parseOk = await testParseConnection();
        const supabaseOk = await testSupabaseConnection();

        console.log('\n📋 Test Summary');
        console.log('===============');

        if (parseOk && supabaseOk) {
            console.log('✅ All connection tests passed!');
            console.log('   Your environment is ready for migration.');
            console.log('\n🚀 Next steps:');
            console.log('   1. Review the migration plan in README.md');
            console.log('   2. Run the migration: npm run migrate');
            console.log('   3. Validate results: npm run validate-data');
        } else {
            console.log('❌ Some connection tests failed');
            console.log('   Please fix the issues above before running migration.');

            if (!parseOk) {
                console.log('\n🔧 Parse troubleshooting:');
                console.log('   - Verify your Parse server URL');
                console.log('   - Check your application ID and master key');
                console.log('   - Ensure master key has proper permissions');
            }

            if (!supabaseOk) {
                console.log('\n🔧 Supabase troubleshooting:');
                console.log('   - Verify your project URL');
                console.log('   - Check your service role key');
                console.log('   - Ensure required tables exist');
                console.log('   - Verify RLS policies allow service role access');
            }
        }

    } catch (error) {
        console.error('❌ Connection test failed:', error);
        process.exit(1);
    }
}

if (require.main === module) {
    // Load environment variables if dotenv is available
    try {
        require('dotenv').config();
    } catch (e) {
        // dotenv not installed, use system env vars
    }

    runConnectionTests().catch(error => {
        console.error('❌ Test script failed:', error);
        process.exit(1);
    });
}

module.exports = { testParseConnection, testSupabaseConnection };