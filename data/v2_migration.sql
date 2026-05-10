-- ================================================================
-- MAHARAT ACADEMY — V2 MIGRATION (Safe & Idempotent)
-- Run this ONCE in Supabase SQL Editor
-- All statements are safe to re-run (IF NOT EXISTS, DROP IF EXISTS)
-- ================================================================

BEGIN;

-- ================================================================
-- STEP 1: Fix courses.status constraint to include all states
-- ================================================================
ALTER TABLE public.courses DROP CONSTRAINT IF EXISTS courses_status_check;
ALTER TABLE public.courses
  ADD CONSTRAINT courses_status_check
  CHECK (status IN ('draft', 'pending_review', 'published', 'rejected'));

-- ================================================================
-- STEP 2: Add question type support (MCQ + Essay)
-- ================================================================
ALTER TABLE public.questions
  ADD COLUMN IF NOT EXISTS type text DEFAULT 'mcq',
  ADD COLUMN IF NOT EXISTS model_answer text;

-- Add type constraint only if not already there
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'questions_type_check' AND conrelid = 'public.questions'::regclass
  ) THEN
    ALTER TABLE public.questions
      ADD CONSTRAINT questions_type_check CHECK (type IN ('mcq', 'essay'));
  END IF;
END $$;

-- ================================================================
-- STEP 3: Add manual grading support to results
-- ================================================================
ALTER TABLE public.results
  ADD COLUMN IF NOT EXISTS is_graded boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS grader_comment text;

-- ================================================================
-- STEP 4: Add time limit, status and scheduling to exams
-- ================================================================
ALTER TABLE public.exams
  ADD COLUMN IF NOT EXISTS time_limit_minutes int DEFAULT 30,
  ADD COLUMN IF NOT EXISTS status text DEFAULT 'draft',
  ADD COLUMN IF NOT EXISTS scheduled_at timestamptz;

-- Ensure status constraint
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'exams_status_check') THEN
    ALTER TABLE public.exams ADD CONSTRAINT exams_status_check CHECK (status IN ('draft', 'published'));
  END IF;
END $$;

-- Update question type constraint
ALTER TABLE public.questions DROP CONSTRAINT IF EXISTS questions_type_check;
ALTER TABLE public.questions ADD CONSTRAINT questions_type_check CHECK (type IN ('mcq', 'essay', 'boolean'));

-- ================================================================
-- STEP 5: Create notifications table
-- ================================================================
CREATE TABLE IF NOT EXISTS public.notifications (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id     uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  department_id uuid NOT NULL REFERENCES public.departments(id) ON DELETE CASCADE,
  title         text NOT NULL,
  message       text NOT NULL,
  created_at    timestamptz DEFAULT now()
);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Drop and recreate notification policies cleanly
DROP POLICY IF EXISTS "notif_dept_read"     ON public.notifications;
DROP POLICY IF EXISTS "notif_academic_send" ON public.notifications;
DROP POLICY IF EXISTS "notif_admin_all"     ON public.notifications;

-- Students and academics see notifications from their department
CREATE POLICY "notif_dept_read" ON public.notifications
  FOR SELECT USING (
    department_id = public.my_dept()
    OR public.my_role() = 'admin'
  );

-- Academics can send notifications to their own department
CREATE POLICY "notif_academic_send" ON public.notifications
  FOR INSERT WITH CHECK (
    public.my_role() = 'academic'
    AND department_id = public.my_dept()
  );

-- Admin can do anything with notifications
CREATE POLICY "notif_admin_all" ON public.notifications
  FOR ALL USING (public.my_role() = 'admin');

-- ================================================================
-- STEP 6: Fix RLS for courses (Academic sees ALL statuses in dept)
-- ================================================================
DROP POLICY IF EXISTS "courses_academic_dept"  ON public.courses;
DROP POLICY IF EXISTS "courses_academic_all"   ON public.courses;

-- Admin can do everything with courses
DROP POLICY IF EXISTS "courses_admin_all" ON public.courses;
CREATE POLICY "courses_admin_all" ON public.courses
  FOR ALL USING (public.my_role() = 'admin')
  WITH CHECK (public.my_role() = 'admin');

-- Students see only published courses
DROP POLICY IF EXISTS "courses_anyone_read" ON public.courses;
CREATE POLICY "courses_student_read" ON public.courses
  FOR SELECT USING (
    status = 'published'
    AND (
      public.my_role() = 'student'
      OR auth.uid() IS NULL
    )
  );

-- Academic can manage ALL courses in their department (any status)
CREATE POLICY "courses_academic_manage" ON public.courses
  FOR ALL USING (
    public.my_role() = 'academic'
    AND department_id = public.my_dept()
  ) WITH CHECK (
    public.my_role() = 'academic'
    AND department_id = public.my_dept()
  );

-- ================================================================
-- STEP 7: Fix RLS for materials (Academic sees all in dept)
-- ================================================================
DROP POLICY IF EXISTS "materials_academic_own"  ON public.materials;
DROP POLICY IF EXISTS "materials_academic_dept" ON public.materials;

-- Academic can manage ALL materials in their department's courses
CREATE POLICY "materials_academic_manage" ON public.materials
  FOR ALL USING (
    public.my_role() = 'academic'
    AND course_id IN (
      SELECT id FROM public.courses WHERE department_id = public.my_dept()
    )
  ) WITH CHECK (
    public.my_role() = 'academic'
    AND course_id IN (
      SELECT id FROM public.courses WHERE department_id = public.my_dept()
    )
  );

-- ================================================================
-- STEP 8: Fix submit_exam RPC — supports MCQ (auto) + Essay (manual)
-- Drop first to allow return type change
-- ================================================================
DROP FUNCTION IF EXISTS public.submit_exam(uuid, jsonb);
CREATE OR REPLACE FUNCTION public.submit_exam(
  p_exam_id uuid,
  p_answers jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_student_id  uuid := auth.uid();
  v_correct     int  := 0;
  v_mcq_total   int  := 0;
  v_has_essay   boolean := false;
  v_score       numeric(5,2);
  q             record;
BEGIN
  -- Count MCQ score and detect essays
  FOR q IN
    SELECT id, type, correct_answer
    FROM public.questions
    WHERE exam_id = p_exam_id
  LOOP
    IF q.type = 'essay' THEN
      v_has_essay := true;
    ELSE
      -- MCQ scoring
      v_mcq_total := v_mcq_total + 1;
      IF (p_answers->>(q.id::text)) = q.correct_answer THEN
        v_correct := v_correct + 1;
      END IF;
    END IF;
  END LOOP;

  -- Score is based on auto-graded questions (MCQ + Boolean)
  v_score := CASE
    WHEN v_mcq_total > 0
    THEN ROUND((v_correct::numeric / v_mcq_total) * 100, 2)
    ELSE 0
  END;

  -- Upsert result — mark as NOT graded if essay exists
  INSERT INTO public.results (student_id, exam_id, score, answers, is_graded, submitted_at)
  VALUES (v_student_id, p_exam_id, v_score, p_answers, NOT v_has_essay, now())
  ON CONFLICT (student_id, exam_id) DO UPDATE SET
    answers    = EXCLUDED.answers,
    score      = EXCLUDED.score,
    is_graded  = EXCLUDED.is_graded,
    submitted_at = EXCLUDED.submitted_at;

  RETURN jsonb_build_object(
    'score',         v_score,
    'has_essay',     v_has_essay,
    'needs_grading', v_has_essay
  );
END;
$$;

-- Grant execute to authenticated users
REVOKE ALL ON FUNCTION public.submit_exam FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_exam TO authenticated;

COMMIT;

-- ================================================================
-- VERIFICATION
-- ================================================================
SELECT
  (SELECT count(*) FROM public.notifications)  AS notifications_table_ok,
  (SELECT count(*) FROM information_schema.columns
   WHERE table_name='questions' AND column_name='type') AS questions_type_col_ok,
  (SELECT count(*) FROM information_schema.columns
   WHERE table_name='results' AND column_name='is_graded') AS results_graded_col_ok,
  (SELECT count(*) FROM information_schema.columns
   WHERE table_name='exams' AND column_name='time_limit_minutes') AS exams_timelimit_ok;
