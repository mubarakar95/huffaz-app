-- ============================================================
-- Complete RLS Fix Script for Huffaz App
-- Run this in: Supabase Dashboard → SQL Editor → New Query
-- ============================================================

-- ------------------------------------------------------------
-- 1. FIX: Teachers cannot delete a student profile or update daily targets
--    Table: students
-- ------------------------------------------------------------
ALTER TABLE students ENABLE ROW LEVEL SECURITY;

-- Allow teachers & admins in the institution to UPDATE student profiles (daily targets, assigned teacher, etc.)
DROP POLICY IF EXISTS "Teachers and admins can update students" ON students;
CREATE POLICY "Teachers and admins can update students"
  ON students
  FOR UPDATE
  USING (
    teacher_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM profiles me
      WHERE me.id = auth.uid()
        AND me.institution_id = students.institution_id
        AND me.role IN ('admin', 'super_admin', 'teacher')
    )
  )
  WITH CHECK (
    teacher_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM profiles me
      WHERE me.id = auth.uid()
        AND me.institution_id = students.institution_id
        AND me.role IN ('admin', 'super_admin', 'teacher')
    )
  );

-- Allow teachers & admins in the institution to DELETE student profiles
DROP POLICY IF EXISTS "Teachers and admins can delete students" ON students;
CREATE POLICY "Teachers and admins can delete students"
  ON students
  FOR DELETE
  USING (
    teacher_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM profiles me
      WHERE me.id = auth.uid()
        AND me.institution_id = students.institution_id
        AND me.role IN ('admin', 'super_admin', 'teacher')
    )
  );


-- ------------------------------------------------------------
-- 2. FIX: Teachers deleting student logs when deleting a student
--    Table: sabaq_logs
-- ------------------------------------------------------------
ALTER TABLE sabaq_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Teachers and admins can delete logs" ON sabaq_logs;
CREATE POLICY "Teachers and admins can delete logs"
  ON sabaq_logs
  FOR DELETE
  USING (
    auth.uid() = teacher_id 
    OR EXISTS (
      SELECT 1 FROM profiles me
      WHERE me.id = auth.uid()
        AND me.institution_id = sabaq_logs.institution_id
        AND me.role IN ('admin', 'super_admin', 'teacher')
    )
  );


-- ------------------------------------------------------------
-- 3. FIX: Admin cannot set scheduled absence for a teacher
--    Table: teacher_absences
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS teacher_absences (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  teacher_id     UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  institution_id UUID REFERENCES institutions(id) ON DELETE CASCADE,
  absence_date   DATE NOT NULL,
  CONSTRAINT teacher_absence_unique UNIQUE (teacher_id, absence_date)
);

ALTER TABLE teacher_absences ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Teachers and admins can view teacher absences" ON teacher_absences;
DROP POLICY IF EXISTS "Teachers and admins can manage teacher absences" ON teacher_absences;
DROP POLICY IF EXISTS "Users can manage teacher absences" ON teacher_absences;

CREATE POLICY "Teachers and admins can view teacher absences"
  ON teacher_absences
  FOR SELECT
  USING (
    teacher_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM profiles me
      WHERE me.id = auth.uid()
        AND me.institution_id = teacher_absences.institution_id
    )
  );

CREATE POLICY "Teachers and admins can manage teacher absences"
  ON teacher_absences
  FOR ALL
  USING (
    teacher_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM profiles me
      WHERE me.id = auth.uid()
        AND me.institution_id = teacher_absences.institution_id
        AND me.role IN ('admin', 'super_admin')
    )
  )
  WITH CHECK (
    teacher_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM profiles me
      WHERE me.id = auth.uid()
        AND me.institution_id = teacher_absences.institution_id
        AND me.role IN ('admin', 'super_admin')
    )
  );
