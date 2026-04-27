-- ============================================================
-- AKRAM ACADEMY - COMPLETE DATABASE SCHEMA v2.0
-- Run this ENTIRE script in Supabase SQL Editor
-- ⚠️  This will DROP existing tables and recreate them fresh.
-- ============================================================

-- 0. EXTENSIONS
create extension if not exists "uuid-ossp";

-- ============================================================
-- DROP EXISTING TABLES (clean slate)
-- ============================================================
drop table if exists public.results    cascade;
drop table if exists public.questions  cascade;
drop table if exists public.exams      cascade;
drop table if exists public.materials  cascade;
drop table if exists public.devices    cascade;
drop table if exists public.profiles   cascade;
drop table if exists public.departments cascade;

-- ============================================================
-- 1. DEPARTMENTS
-- ============================================================
create table public.departments (
  id          uuid primary key default uuid_generate_v4(),
  name        text not null,
  description text,
  created_at  timestamptz default now()
);

-- ============================================================
-- 2. PROFILES  (linked to Supabase Auth)
-- ============================================================
create table public.profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  name          text not null,
  role          text not null default 'student'
                  check (role in ('super_admin','admin','instructor','student')),
  department_id uuid references public.departments(id) on delete set null,
  status        text not null default 'pending'
                  check (status in ('pending','approved','rejected')),
  created_at    timestamptz default now()
);

-- ============================================================
-- 3. DEVICES  (medical devices per department)
-- ============================================================
create table public.devices (
  id            uuid primary key default uuid_generate_v4(),
  department_id uuid references public.departments(id) on delete cascade,
  name          text not null,
  description   text,
  image_url     text,
  created_at    timestamptz default now()
);

-- ============================================================
-- 4. MATERIALS  (learning content per device)
-- ============================================================
create table public.materials (
  id          uuid primary key default uuid_generate_v4(),
  device_id   uuid references public.devices(id) on delete cascade,
  type        text not null
                check (type in ('video','pdf','image','file','model3d','text')),
  title       text not null,
  description text,
  content_url text not null,
  sort_order  int default 0,
  created_at  timestamptz default now()
);

-- ============================================================
-- 5. EXAMS  (one exam per device)
-- ============================================================
create table public.exams (
  id          uuid primary key default uuid_generate_v4(),
  device_id   uuid references public.devices(id) on delete cascade,
  title       text not null default 'Certification Exam',
  duration    int  not null default 30,  -- minutes
  pass_score  int  not null default 60,  -- percentage to pass
  created_at  timestamptz default now()
);

-- ============================================================
-- 6. QUESTIONS  (MCQ questions per exam)
-- ============================================================
create table public.questions (
  id             uuid primary key default uuid_generate_v4(),
  exam_id        uuid references public.exams(id) on delete cascade,
  question       text not null,
  options        jsonb not null,  -- {"a":"...", "b":"...", "c":"...", "d":"..."}
  correct_answer text not null,   -- "a" | "b" | "c" | "d"
  sort_order     int default 0,
  created_at     timestamptz default now()
);

-- ============================================================
-- 7. RESULTS  (student exam submissions)
-- ============================================================
create table public.results (
  id               uuid primary key default uuid_generate_v4(),
  user_id          uuid references public.profiles(id) on delete cascade,
  exam_id          uuid references public.exams(id) on delete cascade,
  score            int not null default 0 check (score >= 0 and score <= 100),
  student_answers  jsonb default '{}',  -- {"question_id": "chosen_option"}
  status           text not null default 'pending_review'
                     check (status in ('pending_review','approved','rejected')),
  reviewed_by      uuid references public.profiles(id) on delete set null,
  reviewed_at      timestamptz,
  submitted_at     timestamptz default now()
);

-- prevent double-submission
create unique index results_user_exam_unique on public.results(user_id, exam_id);

-- ============================================================
-- 8. ENABLE ROW LEVEL SECURITY
-- ============================================================
alter table public.departments enable row level security;
alter table public.profiles    enable row level security;
alter table public.devices     enable row level security;
alter table public.materials   enable row level security;
alter table public.exams       enable row level security;
alter table public.questions   enable row level security;
alter table public.results     enable row level security;

-- ============================================================
-- 9. RLS POLICIES
-- ============================================================

-- helper: get current user role
create or replace function public.current_role()
returns text language sql security definer as $$
  select role from public.profiles where id = auth.uid()
$$;

-- helper: get current user department
create or replace function public.current_dept()
returns uuid language sql security definer as $$
  select department_id from public.profiles where id = auth.uid()
$$;

-- --- DEPARTMENTS ---
-- Anyone logged in can read (needed for registration dropdown)
create policy "dept_read_all"    on public.departments for select using (true);
-- Only super_admin can insert/update/delete departments
create policy "dept_manage_sa"   on public.departments for all
  using   (public.current_role() = 'super_admin')
  with check (public.current_role() = 'super_admin');

-- --- PROFILES ---
-- Users see their own profile always
create policy "profile_own"      on public.profiles for select
  using (id = auth.uid());
-- Admins & super_admins see all profiles in system
create policy "profile_admin_read" on public.profiles for select
  using (public.current_role() in ('admin','super_admin'));
-- Instructors see profiles in their dept (to see students)
create policy "profile_instructor_dept" on public.profiles for select
  using (
    public.current_role() = 'instructor'
    and department_id = public.current_dept()
  );
-- super_admin can update any profile (approve/change role)
create policy "profile_sa_update" on public.profiles for update
  using   (public.current_role() = 'super_admin')
  with check (public.current_role() = 'super_admin');
-- admin can approve profiles in their own dept
create policy "profile_admin_update" on public.profiles for update
  using (
    public.current_role() = 'admin'
    and department_id = public.current_dept()
  )
  with check (
    public.current_role() = 'admin'
    and department_id = public.current_dept()
  );

-- --- DEVICES ---
-- Students & instructors see devices in their dept
create policy "device_dept_read" on public.devices for select
  using (department_id = public.current_dept());
-- super_admin sees all devices
create policy "device_sa_read"   on public.devices for select
  using (public.current_role() = 'super_admin');
-- Instructor can manage devices in their dept
create policy "device_instructor_manage" on public.devices for all
  using (
    public.current_role() in ('instructor','admin','super_admin')
    and department_id = public.current_dept()
  )
  with check (
    public.current_role() in ('instructor','admin','super_admin')
    and department_id = public.current_dept()
  );

-- --- MATERIALS ---
-- Users in same dept can read materials
create policy "material_dept_read" on public.materials for select
  using (
    device_id in (
      select id from public.devices where department_id = public.current_dept()
    )
  );
-- Instructor/admin/super_admin can manage materials in their dept
create policy "material_manage" on public.materials for all
  using (
    public.current_role() in ('instructor','admin','super_admin')
    and device_id in (
      select id from public.devices where department_id = public.current_dept()
    )
  )
  with check (
    public.current_role() in ('instructor','admin','super_admin')
    and device_id in (
      select id from public.devices where department_id = public.current_dept()
    )
  );

-- --- EXAMS ---
create policy "exam_dept_read" on public.exams for select
  using (
    device_id in (
      select id from public.devices where department_id = public.current_dept()
    )
  );
create policy "exam_manage" on public.exams for all
  using (
    public.current_role() in ('instructor','admin','super_admin')
    and device_id in (
      select id from public.devices where department_id = public.current_dept()
    )
  )
  with check (
    public.current_role() in ('instructor','admin','super_admin')
    and device_id in (
      select id from public.devices where department_id = public.current_dept()
    )
  );

-- --- QUESTIONS ---
create policy "question_dept_read" on public.questions for select
  using (
    exam_id in (
      select e.id from public.exams e
      join public.devices d on d.id = e.device_id
      where d.department_id = public.current_dept()
    )
  );
create policy "question_manage" on public.questions for all
  using (
    public.current_role() in ('instructor','admin','super_admin')
    and exam_id in (
      select e.id from public.exams e
      join public.devices d on d.id = e.device_id
      where d.department_id = public.current_dept()
    )
  )
  with check (
    public.current_role() in ('instructor','admin','super_admin')
    and exam_id in (
      select e.id from public.exams e
      join public.devices d on d.id = e.device_id
      where d.department_id = public.current_dept()
    )
  );

-- --- RESULTS ---
-- Students see only their own results
create policy "result_own_read" on public.results for select
  using (user_id = auth.uid());
-- Students can submit (insert) their own results
create policy "result_student_insert" on public.results for insert
  with check (user_id = auth.uid());
-- Instructor/admin see results of students in their dept
create policy "result_dept_read" on public.results for select
  using (
    public.current_role() in ('instructor','admin','super_admin')
    and user_id in (
      select id from public.profiles where department_id = public.current_dept()
    )
  );
-- Instructor/admin can approve/reject results in their dept
create policy "result_approve" on public.results for update
  using (
    public.current_role() in ('instructor','admin','super_admin')
    and user_id in (
      select id from public.profiles where department_id = public.current_dept()
    )
  )
  with check (
    public.current_role() in ('instructor','admin','super_admin')
  );

-- ============================================================
-- 10. AUTO-CREATE PROFILE TRIGGER
-- ============================================================
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  dept_id uuid;
begin
  -- Use dept from metadata, fallback to first available dept
  begin
    dept_id := (new.raw_user_meta_data->>'department_id')::uuid;
  exception when others then
    dept_id := null;
  end;

  if dept_id is null then
    select id into dept_id from public.departments limit 1;
  end if;

  insert into public.profiles (id, name, role, department_id, status)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name', split_part(new.email,'@',1)),
    coalesce(new.raw_user_meta_data->>'role', 'student'),
    dept_id,
    'pending'
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ============================================================
-- 11. SEED DATA  (Departments)
-- ============================================================
insert into public.departments (name, description) values
  ('Pathological Analysis',  'Clinical pathology and laboratory science'),
  ('Medical Devices',        'Medical equipment operation and maintenance'),
  ('Radiology',              'Diagnostic imaging and radiation therapy'),
  ('Anesthesia',             'Anesthesia techniques and patient care')
on conflict do nothing;

-- ============================================================
-- 12. SECURE EXAM EVALUATION (RPC)
-- ============================================================
create or replace function public.submit_exam(p_exam_id uuid, p_answers jsonb)
returns int
language plpgsql security definer set search_path = public as $$
declare
  total_questions int := 0;
  correct_count int := 0;
  q record;
  student_opt text;
  final_score int;
begin
  -- Loop through all questions for this exam
  for q in select id, correct_answer from public.questions where exam_id = p_exam_id loop
    total_questions := total_questions + 1;
    -- Get the student's answer for this question from the JSONB
    student_opt := p_answers->>q.id::text;
    
    if student_opt = q.correct_answer then
      correct_count := correct_count + 1;
    end if;
  end loop;

  -- Calculate percentage
  if total_questions > 0 then
    final_score := round((correct_count::numeric / total_questions::numeric) * 100);
  else
    final_score := 100; -- If no questions, pass by default (or handle differently)
  end if;

  -- Insert into results table
  insert into public.results (user_id, exam_id, score, student_answers, status)
  values (auth.uid(), p_exam_id, final_score, p_answers, 'pending_review')
  on conflict (user_id, exam_id) do update 
  set score = excluded.score, student_answers = excluded.student_answers, submitted_at = now(), status = 'pending_review';

  return final_score;
end;
$$;

-- ============================================================
-- 13. SUPABASE STORAGE (MATERIALS BUCKET)
-- ============================================================
-- Ensure the storage schema exists (it usually does in Supabase)
insert into storage.buckets (id, name, public) 
values ('materials', 'materials', true) 
on conflict do nothing;

-- Storage RLS Policies
create policy "materials_public_read" on storage.objects for select
  using ( bucket_id = 'materials' );

create policy "materials_instructor_insert" on storage.objects for insert
  with check (
    bucket_id = 'materials' 
    and (public.current_role() in ('instructor','admin','super_admin'))
  );

create policy "materials_instructor_delete" on storage.objects for delete
  using (
    bucket_id = 'materials' 
    and (public.current_role() in ('instructor','admin','super_admin'))
  );

-- ============================================================
-- 14. UTILITY: Confirm & Approve a user by email
-- (Run separately when needed)
-- ============================================================
-- UPDATE auth.users SET email_confirmed_at = NOW() WHERE email = 'EMAIL_HERE';
-- UPDATE public.profiles SET status = 'approved', role = 'super_admin' WHERE id = (SELECT id FROM auth.users WHERE email = 'EMAIL_HERE');

-- ============================================================
-- DONE ✅
-- ============================================================
