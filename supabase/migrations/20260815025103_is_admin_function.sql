-- T-010: helper used by RLS policies to check the admin flag of the current session's user

create function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((select is_admin from public.profiles where id = auth.uid()), false);
$$;

-- Smoke test: a profile with is_admin=false must evaluate to false when impersonated.
do $$
declare
  test_user_id uuid := gen_random_uuid();
  result boolean;
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data
  ) values (
    '00000000-0000-0000-0000-000000000000', test_user_id, 'authenticated', 'authenticated',
    'migration-smoke-test-admin@example.com', 'smoke-test-placeholder',
    now(), now(), now(), '{}'::jsonb, '{}'::jsonb
  );

  perform set_config('request.jwt.claims', json_build_object('sub', test_user_id::text)::text, true);
  select public.is_admin() into result;
  if result is distinct from false then
    raise exception 'T-010 smoke test failed: is_admin() should be false for a non-admin profile, got %', result;
  end if;

  delete from auth.users where id = test_user_id;
end $$;
