-- Add Row Level Security policies for foods table
-- Enable RLS if not already enabled
ALTER TABLE foods ENABLE ROW LEVEL SECURITY;

-- Allow all authenticated users to view all foods (public food database)
CREATE POLICY "Authenticated users can view all foods" ON foods
FOR SELECT USING (auth.role() = 'authenticated');

-- Allow authenticated users to insert new foods
CREATE POLICY "Authenticated users can insert foods" ON foods
FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Allow users to update foods they created, or allow all users to update if created_by is null
CREATE POLICY "Users can update foods they created or public foods" ON foods
FOR UPDATE USING (
    auth.role() = 'authenticated' AND
    (created_by = auth.uid() OR created_by IS NULL)
);

-- Allow users to delete foods they created
CREATE POLICY "Users can delete foods they created" ON foods
FOR DELETE USING (
    auth.role() = 'authenticated' AND
    created_by = auth.uid()
);

-- Add comment explaining the RLS setup
COMMENT ON TABLE foods IS 'Food database with RLS policies allowing authenticated users to view all foods and manage foods they created';