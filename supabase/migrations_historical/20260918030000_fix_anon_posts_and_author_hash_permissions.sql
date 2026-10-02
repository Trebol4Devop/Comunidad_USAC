-- =============================================================================
-- PEMTREE · Corrección de permisos para posts, comentarios y generate_author_hash
-- Fecha: 2026-09-18
--
-- Corrige:
-- 1. Error 42501: permission denied for function generate_author_hash
--    Se restaura EXECUTE a anon y authenticated en public.generate_author_hash.
--    Al ser invocada por las vistas v_public_posts y v_public_comments, los
--    roles que consultan el foro público requieren permisos de ejecución.
--
-- 2. Error 42501: permission denied for table posts / comments
--    Se otorga SELECT a anon y authenticated en public.posts y public.comments.
--    Se configuran políticas RLS de lectura permisiva (moderation_status != 2)
--    para acceso directo seguro sin violar privacidad de usuarios.
--
-- 3. Vistas públicas v_public_posts y v_public_comments
--    Se recrean sin forzar security_invoker (security_invoker = false) para
--    garantizar que anon pueda consumir las vistas desacopladas de las tablas
--    base, y se otorgan permisos explícitos de SELECT a anon y authenticated.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) Permisos de ejecución para generate_author_hash
-- -----------------------------------------------------------------------------
do $$
begin
  grant execute on function public.generate_author_hash(uuid, text) to anon, authenticated;
exception
  when others then
    null;
end $$;

do $$
begin
  grant execute on function public.generate_author_hash(uuid) to anon, authenticated;
exception
  when others then
    null;
end $$;

-- -----------------------------------------------------------------------------
-- 2) Permisos SELECT en posts y comments para anon y authenticated
-- -----------------------------------------------------------------------------
grant select on public.posts to anon, authenticated;
grant select on public.comments to anon, authenticated;

-- Políticas RLS para lectura pública de posts y comentarios no bloqueados
do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'posts' and policyname = 'Allow public read access to non-blocked posts'
  ) then
    create policy "Allow public read access to non-blocked posts"
      on public.posts for select
      to anon, authenticated
      using (moderation_status is distinct from 2);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'comments' and policyname = 'Allow public read access to non-blocked comments'
  ) then
    create policy "Allow public read access to non-blocked comments"
      on public.comments for select
      to anon, authenticated
      using (moderation_status is distinct from 2);
  end if;
end $$;

-- -----------------------------------------------------------------------------
-- 3) Recrear vistas públicas asegurando acceso a anon y authenticated
-- -----------------------------------------------------------------------------
create or replace view public.v_public_posts
with (security_invoker = false) as
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
with (security_invoker = false) as
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

grant select on public.v_public_posts to anon, authenticated;
grant select on public.v_public_comments to anon, authenticated;
