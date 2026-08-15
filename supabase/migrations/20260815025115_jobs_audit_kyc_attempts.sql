-- T-016: jobs (generic async queue), audit_logs (append-only), kyc_attempts (private)

create table public.jobs (
  id uuid primary key default gen_random_uuid(),
  type text not null,
  payload jsonb not null default '{}'::jsonb,
  status text not null default 'pending' check (status in ('pending', 'processing', 'done', 'failed')),
  attempts int not null default 0,
  max_attempts int not null default 5,
  next_run_at timestamptz not null default now(),
  last_error text,
  created_at timestamptz not null default now()
);

create index jobs_status_next_run_at_idx on public.jobs (status, next_run_at);

create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.profiles (id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id uuid not null,
  metadata jsonb,
  created_at timestamptz not null default now()
);

create index audit_logs_entity_idx on public.audit_logs (entity_type, entity_id);

create table public.kyc_attempts (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete cascade,
  status text not null check (status in ('pending', 'passed', 'failed', 'fraud_suspected')),
  provider text not null,
  raw_result jsonb,
  created_at timestamptz not null default now()
);

create index kyc_attempts_profile_id_idx on public.kyc_attempts (profile_id);

-- Smoke test: enqueue a job and record an audit log entry, then clean up.
do $$
declare
  test_job_id uuid;
  test_log_id uuid;
begin
  insert into public.jobs (type, payload) values ('verify_theft', '{"plate":"AASM99"}'::jsonb)
  returning id into test_job_id;

  insert into public.audit_logs (action, entity_type, entity_id, metadata)
  values ('smoke_test', 'job', test_job_id, '{}'::jsonb)
  returning id into test_log_id;

  delete from public.audit_logs where id = test_log_id;
  delete from public.jobs where id = test_job_id;
end $$;
