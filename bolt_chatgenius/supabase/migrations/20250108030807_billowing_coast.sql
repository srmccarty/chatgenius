/*
  # Fix RLS Policies

  1. Changes
    - Fix infinite recursion in channel_members policy
    - Add insert policy for profiles
    - Simplify channel member policies
*/

-- Drop problematic policies
DROP POLICY IF EXISTS "Channel members are viewable by channel members" ON channel_members;
DROP POLICY IF EXISTS "Users can join public channels" ON channel_members;

-- Create simplified channel_members policies
CREATE POLICY "Anyone can view channel members"
  ON channel_members FOR SELECT
  USING (true);

CREATE POLICY "Authenticated users can join channels"
  ON channel_members FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Add missing profiles policies
CREATE POLICY "Users can insert their own profile"
  ON profiles FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = id);