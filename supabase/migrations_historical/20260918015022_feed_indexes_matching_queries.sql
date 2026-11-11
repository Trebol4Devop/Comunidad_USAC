-- =============================================================================
-- PEMTREE · Índices de feed alineados a las consultas reales
-- Fecha: 2026-09-18
--
-- Los feeds de posts leen v_public_posts, cuyo predicado es
-- "moderation_status IS DISTINCT FROM 2". Un índice parcial con
-- "moderation_status < 2" no puede usarse para esa consulta (el planner no
-- puede probar la implicación), y además el feed ordena
-- is_pinned DESC, created_at DESC. Por eso:
--   - se crea idx_posts_category_created (categoría + orden real),
--   - se recrean idx_posts_carrera_created y idx_posts_global_created con el
--     predicado y el orden que sí usa el feed.
--
-- Comentarios, marketplace por categoría y marketplace por status también se
-- alinean a las consultas de la app.
--
-- Es idempotente.
-- =============================================================================

-- 1) Posts: feed por categoría (nuevo)
create index if not exists idx_posts_category_created
  on public.posts (category, is_pinned desc, created_at desc)
  where moderation_status is distinct from 2;

-- 2) Posts: feed por carrera (reemplaza el índice que no se usaba)
drop index if exists public.idx_posts_carrera_created;
create index idx_posts_carrera_created
  on public.posts (carrera, is_pinned desc, created_at desc)
  where moderation_status is distinct from 2;

-- 3) Posts: feed global (sin filtros)
drop index if exists public.idx_posts_global_created;
create index idx_posts_global_created
  on public.posts (is_pinned desc, created_at desc)
  where moderation_status is distinct from 2;

-- 4) Comentarios de un post en orden cronológico (v_public_comments)
create index if not exists idx_comments_post_created
  on public.comments (post_id, created_at);

-- 5) Marketplace: feed por categoría (la app filtra moderation_status < 2,
--    no status = 'available'; además ordena is_sponsored DESC, created_at DESC)
create index if not exists idx_marketplace_category_feed
  on public.marketplace_items (category, is_sponsored desc, created_at desc)
  where moderation_status < 2;

-- 6) Marketplace: status + fecha. La RLS visible usa
--    status IN ('available','reserved'), así que un parcial sobre
--    'available' no aplica; se reemplaza el índice de una sola columna.
create index if not exists idx_marketplace_status_created
  on public.marketplace_items (status, created_at desc);
drop index if exists public.idx_marketplace_items_status;
