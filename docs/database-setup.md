# Database Setup Guide

## Overview
This guide covers the database schema setup for NutritionTrackerV2, starting with the profiles table.

## Profiles Table

### Purpose
The `profiles` table extends Supabase Auth users with custom application data, replacing the Parse User model functionality.

### Schema Design
```sql
profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id),
    username TEXT UNIQUE,
    custom_key TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
)
```

### Key Features
- **Auth Integration**: Primary key references Supabase Auth users
- **Parse Compatibility**: Maintains original User model fields (username, custom_key)
- **Automatic Timestamps**: `updated_at` automatically updated via trigger
- **Row Level Security**: Users can only access their own profile data
- **Performance Optimized**: Indexes on username and created_at

## Setup Instructions

### 1. Create Profiles Table
Run the SQL script in your Supabase dashboard:
```bash
database/01-profiles-table.sql
```

### 2. Test RLS Policies
Verify security policies work correctly:
```bash
database/test-profiles-rls.sql
```

## Row Level Security Policies

### Implemented Policies
1. **SELECT**: Users can view their own profile (`auth.uid() = id`)
2. **INSERT**: Users can create their own profile during signup
3. **UPDATE**: Users can modify their own profile data
4. **DELETE**: Handled automatically by auth.users CASCADE

### Security Benefits
- **Data Isolation**: Users cannot access other users' profiles
- **Auth Integration**: Uses Supabase's built-in authentication
- **Automatic Cleanup**: Profile deleted when auth user is deleted

## Real-time Features
- **Live Updates**: Changes sync in real-time across sessions
- **Subscription Ready**: Enabled for `supabase_realtime` publication

## Migration Notes
- **From Parse User**: Maps `objectId` → `id`, preserves `username` and `custom_key`
- **Auth Fields**: Email, password handled by Supabase Auth, not profiles table
- **Timestamps**: `createdAt`/`updatedAt` → `created_at`/`updated_at`

## Testing Checklist
- [ ] Table created successfully
- [ ] RLS policies prevent cross-user access
- [ ] Users can CRUD their own profiles
- [ ] Indexes improve query performance
- [ ] Triggers update timestamps automatically
- [ ] Real-time subscriptions work

## Next Steps
After profiles table setup:
1. Create foods table (subtask 1.3)
2. Create food_logs table (subtask 1.4)
3. Setup indexes and constraints (subtask 1.5)