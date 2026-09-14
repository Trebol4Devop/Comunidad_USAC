-- =============================================================================
-- PEMTREE · updated_at en contenido editable
-- Fecha: 2026-09-14
--
-- Corrige el hallazgo "Faltan updated_at en contenido editable":
--   - posts, comments, student_groups, marketplace_items, post_polls,
--     post_poll_options y entity_reports no tenían updated_at.
--   - profiles, notification_preferences y seccion_reviews ya tenían la
--     columna, pero sin trigger que la mantuviera (columnas muertas).
--
-- Se agrega la columna con default now() + trigger BEFORE UPDATE compartido
-- (_triggers.set_updated_at), y se backfillea con created_at en las filas
-- existentes.
--
-- Es idempotente.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) Función compartida de mantenimiento
-- -----------------------------------------------------------------------------
create or replace function _triggers.set_updated_at()
returns trigger
language plpgsql
set search_path to ''
as $$
begin
    new.updated_at := now();
    return new;
end $$;

comment on function _triggers.set_updated_at() is
  'Trigger BEFORE UPDATE: setea NEW.updated_at = now().';

-- -----------------------------------------------------------------------------
-- 2) Contenido editable: agregar columna + trigger
-- -----------------------------------------------------------------------------
do $$
declare
  t text;
  tablas text[] := array[
    'posts',
    'comments',
    'student_groups',
    'marketplace_items',
    'post_polls',
    'post_poll_options',
    'entity_reports'
  ];
begin
  foreach t in array tablas loop
    execute format('alter table public.%I add column if not exists updated_at timestamptz', t);
    -- Backfill: con created_at si existe (p.ej. post_poll_options no lo tiene).
    if exists (
      select 1 from pg_attribute
      where attrelid = format('public.%I', t)::regclass
        and attname = 'created_at' and attnum > 0 and not attisdropped
    ) then
      execute format('update public.%I set updated_at = created_at where updated_at is null', t);
    else
      execute format('update public.%I set updated_at = now() where updated_at is null', t);
    end if;
    execute format('alter table public.%I alter column updated_at set default now()', t);
    execute format('alter table public.%I alter column updated_at set not null', t);
    execute format('drop trigger if exists trg_set_updated_at on public.%I', t);
    execute format(
      'create trigger trg_set_updated_at before update on public.%I for each row execute function _triggers.set_updated_at()',
      t);
    execute format(
      'comment on column public.%I.updated_at is %L',
      t, 'Última modificación de la fila. Mantenido automáticamente por trg_set_updated_at.');
  end loop;
end $$;

-- -----------------------------------------------------------------------------
-- 3) Tablas que ya tenían updated_at pero sin trigger que lo mantenga
-- -----------------------------------------------------------------------------
do $$
declare
  t text;
  tablas text[] := array[
    'profiles',
    'notification_preferences',
    'seccion_reviews'
  ];
begin
  foreach t in array tablas loop
    execute format('update public.%I set updated_at = coalesce(created_at, now()) where updated_at is null', t);
    execute format('alter table public.%I alter column updated_at set default now()', t);
    execute format('alter table public.%I alter column updated_at set not null', t);
    execute format('drop trigger if exists trg_set_updated_at on public.%I', t);
    execute format(
      'create trigger trg_set_updated_at before update on public.%I for each row execute function _triggers.set_updated_at()',
      t);
  end loop;
end $$;

-- -----------------------------------------------------------------------------
-- 4) Resumen
-- -----------------------------------------------------------------------------
do $$
declare
  v_tablas text;
begin
  select string_agg(c.relname, ', ' order by c.relname) into v_tablas
  from pg_trigger t
  join pg_class c on c.oid = t.tgrelid
  where not t.tgisinternal
    and t.tgname = 'trg_set_updated_at'
    and c.relnamespace = 'public'::regnamespace;

  raise notice 'updated_at mantenido por trigger en: %', v_tablas;
end $$;
