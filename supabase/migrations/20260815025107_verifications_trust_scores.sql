-- T-012: vehicle_verifications (append-only log) + trust_scores (append-only history)

create table public.vehicle_verifications (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles (id) on delete cascade,
  source text not null check (source in ('auto_seguro', 'cav', 'prenda', 'multas')),
  is_gate boolean not null,
  result text not null check (result in ('passed', 'failed', 'error')),
  raw_result jsonb,
  checked_at timestamptz not null default now()
);

create index vehicle_verifications_vehicle_id_idx on public.vehicle_verifications (vehicle_id);

create table public.trust_scores (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings (id) on delete cascade,
  score int not null check (score between 0 and 100),
  breakdown jsonb not null default '[]'::jsonb,
  computed_at timestamptz not null default now()
);

create index trust_scores_listing_id_idx on public.trust_scores (listing_id);

-- Smoke test: insert a verification + trust score for a throwaway vehicle/listing, then clean up.
do $$
declare
  test_user_id uuid := gen_random_uuid();
  test_vehicle_id uuid;
  test_listing_id uuid;
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data
  ) values (
    '00000000-0000-0000-0000-000000000000', test_user_id, 'authenticated', 'authenticated',
    'migration-smoke-test-verif@example.com', 'smoke-test-placeholder',
    now(), now(), now(), '{}'::jsonb, '{}'::jsonb
  );

  insert into public.vehicles (plate, brand, model, year, mileage, fuel_type, transmission, body_type, color)
  values ('AASM02', 'Toyota', 'Yaris', 2020, 40000, 'bencina', 'manual', 'hatchback', 'rojo')
  returning id into test_vehicle_id;

  insert into public.listings (vehicle_id, seller_id, price)
  values (test_vehicle_id, test_user_id, 8000000)
  returning id into test_listing_id;

  insert into public.vehicle_verifications (vehicle_id, source, is_gate, result)
  values (test_vehicle_id, 'auto_seguro', true, 'passed');

  insert into public.trust_scores (listing_id, score, breakdown)
  values (test_listing_id, 0, '[]'::jsonb);

  delete from auth.users where id = test_user_id;
  delete from public.vehicles where id = test_vehicle_id;
end $$;
