-- Continuation of the E2E pipeline test: simulate the active OKE2E01 listing's
-- vehicle later getting flagged as stolen, then enqueue a re-verification job
-- exactly like reverify-active-listings would after 24h, to exercise T-039's
-- deactivation path via the live process-jobs function.
update public.vehicles set plate = 'ROBOE2E2'
where id = (select vehicle_id from public.listings where id = '00000000-0000-0000-0000-0000000000c2');

insert into public.jobs (type, payload)
values ('verify_theft', jsonb_build_object('listing_id', '00000000-0000-0000-0000-0000000000c2'));
