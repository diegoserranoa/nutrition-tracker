# Parse to Supabase Migration

This directory contains scripts to migrate data from Parse Server to Supabase for the Nutrition Tracker application.

## Overview

The migration handles the following data:

### Parse Schema Analysis
- **_User**: Standard Parse users with username, email, password
- **Food**: Nutrition data with extensive vitamin/mineral fields
- **FoodLog**: User food consumption logs (references Food and User)
- **Meal**: Collection of ingredients (appears unused in current app)
- **Ingredient**: Components of meals (appears unused in current app)

### Supabase Target Schema
- **auth.users**: Supabase authentication users
- **foods**: Enhanced food model with categories, verification, and source tracking
- **food_logs**: Enhanced food logs with meal types, soft delete, and sync status

## Field Mapping

### Food Name and Brand Parsing

The migration script intelligently parses Parse food names to extract brand information:

**Format Recognition:**
- `"Tomato"` → name: `"Tomato"`, brand: `null` (generic food)
- `"Chicken Breast (Perdue)"` → name: `"Chicken Breast"`, brand: `"Perdue"`
- `"Whole Milk (Organic Valley)"` → name: `"Whole Milk"`, brand: `"Organic Valley"`
- `"Bread Whole Wheat (Dave's Killer Bread)"` → name: `"Bread Whole Wheat"`, brand: `"Dave's Killer Bread"`

**Edge Cases:**
- Empty or null names → `"Unknown Food"` with no brand
- Invalid parentheses format → Treated as generic food name
- Extra whitespace → Automatically trimmed

**Testing:**
```bash
npm run test-name-parsing           # Test food name parsing
npm run test-selective             # Test selective migration functionality
npm run test-photo-migration       # Test photo URL extraction
npm run test-single-photo-migration # Test complete photo migration workflow
npm run test-serving-size-mapping   # Test serving_size field mapping correction
```

### User Migration
| Parse Field | Supabase Field | Notes |
|-------------|----------------|-------|
| objectId | user_metadata.parse_object_id | Stored for reference |
| username | user_metadata.username | Stored in metadata |
| email | email | Direct mapping |
| emailVerified | email_confirmed | Email verification status |
| createdAt | created_at | Timestamp |
| updatedAt | updated_at | Timestamp |

### Food Migration
| Parse Field | Supabase Field | Notes |
|-------------|----------------|-------|
| name | name, brand | Smart parsing: "Food Name (Brand)" → name="Food Name", brand="Brand" |
| servingSize | serving_size | Serving size amount |
| measurementUnit | measurement_unit | Unit (g, oz, etc.) |
| calories | calories | Calories per serving |
| protein | protein | Protein in grams |
| totalCarbohydrate | total_carbohydrate | Carbs in grams |
| totalFat | total_fat | Fat in grams |
| dietaryFiber | dietary_fiber | Fiber in grams |
| totalSugars | total_sugars | Sugar in grams |
| addedSugars | added_sugars | Added sugars in grams |
| saturatedFat | saturated_fat | Saturated fat |
| sodium | sodium | Sodium in mg |
| cholesterol | cholesterol | Cholesterol in mg |
| potassium | potassium | Potassium in mg |
| calcium | calcium | Calcium in mg |
| iron | iron | Iron in mg |
| vitaminA | vitamin_a | Vitamin A |
| vitaminC | vitamin_c | Vitamin C |
| vitaminD | vitamin_d | Vitamin D |
| vitaminE | vitamin_e | Vitamin E |
| vitaminK | vitamin_k | Vitamin K |
| thiamin | thiamin | Thiamin (B1) |
| riboflavin | riboflavin | Riboflavin (B2) |
| niacin | niacin | Niacin (B3) |
| vitaminB6 | vitamin_b6 | Vitamin B6 |
| vitaminB12 | vitamin_b12 | Vitamin B12 |
| folate | folate | Folate |
| magnesium | magnesium | Magnesium |
| phosphorus | phosphorus | Phosphorus |
| zinc | zinc | Zinc |

### FoodLog Migration
| Parse Field | Supabase Field | Notes |
|-------------|----------------|-------|
| user (pointer) | user_id | Maps to migrated user UUID |
| food (pointer) | food_id | Maps to migrated food UUID |
| servingSize | serving_size | **Corrected mapping**: Amount of one serving consumed |
| - | quantity | Default value: 1 (number of servings) |
| date | logged_at | When food was consumed |
| photo | photo_url | **Photo files migrated to Supabase Storage** - downloads from Parse and uploads to Supabase |
| createdAt | created_at | Log entry creation time |

## Prerequisites

1. **Node.js** (version 16 or higher)
2. **Parse Server access** with master key
3. **Supabase project** with service role key
4. **Database permissions** to create users and insert data

## Setup

1. **Install dependencies:**
   ```bash
   cd scripts
   npm install
   ```

2. **Configure environment variables:**
   ```bash
   cp .env.template .env
   # Edit .env with your actual credentials
   ```

3. **Required environment variables:**
   ```bash
   # Parse Configuration
   PARSE_APPLICATION_ID=your_parse_app_id
   PARSE_MASTER_KEY=your_parse_master_key
   PARSE_SERVER_URL=https://parseapi.back4app.com

   # Supabase Configuration
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
   ```

## Pre-Migration Checklist

### Supabase Setup
1. **Create Supabase project** if not already done
2. **Ensure tables exist:**
   - `foods` table with all required columns
   - `food_logs` table with all required columns
   - Row Level Security (RLS) policies configured

3. **Enable auth providers** you plan to use
4. **Configure storage for photo migration:**
   - Create a storage bucket named `food-photos`
   - Set appropriate access policies (public read recommended)
   - Ensure bucket allows file uploads

### Data Backup
1. **Export Parse data** as backup:
   ```bash
   # Use Parse Dashboard or parse-server-migration tools
   ```

2. **Backup Supabase data** (if any exists):
   ```bash
   # Export current Supabase data
   ```

## Running the Migration

### 1. Test Connections
```bash
npm run test-connection
```

### 2. Run Migration

**Full Migration (All Tables):**
```bash
npm run migrate
```

**Selective Migration:**
```bash
# Migrate only specific tables
npm run migrate:users     # Users only
npm run migrate:foods     # Foods only
npm run migrate:foodlogs  # Food logs only

# Or use command line parameters
node parse-to-supabase-migration.js --tables=foods
node parse-to-supabase-migration.js --tables=users,foods
```

**Get Help:**
```bash
npm run migrate:help
# or
node parse-to-supabase-migration.js --help
```

The migration will:
1. Migrate all Parse users to Supabase Auth (if users table selected)
2. Migrate all Food records to the foods table (if foods table selected)
3. Migrate all FoodLog records to the food_logs table (if foodlogs table selected)

**⚠️ Important:** Food logs migration requires users and foods to be migrated first due to foreign key relationships.

### 3. Validate Migration
```bash
npm run validate-data
```

## Migration Strategies

### Full Migration
For most use cases, migrate all tables at once:
```bash
npm run migrate
```

### Selective Migration
For large datasets or when you need more control, migrate tables individually:

**Strategy 1: Sequential Migration**
```bash
npm run migrate:users     # First: Users (no dependencies)
npm run migrate:foods     # Second: Foods (no dependencies)
npm run migrate:foodlogs  # Third: Food logs (depends on users + foods)
```

**Strategy 2: Data-Only Migration**
If you already have users in Supabase:
```bash
npm run migrate:foods     # Just migrate food data
npm run migrate:foodlogs  # Then migrate consumption logs
```

**Strategy 3: Testing Migration**
For testing or development:
```bash
npm run migrate:foods     # Test with foods table first (simpler data)
```

### Use Cases for Selective Migration

- **Large Datasets**: Migrate tables separately to avoid timeouts
- **Testing**: Test migration logic on one table before full migration
- **Incremental Migration**: Add new data types over time
- **Error Recovery**: Re-migrate specific tables if they fail
- **Development**: Work with subsets of data during development
- **Existing Users**: Run multiple times safely - existing users won't be duplicated

## Migration Process Details

### User Migration
- **Checks for existing users by email** before creating new ones
- Uses existing Supabase user IDs when users already exist
- Creates new users only when they don't exist in Supabase
- Updates metadata for existing users to include Parse information
- Stores original Parse objectId in user metadata
- Email verification status is preserved
- **⚠️ Passwords are NOT migrated** - users must reset passwords

### Food Migration
- Comprehensive nutrition data mapping
- Sets `source` to `'migrated_from_parse'`
- Sets `is_verified` to `false` for review
- Creates UUID mappings for relationship integrity

### FoodLog Migration
- Maps user and food relationships using UUID mappings
- Infers meal type from timestamp (breakfast/lunch/dinner/snack)
- Sets default unit to 'serving' for Parse data
- Preserves original consumption dates
- **Photo Migration**: Downloads photo files from Parse and uploads to Supabase Storage
  - Creates unique filenames: `foodlog_{parseid}_{timestamp}.jpg`
  - Stores in `food-photos` bucket
  - Falls back to original Parse URL if migration fails
  - Supports HTTPS downloads with proper error handling

## Post-Migration Tasks

### 0. Field Mapping Corrections (If Needed)
If you migrated FoodLogs before the serving_size field fix, run this script to correct the data:
```bash
npm run fix-serving-size    # Populate serving_size from quantity field
```

### 1. User Account Recovery
- **Send password reset emails** to all migrated users
- Consider implementing a "migrated account" flow in your app

### 2. Data Verification
- Review migrated food categories and set appropriate values
- Verify nutrition data accuracy for critical foods
- Check that food log meal type inference is reasonable

### 3. App Configuration Updates
- Update app to use Supabase instead of Parse
- Remove Parse SDK dependencies
- Update authentication flows

### 4. Performance Optimization
- Add database indexes for common queries
- Configure RLS policies for security
- Set up database backups

## Troubleshooting

### Common Issues

**Authentication Errors:**
```
Error: Invalid API key or URL
```
- Verify Supabase URL and service role key
- Ensure service role key has admin privileges

**Parse Connection Issues:**
```
Error: XMLHttpRequest failed
```
- Check Parse server URL and app ID
- Verify master key permissions

**Data Validation Errors:**
```
Error: Invalid input syntax for type uuid
```
- Check that referenced users/foods were migrated successfully
- Review UUID mapping logic

**Large Dataset Timeouts:**
- Increase batch sizes if memory allows
- Implement pagination for very large datasets
- Consider running migration in multiple phases

### Monitoring Progress

The migration script provides detailed logging:
- ✅ Success indicators
- ⚠️ Warning messages
- ❌ Error details with data context
- 📊 Progress statistics

### Recovery Options

If migration fails:
1. **Review error logs** for specific issues
2. **Fix data inconsistencies** in source
3. **Clear migrated data** from Supabase if needed
4. **Re-run migration** with fixes

## Data Integrity Checks

The validation script verifies:
- Record count matching between Parse and Supabase
- Sample data integrity for nutrition values
- Relationship integrity for food logs
- User authentication data consistency

## Security Considerations

1. **Environment Variables**: Never commit credentials to git
2. **Service Role Key**: Use carefully, has admin privileges
3. **Master Key**: Parse master key bypasses all security
4. **RLS Policies**: Ensure proper security policies are in place post-migration

## File Structure

```
scripts/
├── parse-to-supabase-migration.js  # Main migration script
├── validate-migration.js           # Validation script
├── package.json                    # Dependencies
├── .env.template                   # Environment template
└── README.md                       # This file
```

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review the error logs for specific details
3. Ensure all prerequisites are met
4. Verify environment configuration

---

**⚠️ Important Notes:**
- Always test migration on a staging environment first
- Users will need to reset their passwords after migration
- Consider the impact of downtime during migration
- Have a rollback plan in case of issues