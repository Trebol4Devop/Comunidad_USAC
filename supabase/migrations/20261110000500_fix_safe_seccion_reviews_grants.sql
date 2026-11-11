-- =============================================================================
-- Fix de grants para la vista safe_seccion_reviews
-- =============================================================================
-- Al añadir deleted_at/is_legal_hold a seccion_reviews después de los grants
-- por columna de la migración 20261110000000, la vista security_invoker
-- fallaba para anon/authenticated al filtrar por deleted_at.
-- Se conceden explícitamente esas dos columnas (sin exponer user_id).
-- =============================================================================

GRANT SELECT (deleted_at, is_legal_hold)
    ON TABLE public.seccion_reviews
    TO anon, authenticated;
