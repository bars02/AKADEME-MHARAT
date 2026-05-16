-- ================================================================
-- MAHARAT ACADEMY — V3 COMPREHENSIVE FIX (Safe & Idempotent)
-- Run ONCE in Supabase SQL Editor
-- Fixes: Trigger roles, uploaded_by column, submit_exam RPC
-- ================================================================

BEGIN;

-- ================================================================
-- STEP 1: Ensure helper functions exist (used by all RLS policies)
-- ================================================================
CREATE OR REPLACE FUNCTION public.my_role()
RETURNS text LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.my_dept()
RETURNS uuid LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT department_id FROM public.profiles WHERE id = auth.uid();
$$;

-- ================================================================
-- STEP 2: Add missing columns to materials table
-- ================================================================
ALTER TABLE public.materials
  ADD COLUMN IF NOT EXISTS uploaded_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL;

-- ================================================================
-- STEP 3: Add missing columns to results table
-- ================================================================
ALTER TABLE public.results
  ADD COLUMN IF NOT EXISTS is_graded boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS grader_comment text;

-- Back-fill: existing results (if any) are considered graded
UPDATE public.results SET is_graded = true WHERE is_graded IS NULL;

-- ================================================================
-- STEP 4: Fix registration trigger (canonical, single definition)
-- Reads role from raw_user_meta_data, defaults to 'student'
-- ================================================================
CREATE OR REPLACE FUNCTION public.on_new_user()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_role text;
BEGIN
  -- Safely extract role; only accept known values
  v_role := COALESCE(NULLIF(NEW.raw_user_meta_data->>'role', ''), 'student');
  IF v_role NOT IN ('student', 'academic', 'admin') THEN
    v_role := 'student';
  END IF;

  INSERT INTO public.profiles (id, name, role, status, department_id)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)),
    v_role,
    'pending',
    NULLIF(NEW.raw_user_meta_data->>'department_id', '')::uuid
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

-- Drop ALL old triggers (regardless of name) then recreate one canonical trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP TRIGGER IF EXISTS handle_new_user_trigger ON auth.users;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.on_new_user();

-- ================================================================
-- STEP 5: Rebuild submit_exam RPC (correct, complete, secure)
-- Returns: { score, correct, total, has_essay, needs_grading }
-- ================================================================
DROP FUNCTION IF EXISTS public.submit_exam(uuid, jsonb);

CREATE OR REPLACE FUNCTION public.submit_exam(p_exam_id uuid, p_answers jsonb)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_student_id  uuid    := auth.uid();
  v_correct     int     := 0;
  v_mcq_total   int     := 0;
  v_has_essay   boolean := false;
  v_score       numeric(5,2);
  q             record;
BEGIN
  IF v_student_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Score MCQ/Boolean; detect essays
  FOR q IN
    SELECT id, type, correct_answer
    FROM public.questions
    WHERE exam_id = p_exam_id
  LOOP
    IF q.type = 'essay' THEN
      v_has_essay := true;
    ELSE
      v_mcq_total := v_mcq_total + 1;
      IF (p_answers->>(q.id::text)) = q.correct_answer THEN
        v_correct := v_correct + 1;
      END IF;
    END IF;
  END LOOP;

  -- Calculate score based on auto-gradable questions only
  v_score := CASE
    WHEN v_mcq_total > 0 THEN ROUND((v_correct::numeric / v_mcq_total) * 100, 2)
    ELSE 0
  END;

  -- Upsert result — essays mark as not graded (awaits academic review)
  INSERT INTO public.results (student_id, exam_id, score, answers, is_graded, submitted_at)
  VALUES (v_student_id, p_exam_id, v_score, p_answers, NOT v_has_essay, now())
  ON CONFLICT (student_id, exam_id) DO UPDATE SET
    answers      = EXCLUDED.answers,
    score        = EXCLUDED.score,
    is_graded    = EXCLUDED.is_graded,
    submitted_at = EXCLUDED.submitted_at;

  RETURN jsonb_build_object(
    'score',         v_score,
    'correct',       v_correct,
    'total',         v_mcq_total,
    'has_essay',     v_has_essay,
    'needs_grading', v_has_essay
  );
END;
$$;

REVOKE ALL ON FUNCTION public.submit_exam FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_exam TO authenticated;

-- ================================================================
-- STEP 6: Fix RLS for materials (allow academic to use uploaded_by)
-- ================================================================
DROP POLICY IF EXISTS "materials_academic_own"    ON public.materials;
DROP POLICY IF EXISTS "materials_academic_manage" ON public.materials;
DROP POLICY IF EXISTS "materials_academic_dept"   ON public.materials;
DROP POLICY IF EXISTS "materials_uploader_read"   ON public.materials;

-- Academic can read their own uploads (by uploaded_by)
CREATE POLICY "materials_uploader_read" ON public.materials
  FOR SELECT USING (uploaded_by = auth.uid());

-- Academic can manage all materials in their department's courses
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
-- STEP 7: Ensure profiles constraint allows 'academic' (not old schema)
-- ================================================================
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_role_check
  CHECK (role IN ('admin', 'academic', 'student'));

COMMIT;

-- ================================================================
-- VERIFICATION — Should see all counts > 0 after running
-- ================================================================
SELECT
  (SELECT count(*) FROM information_schema.columns
   WHERE table_name='materials' AND column_name='uploaded_by') AS materials_uploaded_by_ok,
  (SELECT count(*) FROM information_schema.columns
   WHERE table_name='results'   AND column_name='is_graded')   AS results_is_graded_ok,
  (SELECT count(*) FROM information_schema.routines
   WHERE routine_name='submit_exam')                           AS submit_exam_rpc_ok,
  (SELECT count(*) FROM information_schema.routines
   WHERE routine_name='on_new_user')                          AS trigger_function_ok;
