-- =============================================================================
-- Migración: 20261116150000_merchant_verification.sql
-- Módulo: Verificación de Comerciantes USAC (Capa de Base de Datos y Hardening)
-- Rol: Arquitecto Senior de Base de Datos y Seguridad (PostgreSQL / Supabase)
-- =============================================================================

-- =============================================================================
-- BLOQUE 1: TABLA public.merchant_verification_requests
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.merchant_verification_requests (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
    business_name text NOT NULL,
    dpi_hash text NOT NULL,
    dpi_front_key text,
    dpi_back_key text,
    establishment_key text,
    establishment_note text,
    status text NOT NULL DEFAULT 'pending',
    rejection_reason text,
    reviewed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
    reviewed_at timestamptz,
    expires_at timestamptz NOT NULL DEFAULT (now() + interval '24 hours'),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT merchant_verification_requests_business_name_check
        CHECK (char_length(business_name) BETWEEN 2 AND 80),
    CONSTRAINT merchant_verification_requests_establishment_note_check
        CHECK (establishment_note IS NULL OR char_length(establishment_note) <= 160),
    CONSTRAINT merchant_verification_requests_status_check
        CHECK (status IN ('pending', 'approved', 'rejected'))
);

-- Asegurar restricciones de forma idempotente ante reejecuciones o tablas preexistentes
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'public.merchant_verification_requests'::regclass
          AND conname = 'merchant_verification_requests_business_name_check'
    ) AND NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'public.merchant_verification_requests'::regclass
          AND pg_get_constraintdef(oid) LIKE '%business_name%BETWEEN%'
    ) THEN
        ALTER TABLE public.merchant_verification_requests
            ADD CONSTRAINT merchant_verification_requests_business_name_check
            CHECK (char_length(business_name) BETWEEN 2 AND 80);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'public.merchant_verification_requests'::regclass
          AND conname = 'merchant_verification_requests_establishment_note_check'
    ) AND NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'public.merchant_verification_requests'::regclass
          AND pg_get_constraintdef(oid) LIKE '%establishment_note%160%'
    ) THEN
        ALTER TABLE public.merchant_verification_requests
            ADD CONSTRAINT merchant_verification_requests_establishment_note_check
            CHECK (establishment_note IS NULL OR char_length(establishment_note) <= 160);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'public.merchant_verification_requests'::regclass
          AND conname = 'merchant_verification_requests_status_check'
    ) AND NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'public.merchant_verification_requests'::regclass
          AND pg_get_constraintdef(oid) LIKE '%status%pending%'
    ) THEN
        ALTER TABLE public.merchant_verification_requests
            ADD CONSTRAINT merchant_verification_requests_status_check
            CHECK (status IN ('pending', 'approved', 'rejected'));
    END IF;
END $$;

-- Índices según el contrato normativo (§2.1)
CREATE INDEX IF NOT EXISTS idx_merchant_verification_requests_user_created
    ON public.merchant_verification_requests (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_merchant_verification_requests_status_expires
    ON public.merchant_verification_requests (status, expires_at);

CREATE INDEX IF NOT EXISTS idx_merchant_verification_requests_dpi_hash
    ON public.merchant_verification_requests (dpi_hash);

-- Índice parcial para optimizar purga de claves en R2 por cron o Worker
CREATE INDEX IF NOT EXISTS idx_merchant_verification_requests_keys
    ON public.merchant_verification_requests (id)
    WHERE dpi_front_key IS NOT NULL OR dpi_back_key IS NOT NULL OR establishment_key IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_merchant_verification_requests_reviewed_by
    ON public.merchant_verification_requests (reviewed_by);

-- Trigger de actualización automática de timestamp updated_at
DROP TRIGGER IF EXISTS trg_merchant_verification_requests_updated_at ON public.merchant_verification_requests;
CREATE TRIGGER trg_merchant_verification_requests_updated_at
    BEFORE UPDATE ON public.merchant_verification_requests
    FOR EACH ROW
    EXECUTE FUNCTION _triggers.set_updated_at();

-- =============================================================================
-- BLOQUE 2: EXTENSIÓN DE public.moderation_jobs
-- =============================================================================

ALTER TABLE public.moderation_jobs
    DROP CONSTRAINT IF EXISTS moderation_jobs_entity_table_check;

ALTER TABLE public.moderation_jobs
    ADD CONSTRAINT moderation_jobs_entity_table_check
    CHECK (entity_table = ANY (ARRAY[
        'posts'::text,
        'comments'::text,
        'student_groups'::text,
        'marketplace_items'::text,
        'verification_requests'::text,
        'merchant_verification_requests'::text
    ]));

-- =============================================================================
-- BLOQUE 3: POLÍTICAS DE ACCESO (RLS) Y PRIVILEGIOS
-- =============================================================================

ALTER TABLE public.merchant_verification_requests ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.merchant_verification_requests FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.merchant_verification_requests TO authenticated;
GRANT ALL ON TABLE public.merchant_verification_requests TO service_role, postgres;

DROP POLICY IF EXISTS "merchant_verification_requests_select" ON public.merchant_verification_requests;
CREATE POLICY "merchant_verification_requests_select"
    ON public.merchant_verification_requests
    FOR SELECT
    TO authenticated
    USING (
        user_id = auth.uid()
        OR public.is_pemtree_admin(auth.uid())
        OR public.is_pemtree_moderator(auth.uid())
    );

-- =============================================================================
-- BLOQUE 4: RPC public.admin_create_merchant_verification_request
-- =============================================================================

CREATE OR REPLACE FUNCTION public.admin_create_merchant_verification_request(
    p_request_id uuid,
    p_user_id uuid,
    p_business_name text,
    p_dpi_number text,
    p_dpi_front_key text,
    p_dpi_back_key text,
    p_establishment_key text,
    p_establishment_note text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_business_name text;
    v_dpi_number text;
    v_dpi_hash text;
    v_establishment_note text;
    v_key_prefix text;
    v_recent_count integer;
BEGIN
    -- 1. Validar autorización: Solo invocable por service_role o postgres interno
    IF auth.role() IS DISTINCT FROM 'service_role' AND current_user NOT IN ('postgres', 'supabase_admin') THEN
        RETURN jsonb_build_object('ok', false, 'code', 'not_authorized');
    END IF;

    -- 2. Validar identificadores requeridos
    IF p_request_id IS NULL OR p_user_id IS NULL THEN
        RETURN jsonb_build_object('ok', false, 'code', 'not_authorized');
    END IF;

    -- 3. Validar y normalizar nombre del negocio (2-80 caracteres)
    IF p_business_name IS NULL THEN
        RETURN jsonb_build_object('ok', false, 'code', 'invalid_business_name');
    END IF;

    v_business_name := btrim(p_business_name);
    IF char_length(v_business_name) < 2 OR char_length(v_business_name) > 80 THEN
        RETURN jsonb_build_object('ok', false, 'code', 'invalid_business_name');
    END IF;

    -- 4. Validar y normalizar número de DPI (13 dígitos, departamento 01 a 22)
    IF p_dpi_number IS NULL THEN
        RETURN jsonb_build_object('ok', false, 'code', 'invalid_dpi');
    END IF;

    v_dpi_number := btrim(p_dpi_number);
    IF v_dpi_number !~ '^[0-9]{9}(0[1-9]|1[0-9]|2[0-2])[0-9]{2}$' THEN
        RETURN jsonb_build_object('ok', false, 'code', 'invalid_dpi');
    END IF;

    -- 5. Validar claves R2 de los 3 documentos
    -- Deben ser no nulas, distintas entre sí y comenzar estrictamente con el prefijo normativo
    v_key_prefix := 'pending/merchant/' || p_user_id::text || '/' || p_request_id::text || '/';

    IF p_dpi_front_key IS NULL
       OR p_dpi_back_key IS NULL
       OR p_establishment_key IS NULL
       OR p_dpi_front_key = p_dpi_back_key
       OR p_dpi_front_key = p_establishment_key
       OR p_dpi_back_key = p_establishment_key
       OR NOT starts_with(p_dpi_front_key, v_key_prefix)
       OR NOT starts_with(p_dpi_back_key, v_key_prefix)
       OR NOT starts_with(p_establishment_key, v_key_prefix)
       OR char_length(p_dpi_front_key) <= char_length(v_key_prefix)
       OR char_length(p_dpi_back_key) <= char_length(v_key_prefix)
       OR char_length(p_establishment_key) <= char_length(v_key_prefix) THEN
        RETURN jsonb_build_object('ok', false, 'code', 'invalid_keys');
    END IF;

    -- Normalizar nota opcional de ubicación (máximo 160 caracteres)
    v_establishment_note := NULLIF(btrim(p_establishment_note), '');
    IF v_establishment_note IS NOT NULL AND char_length(v_establishment_note) > 160 THEN
        v_establishment_note := substring(v_establishment_note from 1 for 160);
    END IF;

    -- 6. Rate limit: Máximo 2 solicitudes por usuario en una ventana móvil de 24 horas
    SELECT count(*) INTO v_recent_count
    FROM public.merchant_verification_requests
    WHERE user_id = p_user_id
      AND created_at > now() - interval '24 hours';

    IF v_recent_count >= 2 THEN
        RETURN jsonb_build_object('ok', false, 'code', 'rate_limited');
    END IF;

    -- 7. Computar hash HMAC-SHA256 con salt secreto (nunca se almacena el DPI en claro)
    v_dpi_hash := private.hash_credential(v_dpi_number);

    -- Detección de DPI duplicado en otra cuenta con estado pending o approved
    IF EXISTS (
        SELECT 1 FROM public.merchant_verification_requests
        WHERE user_id IS DISTINCT FROM p_user_id
          AND dpi_hash = v_dpi_hash
          AND status IN ('pending', 'approved')
    ) THEN
        RETURN jsonb_build_object('ok', false, 'code', 'credential_unavailable');
    END IF;

    -- 8. Insertar fila de solicitud con expiración a 24 horas
    INSERT INTO public.merchant_verification_requests (
        id,
        user_id,
        business_name,
        dpi_hash,
        dpi_front_key,
        dpi_back_key,
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
        v_dpi_hash,
        p_dpi_front_key,
        p_dpi_back_key,
        p_establishment_key,
        v_establishment_note,
        'pending',
        now() + interval '24 hours',
        now(),
        now()
    );

    -- 9. Asegurar existencia de perfil y actualizar seller_verification_status a pending
    -- IMPORTANTE: No modificar is_verified ni campos de verificación estudiantil.
    INSERT INTO public.profiles (id)
    VALUES (p_user_id)
    ON CONFLICT (id) DO NOTHING;

    UPDATE public.profiles
    SET seller_verification_status = 'pending',
        updated_at = now()
    WHERE id = p_user_id;

    -- 10. Crear tarea en la cola de moderación (priority=40, has_image=true)
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

    -- 11. Respuesta exitosa
    RETURN jsonb_build_object(
        'ok', true,
        'status', 'manual_review',
        'request_id', p_request_id
    );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_create_merchant_verification_request(uuid, uuid, text, text, text, text, text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_create_merchant_verification_request(uuid, uuid, text, text, text, text, text, text) TO service_role;

-- =============================================================================
-- BLOQUE 5: RPC public.admin_review_merchant_verification
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
    -- 1. Validar autorización de llamada (service_role o postgres interno)
    IF auth.role() IS DISTINCT FROM 'service_role' AND current_user NOT IN ('postgres', 'supabase_admin') THEN
        RETURN jsonb_build_object('ok', false, 'code', 'not_authorized');
    END IF;

    -- 2. Validar que el revisor tenga rol de staff en public.user_roles
    IF p_reviewer_id IS NULL OR NOT EXISTS (
        SELECT 1 FROM public.user_roles
        WHERE user_id = p_reviewer_id
          AND role IN ('admin', 'moderator')
    ) THEN
        RETURN jsonb_build_object('ok', false, 'code', 'not_authorized');
    END IF;

    -- 3. Validar decisión
    IF p_decision IS NULL OR p_decision NOT IN ('approved', 'rejected') THEN
        RETURN jsonb_build_object('ok', false, 'code', 'invalid_decision');
    END IF;

    -- 4. Bloquear la fila de la solicitud para concurrencia segura
    SELECT * INTO v_request
    FROM public.merchant_verification_requests
    WHERE id = p_request_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('ok', false, 'code', 'not_found');
    END IF;

    -- Configurar temporalmente claims administrativos para triggers dependientes (guard_seller_profile_updates)
    v_prev_claims := current_setting('request.jwt.claims', true);
    PERFORM set_config(
        'request.jwt.claims',
        jsonb_build_object('role', 'service_role', 'sub', p_reviewer_id::text)::text,
        true
    );

    IF p_decision = 'approved' THEN
        -- Actualizar solicitud a approved
        UPDATE public.merchant_verification_requests
        SET status = 'approved',
            reviewed_by = p_reviewer_id,
            reviewed_at = now(),
            rejection_reason = NULL,
            updated_at = now()
        WHERE id = p_request_id;

        IF v_request.user_id IS NOT NULL THEN
            -- Upsert en seller_profiles como local_business aprobado, conservando plan_id si existía
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

            -- Actualizar perfil: seller_verification_status = verified
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

        -- Marcar moderación como resuelta
        UPDATE public.moderation_jobs
        SET status = 'done',
            updated_at = now()
        WHERE entity_table = 'merchant_verification_requests'
          AND entity_id = p_request_id;
    ELSE
        -- p_decision = 'rejected'
        UPDATE public.merchant_verification_requests
        SET status = 'rejected',
            reviewed_by = p_reviewer_id,
            reviewed_at = now(),
            rejection_reason = p_reason,
            updated_at = now()
        WHERE id = p_request_id;

        IF v_request.user_id IS NOT NULL THEN
            -- Actualizar seller_profiles a rejected si existe
            UPDATE public.seller_profiles
            SET verification_status = 'rejected',
                updated_at = now()
            WHERE user_id = v_request.user_id;

            -- Actualizar profiles: seller_verification_status = rejected, seller_verified_at = NULL
            -- IMPORTANTE: No degradar is_verified ni la verificación de estudiante
            UPDATE public.profiles
            SET seller_verification_status = 'rejected',
                seller_verified_at = NULL,
                updated_at = now()
            WHERE id = v_request.user_id;
        END IF;

        -- Marcar moderación como resuelta
        UPDATE public.moderation_jobs
        SET status = 'done',
            updated_at = now()
        WHERE entity_table = 'merchant_verification_requests'
          AND entity_id = p_request_id;
    END IF;

    -- Restaurar claims previos de sesión
    PERFORM set_config('request.jwt.claims', COALESCE(v_prev_claims, ''), true);

    -- Devolver resultado de la revisión
    RETURN jsonb_build_object(
        'ok', true,
        'status', p_decision,
        'request_id', p_request_id
    );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_review_merchant_verification(uuid, uuid, text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_review_merchant_verification(uuid, uuid, text, text) TO service_role;

-- =============================================================================
-- BLOQUE 6: RPC public.admin_clear_merchant_keys
-- =============================================================================

CREATE OR REPLACE FUNCTION public.admin_clear_merchant_keys(
    p_request_id uuid
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    -- Validar privilegios de llamada
    IF auth.role() IS DISTINCT FROM 'service_role' AND current_user NOT IN ('postgres', 'supabase_admin') THEN
        RAISE EXCEPTION 'not_authorized' USING ERRCODE = '42501';
    END IF;

    IF p_request_id IS NULL THEN
        RETURN;
    END IF;

    -- Poner las 3 claves R2 a NULL y actualizar timestamp sin tocar status
    UPDATE public.merchant_verification_requests
    SET dpi_front_key = NULL,
        dpi_back_key = NULL,
        establishment_key = NULL,
        updated_at = now()
    WHERE id = p_request_id;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_clear_merchant_keys(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_clear_merchant_keys(uuid) TO service_role;
