-- =============================================================================
-- PEMTREE · BRIN en moderation_audit_log(created_at)
-- Fecha: 2026-09-18
--
-- Log append-only: las filas se insertan en orden cronológico, así que un
-- índice BRIN en created_at es mucho más pequeño que un B-tree y sirve para
-- filtros/retención por rango de fechas cuando la tabla crezca.
--
-- No se particiona ninguna tabla (decisión: el volumen actual no lo justifica).
--
-- Es idempotente.
-- =============================================================================

create index if not exists idx_moderation_audit_log_created_brin
  on public.moderation_audit_log using brin (created_at);
