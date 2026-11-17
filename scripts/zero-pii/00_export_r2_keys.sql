-- =============================================================================
-- Script: scripts/zero-pii/00_export_r2_keys.sql
-- Propósito: Exportar a formato CSV las claves de objetos R2 legacy
--            asociadas a solicitudes estudiantiles y de comerciantes
--            ANTES de ejecutar la migración y purga Zero-PII.
--
-- Uso con psql:
--   psql "$DATABASE_URL" -f scripts/zero-pii/00_export_r2_keys.sql > r2_legacy_keys.csv
--
-- O con \copy interactivo en psql:
--   \copy (SELECT DISTINCT r2_key, source_table, request_id FROM ...) TO 'r2_legacy_keys.csv' WITH CSV HEADER;
-- =============================================================================

COPY (
    SELECT DISTINCT
        sub.r2_key,
        sub.source_table,
        sub.request_id
    FROM (
        -- Claves de documentos de verificación estudiantil
        SELECT
            r2_object_key AS r2_key,
            'verification_requests'::text AS source_table,
            id::text AS request_id
        FROM public.verification_requests
        WHERE r2_object_key IS NOT NULL
          AND btrim(r2_object_key) <> ''

        UNION ALL

        -- Claves de DPI anverso de comerciantes
        SELECT
            dpi_front_key AS r2_key,
            'merchant_verification_requests'::text AS source_table,
            id::text AS request_id
        FROM public.merchant_verification_requests
        WHERE dpi_front_key IS NOT NULL
          AND btrim(dpi_front_key) <> ''

        UNION ALL

        -- Claves de DPI reverso de comerciantes
        SELECT
            dpi_back_key AS r2_key,
            'merchant_verification_requests'::text AS source_table,
            id::text AS request_id
        FROM public.merchant_verification_requests
        WHERE dpi_back_key IS NOT NULL
          AND btrim(dpi_back_key) <> ''

        UNION ALL

        -- Claves de fotos de establecimiento de comerciantes
        SELECT
            establishment_key AS r2_key,
            'merchant_verification_requests'::text AS source_table,
            id::text AS request_id
        FROM public.merchant_verification_requests
        WHERE establishment_key IS NOT NULL
          AND btrim(establishment_key) <> ''
    ) sub
    ORDER BY sub.source_table, sub.request_id, sub.r2_key
) TO STDOUT WITH (FORMAT csv, HEADER true);
