-- =============================================================================
-- Migración: 20261116120000_student_verification.sql
-- Módulo: Verificación Estudiantil USAC (Capa de Base de Datos y Hardening)
-- Rol: Arquitecto Senior de Base de Datos y Seguridad (PostgreSQL / Supabase)
-- =============================================================================

-- =============================================================================
-- BLOQUE 1: EXTENSIÓN DE public.facultades
-- =============================================================================

ALTER TABLE public.facultades
    ADD COLUMN IF NOT EXISTS allowed_domains text[] NOT NULL DEFAULT '{}'::text[];

-- Población de dominios autorizados según contrato normativo (§2.1)
-- Se pueblan únicamente si el arreglo está vacío para garantizar idempotencia.
UPDATE public.facultades
SET allowed_domains = ARRAY['ingenieria.usac.edu.gt', 'ecys.org']
WHERE id = '08' AND cardinality(allowed_domains) = 0;

UPDATE public.facultades
SET allowed_domains = ARRAY['medicina.usac.edu.gt']
WHERE id = '05' AND cardinality(allowed_domains) = 0;

UPDATE public.facultades
SET allowed_domains = ARRAY['derecho.usac.edu.gt']
WHERE id = '04' AND cardinality(allowed_domains) = 0;

UPDATE public.facultades
SET allowed_domains = ARRAY['economicas.usac.edu.gt']
WHERE id = '03' AND cardinality(allowed_domains) = 0;

UPDATE public.facultades
SET allowed_domains = ARRAY['farusac.edu.gt']
WHERE id = '06' AND cardinality(allowed_domains) = 0;

UPDATE public.facultades
SET allowed_domains = ARRAY['fausac.gt']
WHERE id = '01' AND cardinality(allowed_domains) = 0;

-- =============================================================================
-- BLOQUE 2: CAMPOS DE VERIFICACIÓN EN public.profiles
-- =============================================================================

ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS verification_method text,
    ADD COLUMN IF NOT EXISTS verification_status text NOT NULL DEFAULT 'unverified',
    ADD COLUMN IF NOT EXISTS institutional_email_domain text;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'public.profiles'::regclass
          AND conname = 'profiles_verification_method_check'
    ) THEN
        ALTER TABLE public.profiles
            ADD CONSTRAINT profiles_verification_method_check
            CHECK (verification_method IS NULL OR verification_method = ANY (ARRAY[
                'institutional_email'::text, 'ocr_document'::text, 'qr_code'::text, 'manual_review'::text
            ]));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'public.profiles'::regclass
          AND conname = 'profiles_verification_status_check'
    ) THEN
        ALTER TABLE public.profiles
            ADD CONSTRAINT profiles_verification_status_check
            CHECK (verification_status = ANY (ARRAY[
                'unverified'::text, 'pending_review'::text, 'verified'::text, 'rejected'::text
            ]));
    END IF;
END $$;

-- Verificación de índices únicos de hashes en profiles (no duplicar)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relname = 'profiles_carne_hash_key'
    ) AND NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'public.profiles'::regclass AND conname = 'profiles_carne_hash_key'
    ) THEN
        CREATE UNIQUE INDEX profiles_carne_hash_key ON public.profiles (carne_hash);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relname = 'profiles_cui_hash_key'
    ) AND NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'public.profiles'::regclass AND conname = 'profiles_cui_hash_key'
    ) THEN
        CREATE UNIQUE INDEX profiles_cui_hash_key ON public.profiles (cui_hash);
    END IF;
END $$;

-- Sincronizar perfiles existentes con el invariante de verificación
UPDATE public.profiles
SET verification_status = 'verified'
WHERE is_verified = true AND verification_status <> 'verified';

UPDATE public.profiles
SET is_verified = true,
    verified_at = COALESCE(verified_at, now())
WHERE verification_status = 'verified' AND is_verified = false;

-- =============================================================================
-- BLOQUE 3: TABLA public.verification_requests
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.verification_requests (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    carne_hash text NOT NULL,
    cui_hash text,
    document_type text NOT NULL CHECK (document_type = ANY (ARRAY[
        'constancia_inscripcion'::text, 'carne_fisico'::text, 'boleta_asignacion'::text
    ])),
    r2_object_key text,
    extracted_ocr_text text,
    qr_url text,
    ocr_confidence double precision,
    ocr_source text NOT NULL DEFAULT 'client' CHECK (ocr_source = ANY (ARRAY['client'::text, 'server'::text])),
    status text NOT NULL DEFAULT 'pending' CHECK (status = ANY (ARRAY[
        'pending'::text, 'approved'::text, 'manual_review'::text, 'rejected'::text
    ])),
    rejection_reason text,
    reviewed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
    reviewed_at timestamptz,
    expires_at timestamptz NOT NULL DEFAULT (now() + interval '24 hours'),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_verification_requests_user_created
    ON public.verification_requests (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_verification_requests_status_expires
    ON public.verification_requests (status, expires_at);

CREATE INDEX IF NOT EXISTS idx_verification_requests_r2_object_key
    ON public.verification_requests (id)
    WHERE r2_object_key IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_verification_requests_reviewed_by
    ON public.verification_requests (reviewed_by);

-- Trigger de updated_at para verification_requests
DROP TRIGGER IF EXISTS trg_verification_requests_updated_at ON public.verification_requests;
CREATE TRIGGER trg_verification_requests_updated_at
    BEFORE UPDATE ON public.verification_requests
    FOR EACH ROW
    EXECUTE FUNCTION _triggers.set_updated_at();

-- =============================================================================
-- BLOQUE 4: CHECK CONSTRAINT EN public.moderation_jobs
-- =============================================================================

ALTER TABLE public.moderation_jobs
    DROP CONSTRAINT IF EXISTS moderation_jobs_entity_table_check;

ALTER TABLE public.moderation_jobs
    ADD CONSTRAINT moderation_jobs_entity_table_check
    CHECK (entity_table = ANY (ARRAY[
        'posts'::text, 'comments'::text, 'student_groups'::text, 'marketplace_items'::text, 'verification_requests'::text
    ]));

-- =============================================================================
-- BLOQUE 5: HASH DE CREDENCIALES (SCHEMA private)
-- =============================================================================

CREATE OR REPLACE FUNCTION private.hash_credential(p_value text)
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF p_value IS NULL OR btrim(p_value) = '' THEN
        RETURN NULL;
    END IF;

    RETURN encode(extensions.hmac(btrim(p_value)::text, private.get_secret_salt()::text, 'sha256'::text), 'hex');
END;
$$;

REVOKE ALL ON FUNCTION private.hash_credential(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.hash_credential(text) TO postgres, service_role;

-- =============================================================================
-- BLOQUE 6: FUNCIONES SQL DE NEGOCIO Y ADMINISTRACIÓN
-- =============================================================================

-- 6.1 public.is_user_verified
CREATE OR REPLACE FUNCTION public.is_user_verified()
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM public.profiles
        WHERE id = auth.uid()
          AND is_verified = true
    );
END;
$$;

REVOKE ALL ON FUNCTION public.is_user_verified() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_user_verified() TO authenticated, service_role;

-- 6.2 public.claim_student_credentials
CREATE OR REPLACE FUNCTION public.claim_student_credentials(
    p_carne text,
    p_cui text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_user_id uuid;
    v_carne_year integer;
    v_carne_hash text;
    v_cui_clean text;
    v_cui_hash text;
    v_status text;
    v_is_verified boolean;
BEGIN
    -- Validar que el usuario esté autenticado
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('ok', false, 'code', 'not_authenticated');
    END IF;

    -- Validar formato del carné y rango del año
    IF p_carne IS NULL OR btrim(p_carne) !~ '^(19[8-9][0-9]|20[0-9][0-9])[0-9]{5}$' THEN
        RETURN jsonb_build_object('ok', false, 'code', 'invalid_carne');
    END IF;

    v_carne_year := substring(btrim(p_carne) from 1 for 4)::integer;
    IF v_carne_year < 1980 OR v_carne_year > EXTRACT(YEAR FROM now())::integer THEN
        RETURN jsonb_build_object('ok', false, 'code', 'invalid_carne');
    END IF;

    -- Validar CUI si es provisto
    IF p_cui IS NOT NULL AND btrim(p_cui) <> '' THEN
        IF btrim(p_cui) !~ '^[0-9]{9}(0[1-9]|1[0-9]|2[0-2])[0-9]{2}$' THEN
            RETURN jsonb_build_object('ok', false, 'code', 'invalid_cui');
        END IF;
        v_cui_clean := btrim(p_cui);
    ELSE
        v_cui_clean := NULL;
    END IF;

    -- Computar hashes criptográficos
    v_carne_hash := private.hash_credential(btrim(p_carne));
    IF v_cui_clean IS NOT NULL THEN
        v_cui_hash := private.hash_credential(v_cui_clean);
    ELSE
        v_cui_hash := NULL;
    END IF;

    -- Verificar que la credencial no esté reclamada por otro usuario
    IF EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id <> v_user_id
          AND (
              carne_hash = v_carne_hash
              OR (v_cui_hash IS NOT NULL AND cui_hash = v_cui_hash)
          )
    ) OR EXISTS (
        SELECT 1 FROM public.verification_requests
        WHERE user_id <> v_user_id
          AND status IN ('approved', 'manual_review', 'pending')
          AND (
              carne_hash = v_carne_hash
              OR (v_cui_hash IS NOT NULL AND cui_hash = v_cui_hash)
          )
    ) THEN
        RETURN jsonb_build_object('ok', false, 'code', 'credential_unavailable');
    END IF;

    -- Asegurar perfil y actualizar hashes
    INSERT INTO public.profiles (id) VALUES (v_user_id) ON CONFLICT (id) DO NOTHING;

    UPDATE public.profiles
    SET carne_hash = v_carne_hash,
        cui_hash = COALESCE(v_cui_hash, cui_hash),
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

REVOKE ALL ON FUNCTION public.claim_student_credentials(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.claim_student_credentials(text, text) TO authenticated, service_role;

-- 6.3 public.admin_create_verification_request
CREATE OR REPLACE FUNCTION public.admin_create_verification_request(
    p_user_id uuid,
    p_carne text,
    p_cui text DEFAULT NULL,
    p_document_type text DEFAULT 'constancia_inscripcion',
    p_r2_object_key text DEFAULT NULL,
    p_ocr_text text DEFAULT NULL,
    p_qr_url text DEFAULT NULL,
    p_ocr_confidence double precision DEFAULT NULL,
    p_auto_approved boolean DEFAULT false
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_carne_year integer;
    v_cui_clean text;
    v_carne_hash text;
    v_cui_hash text;
    v_recent_count integer;
    v_request_id uuid;
BEGIN
    -- Validar rol del llamador
    IF auth.role() IS DISTINCT FROM 'service_role' AND current_user NOT IN ('postgres', 'supabase_admin') THEN
        RETURN jsonb_build_object('ok', false, 'code', 'not_authorized');
    END IF;

    IF p_user_id IS NULL THEN
        RETURN jsonb_build_object('ok', false, 'code', 'not_authorized');
    END IF;

    -- Validar carné
    IF p_carne IS NULL OR btrim(p_carne) !~ '^(19[8-9][0-9]|20[0-9][0-9])[0-9]{5}$' THEN
        RETURN jsonb_build_object('ok', false, 'code', 'invalid_carne');
    END IF;

    v_carne_year := substring(btrim(p_carne) from 1 for 4)::integer;
    IF v_carne_year < 1980 OR v_carne_year > EXTRACT(YEAR FROM now())::integer THEN
        RETURN jsonb_build_object('ok', false, 'code', 'invalid_carne');
    END IF;

    -- Validar CUI
    IF p_cui IS NOT NULL AND btrim(p_cui) <> '' THEN
        IF btrim(p_cui) !~ '^[0-9]{9}(0[1-9]|1[0-9]|2[0-2])[0-9]{2}$' THEN
            RETURN jsonb_build_object('ok', false, 'code', 'invalid_cui');
        END IF;
        v_cui_clean := btrim(p_cui);
    ELSE
        v_cui_clean := NULL;
    END IF;

    -- Validar tipo de documento
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

    -- Computar hashes
    v_carne_hash := private.hash_credential(btrim(p_carne));
    IF v_cui_clean IS NOT NULL THEN
        v_cui_hash := private.hash_credential(v_cui_clean);
    ELSE
        v_cui_hash := NULL;
    END IF;

    -- Detección de credencial tomada por otro usuario
    IF EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id <> p_user_id
          AND (
              carne_hash = v_carne_hash
              OR (v_cui_hash IS NOT NULL AND cui_hash = v_cui_hash)
          )
    ) OR EXISTS (
        SELECT 1 FROM public.verification_requests
        WHERE user_id <> p_user_id
          AND status IN ('approved', 'manual_review', 'pending')
          AND (
              carne_hash = v_carne_hash
              OR (v_cui_hash IS NOT NULL AND cui_hash = v_cui_hash)
          )
    ) THEN
        RETURN jsonb_build_object('ok', false, 'code', 'credential_unavailable');
    END IF;

    -- Insertar solicitud
    INSERT INTO public.verification_requests (
        user_id,
        carne_hash,
        cui_hash,
        document_type,
        r2_object_key,
        extracted_ocr_text,
        qr_url,
        ocr_confidence,
        ocr_source,
        status,
        reviewed_at,
        expires_at
    ) VALUES (
        p_user_id,
        v_carne_hash,
        v_cui_hash,
        p_document_type,
        CASE WHEN p_auto_approved THEN NULL ELSE p_r2_object_key END,
        p_ocr_text,
        p_qr_url,
        p_ocr_confidence,
        'client',
        CASE WHEN p_auto_approved THEN 'approved' ELSE 'manual_review' END,
        CASE WHEN p_auto_approved THEN now() ELSE NULL END,
        now() + interval '24 hours'
    ) RETURNING id INTO v_request_id;

    -- Asegurar perfil
    INSERT INTO public.profiles (id) VALUES (p_user_id) ON CONFLICT (id) DO NOTHING;

    IF p_auto_approved THEN
        UPDATE public.profiles
        SET is_verified = true,
            verified_at = now(),
            verification_status = 'verified',
            verification_method = 'ocr_document',
            carne_hash = v_carne_hash,
            cui_hash = COALESCE(v_cui_hash, cui_hash),
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

REVOKE ALL ON FUNCTION public.admin_create_verification_request(uuid, text, text, text, text, text, text, double precision, boolean) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_create_verification_request(uuid, text, text, text, text, text, text, double precision, boolean) TO service_role;

-- 6.4 public.admin_review_verification
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

        UPDATE public.profiles
        SET is_verified = true,
            verification_status = 'verified',
            verification_method = 'manual_review',
            verified_at = COALESCE(verified_at, now()),
            carne_hash = v_request.carne_hash,
            cui_hash = COALESCE(v_request.cui_hash, cui_hash),
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
GRANT EXECUTE ON FUNCTION public.admin_review_verification(uuid, uuid, text, text) TO service_role;

-- =============================================================================
-- BLOQUE 7: TRIGGER DE CORREO INSTITUCIONAL
-- =============================================================================

CREATE OR REPLACE FUNCTION public.handle_institutional_email_verification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_domain text;
    v_is_allowed boolean := false;
BEGIN
    IF NEW.email_confirmed_at IS NULL OR NEW.email IS NULL OR position('@' in NEW.email) = 0 THEN
        RETURN NEW;
    END IF;

    v_domain := lower(split_part(NEW.email, '@', 2));
    IF v_domain = '' THEN
        RETURN NEW;
    END IF;

    IF v_domain = 'usac.edu.gt'
       OR v_domain LIKE '%.usac.edu.gt'
       OR EXISTS (
           SELECT 1
           FROM public.facultades f
           WHERE v_domain = ANY(f.allowed_domains)
       ) THEN
        v_is_allowed := true;
    END IF;

    IF NOT v_is_allowed THEN
        RETURN NEW;
    END IF;

    -- Resiliente ante orden de creación de perfiles
    INSERT INTO public.profiles (id)
    VALUES (NEW.id)
    ON CONFLICT (id) DO NOTHING;

    UPDATE public.profiles
    SET is_verified = true,
        verification_status = 'verified',
        verification_method = CASE
            WHEN verification_method IN ('ocr_document', 'manual_review') THEN verification_method
            ELSE 'institutional_email'
        END,
        verified_at = COALESCE(verified_at, now()),
        institutional_email_domain = v_domain,
        updated_at = now()
    WHERE id = NEW.id;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_on_auth_user_email_verified ON auth.users;
CREATE TRIGGER trg_on_auth_user_email_verified
    AFTER INSERT OR UPDATE OF email, email_confirmed_at ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_institutional_email_verification();

REVOKE ALL ON FUNCTION public.handle_institutional_email_verification() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.handle_institutional_email_verification() TO postgres, service_role;

-- =============================================================================
-- BLOQUE 8: RLS Y PROTECCIÓN DE CAMPOS SENSIBLES
-- =============================================================================

ALTER TABLE public.verification_requests ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.verification_requests FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.verification_requests TO authenticated;
GRANT ALL ON TABLE public.verification_requests TO service_role, postgres;

DROP POLICY IF EXISTS "verification_requests_select" ON public.verification_requests;
CREATE POLICY "verification_requests_select"
    ON public.verification_requests
    FOR SELECT
    TO authenticated
    USING (
        user_id = auth.uid()
        OR public.is_pemtree_admin(auth.uid())
        OR public.is_pemtree_moderator(auth.uid())
    );

CREATE OR REPLACE FUNCTION public.guard_verification_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
BEGIN
    IF TG_OP = 'UPDATE' THEN
        IF (
            NEW.is_verified IS DISTINCT FROM OLD.is_verified
            OR NEW.verified_at IS DISTINCT FROM OLD.verified_at
            OR NEW.verification_status IS DISTINCT FROM OLD.verification_status
            OR NEW.verification_method IS DISTINCT FROM OLD.verification_method
            OR NEW.institutional_email_domain IS DISTINCT FROM OLD.institutional_email_domain
        )
        AND auth.role() IS DISTINCT FROM 'service_role'
        AND current_user NOT IN ('postgres', 'supabase_admin')
        AND NOT (
            public.is_pemtree_admin(auth.uid())
            OR public.is_pemtree_moderator(auth.uid())
        ) THEN
            RAISE EXCEPTION 'Student verification fields can only be changed by authorized staff or system.'
                USING ERRCODE = '42501';
        END IF;
    END IF;

    -- Garantizar invariante: verification_status = 'verified' <=> is_verified = true
    IF NEW.verification_status = 'verified' THEN
        NEW.is_verified := true;
        NEW.verified_at := COALESCE(NEW.verified_at, CASE WHEN TG_OP = 'UPDATE' THEN OLD.verified_at ELSE NULL END, now());
    ELSIF NEW.is_verified = true AND (NEW.verification_status IS NULL OR NEW.verification_status = 'unverified') THEN
        NEW.verification_status := 'verified';
        NEW.verified_at := COALESCE(NEW.verified_at, CASE WHEN TG_OP = 'UPDATE' THEN OLD.verified_at ELSE NULL END, now());
    ELSIF NEW.verification_status IN ('unverified', 'pending_review', 'rejected') THEN
        NEW.is_verified := false;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS guard_verification_fields ON public.profiles;
CREATE TRIGGER guard_verification_fields
    BEFORE INSERT OR UPDATE ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.guard_verification_fields();
