-- T-035: whenever a listing enters pendiente_verificacion, enqueue a verify_theft
-- job. SECURITY DEFINER because `jobs` has no INSERT policy for `authenticated`
-- (T-017) — only a privileged process may enqueue work.
create or replace function public.enqueue_theft_verification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'pendiente_verificacion' and old.status is distinct from 'pendiente_verificacion' then
    insert into public.jobs (type, payload)
    values ('verify_theft', jsonb_build_object('listing_id', new.id));
  end if;
  return new;
end;
$$;

create trigger listings_enqueue_theft_verification
  after update on public.listings
  for each row execute function public.enqueue_theft_verification();

-- T-036: a listing only ever reaches 'activo' through this function, called by
-- process-jobs after a theft check and (once T-028 exists) after identity
-- verification. It re-checks both gates from their source of truth every time,
-- rather than trusting a caller's claim that "both passed".
create or replace function public.try_activate_listing(p_listing_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_vehicle_id uuid;
  v_seller_id uuid;
  v_status text;
  v_last_theft_result text;
  v_identity_status text;
begin
  select vehicle_id, seller_id, status into v_vehicle_id, v_seller_id, v_status
  from public.listings where id = p_listing_id;

  if v_status is distinct from 'pendiente_verificacion' then
    return false;
  end if;

  select result into v_last_theft_result
  from public.vehicle_verifications
  where vehicle_id = v_vehicle_id and source = 'auto_seguro'
  order by checked_at desc
  limit 1;

  select identity_status into v_identity_status
  from public.profiles where id = v_seller_id;

  if v_last_theft_result = 'passed' and v_identity_status = 'verified' then
    update public.listings
    set status = 'activo', published_at = coalesce(published_at, now())
    where id = p_listing_id;
    return true;
  end if;

  return false;
end;
$$;

-- Smoke test: submitting for verification enqueues a job; activation only
-- happens once both gates are satisfied, never with just one.
do $$
declare
  seller_id uuid := gen_random_uuid();
  original_role text := current_user;
  test_vehicle_id uuid;
  test_listing_id uuid;
  job_count int;
  activated boolean;
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data
  ) values (
    '00000000-0000-0000-0000-000000000000', seller_id, 'authenticated', 'authenticated',
    'migration-smoke-test-theft-gate@example.com', 'smoke-test-placeholder', now(), now(), now(), '{}'::jsonb, '{}'::jsonb
  );

  insert into public.vehicles (plate, brand, model, year, mileage, fuel_type, transmission, body_type, color)
  values ('AASM20', 'Toyota', 'Yaris', 2020, 40000, 'bencina', 'manual', 'hatchback', 'rojo')
  returning id into test_vehicle_id;

  insert into public.listings (vehicle_id, seller_id, price, status)
  values (test_vehicle_id, seller_id, 8000000, 'borrador')
  returning id into test_listing_id;

  update public.listings set status = 'pendiente_verificacion' where id = test_listing_id;

  select count(*) into job_count from public.jobs
  where type = 'verify_theft' and (payload->>'listing_id')::uuid = test_listing_id;
  if job_count != 1 then
    raise exception 'theft_gate_pipeline smoke test failed: expected 1 enqueued job, got %', job_count;
  end if;

  -- Neither gate satisfied yet: must not activate.
  select public.try_activate_listing(test_listing_id) into activated;
  if activated then
    raise exception 'theft_gate_pipeline smoke test failed: activated with no gates passed';
  end if;

  -- Only the theft gate passed: still must not activate.
  insert into public.vehicle_verifications (vehicle_id, source, is_gate, result)
  values (test_vehicle_id, 'auto_seguro', true, 'passed');
  select public.try_activate_listing(test_listing_id) into activated;
  if activated then
    raise exception 'theft_gate_pipeline smoke test failed: activated with only the theft gate passed';
  end if;

  -- Both gates now satisfied: must activate.
  update public.profiles set identity_status = 'verified' where id = seller_id;
  select public.try_activate_listing(test_listing_id) into activated;
  if not activated then
    raise exception 'theft_gate_pipeline smoke test failed: did not activate with both gates passed';
  end if;

  delete from public.jobs where (payload->>'listing_id')::uuid = test_listing_id;
  delete from auth.users where id = seller_id;
  delete from public.vehicles where id = test_vehicle_id;
exception when others then
  execute format('set local role %I', original_role);
  raise;
end $$;
