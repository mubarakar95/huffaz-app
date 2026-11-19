-- ============================================================
-- Teacher Management Migration
-- Adds is_active column to profiles for soft-disable of teachers.
-- Run this in the Supabase SQL editor.
-- ============================================================

-- 1. Add is_active column to profiles (idempotent)
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true;

-- 2. Allow admins to update is_active on profiles within their institution.
--    This RLS policy lets admins/super_admins modify profile status of others
--    in the same institution.
CREATE POLICY "Admins can manage teacher active status"
  ON profiles
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM profiles AS me
      WHERE me.id = auth.uid()
        AND me.institution_id = profiles.institution_id
        AND me.role IN ('admin', 'super_admin')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles AS me
      WHERE me.id = auth.uid()
        AND me.institution_id = profiles.institution_id
        AND me.role IN ('admin', 'super_admin')
    )
  );

