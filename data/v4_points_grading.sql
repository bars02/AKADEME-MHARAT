-- ================================================================
-- MAHARAT ACADEMY — V4 POINT-BASED GRADING SYSTEM
-- Run this in Supabase SQL Editor
-- ================================================================

BEGIN;

-- 1. Update questions table
ALTER TABLE public.questions 
  ADD COLUMN IF NOT EXISTS points numeric(5,2) DEFAULT 1.0;

-- 2. Update results table
ALTER TABLE public.results 
  ADD COLUMN IF NOT EXISTS max_score numeric(5,2),
  ADD COLUMN IF NOT EXISTS mcq_score numeric(5,2),
  ADD COLUMN IF NOT EXISTS essay_scores jsonb DEFAULT '{}';

-- 3. Replace the submit_exam RPC to calculate based on points
DROP FUNCTION IF EXISTS public.submit_exam(uuid, jsonb);

CREATE OR REPLACE FUNCTION public.submit_exam(p_exam_id uuid, p_answers jsonb)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_student_id   uuid    := auth.uid();
  v_correct      int     := 0;
  v_mcq_total    int     := 0;
  v_has_essay    boolean := false;
  
  v_mcq_score    numeric(5,2) := 0;
  v_max_score    numeric(5,2) := 0;
  v_final_score  numeric(5,2) := 0;
  
  q              record;
BEGIN
  IF v_student_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Iterate through all questions for this exam
  FOR q IN
    SELECT id, type, correct_answer, points
    FROM public.questions
    WHERE exam_id = p_exam_id
  LOOP
    v_max_score := v_max_score + COALESCE(q.points, 1.0);

    IF q.type = 'essay' THEN
      v_has_essay := true;
    ELSE
      v_mcq_total := v_mcq_total + 1;
      -- Check answer
      IF (p_answers->>(q.id::text)) = q.correct_answer THEN
        v_correct := v_correct + 1;
        v_mcq_score := v_mcq_score + COALESCE(q.points, 1.0);
      END IF;
    END IF;
  END LOOP;

  -- The initial score is just the MCQ score.
  -- If there are no essays, this is the final score.
  v_final_score := v_mcq_score;

  -- Upsert result
  INSERT INTO public.results (student_id, exam_id, score, answers, is_graded, submitted_at, max_score, mcq_score, essay_scores)
  VALUES (v_student_id, p_exam_id, v_final_score, p_answers, NOT v_has_essay, now(), v_max_score, v_mcq_score, '{}'::jsonb)
  ON CONFLICT (student_id, exam_id) DO UPDATE SET
    answers      = EXCLUDED.answers,
    score        = EXCLUDED.score,
    is_graded    = EXCLUDED.is_graded,
    submitted_at = EXCLUDED.submitted_at,
    max_score    = EXCLUDED.max_score,
    mcq_score    = EXCLUDED.mcq_score,
    essay_scores = EXCLUDED.essay_scores;

  RETURN jsonb_build_object(
    'score',         v_final_score,
    'max_score',     v_max_score,
    'correct',       v_correct,
    'total',         v_mcq_total,
    'has_essay',     v_has_essay,
    'needs_grading', v_has_essay
  );
END;
$$;

REVOKE ALL ON FUNCTION public.submit_exam FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_exam TO authenticated;

COMMIT;
