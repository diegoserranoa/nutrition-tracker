-- ========================================
-- Profiles Table Creation Script
-- ========================================
-- This script creates the profiles table that extends Supabase Auth users
-- with custom application-specific fields matching the original Parse User model

-- Create profiles table
CREATE TABLE IF NOT EXISTS profiles (
    -- Primary key that references auth.users(id)
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,

    -- Core user information (matching original Parse User fields)
    username TEXT UNIQUE,
    custom_key TEXT,

    -- Timestamps for tracking
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- ========================================
-- Row Level Security (RLS) Setup
-- ========================================
-- Enable RLS on the profiles table
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their own profile
CREATE POLICY "Users can view own profile"
ON profiles FOR SELECT
USING (auth.uid() = id);

-- Policy: Users can insert their own profile (one-time during signup)
CREATE POLICY "Users can insert own profile"
ON profiles FOR INSERT
WITH CHECK (auth.uid() = id);

-- Policy: Users can update their own profile
CREATE POLICY "Users can update own profile"
ON profiles FOR UPDATE
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- Policy: Users cannot delete profiles (handled by auth cascade)
-- No delete policy needed as auth.users cascade will handle deletion

-- ========================================
-- Indexes for Performance
-- ========================================
-- Index on username for fast lookups
CREATE INDEX IF NOT EXISTS idx_profiles_username ON profiles(username);

-- Index on created_at for sorting
CREATE INDEX IF NOT EXISTS idx_profiles_created_at ON profiles(created_at);

-- ========================================
-- Automatic Timestamps Function
-- ========================================
-- Function to automatically update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger to call the function before any UPDATE
CREATE TRIGGER update_profiles_updated_at
    BEFORE UPDATE ON profiles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ========================================
-- Real-time Subscriptions
-- ========================================
-- Enable real-time for profiles table
ALTER PUBLICATION supabase_realtime ADD TABLE profiles;

-- ========================================
-- Comments for Documentation
-- ========================================
COMMENT ON TABLE profiles IS 'User profiles table extending Supabase Auth with custom application data';
COMMENT ON COLUMN profiles.id IS 'References auth.users(id), serves as primary key';
COMMENT ON COLUMN profiles.username IS 'Unique username for the user, migrated from Parse User';
COMMENT ON COLUMN profiles.custom_key IS 'Custom application-specific data field from original Parse User model';
COMMENT ON COLUMN profiles.created_at IS 'Timestamp when profile was created';
COMMENT ON COLUMN profiles.updated_at IS 'Timestamp when profile was last updated (auto-updated by trigger)';

-- ========================================
-- Verification Queries
-- ========================================
-- Uncomment these to verify the table structure after creation:

-- SELECT table_name, column_name, data_type, is_nullable, column_default
-- FROM information_schema.columns
-- WHERE table_name = 'profiles'
-- ORDER BY ordinal_position;

-- SELECT schemaname, tablename, hasindexes, hasrules, hastriggers
-- FROM pg_tables
-- WHERE tablename = 'profiles';

-- SELECT policyname, permissive, roles, cmd, qual, with_check
-- FROM pg_policies
-- WHERE tablename = 'profiles';