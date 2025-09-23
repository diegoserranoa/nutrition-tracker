# Utility Scripts

This directory contains utility scripts for managing the NutritionTrackerV2 database and migrations.

## Scripts

### `run-db-script`
Executes individual SQL scripts against your Supabase database.

**Usage:**
```bash
./bin/run-db-script <script-file> [options]
```

**Examples:**
```bash
# Run a single SQL file
./bin/run-db-script database/01-profiles-table.sql

# Run with verbose output
./bin/run-db-script database/test-profiles-rls.sql --verbose

# Dry run (show what would be executed)
./bin/run-db-script database/02-foods-table.sql --dry-run

# Require confirmation before execution
./bin/run-db-script database/01-profiles-table.sql --confirm
```

**Options:**
- `-h, --help`: Show help message
- `-v, --verbose`: Verbose output
- `--dry-run`: Show commands without executing
- `--confirm`: Require confirmation before executing

### `run-migration`
Manages database migrations with tracking and ordering.

**Usage:**
```bash
./bin/run-migration [options]
```

**Examples:**
```bash
# Run all migrations
./bin/run-migration --all

# Run specific migration
./bin/run-migration --single 1

# Run migration range
./bin/run-migration --from 2 --to 3

# List available migrations
./bin/run-migration --list

# Check migration status
./bin/run-migration --status

# Dry run all migrations
./bin/run-migration --all --dry-run

# Run with confirmation
./bin/run-migration --all --confirm
```

**Options:**
- `-h, --help`: Show help message
- `-v, --verbose`: Verbose output
- `--dry-run`: Show commands without executing
- `--all`: Run all migrations
- `--from <number>`: Start from specific migration
- `--to <number>`: Run up to specific migration
- `--single <number>`: Run only specific migration
- `--list`: List available migrations
- `--status`: Show migration status
- `--confirm`: Require confirmation before executing

## Migration Files

The migration runner expects these files in the `database/` directory:

1. `01-profiles-table.sql` - User profiles table
2. `02-foods-table.sql` - Foods with nutrition data
3. `03-food-logs-table.sql` - Food consumption logs
4. `04-indexes-constraints.sql` - Performance optimizations

## Prerequisites

### Required Software
- **PostgreSQL Client**: Install `psql` command
  - macOS: `brew install postgresql`
  - Ubuntu: `sudo apt-get install postgresql-client`

### Environment Variables
Set these in your `.env` file:

```bash
# Required: PostgreSQL connection string
DATABASE_URL="postgresql://postgres:[PASSWORD]@db.[PROJECT-REF].supabase.co:5432/postgres"

# Optional: Alternative Supabase configuration
SUPABASE_URL="https://[PROJECT-REF].supabase.co"
SUPABASE_SERVICE_KEY="your_service_role_key"
```

## Migration Tracking

The migration runner automatically creates a `_migrations` table to track:
- Which migrations have been executed
- When they were executed
- File checksums for integrity verification

## Security Features

- **Credential Protection**: Database URLs are masked in output
- **Confirmation Prompts**: Optional confirmation before execution
- **Dry Run Mode**: Preview commands without executing
- **Error Handling**: Stops on first failure to prevent data corruption

## Troubleshooting

### Common Issues

**"psql command not found"**
```bash
# Install PostgreSQL client
brew install postgresql  # macOS
sudo apt-get install postgresql-client  # Ubuntu
```

**"DATABASE_URL environment variable is not set"**
```bash
# Copy environment template and fill in values
cp .env.example .env
# Edit .env with your actual Supabase credentials
```

**"Migration file not found"**
```bash
# Check that database files exist
ls -la database/
# Create missing migration files as needed
```

### Getting Help

```bash
# Show detailed help for any script
./bin/run-db-script --help
./bin/run-migration --help

# List available migrations
./bin/run-migration --list

# Check migration status
./bin/run-migration --status
```

## Examples

### Initial Database Setup
```bash
# Check migration status
./bin/run-migration --status

# Run all migrations with confirmation
./bin/run-migration --all --confirm

# Verify setup with test scripts
./bin/run-db-script database/test-profiles-rls.sql
```

### Development Workflow
```bash
# Create new migration file
touch database/05-new-feature.sql

# Test migration with dry run
./bin/run-db-script database/05-new-feature.sql --dry-run

# Execute single migration
./bin/run-migration --single 5 --verbose

# Check final status
./bin/run-migration --status
```