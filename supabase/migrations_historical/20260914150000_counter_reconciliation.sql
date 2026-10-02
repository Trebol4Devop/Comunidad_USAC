-- =============================================================================
-- PEMTREE · Contadores denormalizados con respaldo claro
-- Fecha: 2026-09-14
--
-- Contexto del hallazgo: posts.likes, posts.reposts_count,
-- student_groups.upvotes/reported_count, marketplace_items.upvotes/reported_count
-- y post_poll_options.votes_count se mantienen por triggers que recalculan con
-- COUNT(*) (patrón autorreparable). Hoy no hay desincronización.
--
-- Para darles "respaldo claro" se agrega:
--   1. Documentación de la fuente de verdad de cada contador (COMMENT).
--   2. public.recalcular_contadores(): recalcula los 7 contadores desde las
--      tablas fuente y reporta cuántas filas corrigió.
--   3. public.verificar_contadores(): reporta desincronizaciones sin reparar.
--   4. Job diario en pg_cron que ejecuta la reconciliación.
--
-- Se conservan los contadores porque la app los lee directamente; pasarlos a
-- COUNT()/vistas materializadas exigiría cambiar el cliente.
--
-- Es idempotente.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) Documentar fuente de verdad
-- -----------------------------------------------------------------------------
comment on column public.posts.likes is
  'Denormalizado: count(public.post_likes). Mantenido por trg_sync_post_likes. Reconciliar con public.recalcular_contadores().';
comment on column public.posts.reposts_count is
  'Denormalizado: count(public.posts donde quoted_post_id = id). Mantenido por trg_sync_reposts_counter. Reconciliar con public.recalcular_contadores().';
comment on column public.student_groups.upvotes is
  'Denormalizado: count(public.student_group_upvotes). Mantenido por trg_sync_group_upvotes. Reconciliar con public.recalcular_contadores().';
comment on column public.student_groups.reported_count is
  'Denormalizado: count(entity_reports con entity_type=group). Mantenido por trg_sync_entity_report_counters. Reconciliar con public.recalcular_contadores().';
comment on column public.marketplace_items.upvotes is
  'Denormalizado: count(public.marketplace_upvotes). Mantenido por trg_sync_marketplace_upvotes. Reconciliar con public.recalcular_contadores().';
comment on column public.marketplace_items.reported_count is
  'Denormalizado: count(entity_reports con entity_type=marketplace_item). Mantenido por trg_sync_entity_report_counters. Reconciliar con public.recalcular_contadores().';
comment on column public.post_poll_options.votes_count is
  'Denormalizado: count(public.post_poll_votes). Mantenido por trg_sync_poll_votes_counter. Reconciliar con public.recalcular_contadores().';

-- -----------------------------------------------------------------------------
-- 2) Reconciliación: recalcula todos los contadores desde la fuente
-- -----------------------------------------------------------------------------
create or replace function public.recalcular_contadores()
returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_uid uuid := auth.uid();
  v_role text := coalesce(current_setting('request.jwt.claim.role', true), '');
  v_reparados jsonb := '{}'::jsonb;
  v_n integer;
begin
  -- Admins por JWT; service_role; o conexión directa/cron (sin claims).
  if v_uid is not null and not public.is_pemtree_admin(v_uid) then
    raise exception 'Permiso denegado: solo administradores pueden recalcular contadores.';
  end if;
  if v_uid is null and v_role not in ('', 'service_role') then
    raise exception 'Permiso denegado: se requiere sesión de administrador.';
  end if;

  -- posts.likes
  update public.posts p
     set likes = (select count(*) from public.post_likes l where l.post_id = p.id)
   where p.likes is distinct from (select count(*) from public.post_likes l where l.post_id = p.id);
  get diagnostics v_n = row_count;
  v_reparados := v_reparados || jsonb_build_object('posts.likes', v_n);

  -- posts.reposts_count
  update public.posts p
     set reposts_count = (select count(*) from public.posts r where r.quoted_post_id = p.id)
   where p.reposts_count is distinct from (select count(*) from public.posts r where r.quoted_post_id = p.id);
  get diagnostics v_n = row_count;
  v_reparados := v_reparados || jsonb_build_object('posts.reposts_count', v_n);

  -- student_groups.upvotes
  update public.student_groups g
     set upvotes = (select count(*) from public.student_group_upvotes u where u.group_id = g.id)
   where g.upvotes is distinct from (select count(*) from public.student_group_upvotes u where u.group_id = g.id);
  get diagnostics v_n = row_count;
  v_reparados := v_reparados || jsonb_build_object('student_groups.upvotes', v_n);

  -- student_groups.reported_count
  update public.student_groups g
     set reported_count = (
       select count(*) from public.entity_reports er
       where er.entity_type = 'group' and er.entity_id = g.id)
   where g.reported_count is distinct from (
       select count(*) from public.entity_reports er
       where er.entity_type = 'group' and er.entity_id = g.id);
  get diagnostics v_n = row_count;
  v_reparados := v_reparados || jsonb_build_object('student_groups.reported_count', v_n);

  -- marketplace_items.upvotes
  update public.marketplace_items m
     set upvotes = (select count(*) from public.marketplace_upvotes u where u.item_id = m.id)
   where m.upvotes is distinct from (select count(*) from public.marketplace_upvotes u where u.item_id = m.id);
  get diagnostics v_n = row_count;
  v_reparados := v_reparados || jsonb_build_object('marketplace_items.upvotes', v_n);

  -- marketplace_items.reported_count
  update public.marketplace_items m
     set reported_count = (
       select count(*) from public.entity_reports er
       where er.entity_type = 'marketplace_item' and er.entity_id = m.id)
   where m.reported_count is distinct from (
       select count(*) from public.entity_reports er
       where er.entity_type = 'marketplace_item' and er.entity_id = m.id);
  get diagnostics v_n = row_count;
  v_reparados := v_reparados || jsonb_build_object('marketplace_items.reported_count', v_n);

  -- post_poll_options.votes_count
  update public.post_poll_options o
     set votes_count = (select count(*) from public.post_poll_votes v where v.option_id = o.id)
   where o.votes_count is distinct from (select count(*) from public.post_poll_votes v where v.option_id = o.id);
  get diagnostics v_n = row_count;
  v_reparados := v_reparados || jsonb_build_object('post_poll_options.votes_count', v_n);

  return v_reparados;
end $$;

comment on function public.recalcular_contadores() is
  'Recalcula los contadores denormalizados desde sus tablas fuente y devuelve cuántas filas corrigió por contador.';

-- -----------------------------------------------------------------------------
-- 3) Verificación: reporta desincronizaciones sin reparar
-- -----------------------------------------------------------------------------
create or replace function public.verificar_contadores()
returns table(contador text, desincronizados bigint)
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_uid uuid := auth.uid();
  v_role text := coalesce(current_setting('request.jwt.claim.role', true), '');
begin
  if v_uid is not null and not public.is_pemtree_admin(v_uid) then
    raise exception 'Permiso denegado: solo administradores pueden verificar contadores.';
  end if;
  if v_uid is null and v_role not in ('', 'service_role') then
    raise exception 'Permiso denegado: se requiere sesión de administrador.';
  end if;

  return query
    select 'posts.likes'::text, count(*)::bigint
    from public.posts p
    left join (select post_id, count(*) c from public.post_likes group by 1) x on x.post_id = p.id
    where p.likes is distinct from coalesce(x.c, 0)
    union all
    select 'posts.reposts_count', count(*)::bigint
    from public.posts p
    left join (select quoted_post_id, count(*) c from public.posts where quoted_post_id is not null group by 1) x
      on x.quoted_post_id = p.id
    where p.reposts_count is distinct from coalesce(x.c, 0)
    union all
    select 'student_groups.upvotes', count(*)::bigint
    from public.student_groups g
    left join (select group_id, count(*) c from public.student_group_upvotes group by 1) x on x.group_id = g.id
    where g.upvotes is distinct from coalesce(x.c, 0)
    union all
    select 'student_groups.reported_count', count(*)::bigint
    from public.student_groups g
    left join (select entity_id, count(*) c from public.entity_reports where entity_type='group' group by 1) x
      on x.entity_id = g.id
    where g.reported_count is distinct from coalesce(x.c, 0)
    union all
    select 'marketplace_items.upvotes', count(*)::bigint
    from public.marketplace_items m
    left join (select item_id, count(*) c from public.marketplace_upvotes group by 1) x on x.item_id = m.id
    where m.upvotes is distinct from coalesce(x.c, 0)
    union all
    select 'marketplace_items.reported_count', count(*)::bigint
    from public.marketplace_items m
    left join (select entity_id, count(*) c from public.entity_reports where entity_type='marketplace_item' group by 1) x
      on x.entity_id = m.id
    where m.reported_count is distinct from coalesce(x.c, 0)
    union all
    select 'post_poll_options.votes_count', count(*)::bigint
    from public.post_poll_options o
    left join (select option_id, count(*) c from public.post_poll_votes group by 1) x on x.option_id = o.id
    where o.votes_count is distinct from coalesce(x.c, 0);
end $$;

comment on function public.verificar_contadores() is
  'Devuelve, por contador denormalizado, cuántas filas están desincronizadas respecto de su tabla fuente.';

-- -----------------------------------------------------------------------------
-- 4) Permisos: solo authenticated (con check de admin dentro) y service_role
-- -----------------------------------------------------------------------------
revoke all on function public.recalcular_contadores() from public, anon;
revoke all on function public.verificar_contadores() from public, anon;
grant execute on function public.recalcular_contadores() to authenticated, service_role;
grant execute on function public.verificar_contadores() to authenticated, service_role;

-- -----------------------------------------------------------------------------
-- 5) Job diario de reconciliación (pg_cron)
-- -----------------------------------------------------------------------------
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule(
      'pemtree-reconciliar-contadores',
      '17 3 * * *',
      'select public.recalcular_contadores();'
    );
    raise notice 'Job pg_cron pemtree-reconciliar-contadores programado (03:17 UTC diario).';
  else
    raise notice 'pg_cron no está instalado: programa manualmente select public.recalcular_contadores().';
  end if;
end $$;

-- -----------------------------------------------------------------------------
-- 6) Resumen: estado actual de los contadores
-- -----------------------------------------------------------------------------
do $$
declare
  v_desync bigint := 0;
  r record;
begin
  for r in select * from public.verificar_contadores() loop
    v_desync := v_desync + r.desincronizados;
  end loop;
  raise notice 'Contadores verificados. Desincronizaciones actuales: %', v_desync;
end $$;
