-- ================================================================
-- MAHARAT ACADEMY — V3 PATCH (Exam Status + True/False Support)
-- Run this ONCE in Supabase SQL Editor
-- Safe to re-run (uses IF NOT EXISTS / DROP IF EXISTS)
-- ================================================================

BEGIN;

-- 1. Add exam status column
ALTER TABLE public.exams
  ADD COLUMN IF NOT EXISTS status text DEFAULT 'draft',
  ADD COLUMN IF NOT EXISTS scheduled_at timestamptz;

-- 2. Add status constraint safely
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'exams_status_check' AND conrelid = 'public.exams'::regclass
  ) THEN
    ALTER TABLE public.exams
      ADD CONSTRAINT exams_status_check CHECK (status IN ('draft', 'published'));
  END IF;
END $$;

-- 3. Add question type + model_answer columns
ALTER TABLE public.questions
  ADD COLUMN IF NOT EXISTS type text DEFAULT 'mcq',
  ADD COLUMN IF NOT EXISTS model_answer text;

-- 4. Update question type constraint to include boolean (True/False)
ALTER TABLE public.questions DROP CONSTRAINT IF EXISTS questions_type_check;
ALTER TABLE public.questions
  ADD CONSTRAINT questions_type_check CHECK (type IN ('mcq', 'essay', 'boolean'));

-- 5. Update submit_exam RPC to handle boolean type
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
  v_auto_total  int  := 0;
  v_has_essay   boolean := false;
  v_score       numeric(5,2);
  q             record;
BEGIN
  FOR q IN
    SELECT id, type, correct_answer
    FROM public.questions
    WHERE exam_id = p_exam_id
  LOOP
    IF q.type = 'essay' THEN
      v_has_essay := true;
    ELSE
      -- Auto-grade MCQ and Boolean (True/False)
      v_auto_total := v_auto_total + 1;
      IF (p_answers->>(q.id::text)) = q.correct_answer THEN
        v_correct := v_correct + 1;
      END IF;
    END IF;
  END LOOP;

  v_score := CASE
    WHEN v_auto_total > 0
    THEN ROUND((v_correct::numeric / v_auto_total) * 100, 2)
    ELSE 0
  END;

  INSERT INTO public.results (student_id, exam_id, score, answers, is_graded, submitted_at)
  VALUES (v_student_id, p_exam_id, v_score, p_answers, NOT v_has_essay, now())
  ON CONFLICT (student_id, exam_id) DO UPDATE SET
    answers      = EXCLUDED.answers,
    score        = EXCLUDED.score,
    is_graded    = EXCLUDED.is_graded,
    submitted_at = EXCLUDED.submitted_at;

  RETURN jsonb_build_object(
    'score',         v_score,
    'has_essay',     v_has_essay,
    'needs_grading', v_has_essay
  );
END;
$$;

REVOKE ALL ON FUNCTION public.submit_exam FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_exam TO authenticated;

COMMIT;

-- VERIFICATION
SELECT
  (SELECT count(*) FROM information_schema.columns
   WHERE table_name='exams' AND column_name='status')    AS exams_status_ok,
  (SELECT count(*) FROM information_schema.columns
   WHERE table_name='exams' AND column_name='scheduled_at') AS exams_schedule_ok,
  (SELECT count(*) FROM information_schema.columns
   WHERE table_name='questions' AND column_name='type')  AS questions_type_ok;
