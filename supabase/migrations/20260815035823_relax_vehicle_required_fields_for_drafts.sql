-- REQ-PUB-001: "Un aviso puede guardarse como borrador en cualquier estado de
-- completitud, sin restricciones". The original vehicles table (T-011) made most
-- columns NOT NULL, which made saving a partial draft impossible. Completeness is
-- enforced at the application layer (T-032) when moving a listing out of borrador,
-- not by the schema — the DB should only guarantee structural integrity.
alter table public.vehicles alter column plate drop not null;
alter table public.vehicles alter column brand drop not null;
alter table public.vehicles alter column model drop not null;
alter table public.vehicles alter column year drop not null;
alter table public.vehicles alter column mileage drop not null;
alter table public.vehicles alter column fuel_type drop not null;
alter table public.vehicles alter column transmission drop not null;
alter table public.vehicles alter column body_type drop not null;
alter table public.vehicles alter column color drop not null;

-- A NULL plate must still never collide (Postgres already treats multiple NULLs as
-- distinct under a UNIQUE constraint, so no index change is needed) — verified below.
do $$
declare
  v1 uuid;
  v2 uuid;
begin
  insert into public.vehicles default values returning id into v1;
  insert into public.vehicles default values returning id into v2;
  -- If this insert succeeded twice without a unique_violation, NULL plates coexist fine.
  delete from public.vehicles where id in (v1, v2);
end $$;
