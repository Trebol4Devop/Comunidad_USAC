-- =============================================================================
-- Migración: 20261117120000_zero_pii_hardening.sql
-- Módulo: Endurecimiento de Seguridad Zero-PII (Comunidad USAC)
-- Rol: Ingeniero Senior de PostgreSQL y Supabase
-- =============================================================================

-- =============================================================================
-- BLOQUE 0: PURGA DE DATOS LEGACY DE VERIFICACIÓN (DATOS DE PRUEBA)
-- =============================================================================
-- En orden de integridad referencial. Solo se ejecuta en la primera aplicación:
-- si las columnas legacy ya no existen, la migración se re-ejecuta sin borrar datos nuevos.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'verification_requests'
          AND column_name = 'extracted_ocr_text'
    ) OR EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'merchant_verification_requests'
          AND column_name = 'dpi_hash'
    ) THEN
        DELETE FROM public.moderation_jobs
        WHERE entity_table = 'verification_requests' OR entity_table = 'merchant_verification_requests';

        DELETE FROM public.verification_requests;
        DELETE FROM public.merchant_verification_requests;
    END IF;
END $$;

-- =============================================================================
-- BLOQUE 1: REFACTORIZACIÓN ZERO-PII EN public.profiles
-- =============================================================================

-- 1.1 Eliminar triggers y funciones legacy que manipulaban cui y carne en texto plano
DROP TRIGGER IF EXISTS trg_handle_profile_sensitive_data ON public.profiles;
DROP FUNCTION IF EXISTS public.handle_profile_sensitive_data();

-- 1.2 Eliminar constraints e índices obsoletos
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_carne_key;
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_cui_key;
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_cui_hash_key;
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_carne_hash_key;
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_cui_carne_null_check;
DROP INDEX IF EXISTS public.profiles_cui_hash_key;
DROP INDEX IF EXISTS public.profiles_carne_hash_key;
DROP INDEX IF EXISTS public.profiles_carne_key;
DROP INDEX IF EXISTS public.profiles_cui_key;

-- 1.3 Resolver posibles duplicados de carne_hash:
--     Conserva el valor únicamente en el perfil más antiguo (created_at, id) y asigna NULL al resto.
WITH ranked_profiles AS (
    SELECT id,
           ROW_NUMBER() OVER (
               PARTITION BY carne_hash
               ORDER BY created_at ASC, id ASC
           ) AS rn
    FROM public.profiles
    WHERE carne_hash IS NOT NULL
)
UPDATE public.profiles p
SET carne_hash = NULL
FROM ranked_profiles r
WHERE p.id = r.id AND r.rn > 1;

-- 1.4 Crear el constraint de unicidad definitiva profiles_carne_hash_unique de forma idempotente
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'public.profiles'::regclass
          AND conname = 'profiles_carne_hash_unique'
    ) THEN
        ALTER TABLE public.profiles
            ADD CONSTRAINT profiles_carne_hash_unique UNIQUE (carne_hash);
    END IF;
END $$;

-- 1.5 Eliminar columnas PII en profiles
ALTER TABLE public.profiles DROP COLUMN IF EXISTS cui;
ALTER TABLE public.profiles DROP COLUMN IF EXISTS carne;
ALTER TABLE public.profiles DROP COLUMN IF EXISTS full_name;
ALTER TABLE public.profiles DROP COLUMN IF EXISTS cui_hash;

-- 1.6 Actualizar función de alta de nuevo usuario para NO almacenar full_name
CREATE OR REPLACE FUNCTION public.handle_new_user_profile()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    INSERT INTO public.profiles (id)
    VALUES (NEW.id)
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.handle_new_user_profile() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.handle_new_user_profile() TO postgres, service_role;

-- 1.7 Restablecer permisos de UPDATE en profiles para authenticated sin full_name
REVOKE UPDATE ON TABLE public.profiles FROM anon, authenticated;
GRANT UPDATE (carrera, accepted_terms_version, accepted_terms_at) ON TABLE public.profiles TO authenticated;

-- 1.8 Actualizar admin_list_marketplace_sellers para no leer p.full_name ni p.carne
--     Preserva el contrato de columnas de retorno devolviendo NULL::text
CREATE OR REPLACE FUNCTION public.admin_list_marketplace_sellers(
    p_search       text    DEFAULT NULL,
    p_plan         text    DEFAULT NULL,
    p_verification text    DEFAULT NULL,
    p_limit        integer DEFAULT 100,
    p_offset       integer DEFAULT 0
)
RETURNS TABLE (
    user_id                uuid,
    public_id              uuid,
    full_name              text,
    carne                  text,
    is_verified            boolean,
    plan_id                text,
    plan_name              text,
    plan_monthly           numeric,
    seller_type            text,
    verification_status    text,
    business_name          text,
    business_description   text,
    plan_expires_at        timestamptz,
    is_currently_on_campus boolean,
    current_building_code  text,
    active_items           bigint,
    total_items            bigint,
    views_30d              bigint,
    contact_clicks_30d     bigint,
    created_at             timestamptz,
    updated_at             timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_limit  integer;
    v_offset integer;
    v_search text;
BEGIN
    IF NOT public.is_marketplace_staff(auth.uid()) THEN
        RAISE EXCEPTION 'Solo el personal de PEMTREE (administrador o moderador) puede listar vendedores del Marketplace'
            USING ERRCODE = '42501';
    END IF;

    v_limit  := LEAST(GREATEST(COALESCE(p_limit, 100), 1), 500);
    v_offset := GREATEST(COALESCE(p_offset, 0), 0);
    v_search := NULLIF(btrim(COALESCE(p_search, '')), '');

    RETURN QUERY
    SELECT
        sp.user_id,
        sp.public_id,
        NULL::text                            AS full_name,
        NULL::text                            AS carne,
        public.is_verified_seller(sp.user_id) AS is_verified,
        COALESCE(ep.id, 'free')               AS plan_id,
        COALESCE(ep.name, 'Estudiante')       AS plan_name,
        COALESCE(ep.price_monthly, 0)         AS plan_monthly,
        sp.seller_type,
        sp.verification_status,
        sp.business_name,
        sp.business_description,
        sp.plan_expires_at,
        sp.is_currently_on_campus,
        sp.current_building_code,
        COALESCE(it.active_items, 0)::bigint  AS active_items,
        COALESCE(it.total_items, 0)::bigint   AS total_items,
        COALESCE(ev.views_30d, 0)::bigint     AS views_30d,
        COALESCE(ev.contact_clicks_30d, 0)::bigint AS contact_clicks_30d,
        sp.created_at,
        sp.updated_at
    FROM public.seller_profiles sp
    LEFT JOIN public.profiles p ON p.id = sp.user_id
    LEFT JOIN LATERAL public.get_effective_seller_plan(sp.user_id) ep ON true
    LEFT JOIN LATERAL (
        SELECT count(*) FILTER (WHERE mi.status IN ('available', 'reserved')) AS active_items,
               count(*)                                                       AS total_items
        FROM public.marketplace_items mi
        WHERE mi.user_id = sp.user_id
          AND mi.deleted_at IS NULL
    ) it ON true
    LEFT JOIN LATERAL (
        SELECT count(*) FILTER (WHERE e.event_type = 'view')        AS views_30d,
               count(*) FILTER (WHERE e.event_type LIKE 'click\_%') AS contact_clicks_30d
        FROM public.marketplace_item_events e
        JOIN public.marketplace_items mi ON mi.id = e.item_id
        WHERE mi.user_id = sp.user_id
          AND e.created_at >= now() - interval '30 days'
    ) ev ON true
    WHERE (
            v_search IS NULL
            OR COALESCE(sp.business_name, '') ILIKE '%' || v_search || '%'
          )
      AND (p_plan IS NULL OR COALESCE(ep.id, 'free') = p_plan)
      AND (p_verification IS NULL OR sp.verification_status = p_verification)
    ORDER BY sp.created_at DESC, sp.user_id
    LIMIT v_limit
    OFFSET v_offset;
END;
$$;

-- =============================================================================
-- BLOQUE 2: public.verification_requests
-- =============================================================================

-- 2.1 Eliminar cui_hash y extracted_ocr_text
ALTER TABLE public.verification_requests DROP COLUMN IF EXISTS cui_hash;
ALTER TABLE public.verification_requests DROP COLUMN IF EXISTS extracted_ocr_text;

-- 2.2 Agregar banderas booleanas de coincidencia OCR
ALTER TABLE public.verification_requests
    ADD COLUMN IF NOT EXISTS matched_keywords boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS matched_carne boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS matched_current_year boolean NOT NULL DEFAULT false;

-- =============================================================================
-- BLOQUE 3: public.merchant_verification_requests
-- =============================================================================

-- 3.1 Eliminar índices obsoletos que dependían de columnas DPI
DROP INDEX IF EXISTS public.idx_merchant_verification_requests_dpi_hash;
DROP INDEX IF EXISTS public.idx_merchant_verification_requests_keys;

-- 3.2 Eliminar columnas DPI
ALTER TABLE public.merchant_verification_requests DROP COLUMN IF EXISTS dpi_hash;
ALTER TABLE public.merchant_verification_requests DROP COLUMN IF EXISTS dpi_front_key;
ALTER TABLE public.merchant_verification_requests DROP COLUMN IF EXISTS dpi_back_key;

-- 3.3 Agregar contact_phone_hash NOT NULL (la tabla fue purgada previamente)
ALTER TABLE public.merchant_verification_requests
    ADD COLUMN IF NOT EXISTS contact_phone_hash text;

ALTER TABLE public.merchant_verification_requests
    ALTER COLUMN contact_phone_hash SET NOT NULL;

-- 3.4 Agregar campus_zone (nullable)
ALTER TABLE public.merchant_verification_requests
    ADD COLUMN IF NOT EXISTS campus_zone text;

-- 3.5 Crear índice único parcial sobre contact_phone_hash para estados activos
CREATE UNIQUE INDEX IF NOT EXISTS idx_merchant_unique_active_phone_hash
    ON public.merchant_verification_requests (contact_phone_hash)
    WHERE status IN ('pending', 'approved');

-- 3.6 Crear índice parcial para purga de claves de establecimiento en R2
CREATE INDEX IF NOT EXISTS idx_merchant_verification_requests_establishment_key
    ON public.merchant_verification_requests (id)
    WHERE establishment_key IS NOT NULL;

-- =============================================================================
-- BLOQUE 4: RPC public.claim_student_credentials(p_carne text)
-- =============================================================================

-- Drop de versión previa de 2 argumentos
DROP FUNCTION IF EXISTS public.claim_student_credentials(text, text);

CREATE OR REPLACE FUNCTION public.claim_student_credentials(
    p_carne text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id uuid;
    v_carne_clean text;
    v_carne_year integer;
    v_carne_hash text;
    v_status text;
    v_is_verified boolean;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('ok', false, 'code', 'not_authenticated');
    END IF;

    IF p_carne IS NULL THEN
        RETURN jsonb_build_object('ok', false, 'code', 'invalid_carne_format');
    END IF;

    v_carne_clean := btrim(p_carne);
    IF v_carne_clean !~ '^\d{9}$' THEN
        RETURN jsonb_build_object('ok', false, 'code', 'invalid_carne_format');
    END IF;

    v_carne_year := substring(v_carne_clean from 1 for 4)::integer;
    IF v_carne_year < 1980 OR v_carne_year > EXTRACT(YEAR FROM now())::integer THEN
        RETURN jsonb_build_object('ok', false, 'code', 'invalid_carne_year');
    END IF;

    v_carne_hash := private.hash_credential(v_carne_clean);

    -- Verificar que el hash no pertenezca a otro perfil ni a otra solicitud activa
    IF EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id <> v_user_id
          AND carne_hash = v_carne_hash
    ) OR EXISTS (
        SELECT 1 FROM public.verification_requests
        WHERE user_id <> v_user_id
          AND status IN ('approved', 'manual_review', 'pending')
          AND carne_hash = v_carne_hash
    ) THEN
        RETURN jsonb_build_object('ok', false, 'code', 'credential_unavailable');
    END IF;

    INSERT INTO public.profiles (id)
    VALUES (v_user_id)
    ON CONFLICT (id) DO NOTHING;

    -- Actualiza solo carne_hash y updated_at, preservando el estado de verificación
    UPDATE public.profiles
    SET carne_hash = v_carne_hash,
        updated_at = now()
    WHERE id = v_user_id
    RETURNING verification_status, is_verified INTO v_status, v_is_verified;

    RETURN jsonb_build_object(
        'ok', true,
        'verification_status', v_status,
        'is_verified', v_is_verified
    );
END;
$$;

REVOKE ALL ON FUNCTION public.claim_student_credentials(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.claim_student_credentials(text) TO authenticated, service_role;

-- =============================================================================
-- BLOQUE 5: RPC public.admin_create_verification_request
-- =============================================================================

DROP FUNCTION IF EXISTS public.admin_create_verification_request(uuid, text, text, text, text, text, text, double precision, boolean);

CREATE OR REPLACE FUNCTION public.admin_create_verification_request(
    p_user_id uuid,
    p_carne text,
    p_document_type text,
    p_r2_object_key text DEFAULT NULL,
    p_qr_url text DEFAULT NULL,
    p_matched_keywords boolean DEFAULT false,
    p_matched_carne boolean DEFAULT false,
    p_matched_current_year boolean DEFAULT false,
    p_auto_approved boolean DEFAULT false
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_carne_clean text;
    v_carne_year integer;
    v_carne_hash text;
    v_recent_count integer;
    v_request_id uuid;
BEGIN
    IF auth.role() IS DISTINCT FROM 'service_role' AND current_user NOT IN ('postgres', 'supabase_admin') THEN
        RETURN jsonb_build_object('ok', false, 'code', 'not_authorized');
    END IF;

    IF p_user_id IS NULL THEN
        RETURN jsonb_build_object('ok', false, 'code', 'not_authorized');
    END IF;

    IF p_carne IS NULL THEN
        RETURN jsonb_build_object('ok', false, 'code', 'invalid_carne');
    END IF;

    v_carne_clean := btrim(p_carne);
    IF v_carne_clean !~ '^\d{9}$' THEN
        RETURN jsonb_build_object('ok', false, 'code', 'invalid_carne');
    END IF;

    v_carne_year := substring(v_carne_clean from 1 for 4)::integer;
    IF v_carne_year < 1980 OR v_carne_year > EXTRACT(YEAR FROM now())::integer THEN
        RETURN jsonb_build_object('ok', false, 'code', 'invalid_carne');
    END IF;

    IF p_document_type IS NULL OR p_document_type NOT IN ('constancia_inscripcion', 'carne_fisico', 'boleta_asignacion') THEN
        RETURN jsonb_build_object('ok', false, 'code', 'invalid_document_type');
    END IF;

    -- Rate limit: máximo 3 solicitudes en las últimas 24 horas
    SELECT count(*) INTO v_recent_count
    FROM public.verification_requests
    WHERE user_id = p_user_id
      AND created_at > now() - interval '24 hours';

    IF v_recent_count >= 3 THEN
        RETURN jsonb_build_object('ok', false, 'code', 'rate_limited');
    END IF;

    v_carne_hash := private.hash_credential(v_carne_clean);

    IF EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id <> p_user_id
          AND carne_hash = v_carne_hash
    ) OR EXISTS (
        SELECT 1 FROM public.verification_requests
        WHERE user_id <> p_user_id
          AND status IN ('approved', 'manual_review', 'pending')
          AND carne_hash = v_carne_hash
    ) THEN
        RETURN jsonb_build_object('ok', false, 'code', 'credential_unavailable');
    END IF;

    INSERT INTO public.verification_requests (
        user_id,
        carne_hash,
        document_type,
        r2_object_key,
        qr_url,
        matched_keywords,
        matched_carne,
        matched_current_year,
        ocr_source,
        status,
        reviewed_at,
        expires_at
    ) VALUES (
        p_user_id,
        v_carne_hash,
        p_document_type,
        CASE WHEN p_auto_approved THEN NULL ELSE p_r2_object_key END,
        p_qr_url,
        COALESCE(p_matched_keywords, false),
        COALESCE(p_matched_carne, false),
        COALESCE(p_matched_current_year, false),
        'client',
        CASE WHEN p_auto_approved THEN 'approved' ELSE 'manual_review' END,
        CASE WHEN p_auto_approved THEN now() ELSE NULL END,
        now() + interval '24 hours'
    ) RETURNING id INTO v_request_id;

    INSERT INTO public.profiles (id)
    VALUES (p_user_id)
    ON CONFLICT (id) DO NOTHING;

    IF p_auto_approved THEN
        UPDATE public.profiles
        SET is_verified = true,
            verified_at = now(),
            verification_status = 'verified',
            verification_method = 'ocr_document',
            carne_hash = v_carne_hash,
            updated_at = now()
        WHERE id = p_user_id;
    ELSE
        UPDATE public.profiles
        SET verification_status = CASE
                WHEN verification_status = 'verified' THEN verification_status
                ELSE 'pending_review'
            END,
            updated_at = now()
        WHERE id = p_user_id;

        INSERT INTO public.moderation_jobs (
            entity_table,
            entity_id,
            content_hash,
            has_image,
            priority,
            status
        ) VALUES (
            'verification_requests',
            v_request_id,
            'verification_request:' || v_request_id::text,
            (p_r2_object_key IS NOT NULL),
            50,
            'pending'
        );
    END IF;

    RETURN jsonb_build_object(
        'ok', true,
        'status', CASE WHEN p_auto_approved THEN 'verified' ELSE 'manual_review' END,
        'request_id', v_request_id
    );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_create_verification_request(uuid, text, text, text, text, boolean, boolean, boolean, boolean) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_create_verification_request(uuid, text, text, text, text, boolean, boolean, boolean, boolean) TO service_role, postgres;

-- =============================================================================
-- BLOQUE 6: RPC public.admin_create_merchant_verification_request
-- =============================================================================

DROP FUNCTION IF EXISTS public.admin_create_merchant_verification_request(uuid, uuid, text, text, text, text, text, text);

CREATE OR REPLACE FUNCTION public.admin_create_merchant_verification_request(
    p_request_id uuid,
    p_user_id uuid,
    p_business_name text,
    p_contact_phone text,
    p_establishment_key text,
    p_establishment_note text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_business_name text;
    v_contact_phone text;
    v_phone_hash text;
    v_establishment_note text;
    v_key_prefix text;
    v_recent_count integer;
BEGIN
    IF auth.role() IS DISTINCT FROM 'service_role' AND current_user NOT IN ('postgres', 'supabase_admin') THEN
        RETURN jsonb_build_object('ok', false, 'code', 'not_authorized');
    END IF;

    IF p_request_id IS NULL OR p_user_id IS NULL THEN
        RETURN jsonb_build_object('ok', false, 'code', 'not_authorized');
    END IF;

    IF p_business_name IS NULL THEN
        RETURN jsonb_build_object('ok', false, 'code', 'invalid_business_name');
    END IF;

    v_business_name := btrim(p_business_name);
    IF char_length(v_business_name) < 2 OR char_length(v_business_name) > 80 THEN
        RETURN jsonb_build_object('ok', false, 'code', 'invalid_business_name');
    END IF;

    IF p_contact_phone IS NULL THEN
        RETURN jsonb_build_object('ok', false, 'code', 'invalid_phone');
    END IF;

    -- Normalizar teléfono guatemalteco de 8 dígitos: remover espacios, guiones y prefijo +502 / 502
    v_contact_phone := regexp_replace(btrim(p_contact_phone), '[\s\-]+', '', 'g');
    IF starts_with(v_contact_phone, '+502') THEN
        v_contact_phone := substring(v_contact_phone from 5);
    ELSIF starts_with(v_contact_phone, '502') AND char_length(v_contact_phone) = 11 THEN
        v_contact_phone := substring(v_contact_phone from 4);
    END IF;

    IF v_contact_phone !~ '^[2-7][0-9]{7}$' THEN
        RETURN jsonb_build_object('ok', false, 'code', 'invalid_phone');
    END IF;

    -- Validar clave R2 de establecimiento con prefijo obligatorio
    v_key_prefix := 'pending/merchant/' || p_user_id::text || '/' || p_request_id::text || '/';

    IF p_establishment_key IS NULL
       OR NOT starts_with(p_establishment_key, v_key_prefix)
       OR char_length(p_establishment_key) <= char_length(v_key_prefix) THEN
        RETURN jsonb_build_object('ok', false, 'code', 'invalid_keys');
    END IF;

    v_establishment_note := NULLIF(btrim(p_establishment_note), '');
    IF v_establishment_note IS NOT NULL AND char_length(v_establishment_note) > 160 THEN
        v_establishment_note := substring(v_establishment_note from 1 for 160);
    END IF;

    -- Rate limit: Máximo 2 solicitudes en 24 horas
    SELECT count(*) INTO v_recent_count
    FROM public.merchant_verification_requests
    WHERE user_id = p_user_id
      AND created_at > now() - interval '24 hours';

    IF v_recent_count >= 2 THEN
        RETURN jsonb_build_object('ok', false, 'code', 'rate_limited');
    END IF;

    v_phone_hash := private.hash_credential(v_contact_phone);

    -- Detección de teléfono duplicado en solicitudes pending o approved
    IF EXISTS (
        SELECT 1 FROM public.merchant_verification_requests
        WHERE contact_phone_hash = v_phone_hash
          AND status IN ('pending', 'approved')
    ) THEN
        RETURN jsonb_build_object('ok', false, 'code', 'credential_unavailable');
    END IF;

    INSERT INTO public.merchant_verification_requests (
        id,
        user_id,
        business_name,
        contact_phone_hash,
        establishment_key,
        establishment_note,
        status,
        expires_at,
        created_at,
        updated_at
    ) VALUES (
        p_request_id,
        p_user_id,
        v_business_name,
        v_phone_hash,
        p_establishment_key,
        v_establishment_note,
        'pending',
        now() + interval '24 hours',
        now(),
        now()
    );

    INSERT INTO public.profiles (id)
    VALUES (p_user_id)
    ON CONFLICT (id) DO NOTHING;

    UPDATE public.profiles
    SET seller_verification_status = 'pending',
        updated_at = now()
    WHERE id = p_user_id;

    INSERT INTO public.moderation_jobs (
        entity_table,
        entity_id,
        content_hash,
        has_image,
        priority,
        status
    ) VALUES (
        'merchant_verification_requests',
        p_request_id,
        'merchant_request:' || p_request_id::text,
        true,
        40,
        'pending'
    );

    RETURN jsonb_build_object(
        'ok', true,
        'status', 'manual_review',
        'request_id', p_request_id
    );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_create_merchant_verification_request(uuid, uuid, text, text, text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_create_merchant_verification_request(uuid, uuid, text, text, text, text) TO service_role, postgres;

-- =============================================================================
-- BLOQUE 7: RPC public.admin_clear_merchant_keys
-- =============================================================================

CREATE OR REPLACE FUNCTION public.admin_clear_merchant_keys(
    p_request_id uuid
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF auth.role() IS DISTINCT FROM 'service_role' AND current_user NOT IN ('postgres', 'supabase_admin') THEN
        RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
    END IF;

    IF p_request_id IS NULL THEN
        RETURN;
    END IF;

    UPDATE public.merchant_verification_requests
    SET establishment_key = NULL,
        updated_at = now()
    WHERE id = p_request_id;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_clear_merchant_keys(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_clear_merchant_keys(uuid) TO service_role, postgres;

-- =============================================================================
-- BLOQUE 8: RPC public.admin_review_verification
-- =============================================================================

CREATE OR REPLACE FUNCTION public.admin_review_verification(
    p_reviewer_id uuid,
    p_request_id uuid,
    p_decision text,
    p_reason text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_request public.verification_requests%ROWTYPE;
BEGIN
    IF auth.role() IS DISTINCT FROM 'service_role' AND current_user NOT IN ('postgres', 'supabase_admin') THEN
        RETURN jsonb_build_object('ok', false, 'code', 'not_authorized');
    END IF;

    IF p_reviewer_id IS NULL OR NOT EXISTS (
        SELECT 1 FROM public.user_roles
        WHERE user_id = p_reviewer_id
          AND role IN ('admin', 'moderator')
    ) THEN
        RETURN jsonb_build_object('ok', false, 'code', 'not_authorized');
    END IF;

    IF p_decision NOT IN ('approved', 'rejected') THEN
        RETURN jsonb_build_object('ok', false, 'code', 'invalid_decision');
    END IF;

    SELECT * INTO v_request
    FROM public.verification_requests
    WHERE id = p_request_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('ok', false, 'code', 'not_found');
    END IF;

    IF p_decision = 'approved' THEN
        UPDATE public.verification_requests
        SET status = 'approved',
            reviewed_by = p_reviewer_id,
            reviewed_at = now(),
            rejection_reason = NULL,
            updated_at = now()
        WHERE id = p_request_id;

        INSERT INTO public.profiles (id) VALUES (v_request.user_id) ON CONFLICT (id) DO NOTHING;

        -- Sigue asignando carne_hash sin manipular CUI (Art. 12 Zero-PII)
        UPDATE public.profiles
        SET is_verified = true,
            verification_status = 'verified',
            verification_method = 'manual_review',
            verified_at = COALESCE(verified_at, now()),
            carne_hash = v_request.carne_hash,
            updated_at = now()
        WHERE id = v_request.user_id;

        UPDATE public.moderation_jobs
        SET status = 'done',
            updated_at = now()
        WHERE entity_table = 'verification_requests'
          AND entity_id = p_request_id;
    ELSE
        UPDATE public.verification_requests
        SET status = 'rejected',
            reviewed_by = p_reviewer_id,
            reviewed_at = now(),
            rejection_reason = p_reason,
            updated_at = now()
        WHERE id = p_request_id;

        -- No degradar perfil si fue verificado institucionalmente
        UPDATE public.profiles
        SET verification_status = 'rejected',
            is_verified = false,
            updated_at = now()
        WHERE id = v_request.user_id
          AND (verification_method IS NULL OR verification_method <> 'institutional_email');

        UPDATE public.moderation_jobs
        SET status = 'done',
            updated_at = now()
        WHERE entity_table = 'verification_requests'
          AND entity_id = p_request_id;
    END IF;

    RETURN jsonb_build_object(
        'ok', true,
        'status', p_decision,
        'request_id', p_request_id
    );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_review_verification(uuid, uuid, text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_review_verification(uuid, uuid, text, text) TO service_role, postgres;

-- =============================================================================
-- BLOQUE 9: RECOMPILACIÓN DE public.admin_review_merchant_verification
-- =============================================================================

CREATE OR REPLACE FUNCTION public.admin_review_merchant_verification(
    p_reviewer_id uuid,
    p_request_id uuid,
    p_decision text,
    p_reason text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_request public.merchant_verification_requests%ROWTYPE;
    v_prev_claims text;
BEGIN
    IF auth.role() IS DISTINCT FROM 'service_role' AND current_user NOT IN ('postgres', 'supabase_admin') THEN
        RETURN jsonb_build_object('ok', false, 'code', 'not_authorized');
    END IF;

    IF p_reviewer_id IS NULL OR NOT EXISTS (
        SELECT 1 FROM public.user_roles
        WHERE user_id = p_reviewer_id
          AND role IN ('admin', 'moderator')
    ) THEN
        RETURN jsonb_build_object('ok', false, 'code', 'not_authorized');
    END IF;

    IF p_decision IS NULL OR p_decision NOT IN ('approved', 'rejected') THEN
        RETURN jsonb_build_object('ok', false, 'code', 'invalid_decision');
    END IF;

    SELECT * INTO v_request
    FROM public.merchant_verification_requests
    WHERE id = p_request_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('ok', false, 'code', 'not_found');
    END IF;

    v_prev_claims := current_setting('request.jwt.claims', true);
    PERFORM set_config(
        'request.jwt.claims',
        jsonb_build_object('role', 'service_role', 'sub', p_reviewer_id::text)::text,
        true
    );

    IF p_decision = 'approved' THEN
        UPDATE public.merchant_verification_requests
        SET status = 'approved',
            reviewed_by = p_reviewer_id,
            reviewed_at = now(),
            rejection_reason = NULL,
            updated_at = now()
        WHERE id = p_request_id;

        IF v_request.user_id IS NOT NULL THEN
            INSERT INTO public.seller_profiles (
                user_id,
                seller_type,
                verification_status,
                business_name,
                created_at,
                updated_at
            ) VALUES (
                v_request.user_id,
                'local_business',
                'approved',
                v_request.business_name,
                now(),
                now()
            )
            ON CONFLICT (user_id) DO UPDATE SET
                seller_type = 'local_business',
                verification_status = 'approved',
                business_name = EXCLUDED.business_name,
                updated_at = now();

            INSERT INTO public.profiles (id)
            VALUES (v_request.user_id)
            ON CONFLICT (id) DO NOTHING;

            UPDATE public.profiles
            SET seller_verification_status = 'verified',
                seller_verified_at = now(),
                seller_verified_by = p_reviewer_id,
                updated_at = now()
            WHERE id = v_request.user_id;
        END IF;

        UPDATE public.moderation_jobs
        SET status = 'done',
            updated_at = now()
        WHERE entity_table = 'merchant_verification_requests'
          AND entity_id = p_request_id;
    ELSE
        UPDATE public.merchant_verification_requests
        SET status = 'rejected',
            reviewed_by = p_reviewer_id,
            reviewed_at = now(),
            rejection_reason = p_reason,
            updated_at = now()
        WHERE id = p_request_id;

        IF v_request.user_id IS NOT NULL THEN
            UPDATE public.seller_profiles
            SET verification_status = 'rejected',
                updated_at = now()
            WHERE user_id = v_request.user_id;

            UPDATE public.profiles
            SET seller_verification_status = 'rejected',
                seller_verified_at = NULL,
                updated_at = now()
            WHERE id = v_request.user_id;
        END IF;

        UPDATE public.moderation_jobs
        SET status = 'done',
            updated_at = now()
        WHERE entity_table = 'merchant_verification_requests'
          AND entity_id = p_request_id;
    END IF;

    PERFORM set_config('request.jwt.claims', COALESCE(v_prev_claims, ''), true);

    RETURN jsonb_build_object(
        'ok', true,
        'status', p_decision,
        'request_id', p_request_id
    );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_review_merchant_verification(uuid, uuid, text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_review_merchant_verification(uuid, uuid, text, text) TO service_role, postgres;
