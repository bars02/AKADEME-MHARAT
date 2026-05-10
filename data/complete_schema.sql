-- ============================================================
-- MAHARAT ACADEMY - COMPLETE DATABASE SCHEMA v2.0
-- ============================================================

-- 0. EXTENSIONS
create extension if not exists "uuid-ossp";

-- 1. DEPARTMENTS
create table public.departments (
  id             uuid primary key default uuid_generate_v4(),
  name           text not null,
  description    text,
  image_url      text,
  external_links jsonb default '[]',
  is_active      boolean default true,
  created_at     timestamptz default now()
);

-- 2. PROFILES
create table public.profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  name          text not null,
  role          text not null default 'student'
                  check (role in ('admin','academic','student')),
  department_id uuid references public.departments(id) on delete set null,
  status        text not null default 'pending'
                  check (status in ('pending','approved','rejected')),
  created_at    timestamptz default now()
);

-- 3. COURSES
create table public.courses (
  id            uuid primary key default uuid_generate_v4(),
  department_id uuid references public.departments(id) on delete cascade,
  name          text not null,
  description   text,
  image_url     text,
  is_paid       boolean default false,
  price         numeric default 0,
  status        text not null default 'published' 
                  check (status in ('draft','published')),
  created_at    timestamptz default now()
);

-- 4. MATERIALS
create table public.materials (
  id          uuid primary key default uuid_generate_v4(),
  course_id   uuid references public.courses(id) on delete cascade,
  type        text not null
                check (type in ('video','pdf','image','file','model3d','text')),
  title       text not null,
  description text,
  content_url text not null,
  status      text not null default 'published'
                check (status in ('pending_review', 'published', 'rejected')),
  reviewed_by uuid references public.profiles(id),
  reviewed_at timestamptz,
  sort_order  int default 0,
  created_at  timestamptz default now()
);

-- 5. EXAMS
create table public.exams (
  id          uuid primary key default uuid_generate_v4(),
  course_id   uuid references public.courses(id) on delete cascade,
  title       text not null default 'Certification Exam',
  duration    int  not null default 30,
  pass_score  int  not null default 60,
  created_at  timestamptz default now()
);

-- 6. QUESTIONS
create table public.questions (
  id             uuid primary key default uuid_generate_v4(),
  exam_id        uuid references public.exams(id) on delete cascade,
  question       text not null,
  options        jsonb not null,
  correct_answer text not null,
  sort_order     int default 0,
  created_at     timestamptz default now()
);

-- 7. RESULTS
create table public.results (
  id               uuid primary key default uuid_generate_v4(),
  user_id          uuid references public.profiles(id) on delete cascade,
  exam_id          uuid references public.exams(id) on delete cascade,
  score            int not null default 0 check (score >= 0 and score <= 100),
  student_answers  jsonb default '{}',
  status           text not null default 'pending_review'
                     check (status in ('pending_review','approved','rejected')),
  reviewed_by      uuid references public.profiles(id) on delete set null,
  reviewed_at      timestamptz,
  submitted_at     timestamptz default now()
);

create unique index results_user_exam_unique on public.results(user_id, exam_id);

-- 8. ANNOUNCEMENTS
create table public.announcements (
  id            uuid primary key default uuid_generate_v4(),
  department_id uuid references public.departments(id) on delete cascade,
  created_by    uuid references public.profiles(id) on delete set null,
  title         text not null,
  body          text not null,
  created_at    timestamptz default now()
);

-- 9. FUNCTIONS
create or replace function public.current_role()
returns text language sql security definer as $$
  select role from public.profiles where id = auth.uid()
$$;

create or replace function public.current_dept()
returns uuid language sql security definer as $$
  select department_id from public.profiles where id = auth.uid()
$$;

-- 10. RLS POLICIES
alter table public.departments   enable row level security;
alter table public.profiles      enable row level security;
alter table public.courses       enable row level security;
alter table public.materials     enable row level security;
alter table public.exams         enable row level security;
alter table public.questions     enable row level security;
alter table public.results       enable row level security;
alter table public.announcements enable row level security;

-- Departments
create policy "admin_all_depts" on public.departments for all using (public.current_role() = 'admin');
create policy "anyone_read_depts" on public.departments for select using (true);

-- Profiles
create policy "profiles_admin_all" on public.profiles for all using (public.current_role() = 'admin');
create policy "profiles_academic_dept" on public.profiles for select 
  using (public.current_role() = 'academic' and department_id = public.current_dept());
create policy "profiles_academic_update_dept" on public.profiles for update 
  using (public.current_role() = 'academic' and department_id = public.current_dept());
create policy "profiles_self" on public.profiles for select using (id = auth.uid());

-- Courses
create policy "courses_read_all" on public.courses for select using (true);
create policy "courses_admin_manage" on public.courses for all using (public.current_role() = 'admin');
create policy "courses_academic_manage" on public.courses for all 
  using (public.current_role() = 'academic' and department_id = public.current_dept());

-- Materials
create policy "materials_read_published" on public.materials for select using (status = 'published');
create policy "materials_academic_manage" on public.materials for all 
  using (public.current_role() = 'academic' and course_id in (select id from public.courses where department_id = public.current_dept()));
create policy "materials_admin_manage" on public.materials for all using (public.current_role() = 'admin');

-- Exams
create policy "exams_read_all" on public.exams for select using (true);
create policy "exams_academic_manage" on public.exams for all 
  using (public.current_role() = 'academic' and course_id in (select id from public.courses where department_id = public.current_dept()));

-- Announcements
create policy "announcements_read_dept" on public.announcements for select 
  using (department_id = public.current_dept() or public.current_role() = 'admin');
create policy "announcements_academic_manage" on public.announcements for all 
  using (public.current_role() = 'academic' and department_id = public.current_dept());

-- 11. TRIGGERS
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, name, role, department_id, status)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name', split_part(new.email,'@',1)),
    coalesce(new.raw_user_meta_data->>'role', 'student'),
    (new.raw_user_meta_data->>'department_id')::uuid,
    'pending'
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- 12. RPC
create or replace function public.submit_exam(p_exam_id uuid, p_answers jsonb)
returns int language plpgsql security definer set search_path = public as $$
declare
  total_questions int := 0;
  correct_count int := 0;
  q record;
  student_opt text;
  final_score int;
begin
  for q in select id, correct_answer from public.questions where exam_id = p_exam_id loop
    total_questions := total_questions + 1;
    student_opt := p_answers->>q.id::text;
    if student_opt = q.correct_answer then
      correct_count := correct_count + 1;
    end if;
  end loop;

  if total_questions > 0 then
    final_score := round((correct_count::numeric / total_questions::numeric) * 100);
  else
    final_score := 100;
  end if;

  insert into public.results (user_id, exam_id, score, student_answers, status)
  values (auth.uid(), p_exam_id, final_score, p_answers, 'pending_review')
  on conflict (user_id, exam_id) do update 
  set score = excluded.score, student_answers = excluded.student_answers, submitted_at = now(), status = 'pending_review';

  return final_score;
end;
$$;
