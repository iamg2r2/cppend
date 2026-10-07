create extension if not exists pgcrypto; -- used for secure session tokens; teacher password is intentionally plaintext for this classroom deployment

-- ============================================================
-- C++ END SEMESTER PRACTICAL TEST
-- Supabase database + secure RPC layer
-- ============================================================
-- IMPORTANT: Before the exam, change exam_start/exam_end below
-- to the actual examination date, keeping the +05:30 timezone.
-- Example: 2026-10-20 09:00:00+05:30

create table if not exists public.exam_settings (
  id boolean primary key default true check (id=true),
  title text not null default 'C++ End Semester Practical Test',
  exam_start timestamptz not null,
  exam_end timestamptz not null,
  updated_at timestamptz not null default now(),
  check (exam_end > exam_start)
);

-- CHANGE THESE TWO VALUES before the examination.
insert into public.exam_settings(id,exam_start,exam_end)
values (true, '2026-10-07 09:00:00+05:30', '2026-10-07 11:00:00+05:30')
on conflict(id) do update set exam_start=excluded.exam_start, exam_end=excluded.exam_end, updated_at=now();

create table if not exists public.students (
  id uuid primary key default gen_random_uuid(),
  register_number text unique not null,
  active boolean not null default true
);

create table if not exists public.questions (
  id uuid primary key default gen_random_uuid(),
  topic text not null check (topic in ('queue','constructor','inheritance')),
  title text not null,
  question_text text not null,
  difficulty text not null default 'Easy Think',
  active boolean not null default true
);

create table if not exists public.attempts (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null unique references public.students(id) on delete cascade,
  question1_id uuid not null references public.questions(id),
  question2_id uuid not null references public.questions(id),
  status text not null default 'in_progress' check (status in ('in_progress','submitted')),
  started_at timestamptz,
  last_saved_at timestamptz not null default now(),
  submitted_at timestamptz,
  exam_start timestamptz not null,
  exam_end timestamptz not null
);

create table if not exists public.attempt_photos (
  id uuid primary key default gen_random_uuid(),
  attempt_id uuid not null references public.attempts(id) on delete cascade,
  question_no smallint not null check (question_no in (1,2)),
  kind text not null check (kind in ('code','output')),
  public_url text not null,
  updated_at timestamptz not null default now(),
  unique(attempt_id,question_no,kind)
);

create table if not exists public.proctor_events (
  id bigint generated always as identity primary key,
  attempt_id uuid not null references public.attempts(id) on delete cascade,
  session_id text not null,
  event_type text not null,
  detail text,
  created_at timestamptz not null default now()
);

create table if not exists public.attempt_sessions (
  attempt_id uuid not null references public.attempts(id) on delete cascade,
  session_id text not null,
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  primary key(attempt_id,session_id)
);

create table if not exists public.teachers (
  id uuid primary key default gen_random_uuid(),
  username text unique not null,
  password_hash text not null,
  active boolean not null default true
);

create table if not exists public.teacher_sessions (
  token text primary key,
  teacher_id uuid not null references public.teachers(id) on delete cascade,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '4 hours'
);

create table if not exists public.grades (
  attempt_id uuid primary key references public.attempts(id) on delete cascade,
  mid numeric not null default 0 check(mid>=0),
  end_mark numeric not null default 0 check(end_mark>=0),
  viva numeric not null default 0 check(viva>=0),
  record numeric not null default 0 check(record>=0),
  updated_at timestamptz not null default now()
);

-- Seed exactly 60 active students: 26PCA101 ... 26PCA162, excluding discontinued 26PCA104 and 26PCA155.
insert into public.students(register_number)
select '26PCA' || lpad(n::text,3,'0')
from generate_series(101,162) n
where n not in (104,155)
on conflict(register_number) do nothing;

-- Seed questions only if the table is empty.
do $$
begin
  if not exists(select 1 from public.questions) then
    insert into public.questions(topic,title,question_text) values
    ('queue','Canteen Queue','Students wait at the college canteen. Write a C++ program using a queue to add a student, serve the first student, and display the students waiting. If the queue is empty, display a suitable message.'),
    ('queue','Printer Queue','Documents reach a printer one after another. Write a C++ program using a queue to add a document, print the next document, and display the pending documents.'),
    ('queue','Theme Park Queue','Only 5 people can wait for a ride. Write a queue program to add a person, allow the first person to enter the ride, and display the waiting queue. Show a message when the queue is full.'),
    ('queue','Hospital Token Queue','Patients are attended in the order in which they receive tokens. Write a queue program to add a patient/token, call the next patient, display waiting patients, and handle an empty queue.'),
    ('queue','Cinema Ticket Queue','People waiting for cinema tickets are handled in order. Write a queue program to join the queue, issue a ticket to the first person, and display the people still waiting.'),
    ('queue','Customer Support Queue','Customers waiting for technical support must be handled in the order they arrive. Implement add customer, attend next customer, and display waiting customers using a queue.'),
    ('queue','Bus Boarding Queue','Passengers wait to board a bus. Write a queue program to add a passenger, board the first passenger, and display the remaining passengers. Handle an empty queue.'),
    ('queue','Game Player Queue','Players waiting to enter an online game are stored in a queue. Implement add player, allow the first player to enter, and display waiting players.'),
    ('queue','Library Counter Queue','Students wait at the library counter to borrow books. Implement add student, serve the first student, display waiting students, and handle an empty queue.'),
    ('queue','Taxi Booking Queue','Customers waiting for taxis are placed in a queue. Implement add customer, assign a taxi to the first customer, and display remaining customers. Handle an empty queue.'),
    ('constructor','Student ID Creator','Create a Student class with name and register number. Use a constructor to initialize both values. Create two student objects with different values and display them.'),
    ('constructor','Game Character','Create a Character class with name and health. Use a constructor to initialize the character. Create two characters and display their details.'),
    ('constructor','Movie Ticket','Create a MovieTicket class with movie name, seat number, and ticket price. Use a constructor to initialize the details. Create two tickets and display them.'),
    ('constructor','Canteen Item','Create a CanteenItem class with item name and price. Use a constructor to initialize the details and display two items.'),
    ('constructor','Book Creator','Create a Book class with title and author. Initialize the details using a constructor and display two books.'),
    ('inheritance','Superhero Academy','Create a base class Person containing name and age. Derive a Superhero class containing superpower. Use inheritance and display all details.'),
    ('inheritance','Animal Sounds','Create a base class Animal with makeSound(). Derive Dog and Cat classes and make each display its own sound.'),
    ('inheritance','College People','Create a base class Person containing name. Derive Student with register number and Teacher with subject. Create objects and display their details.'),
    ('inheritance','Game Characters','Create a base class Player with name and level. Derive Warrior with weapon and Wizard with magic power. Display a complete character.'),
    ('inheritance','Taxi Vehicle','Create a base class Vehicle with vehicle number. Derive Taxi with driver name. Create a Taxi object and display both details.');
  end if;
end $$;

-- Teacher account. Password: g2r2rocks.
-- Classroom deployment requested: teacher password is stored as plaintext.
insert into public.teachers(username,password_hash)
values('g2r2','g2r2rocks')
on conflict(username) do update set password_hash=excluded.password_hash, active=true;

-- Storage bucket for code/output photos. It is intentionally a simple public-read bucket
-- for this GitHub Pages prototype. Paths contain an unguessable attempt UUID.
insert into storage.buckets(id,name,public)
values('exam-submissions','exam-submissions',true)
on conflict(id) do update set public=true;

-- Storage policies: browser may upload/update only inside the exam bucket.
-- The app never exposes the database tables directly; all exam state goes through RPCs.
drop policy if exists exam_upload on storage.objects;
drop policy if exists exam_update on storage.objects;
drop policy if exists exam_read on storage.objects;
create policy exam_upload on storage.objects for insert to anon,authenticated with check(bucket_id='exam-submissions');
create policy exam_update on storage.objects for update to anon,authenticated using(bucket_id='exam-submissions') with check(bucket_id='exam-submissions');
create policy exam_read on storage.objects for select to anon,authenticated using(bucket_id='exam-submissions');

alter table public.students enable row level security;
alter table public.questions enable row level security;
alter table public.attempts enable row level security;
alter table public.attempt_photos enable row level security;
alter table public.proctor_events enable row level security;
alter table public.attempt_sessions enable row level security;
alter table public.teachers enable row level security;
alter table public.teacher_sessions enable row level security;
alter table public.grades enable row level security;
alter table public.exam_settings enable row level security;

-- Helper: validate teacher token.
create or replace function public.valid_teacher(p_token text)
returns boolean language sql security definer set search_path=public as $$
  select exists(select 1 from public.teacher_sessions where token=p_token and expires_at>now())
$$;

-- Student login / assignment. Creates exactly one attempt per register number.
create or replace function public.start_or_resume_attempt(p_register_number text,p_session_id text)
returns json language plpgsql security definer set search_path=public as $$
declare s public.students; a public.attempts; q1 uuid; q2 uuid; es public.exam_settings;
begin
  select * into es from public.exam_settings where id=true;
  select * into s from public.students where upper(register_number)=upper(trim(p_register_number)) and active=true;
  if not found then return json_build_object('ok',false,'message','Register number not found.'); end if;
  if now() > es.exam_end then return json_build_object('ok',false,'message','The examination window has closed.'); end if;
  select * into a from public.attempts where student_id=s.id;
  if found then
    insert into public.attempt_sessions(attempt_id,session_id) values(a.id,p_session_id)
      on conflict(attempt_id,session_id) do update set last_seen_at=now();
    return json_build_object('ok',true,'existing',true,'attempt_id',a.id,'status',a.status);
  end if;
  select id into q1 from public.questions where active and topic='queue' order by random() limit 1;
  select id into q2 from public.questions where active and topic in('constructor','inheritance') order by random() limit 1;
  insert into public.attempts(student_id,question1_id,question2_id,exam_start,exam_end)
  values(s.id,q1,q2,es.exam_start,es.exam_end) returning * into a;
  insert into public.attempt_sessions(attempt_id,session_id) values(a.id,p_session_id);
  return json_build_object('ok',true,'existing',false,'attempt_id',a.id,'status',a.status);
end $$;
grant execute on function public.start_or_resume_attempt(text,text) to anon,authenticated;

create or replace function public.get_student_attempt(p_attempt_id uuid,p_session_id text)
returns json language plpgsql security definer set search_path=public as $$
declare r record;
begin
  if not exists(select 1 from public.attempt_sessions where attempt_id=p_attempt_id and session_id=p_session_id) then
    return json_build_object('ok',false,'message','Session not recognised.');
  end if;
  select a.*,s.register_number,q1.title q1_title,q1.question_text q1_text,q1.topic q1_topic,
         q2.title q2_title,q2.question_text q2_text,q2.topic q2_topic,
         coalesce((select public_url from public.attempt_photos where attempt_id=a.id and question_no=1 and kind='code'),'') code1,
         coalesce((select public_url from public.attempt_photos where attempt_id=a.id and question_no=1 and kind='output'),'') output1,
         coalesce((select public_url from public.attempt_photos where attempt_id=a.id and question_no=2 and kind='code'),'') code2,
         coalesce((select public_url from public.attempt_photos where attempt_id=a.id and question_no=2 and kind='output'),'') output2
  into r from public.attempts a join public.students s on s.id=a.student_id
  join public.questions q1 on q1.id=a.question1_id join public.questions q2 on q2.id=a.question2_id
  where a.id=p_attempt_id;
  if not found then return json_build_object('ok',false,'message','Attempt not found.'); end if;
  update public.attempt_sessions set last_seen_at=now() where attempt_id=p_attempt_id and session_id=p_session_id;
  return json_build_object('ok',true,'attempt',row_to_json(r));
end $$;
grant execute on function public.get_student_attempt(uuid,text) to anon,authenticated;

create or replace function public.touch_attempt(p_attempt_id uuid,p_session_id text)
returns json language plpgsql security definer set search_path=public as $$
begin
  update public.attempt_sessions set last_seen_at=now() where attempt_id=p_attempt_id and session_id=p_session_id;
  update public.attempts set last_saved_at=now(),started_at=coalesce(started_at,now())
    where id=p_attempt_id and status='in_progress' and now() between exam_start and exam_end;
  return json_build_object('ok',true,'saved_at',now());
end $$;
grant execute on function public.touch_attempt(uuid,text) to anon,authenticated;

create or replace function public.heartbeat(p_attempt_id uuid,p_session_id text)
returns json language plpgsql security definer set search_path=public as $$
begin
  insert into public.attempt_sessions(attempt_id,session_id) values(p_attempt_id,p_session_id)
    on conflict(attempt_id,session_id) do update set last_seen_at=now();
  return json_build_object('ok',true);
end $$;
grant execute on function public.heartbeat(uuid,text) to anon,authenticated;

create or replace function public.save_photo(p_attempt_id uuid,p_question_no smallint,p_kind text,p_url text)
returns json language plpgsql security definer set search_path=public as $$
begin
  if not exists(select 1 from public.attempt_sessions where attempt_id=p_attempt_id) then return json_build_object('ok',false,'message','Invalid attempt.'); end if;
  if not exists(select 1 from public.attempts where id=p_attempt_id and status='in_progress' and now() between exam_start and exam_end) then
    return json_build_object('ok',false,'message','The examination window is closed.');
  end if;
  insert into public.attempt_photos(attempt_id,question_no,kind,public_url,updated_at)
  values(p_attempt_id,p_question_no,p_kind,p_url,now())
  on conflict(attempt_id,question_no,kind) do update set public_url=excluded.public_url,updated_at=now();
  update public.attempts set started_at=coalesce(started_at,now()),last_saved_at=now() where id=p_attempt_id;
  return json_build_object('ok',true);
end $$;
grant execute on function public.save_photo(uuid,smallint,text,text) to anon,authenticated;

create or replace function public.remove_photo(p_attempt_id uuid,p_question_no smallint,p_kind text)
returns json language plpgsql security definer set search_path=public as $$
begin
  delete from public.attempt_photos where attempt_id=p_attempt_id and question_no=p_question_no and kind=p_kind;
  return json_build_object('ok',true);
end $$;
grant execute on function public.remove_photo(uuid,smallint,text) to anon,authenticated;

create or replace function public.submit_attempt(p_attempt_id uuid,p_session_id text,p_auto boolean default false)
returns json language plpgsql security definer set search_path=public as $$
declare missing integer;
begin
  if not exists(select 1 from public.attempt_sessions where attempt_id=p_attempt_id and session_id=p_session_id) then return json_build_object('ok',false,'message','Session not recognised.'); end if;
  if exists(select 1 from public.attempts where id=p_attempt_id and status='submitted') then return json_build_object('ok',true,'message','Already submitted.'); end if;
  if not exists(select 1 from public.attempt_photos where attempt_id=p_attempt_id and question_no=1 and kind='code') or
     not exists(select 1 from public.attempt_photos where attempt_id=p_attempt_id and question_no=1 and kind='output') or
     not exists(select 1 from public.attempt_photos where attempt_id=p_attempt_id and question_no=2 and kind='code') or
     not exists(select 1 from public.attempt_photos where attempt_id=p_attempt_id and question_no=2 and kind='output') then
    if not p_auto then return json_build_object('ok',false,'message','Both code and output photographs are required for both questions.'); end if;
  end if;
  update public.attempts set status='submitted',submitted_at=now(),last_saved_at=now() where id=p_attempt_id and status='in_progress';
  return json_build_object('ok',true,'message',case when p_auto then 'The examination window has closed.' else 'Submitted successfully.' end);
end $$;
grant execute on function public.submit_attempt(uuid,text,boolean) to anon,authenticated;

create or replace function public.record_proctor_event(p_attempt_id uuid,p_session_id text,p_event_type text,p_detail text default '')
returns json language plpgsql security definer set search_path=public as $$
declare c integer;
begin
  if not exists(select 1 from public.attempts where id=p_attempt_id and status='in_progress') then return json_build_object('ok',false,'warning_count',0); end if;
  insert into public.proctor_events(attempt_id,session_id,event_type,detail) values(p_attempt_id,p_session_id,p_event_type,p_detail);
  select count(*) into c from public.proctor_events where attempt_id=p_attempt_id and event_type in('APP_BACKGROUND','WINDOW_BLUR','MULTIPLE_SESSION');
  return json_build_object('ok',true,'warning_count',c);
end $$;
grant execute on function public.record_proctor_event(uuid,text,text,text) to anon,authenticated;

create or replace function public.teacher_login(p_password text)
returns json language plpgsql security definer set search_path=public as $$
declare t public.teachers; tok text;
begin
  select * into t from public.teachers where username='g2r2' and active=true;
  if not found or t.password_hash<>p_password then return json_build_object('ok',false,'message','Invalid teacher password.'); end if;
  tok=encode(extensions.gen_random_bytes(32),'hex');
  insert into public.teacher_sessions(token,teacher_id) values(tok,t.id);
  return json_build_object('ok',true,'token',tok,'expires_at',now()+interval '4 hours');
end $$;
grant execute on function public.teacher_login(text) to anon,authenticated;

create or replace function public.teacher_attempts(p_token text)
returns json language plpgsql security definer set search_path=public as $$
begin
  if not public.valid_teacher(p_token) then return json_build_object('ok',false,'message','Teacher session expired.'); end if;
  return json_build_object('ok',true,'rows',(select coalesce(json_agg(x order by x.register_number),'[]'::json) from (
    select a.id attempt_id,s.register_number,coalesce(a.status,'not_started') status,a.started_at,a.last_saved_at,a.submitted_at,
      q1.title q1_title,q2.title q2_title,
      coalesce((select public_url from public.attempt_photos where attempt_id=a.id and question_no=1 and kind='code'),'') code1,
      coalesce((select public_url from public.attempt_photos where attempt_id=a.id and question_no=1 and kind='output'),'') output1,
      coalesce((select public_url from public.attempt_photos where attempt_id=a.id and question_no=2 and kind='code'),'') code2,
      coalesce((select public_url from public.attempt_photos where attempt_id=a.id and question_no=2 and kind='output'),'') output2,
      coalesce(g.mid,0) mid,coalesce(g.end_mark,0) end_mark,coalesce(g.viva,0) viva,coalesce(g.record,0) record,
      (select count(*) from public.proctor_events pe where pe.attempt_id=a.id and pe.event_type in('APP_BACKGROUND','WINDOW_BLUR','MULTIPLE_SESSION')) warning_count,
      coalesce((select json_agg(json_build_object('event_type',pe.event_type,'detail',pe.detail,'created_at',pe.created_at) order by pe.created_at) from public.proctor_events pe where pe.attempt_id=a.id),'[]'::json) events
    from public.students s
    left join public.attempts a on a.student_id=s.id
    left join public.questions q1 on q1.id=a.question1_id
    left join public.questions q2 on q2.id=a.question2_id
    left join public.grades g on g.attempt_id=a.id
    where s.active=true
  ) x));
end $$;
grant execute on function public.teacher_attempts(text) to anon,authenticated;

create or replace function public.teacher_grade(p_token text,p_attempt_id uuid,p_mid numeric,p_end numeric,p_viva numeric,p_record numeric)
returns json language plpgsql security definer set search_path=public as $$
begin
  if not public.valid_teacher(p_token) then return json_build_object('ok',false,'message','Teacher session expired.'); end if;
  insert into public.grades(attempt_id,mid,end_mark,viva,record,updated_at) values(p_attempt_id,greatest(0,p_mid),greatest(0,p_end),greatest(0,p_viva),greatest(0,p_record),now())
  on conflict(attempt_id) do update set mid=excluded.mid,end_mark=excluded.end_mark,viva=excluded.viva,record=excluded.record,updated_at=now();
  return json_build_object('ok',true);
end $$;
grant execute on function public.teacher_grade(text,uuid,numeric,numeric,numeric,numeric) to anon,authenticated;

create or replace function public.teacher_reset_attempt(p_token text,p_attempt_id uuid)
returns json language plpgsql security definer set search_path=public as $$
begin
  if not public.valid_teacher(p_token) then return json_build_object('ok',false,'message','Teacher session expired.'); end if;
  delete from public.grades where attempt_id=p_attempt_id;
  delete from public.attempt_sessions where attempt_id=p_attempt_id;
  delete from public.proctor_events where attempt_id=p_attempt_id;
  delete from public.attempt_photos where attempt_id=p_attempt_id;
  delete from storage.objects where bucket_id='exam-submissions' and name like p_attempt_id::text || '/%';
  delete from public.attempts where id=p_attempt_id;
  return json_build_object('ok',true);
end $$;
grant execute on function public.teacher_reset_attempt(text,uuid) to anon,authenticated;


create or replace function public.teacher_csv(p_token text)
returns json language plpgsql security definer set search_path=public as $$
declare out text;
begin
  if not public.valid_teacher(p_token) then return json_build_object('ok',false,'message','Teacher session expired.'); end if;
  select 'reg number,mid,end,viva,record' || E'\n' || coalesce(string_agg(format('%s,%s,%s,%s,%s',s.register_number,coalesce(g.mid,0),coalesce(g.end_mark,0),coalesce(g.viva,0),coalesce(g.record,0)),E'\n' order by s.register_number),'') into out
  from public.students s left join public.attempts a on a.student_id=s.id left join public.grades g on g.attempt_id=a.id;
  return json_build_object('ok',true,'csv',out);
end $$;
grant execute on function public.teacher_csv(text) to anon,authenticated;

-- Multiple-session warning: the teacher can see it, but we do not automatically fail a student.
create or replace function public.heartbeat_with_session_check(p_attempt_id uuid,p_session_id text)
returns json language plpgsql security definer set search_path=public as $$
declare other_count integer;
begin
  insert into public.attempt_sessions(attempt_id,session_id) values(p_attempt_id,p_session_id) on conflict(attempt_id,session_id) do update set last_seen_at=now();
  select count(*) into other_count from public.attempt_sessions where attempt_id=p_attempt_id and last_seen_at>now()-interval '45 seconds' and session_id<>p_session_id;
  if other_count>0 and not exists(select 1 from public.proctor_events where attempt_id=p_attempt_id and session_id=p_session_id and event_type='MULTIPLE_SESSION' and created_at>now()-interval '60 seconds') then
    insert into public.proctor_events(attempt_id,session_id,event_type,detail) values(p_attempt_id,p_session_id,'MULTIPLE_SESSION','Another active browser session was detected.');
  end if;
  return json_build_object('ok',true,'multiple_session',other_count>0);
end $$;
grant execute on function public.heartbeat_with_session_check(uuid,text) to anon,authenticated;
