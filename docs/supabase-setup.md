# Supabase Project Setup Guide

## Overview
This guide walks through setting up the Supabase project for NutritionTrackerV2.

## Step 1: Create Supabase Project

1. **Visit Supabase Dashboard**: Go to [https://supabase.com/dashboard](https://supabase.com/dashboard)
2. **Sign in**: Use your existing account or create a new one
3. **Create New Project**: Click "New Project" button

### Recommended Settings:
- **Project Name**: `nutrition-tracker-v2`
- **Database Password**: Generate and save a strong password
- **Region**: Choose closest to your location (e.g., `us-east-1`)
- **Pricing Plan**: Free tier for development

## Step 2: Obtain Project Credentials

After project creation (~2 minutes), get your credentials:

1. **Navigate to**: Project Settings > API
2. **Copy the following values**:
   - **Project URL**: `https://your-project-ref.supabase.co`
   - **Anon Key**: Public key for client-side operations
   - **Service Role Key**: Private key for admin operations

## Step 3: Configure Environment

### For iOS App:
1. Copy `NutritionTrackerV2/Config.swift.example` to `Config.swift`
2. Fill in your actual Supabase URL and anon key

### For Migration Scripts:
1. Copy `.env.example` to `.env`
2. Fill in all Supabase configuration values
3. Add your database password to the DATABASE_URL

## Security Notes

- **Never commit** actual credentials to git
- **Keep Config.swift** in .gitignore
- **Keep .env** in .gitignore
- **Service Role Key** should only be used for migration scripts, not in the iOS app

## Next Steps

Once configured:
1. Continue to subtask 1.2: Design and create profiles table
2. The database schema will be created in subsequent subtasks
3. Test connection when implementing the iOS app integration

## Verification

You can verify your setup by:
1. Visiting your project dashboard at the provided URL
2. Checking that the API keys are accessible in Project Settings
3. Confirming the database is running (green status indicator)