-- Cleanup for the E2E pipeline test (T-033 to T-039), confirmed working end to
-- end against the live deployed Edge Functions: theft-blocked-at-publish,
-- both-gates-activate, and re-verification-deactivates all verified for real.
delete from public.audit_logs
where entity_id in ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000c2');

delete from public.jobs
where (payload->>'listing_id')::uuid in ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000c2');

delete from auth.users
where email in ('e2e-blocked-seller@example.com', 'e2e-ok-seller@example.com'); -- cascades listings/vehicles' listings row

delete from public.vehicles where plate in ('ROBOE2E', 'OKE2E01', 'ROBOE2E2');
