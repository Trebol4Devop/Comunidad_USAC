-- =============================================================================
-- PEMTREE · Índices faltantes en FK y auditoría
-- Fecha: 2026-09-18
--
-- El resto de índices propuestos ya existían (posts, comments, upvotes,
-- entity_reports, etc. — creados en optimize_performance_indexes_and_rls y
-- fix_advisors). Los huecos reales eran:
--   1. marketplace_items.facultad (FK creada en consistency_facultades_...).
--   2. notification_preference_carreras.carrera_id (la PK cubre user_id).
--   3. moderation_audit_log(entity_table, entity_id).
--
-- Es idempotente.
-- =============================================================================

-- 1) FK recién creada: marketplace_items.facultad
create index if not exists idx_marketplace_items_facultad
  on public.marketplace_items (facultad);

-- 2) FK sin índice: notification_preference_carreras.carrera_id
--    (la PK cubre user_id como prefijo, no carrera_id)
create index if not exists idx_notification_preference_carreras_carrera
  on public.notification_preference_carreras (carrera_id);

-- 3) Auditoría de moderación por entidad
create index if not exists idx_moderation_audit_log_entity
  on public.moderation_audit_log (entity_table, entity_id);
