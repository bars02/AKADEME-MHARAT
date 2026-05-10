-- ================================================================
-- MAHARAT ACADEMY - COMPLETE SYSTEM SETUP (Production Ready)
-- Run this ONCE in Supabase SQL Editor
-- ================================================================

BEGIN;

-- ================================================================
-- STEP 1: FIX LEGACY COLUMN NAMES AND DROP OLD CONSTRAINTS
-- ================================================================
DO $$
BEGIN
  -- Fix materials.device_id -> course_id and its foreign key
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='materials' AND column_name='device_id') THEN
    ALTER TABLE public.materials RENAME COLUMN device_id TO course_id;
  END IF;
  
  -- Drop the old foreign key pointing to devices if it exists
  IF EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name='materials_device_id_fkey') THEN
    ALTER TABLE public.materials DROP CONSTRAINT materials_device_id_fkey;
  END IF;

  -- Fix exams.device_id -> course_id and its foreign key
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='exams' AND column_name='device_id') THEN
    ALTER TABLE public.exams RENAME COLUMN device_id TO course_id;
  END IF;
  
  IF EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name='exams_device_id_fkey') THEN
    ALTER TABLE public.exams DROP CONSTRAINT exams_device_id_fkey;
  END IF;

  -- Ensure the new foreign keys exist (in case tables existed before)
  IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name='materials_course_id_fkey') AND
     EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='materials') THEN
    ALTER TABLE public.materials ADD CONSTRAINT materials_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.courses(id) ON DELETE CASCADE;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_name='exams_course_id_fkey') AND
     EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='exams') THEN
    ALTER TABLE public.exams ADD CONSTRAINT exams_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.courses(id) ON DELETE CASCADE;
  END IF;

  -- Fix results.user_id -> student_id
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='results' AND column_name='user_id') THEN
    ALTER TABLE public.results RENAME COLUMN user_id TO student_id;
  END IF;
END $$;

ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_status_check;

-- ================================================================
-- STEP 2: ENSURE PROFILES TABLE IS CORRECT
-- ================================================================
CREATE TABLE IF NOT EXISTS public.profiles (
  id            uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name          text NOT NULL DEFAULT 'User',
  role          text NOT NULL DEFAULT 'student',
  status        text NOT NULL DEFAULT 'pending',
  department_id uuid,
  created_at    timestamptz DEFAULT now()
);

-- Add constraints cleanly
ALTER TABLE public.profiles 
  ADD CONSTRAINT profiles_role_check   CHECK (role   IN ('admin', 'academic', 'student')),
  ADD CONSTRAINT profiles_status_check CHECK (status IN ('pending', 'approved', 'rejected'));

-- ================================================================
-- STEP 3: DEPARTMENTS TABLE
-- ================================================================
CREATE TABLE IF NOT EXISTS public.departments (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name        text NOT NULL,
  description text,
  image_url   text,
  external_links JSONB DEFAULT '[]',
  is_active   boolean DEFAULT true,
  created_at  timestamptz DEFAULT now()
);

-- ================================================================
-- STEP 4: COURSES TABLE (linked to departments)
-- ================================================================
CREATE TABLE IF NOT EXISTS public.courses (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  department_id uuid NOT NULL REFERENCES public.departments(id) ON DELETE CASCADE,
  name          text NOT NULL,
  description   text,
  image_url     text,
  status        text NOT NULL DEFAULT 'published' CHECK (status IN ('draft','published')),
  created_at    timestamptz DEFAULT now()
);

-- ================================================================
-- STEP 5: MATERIALS TABLE (linked to courses, uploaded by academic)
-- ================================================================
CREATE TABLE IF NOT EXISTS public.materials (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id   uuid NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  uploaded_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  title       text NOT NULL,
  type        text NOT NULL CHECK (type IN ('video','pdf','image','file','text')),
  content_url text NOT NULL,
  status      text NOT NULL DEFAULT 'pending_review' CHECK (status IN ('pending_review','published','rejected')),
  reviewed_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  reviewed_at timestamptz,
  created_at  timestamptz DEFAULT now()
);

-- ================================================================
-- STEP 6: EXAMS & QUESTIONS (linked to courses)
-- ================================================================
CREATE TABLE IF NOT EXISTS public.exams (
  id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id uuid NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  title     text DEFAULT 'Final Exam',
  time_limit_minutes int DEFAULT 30,
  status    text DEFAULT 'draft' CHECK (status IN ('draft', 'published')),
  scheduled_at timestamptz,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.questions (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  exam_id        uuid NOT NULL REFERENCES public.exams(id) ON DELETE CASCADE,
  question       text NOT NULL,
  type           text DEFAULT 'mcq' CHECK (type IN ('mcq', 'essay', 'boolean')),
  options        jsonb DEFAULT '{}',
  correct_answer text,
  model_answer   text,
  sort_order     int DEFAULT 0,
  created_at     timestamptz DEFAULT now()
);

-- ================================================================
-- STEP 7: RESULTS TABLE (student exam results)
-- ================================================================
CREATE TABLE IF NOT EXISTS public.results (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  exam_id    uuid NOT NULL REFERENCES public.exams(id) ON DELETE CASCADE,
  score      numeric(5,2),
  answers    jsonb,
  passed     boolean,
  submitted_at timestamptz DEFAULT now(),
  UNIQUE(student_id, exam_id)
);

-- ================================================================
-- STEP 8: ANNOUNCEMENTS (posted by academic, scoped to department)
-- ================================================================
CREATE TABLE IF NOT EXISTS public.announcements (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  department_id uuid NOT NULL REFERENCES public.departments(id) ON DELETE CASCADE,
  created_by    uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  title         text NOT NULL,
  body          text NOT NULL,
  created_at    timestamptz DEFAULT now()
);

-- ================================================================
-- STEP 9: ADD FOREIGN KEY FROM PROFILES TO DEPARTMENTS
-- ================================================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'profiles_department_id_fkey'
  ) THEN
    ALTER TABLE public.profiles 
      ADD CONSTRAINT profiles_department_id_fkey 
      FOREIGN KEY (department_id) REFERENCES public.departments(id) ON DELETE SET NULL;
  END IF;
END $$;

-- ================================================================
-- STEP 10: ROW LEVEL SECURITY (RLS) - The Core of Multi-Role System
-- ================================================================

ALTER TABLE public.profiles     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.departments  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.courses      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.materials    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exams        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.questions    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.results      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;

-- Drop all old policies to start fresh
DO $$ DECLARE r record; BEGIN FOR r IN (
  SELECT schemaname, tablename, policyname FROM pg_policies 
  WHERE schemaname = 'public'
) LOOP EXECUTE 'DROP POLICY IF EXISTS ' || quote_ident(r.policyname) || ' ON ' || quote_ident(r.schemaname) || '.' || quote_ident(r.tablename); END LOOP; END $$;

-- Helper: get current user's role
CREATE OR REPLACE FUNCTION public.my_role() RETURNS text AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Helper: get current user's department_id
CREATE OR REPLACE FUNCTION public.my_dept() RETURNS uuid AS $$
  SELECT department_id FROM public.profiles WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- PROFILES policies
CREATE POLICY "profiles_self_read"      ON public.profiles FOR SELECT USING (id = auth.uid());
CREATE POLICY "profiles_admin_all"      ON public.profiles FOR ALL    USING (public.my_role() = 'admin') WITH CHECK (public.my_role() = 'admin');
CREATE POLICY "profiles_academic_dept"  ON public.profiles FOR SELECT USING (public.my_role() = 'academic' AND department_id = public.my_dept());
CREATE POLICY "profiles_academic_approve" ON public.profiles FOR UPDATE USING (public.my_role() = 'academic' AND department_id = public.my_dept() AND role = 'student');

-- DEPARTMENTS policies
CREATE POLICY "depts_anyone_read"  ON public.departments FOR SELECT USING (true);
CREATE POLICY "depts_admin_write"  ON public.departments FOR ALL    USING (public.my_role() = 'admin') WITH CHECK (public.my_role() = 'admin');

-- COURSES policies
CREATE POLICY "courses_anyone_read"     ON public.courses FOR SELECT USING (status = 'published');
CREATE POLICY "courses_admin_all"       ON public.courses FOR ALL    USING (public.my_role() = 'admin');
CREATE POLICY "courses_academic_dept"   ON public.courses FOR SELECT USING (public.my_role() = 'academic' AND department_id = public.my_dept());

-- MATERIALS policies
CREATE POLICY "materials_published_read" ON public.materials FOR SELECT USING (status = 'published');
CREATE POLICY "materials_admin_all"      ON public.materials FOR ALL    USING (public.my_role() = 'admin');
CREATE POLICY "materials_academic_own"   ON public.materials FOR ALL    USING (
  public.my_role() = 'academic' AND 
  course_id IN (SELECT id FROM public.courses WHERE department_id = public.my_dept())
) WITH CHECK (
  public.my_role() = 'academic' AND 
  course_id IN (SELECT id FROM public.courses WHERE department_id = public.my_dept())
);

-- EXAMS & QUESTIONS policies
CREATE POLICY "exams_read_all"    ON public.exams     FOR SELECT USING (true);
CREATE POLICY "exams_academic"    ON public.exams     FOR ALL    USING (public.my_role() IN ('admin','academic'));
CREATE POLICY "questions_read"    ON public.questions FOR SELECT USING (true);
CREATE POLICY "questions_manage"  ON public.questions FOR ALL    USING (public.my_role() IN ('admin','academic'));

-- RESULTS policies
CREATE POLICY "results_student_own" ON public.results FOR ALL USING (student_id = auth.uid());
CREATE POLICY "results_academic_view" ON public.results FOR SELECT USING (
  public.my_role() = 'academic' AND 
  exam_id IN (SELECT e.id FROM public.exams e JOIN public.courses c ON e.course_id = c.id WHERE c.department_id = public.my_dept())
);
CREATE POLICY "results_admin_all"   ON public.results FOR ALL USING (public.my_role() = 'admin');

-- ANNOUNCEMENTS policies
CREATE POLICY "ann_dept_read"    ON public.announcements FOR SELECT USING (department_id = public.my_dept() OR public.my_role() = 'admin');
CREATE POLICY "ann_academic_manage" ON public.announcements FOR ALL USING (public.my_role() = 'academic' AND department_id = public.my_dept()) WITH CHECK (public.my_role() = 'academic' AND department_id = public.my_dept());
CREATE POLICY "ann_admin_all"    ON public.announcements FOR ALL USING (public.my_role() = 'admin');

-- ================================================================
-- STEP 11: AUTO-CREATE PROFILE TRIGGER (new user → profile auto-created)
-- ================================================================
CREATE OR REPLACE FUNCTION public.on_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, name, role, status, department_id)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'role', 'student'),
    'pending',
    NULLIF(NEW.raw_user_meta_data->>'department_id', '')::uuid
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.on_new_user();

-- ================================================================
-- STEP 12: DEMO DATA (for ministerial presentation)
-- ================================================================

-- Departments
INSERT INTO public.departments (id, name, description, image_url) VALUES
  ('11111111-1111-1111-1111-111111111111', 'Hematology', 'Blood analysis, CBC, and coagulation studies', 'https://images.unsplash.com/photo-1582719508461-905c673771fd?w=400'),
  ('22222222-2222-2222-2222-222222222222', 'Clinical Chemistry', 'Biochemistry, enzymes, and metabolic panels', 'https://images.unsplash.com/photo-1579154204601-01588f351e67?w=400'),
  ('33333333-3333-3333-3333-333333333333', 'Microbiology', 'Bacteriology, virology, and culture techniques', 'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?w=400')
ON CONFLICT (id) DO NOTHING;

-- Courses for Hematology
INSERT INTO public.courses (id, department_id, name, description, image_url, status) VALUES
  ('aaaa0001-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'Complete Blood Count (CBC)', 'Learn to operate and interpret CBC analyzers including WBC, RBC, Hemoglobin, Hematocrit, and Platelets', 'https://images.unsplash.com/photo-1576091160399-112ba8d25d1f?w=400', 'published'),
  ('aaaa0002-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'Coagulation Studies (PT/APTT)', 'Prothrombin time, APTT, and fibrinogen testing for bleeding disorders', 'https://images.unsplash.com/photo-1559757175-0eb30cd8c063?w=400', 'published'),
  ('aaaa0003-0000-0000-0000-000000000003', '22222222-2222-2222-2222-222222222222', 'Liver Function Tests', 'AST, ALT, ALP, Bilirubin and albumin in hepatic assessment', 'https://images.unsplash.com/photo-1631563019676-dade0e5e9b59?w=400', 'published'),
  ('aaaa0004-0000-0000-0000-000000000004', '33333333-3333-3333-3333-333333333333', 'Gram Staining Technique', 'Differential staining for bacterial identification', 'https://images.unsplash.com/photo-1576671081400-f4a083cbf5ab?w=400', 'published')
ON CONFLICT (id) DO NOTHING;

-- Materials for CBC Course
INSERT INTO public.materials (course_id, title, type, content_url, status) VALUES
  ('aaaa0001-0000-0000-0000-000000000001', 'Introduction to CBC Analyzer Operation', 'video', 'https://www.youtube.com/watch?v=dQw4w9WgXcQ', 'published'),
  ('aaaa0001-0000-0000-0000-000000000001', 'CBC Reference Ranges & Clinical Interpretation', 'pdf', 'https://www.w3.org/WAI/WCAG21/Techniques/pdf/PDF1', 'published'),
  ('aaaa0001-0000-0000-0000-000000000001', 'Sysmex XN-1000 Operator Manual', 'pdf', 'https://www.w3.org/WAI/WCAG21/Techniques/pdf/PDF1', 'published'),
  ('aaaa0002-0000-0000-0000-000000000002', 'Coagulation Cascade Animation', 'video', 'https://www.youtube.com/watch?v=dQw4w9WgXcQ', 'published'),
  ('aaaa0003-0000-0000-0000-000000000003', 'Liver Panel Interpretation Guide', 'video', 'https://www.youtube.com/watch?v=dQw4w9WgXcQ', 'published')
ON CONFLICT DO NOTHING;

-- Exams for CBC Course
INSERT INTO public.exams (id, course_id, title) VALUES
  ('eeee0001-0000-0000-0000-000000000001', 'aaaa0001-0000-0000-0000-000000000001', 'CBC Final Assessment')
ON CONFLICT (id) DO NOTHING;

-- Questions for CBC Exam
INSERT INTO public.questions (exam_id, question, options, correct_answer, sort_order) VALUES
  ('eeee0001-0000-0000-0000-000000000001', 'What is the normal range for adult hemoglobin (male)?',
   '{"a": "8-10 g/dL", "b": "13.5-17.5 g/dL", "c": "20-25 g/dL", "d": "5-8 g/dL"}', 'b', 1),
  ('eeee0001-0000-0000-0000-000000000001', 'Which cell type is responsible for oxygen transport?',
   '{"a": "Leukocytes", "b": "Platelets", "c": "Erythrocytes", "d": "Monocytes"}', 'c', 2),
  ('eeee0001-0000-0000-0000-000000000001', 'What does MCV measure in a CBC report?',
   '{"a": "Mean Corpuscular Volume", "b": "Maximum Cell Velocity", "c": "Monocyte Count Value", "d": "Minimal Coagulation Volume"}', 'a', 3),
  ('eeee0001-0000-0000-0000-000000000001', 'A platelet count below 150,000/µL is called:',
   '{"a": "Thrombocytosis", "b": "Leukopenia", "c": "Thrombocytopenia", "d": "Polycythemia"}', 'c', 4)
ON CONFLICT DO NOTHING;

-- Sample Announcement
INSERT INTO public.announcements (department_id, title, body) VALUES
  ('11111111-1111-1111-1111-111111111111', 'Welcome to Hematology Department', 'All students are required to complete the CBC course by end of this month. Please review all uploaded materials and prepare for the final assessment. Good luck!'),
  ('22222222-2222-2222-2222-222222222222', 'Chemistry Lab Schedule Updated', 'The practical sessions for Liver Function Tests have been rescheduled to Thursdays at 9:00 AM.')
ON CONFLICT DO NOTHING;

-- ================================================================
-- STEP 13: PROMOTE THE ADMIN ACCOUNT
-- ================================================================
UPDATE public.profiles 
SET role = 'admin', status = 'approved', name = 'System Admin'
WHERE id = (SELECT id FROM auth.users WHERE email = 'akremalzentee@gmail.com');

-- Also confirm the email if not confirmed
UPDATE auth.users 
SET email_confirmed_at = COALESCE(email_confirmed_at, now())
WHERE email = 'akremalzentee@gmail.com';

COMMIT;

-- Verify everything is ready
SELECT 
  (SELECT count(*) FROM public.departments) as departments,
  (SELECT count(*) FROM public.courses)     as courses,
  (SELECT count(*) FROM public.materials)   as materials,
  (SELECT count(*) FROM public.exams)       as exams,
  (SELECT count(*) FROM public.questions)   as questions,
  (SELECT count(*) FROM public.announcements) as announcements;
