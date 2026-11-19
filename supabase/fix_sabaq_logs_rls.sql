-- ============================================================
-- Fix Sabaq Logs RLS Policies & NULL Teacher IDs
-- Run this in: Supabase Dashboard → SQL Editor → New Query
-- ============================================================

-- 1. Fix existing logs where teacher_id is NULL
-- This sets the log's teacher_id to the student's assigned teacher_id
UPDATE sabaq_logs l
SET teacher_id = s.teacher_id
FROM students s
WHERE l.student_id = s.id
  AND l.teacher_id IS NULL
  AND s.teacher_id IS NOT NULL;

-- 2. Drop the restrictive old update/delete policies on sabaq_logs if they exist
-- (Replace "policyname" if yours are named differently, or let these recreate)
DROP POLICY IF EXISTS "Teachers can update own sabaq logs" ON sabaq_logs;
DROP POLICY IF EXISTS "Teachers can delete own sabaq logs" ON sabaq_logs;
DROP POLICY IF EXISTS "Users can update their own logs" ON sabaq_logs;
DROP POLICY IF EXISTS "Users can delete their own logs" ON sabaq_logs;
DROP POLICY IF EXISTS "Teachers and admins can update logs" ON sabaq_logs;
DROP POLICY IF EXISTS "Teachers and admins can delete logs" ON sabaq_logs;

-- 3. Create comprehensive Update and Delete policies for sabaq_logs
-- Allowing:
--   a) The teacher who created the log (auth.uid() = teacher_id)
--   b) Admins/Super-admins of the same institution
CREATE POLICY "Teachers and admins can update logs"
  ON sabaq_logs
  FOR UPDATE
  USING (
    auth.uid() = teacher_id 
    OR EXISTS (
      SELECT 1 FROM profiles admin
      WHERE admin.id = auth.uid()
        AND admin.role IN ('admin', 'super_admin')
        AND admin.institution_id = sabaq_logs.institution_id
    )
  )
  WITH CHECK (
    auth.uid() = teacher_id 
    OR EXISTS (
      SELECT 1 FROM profiles admin
      WHERE admin.id = auth.uid()
        AND admin.role IN ('admin', 'super_admin')
        AND admin.institution_id = sabaq_logs.institution_id
    )
  );

CREATE POLICY "Teachers and admins can delete logs"
  ON sabaq_logs
  FOR DELETE
  USING (
    auth.uid() = teacher_id 
    OR EXISTS (
      SELECT 1 FROM profiles admin
      WHERE admin.id = auth.uid()
        AND admin.role IN ('admin', 'super_admin')
        AND admin.institution_id = sabaq_logs.institution_id
    )
  );
