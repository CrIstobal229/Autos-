-- T-017: Row Level Security for every table (architecture.md §4).
-- General rule: public read only where the product requires it (active listings,
-- verifications, trust scores); everything else requires ownership or is_admin().

alter table public.profiles enable row level security;
alter table public.kyc_attempts enable row level security;
alter table public.vehicles enable row level security;
alter table public.listings enable row level security;
alter table public.listing_photos enable row level security;
alter table public.vehicle_verifications enable row level security;
alter table public.trust_scores enable row level security;
alter table public.conversations enable row level security;
alter table public.messages enable row level security;
alter table public.favorites enable row level security;
alter table public.reports enable row level security;
alter table public.payments enable row level security;
alter table public.boosts enable row level security;
alter table public.jobs enable row level security;
alter table public.audit_logs enable row level security;

-- ── profiles ─────────────────────────────────────────────────────────────
-- Sensitive columns (is_admin, identity_status, identity_verified_at) are readable
-- only by the owner/admin; a public view exposes only what other users may see.
create policy profiles_select_own_or_admin on public.profiles
  for select using (id = auth.uid() or public.is_admin());

create policy profiles_update_own on public.profiles
  for update using (id = auth.uid()) with check (id = auth.uid());

-- Prevents a user from escalating themselves via the otherwise-permitted UPDATE above.
create function public.protect_profile_privileged_columns()
returns trigger
language plpgsql
as $$
begin
  if not (select rolbypassrls from pg_roles where rolname = current_user) then
    if new.is_admin is distinct from old.is_admin
       or new.identity_status is distinct from old.identity_status
       or new.identity_verified_at is distinct from old.identity_verified_at then
      raise exception 'profiles.is_admin / identity_status / identity_verified_at can only be changed by a privileged process';
    end if;
  end if;
  return new;
end;
$$;

create trigger profiles_protect_privileged_columns
  before update on public.profiles
  for each row execute function public.protect_profile_privileged_columns();

create view public.public_profiles
  with (security_invoker = true) as
  select id, display_name, account_type, created_at
  from public.profiles;

grant select on public.public_profiles to anon, authenticated;

-- ── kyc_attempts ─────────────────────────────────────────────────────────
create policy kyc_attempts_select_admin on public.kyc_attempts
  for select using (public.is_admin());
-- No insert/update policy for anon/authenticated: only service_role (bypasses RLS) writes here.

-- ── vehicles ─────────────────────────────────────────────────────────────
create policy vehicles_select_public on public.vehicles
  for select using (true);
-- No insert/update policy: vehicles are created only via a privileged Server Action (service_role).

-- ── listings ─────────────────────────────────────────────────────────────
create policy listings_select_active_or_own on public.listings
  for select using (status = 'activo' or seller_id = auth.uid() or public.is_admin());

create policy listings_insert_own on public.listings
  for insert with check (seller_id = auth.uid());

create policy listings_update_own_or_admin on public.listings
  for update using (seller_id = auth.uid() or public.is_admin())
  with check (seller_id = auth.uid() or public.is_admin());

-- Defense in depth for REQ-VER-001/003: a listing can only reach 'activo' through a
-- privileged (service_role) process — never directly by the owner's own request.
create function public.prevent_client_listing_activation()
returns trigger
language plpgsql
as $$
begin
  if new.status = 'activo' and old.status is distinct from 'activo' then
    if not (select rolbypassrls from pg_roles where rolname = current_user) then
      raise exception 'listings.status can only transition to activo via a privileged verification process';
    end if;
  end if;
  return new;
end;
$$;

create trigger listings_prevent_client_activation
  before update on public.listings
  for each row execute function public.prevent_client_listing_activation();

-- ── listing_photos ───────────────────────────────────────────────────────
create policy listing_photos_select_visible on public.listing_photos
  for select using (
    exists (
      select 1 from public.listings l
      where l.id = listing_photos.listing_id
        and (l.status = 'activo' or l.seller_id = auth.uid() or public.is_admin())
    )
  );

create policy listing_photos_write_own on public.listing_photos
  for all using (
    exists (select 1 from public.listings l where l.id = listing_photos.listing_id and l.seller_id = auth.uid())
  ) with check (
    exists (select 1 from public.listings l where l.id = listing_photos.listing_id and l.seller_id = auth.uid())
  );

-- ── vehicle_verifications / trust_scores ────────────────────────────────
create policy vehicle_verifications_select_public on public.vehicle_verifications
  for select using (true);

create policy trust_scores_select_public on public.trust_scores
  for select using (true);
-- No insert/update policy on either: only service_role writes verification/scoring results.

-- ── conversations / messages ─────────────────────────────────────────────
alter table public.conversations add constraint conversations_buyer_not_seller check (buyer_id <> seller_id);

create policy conversations_select_participant on public.conversations
  for select using (buyer_id = auth.uid() or seller_id = auth.uid() or public.is_admin());

create policy conversations_insert_as_buyer on public.conversations
  for insert with check (
    buyer_id = auth.uid()
    and seller_id = (select l.seller_id from public.listings l where l.id = listing_id)
  );

create policy messages_select_participant on public.messages
  for select using (
    exists (
      select 1 from public.conversations c
      where c.id = messages.conversation_id and (c.buyer_id = auth.uid() or c.seller_id = auth.uid())
    )
  );

create policy messages_insert_participant on public.messages
  for insert with check (
    sender_id = auth.uid()
    and exists (
      select 1 from public.conversations c
      where c.id = conversation_id and (c.buyer_id = auth.uid() or c.seller_id = auth.uid())
    )
  );

-- ── favorites ────────────────────────────────────────────────────────────
create policy favorites_owner_all on public.favorites
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ── reports ──────────────────────────────────────────────────────────────
create policy reports_select_own_or_admin on public.reports
  for select using (reporter_id = auth.uid() or public.is_admin());

create policy reports_insert_own on public.reports
  for insert with check (reporter_id = auth.uid());

create policy reports_update_admin on public.reports
  for update using (public.is_admin()) with check (public.is_admin());

-- ── payments ─────────────────────────────────────────────────────────────
create policy payments_select_own_or_admin on public.payments
  for select using (user_id = auth.uid() or public.is_admin());
-- No insert/update policy: created/updated only via service_role (checkout + webhook).

-- ── boosts ───────────────────────────────────────────────────────────────
create policy boosts_select_public on public.boosts
  for select using (true);
-- No insert/update policy: only service_role, once the related payment is confirmed.

-- ── jobs / audit_logs ────────────────────────────────────────────────────
-- jobs: no policies at all for anon/authenticated — fully internal, service_role only.

create policy audit_logs_select_admin on public.audit_logs
  for select using (public.is_admin());
-- No insert policy: only service_role writes audit entries.

-- ── Smoke test: RLS actually isolates rows between two different authenticated users ──
do $$
declare
  original_role text := current_user;
  buyer_a uuid := gen_random_uuid();
  buyer_b uuid := gen_random_uuid();
  test_vehicle_id uuid;
  draft_listing_id uuid;
  active_listing_id uuid;
  visible_count int;
  affected_rows int;
  activation_blocked boolean := false;
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data
  ) values
    ('00000000-0000-0000-0000-000000000000', buyer_a, 'authenticated', 'authenticated',
     'migration-smoke-test-rls-a@example.com', 'smoke-test-placeholder', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
    ('00000000-0000-0000-0000-000000000000', buyer_b, 'authenticated', 'authenticated',
     'migration-smoke-test-rls-b@example.com', 'smoke-test-placeholder', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);

  insert into public.vehicles (plate, brand, model, year, mileage, fuel_type, transmission, body_type, color)
  values ('AASM10', 'Toyota', 'Yaris', 2020, 40000, 'bencina', 'manual', 'hatchback', 'rojo')
  returning id into test_vehicle_id;

  insert into public.listings (vehicle_id, seller_id, price, status)
  values (test_vehicle_id, buyer_a, 8000000, 'borrador')
  returning id into draft_listing_id;

  insert into public.listings (vehicle_id, seller_id, price, status)
  values (test_vehicle_id, buyer_a, 9000000, 'activo')
  returning id into active_listing_id;

  -- Impersonate buyer_b (not the owner, not admin) with a genuinely restricted role.
  execute 'set local role authenticated';
  perform set_config('request.jwt.claims', json_build_object('sub', buyer_b::text)::text, true);

  select count(*) into visible_count from public.listings where id = draft_listing_id;
  if visible_count != 0 then
    execute format('set local role %I', original_role);
    raise exception 'T-017 smoke test failed: buyer_b could see buyer_a''s borrador listing (RLS not isolating)';
  end if;

  select count(*) into visible_count from public.listings where id = active_listing_id;
  if visible_count != 1 then
    execute format('set local role %I', original_role);
    raise exception 'T-017 smoke test failed: buyer_b could not see an activo listing (public visibility broken)';
  end if;

  update public.listings set price = 1 where id = draft_listing_id;
  get diagnostics affected_rows = row_count;
  if affected_rows != 0 then
    execute format('set local role %I', original_role);
    raise exception 'T-017 smoke test failed: buyer_b was able to update buyer_a''s listing';
  end if;

  -- Now impersonate buyer_a (the actual owner) to test the activation-guard trigger.
  perform set_config('request.jwt.claims', json_build_object('sub', buyer_a::text)::text, true);

  update public.listings set price = 8500000 where id = draft_listing_id;
  get diagnostics affected_rows = row_count;
  if affected_rows != 1 then
    execute format('set local role %I', original_role);
    raise exception 'T-017 smoke test failed: buyer_a could not update their own listing (ownership access broken)';
  end if;

  begin
    update public.listings set status = 'activo' where id = draft_listing_id;
  exception when others then
    activation_blocked := true;
  end;

  -- Restore the original privileged role before touching auth.users / doing cleanup.
  execute format('set local role %I', original_role);

  if not activation_blocked then
    raise exception 'T-017 smoke test failed: the owner was able to self-activate a listing (activation guard not working)';
  end if;

  delete from auth.users where id in (buyer_a, buyer_b);
  delete from public.vehicles where id = test_vehicle_id;
exception when others then
  execute format('set local role %I', original_role);
  raise;
end $$;
