-- ========================================
-- Profiles Table RLS Policy Testing Script
-- ========================================
-- This script tests Row Level Security policies for the profiles table
-- Run these queries in Supabase SQL editor to verify RLS is working correctly

-- ========================================
-- Prerequisites
-- ========================================
-- 1. Ensure profiles table is created (run 01-profiles-table.sql first)
-- 2. Create test users through Supabase Auth dashboard or signup flow
-- 3. Note the user IDs from auth.users table for testing

-- ========================================
-- View Current Auth Users (for reference)
-- ========================================
-- Get list of existing auth users
SELECT id, email, created_at, last_sign_in_at
FROM auth.users
ORDER BY created_at DESC
LIMIT 5;

-- ========================================
-- Test 1: Anonymous Access (Should Fail)
-- ========================================
-- Test that unauthenticated users cannot access profiles
-- This should return no rows or error with RLS enabled

-- Reset to anonymous user context
SET ROLE anon;

-- This should return no rows due to RLS
SELECT * FROM profiles;

-- ========================================
-- Test 2: Authenticated User Access
-- ========================================
-- Test that authenticated users can only see their own profile

-- Reset to authenticated role
SET ROLE authenticated;

-- Simulate setting the auth.uid() for a specific user
-- Replace 'user-uuid-here' with an actual user ID from auth.users
-- SELECT set_config('request.jwt.claims', '{"sub":"user-uuid-here"}', true);

-- This should return only the profile for the authenticated user
-- SELECT * FROM profiles WHERE id = auth.uid();

-- ========================================
-- Test 3: Profile Creation Test
-- ========================================
-- Test that users can create their own profile

-- Example profile insertion (replace with actual user ID)
-- INSERT INTO profiles (id, username, custom_key)
-- VALUES (
--     'user-uuid-here',
--     'testuser',
--     'custom_value'
-- );

-- ========================================
-- Test 4: Profile Update Test
-- ========================================
-- Test that users can update their own profile

-- Example profile update (replace with actual user ID)
-- UPDATE profiles
-- SET username = 'updated_username', custom_key = 'updated_value'
-- WHERE id = 'user-uuid-here';

-- ========================================
-- Test 5: Cross-User Access Test (Should Fail)
-- ========================================
-- Test that users cannot access other users' profiles

-- Simulate user A trying to access user B's profile
-- This should return no rows due to RLS policies

-- SELECT * FROM profiles WHERE id != auth.uid();

-- ========================================
-- Test 6: Policy Verification
-- ========================================
-- Check that all expected policies are in place
SELECT
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'profiles'
ORDER BY policyname;

-- ========================================
-- Test 7: Index Performance Test
-- ========================================
-- Verify indexes are working for performance
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM profiles WHERE username = 'testuser';

-- ========================================
-- Test 8: Trigger Test
-- ========================================
-- Verify that updated_at trigger is working
-- (Run an UPDATE and check if updated_at changes)

-- Show current timestamp for a profile
-- SELECT id, username, created_at, updated_at FROM profiles WHERE id = 'user-uuid-here';

-- Update the profile
-- UPDATE profiles SET custom_key = 'trigger_test' WHERE id = 'user-uuid-here';

-- Check if updated_at was automatically updated
-- SELECT id, username, created_at, updated_at FROM profiles WHERE id = 'user-uuid-here';

-- ========================================
-- Cleanup (Optional)
-- ========================================
-- Reset role to default
RESET ROLE;

-- ========================================
-- Expected Results Summary
-- ========================================
/*
Test 1 (Anonymous): Should return 0 rows
Test 2 (Authenticated): Should return only user's own profile
Test 3 (Insert): Should succeed for own profile, fail for others
Test 4 (Update): Should succeed for own profile, fail for others
Test 5 (Cross-user): Should return 0 rows
Test 6 (Policies): Should show 3 policies (SELECT, INSERT, UPDATE)
Test 7 (Index): Should use index scan on username
Test 8 (Trigger): updated_at should change after UPDATE
*/