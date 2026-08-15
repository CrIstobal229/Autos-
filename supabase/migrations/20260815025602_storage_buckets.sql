-- T-018: Storage buckets `listing-photos` (public) and `identity-documents` (private) + policies

insert into storage.buckets (id, name, public)
values
  ('listing-photos', 'listing-photos', true),
  ('identity-documents', 'identity-documents', false);

-- listing-photos: anyone can view; only authenticated users can upload/manage their own files
-- (path convention: "<user_id>/<listing_id>/<filename>").
create policy listing_photos_bucket_select on storage.objects
  for select using (bucket_id = 'listing-photos');

create policy listing_photos_bucket_insert on storage.objects
  for insert with check (
    bucket_id = 'listing-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy listing_photos_bucket_modify on storage.objects
  for update using (
    bucket_id = 'listing-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  ) with check (
    bucket_id = 'listing-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy listing_photos_bucket_delete on storage.objects
  for delete using (
    bucket_id = 'listing-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- identity-documents: strictly private. Users can upload their own KYC documents but
-- can never read them back (not even their own) — only service_role (bypasses RLS) does,
-- from process-kyc / admin review tooling, per architecture.md §6/§12.
create policy identity_documents_bucket_insert on storage.objects
  for insert with check (
    bucket_id = 'identity-documents'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
-- No select/update/delete policy for anon/authenticated on this bucket: fully locked down.

-- Smoke test: buckets exist with the expected public/private configuration.
do $$
declare
  public_count int;
  private_count int;
begin
  select count(*) into public_count from storage.buckets where id = 'listing-photos' and public = true;
  select count(*) into private_count from storage.buckets where id = 'identity-documents' and public = false;

  if public_count != 1 then
    raise exception 'T-018 smoke test failed: listing-photos bucket missing or not public';
  end if;
  if private_count != 1 then
    raise exception 'T-018 smoke test failed: identity-documents bucket missing or not private';
  end if;
end $$;
