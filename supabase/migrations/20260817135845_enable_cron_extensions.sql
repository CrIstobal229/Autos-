-- Required for scheduling process-jobs / reverify-active-listings (T-034/T-038).
create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;
