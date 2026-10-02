-- =============================================================================
-- PEMTREE · Consolidación de reportes en public.entity_reports
-- Fecha: 2026-09-14
--
-- Corrige los hallazgos de la auditoría:
--   1. Unifica user_reports / student_group_reports / marketplace_reports en
--      entity_reports (entity_type: user | group | marketplace_item).
--   2. Agrega a entity_reports los campos específicos de esas tablas:
--      metadata jsonb, reported_user_id, entity_owner_id y las columnas de
--      moderación (moderation_label / moderation_confidence / moderation_reason).
--   3. Cierra los huecos de integridad referencial con FKs a auth.users:
--        - reported_user_id -> auth.users (cubre user_reports.reported_user_id)
--        - entity_owner_id  -> auth.users (cubre marketplace_reports.seller_user_id)
--      (reporter_id ya tenía FK y cubre student_group_reports.user_id)
--   4. Elimina la inconsistencia de PKs: las tablas redundantes dejan de ser
--      tablas y pasan a ser vistas respaldadas por entity_reports.
--   5. Mantiene compatibilidad TOTAL: las vistas tienen triggers
--      INSTEAD OF INSERT/UPDATE/DELETE, así que la app vieja y las funciones
--      admin (apply_moderation_batch, purge_inappropriate_content,
--      marcar_pendientes_error, limpieza_semestral_pemtree, v_moderation_queue,
--      whatsapp_group_reports) siguen funcionando sin cambios.
--   6. Conserva el contenido original en *_legacy_20260914.
--
-- Es idempotente: se puede correr más de una vez sin duplicar datos.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) Columnas nuevas en entity_reports
-- -----------------------------------------------------------------------------
alter table public.entity_reports
  add column if not exists metadata jsonb,
  add column if not exists reported_user_id uuid,
  add column if not exists entity_owner_id uuid,
  add column if not exists moderation_label text,
  add column if not exists moderation_confidence double precision,
  add column if not exists moderation_reason text;

update public.entity_reports set metadata = '{}'::jsonb where metadata is null;
alter table public.entity_reports alter column metadata set default '{}'::jsonb;
alter table public.entity_reports alter column metadata set not null;

comment on column public.entity_reports.metadata is
  'Campos específicos del tipo de entidad: reported_user_alias, seller_alias, legacy_status.';
comment on column public.entity_reports.reported_user_id is
  'Usuario reportado (solo entity_type = user). FK a auth.users.';
comment on column public.entity_reports.entity_owner_id is
  'Dueño del contenido reportado, p.ej. vendedor (solo marketplace_item). FK a auth.users.';

-- -----------------------------------------------------------------------------
-- 2) Helper para validar referencias a auth.users sin dar SELECT al rol
--    authenticated. Solo esta verificación corre como definer.
-- -----------------------------------------------------------------------------
create or replace function public.user_exists(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$ select exists (select 1 from auth.users u where u.id = p_user_id) $$;

revoke all on function public.user_exists(uuid) from public, anon;
grant execute on function public.user_exists(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 3) FKs nuevas a auth.users (idempotentes)
-- -----------------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.entity_reports'::regclass
      and conname = 'entity_reports_reported_user_id_fkey'
  ) then
    update public.entity_reports
       set reported_user_id = null
     where reported_user_id is not null
       and not public.user_exists(reported_user_id);

    alter table public.entity_reports
      add constraint entity_reports_reported_user_id_fkey
      foreign key (reported_user_id) references auth.users(id) on delete set null;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.entity_reports'::regclass
      and conname = 'entity_reports_entity_owner_id_fkey'
  ) then
    update public.entity_reports
       set entity_owner_id = null
     where entity_owner_id is not null
       and not public.user_exists(entity_owner_id);

    alter table public.entity_reports
      add constraint entity_reports_entity_owner_id_fkey
      foreign key (entity_owner_id) references auth.users(id) on delete set null;
  end if;
end $$;

-- -----------------------------------------------------------------------------
-- 4) Índices de apoyo (el único (reporter_id, entity_type, entity_id) ya existe)
-- -----------------------------------------------------------------------------
create index if not exists idx_entity_reports_reported_user_id
  on public.entity_reports (reported_user_id);
create index if not exists idx_entity_reports_entity_owner_id
  on public.entity_reports (entity_owner_id);
create index if not exists idx_entity_reports_type_entity
  on public.entity_reports (entity_type, entity_id);
create index if not exists idx_entity_reports_moderation
  on public.entity_reports (moderation_status, created_at desc);

-- -----------------------------------------------------------------------------
-- 5) Triggers en entity_reports
-- -----------------------------------------------------------------------------

-- 5a. Moderación de contenido para reportes de usuario/grupo.
--     Paridad exacta con las tablas legacy: los reportes de foro y marketplace
--     no pasaban por check_content_moderation, los de user/group sí.
drop trigger if exists trg_moderate_entity_reports on public.entity_reports;
create trigger trg_moderate_entity_reports
  before insert or update on public.entity_reports
  for each row
  when (new.entity_type in ('user', 'group'))
  execute function public.check_content_moderation();

-- 5b. Reset de moderación al editar (se extiende la función existente con el
--     caso entity_reports).
create or replace function public.reset_moderation_on_edit()
returns trigger
language plpgsql
set search_path to 'public'
as $$
begin
    if tg_table_name = 'posts' then
        if new.title is distinct from old.title
           or new.content is distinct from old.content
           or new.category is distinct from old.category
        then
            new.moderation_status := 0;
            new.moderation_label := null;
            new.moderation_confidence := null;
            new.moderation_reason := null;
            new.moderated_at := null;
            new.moderated_by := null;
        end if;
        return new;
    end if;

    if tg_table_name = 'comments' then
        if new.content is distinct from old.content then
            new.moderation_status := 0;
            new.moderation_label := null;
            new.moderation_confidence := null;
            new.moderation_reason := null;
            new.moderated_at := null;
            new.moderated_by := null;
        end if;
        return new;
    end if;

    if tg_table_name in ('student_groups', 'whatsapp_groups') then
        if new.title is distinct from old.title
           or new.carrera is distinct from old.carrera
           or new.curso is distinct from old.curso
           or new.section is distinct from old.section
           or new.link is distinct from old.link
           or new.description is distinct from old.description
        then
            new.moderation_status := 0;
            new.moderation_label := null;
            new.moderation_confidence := null;
            new.moderation_reason := null;
            new.moderated_at := null;
            new.moderated_by := null;
        end if;
        return new;
    end if;

    if tg_table_name = 'user_reports' then
        if new.reason is distinct from old.reason then
            new.moderation_status := 0;
            new.moderation_label := null;
            new.moderation_confidence := null;
            new.moderation_reason := null;
            new.moderated_at := null;
            new.moderated_by := null;
        end if;
        return new;
    end if;

    if tg_table_name in ('student_group_reports', 'whatsapp_group_reports') then
        if new.reason is distinct from old.reason then
            new.moderation_status := 0;
            new.moderation_label := null;
            new.moderation_confidence := null;
            new.moderation_reason := null;
            new.moderated_at := null;
            new.moderated_by := null;
        end if;
        return new;
    end if;

    if tg_table_name = 'entity_reports' then
        if new.reason is distinct from old.reason
           or new.details is distinct from old.details
           or new.metadata is distinct from old.metadata
        then
            new.moderation_status := 0;
            new.moderation_label := null;
            new.moderation_confidence := null;
            new.moderation_reason := null;
            new.moderated_at := null;
            new.moderated_by := null;
        end if;
        return new;
    end if;

    return new;
end $$;

drop trigger if exists trg_reset_moderation_entity_reports on public.entity_reports;
create trigger trg_reset_moderation_entity_reports
  before update on public.entity_reports
  for each row execute function public.reset_moderation_on_edit();

-- 5c. Sync de contadores reported_count (reemplaza a los triggers legacy
--     _triggers.sync_group_reported_counter / sync_marketplace_reported_counter,
--     que leían de las tablas que ahora son vistas).
create or replace function _triggers.sync_entity_report_counters()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
    if tg_op = 'INSERT' then
        if new.entity_type = 'group' then
            update public.student_groups g
               set reported_count = (select count(*) from public.entity_reports er
                                     where er.entity_type = 'group' and er.entity_id = new.entity_id)
             where g.id = new.entity_id;
        elsif new.entity_type = 'marketplace_item' then
            update public.marketplace_items m
               set reported_count = (select count(*) from public.entity_reports er
                                     where er.entity_type = 'marketplace_item' and er.entity_id = new.entity_id)
             where m.id = new.entity_id;
        end if;
    elsif tg_op = 'DELETE' then
        if old.entity_type = 'group' then
            update public.student_groups g
               set reported_count = (select count(*) from public.entity_reports er
                                     where er.entity_type = 'group' and er.entity_id = old.entity_id)
             where g.id = old.entity_id;
        elsif old.entity_type = 'marketplace_item' then
            update public.marketplace_items m
               set reported_count = (select count(*) from public.entity_reports er
                                     where er.entity_type = 'marketplace_item' and er.entity_id = old.entity_id)
             where m.id = old.entity_id;
        end if;
    else
        if new.entity_type is distinct from old.entity_type
           or new.entity_id is distinct from old.entity_id then
            if old.entity_type = 'group' then
                update public.student_groups g
                   set reported_count = (select count(*) from public.entity_reports er
                                         where er.entity_type = 'group' and er.entity_id = old.entity_id)
                 where g.id = old.entity_id;
            elsif old.entity_type = 'marketplace_item' then
                update public.marketplace_items m
                   set reported_count = (select count(*) from public.entity_reports er
                                         where er.entity_type = 'marketplace_item' and er.entity_id = old.entity_id)
                 where m.id = old.entity_id;
            end if;
            if new.entity_type = 'group' then
                update public.student_groups g
                   set reported_count = (select count(*) from public.entity_reports er
                                         where er.entity_type = 'group' and er.entity_id = new.entity_id)
                 where g.id = new.entity_id;
            elsif new.entity_type = 'marketplace_item' then
                update public.marketplace_items m
                   set reported_count = (select count(*) from public.entity_reports er
                                         where er.entity_type = 'marketplace_item' and er.entity_id = new.entity_id)
                 where m.id = new.entity_id;
            end if;
        end if;
    end if;
    return null;
end $$;

drop trigger if exists trg_sync_entity_report_counters on public.entity_reports;
create trigger trg_sync_entity_report_counters
  after insert or delete or update on public.entity_reports
  for each row execute function _triggers.sync_entity_report_counters();

-- -----------------------------------------------------------------------------
-- 6) Migración de datos (solo si las tablas viejas siguen siendo tablas reales;
--    hoy están vacías, pero se conserva la lógica por si hay datos)
-- -----------------------------------------------------------------------------
do $$
declare
  v_users_migrated  bigint := 0;
  v_groups_migrated bigint := 0;
  v_market_migrated bigint := 0;
  v_skipped         bigint;
begin
  -- 6.1 user_reports -> entity_reports
  if to_regclass('public.user_reports') is not null
     and (select relkind from pg_class where oid = to_regclass('public.user_reports')) = 'r'
  then
    insert into public.entity_reports
      (id, reporter_id, entity_type, entity_id, reported_user_id, reason, created_at,
       moderation_status, moderation_label, moderation_confidence, moderation_reason,
       moderated_at, moderated_by, metadata)
    select ur.id,
           ur.reporter_id,
           'user',
           ur.reported_user_id,
           case when public.user_exists(ur.reported_user_id) then ur.reported_user_id else null end,
           ur.reason,
           coalesce(ur.created_at, now()),
           coalesce(ur.moderation_status, 0),
           ur.moderation_label,
           ur.moderation_confidence,
           ur.moderation_reason,
           ur.moderated_at,
           ur.moderated_by,
           jsonb_strip_nulls(jsonb_build_object('reported_user_alias', ur.reported_user_alias))
    from public.user_reports ur
    where not exists (select 1 from public.entity_reports er where er.id = ur.id)
    on conflict do nothing;

    get diagnostics v_users_migrated = row_count;
  end if;

  -- 6.2 student_group_reports -> entity_reports
  if to_regclass('public.student_group_reports') is not null
     and (select relkind from pg_class where oid = to_regclass('public.student_group_reports')) = 'r'
  then
    select count(*) into v_skipped
    from public.student_group_reports sgr
    where not public.user_exists(sgr.user_id);
    if v_skipped > 0 then
      raise notice 'student_group_reports: % filas con usuario inexistente no se migran (quedan en el respaldo legacy).', v_skipped;
    end if;

    insert into public.entity_reports
      (reporter_id, entity_type, entity_id, reason, created_at,
       moderation_status, moderation_label, moderation_confidence, moderation_reason,
       moderated_at, moderated_by, metadata)
    select sgr.user_id,
           'group',
           sgr.group_id,
           coalesce(sgr.reason, ''),
           coalesce(sgr.created_at, now()),
           coalesce(sgr.moderation_status, 0),
           sgr.moderation_label,
           sgr.moderation_confidence,
           sgr.moderation_reason,
           sgr.moderated_at,
           sgr.moderated_by,
           '{}'::jsonb
    from public.student_group_reports sgr
    where public.user_exists(sgr.user_id)
      and not exists (
        select 1 from public.entity_reports er
        where er.entity_type = 'group'
          and er.entity_id = sgr.group_id
          and er.reporter_id = sgr.user_id
      )
    on conflict do nothing;

    get diagnostics v_groups_migrated = row_count;
  end if;

  -- 6.3 marketplace_reports -> entity_reports
  if to_regclass('public.marketplace_reports') is not null
     and (select relkind from pg_class where oid = to_regclass('public.marketplace_reports')) = 'r'
  then
    select count(*) into v_skipped
    from public.marketplace_reports mr
    where mr.user_id is null or not public.user_exists(mr.user_id);
    if v_skipped > 0 then
      raise notice 'marketplace_reports: % filas sin reporter válido no se migran (quedan en el respaldo legacy).', v_skipped;
    end if;

    insert into public.entity_reports
      (id, reporter_id, entity_type, entity_id, entity_owner_id, reason, created_at,
       moderation_status, metadata)
    select mr.id,
           mr.user_id,
           'marketplace_item',
           mr.item_id,
           case when mr.seller_user_id is not null and public.user_exists(mr.seller_user_id)
                then mr.seller_user_id else null end,
           mr.reason,
           coalesce(mr.created_at, now()),
           case lower(coalesce(mr.status, 'pending'))
             when 'reviewed'  then 1
             when 'resolved'  then 1
             when 'in_review' then 1
             when 'dismissed' then 2
             when 'rejected'  then 2
             else 0
           end,
           jsonb_strip_nulls(jsonb_build_object(
             'seller_alias', mr.seller_alias,
             'legacy_status', mr.status))
    from public.marketplace_reports mr
    where mr.user_id is not null
      and public.user_exists(mr.user_id)
      and not exists (select 1 from public.entity_reports er where er.id = mr.id)
    on conflict do nothing;

    get diagnostics v_market_migrated = row_count;
  end if;

  raise notice 'Migrados: % de user_reports, % de student_group_reports, % de marketplace_reports.',
    v_users_migrated, v_groups_migrated, v_market_migrated;
end $$;

-- -----------------------------------------------------------------------------
-- 7) Compatibilidad: tablas viejas -> respaldo legacy + vistas
-- -----------------------------------------------------------------------------
do $$
begin
  if (select relkind from pg_class where oid = to_regclass('public.user_reports')) = 'r' then
    alter table public.user_reports rename to user_reports_legacy_20260914;
  end if;
  if (select relkind from pg_class where oid = to_regclass('public.student_group_reports')) = 'r' then
    alter table public.student_group_reports rename to student_group_reports_legacy_20260914;
  end if;
  if (select relkind from pg_class where oid = to_regclass('public.marketplace_reports')) = 'r' then
    alter table public.marketplace_reports rename to marketplace_reports_legacy_20260914;
  end if;
end $$;

-- Vistas de compatibilidad: una sola fuente de verdad (entity_reports)
create or replace view public.user_reports
with (security_invoker = true) as
select er.id,
       er.reporter_id,
       er.reported_user_id,
       er.metadata->>'reported_user_alias' as reported_user_alias,
       er.reason,
       er.created_at,
       er.moderation_status,
       er.moderation_label,
       er.moderation_confidence,
       er.moderation_reason,
       er.moderated_at,
       er.moderated_by
from public.entity_reports er
where er.entity_type = 'user';

create or replace view public.student_group_reports
with (security_invoker = true) as
select er.entity_id as group_id,
       er.reporter_id as user_id,
       er.reason,
       er.created_at,
       er.moderation_status,
       er.moderation_label,
       er.moderation_confidence,
       er.moderation_reason,
       er.moderated_at,
       er.moderated_by
from public.entity_reports er
where er.entity_type = 'group';

create or replace view public.marketplace_reports
with (security_invoker = true) as
select er.id,
       er.entity_id as item_id,
       er.reporter_id as user_id,
       er.reason,
       er.created_at,
       er.entity_owner_id as seller_user_id,
       er.metadata->>'seller_alias' as seller_alias,
       coalesce(er.metadata->>'legacy_status', 'pending') as status
from public.entity_reports er
where er.entity_type = 'marketplace_item';

-- Triggers INSTEAD OF INSERT/UPDATE/DELETE: los clientes viejos y las funciones
-- admin siguen operando sobre los nombres viejos.
create or replace function public.legacy_user_reports_iud()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
begin
    if tg_op = 'INSERT' then
        insert into public.entity_reports
          (id, reporter_id, entity_type, entity_id, reported_user_id, reason, created_at,
           moderation_status, moderation_label, moderation_confidence, moderation_reason,
           moderated_at, moderated_by, metadata)
        values
          (coalesce(new.id, gen_random_uuid()),
           new.reporter_id,
           'user',
           new.reported_user_id,
           case when public.user_exists(new.reported_user_id) then new.reported_user_id else null end,
           new.reason,
           coalesce(new.created_at, now()),
           coalesce(new.moderation_status, 0),
           new.moderation_label,
           new.moderation_confidence,
           new.moderation_reason,
           new.moderated_at,
           new.moderated_by,
           jsonb_strip_nulls(jsonb_build_object('reported_user_alias', new.reported_user_alias)));
        return new;

    elsif tg_op = 'UPDATE' then
        update public.entity_reports set
          reporter_id = new.reporter_id,
          entity_id = new.reported_user_id,
          reported_user_id = case when public.user_exists(new.reported_user_id) then new.reported_user_id else null end,
          reason = new.reason,
          created_at = coalesce(new.created_at, created_at),
          moderation_status = new.moderation_status,
          moderation_label = new.moderation_label,
          moderation_confidence = new.moderation_confidence,
          moderation_reason = new.moderation_reason,
          moderated_at = new.moderated_at,
          moderated_by = new.moderated_by,
          metadata = coalesce(metadata, '{}'::jsonb)
                     || jsonb_strip_nulls(jsonb_build_object('reported_user_alias', new.reported_user_alias))
        where id = old.id and entity_type = 'user';
        return new;

    else
        delete from public.entity_reports where id = old.id and entity_type = 'user';
        return old;
    end if;
end $$;

drop trigger if exists user_reports_iud on public.user_reports;
create trigger user_reports_iud
  instead of insert or update or delete on public.user_reports
  for each row execute function public.legacy_user_reports_iud();

create or replace function public.legacy_student_group_reports_iud()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
begin
    if tg_op = 'INSERT' then
        insert into public.entity_reports
          (reporter_id, entity_type, entity_id, reason, created_at,
           moderation_status, moderation_label, moderation_confidence, moderation_reason,
           moderated_at, moderated_by, metadata)
        values
          (new.user_id,
           'group',
           new.group_id,
           coalesce(new.reason, ''),
           coalesce(new.created_at, now()),
           coalesce(new.moderation_status, 0),
           new.moderation_label,
           new.moderation_confidence,
           new.moderation_reason,
           new.moderated_at,
           new.moderated_by,
           '{}'::jsonb);
        return new;

    elsif tg_op = 'UPDATE' then
        update public.entity_reports set
          reporter_id = new.user_id,
          entity_id = new.group_id,
          reason = new.reason,
          created_at = coalesce(new.created_at, created_at),
          moderation_status = new.moderation_status,
          moderation_label = new.moderation_label,
          moderation_confidence = new.moderation_confidence,
          moderation_reason = new.moderation_reason,
          moderated_at = new.moderated_at,
          moderated_by = new.moderated_by
        where entity_type = 'group'
          and entity_id = old.group_id
          and reporter_id = old.user_id;
        return new;

    else
        delete from public.entity_reports
         where entity_type = 'group'
           and entity_id = old.group_id
           and reporter_id = old.user_id;
        return old;
    end if;
end $$;

drop trigger if exists student_group_reports_iud on public.student_group_reports;
create trigger student_group_reports_iud
  instead of insert or update or delete on public.student_group_reports
  for each row execute function public.legacy_student_group_reports_iud();

create or replace function public.legacy_marketplace_reports_iud()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
begin
    if tg_op = 'INSERT' then
        insert into public.entity_reports
          (id, reporter_id, entity_type, entity_id, entity_owner_id, reason, created_at,
           moderation_status, metadata)
        values
          (coalesce(new.id, gen_random_uuid()),
           new.user_id,
           'marketplace_item',
           new.item_id,
           case when new.seller_user_id is not null and public.user_exists(new.seller_user_id)
                then new.seller_user_id else null end,
           new.reason,
           coalesce(new.created_at, now()),
           case lower(coalesce(new.status, 'pending'))
             when 'reviewed'  then 1
             when 'resolved'  then 1
             when 'in_review' then 1
             when 'dismissed' then 2
             when 'rejected'  then 2
             else 0
           end,
           jsonb_strip_nulls(jsonb_build_object(
             'seller_alias', new.seller_alias,
             'legacy_status', new.status)));
        return new;

    elsif tg_op = 'UPDATE' then
        update public.entity_reports set
          reporter_id = new.user_id,
          entity_id = new.item_id,
          entity_owner_id = case when new.seller_user_id is not null and public.user_exists(new.seller_user_id)
                                 then new.seller_user_id else null end,
          reason = new.reason,
          created_at = coalesce(new.created_at, created_at),
          moderation_status = case lower(coalesce(new.status, 'pending'))
             when 'reviewed'  then 1
             when 'resolved'  then 1
             when 'in_review' then 1
             when 'dismissed' then 2
             when 'rejected'  then 2
             else 0
           end,
          metadata = coalesce(metadata, '{}'::jsonb)
                     || jsonb_strip_nulls(jsonb_build_object(
                          'seller_alias', new.seller_alias,
                          'legacy_status', new.status))
        where id = old.id and entity_type = 'marketplace_item';
        return new;

    else
        delete from public.entity_reports where id = old.id and entity_type = 'marketplace_item';
        return old;
    end if;
end $$;

drop trigger if exists marketplace_reports_iud on public.marketplace_reports;
create trigger marketplace_reports_iud
  instead of insert or update or delete on public.marketplace_reports
  for each row execute function public.legacy_marketplace_reports_iud();

-- La vista whatsapp_group_reports quedó apuntando a la tabla renombrada por el
-- ALTER TABLE RENAME; se recrea para que lea de la nueva vista.
create or replace view public.whatsapp_group_reports as
select group_id,
       user_id,
       reason,
       created_at,
       moderation_status,
       moderation_label,
       moderation_confidence,
       moderation_reason,
       moderated_at,
       moderated_by
from public.student_group_reports;

-- -----------------------------------------------------------------------------
-- 8) report_marketplace_item: ahora escribe en entity_reports y deja que el
--    trigger de contadores mantenga reported_count (antes duplicaba el conteo).
-- -----------------------------------------------------------------------------
create or replace function public.report_marketplace_item(
    target_item_id uuid,
    report_reason text,
    target_seller_id uuid default null,
    target_seller_alias text default null
)
returns boolean
language plpgsql
security definer
set search_path to 'public'
as $$
declare
    v_count int;
begin
    insert into public.entity_reports (
        reporter_id,
        entity_type,
        entity_id,
        entity_owner_id,
        reason,
        metadata
    ) values (
        auth.uid(),
        'marketplace_item',
        target_item_id,
        case when target_seller_id is not null and public.user_exists(target_seller_id)
             then target_seller_id else null end,
        report_reason,
        jsonb_strip_nulls(jsonb_build_object('seller_alias', target_seller_alias))
    )
    on conflict (reporter_id, entity_type, entity_id) do nothing;

    -- El trigger AFTER INSERT ya recalculó reported_count.
    select reported_count into v_count
    from public.marketplace_items
    where id = target_item_id;

    if v_count >= 3 then
        update public.marketplace_items
           set moderation_status = 2
         where id = target_item_id;
    end if;

    return true;
exception
    when others then
        return false;
end $$;

-- -----------------------------------------------------------------------------
-- 9) RLS: política DELETE (paridad con las tablas legacy: dueño o moderador)
--    La política INSERT ya existe ("Authenticated users can create entity reports").
-- -----------------------------------------------------------------------------
drop policy if exists "Users and moderators can delete entity reports" on public.entity_reports;
create policy "Users and moderators can delete entity reports"
  on public.entity_reports
  for delete
  to authenticated
  using (
    reporter_id = auth.uid()
    or public.is_pemtree_admin(auth.uid())
    or public.is_pemtree_moderator(auth.uid())
  );

-- -----------------------------------------------------------------------------
-- 10) Permisos (RLS sigue aplicando a nivel de fila)
-- -----------------------------------------------------------------------------
grant select, insert, update, delete on public.entity_reports to authenticated;
grant select, insert, update, delete on public.user_reports to authenticated;
grant select, insert, update, delete on public.student_group_reports to authenticated;
grant select, insert, update, delete on public.marketplace_reports to authenticated;

-- -----------------------------------------------------------------------------
-- 11) Resumen final
-- -----------------------------------------------------------------------------
do $$
declare
  v_total  bigint;
  v_users  bigint;
  v_groups bigint;
  v_market bigint;
begin
  select count(*) into v_total  from public.entity_reports;
  select count(*) into v_users  from public.entity_reports where entity_type = 'user';
  select count(*) into v_groups from public.entity_reports where entity_type = 'group';
  select count(*) into v_market from public.entity_reports where entity_type = 'marketplace_item';

  raise notice 'entity_reports -> total=%, user=%, group=%, marketplace_item=%',
    v_total, v_users, v_groups, v_market;
end $$;

-- -----------------------------------------------------------------------------
-- Limpieza posterior (ejecutar SOLO después de verificar que todo quedó bien):
-- drop table if exists public.user_reports_legacy_20260914;
-- drop table if exists public.student_group_reports_legacy_20260914;
-- drop table if exists public.marketplace_reports_legacy_20260914;
-- -----------------------------------------------------------------------------
