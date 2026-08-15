-- Same relaxation as the previous migration, but for `listings.price` — it was
-- left NOT NULL in T-011, which also blocks saving a partial draft.
alter table public.listings alter column price drop not null;

-- T-029/T-031: creating/editing a vehicle requires a privileged write (RLS only
-- allows service_role to INSERT/UPDATE `vehicles`, per architecture.md §4). This
-- SECURITY DEFINER function is the one sanctioned path for authenticated users to
-- create or edit their own draft — ownership is checked explicitly inside since
-- SECURITY DEFINER bypasses RLS.
--
-- NULL args mean "leave unchanged" on an edit (there's no way to clear a field
-- back to NULL through this function) — acceptable for the MVP wizard, revisit
-- if a "remove value" UX is needed later.
create or replace function public.save_vehicle_draft(
  p_listing_id uuid default null,
  p_plate text default null,
  p_brand text default null,
  p_model text default null,
  p_version text default null,
  p_year int default null,
  p_mileage int default null,
  p_fuel_type text default null,
  p_transmission text default null,
  p_body_type text default null,
  p_color text default null,
  p_price numeric default null,
  p_region text default null,
  p_comuna text default null,
  p_description text default null,
  p_accidents_declared text default null,
  p_financing_declared boolean default null,
  p_condition_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_vehicle_id uuid;
  v_listing_id uuid;
  v_owner uuid;
  v_status text;
begin
  if auth.uid() is null then
    raise exception 'Debes iniciar sesión para guardar un borrador';
  end if;

  if p_listing_id is not null then
    select seller_id, vehicle_id, status into v_owner, v_vehicle_id, v_status
    from public.listings where id = p_listing_id;

    if v_owner is null then
      raise exception 'Aviso no encontrado';
    end if;
    if v_owner <> auth.uid() then
      raise exception 'No tienes permiso para editar este aviso';
    end if;
    if v_status not in ('borrador', 'pendiente_verificacion') then
      raise exception 'Este aviso ya no se puede editar como borrador (estado: %)', v_status;
    end if;

    update public.vehicles set
      plate = coalesce(p_plate, plate),
      brand = coalesce(p_brand, brand),
      model = coalesce(p_model, model),
      version = coalesce(p_version, version),
      year = coalesce(p_year, year),
      mileage = coalesce(p_mileage, mileage),
      fuel_type = coalesce(p_fuel_type, fuel_type),
      transmission = coalesce(p_transmission, transmission),
      body_type = coalesce(p_body_type, body_type),
      color = coalesce(p_color, color)
    where id = v_vehicle_id;

    update public.listings set
      price = coalesce(p_price, price),
      region = coalesce(p_region, region),
      comuna = coalesce(p_comuna, comuna),
      description = coalesce(p_description, description),
      accidents_declared = coalesce(p_accidents_declared, accidents_declared),
      financing_declared = coalesce(p_financing_declared, financing_declared),
      condition_notes = coalesce(p_condition_notes, condition_notes),
      updated_at = now()
    where id = p_listing_id;

    return p_listing_id;
  end if;

  insert into public.vehicles (
    plate, brand, model, version, year, mileage, fuel_type, transmission, body_type, color
  ) values (
    p_plate, p_brand, p_model, p_version, p_year, p_mileage, p_fuel_type, p_transmission, p_body_type, p_color
  )
  returning id into v_vehicle_id;

  insert into public.listings (
    vehicle_id, seller_id, price, region, comuna, description,
    accidents_declared, financing_declared, condition_notes, status
  ) values (
    v_vehicle_id, auth.uid(), p_price, p_region, p_comuna, p_description,
    p_accidents_declared, p_financing_declared, p_condition_notes, 'borrador'
  )
  returning id into v_listing_id;

  return v_listing_id;
end;
$$;

grant execute on function public.save_vehicle_draft to authenticated;

-- Smoke test: create a draft, edit it, confirm another user can't touch it.
do $$
declare
  owner_id uuid := gen_random_uuid();
  intruder_id uuid := gen_random_uuid();
  original_role text := current_user;
  new_listing_id uuid;
  edited_price numeric;
  blocked boolean := false;
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data
  ) values
    ('00000000-0000-0000-0000-000000000000', owner_id, 'authenticated', 'authenticated',
     'migration-smoke-test-draft-owner@example.com', 'smoke-test-placeholder', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
    ('00000000-0000-0000-0000-000000000000', intruder_id, 'authenticated', 'authenticated',
     'migration-smoke-test-draft-intruder@example.com', 'smoke-test-placeholder', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);

  execute 'set local role authenticated';
  perform set_config('request.jwt.claims', json_build_object('sub', owner_id::text)::text, true);

  select public.save_vehicle_draft(p_brand := 'Toyota', p_model := 'Yaris') into new_listing_id;

  perform public.save_vehicle_draft(p_listing_id := new_listing_id, p_price := 7500000);
  select price into edited_price from public.listings where id = new_listing_id;
  if edited_price is distinct from 7500000 then
    execute format('set local role %I', original_role);
    raise exception 'save_vehicle_draft smoke test failed: edit did not persist (got %)', edited_price;
  end if;

  perform set_config('request.jwt.claims', json_build_object('sub', intruder_id::text)::text, true);
  begin
    perform public.save_vehicle_draft(p_listing_id := new_listing_id, p_price := 1);
  exception when others then
    blocked := true;
  end;

  execute format('set local role %I', original_role);

  if not blocked then
    raise exception 'save_vehicle_draft smoke test failed: a different user was able to edit someone else''s draft';
  end if;

  delete from public.vehicles where id = (select vehicle_id from public.listings where id = new_listing_id);
  delete from auth.users where id in (owner_id, intruder_id);
exception when others then
  execute format('set local role %I', original_role);
  raise;
end $$;
