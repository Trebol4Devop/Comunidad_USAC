-- =============================================================================
-- PEMTREE · Corrección de hallazgos del Database Linter (Security + Performance)
-- Fecha: 2026-09-14
--
-- Resuelve:
--   [ERROR] 0010 security_definer_view
--     public.whatsapp_group_reports pasa a security_invoker para que respete
--     RLS de entity_reports (antes exponía todos los reportes de grupo).
--   [WARN]  0014 extension_in_public
--     pg_net se reinstala en el schema extensions. La extensión es no
--     relocalizable (extrelocatable = false), por eso no sirve ALTER SET SCHEMA.
--   [WARN]  0028 anon puede ejecutar funciones SECURITY DEFINER
--     Se revoca EXECUTE de PUBLIC y anon en las 5 funciones expuestas por RPC.
--   [WARN]  0029 authenticated puede ejecutar funciones SECURITY DEFINER
--     Se revoca EXECUTE de las funciones de mantenimiento (recalcular y
--     verificar contadores). Las demás son intencionales: helpers de RLS y RPC
--     de usuario con guardas internas (auth.uid() / is_pemtree_admin).
--   [WARN]  0003 auth_rls_initplan
--     Policy DELETE de entity_reports reescrita con subselects.
--   [WARN]  0006 multiple_permissive_policies
--     Las dos policies SELECT de profiles se fusionan en una sola.
--   [INFO]  0001 unindexed_foreign_keys
--     Índices de cobertura para las 10 FKs señaladas.
--
-- Es idempotente: se puede correr más de una vez sin efectos adicionales.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) [ERROR 0010] whatsapp_group_reports -> security_invoker
--    Era la última vista del schema public sin security_invoker.
-- -----------------------------------------------------------------------------
create or replace view public.whatsapp_group_reports
with (security_invoker = true) as
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
-- 2) [WARN 0014] pg_net fuera de public
--    pg_net no soporta SET SCHEMA; se reinstala en extensions. El bloque es
--    atómico: si el create falla, la excepción revierte el drop y la extensión
--    queda como estaba.
-- -----------------------------------------------------------------------------
do $$
begin
  if exists (
    select 1
    from pg_extension
    where extname = 'pg_net'
      and extnamespace = 'public'::regnamespace
  ) then
    execute 'drop extension pg_net';
    execute 'create extension pg_net with schema extensions';
  end if;
exception
  when others then
    raise warning 'No se pudo mover pg_net a extensions: % (%)', sqlerrm, sqlstate;
end $$;

-- -----------------------------------------------------------------------------
-- 3) [WARN 0028] Funciones SECURITY DEFINER invocables por anon
-- -----------------------------------------------------------------------------
revoke execute on function public.generate_author_hash(uuid, text) from public, anon;
revoke execute on function public.moderate_marketplace_item(uuid, integer, text, double precision, text) from public, anon;
revoke execute on function public.report_forum_comment(uuid, text, text) from public, anon;
revoke execute on function public.report_forum_post(uuid, text, text) from public, anon;
revoke execute on function public.report_marketplace_item(uuid, text, uuid, text) from public, anon;

-- v_public_posts / v_public_comments son security_invoker y llaman a
-- generate_author_hash(auth.uid()). El CASE garantiza que anon (sin EXECUTE)
-- nunca evalúe la función, manteniendo el mismo resultado (false).
create or replace view public.v_public_posts
with (security_invoker = true) as
select p.id,
       p.title,
       p.category,
       p.content,
       p.author_alias,
       p.author_hash,
       p.likes,
       p.reposts_count,
       p.carrera,
       p.image_url,
       p.gif_url,
       p.is_pinned,
       p.quoted_post_id,
       p.created_at,
       p.moderation_status,
       (select count(*)::integer
          from public.comments c
         where c.post_id = p.id
           and c.moderation_status is distinct from 2) as comment_count,
       case
         when auth.uid() is not null
         then p.author_hash = public.generate_author_hash(auth.uid())
         else false
       end as is_my_post
from public.posts p
where p.moderation_status is distinct from 2;

create or replace view public.v_public_comments
with (security_invoker = true) as
select c.id,
       c.post_id,
       c.parent_id,
       c.content,
       c.author_alias,
       c.author_hash,
       c.gif_url,
       c.created_at,
       c.moderation_status,
       ((c.author_hash is not null) and (c.author_hash = p.author_hash)) as is_post_author,
       case
         when auth.uid() is not null
         then c.author_hash = public.generate_author_hash(auth.uid())
         else false
       end as is_my_comment
from public.comments c
left join public.posts p on p.id = c.post_id
where c.moderation_status is distinct from 2;

-- -----------------------------------------------------------------------------
-- 4) [WARN 0029] Funciones de mantenimiento fuera del alcance de authenticated
--    El cron las ejecuta como postgres, así que no las necesita el API.
-- -----------------------------------------------------------------------------
revoke execute on function public.recalcular_contadores() from authenticated;
revoke execute on function public.verificar_contadores() from authenticated;

-- -----------------------------------------------------------------------------
-- 5) [WARN 0003] auth_rls_initplan en entity_reports (DELETE)
-- -----------------------------------------------------------------------------
drop policy if exists "Users and moderators can delete entity reports" on public.entity_reports;
create policy "Users and moderators can delete entity reports"
  on public.entity_reports
  for delete
  to authenticated
  using (
    reporter_id = (select auth.uid())
    or (select public.is_pemtree_admin((select auth.uid())))
    or (select public.is_pemtree_moderator((select auth.uid())))
  );

-- -----------------------------------------------------------------------------
-- 6) [WARN 0006] profiles: una sola policy SELECT permisiva
-- -----------------------------------------------------------------------------
drop policy if exists "Admins can view all profiles" on public.profiles;
drop policy if exists "Users can read own profile" on public.profiles;
create policy "Users can read own profile"
  on public.profiles
  for select
  to authenticated
  using (
    (select auth.uid()) = id
    or (select public.is_pemtree_admin((select auth.uid())))
  );

-- -----------------------------------------------------------------------------
-- 7) [INFO 0001] Índices de cobertura para FKs sin índice
-- -----------------------------------------------------------------------------
create index if not exists idx_carreras_facultad_id
  on public.carreras (facultad_id);
create index if not exists idx_comment_authors_user_id
  on public.comment_authors (user_id);
create index if not exists idx_entity_reports_moderated_by
  on public.entity_reports (moderated_by);
create index if not exists idx_marketplace_items_category
  on public.marketplace_items (category);
create index if not exists idx_marketplace_items_moderated_by
  on public.marketplace_items (moderated_by);
create index if not exists idx_post_authors_user_id
  on public.post_authors (user_id);
create index if not exists idx_post_poll_votes_poll_option
  on public.post_poll_votes (poll_id, option_id);
create index if not exists idx_post_poll_votes_user_id
  on public.post_poll_votes (user_id);
create index if not exists idx_posts_category
  on public.posts (category);
create index if not exists idx_profiles_carrera
  on public.profiles (carrera);
