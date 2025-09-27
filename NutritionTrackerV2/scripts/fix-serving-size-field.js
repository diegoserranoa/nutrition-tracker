#!/usr/bin/env node

/**
 * Script to fix serving_size field mapping in FoodLog migration
 * The script currently maps Parse servingSize to quantity, but it should map to serving_size
 */

const { createClient } = require('@supabase/supabase-js');

// Configuration
const SUPABASE_CONFIG = {
    url: 'https://hcskwwdqmgilvasqeqxh.supabase.co',
    serviceKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhjc2t3d2RxbWdpbHZhc3FlcXhoIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1ODU4NTIzNSwiZXhwIjoyMDc0MTYxMjM1fQ.9HYTSYaZOspxMqHEnv31BLoXVxGaz95VNjZ_L7fW21k',
};

const supabase = createClient(SUPABASE_CONFIG.url, SUPABASE_CONFIG.serviceKey);

async function checkFoodLogsSchema() {
    console.log('🔍 Checking food_logs table schema...');

    try {
        // Get a sample record to see the schema
        const { data: sampleRecord, error } = await supabase
            .from('food_logs')
            .select('*')
            .limit(1);

        if (error) {
            console.error('❌ Error fetching sample record:', error);
            return;
        }

        if (sampleRecord && sampleRecord.length > 0) {
            console.log('📊 Sample food_logs record fields:');
            Object.keys(sampleRecord[0]).forEach(field => {
                console.log(`   - ${field}: ${typeof sampleRecord[0][field]} = ${sampleRecord[0][field]}`);
            });
        }

        // Check if serving_size field exists
        const { data: servingSizeData, error: servingSizeError } = await supabase
            .from('food_logs')
            .select('serving_size')
            .limit(1);

        if (servingSizeError) {
            console.log('❌ serving_size field does not exist or is not accessible');
            console.log('   Error:', servingSizeError.message);
        } else {
            console.log('✅ serving_size field exists in food_logs table');
        }

    } catch (error) {
        console.error('❌ Error checking schema:', error.message);
    }
}

async function fixServingSizeField() {
    console.log('🔧 Starting serving_size field migration...');

    try {
        // First, check current data
        const { data: foodLogs, error: fetchError } = await supabase
            .from('food_logs')
            .select('id, quantity, serving_size, unit')
            .not('quantity', 'is', null);

        if (fetchError) {
            console.error('❌ Error fetching food logs:', fetchError);
            return;
        }

        console.log(`📊 Found ${foodLogs.length} food logs with quantity data`);

        // Show sample of current data
        console.log('📋 Sample of current data:');
        foodLogs.slice(0, 5).forEach((log, index) => {
            console.log(`   ${index + 1}. ID: ${log.id}, quantity: ${log.quantity}, serving_size: ${log.serving_size}, unit: ${log.unit}`);
        });

        // Check how many already have serving_size populated
        const withServingSize = foodLogs.filter(log => log.serving_size !== null);
        const withoutServingSize = foodLogs.filter(log => log.serving_size === null);

        console.log(`📊 Records with serving_size: ${withServingSize.length}`);
        console.log(`📊 Records without serving_size: ${withoutServingSize.length}`);

        if (withoutServingSize.length === 0) {
            console.log('✅ All records already have serving_size populated');
            return;
        }

        // Update records to populate serving_size from quantity
        console.log(`🔄 Updating ${withoutServingSize.length} records...`);

        const batchSize = 100;
        let updated = 0;
        let errors = 0;

        for (let i = 0; i < withoutServingSize.length; i += batchSize) {
            const batch = withoutServingSize.slice(i, i + batchSize);

            for (const log of batch) {
                try {
                    const { error: updateError } = await supabase
                        .from('food_logs')
                        .update({ serving_size: log.quantity })
                        .eq('id', log.id);

                    if (updateError) {
                        console.error(`❌ Error updating record ${log.id}:`, updateError.message);
                        errors++;
                    } else {
                        updated++;
                        if (updated % 50 === 0) {
                            console.log(`   ✅ Updated ${updated} records...`);
                        }
                    }
                } catch (error) {
                    console.error(`❌ Exception updating record ${log.id}:`, error.message);
                    errors++;
                }
            }
        }

        console.log(`\n📊 Migration Results:`);
        console.log(`   ✅ Successfully updated: ${updated}`);
        console.log(`   ❌ Errors: ${errors}`);

        // Verify the update
        const { data: verifyData, error: verifyError } = await supabase
            .from('food_logs')
            .select('id, quantity, serving_size')
            .is('serving_size', null)
            .limit(5);

        if (verifyError) {
            console.log('⚠️ Could not verify update:', verifyError.message);
        } else {
            console.log(`📊 Records still missing serving_size: ${verifyData.length}`);
            if (verifyData.length > 0) {
                console.log('📋 Sample records still missing serving_size:');
                verifyData.forEach(log => {
                    console.log(`   - ID: ${log.id}, quantity: ${log.quantity}, serving_size: ${log.serving_size}`);
                });
            }
        }

    } catch (error) {
        console.error('❌ Error during migration:', error.message);
    }
}

async function main() {
    console.log('🚀 Food Logs serving_size Field Migration\n');

    await checkFoodLogsSchema();
    console.log('');
    await fixServingSizeField();

    console.log('\n✅ Migration completed!');
}

main().catch(error => {
    console.error('❌ Script failed:', error);
    process.exit(1);
});