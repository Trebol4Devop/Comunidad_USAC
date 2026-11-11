-- =============================================================================
-- Permisos de ejecución de triggers y acceso a tablas posts y comments
-- =============================================================================
-- Corrige el error 42501 (insufficient_privilege):
-- 1. Otorga EXECUTE a authenticated sobre las funciones de los triggers de
--    public.posts y public.comments:
--      - public.handle_post_author_hash
--      - public.handle_comment_author_hash
--      - public.after_post_insert_author
--      - public.after_comment_insert_author
--      - public.trg_enqueue_posts
--      - public.trg_enqueue_comments
--      - public.check_content_moderation
--      - _triggers.notify_new_post
--      - _triggers.notify_comment_inserted
--      - _triggers.notify_post_liked
--
-- 2. Restaura permisos completos de SELECT, INSERT, UPDATE, DELETE a authenticated
--    sobre public.posts y public.comments para que las políticas RLS gobiernen
--    el acceso a filas y columnas sin bloqueos prematuros de permisos de tabla/columna.
-- =============================================================================

-- 1) Permisos sobre tablas posts y comments
grant select, insert, update, delete on table public.posts to authenticated;
grant select on table public.posts to anon;

grant select, insert, update, delete on table public.comments to authenticated;
grant select on table public.comments to anon;

-- 2) Permisos sobre vistas públicas
grant select on table public.v_public_posts to anon, authenticated;
grant select on table public.v_public_comments to anon, authenticated;

-- 3) Permisos de ejecución en funciones de triggers
grant execute on function public.handle_post_author_hash() to authenticated;
grant execute on function public.handle_comment_author_hash() to authenticated;
grant execute on function public.after_post_insert_author() to authenticated;
grant execute on function public.after_comment_insert_author() to authenticated;
grant execute on function public.trg_enqueue_posts() to authenticated;
grant execute on function public.trg_enqueue_comments() to authenticated;
grant execute on function public.check_content_moderation() to authenticated, anon;
grant execute on function _triggers.notify_new_post() to authenticated;
grant execute on function _triggers.notify_comment_inserted() to authenticated;
grant execute on function _triggers.notify_post_liked() to authenticated;

-- Permisos sobre generate_author_hash (tolerante a sobrecargas)
do $$
begin
  grant execute on function public.generate_author_hash(uuid, text) to authenticated, anon;
exception
  when undefined_function then null;
end $$;

do $$
begin
  grant execute on function public.generate_author_hash(uuid) to authenticated, anon;
exception
  when undefined_function then null;
end $$;
