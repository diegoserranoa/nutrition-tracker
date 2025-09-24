-- Create food-photos storage bucket and configure policies
-- This script sets up the storage bucket for food photos with appropriate security policies

-- Insert the storage bucket (will be ignored if exists due to unique constraint)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types, created_at, updated_at)
VALUES (
    'food-photos',
    'food-photos',
    true,
    52428800, -- 50MB in bytes
    ARRAY['image/jpeg', 'image/png', 'image/heic', 'image/webp'],
    NOW(),
    NOW()
) ON CONFLICT (id) DO UPDATE SET
    public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types,
    updated_at = NOW();

-- Drop existing policies if they exist (to avoid conflicts)
DROP POLICY IF EXISTS "Public read access for food photos" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload food photos" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own food photos" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own food photos" ON storage.objects;

-- Policy 1: Public read access for food photos
CREATE POLICY "Public read access for food photos"
ON storage.objects FOR SELECT
USING (bucket_id = 'food-photos');

-- Policy 2: Authenticated users can upload food photos
CREATE POLICY "Authenticated users can upload food photos"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'food-photos');

-- Policy 3: Users can update their own food photos
CREATE POLICY "Users can update their own food photos"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'food-photos' AND owner = auth.uid());

-- Policy 4: Users can delete their own food photos
CREATE POLICY "Users can delete their own food photos"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'food-photos' AND owner = auth.uid());