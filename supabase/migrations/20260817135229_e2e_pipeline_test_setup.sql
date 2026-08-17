-- Temporary: two real draft listings, submitted to pendiente_verificacion, to
-- exercise the deployed process-jobs Edge Function end to end — one plate
-- that should get blocked (ROBO-prefixed), one that should reach activo
-- (identity pre-verified to isolate the theft-check path). Cleaned up in the
-- next migration once confirmed via the live function calls.
do $$
declare
  blocked_seller uuid := gen_random_uuid();
  ok_seller uuid := gen_random_uuid();
  blocked_vehicle uuid;
  ok_vehicle uuid;
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data
  ) values
    ('00000000-0000-0000-0000-000000000000', blocked_seller, 'authenticated', 'authenticated',
     'e2e-blocked-seller@example.com', 'smoke-test-placeholder', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
    ('00000000-0000-0000-0000-000000000000', ok_seller, 'authenticated', 'authenticated',
     'e2e-ok-seller@example.com', 'smoke-test-placeholder', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);

  update public.profiles set identity_status = 'verified' where id = ok_seller;

  insert into public.vehicles (plate, brand, model, year, mileage, fuel_type, transmission, body_type, color)
  values ('ROBOE2E', 'Toyota', 'Yaris', 2020, 40000, 'bencina', 'manual', 'hatchback', 'rojo')
  returning id into blocked_vehicle;

  insert into public.vehicles (plate, brand, model, year, mileage, fuel_type, transmission, body_type, color)
  values ('OKE2E01', 'Toyota', 'Yaris', 2020, 40000, 'bencina', 'manual', 'hatchback', 'azul')
  returning id into ok_vehicle;

  insert into public.listings (id, vehicle_id, seller_id, price, status)
  values ('00000000-0000-0000-0000-0000000000c1', blocked_vehicle, blocked_seller, 8000000, 'borrador');
  update public.listings set status = 'pendiente_verificacion' where id = '00000000-0000-0000-0000-0000000000c1';

  insert into public.listings (id, vehicle_id, seller_id, price, status)
  values ('00000000-0000-0000-0000-0000000000c2', ok_vehicle, ok_seller, 8000000, 'borrador');
  update public.listings set status = 'pendiente_verificacion' where id = '00000000-0000-0000-0000-0000000000c2';
end $$;
