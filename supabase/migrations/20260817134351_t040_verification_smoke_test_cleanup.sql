-- Cleanup for the previous migration's T-040 smoke test data, confirmed against
-- the real PostgREST API with the anon key.
delete from public.vehicles where id = '00000000-0000-0000-0000-0000000000a0';
delete from auth.users where email = 't040-smoke-test-seller@example.com';
