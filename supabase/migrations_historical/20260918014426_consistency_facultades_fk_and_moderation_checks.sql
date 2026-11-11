-- =============================================================================
-- PEMTREE · Consistencia de facultades y checks de moderación
-- Fecha: 2026-09-18
--
-- Corrige hallazgos de revisión:
--   1. facultades: marketplace_items.facultad era text sin FK. La app sí usa
--      la columna (filtro y creación de listings), así que se enlaza al catálogo.
--   2. moderation_status: posts, comments, student_groups y marketplace_items
--      no tenían CHECK; se alinean con entity_reports (escala 0..3).
--   3. post_authors / comment_authors: se documentan como mapas privados de
--      autoría (el autor público se expone por author_hash en las vistas).
--
-- Es idempotente.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) facultades: FK desde marketplace_items.facultad
-- -----------------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.marketplace_items'::regclass
      and conname = 'marketplace_items_facultad_catalogo_fkey'
  ) then
    alter table public.marketplace_items
      add constraint marketplace_items_facultad_catalogo_fkey
      foreign key (facultad) references public.facultades(id) on update cascade;
  end if;
end $$;

-- -----------------------------------------------------------------------------
-- 2) CHECK moderation_status 0..3 en las tablas de contenido
--    (consistencia con entity_reports_moderation_status_check)
-- -----------------------------------------------------------------------------
do $$
declare
  t text;
begin
  foreach t in array array['posts','comments','student_groups','marketplace_items']
  loop
    if not exists (
      select 1 from pg_constraint
      where conrelid = ('public.' || t)::regclass
        and conname = t || '_moderation_status_check'
    ) then
      execute format(
        'alter table public.%I add constraint %I check (moderation_status between 0 and 3)',
        t, t || '_moderation_status_check'
      );
    end if;
  end loop;
end $$;

-- -----------------------------------------------------------------------------
-- 3) Documentar las tablas de autoría privada
-- -----------------------------------------------------------------------------
comment on table public.post_authors is
  'Mapa privado post -> autor real (user_id). Se puebla por trigger en el INSERT del post; RLS solo permite al autor leer su propia fila. La autoría pública se expone anonimizada vía posts.author_hash (v_public_posts), no por esta tabla.';
comment on table public.comment_authors is
  'Mapa privado comentario -> autor real (user_id). Se puebla por trigger en el INSERT del comentario; RLS solo permite al autor leer su propia fila. La autoría pública se expone anonimizada vía comments.author_hash (v_public_comments), no por esta tabla.';
