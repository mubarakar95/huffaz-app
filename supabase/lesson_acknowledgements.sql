-- ============================================================
-- Lesson Acknowledgements Table
-- Run this in: Supabase Dashboard → SQL Editor → New Query
-- ============================================================

CREATE TABLE IF NOT EXISTS lesson_acknowledgements (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  teacher_id      UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  student_id      UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  institution_id  UUID REFERENCES institutions(id) ON DELETE CASCADE,
  date            DATE NOT NULL,
  acknowledged_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- One acknowledgement per teacher + student + date
  CONSTRAINT lesson_ack_unique UNIQUE (teacher_id, student_id, date)
);

-- Index for fast lookups by teacher + date
CREATE INDEX IF NOT EXISTS idx_lesson_ack_teacher_date
  ON lesson_acknowledgements (teacher_id, date);

-- RLS: allow teachers/admins in the same institution to view acknowledgements
ALTER TABLE lesson_acknowledgements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Teachers manage own acknowledgements" ON lesson_acknowledgements;
DROP POLICY IF EXISTS "Users can view institution acknowledgements" ON lesson_acknowledgements;
DROP POLICY IF EXISTS "Users can manage own acknowledgements" ON lesson_acknowledgements;

CREATE POLICY "Users can view institution acknowledgements"
  ON lesson_acknowledgements
  FOR SELECT
  USING (
    institution_id IN (
      SELECT institution_id FROM profiles WHERE id = auth.uid()
    )
    OR teacher_id = auth.uid()
  );

CREATE POLICY "Users can manage own acknowledgements"
  ON lesson_acknowledgements
  FOR ALL
  USING (teacher_id = auth.uid())
  WITH CHECK (teacher_id = auth.uid());
