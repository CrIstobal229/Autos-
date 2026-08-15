-- T-013: conversations + messages

create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings (id) on delete cascade,
  buyer_id uuid not null references public.profiles (id) on delete cascade,
  seller_id uuid not null references public.profiles (id) on delete cascade,
  last_message_at timestamptz,
  created_at timestamptz not null default now(),
  unique (listing_id, buyer_id)
);

create index conversations_buyer_id_idx on public.conversations (buyer_id);
create index conversations_seller_id_idx on public.conversations (seller_id);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  sender_id uuid not null references public.profiles (id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now()
);

create index messages_conversation_id_idx on public.messages (conversation_id);

-- Smoke test: create a conversation + message, confirm the UNIQUE(listing_id, buyer_id) constraint, clean up.
do $$
declare
  buyer_id uuid := gen_random_uuid();
  seller_id uuid := gen_random_uuid();
  test_vehicle_id uuid;
  test_listing_id uuid;
  test_conversation_id uuid;
  duplicate_blocked boolean := false;
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data
  ) values
    ('00000000-0000-0000-0000-000000000000', buyer_id, 'authenticated', 'authenticated',
     'migration-smoke-test-buyer@example.com', 'smoke-test-placeholder', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
    ('00000000-0000-0000-0000-000000000000', seller_id, 'authenticated', 'authenticated',
     'migration-smoke-test-seller@example.com', 'smoke-test-placeholder', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);

  insert into public.vehicles (plate, brand, model, year, mileage, fuel_type, transmission, body_type, color)
  values ('AASM03', 'Toyota', 'Yaris', 2020, 40000, 'bencina', 'manual', 'hatchback', 'rojo')
  returning id into test_vehicle_id;

  insert into public.listings (vehicle_id, seller_id, price)
  values (test_vehicle_id, seller_id, 8000000)
  returning id into test_listing_id;

  insert into public.conversations (listing_id, buyer_id, seller_id)
  values (test_listing_id, buyer_id, seller_id)
  returning id into test_conversation_id;

  insert into public.messages (conversation_id, sender_id, body)
  values (test_conversation_id, buyer_id, 'Smoke test message');

  begin
    insert into public.conversations (listing_id, buyer_id, seller_id) values (test_listing_id, buyer_id, seller_id);
  exception when unique_violation then
    duplicate_blocked := true;
  end;

  if not duplicate_blocked then
    raise exception 'T-013 smoke test failed: UNIQUE(listing_id, buyer_id) did not block a duplicate conversation';
  end if;

  delete from auth.users where id in (buyer_id, seller_id);
  delete from public.vehicles where id = test_vehicle_id;
end $$;
