-- =============================================================================
-- PEMTREE · Fix del CHECK de marketplace_items.status
-- Fecha: 2026-09-14
--
-- El CHECK preexistente permitía 'archived' pero no 'paused', y la app usa
-- 'paused' para pausar una publicación (el botón "Pausar" fallaba con
-- violación de check). Se reemplaza por el conjunto completo: los 4 estados
-- de la app + 'archived' por compatibilidad.
-- =============================================================================

alter table public.marketplace_items
  drop constraint if exists marketplace_items_status_check;

alter table public.marketplace_items
  add constraint marketplace_items_status_check
  check (status in ('available', 'reserved', 'sold', 'paused', 'archived'));

comment on column public.marketplace_items.status is
  'Estado de la publicación: available | reserved | sold | paused | archived.';

do $$
begin
  raise notice 'marketplace_items_status_check: %',
    (select pg_get_constraintdef(oid) from pg_constraint
     where conrelid='public.marketplace_items'::regclass and conname='marketplace_items_status_check');
end $$;
