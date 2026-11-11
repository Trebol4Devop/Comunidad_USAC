-- =============================================================================
-- PEMTREE · created_at consistente y a prueba de manipulación
-- Fecha: 2026-09-14
--
-- Corrige el manejo de created_at:
--   - post_poll_options no tenía created_at.
--   - 13 tablas activas lo tenían NULLABLE (posts, comments, student_groups,
--     profiles, entity_reports, likes/upvotes, audit log, etc.).
--   - Un cliente con INSERT directo (PostgREST + RLS) podía enviar un
--     created_at arbitrario y "backdatear" contenido, afectando el orden.
--
-- Se estandariza a timestamptz NOT NULL DEFAULT now() en todas las tablas
-- activas, se backfillean los nulls y se agrega un trigger BEFORE INSERT
-- (_triggers.set_created_at) que fuerza new.created_at = now(), de modo que
-- el timestamp es siempre del servidor.
--
-- Nota: si en el futuro se necesita importar datos históricos, hay que
-- desactivar puntualmente trg_set_created_at en esa carga.
--
-- Es idempotente.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) post_poll_options: agregar la columna faltante
-- -----------------------------------------------------------------------------
alter table public.post_poll_options add column if not exists created_at timestamptz;
update public.post_poll_options set created_at = now() where created_at is null;
alter table public.post_poll_options alter column created_at set default now();
alter table public.post_poll_options alter column created_at set not null;

-- -----------------------------------------------------------------------------
-- 2) Estandarizar created_at en tablas activas
--    (se excluyen los respaldos *_legacy_20260914, que son snapshots congelados)
-- -----------------------------------------------------------------------------
do $$
declare
  t text;
  tablas text[] := array[
    'comment_authors',
    'comments',
    'entity_reports',
    'marketplace_items',
    'marketplace_upvotes',
    'moderation_audit_log',
    'notification_preferences',
    'notification_subscriptions',
    'post_authors',
    'post_bookmarks',
    'post_likes',
    'post_poll_options',
    'post_poll_votes',
    'post_polls',
    'posts',
    'profiles',
    'seccion_reviews',
    'sponsor_requests',
    'student_group_upvotes',
    'student_groups',
    'user_notifications',
    'user_roles'
  ];
begin
  foreach t in array tablas loop
    execute format('alter table public.%I add column if not exists created_at timestamptz', t);
    execute format('update public.%I set created_at = now() where created_at is null', t);
    execute format('alter table public.%I alter column created_at set default now()', t);
    execute format('alter table public.%I alter column created_at set not null', t);
  end loop;
end $$;

-- -----------------------------------------------------------------------------
-- 3) Trigger: created_at siempre del servidor
-- -----------------------------------------------------------------------------
create or replace function _triggers.set_created_at()
returns trigger
language plpgsql
set search_path to ''
as $$
begin
    new.created_at := now();
    return new;
end $$;

comment on function _triggers.set_created_at() is
  'Trigger BEFORE INSERT: fuerza NEW.created_at = now() (evita backdating por parte de clientes).';

do $$
declare
  t text;
  tablas text[] := array[
    'comment_authors',
    'comments',
    'entity_reports',
    'marketplace_items',
    'marketplace_upvotes',
    'moderation_audit_log',
    'notification_preferences',
    'notification_subscriptions',
    'post_authors',
    'post_bookmarks',
    'post_likes',
    'post_poll_options',
    'post_poll_votes',
    'post_polls',
    'posts',
    'profiles',
    'seccion_reviews',
    'sponsor_requests',
    'student_group_upvotes',
    'student_groups',
    'user_notifications',
    'user_roles'
  ];
begin
  foreach t in array tablas loop
    execute format('drop trigger if exists trg_set_created_at on public.%I', t);
    execute format(
      'create trigger trg_set_created_at before insert on public.%I for each row execute function _triggers.set_created_at()',
      t);
    execute format(
      'comment on column public.%I.created_at is %L',
      t, 'Momento de creación de la fila. Forzado a now() en INSERT por trg_set_created_at.');
  end loop;
end $$;

-- -----------------------------------------------------------------------------
-- 4) Resumen
-- -----------------------------------------------------------------------------
do $$
declare
  v_sin_created text;
  v_nullable text;
  v_con_trigger bigint;
begin
  select string_agg(c.relname, ', ' order by c.relname) into v_sin_created
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind = 'r'
    and c.relname not like '%\_legacy\_%'
    and not exists (
      select 1 from pg_attribute a
      where a.attrelid = c.oid and a.attname = 'created_at'
        and a.attnum > 0 and not a.attisdropped
    );

  select string_agg(c.relname, ', ' order by c.relname) into v_nullable
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  join pg_attribute a on a.attrelid = c.oid and a.attname = 'created_at'
    and a.attnum > 0 and not a.attisdropped
  where n.nspname = 'public' and c.relkind = 'r'
    and c.relname not like '%\_legacy\_%'
    and not a.attnotnull;

  select count(*) into v_con_trigger
  from pg_trigger t
  join pg_class c on c.oid = t.tgrelid
  where not t.tgisinternal and t.tgname = 'trg_set_created_at'
    and c.relnamespace = 'public'::regnamespace;

  raise notice 'created_at → tablas sin columna: % | nullable: % | tablas con trg_set_created_at: %',
    coalesce(v_sin_created, 'ninguna'),
    coalesce(v_nullable, 'ninguna'),
    v_con_trigger;
end $$;
