-- =============================================================================
-- PEMTREE · Búsqueda de texto con pg_trgm por columna
-- Fecha: 2026-09-18
--
-- La app busca con ILIKE '%q%' por columna en OR:
--   posts: title OR content
--   student_groups: title OR curso OR description
--   marketplace_items: title OR description OR building_code
-- Un GIN trgm sobre la concatenación no puede usarse para esas consultas
-- (los índices viejos tenían 0 scans). Se reemplazan por índices por columna,
-- que el planner combina con BitmapOr.
--
-- tsvector no aplica mientras la búsqueda sea por subcadena (ILIKE); si se
-- quiere ranking/stemming habrá que migrar las consultas a textSearch.
--
-- Es idempotente.
-- =============================================================================

-- posts
create index if not exists idx_posts_title_trgm
  on public.posts using gin (title gin_trgm_ops);
create index if not exists idx_posts_content_trgm
  on public.posts using gin (content gin_trgm_ops);
drop index if exists public.idx_posts_search_gin;

-- student_groups
create index if not exists idx_student_groups_title_trgm
  on public.student_groups using gin (title gin_trgm_ops);
create index if not exists idx_student_groups_curso_trgm
  on public.student_groups using gin (curso gin_trgm_ops);
create index if not exists idx_student_groups_description_trgm
  on public.student_groups using gin (description gin_trgm_ops);
drop index if exists public.idx_student_groups_search_gin;

-- marketplace_items
create index if not exists idx_marketplace_title_trgm
  on public.marketplace_items using gin (title gin_trgm_ops);
create index if not exists idx_marketplace_description_trgm
  on public.marketplace_items using gin (description gin_trgm_ops);
create index if not exists idx_marketplace_building_code_trgm
  on public.marketplace_items using gin (building_code gin_trgm_ops);
