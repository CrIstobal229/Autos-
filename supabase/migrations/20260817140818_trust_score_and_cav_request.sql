-- T-043: Trust Score calculation (REQ-TRUST-001). Gates (identity, theft — see
-- REQ-VER-001/003) are explicitly excluded: every active listing already has
-- them by definition, so they wouldn't differentiate one listing from another.
-- Formula (documented here as the source of truth, referenced from
-- architecture.md §16): CAV verified +60, account tenure up to +40 (1 point per
-- 30 days, capped). An empty `breakdown` means REQ-TRUST-002 applies (show
-- "Sin antecedentes adicionales" instead of the number).
create or replace function public.compute_trust_score(p_listing_id uuid)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_vehicle_id uuid;
  v_seller_id uuid;
  v_last_cav_result text;
  v_account_created_at timestamptz;
  v_tenure_days int;
  v_tenure_points int;
  v_score int := 0;
  v_breakdown jsonb := '[]'::jsonb;
begin
  select vehicle_id, seller_id into v_vehicle_id, v_seller_id
  from public.listings where id = p_listing_id;

  select result into v_last_cav_result
  from public.vehicle_verifications
  where vehicle_id = v_vehicle_id and source = 'cav'
  order by checked_at desc
  limit 1;

  if v_last_cav_result = 'passed' then
    v_score := v_score + 60;
    v_breakdown := v_breakdown || jsonb_build_object(
      'source', 'cav', 'points', 60, 'label', 'Historial de propietarios verificado (CAV)'
    );
  end if;

  select created_at into v_account_created_at from public.profiles where id = v_seller_id;
  v_tenure_days := greatest(0, extract(day from now() - v_account_created_at)::int);
  v_tenure_points := least(40, v_tenure_days / 30);

  if v_tenure_points > 0 then
    v_score := v_score + v_tenure_points;
    v_breakdown := v_breakdown || jsonb_build_object(
      'source', 'account_tenure', 'points', v_tenure_points, 'label', 'Antigüedad de la cuenta'
    );
  end if;

  insert into public.trust_scores (listing_id, score, breakdown)
  values (p_listing_id, v_score, v_breakdown);

  return v_score;
end;
$$;

-- Every listing gets an initial score the moment it activates, so the ficha
-- always has something to show (even if just "Sin antecedentes adicionales").
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

    perform public.compute_trust_score(p_listing_id);
    return true;
  end if;

  return false;
end;
$$;

-- T-042: paying for and requesting the CAV. MOCK — Flow isn't connected yet
-- (T-024/025), so this creates the payment as already 'paid' instead of going
-- through a real checkout. Swap this out for a real PaymentProvider checkout
-- once Flow is confirmed; nothing downstream (verify-cav, trust score) needs
-- to change when that happens.
create or replace function public.request_cav_check(p_listing_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_seller_id uuid;
  v_status text;
  v_payment_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Debes iniciar sesión';
  end if;

  select seller_id, status into v_seller_id, v_status
  from public.listings where id = p_listing_id;

  if v_seller_id is null then
    raise exception 'Aviso no encontrado';
  end if;
  if v_seller_id <> auth.uid() then
    raise exception 'No tienes permiso sobre este aviso';
  end if;
  if v_status not in ('pendiente_verificacion', 'activo') then
    raise exception 'Este aviso todavía no puede solicitar el CAV (estado: %)', v_status;
  end if;

  insert into public.payments (user_id, listing_id, type, amount, status, provider)
  values (auth.uid(), p_listing_id, 'cav_check', 9990, 'paid', 'mock')
  returning id into v_payment_id;

  insert into public.jobs (type, payload)
  values ('verify_cav', jsonb_build_object('listing_id', p_listing_id, 'payment_id', v_payment_id));

  return v_payment_id;
end;
$$;

grant execute on function public.request_cav_check to authenticated;

-- Smoke test: request_cav_check creates a paid payment + enqueues a job, and
-- blocks a non-owner from requesting it on someone else's listing.
do $$
declare
  original_role text := current_user;
  owner_id uuid := gen_random_uuid();
  intruder_id uuid := gen_random_uuid();
  test_vehicle_id uuid;
  test_listing_id uuid;
  payment_id uuid;
  job_count int;
  blocked boolean := false;
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data
  ) values
    ('00000000-0000-0000-0000-000000000000', owner_id, 'authenticated', 'authenticated',
     'migration-smoke-test-cav-owner@example.com', 'smoke-test-placeholder', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
    ('00000000-0000-0000-0000-000000000000', intruder_id, 'authenticated', 'authenticated',
     'migration-smoke-test-cav-intruder@example.com', 'smoke-test-placeholder', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);

  insert into public.vehicles (plate, brand, model, year, mileage, fuel_type, transmission, body_type, color)
  values ('AASM30', 'Toyota', 'Yaris', 2020, 40000, 'bencina', 'manual', 'hatchback', 'rojo')
  returning id into test_vehicle_id;

  insert into public.listings (vehicle_id, seller_id, price, status)
  values (test_vehicle_id, owner_id, 8000000, 'activo')
  returning id into test_listing_id;

  execute 'set local role authenticated';
  perform set_config('request.jwt.claims', json_build_object('sub', owner_id::text)::text, true);

  select public.request_cav_check(test_listing_id) into payment_id;

  perform set_config('request.jwt.claims', json_build_object('sub', intruder_id::text)::text, true);
  begin
    perform public.request_cav_check(test_listing_id);
  exception when others then
    blocked := true;
  end;

  -- Reset role BEFORE reading `jobs` — it has no SELECT policy for authenticated
  -- (service_role only), so checking job_count while still impersonating a user
  -- would read 0 rows regardless of whether the insert actually happened.
  execute format('set local role %I', original_role);

  if not blocked then
    raise exception 'request_cav_check smoke test failed: a different user could request the CAV on someone else''s listing';
  end if;

  select count(*) into job_count from public.jobs
  where type = 'verify_cav' and (payload->>'listing_id')::uuid = test_listing_id;
  if job_count != 1 then
    raise exception 'request_cav_check smoke test failed: expected 1 enqueued job, got %', job_count;
  end if;

  -- Also exercise compute_trust_score directly: no CAV yet, brand-new account -> empty breakdown.
  declare
    v_score int;
    v_breakdown jsonb;
  begin
    select public.compute_trust_score(test_listing_id) into v_score;
    select breakdown into v_breakdown from public.trust_scores where listing_id = test_listing_id order by computed_at desc limit 1;
    if v_breakdown != '[]'::jsonb then
      raise exception 'compute_trust_score smoke test failed: expected empty breakdown for a brand-new account with no CAV, got %', v_breakdown;
    end if;
  end;

  delete from public.jobs where (payload->>'listing_id')::uuid = test_listing_id;
  delete from auth.users where id in (owner_id, intruder_id);
  delete from public.vehicles where id = test_vehicle_id;
exception when others then
  execute format('set local role %I', original_role);
  raise;
end $$;
