#!/usr/bin/env node

/**
 * Parse to Supabase Migration Script
 *
 * This script migrates data from Parse Server to Supabase for the Nutrition Tracker app.
 *
 * Schema Analysis:
 * Parse Schema:
 * - _User: Standard Parse user with username, email, password
 * - Food: Nutrition data with extensive vitamin/mineral fields
 * - FoodLog: User food consumption logs (pointer to Food and User)
 * - Meal: Collection of ingredients (seems unused in current app)
 * - Ingredient: Components of meals (seems unused in current app)
 *
 * Supabase Schema:
 * - auth.users: Supabase auth users
 * - foods: Enhanced food model with categories and verification
 * - food_logs: Enhanced food logs with meal types and soft delete
 *
 * Usage:
 *   node parse-to-supabase-migration.js                    # Migrate all tables
 *   node parse-to-supabase-migration.js --tables=foods     # Migrate only foods table
 *   node parse-to-supabase-migration.js --tables=users,foods # Migrate users and foods
 *   node parse-to-supabase-migration.js --help             # Show help
 *
 * Available tables: users, foods, foodlogs
 */

const Parse = require('parse/node');
const { createClient } = require('@supabase/supabase-js');
const crypto = require('crypto');
const https = require('https');
const http = require('http');

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

// Initialize Parse client
Parse.initialize(PARSE_CONFIG.applicationId);
Parse.masterKey = PARSE_CONFIG.masterKey;
Parse.serverURL = PARSE_CONFIG.serverURL;

// Supabase client will be initialized in functions

// Migration statistics
const stats = {
    users: { total: 0, migrated: 0, existing: 0, created: 0, errors: 0 },
    foods: { total: 0, migrated: 0, errors: 0 },
    foodLogs: { total: 0, migrated: 0, errors: 0 },
    startTime: new Date(),
    errors: []
};

/**
 * Utility Functions
 */

function generateUUID() {
    return crypto.randomUUID();
}

function logError(type, error, data = null) {
    const errorInfo = {
        type,
        error: error.message || error,
        data,
        timestamp: new Date()
    };
    stats.errors.push(errorInfo);
    console.error(`❌ ${type}:`, error.message || error);
    if (data) {
        console.error('Data:', JSON.stringify(data, null, 2));
    }
}

function logProgress(message) {
    console.log(`🔄 ${message}`);
}

function logSuccess(message) {
    console.log(`✅ ${message}`);
}

/**
 * Data Transformation Functions
 */

/**
 * Download photo from Parse and upload to Supabase Storage
 */
async function migratePhotoToSupabase(parsePhotoUrl, supabase, fileName = null) {
    if (!parsePhotoUrl) {
        return null;
    }

    try {
        logProgress(`Downloading photo: ${fileName || 'photo'}`);

        // Download photo from Parse
        const photoBuffer = await downloadPhoto(parsePhotoUrl);

        if (!photoBuffer) {
            logError('Photo Download', new Error('Failed to download photo'), { url: parsePhotoUrl });
            return null;
        }

        // Generate unique filename if not provided
        if (!fileName) {
            const urlParts = parsePhotoUrl.split('/');
            fileName = urlParts[urlParts.length - 1] || `photo_${Date.now()}.jpg`;
        }

        // Ensure filename has extension
        if (!fileName.includes('.')) {
            fileName += '.jpg';
        }

        // Upload to Supabase Storage
        const { data, error } = await supabase.storage
            .from('food-photos')
            .upload(fileName, photoBuffer, {
                contentType: getContentType(fileName),
                upsert: true // Overwrite if exists
            });

        if (error) {
            logError('Photo Upload', error, { fileName, parseUrl: parsePhotoUrl });
            return null;
        }

        // Get public URL
        const { data: { publicUrl } } = supabase.storage
            .from('food-photos')
            .getPublicUrl(fileName);

        logProgress(`Photo migrated: ${fileName} -> ${publicUrl}`);
        return publicUrl;

    } catch (error) {
        logError('Photo Migration', error, { parseUrl: parsePhotoUrl, fileName });
        return null;
    }
}

/**
 * Download photo from URL and return buffer
 */
function downloadPhoto(url) {
    return new Promise((resolve, reject) => {
        const protocol = url.startsWith('https:') ? https : http;

        protocol.get(url, (response) => {
            if (response.statusCode !== 200) {
                reject(new Error(`HTTP ${response.statusCode}: ${response.statusMessage}`));
                return;
            }

            const chunks = [];
            response.on('data', (chunk) => chunks.push(chunk));
            response.on('end', () => resolve(Buffer.concat(chunks)));
            response.on('error', reject);
        }).on('error', reject);
    });
}

/**
 * Get content type from filename
 */
function getContentType(fileName) {
    const ext = fileName.toLowerCase().split('.').pop();
    switch (ext) {
        case 'jpg':
        case 'jpeg':
            return 'image/jpeg';
        case 'png':
            return 'image/png';
        case 'heic':
            return 'image/heic';
        case 'webp':
            return 'image/webp';
        default:
            return 'image/jpeg';
    }
}

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

function transformParseUser(parseUser) {
    return {
        id: generateUUID(),
        email: parseUser.get('email'),
        username: parseUser.get('username'),
        email_verified: parseUser.get('emailVerified') || false,
        // Note: Password migration requires special handling in Supabase
        // Users will need to reset passwords after migration
        created_at: parseUser.get('createdAt'),
        updated_at: parseUser.get('updatedAt'),
        // Store original Parse objectId for reference during migration
        parse_object_id: parseUser.id
    };
}

function transformParseFood(parseFood) {
    // Parse the food name to extract name and brand
    const fullName = parseFood.get('name') || 'Unknown Food';
    const { name, brand } = parseFoodName(fullName);

    return {
        id: generateUUID(),
        name: name,
        brand: brand,
        barcode: null, // Not present in Parse schema
        description: null, // Not present in Parse schema

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
        added_sugars: parseFood.get('addedSugars'),
        saturated_fat: parseFood.get('saturatedFat'),
        unsaturated_fat: null, // Calculate as totalFat - saturatedFat if needed
        trans_fat: null, // Not in Parse schema

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

        // Timestamps (these exist in Supabase schema)
        created_at: parseFood.get('createdAt'),
        updated_at: parseFood.get('updatedAt')

        // Note: Parse objectId stored in migration mapping for reference
    };
}

async function transformParseFoodLog(parseFoodLog, userMap, foodMap, supabase) {
    const parseUserId = parseFoodLog.get('user')?.id;
    const parseFoodId = parseFoodLog.get('food')?.id;

    if (!parseUserId || !parseFoodId) {
        throw new Error('FoodLog missing required user or food reference');
    }

    const supabaseUserId = userMap[parseUserId];
    const supabaseFoodId = foodMap[parseFoodId];

    if (!supabaseUserId || !supabaseFoodId) {
        const missingUser = !supabaseUserId ? `user ${parseUserId}` : '';
        const missingFood = !supabaseFoodId ? `food ${parseFoodId}` : '';
        const missing = [missingUser, missingFood].filter(Boolean).join(', ');
        throw new Error(`Missing mapping for ${missing} - may need to migrate users/foods first`);
    }

    // Determine meal type from date/time (Parse doesn't have meal type)
    const logDate = parseFoodLog.get('date') || parseFoodLog.get('createdAt');
    const hour = logDate.getHours();
    let mealType = 'other';

    if (hour >= 6 && hour < 11) mealType = 'breakfast';
    else if (hour >= 11 && hour < 15) mealType = 'lunch';
    else if (hour >= 15 && hour < 19) mealType = 'dinner';
    else if (hour >= 19 && hour < 23) mealType = 'dinner';
    else mealType = 'snack';

    // Extract and migrate photo if available
    const photo = parseFoodLog.get('photo');
    let photoUrl = null;
    if (photo && photo.url && typeof photo.url === 'function') {
        const parsePhotoUrl = photo.url();

        // Generate unique filename for Supabase storage
        const timestamp = parseFoodLog.get('createdAt') ? parseFoodLog.get('createdAt').getTime() : Date.now();
        const fileName = `foodlog_${parseFoodLog.id}_${timestamp}.jpg`;

        // Migrate photo file to Supabase Storage
        photoUrl = await migratePhotoToSupabase(parsePhotoUrl, supabase, fileName);

        if (!photoUrl) {
            logError('Photo Migration', new Error('Failed to migrate photo'), {
                parsePhotoUrl,
                foodLogId: parseFoodLog.id
            });
            // Fall back to original Parse URL
            photoUrl = parsePhotoUrl;
        }
    } else if (photo && photo._url) {
        const parsePhotoUrl = photo._url;

        // Generate unique filename for Supabase storage
        const timestamp = parseFoodLog.get('createdAt') ? parseFoodLog.get('createdAt').getTime() : Date.now();
        const fileName = `foodlog_${parseFoodLog.id}_${timestamp}.jpg`;

        // Migrate photo file to Supabase Storage
        photoUrl = await migratePhotoToSupabase(parsePhotoUrl, supabase, fileName);

        if (!photoUrl) {
            logError('Photo Migration', new Error('Failed to migrate photo'), {
                parsePhotoUrl,
                foodLogId: parseFoodLog.id
            });
            // Fall back to original Parse URL
            photoUrl = parsePhotoUrl;
        }
    }

    return {
        id: generateUUID(),
        user_id: supabaseUserId,
        food_id: supabaseFoodId,
        quantity: 1, // Default quantity (number of servings)
        serving_size: parseFoodLog.get('servingSize') || 1, // Correct mapping: Parse servingSize → Supabase serving_size
        unit: 'serving', // Default unit for Parse data
        total_grams: null, // Not available in Parse data
        meal_type: mealType,
        logged_at: logDate,
        created_at: parseFoodLog.get('createdAt'),
        updated_at: parseFoodLog.get('updatedAt'),
        notes: null,
        brand: null,
        custom_name: null,
        is_deleted: false,
        sync_status: 'synced',
        photo_url: photoUrl, // Migrate photo URL from Parse

        // Note: Parse objectId stored in migration mapping for reference
    };
}

/**
 * Migration Functions
 */

async function migrateUsers(supabase) {
    logProgress('Starting user migration...');

    const userMap = {};

    try {
        const ParseUser = Parse.Object.extend('_User');
        const query = new Parse.Query(ParseUser);
        query.limit(1000); // Adjust as needed

        const parseUsers = await query.find({ useMasterKey: true });
        stats.users.total = parseUsers.length;

        logProgress(`Found ${parseUsers.length} users to migrate`);

        // Fetch all existing Supabase users once to optimize performance
        logProgress('Fetching existing Supabase users...');
        const { data: existingUsersData, error: searchError } = await supabase.auth.admin.listUsers();

        if (searchError) {
            throw searchError;
        }

        // Create a map of existing users by email for fast lookup
        const existingUsersByEmail = new Map();
        existingUsersData.users.forEach(user => {
            if (user.email) {
                existingUsersByEmail.set(user.email.toLowerCase(), user);
            }
        });

        logProgress(`Found ${existingUsersByEmail.size} existing users in Supabase`);

        for (const parseUser of parseUsers) {
            try {
                const transformedUser = transformParseUser(parseUser);

                // Look for existing user by email (case insensitive)
                const existingUser = existingUsersByEmail.get(transformedUser.email.toLowerCase());

                let supabaseUserId;

                if (existingUser) {
                    // User already exists, use existing ID
                    supabaseUserId = existingUser.id;
                    stats.users.existing++;
                    logProgress(`Found existing user: ${transformedUser.email} (ID: ${supabaseUserId})`);

                    // Optionally update user metadata to include Parse info if not already present
                    if (!existingUser.user_metadata?.migrated_from_parse) {
                        const { error: updateError } = await supabase.auth.admin.updateUserById(
                            existingUser.id,
                            {
                                user_metadata: {
                                    ...existingUser.user_metadata,
                                    username: transformedUser.username,
                                    migrated_from_parse: true,
                                    parse_object_id: transformedUser.parse_object_id
                                }
                            }
                        );

                        if (updateError) {
                            logError('User Metadata Update', updateError, { email: transformedUser.email });
                        } else {
                            logProgress(`Updated metadata for existing user: ${transformedUser.email}`);
                        }
                    }
                } else {
                    // User doesn't exist, create new user
                    const { data: authData, error: authError } = await supabase.auth.admin.createUser({
                        email: transformedUser.email,
                        email_confirm: transformedUser.email_verified,
                        user_metadata: {
                            username: transformedUser.username,
                            migrated_from_parse: true,
                            parse_object_id: transformedUser.parse_object_id
                        }
                    });

                    if (authError) {
                        throw authError;
                    }

                    supabaseUserId = authData.user.id;
                    stats.users.created++;
                    logProgress(`Created new user: ${transformedUser.email} (ID: ${supabaseUserId})`);
                }

                // Map Parse user ID to Supabase user ID
                userMap[parseUser.id] = supabaseUserId;

                stats.users.migrated++;
                logProgress(`User processed: ${transformedUser.email} (${stats.users.migrated}/${stats.users.total})`);
                logProgress(`  Stats: ${stats.users.existing} existing, ${stats.users.created} created`);

            } catch (error) {
                stats.users.errors++;
                logError('User Migration', error, { parseUserId: parseUser.id, email: parseUser.get('email') });
            }
        }

        logSuccess(`User migration completed: ${stats.users.migrated}/${stats.users.total} processed (${stats.users.existing} existing, ${stats.users.created} created)`);
        return userMap;

    } catch (error) {
        logError('User Migration Query', error);
        throw error;
    }
}

async function migrateFoods(supabase) {
    logProgress('Starting food migration...');

    const foodMap = {};
    const brandStats = { withBrand: 0, generic: 0 };

    try {
        const ParseFood = Parse.Object.extend('Food');
        const query = new Parse.Query(ParseFood);
        query.limit(1000); // Adjust as needed

        const parseFoods = await query.find({ useMasterKey: true });
        stats.foods.total = parseFoods.length;

        logProgress(`Found ${parseFoods.length} foods to migrate`);

        // Batch process foods
        const batchSize = 100;
        for (let i = 0; i < parseFoods.length; i += batchSize) {
            const batch = parseFoods.slice(i, i + batchSize);
            const transformedFoods = [];

            for (const parseFood of batch) {
                try {
                    const transformedFood = transformParseFood(parseFood);
                    transformedFoods.push(transformedFood);
                    foodMap[parseFood.id] = transformedFood.id;

                    // Track brand extraction statistics
                    if (transformedFood.brand) {
                        brandStats.withBrand++;
                    } else {
                        brandStats.generic++;
                    }
                } catch (error) {
                    stats.foods.errors++;
                    logError('Food Transformation', error, { parseFoodId: parseFood.id, name: parseFood.get('name') });
                }
            }

            if (transformedFoods.length > 0) {
                const { data, error } = await supabase
                    .from('foods')
                    .insert(transformedFoods);

                if (error) {
                    stats.foods.errors += transformedFoods.length;
                    logError('Food Batch Insert', error, { batchSize: transformedFoods.length });
                } else {
                    stats.foods.migrated += transformedFoods.length;
                    logProgress(`Migrated food batch: ${stats.foods.migrated}/${stats.foods.total}`);
                }
            }
        }

        logSuccess(`Food migration completed: ${stats.foods.migrated}/${stats.foods.total} successful`);
        logProgress(`Brand extraction results: ${brandStats.withBrand} with brands, ${brandStats.generic} generic foods`);
        return foodMap;

    } catch (error) {
        logError('Food Migration Query', error);
        throw error;
    }
}

async function migrateFoodLogs(supabase, userMap, foodMap) {
    logProgress('Starting food log migration...');

    try {
        const ParseFoodLog = Parse.Object.extend('FoodLog');
        const query = new Parse.Query(ParseFoodLog);
        query.include(['user', 'food']);
        query.limit(1000); // Adjust as needed

        const parseFoodLogs = await query.find({ useMasterKey: true });
        stats.foodLogs.total = parseFoodLogs.length;

        logProgress(`Found ${parseFoodLogs.length} food logs to migrate`);

        // Batch process food logs
        const batchSize = 100;
        for (let i = 0; i < parseFoodLogs.length; i += batchSize) {
            const batch = parseFoodLogs.slice(i, i + batchSize);
            const transformedFoodLogs = [];

            for (const parseFoodLog of batch) {
                try {
                    const transformedFoodLog = await transformParseFoodLog(parseFoodLog, userMap, foodMap, supabase);
                    transformedFoodLogs.push(transformedFoodLog);
                } catch (error) {
                    stats.foodLogs.errors++;
                    logError('FoodLog Transformation', error, {
                        parseFoodLogId: parseFoodLog.id,
                        userId: parseFoodLog.get('user')?.id,
                        foodId: parseFoodLog.get('food')?.id
                    });
                }
            }

            if (transformedFoodLogs.length > 0) {
                const { data, error } = await supabase
                    .from('food_logs')
                    .insert(transformedFoodLogs);

                if (error) {
                    stats.foodLogs.errors += transformedFoodLogs.length;
                    logError('FoodLog Batch Insert', error, { batchSize: transformedFoodLogs.length });
                } else {
                    stats.foodLogs.migrated += transformedFoodLogs.length;
                    logProgress(`Migrated food log batch: ${stats.foodLogs.migrated}/${stats.foodLogs.total}`);
                }
            }
        }

        logSuccess(`Food log migration completed: ${stats.foodLogs.migrated}/${stats.foodLogs.total} successful`);

    } catch (error) {
        logError('FoodLog Migration Query', error);
        throw error;
    }
}

/**
 * Build user mapping from existing Supabase data
 * This is used when foodlogs migration runs without user migration
 */
async function buildUserMappingFromSupabase(supabase) {
    logProgress('Building user mapping from existing Supabase data...');

    const userMap = {};

    try {
        // Get all users from Supabase auth
        const { data: existingUsers, error } = await supabase.auth.admin.listUsers();

        if (error) {
            throw error;
        }

        // Get all Parse users to match with Supabase users
        const ParseUser = Parse.Object.extend('_User');
        const query = new Parse.Query(ParseUser);
        query.limit(1000);

        const parseUsers = await query.find({ useMasterKey: true });

        // Build mapping by matching emails
        for (const parseUser of parseUsers) {
            const parseEmail = parseUser.get('email');
            if (parseEmail) {
                const supabaseUser = existingUsers.users.find(u => u.email === parseEmail);
                if (supabaseUser) {
                    userMap[parseUser.id] = supabaseUser.id;
                }
            }
        }

        logSuccess(`Built user mapping: ${Object.keys(userMap).length} users mapped`);
        return userMap;

    } catch (error) {
        logError('Build User Mapping', error);
        return {};
    }
}

/**
 * Build food mapping from existing Supabase data
 * This is used when foodlogs migration runs without food migration
 */
async function buildFoodMappingFromSupabase(supabase) {
    logProgress('Building food mapping from existing Supabase data...');

    const foodMap = {};

    try {
        // Get all foods from Supabase
        const { data: supabaseFoods, error } = await supabase
            .from('foods')
            .select('id, name, brand, created_at');

        if (error) {
            throw error;
        }

        // Get all Parse foods
        const ParseFood = Parse.Object.extend('Food');
        const query = new Parse.Query(ParseFood);
        query.limit(1000);

        const parseFoods = await query.find({ useMasterKey: true });

        // Build mapping by matching name and brand
        for (const parseFood of parseFoods) {
            const parseName = parseFood.get('name');
            const { name: parsedName, brand: parsedBrand } = parseFoodName(parseName);

            // Find matching food in Supabase by name and brand
            const supabaseFood = supabaseFoods.find(f =>
                f.name === parsedName &&
                f.brand === parsedBrand
            );

            if (supabaseFood) {
                foodMap[parseFood.id] = supabaseFood.id;
            }
        }

        logSuccess(`Built food mapping: ${Object.keys(foodMap).length} foods mapped`);
        return foodMap;

    } catch (error) {
        logError('Build Food Mapping', error);
        return {};
    }
}

/**
 * Main Migration Function
 */

async function runMigration(tablesToMigrate = ['users', 'foods', 'foodlogs']) {
    console.log('🚀 Starting Parse to Supabase Migration');
    console.log('=====================================');
    console.log(`Tables to migrate: ${tablesToMigrate.join(', ')}`);

    // Initialize Supabase client
    const supabase = createClient(SUPABASE_CONFIG.url, SUPABASE_CONFIG.serviceKey);

    try {
        // Test connections
        logProgress('Testing Parse connection...');
        const testQuery = new Parse.Query('Food');
        testQuery.limit(1);
        await testQuery.find({ useMasterKey: true });
        logSuccess('Parse connection successful');

        logProgress('Testing Supabase connection...');
        const { data, error } = await supabase.from('foods').select('count').limit(1);
        if (error && error.code !== 'PGRST116') { // PGRST116 is "no rows found" which is OK
            throw error;
        }
        logSuccess('Supabase connection successful');

        // Run migrations in order (users first, then foods, then food logs)
        let userMap = new Map();
        let foodMap = new Map();

        if (tablesToMigrate.includes('users')) {
            userMap = await migrateUsers(supabase);
        } else {
            console.log('⏭️  Skipping users migration');
        }

        if (tablesToMigrate.includes('foods')) {
            foodMap = await migrateFoods(supabase);
        } else {
            console.log('⏭️  Skipping foods migration');
        }

        if (tablesToMigrate.includes('foodlogs')) {
            // If users or foods aren't being migrated in this run, build mappings from existing Supabase data
            if (!tablesToMigrate.includes('users')) {
                console.log('🔄 Users not being migrated - building mapping from existing Supabase data');
                userMap = await buildUserMappingFromSupabase(supabase);
            }

            if (!tablesToMigrate.includes('foods')) {
                console.log('🔄 Foods not being migrated - building mapping from existing Supabase data');
                foodMap = await buildFoodMappingFromSupabase(supabase);
            }

            await migrateFoodLogs(supabase, userMap, foodMap);
        } else {
            console.log('⏭️  Skipping food logs migration');
        }

        // Print final statistics
        const endTime = new Date();
        const duration = ((endTime - stats.startTime) / 1000 / 60).toFixed(2);

        console.log('\n📊 Migration Statistics');
        console.log('=======================');
        console.log(`Duration: ${duration} minutes`);
        console.log(`Users: ${stats.users.migrated}/${stats.users.total} (${stats.users.existing} existing, ${stats.users.created} created, ${stats.users.errors} errors)`);
        console.log(`Foods: ${stats.foods.migrated}/${stats.foods.total} (${stats.foods.errors} errors)`);
        console.log(`Food Logs: ${stats.foodLogs.migrated}/${stats.foodLogs.total} (${stats.foodLogs.errors} errors)`);
        console.log(`Total Errors: ${stats.errors.length}`);

        if (stats.errors.length > 0) {
            console.log('\n⚠️  Error Summary:');
            stats.errors.forEach((error, index) => {
                console.log(`${index + 1}. ${error.type}: ${error.error}`);
            });
        }

        console.log('\n✅ Migration completed!');

        // Important notes for post-migration
        console.log('\n📝 Post-Migration Notes:');
        console.log('1. Users will need to reset their passwords in Supabase');
        console.log('2. Review and update food categories as needed');
        console.log('3. Consider running data validation scripts');
        console.log('4. Update app configuration to use Supabase');

    } catch (error) {
        logError('Migration Failed', error);
        process.exit(1);
    }
}

/**
 * Parse command line arguments
 */
function parseCliArguments() {
    const args = process.argv.slice(2);
    const config = {
        tables: ['users', 'foods', 'foodlogs'],
        showHelp: false
    };

    for (const arg of args) {
        if (arg === '--help' || arg === '-h') {
            config.showHelp = true;
        } else if (arg.startsWith('--tables=')) {
            const tablesArg = arg.split('=')[1];
            if (tablesArg) {
                config.tables = tablesArg.toLowerCase().split(',').map(t => t.trim());

                // Validate table names
                const validTables = ['users', 'foods', 'foodlogs'];
                const invalidTables = config.tables.filter(t => !validTables.includes(t));

                if (invalidTables.length > 0) {
                    console.error(`❌ Invalid table names: ${invalidTables.join(', ')}`);
                    console.error(`   Valid tables: ${validTables.join(', ')}`);
                    process.exit(1);
                }
            }
        }
    }

    return config;
}

/**
 * Show help information
 */
function showHelp() {
    console.log('Parse to Supabase Migration Script');
    console.log('==================================');
    console.log('');
    console.log('Usage:');
    console.log('  node parse-to-supabase-migration.js [options]');
    console.log('');
    console.log('Options:');
    console.log('  --tables=<table1,table2>  Specify which tables to migrate');
    console.log('  --help, -h                Show this help message');
    console.log('');
    console.log('Available tables:');
    console.log('  users      Migrate Parse _User to Supabase auth.users');
    console.log('  foods      Migrate Parse Food to Supabase foods');
    console.log('  foodlogs   Migrate Parse FoodLog to Supabase food_logs');
    console.log('');
    console.log('Examples:');
    console.log('  node parse-to-supabase-migration.js');
    console.log('    → Migrate all tables (default)');
    console.log('');
    console.log('  node parse-to-supabase-migration.js --tables=foods');
    console.log('    → Migrate only the foods table');
    console.log('');
    console.log('  node parse-to-supabase-migration.js --tables=users,foods');
    console.log('    → Migrate users and foods tables');
    console.log('');
    console.log('Dependencies:');
    console.log('  • foodlogs migration requires users and foods to be migrated first');
    console.log('  • Consider migrating in order: users → foods → foodlogs');
    console.log('');
    console.log('Environment variables required:');
    console.log('  PARSE_APPLICATION_ID      Parse application ID');
    console.log('  PARSE_MASTER_KEY          Parse master key');
    console.log('  PARSE_SERVER_URL          Parse server URL');
    console.log('  SUPABASE_URL              Supabase project URL');
    console.log('  SUPABASE_SERVICE_ROLE_KEY Supabase service role key');
}

// CLI handling
if (require.main === module) {
    const config = parseCliArguments();

    if (config.showHelp) {
        showHelp();
        process.exit(0);
    }

    // Check for required environment variables
    // const requiredEnvVars = [
    //     'PARSE_APPLICATION_ID',
    //     'PARSE_MASTER_KEY',
    //     'PARSE_SERVER_URL',
    //     'SUPABASE_URL',
    //     'SUPABASE_SERVICE_ROLE_KEY'
    // ];

    // const missingEnvVars = requiredEnvVars.filter(envVar => !process.env[envVar]);
    //     console.error(missingEnvVars.length);

    // if (missingEnvVars.length > 0) {
    //     console.error('❌ Missing required environment variables:');
    //     missingEnvVars.forEach(envVar => console.error(`   - ${envVar}`));
    //     console.error('\nPlease set these environment variables and try again.');
    //     console.error('Run --help for more information.');
    //     process.exit(1);
    // }

    runMigration(config.tables).catch(error => {
        console.error('❌ Migration failed:', error);
        process.exit(1);
    });
}

/**
 * Test function for food name parsing
 */
function testFoodNameParsing() {
    console.log('\n🧪 Testing food name parsing...');

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
        '   Trimmed Food   (  Trimmed Brand  )   '
    ];

    testCases.forEach(testCase => {
        const result = parseFoodName(testCase);
        console.log(`   "${testCase || 'null'}" → Name: "${result.name}", Brand: ${result.brand ? `"${result.brand}"` : 'null'}`);
    });

    console.log('✅ Food name parsing tests completed');
}

module.exports = {
    runMigration,
    transformParseUser,
    transformParseFood,
    transformParseFoodLog,
    parseFoodName,
    testFoodNameParsing,
    downloadPhoto,
    getContentType,
    generateUUID,
    migratePhotoToSupabase
};