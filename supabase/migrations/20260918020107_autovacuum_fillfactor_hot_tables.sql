-- =============================================================================
-- PEMTREE · Autovacuum agresivo y fillfactor en tablas calientes
-- Fecha: 2026-09-18
--
-- Tablas con updates/borrados frecuentes: umbrales de autovacuum más bajos
-- (20 tuplas / 5%) para que no se acumulen muertas en tablas pequeñas pero
-- activas. fillfactor 90 solo en las que reciben updates in-place
-- (contadores, moderación) para favorecer HOT updates; las de solo
-- alta/borrado no ganan con fillfactor.
--
-- Nota: cambiar fillfactor no reescribe la tabla; aplica a páginas nuevas.
--
-- Es idempotente.
-- =============================================================================

do $$
declare
  t text;
begin
  foreach t in array array[
    'posts','comments','student_groups','post_poll_options','user_notifications','marketplace_items',
    'post_likes','post_bookmarks','student_group_upvotes','marketplace_upvotes'
  ] loop
    execute format(
      'alter table public.%I set (autovacuum_vacuum_threshold = 20, autovacuum_vacuum_scale_factor = 0.05, autovacuum_analyze_threshold = 20, autovacuum_analyze_scale_factor = 0.02)',
      t
    );
  end loop;

  foreach t in array array[
    'posts','comments','student_groups','post_poll_options','user_notifications','marketplace_items'
  ] loop
    execute format('alter table public.%I set (fillfactor = 90)', t);
  end loop;
end $$;
