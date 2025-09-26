-- Add Row Level Security policies for food_logs table
-- This allows users to manage their own food log entries

-- Create policy for users to view their own food logs
CREATE POLICY "Users can view their own food logs" ON food_logs
FOR SELECT USING (auth.uid() = user_id);

-- Create policy for users to insert their own food logs
CREATE POLICY "Users can insert their own food logs" ON food_logs
FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Create policy for users to update their own food logs
CREATE POLICY "Users can update their own food logs" ON food_logs
FOR UPDATE USING (auth.uid() = user_id);

-- Create policy for users to delete their own food logs
CREATE POLICY "Users can delete their own food logs" ON food_logs
FOR DELETE USING (auth.uid() = user_id);

-- Add comment explaining the RLS setup
COMMENT ON TABLE food_logs IS 'User food consumption logs with RLS policies allowing users to manage only their own records';