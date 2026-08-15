-- T-015: payments + boosts

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  listing_id uuid references public.listings (id) on delete set null,
  type text not null check (type in ('boost', 'cav_check')),
  amount numeric not null,
  currency text not null default 'CLP',
  status text not null default 'pending' check (status in ('pending', 'paid', 'failed', 'refunded')),
  provider text,
  provider_ref text,
  created_at timestamptz not null default now()
);

create index payments_user_id_idx on public.payments (user_id);
create index payments_listing_id_idx on public.payments (listing_id);

create table public.boosts (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings (id) on delete cascade,
  payment_id uuid not null references public.payments (id) on delete cascade,
  starts_at timestamptz not null,
  ends_at timestamptz not null
);

create index boosts_listing_id_idx on public.boosts (listing_id);

-- Smoke test: insert a payment + boost for a throwaway listing, then clean up.
do $$
declare
  test_user_id uuid := gen_random_uuid();
  test_vehicle_id uuid;
  test_listing_id uuid;
  test_payment_id uuid;
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data
  ) values (
    '00000000-0000-0000-0000-000000000000', test_user_id, 'authenticated', 'authenticated',
    'migration-smoke-test-pay@example.com', 'smoke-test-placeholder',
    now(), now(), now(), '{}'::jsonb, '{}'::jsonb
  );

  insert into public.vehicles (plate, brand, model, year, mileage, fuel_type, transmission, body_type, color)
  values ('AASM05', 'Toyota', 'Yaris', 2020, 40000, 'bencina', 'manual', 'hatchback', 'rojo')
  returning id into test_vehicle_id;

  insert into public.listings (vehicle_id, seller_id, price)
  values (test_vehicle_id, test_user_id, 8000000)
  returning id into test_listing_id;

  insert into public.payments (user_id, listing_id, type, amount, status)
  values (test_user_id, test_listing_id, 'boost', 9990, 'paid')
  returning id into test_payment_id;

  insert into public.boosts (listing_id, payment_id, starts_at, ends_at)
  values (test_listing_id, test_payment_id, now(), now() + interval '7 days');

  delete from auth.users where id = test_user_id;
  delete from public.vehicles where id = test_vehicle_id;
end $$;
