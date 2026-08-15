-- T-014: favorites + reports

create table public.favorites (
  user_id uuid not null references public.profiles (id) on delete cascade,
  listing_id uuid not null references public.listings (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, listing_id)
);

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings (id) on delete cascade,
  reporter_id uuid not null references public.profiles (id) on delete cascade,
  reason text not null check (reason in ('fraude', 'datos_falsos', 'duplicado', 'ya_vendido', 'otro')),
  comment text,
  status text not null default 'pendiente' check (status in ('pendiente', 'revisado')),
  resolved_by uuid references public.profiles (id),
  resolved_at timestamptz,
  created_at timestamptz not null default now()
);

create index reports_listing_id_idx on public.reports (listing_id);
create index reports_status_idx on public.reports (status);

-- Smoke test: mark a favorite and create a report against a throwaway listing, then clean up.
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
    'migration-smoke-test-fav@example.com', 'smoke-test-placeholder',
    now(), now(), now(), '{}'::jsonb, '{}'::jsonb
  );

  insert into public.vehicles (plate, brand, model, year, mileage, fuel_type, transmission, body_type, color)
  values ('AASM04', 'Toyota', 'Yaris', 2020, 40000, 'bencina', 'manual', 'hatchback', 'rojo')
  returning id into test_vehicle_id;

  insert into public.listings (vehicle_id, seller_id, price)
  values (test_vehicle_id, test_user_id, 8000000)
  returning id into test_listing_id;

  insert into public.favorites (user_id, listing_id) values (test_user_id, test_listing_id);
  insert into public.reports (listing_id, reporter_id, reason) values (test_listing_id, test_user_id, 'duplicado');

  delete from auth.users where id = test_user_id;
  delete from public.vehicles where id = test_vehicle_id;
end $$;
