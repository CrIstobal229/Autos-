-- T-011: vehicles, listings, listing_photos

create table public.vehicles (
  id uuid primary key default gen_random_uuid(),
  plate text not null unique,
  brand text not null,
  model text not null,
  version text,
  year int not null,
  mileage int not null,
  fuel_type text not null,
  transmission text not null,
  body_type text not null,
  color text not null,
  owners_count int,
  created_at timestamptz not null default now()
);

create table public.listings (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles (id) on delete cascade,
  seller_id uuid not null references public.profiles (id) on delete cascade,
  price numeric not null,
  region text,
  comuna text,
  description text,
  accidents_declared text,
  financing_declared boolean,
  condition_notes text,
  status text not null default 'borrador'
    check (status in ('borrador', 'pendiente_verificacion', 'activo', 'pausado', 'vendido', 'rechazado')),
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index listings_vehicle_id_idx on public.listings (vehicle_id);
create index listings_seller_id_idx on public.listings (seller_id);
create index listings_status_idx on public.listings (status);

create table public.listing_photos (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings (id) on delete cascade,
  storage_path text not null,
  slot text not null
    check (slot in ('frontal', 'trasera', 'lateral_izq', 'lateral_der', 'interior', 'odometro', 'otra')),
  position int not null default 0
);

create index listing_photos_listing_id_idx on public.listing_photos (listing_id);

-- Smoke test: insert a vehicle + listing + photo respecting all FKs, then clean up.
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
    'migration-smoke-test-listing@example.com', 'smoke-test-placeholder',
    now(), now(), now(), '{}'::jsonb, '{}'::jsonb
  );

  insert into public.vehicles (plate, brand, model, year, mileage, fuel_type, transmission, body_type, color)
  values ('AASM01', 'Toyota', 'Yaris', 2020, 40000, 'bencina', 'manual', 'hatchback', 'rojo')
  returning id into test_vehicle_id;

  insert into public.listings (vehicle_id, seller_id, price, region, comuna)
  values (test_vehicle_id, test_user_id, 8000000, 'Metropolitana', 'Providencia')
  returning id into test_listing_id;

  insert into public.listing_photos (listing_id, storage_path, slot, position)
  values (test_listing_id, 'test/frontal.jpg', 'frontal', 0);

  delete from auth.users where id = test_user_id; -- cascades listings/photos via profiles/listings FKs
  delete from public.vehicles where id = test_vehicle_id;
end $$;
