-- ============================================================
-- MAHARAT ACADEMY - DATABASE MIGRATION v2.0
-- ============================================================

BEGIN;

-- 1. UPDATE ROLES CONSTRAINT IN PROFILES
-- First, migrate existing role names
UPDATE public.profiles SET role = 'admin' WHERE role = 'super_admin';
UPDATE public.profiles SET role = 'academic' WHERE role IN ('instructor', 'admin');

-- Modify the constraint
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_role_check 
  CHECK (role IN ('admin', 'academic', 'student'));

-- 2. UPDATE DEPARTMENTS TABLE
ALTER TABLE public.departments ADD COLUMN IF NOT EXISTS image_url TEXT;
ALTER TABLE public.departments ADD COLUMN IF NOT EXISTS external_links JSONB DEFAULT '[]';
ALTER TABLE public.departments ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;

-- 3. RENAME devices TO courses (AND UPDATE REFERENCES)
-- Create courses table first to avoid complex renaming of foreign keys if needed
CREATE TABLE IF NOT EXISTS public.courses (
  id            uuid primary key default uuid_generate_v4(),
  department_id uuid references public.departments(id) on delete cascade,
  name          text not null,
  description   text,
  image_url     text,
  is_paid       boolean default false,
  price         numeric default 0,
  status        text not null default 'published' check (status in ('draft','published')),
  created_at    timestamptz default now()
);

-- Migrate data from devices to courses if exists
INSERT INTO public.courses (id, department_id, name, description, created_at)
SELECT id, department_id, name, description, created_at FROM public.devices
ON CONFLICT (id) DO NOTHING;

-- 4. UPDATE materials TABLE
ALTER TABLE public.materials RENAME COLUMN device_id TO course_id;
-- Update foreign key for course_id
ALTER TABLE public.materials DROP CONSTRAINT IF EXISTS materials_device_id_fkey;
ALTER TABLE public.materials ADD CONSTRAINT materials_course_id_fkey 
  FOREIGN KEY (course_id) REFERENCES public.courses(id) ON DELETE CASCADE;

ALTER TABLE public.materials ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'published' 
  CHECK (status in ('pending_review', 'published', 'rejected'));
ALTER TABLE public.materials ADD COLUMN IF NOT EXISTS reviewed_by UUID REFERENCES public.profiles(id);
ALTER TABLE public.materials ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ;

-- 5. UPDATE exams AND questions
ALTER TABLE public.exams RENAME COLUMN device_id TO course_id;
ALTER TABLE public.exams DROP CONSTRAINT IF EXISTS exams_device_id_fkey;
ALTER TABLE public.exams ADD CONSTRAINT materials_course_id_fkey 
  FOREIGN KEY (course_id) REFERENCES public.courses(id) ON DELETE CASCADE;

-- 6. CREATE announcements TABLE
CREATE TABLE IF NOT EXISTS public.announcements (
  id            uuid primary key default uuid_generate_v4(),
  department_id uuid references public.departments(id) on delete cascade,
  created_by    uuid references public.profiles(id) on delete set null,
  title         text not null,
  body          text not null,
  created_at    timestamptz default now()
);

-- 7. REFRESH RLS POLICIES
-- Drop all existing relevant policies
DROP POLICY IF EXISTS "dept_manage_sa" on public.departments;
DROP POLICY IF EXISTS "profile_admin_read" on public.profiles;
DROP POLICY IF EXISTS "profile_instructor_dept" on public.profiles;
DROP POLICY IF EXISTS "profile_sa_update" on public.profiles;
DROP POLICY IF EXISTS "profile_admin_update" on public.profiles;
DROP POLICY IF EXISTS "device_dept_read" on public.devices;
DROP POLICY IF EXISTS "device_sa_read" on public.devices;
DROP POLICY IF EXISTS "device_instructor_manage" on public.devices;
DROP POLICY IF EXISTS "material_dept_read" on public.materials;
DROP POLICY IF EXISTS "material_manage" on public.materials;
DROP POLICY IF EXISTS "exam_dept_read" on public.exams;
DROP POLICY IF EXISTS "exam_manage" on public.exams;
DROP POLICY IF EXISTS "question_dept_read" on public.questions;
DROP POLICY IF EXISTS "question_manage" on public.questions;
DROP POLICY IF EXISTS "result_dept_read" on public.results;
DROP POLICY IF EXISTS "result_approve" on public.results;

-- Enable RLS on new table
ALTER TABLE public.courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;

-- NEW POLICIES

-- DEPARTMENTS
CREATE POLICY "admin_all_depts" ON public.departments FOR ALL USING (public.current_role() = 'admin');
CREATE POLICY "anyone_read_depts" ON public.departments FOR SELECT USING (true);

-- PROFILES
CREATE POLICY "profiles_admin_all" ON public.profiles FOR ALL USING (public.current_role() = 'admin');
CREATE POLICY "profiles_academic_dept" ON public.profiles FOR SELECT 
  USING (public.current_role() = 'academic' AND department_id = public.current_dept());
CREATE POLICY "profiles_academic_update_dept" ON public.profiles FOR UPDATE 
  USING (public.current_role() = 'academic' AND department_id = public.current_dept());
CREATE POLICY "profiles_self" ON public.profiles FOR SELECT USING (id = auth.uid());

-- COURSES
CREATE POLICY "courses_read_all" ON public.courses FOR SELECT USING (true);
CREATE POLICY "courses_admin_manage" ON public.courses FOR ALL USING (public.current_role() = 'admin');
CREATE POLICY "courses_academic_manage" ON public.courses FOR ALL 
  USING (public.current_role() = 'academic' AND department_id = public.current_dept());

-- MATERIALS
CREATE POLICY "materials_read_published" ON public.materials FOR SELECT 
  USING (status = 'published');
CREATE POLICY "materials_academic_manage" ON public.materials FOR ALL 
  USING (public.current_role() = 'academic' AND course_id IN (SELECT id FROM public.courses WHERE department_id = public.current_dept()));
CREATE POLICY "materials_admin_manage" ON public.materials FOR ALL USING (public.current_role() = 'admin');

-- ANNOUNCEMENTS
CREATE POLICY "announcements_read_dept" ON public.announcements FOR SELECT 
  USING (department_id = public.current_dept() OR public.current_role() = 'admin');
CREATE POLICY "announcements_academic_manage" ON public.announcements FOR ALL 
  USING (public.current_role() = 'academic' AND department_id = public.current_dept());

-- 8. AUTO-CONFIRM EMAIL (Hack for free tier)
-- Note: This requires high privileges, usually handled via trigger on auth.users if needed.
-- But for now we will assume user disables it in Supabase Dashboard.

COMMIT;
