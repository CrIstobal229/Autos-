-- T-009: profiles table + auto-provisioning trigger from auth.users

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  account_type text not null default 'individual' check (account_type in ('individual', 'dealer')),
  is_admin boolean not null default false,
  identity_status text not null default 'none' check (identity_status in ('none', 'pending', 'verified', 'failed', 'blocked')),
  identity_verified_at timestamptz,
  created_at timestamptz not null default now()
);

-- Auto-creates a profile row whenever a new auth user signs up.
create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', new.email));
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Smoke test: verify the trigger actually provisions a profile row, then clean up.
do $$
declare
  test_user_id uuid := gen_random_uuid();
  provisioned_count int;
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data
  ) values (
    '00000000-0000-0000-0000-000000000000', test_user_id, 'authenticated', 'authenticated',
    'migration-smoke-test@example.com', 'smoke-test-placeholder',
    now(), now(), now(), '{}'::jsonb, '{"full_name":"Smoke Test"}'::jsonb
  );

  select count(*) into provisioned_count from public.profiles where id = test_user_id;
  if provisioned_count != 1 then
    raise exception 'T-009 smoke test failed: expected 1 auto-provisioned profile, got %', provisioned_count;
  end if;

  delete from auth.users where id = test_user_id; -- cascades to profiles
end $$;
