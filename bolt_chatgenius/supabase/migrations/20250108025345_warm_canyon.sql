/*
  # Initial Schema for Slack Clone

  1. New Tables
    - `profiles`
      - Extends Supabase auth.users
      - Stores user profile information
      - Fields: id, username, avatar_url, status, last_seen
    
    - `channels`
      - Public and private channels
      - Fields: id, name, description, is_private, created_by, created_at
    
    - `channel_members`
      - Tracks channel membership
      - Fields: channel_id, user_id, joined_at
    
    - `messages`
      - Stores all messages (both channel and direct)
      - Fields: id, content, user_id, channel_id, recipient_id, created_at
      - recipient_id is used for direct messages

  2. Security
    - Enable RLS on all tables
    - Policies for reading and writing based on channel membership and permissions
*/

-- Create profiles table
CREATE TABLE IF NOT EXISTS profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username text NOT NULL UNIQUE,
  avatar_url text,
  status text DEFAULT 'offline',
  last_seen timestamptz DEFAULT now(),
  created_at timestamptz DEFAULT now()
);

-- Create channels table
CREATE TABLE IF NOT EXISTS channels (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  is_private boolean DEFAULT false,
  created_by uuid REFERENCES profiles(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now()
);

-- Create channel members table
CREATE TABLE IF NOT EXISTS channel_members (
  channel_id uuid REFERENCES channels(id) ON DELETE CASCADE,
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  joined_at timestamptz DEFAULT now(),
  PRIMARY KEY (channel_id, user_id)
);

-- Create messages table
CREATE TABLE IF NOT EXISTS messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  content text NOT NULL,
  user_id uuid REFERENCES profiles(id) ON DELETE SET NULL,
  channel_id uuid REFERENCES channels(id) ON DELETE CASCADE,
  recipient_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  CONSTRAINT valid_message CHECK (
    (channel_id IS NOT NULL AND recipient_id IS NULL) OR
    (channel_id IS NULL AND recipient_id IS NOT NULL)
  )
);

-- Enable RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE channels ENABLE ROW LEVEL SECURITY;
ALTER TABLE channel_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- Profiles policies
CREATE POLICY "Public profiles are viewable by everyone"
  ON profiles FOR SELECT
  USING (true);

CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  USING (auth.uid() = id);

-- Channels policies
CREATE POLICY "Public channels are viewable by everyone"
  ON channels FOR SELECT
  USING (NOT is_private OR EXISTS (
    SELECT 1 FROM channel_members WHERE channel_id = id AND user_id = auth.uid()
  ));

CREATE POLICY "Authenticated users can create channels"
  ON channels FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- Channel members policies
CREATE POLICY "Channel members are viewable by channel members"
  ON channel_members FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM channel_members cm 
    WHERE cm.channel_id = channel_members.channel_id 
    AND cm.user_id = auth.uid()
  ));

CREATE POLICY "Users can join public channels"
  ON channel_members FOR INSERT
  TO authenticated
  WITH CHECK (
    NOT EXISTS (
      SELECT 1 FROM channels 
      WHERE id = channel_id 
      AND is_private = true
    )
  );

-- Messages policies
CREATE POLICY "Users can view messages in their channels"
  ON messages FOR SELECT
  USING (
    (channel_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM channel_members 
      WHERE channel_id = messages.channel_id 
      AND user_id = auth.uid()
    )) OR
    (recipient_id = auth.uid() OR user_id = auth.uid())
  );

CREATE POLICY "Authenticated users can insert messages"
  ON messages FOR INSERT
  TO authenticated
  WITH CHECK (
    (channel_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM channel_members 
      WHERE channel_id = messages.channel_id 
      AND user_id = auth.uid()
    )) OR
    (recipient_id IS NOT NULL)
  );

-- Create function to update user status
CREATE OR REPLACE FUNCTION update_user_status()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE profiles
  SET last_seen = now(),
      status = 'online'
  WHERE id = auth.uid();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;