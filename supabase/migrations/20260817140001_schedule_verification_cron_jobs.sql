-- T-034/T-038: schedule the two verification Edge Functions via pg_cron + pg_net.
-- The auth key is looked up from Vault at run time (`edge_function_secret_key`,
-- seeded out-of-band via `supabase db query`, never committed to this repo) —
-- the raw secret never appears in a migration file or in git history.

select cron.schedule(
  'process-jobs-every-5-min',
  '*/5 * * * *',
  $$
  select net.http_post(
    url := 'https://sumeqrzkxegpvxctudkg.supabase.co/functions/v1/process-jobs',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name = 'edge_function_secret_key'),
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
  $$
);

select cron.schedule(
  'reverify-active-listings-daily',
  '0 3 * * *',
  $$
  select net.http_post(
    url := 'https://sumeqrzkxegpvxctudkg.supabase.co/functions/v1/reverify-active-listings',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name = 'edge_function_secret_key'),
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
  $$
);
