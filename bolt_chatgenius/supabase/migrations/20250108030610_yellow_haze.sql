/*
  # Add OAuth Provider Support

  1. Changes
    - Add provider_id column to profiles table
    - Add provider column to profiles table
    - Add index for provider lookups
*/

ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS provider_id text,
ADD COLUMN IF NOT EXISTS provider text;

CREATE INDEX IF NOT EXISTS idx_profiles_provider 
ON profiles(provider_id, provider);