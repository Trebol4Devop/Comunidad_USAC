-- =============================================================================
-- PEMTREE · Constraints faltantes
-- Fecha: 2026-09-14
--
-- Corrige el hallazgo "Faltan unique constraints":
--   1. post_poll_votes: se agrega FK compuesta (poll_id, option_id) →
--      post_poll_options(poll_id, id), con su UNIQUE (poll_id, id) como destino.
--      Así se garantiza que la opción votada pertenece al poll votado.
--   2. sponsor_requests.status: CHECK con los estados válidos.
--   3. marketplace_items.status: CHECK con los estados de la app.
--   4. entity_reports.moderation_status: CHECK 0..3 (respalda la vista
--      marketplace_reports, que al ser vista no admite CHECK propio).
--
-- Notas:
--   - seccion_reviews YA tenía UNIQUE (curso_codigo, seccion, user_id) y policy
--     de UPDATE del autor; no se toca.
--   - marketplace_reports es una VISTA sobre entity_reports: el status se deriva
--     de metadata->>'legacy_status' y se escribe vía trigger INSTEAD OF; el
--     enforcement real va en las columnas subyacentes.
--
-- Es idempotente.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) post_poll_options: UNIQUE (poll_id, id) como destino de la FK compuesta
-- -----------------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.post_poll_options'::regclass
      and conname = 'post_poll_options_poll_id_id_key'
  ) then
    alter table public.post_poll_options
      add constraint post_poll_options_poll_id_id_key unique (poll_id, id);
  end if;
end $$;

-- -----------------------------------------------------------------------------
-- 2) post_poll_votes: limpiar votos inconsistentes + FK compuesta
-- -----------------------------------------------------------------------------
delete from public.post_poll_votes v
using public.post_poll_options o
where o.id = v.option_id
  and o.poll_id is distinct from v.poll_id;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.post_poll_votes'::regclass
      and conname = 'post_poll_votes_poll_option_fkey'
  ) then
    alter table public.post_poll_votes
      add constraint post_poll_votes_poll_option_fkey
      foreign key (poll_id, option_id)
      references public.post_poll_options(poll_id, id)
      on delete cascade;
  end if;
end $$;

-- La FK simple de option_id queda cubierta por la compuesta.
alter table public.post_poll_votes
  drop constraint if exists post_poll_votes_option_id_fkey;

-- -----------------------------------------------------------------------------
-- 3) sponsor_requests.status: CHECK de estados válidos
--    (si el panel admin usa otro estado, se agrega aquí)
-- -----------------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.sponsor_requests'::regclass
      and conname = 'sponsor_requests_status_check'
  ) then
    alter table public.sponsor_requests
      add constraint sponsor_requests_status_check
      check (status in ('pending', 'in_review', 'approved', 'rejected'));
  end if;
end $$;

-- -----------------------------------------------------------------------------
-- 4) marketplace_items.status: CHECK de estados válidos
-- -----------------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.marketplace_items'::regclass
      and conname = 'marketplace_items_status_check'
  ) then
    alter table public.marketplace_items
      add constraint marketplace_items_status_check
      check (status in ('available', 'reserved', 'sold', 'paused'));
  end if;
end $$;

-- -----------------------------------------------------------------------------
-- 5) entity_reports.moderation_status: escala 0..3
--    (respalda marketplace_reports.status y el resto de vistas de moderación)
-- -----------------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.entity_reports'::regclass
      and conname = 'entity_reports_moderation_status_check'
  ) then
    alter table public.entity_reports
      add constraint entity_reports_moderation_status_check
      check (moderation_status between 0 and 3);
  end if;
end $$;

-- -----------------------------------------------------------------------------
-- 6) Resumen
-- -----------------------------------------------------------------------------
do $$
declare
  v_post_poll_options text;
  v_post_poll_votes text;
  v_sponsor text;
  v_marketplace text;
  v_entity text;
begin
  select pg_get_constraintdef(oid) into v_post_poll_options
  from pg_constraint
  where conrelid='public.post_poll_options'::regclass and conname='post_poll_options_poll_id_id_key';

  select pg_get_constraintdef(oid) into v_post_poll_votes
  from pg_constraint
  where conrelid='public.post_poll_votes'::regclass and conname='post_poll_votes_poll_option_fkey';

  select pg_get_constraintdef(oid) into v_sponsor
  from pg_constraint
  where conrelid='public.sponsor_requests'::regclass and conname='sponsor_requests_status_check';

  select pg_get_constraintdef(oid) into v_marketplace
  from pg_constraint
  where conrelid='public.marketplace_items'::regclass and conname='marketplace_items_status_check';

  select pg_get_constraintdef(oid) into v_entity
  from pg_constraint
  where conrelid='public.entity_reports'::regclass and conname='entity_reports_moderation_status_check';

  raise notice 'post_poll_options: %', v_post_poll_options;
  raise notice 'post_poll_votes: %', v_post_poll_votes;
  raise notice 'sponsor_requests: %', v_sponsor;
  raise notice 'marketplace_items: %', v_marketplace;
  raise notice 'entity_reports: %', v_entity;
end $$;
