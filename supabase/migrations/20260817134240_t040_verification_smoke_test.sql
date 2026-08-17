-- Temporary: seeds one real `activo` listing with a passed theft verification
-- so /vehiculos/[id]'s query can be checked against the real PostgREST API
-- with just the anon key (simulating an anonymous visitor). Removed by the
-- next migration once confirmed.
do $$
declare
  seller_id uuid := gen_random_uuid();
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data
  ) values (
    '00000000-0000-0000-0000-000000000000', seller_id, 'authenticated', 'authenticated',
    't040-smoke-test-seller@example.com', 'smoke-test-placeholder', now(), now(), now(), '{}'::jsonb, '{}'::jsonb
  );

  insert into public.vehicles (id, plate, brand, model, year, mileage, fuel_type, transmission, body_type, color)
  values ('00000000-0000-0000-0000-0000000000a0', 'AAT040', 'Toyota', 'Yaris', 2020, 40000, 'bencina', 'manual', 'hatchback', 'rojo');

  insert into public.listings (id, vehicle_id, seller_id, price, region, comuna, description, status, published_at)
  values (
    '00000000-0000-0000-0000-0000000000b0',
    '00000000-0000-0000-0000-0000000000a0',
    seller_id, 8500000, 'Metropolitana', 'Providencia', 'T-040 smoke test listing', 'activo', now()
  );

  insert into public.vehicle_verifications (vehicle_id, source, is_gate, result)
  values ('00000000-0000-0000-0000-0000000000a0', 'auto_seguro', true, 'passed');
end $$;
