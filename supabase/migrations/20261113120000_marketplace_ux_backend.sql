-- =============================================================================
-- Migración: 20261113120000_marketplace_ux_backend.sql
-- Módulo: Marketplace y Tutorías — UX, Privacidad, Planes y Backend Robusto
-- Rol: Agente 1 — Arquitecto Senior de Base de Datos (PostgreSQL / Supabase)
-- =============================================================================

BEGIN;

-- =============================================================================
-- BLOQUE 1: TABLAS NUEVAS
-- =============================================================================

-- 1.1 Catálogo de planes de suscripción del Marketplace
CREATE TABLE IF NOT EXISTS public.marketplace_plans (
    id text PRIMARY KEY,
    name text NOT NULL,
    price_monthly numeric(10,2) NOT NULL DEFAULT 0 CHECK (price_monthly >= 0),
    max_active_items integer NOT NULL DEFAULT 3 CHECK (max_active_items >= 0),
    max_images_per_item integer NOT NULL DEFAULT 2 CHECK (max_images_per_item >= 0),
    allow_video boolean NOT NULL DEFAULT false,
    auto_sponsor_items boolean NOT NULL DEFAULT false,
    hide_competitor_related boolean NOT NULL DEFAULT false,
    default_badge_text text,
    features jsonb NOT NULL DEFAULT '[]'::jsonb,
    sort_order integer NOT NULL DEFAULT 0,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

-- Trigger de updated_at para marketplace_plans
DROP TRIGGER IF EXISTS trg_marketplace_plans_updated_at ON public.marketplace_plans;
CREATE TRIGGER trg_marketplace_plans_updated_at
    BEFORE UPDATE ON public.marketplace_plans
    FOR EACH ROW
    EXECUTE FUNCTION _triggers.set_updated_at();

-- 1.2 Perfil comercial y estado de suscripción del vendedor
CREATE TABLE IF NOT EXISTS public.seller_profiles (
    user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    public_id uuid NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    plan_id text NOT NULL REFERENCES public.marketplace_plans(id) ON UPDATE CASCADE DEFAULT 'free',
    seller_type text NOT NULL DEFAULT 'student' CHECK (seller_type IN ('student', 'local_business')),
    verification_status text NOT NULL DEFAULT 'pending' CHECK (verification_status IN ('pending', 'approved', 'rejected', 'suspended')),
    business_name text,
    business_description text,
    business_logo_url text,
    business_banner_url text,
    business_hours jsonb,
    is_currently_on_campus boolean NOT NULL DEFAULT false,
    current_building_code text,
    current_location_note text,
    plan_expires_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT seller_profiles_business_name_len CHECK (business_name IS NULL OR length(business_name) <= 80),
    CONSTRAINT seller_profiles_business_desc_len CHECK (business_description IS NULL OR length(business_description) <= 300),
    CONSTRAINT seller_profiles_location_note_len CHECK (current_location_note IS NULL OR length(current_location_note) <= 120)
);

-- Trigger de updated_at para seller_profiles
DROP TRIGGER IF EXISTS trg_seller_profiles_updated_at ON public.seller_profiles;
CREATE TRIGGER trg_seller_profiles_updated_at
    BEFORE UPDATE ON public.seller_profiles
    FOR EACH ROW
    EXECUTE FUNCTION _triggers.set_updated_at();

-- 1.3 Telemetría y eventos de conversión
CREATE TABLE IF NOT EXISTS public.marketplace_item_events (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    item_id uuid NOT NULL REFERENCES public.marketplace_items(id) ON DELETE CASCADE,
    viewer_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
    event_type text NOT NULL CHECK (event_type IN ('view', 'click_whatsapp', 'click_telegram', 'click_instagram', 'click_messenger', 'share')),
    created_at timestamptz NOT NULL DEFAULT now()
);

-- 1.4 Marcadores / guardados de productos
CREATE TABLE IF NOT EXISTS public.marketplace_bookmarks (
    item_id uuid NOT NULL REFERENCES public.marketplace_items(id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (item_id, user_id)
);

-- =============================================================================
-- BLOQUE 2: EXTENSIONES SOBRE TABLAS EXISTENTES
-- =============================================================================

-- Vigencia y contador de compartidos en marketplace_items
ALTER TABLE public.marketplace_items ADD COLUMN IF NOT EXISTS expires_at timestamptz;
ALTER TABLE public.marketplace_items ADD COLUMN IF NOT EXISTS shares_count integer NOT NULL DEFAULT 0;

-- Compatibilidad con el modelo legacy de verificación de vendedores.
-- En la base remota esta columna puede no existir; se crea y se backfillea
-- desde profiles.is_verified para no romper a vendedores ya verificados.
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS seller_verification_status text NOT NULL DEFAULT 'unverified';
UPDATE public.profiles
SET seller_verification_status = 'verified'
WHERE is_verified = true
  AND seller_verification_status IS DISTINCT FROM 'verified';

-- Plan y revisión administrativa en sponsor_requests
ALTER TABLE public.sponsor_requests ADD COLUMN IF NOT EXISTS plan_id text REFERENCES public.marketplace_plans(id) ON UPDATE CASCADE;
ALTER TABLE public.sponsor_requests ADD COLUMN IF NOT EXISTS reviewed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE public.sponsor_requests ADD COLUMN IF NOT EXISTS reviewed_at timestamptz;
ALTER TABLE public.sponsor_requests ADD COLUMN IF NOT EXISTS admin_note text;

-- Limpieza idempotente de solicitudes activas duplicadas antes de crear el índice único
DO $$
BEGIN
    WITH ranked AS (
        SELECT id,
               ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY created_at DESC, id DESC) AS rn
        FROM public.sponsor_requests
        WHERE status IN ('pending', 'in_review')
          AND user_id IS NOT NULL
    )
    UPDATE public.sponsor_requests
    SET status = 'rejected',
        admin_note = COALESCE(admin_note || E'\n', '') || 'Rechazado automáticamente por duplicidad de solicitud activa.',
        reviewed_at = now()
    WHERE id IN (
        SELECT id FROM ranked WHERE rn > 1
    );
END $$;

-- Índice único parcial: una sola solicitud activa por usuario
CREATE UNIQUE INDEX IF NOT EXISTS idx_sponsor_requests_single_active_per_user
ON public.sponsor_requests (user_id)
WHERE status IN ('pending', 'in_review') AND user_id IS NOT NULL;

-- =============================================================================
-- BLOQUE 3: SEED DE PLANES BASE (IDEMPOTENTE Y EXACTO AL DOCUMENTO UX)
-- =============================================================================

INSERT INTO public.marketplace_plans (
    id, name, price_monthly, max_active_items, max_images_per_item,
    allow_video, auto_sponsor_items, hide_competitor_related,
    default_badge_text, features, sort_order, is_active
) VALUES
    (
        'free',
        'Estudiante',
        0.00,
        3,
        2,
        false,
        false,
        false,
        'Estudiante Verificado',
        '["3 publicaciones activas", "2 fotos por publicación", "14 días de vigencia", "Insignia de Estudiante Verificado", "Contacto directo externo"]'::jsonb,
        1,
        true
    ),
    (
        'pro_student',
        'Emprendedor',
        0.00,
        20,
        6,
        true,
        true,
        false,
        'Emprendedor Verificado',
        '["20 publicaciones activas", "6 fotos por publicación", "1 video promocional", "Publicaciones permanentes", "Check-in de edificio en campus", "Insignia de Emprendedor Verificado", "Prioridad media en feed"]'::jsonb,
        2,
        true
    ),
    (
        'business_local',
        'Comercio',
        0.00,
        0,
        10,
        true,
        true,
        true,
        'Tienda / Local Oficial',
        '["Publicaciones activas ilimitadas", "10 fotos por publicación", "1 video promocional", "Publicaciones permanentes", "Horarios de atención comercial", "Insignia Tienda / Local Oficial", "Fijado en carrusel superior", "Protección de escaparate"]'::jsonb,
        3,
        true
    )
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    price_monthly = EXCLUDED.price_monthly,
    max_active_items = EXCLUDED.max_active_items,
    max_images_per_item = EXCLUDED.max_images_per_item,
    allow_video = EXCLUDED.allow_video,
    auto_sponsor_items = EXCLUDED.auto_sponsor_items,
    hide_competitor_related = EXCLUDED.hide_competitor_related,
    default_badge_text = EXCLUDED.default_badge_text,
    features = EXCLUDED.features,
    sort_order = EXCLUDED.sort_order,
    is_active = EXCLUDED.is_active,
    updated_at = now();

-- =============================================================================
-- BLOQUE 4: FUNCIONES Y REGLAS DE NEGOCIO
-- =============================================================================

-- 4.1 Plan efectivo del vendedor (fallback seguro a 'free')
CREATE OR REPLACE FUNCTION public.get_effective_seller_plan(p_user_id uuid)
RETURNS public.marketplace_plans
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_profile public.seller_profiles;
    v_plan public.marketplace_plans;
BEGIN
    IF p_user_id IS NULL THEN
        SELECT * INTO v_plan FROM public.marketplace_plans WHERE id = 'free';
        RETURN v_plan;
    END IF;

    SELECT * INTO v_profile FROM public.seller_profiles WHERE user_id = p_user_id;

    -- Si no existe perfil o el plan contratado ha expirado, degrada a free
    IF NOT FOUND OR (v_profile.plan_expires_at IS NOT NULL AND v_profile.plan_expires_at <= now()) THEN
        SELECT * INTO v_plan FROM public.marketplace_plans WHERE id = 'free';
        RETURN v_plan;
    END IF;

    -- Obtener el plan del vendedor si está activo
    SELECT * INTO v_plan FROM public.marketplace_plans WHERE id = v_profile.plan_id AND is_active = true;

    IF NOT FOUND THEN
        SELECT * INTO v_plan FROM public.marketplace_plans WHERE id = 'free';
    END IF;

    RETURN v_plan;
END;
$$;

-- 4.2 Verificación de vendedor (estudiante verificado o comercio local aprobado)
CREATE OR REPLACE FUNCTION public.is_verified_seller(p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF p_user_id IS NULL THEN
        RETURN false;
    END IF;

    RETURN EXISTS (
        SELECT 1
        FROM public.profiles p
        WHERE p.id = p_user_id
          AND (p.is_verified = true OR p.seller_verification_status = 'verified')
    ) OR EXISTS (
        SELECT 1
        FROM public.seller_profiles sp
        WHERE sp.user_id = p_user_id
          AND sp.seller_type = 'local_business'
          AND sp.verification_status = 'approved'
    );
END;
$$;

-- 4.3 Detección preventiva de términos prohibidos y fraude académico
CREATE OR REPLACE FUNCTION public.marketplace_contains_prohibited_terms(p_text text)
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_norm text;
    v_term text;
    v_terms text[] := ARRAY[
        'hacer examenes',
        'hago examenes',
        'vender parcial',
        'vendo parcial',
        'resuelvo examen',
        'resolucion de examen',
        'suplantacion',
        'arma',
        'armas',
        'droga',
        'drogas',
        'marihuana',
        'cocaina',
        'estafa',
        'piramidal',
        'alcohol',
        'cerveza',
        'licor',
        'crack',
        'keygen',
        'dump sql',
        'contrasena wifi',
        'cuenta hackeada',
        'acceso ilegal'
    ];
BEGIN
    IF p_text IS NULL OR length(trim(p_text)) = 0 THEN
        RETURN NULL;
    END IF;

    -- Normalizar texto eliminando tildes y diéresis de forma portable sin unaccent
    v_norm := translate(lower(p_text), 'áéíóúüñÁÉÍÓÚÜÑ', 'aeiouunAEIOUUN');

    FOREACH v_term IN ARRAY v_terms LOOP
        -- Utilizar límites de palabra (\m..\M) para evitar falsos positivos
        IF v_norm ~ ('\m' || regexp_replace(v_term, '\s+', '\s+', 'g') || '\M') THEN
            RETURN v_term;
        END IF;
    END LOOP;

    RETURN NULL;
END;
$$;

-- 4.4 Trigger para aplicar reglas y cuotas al publicar o editar artículos
CREATE OR REPLACE FUNCTION public.enforce_marketplace_item_rules()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_caller uuid;
    v_jwt jsonb;
    v_role text;
    v_plan public.marketplace_plans;
    v_prohibited text;
    v_active_count integer;
    v_image_count integer;
BEGIN
    -- Bypass explícito para operaciones anidadas del sistema
    IF pg_trigger_depth() > 1 THEN
        RETURN NEW;
    END IF;

    v_caller := auth.uid();
    v_jwt := NULLIF(current_setting('request.jwt.claims', true), '')::jsonb;
    v_role := current_setting('role', true);

    -- Si no hay sesión o la llamada proviene de service_role / postgres, bypass
    IF v_caller IS NULL THEN
        RETURN NEW;
    END IF;

    IF v_jwt IS NOT NULL AND (v_jwt ->> 'role') IN ('service_role', 'supabase_admin') THEN
        RETURN NEW;
    END IF;

    IF v_role IN ('postgres', 'service_role', 'supabase_admin') THEN
        RETURN NEW;
    END IF;

    -- 1. Verificación de identidad obligatoria para publicar (solo INSERT)
    IF TG_OP = 'INSERT' THEN
        IF NOT public.is_verified_seller(NEW.user_id) THEN
            RAISE EXCEPTION 'Debes verificar tu identidad estudiantil con carné o contar con una cuenta comercial aprobada para publicar en el Marketplace'
                USING ERRCODE = '42501';
        END IF;
    END IF;

    -- Obtener plan efectivo del vendedor
    v_plan := public.get_effective_seller_plan(NEW.user_id);

    -- 2. Validaciones básicas de campos
    IF length(trim(COALESCE(NEW.title, ''))) < 4 THEN
        RAISE EXCEPTION 'El título de la publicación debe tener al menos 4 caracteres'
            USING ERRCODE = '23514';
    END IF;

    IF length(trim(COALESCE(NEW.description, ''))) < 10 THEN
        RAISE EXCEPTION 'La descripción de la publicación debe tener al menos 10 caracteres'
            USING ERRCODE = '23514';
    END IF;

    IF NEW.price IS NULL OR NEW.price < 0 THEN
        RAISE EXCEPTION 'El precio no puede ser negativo'
            USING ERRCODE = '23514';
    END IF;

    IF NEW.is_free = true THEN
        NEW.price := 0.00;
    END IF;

    -- 3. Al menos un canal de contacto directo al insertar
    IF TG_OP = 'INSERT' THEN
        IF NULLIF(trim(COALESCE(NEW.contact_whatsapp, '')), '') IS NULL
           AND NULLIF(trim(COALESCE(NEW.contact_telegram, '')), '') IS NULL
           AND NULLIF(trim(COALESCE(NEW.contact_instagram, '')), '') IS NULL
           AND NULLIF(trim(COALESCE(NEW.contact_messenger, '')), '') IS NULL THEN
            RAISE EXCEPTION 'Debes proporcionar al menos un canal de contacto directo (WhatsApp, Telegram, Instagram o Messenger)'
                USING ERRCODE = '23514';
        END IF;
    END IF;

    -- 4. Filtro semántico de términos prohibidos
    v_prohibited := public.marketplace_contains_prohibited_terms(
        COALESCE(NEW.title, '') || ' ' || COALESCE(NEW.description, '') || ' ' || COALESCE(NEW.video_url, '')
    );
    IF v_prohibited IS NOT NULL THEN
        RAISE EXCEPTION 'Tu publicación contiene términos restringidos ("%"). Por favor revisa las normas de convivencia y contenido académico.', v_prohibited
            USING ERRCODE = '23514';
    END IF;

    -- 5. Límite de imágenes por plan
    v_image_count := COALESCE(cardinality(NEW.image_urls), array_length(NEW.image_urls, 1), 0);
    IF v_plan.max_images_per_item > 0 AND v_image_count > v_plan.max_images_per_item THEN
        RAISE EXCEPTION 'Tu plan actual (%) permite un máximo de % imágenes por publicación (intentaste subir %)',
            v_plan.name, v_plan.max_images_per_item, v_image_count
            USING ERRCODE = '23514';
    END IF;

    -- 6. Validación de video según plan
    IF NULLIF(trim(COALESCE(NEW.video_url, '')), '') IS NOT NULL AND NOT v_plan.allow_video THEN
        RAISE EXCEPTION 'Tu plan actual (%) no permite incluir enlaces de video promocional en las publicaciones',
            v_plan.name
            USING ERRCODE = '23514';
    END IF;

    -- 7. Control de cupo de publicaciones activas (available / reserved)
    IF NEW.status IN ('available', 'reserved') THEN
        IF TG_OP = 'INSERT' OR (OLD.status NOT IN ('available', 'reserved')) OR (NEW.user_id IS DISTINCT FROM OLD.user_id) THEN
            IF v_plan.max_active_items > 0 THEN
                -- Serializa inserciones concurrentes del mismo vendedor para que
                -- el conteo de cupo no sufra carreras en READ COMMITTED.
                PERFORM pg_advisory_xact_lock(hashtext('marketplace_quota_' || NEW.user_id::text));

                SELECT count(*)
                INTO v_active_count
                FROM public.marketplace_items
                WHERE user_id = NEW.user_id
                  AND status IN ('available', 'reserved')
                  AND deleted_at IS NULL
                  AND id <> COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::uuid);

                IF v_active_count >= v_plan.max_active_items THEN
                    RAISE EXCEPTION 'Has alcanzado el límite de publicaciones activas permitidas para tu plan % (% activas). Pausa o marca como vendida alguna publicación antes de activar una nueva.',
                        v_plan.name, v_plan.max_active_items
                        USING ERRCODE = '23514';
                END IF;
            END IF;
        END IF;
    END IF;

    -- 8. Asignación de vigencia según plan
    IF v_plan.id = 'free' THEN
        IF TG_OP = 'INSERT'
           OR (NEW.status IN ('available', 'reserved') AND OLD.status NOT IN ('available', 'reserved')) THEN
            NEW.expires_at := now() + interval '14 days';
        ELSIF TG_OP = 'UPDATE' THEN
            -- La vigencia es inmutable para el cliente: no puede extenderse a mano.
            NEW.expires_at := OLD.expires_at;
        END IF;
    ELSE
        NEW.expires_at := NULL;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_zz_enforce_marketplace_item_rules ON public.marketplace_items;
CREATE TRIGGER trg_zz_enforce_marketplace_item_rules
    BEFORE INSERT OR UPDATE OF user_id, status, title, description, is_free, price,
                               image_urls, video_url, contact_whatsapp, contact_telegram,
                               contact_instagram, contact_messenger, expires_at
    ON public.marketplace_items
    FOR EACH ROW
    EXECUTE FUNCTION public.enforce_marketplace_item_rules();

-- 4.5 Protección e inmutabilidad de perfiles comerciales de vendedor
CREATE OR REPLACE FUNCTION public.guard_seller_profile_updates()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_caller uuid;
    v_jwt jsonb;
    v_is_service_role boolean;
    v_is_staff boolean;
    v_prohibited text;
BEGIN
    v_caller := auth.uid();
    v_jwt := NULLIF(current_setting('request.jwt.claims', true), '')::jsonb;

    v_is_service_role := (v_jwt IS NOT NULL AND (v_jwt ->> 'role') = 'service_role')
                         OR (current_setting('role', true) IN ('postgres', 'service_role', 'supabase_admin') AND v_caller IS NULL);

    v_is_staff := v_is_service_role
                  OR public.is_pemtree_admin(v_caller)
                  OR public.is_pemtree_moderator(v_caller);

    IF TG_OP = 'UPDATE' THEN
        -- public_id es estrictamente inmutable
        IF NEW.public_id IS DISTINCT FROM OLD.public_id THEN
            RAISE EXCEPTION 'El identificador público de tienda (public_id) es inmutable'
                USING ERRCODE = '42501';
        END IF;

        -- Usuarios normales no pueden alterar campos administrativos de suscripción
        IF NOT v_is_staff THEN
            IF (NEW.user_id IS DISTINCT FROM OLD.user_id)
               OR (NEW.plan_id IS DISTINCT FROM OLD.plan_id)
               OR (NEW.seller_type IS DISTINCT FROM OLD.seller_type)
               OR (NEW.verification_status IS DISTINCT FROM OLD.verification_status)
               OR (NEW.plan_expires_at IS DISTINCT FROM OLD.plan_expires_at) THEN
                RAISE EXCEPTION 'No tienes privilegios para modificar campos administrativos o de suscripción del perfil de vendedor'
                    USING ERRCODE = '42501';
            END IF;
        END IF;
    ELSIF TG_OP = 'INSERT' THEN
        -- Si un usuario estándar inserta directamente, forzar valores base seguros
        IF NOT v_is_staff THEN
            NEW.plan_id := 'free';
            NEW.seller_type := 'student';
            NEW.verification_status := 'pending';
            NEW.plan_expires_at := NULL;
        END IF;
    END IF;

    -- Filtro semántico sobre nombre y descripción comercial
    v_prohibited := public.marketplace_contains_prohibited_terms(
        COALESCE(NEW.business_name, '') || ' ' || COALESCE(NEW.business_description, '')
    );
    IF v_prohibited IS NOT NULL THEN
        RAISE EXCEPTION 'El perfil comercial contiene términos restringidos ("%")', v_prohibited
            USING ERRCODE = '23514';
    END IF;

    -- La presencia en campus es exclusiva de planes de pago tipo emprendedor.
    IF NOT v_is_staff THEN
        IF NEW.plan_id = 'free' OR NEW.seller_type = 'local_business' THEN
            NEW.is_currently_on_campus := false;
            NEW.current_building_code := NULL;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_seller_profile_updates ON public.seller_profiles;
CREATE TRIGGER trg_guard_seller_profile_updates
    BEFORE INSERT OR UPDATE ON public.seller_profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.guard_seller_profile_updates();

-- 4.5.b Perfil público de tienda automático para todo vendedor del Marketplace.
-- Garantiza que cada publicación tenga un seller_public_id estable sin exponer user_id.
CREATE OR REPLACE FUNCTION public.ensure_seller_profile_for_item()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF NEW.user_id IS NOT NULL THEN
        INSERT INTO public.seller_profiles (user_id)
        VALUES (NEW.user_id)
        ON CONFLICT (user_id) DO NOTHING;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_ensure_seller_profile_marketplace_items ON public.marketplace_items;
CREATE TRIGGER trg_ensure_seller_profile_marketplace_items
    AFTER INSERT ON public.marketplace_items
    FOR EACH ROW
    EXECUTE FUNCTION public.ensure_seller_profile_for_item();

-- Backfill de vendedores existentes (idempotente)
INSERT INTO public.seller_profiles (user_id)
SELECT DISTINCT mi.user_id
FROM public.marketplace_items mi
WHERE mi.user_id IS NOT NULL
ON CONFLICT (user_id) DO NOTHING;

-- 4.6.b Blindaje del flujo de solicitudes de patrocinio.
-- En instalaciones limpias ya existe; se recrea para garantizar el mismo
-- comportamiento en bases con drift. Un usuario solo puede crear su solicitud
-- en estado pending y nunca puede revisarla.
CREATE OR REPLACE FUNCTION public.guard_sponsor_request_workflow()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF auth.uid() IS NOT NULL AND auth.role() <> 'service_role' THEN
            IF NEW.user_id IS NULL THEN
                NEW.user_id := auth.uid();
            ELSIF NEW.user_id IS DISTINCT FROM auth.uid() THEN
                RAISE EXCEPTION 'No puedes crear una solicitud de patrocinio a nombre de otro usuario'
                    USING ERRCODE = '42501';
            END IF;

            IF NEW.status IS DISTINCT FROM 'pending' THEN
                RAISE EXCEPTION 'Las solicitudes de patrocinio solo pueden crearse en estado pending'
                    USING ERRCODE = '42501';
            END IF;
        END IF;
        RETURN NEW;
    END IF;

    IF auth.uid() IS NOT NULL
       AND auth.role() IS DISTINCT FROM 'service_role'
       AND NOT public.is_pemtree_admin(auth.uid())
       AND (NEW.status IS DISTINCT FROM OLD.status OR NEW.user_id IS DISTINCT FROM OLD.user_id) THEN
        RAISE EXCEPTION 'Only admins may review sponsor requests.'
            USING ERRCODE = '42501';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS guard_sponsor_request_workflow ON public.sponsor_requests;
CREATE TRIGGER guard_sponsor_request_workflow
    BEFORE INSERT OR UPDATE ON public.sponsor_requests
    FOR EACH ROW
    EXECUTE FUNCTION public.guard_sponsor_request_workflow();

-- 4.6 Gestión de resolución de solicitudes de patrocinio / cuenta comercial
CREATE OR REPLACE FUNCTION public.handle_sponsor_request_decision()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_target_plan text;
    v_seller_type text;
BEGIN
    IF pg_trigger_depth() > 1 THEN
        RETURN NEW;
    END IF;

    IF NEW.status = 'approved' AND OLD.status IS DISTINCT FROM 'approved' THEN
        v_target_plan := COALESCE(NEW.plan_id, 'pro_student');
        v_seller_type := CASE WHEN v_target_plan = 'business_local' THEN 'local_business' ELSE 'student' END;

        IF NEW.user_id IS NOT NULL THEN
            INSERT INTO public.seller_profiles (
                user_id,
                plan_id,
                seller_type,
                verification_status,
                business_name,
                plan_expires_at,
                created_at,
                updated_at
            ) VALUES (
                NEW.user_id,
                v_target_plan,
                v_seller_type,
                'approved',
                NEW.brand_name,
                now() + interval '30 days',
                now(),
                now()
            )
            ON CONFLICT (user_id) DO UPDATE SET
                plan_id = EXCLUDED.plan_id,
                seller_type = EXCLUDED.seller_type,
                verification_status = 'approved',
                business_name = COALESCE(public.seller_profiles.business_name, EXCLUDED.business_name),
                plan_expires_at = now() + interval '30 days',
                updated_at = now();
        END IF;

        UPDATE public.sponsor_requests
        SET reviewed_by = COALESCE(NEW.reviewed_by, auth.uid()),
            reviewed_at = now()
        WHERE id = NEW.id
          AND (reviewed_at IS NULL OR reviewed_by IS NULL);

    ELSIF NEW.status = 'rejected' AND OLD.status IS DISTINCT FROM 'rejected' THEN
        UPDATE public.sponsor_requests
        SET reviewed_by = COALESCE(NEW.reviewed_by, auth.uid()),
            reviewed_at = now()
        WHERE id = NEW.id
          AND reviewed_at IS NULL;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_handle_sponsor_request_decision ON public.sponsor_requests;
CREATE TRIGGER trg_handle_sponsor_request_decision
    AFTER UPDATE OF status ON public.sponsor_requests
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_sponsor_request_decision();

-- =============================================================================
-- BLOQUE 5: RECONCILIACIÓN DE CUPOS Y VIGENCIA (CRON / AUTOMATIZACIÓN)
-- =============================================================================

-- 5.1 Reconciliar cupo excedente por plan efectivo de un vendedor
CREATE OR REPLACE FUNCTION public.reconcile_seller_plan_limits(p_user_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_plan public.marketplace_plans;
    v_paused_count integer := 0;
BEGIN
    IF p_user_id IS NULL THEN
        RETURN 0;
    END IF;

    v_plan := public.get_effective_seller_plan(p_user_id);

    -- Si el plan tiene publicaciones ilimitadas (0), no se pausa nada
    IF v_plan.max_active_items = 0 THEN
        RETURN 0;
    END IF;

    WITH active_items AS (
        SELECT id,
               ROW_NUMBER() OVER (ORDER BY created_at DESC, id DESC) AS rn
        FROM public.marketplace_items
        WHERE user_id = p_user_id
          AND status IN ('available', 'reserved')
          AND deleted_at IS NULL
    ),
    items_to_pause AS (
        SELECT id FROM active_items WHERE rn > v_plan.max_active_items
    ),
    updated AS (
        UPDATE public.marketplace_items
        SET status = 'paused',
            updated_at = now()
        WHERE id IN (SELECT id FROM items_to_pause)
        RETURNING id
    )
    SELECT count(*)::integer INTO v_paused_count FROM updated;

    RETURN v_paused_count;
END;
$$;

-- 5.2 Pausa de publicaciones vencidas y degradación de planes expirados
CREATE OR REPLACE FUNCTION public.pause_expired_marketplace_items()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_expired_paused integer := 0;
    v_quota_paused integer := 0;
    r_seller record;
BEGIN
    -- 1. Degradar perfiles de vendedores de pago vencidos a 'free'
    UPDATE public.seller_profiles
    SET plan_id = 'free',
        plan_expires_at = NULL,
        updated_at = now()
    WHERE plan_expires_at IS NOT NULL
      AND plan_expires_at <= now()
      AND plan_id <> 'free';

    -- 2. Pausar publicaciones de vendedores 'free' que superaron su vigencia (14 días)
    WITH expired_free_items AS (
        SELECT mi.id
        FROM public.marketplace_items mi
        LEFT JOIN public.seller_profiles sp ON sp.user_id = mi.user_id
        WHERE mi.status IN ('available', 'reserved')
          AND mi.deleted_at IS NULL
          AND mi.expires_at IS NOT NULL
          AND mi.expires_at <= now()
          AND (sp.plan_id IS NULL OR sp.plan_id = 'free' OR (sp.plan_expires_at IS NOT NULL AND sp.plan_expires_at <= now()))
    ),
    paused_rows AS (
        UPDATE public.marketplace_items
        SET status = 'paused',
            updated_at = now()
        WHERE id IN (SELECT id FROM expired_free_items)
        RETURNING id
    )
    SELECT count(*)::integer INTO v_expired_paused FROM paused_rows;

    -- 3. Reconciliar cupo para vendedores 'free' con más de 3 publicaciones activas
    FOR r_seller IN
        SELECT mi.user_id
        FROM public.marketplace_items mi
        LEFT JOIN public.seller_profiles sp ON sp.user_id = mi.user_id
        WHERE mi.status IN ('available', 'reserved')
          AND mi.deleted_at IS NULL
          AND (sp.plan_id IS NULL OR sp.plan_id = 'free' OR (sp.plan_expires_at IS NOT NULL AND sp.plan_expires_at <= now()))
        GROUP BY mi.user_id
        HAVING count(*) > 3
    LOOP
        v_quota_paused := v_quota_paused + public.reconcile_seller_plan_limits(r_seller.user_id);
    END LOOP;

    RETURN v_expired_paused + v_quota_paused;
END;
$$;

-- =============================================================================
-- BLOQUE 6: TELEMETRÍA, ANALÍTICAS Y ESTADO DEL VENDEDOR
-- =============================================================================

-- 6.1 Registro no bloqueante de eventos con deduplicación por ventana
CREATE OR REPLACE FUNCTION public.track_marketplace_event(p_item_id uuid, p_event_type text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_item_owner uuid;
    v_viewer uuid;
BEGIN
    -- Validar parámetros de entrada
    IF p_item_id IS NULL OR p_event_type NOT IN ('view', 'click_whatsapp', 'click_telegram', 'click_instagram', 'click_messenger', 'share') THEN
        RETURN false;
    END IF;

    -- Comprobar existencia del ítem y su propietario
    SELECT user_id INTO v_item_owner
    FROM public.marketplace_items
    WHERE id = p_item_id AND deleted_at IS NULL;

    IF NOT FOUND THEN
        RETURN false;
    END IF;

    v_viewer := auth.uid();

    -- Descartar auto-visitas del propio autor
    IF p_event_type = 'view' AND v_viewer IS NOT NULL AND v_item_owner = v_viewer THEN
        RETURN true;
    END IF;

    -- Deduplicar 'view' del mismo usuario en ventana de 30 minutos
    IF p_event_type = 'view' AND v_viewer IS NOT NULL THEN
        IF EXISTS (
            SELECT 1
            FROM public.marketplace_item_events
            WHERE item_id = p_item_id
              AND viewer_id = v_viewer
              AND event_type = 'view'
              AND created_at >= (now() - interval '30 minutes')
        ) THEN
            RETURN true;
        END IF;
    END IF;

    -- Si el evento es 'share', incrementar el contador de compartidos del ítem
    IF p_event_type = 'share' THEN
        UPDATE public.marketplace_items
        SET shares_count = shares_count + 1
        WHERE id = p_item_id;
    END IF;

    -- Insertar evento con viewer_id verificado por sesión
    INSERT INTO public.marketplace_item_events (item_id, viewer_id, event_type, created_at)
    VALUES (p_item_id, v_viewer, p_event_type, now());

    RETURN true;
EXCEPTION
    WHEN OTHERS THEN
        RETURN false;
END;
$$;

-- 6.2 Métricas agregadas y anónimas del vendedor
CREATE OR REPLACE FUNCTION public.get_marketplace_metrics(p_days integer DEFAULT 7)
RETURNS TABLE (
    item_id uuid,
    title text,
    views bigint,
    click_whatsapp bigint,
    click_telegram bigint,
    click_instagram bigint,
    click_messenger bigint,
    shares bigint,
    contact_rate numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_caller uuid;
    v_days integer;
    v_since timestamptz;
BEGIN
    v_caller := auth.uid();
    IF v_caller IS NULL THEN
        RETURN;
    END IF;

    v_days := LEAST(GREATEST(COALESCE(p_days, 7), 1), 90);
    v_since := now() - (v_days || ' days')::interval;

    RETURN QUERY
    SELECT
        mi.id AS item_id,
        mi.title,
        COALESCE(COUNT(e.id) FILTER (WHERE e.event_type = 'view'), 0)::bigint AS views,
        COALESCE(COUNT(e.id) FILTER (WHERE e.event_type = 'click_whatsapp'), 0)::bigint AS click_whatsapp,
        COALESCE(COUNT(e.id) FILTER (WHERE e.event_type = 'click_telegram'), 0)::bigint AS click_telegram,
        COALESCE(COUNT(e.id) FILTER (WHERE e.event_type = 'click_instagram'), 0)::bigint AS click_instagram,
        COALESCE(COUNT(e.id) FILTER (WHERE e.event_type = 'click_messenger'), 0)::bigint AS click_messenger,
        COALESCE(COUNT(e.id) FILTER (WHERE e.event_type = 'share'), 0)::bigint AS shares,
        ROUND(
            (
                COALESCE(COUNT(e.id) FILTER (WHERE e.event_type IN ('click_whatsapp', 'click_telegram', 'click_instagram', 'click_messenger')), 0)::numeric
                / NULLIF(COUNT(e.id) FILTER (WHERE e.event_type = 'view'), 0)::numeric
            ),
            4
        ) AS contact_rate
    FROM public.marketplace_items mi
    LEFT JOIN public.marketplace_item_events e
        ON e.item_id = mi.id
       AND e.created_at >= v_since
    WHERE mi.user_id = v_caller
      AND mi.deleted_at IS NULL
    GROUP BY mi.id, mi.title, mi.created_at
    ORDER BY views DESC, mi.created_at DESC;
END;
$$;

-- 6.3 Resumen de estado de vendedor y límites para la sesión actual
CREATE OR REPLACE FUNCTION public.get_my_marketplace_status()
RETURNS TABLE (
    can_publish boolean,
    reason text,
    plan_id text,
    plan_name text,
    max_active_items integer,
    max_images_per_item integer,
    allow_video boolean,
    active_items integer,
    remaining_slots integer,
    expires_at timestamptz,
    seller_public_id uuid,
    seller_type text,
    verification_status text,
    is_verified boolean,
    is_on_campus boolean,
    current_building_code text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_uid uuid;
    v_plan public.marketplace_plans;
    v_is_verified boolean;
    v_active_count integer;
    v_seller_public_id uuid := NULL;
    v_seller_type text := 'student';
    v_verification_status text := 'pending';
    v_is_on_campus boolean := false;
    v_current_building_code text := NULL;
    v_plan_expires_at timestamptz := NULL;
    v_can_pub boolean;
    v_reason text;
    v_slots integer;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RETURN QUERY
        SELECT
            false,
            'Inicia sesión para consultar tu estado de vendedor en el Marketplace.'::text,
            'free'::text,
            'Estudiante'::text,
            3,
            2,
            false,
            0,
            3,
            NULL::timestamptz,
            NULL::uuid,
            'student'::text,
            'pending'::text,
            false,
            false,
            NULL::text;
        RETURN;
    END IF;

    v_plan := public.get_effective_seller_plan(v_uid);
    v_is_verified := public.is_verified_seller(v_uid);

    SELECT
        sp.public_id,
        sp.seller_type,
        sp.verification_status,
        sp.is_currently_on_campus,
        sp.current_building_code,
        sp.plan_expires_at
    INTO
        v_seller_public_id,
        v_seller_type,
        v_verification_status,
        v_is_on_campus,
        v_current_building_code,
        v_plan_expires_at
    FROM public.seller_profiles sp
    WHERE sp.user_id = v_uid;

    IF v_seller_public_id IS NULL THEN
        v_seller_type := 'student';
        v_verification_status := CASE WHEN v_is_verified THEN 'approved' ELSE 'pending' END;
    END IF;

    SELECT COUNT(*)::integer
    INTO v_active_count
    FROM public.marketplace_items
    WHERE user_id = v_uid
      AND status IN ('available', 'reserved')
      AND deleted_at IS NULL;

    IF NOT v_is_verified THEN
        v_can_pub := false;
        v_reason := 'Debes verificar tu carné estudiantil o contar con una cuenta comercial aprobada para publicar.';
    ELSIF v_plan.max_active_items > 0 AND v_active_count >= v_plan.max_active_items THEN
        v_can_pub := false;
        v_reason := 'Has alcanzado el límite de publicaciones activas para tu plan (' || v_plan.name || ').';
    ELSE
        v_can_pub := true;
        v_reason := 'OK';
    END IF;

    v_slots := CASE WHEN v_plan.max_active_items = 0 THEN NULL ELSE GREATEST(v_plan.max_active_items - v_active_count, 0) END;

    RETURN QUERY
    SELECT
        v_can_pub,
        v_reason,
        v_plan.id,
        v_plan.name,
        v_plan.max_active_items,
        v_plan.max_images_per_item,
        v_plan.allow_video,
        v_active_count,
        v_slots,
        v_plan_expires_at,
        v_seller_public_id,
        v_seller_type,
        v_verification_status,
        v_is_verified,
        v_is_on_campus,
        v_current_building_code;
END;
$$;

-- =============================================================================
-- BLOQUE 7: RPCs DEL MARKETPLACE (FEED, DETALLE, CATÁLOGO Y RELACIONADOS)
-- =============================================================================

-- 7.1 Feed principal ponderado y filtrado
CREATE OR REPLACE FUNCTION public.get_marketplace_feed(
    p_sede text DEFAULT NULL,
    p_facultad text DEFAULT NULL,
    p_building_code text DEFAULT NULL,
    p_category text DEFAULT NULL,
    p_search text DEFAULT NULL,
    p_only_free boolean DEFAULT false,
    p_sponsored_only boolean DEFAULT false,
    p_limit integer DEFAULT 20,
    p_offset integer DEFAULT 0
)
RETURNS TABLE (
    id uuid,
    title text,
    description text,
    price numeric,
    is_free boolean,
    category text,
    facultad text,
    sede text,
    building_code text,
    location_detail text,
    contact_whatsapp text,
    contact_telegram text,
    contact_instagram text,
    contact_messenger text,
    social_links text[],
    image_urls text[],
    video_url text,
    is_sponsored boolean,
    sponsor_badge_text text,
    author_alias text,
    upvotes integer,
    reported_count integer,
    shares_count integer,
    moderation_status integer,
    status text,
    created_at timestamptz,
    updated_at timestamptz,
    expires_at timestamptz,
    is_legal_hold boolean,
    seller_public_id uuid,
    seller_business_name text,
    seller_plan_id text,
    seller_plan_name text,
    seller_badge_text text,
    seller_is_verified boolean,
    seller_is_on_campus boolean,
    seller_building_code text,
    is_mine boolean,
    is_upvoted_by_me boolean,
    is_bookmarked_by_me boolean,
    score numeric,
    is_hidden boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_norm_search text;
    v_limit integer;
    v_offset integer;
    v_caller uuid;
BEGIN
    v_caller := auth.uid();
    v_offset := GREATEST(COALESCE(p_offset, 0), 0);
    IF p_sponsored_only THEN
        v_limit := LEAST(COALESCE(p_limit, 5), 5);
    ELSE
        v_limit := LEAST(GREATEST(COALESCE(p_limit, 20), 1), 100);
    END IF;

    IF p_search IS NOT NULL AND length(trim(p_search)) > 0 THEN
        v_norm_search := translate(lower(trim(p_search)), 'áéíóúüñÁÉÍÓÚÜÑ', 'aeiouunAEIOUUN');
    ELSE
        v_norm_search := NULL;
    END IF;

    RETURN QUERY
    SELECT
        mi.id,
        mi.title,
        mi.description,
        mi.price,
        mi.is_free,
        mi.category,
        mi.facultad,
        mi.sede,
        mi.building_code,
        mi.location_detail,
        mi.contact_whatsapp,
        mi.contact_telegram,
        mi.contact_instagram,
        mi.contact_messenger,
        mi.social_links,
        mi.image_urls,
        mi.video_url,
        (mi.is_sponsored OR COALESCE(plan.auto_sponsor_items, false)) AS is_sponsored,
        mi.sponsor_badge_text,
        mi.author_alias,
        mi.upvotes,
        mi.reported_count,
        mi.shares_count,
        mi.moderation_status,
        mi.status,
        mi.created_at,
        mi.updated_at,
        mi.expires_at,
        mi.is_legal_hold,
        sp.public_id AS seller_public_id,
        sp.business_name AS seller_business_name,
        COALESCE(plan.id, 'free') AS seller_plan_id,
        COALESCE(plan.name, 'Estudiante') AS seller_plan_name,
        CASE WHEN public.is_verified_seller(mi.user_id) THEN COALESCE(plan.default_badge_text, mi.sponsor_badge_text) ELSE NULL END AS seller_badge_text,
        public.is_verified_seller(mi.user_id) AS seller_is_verified,
        COALESCE(sp.is_currently_on_campus, false) AS seller_is_on_campus,
        sp.current_building_code AS seller_building_code,
        (v_caller IS NOT NULL AND mi.user_id = v_caller) AS is_mine,
        (v_caller IS NOT NULL AND EXISTS (
            SELECT 1 FROM public.marketplace_upvotes mu
            WHERE mu.item_id = mi.id AND mu.user_id = v_caller
        )) AS is_upvoted_by_me,
        (v_caller IS NOT NULL AND EXISTS (
            SELECT 1 FROM public.marketplace_bookmarks mb
            WHERE mb.item_id = mi.id AND mb.user_id = v_caller
        )) AS is_bookmarked_by_me,
        ROUND(
            (
                mi.upvotes
                + CASE WHEN (mi.is_sponsored OR COALESCE(plan.auto_sponsor_items, false)) THEN 15.0 ELSE 0.0 END
                + CASE WHEN COALESCE(sp.is_currently_on_campus, false) THEN 8.0 ELSE 0.0 END
            )::numeric
            / POWER(
                GREATEST(EXTRACT(EPOCH FROM (now() - mi.created_at)) / 3600.0, 0.5) + 2.0,
                1.5
            )::numeric,
            6
        ) AS score,
        (mi.moderation_status IN (2, 3)) AS is_hidden
    FROM public.marketplace_items mi
    LEFT JOIN public.seller_profiles sp ON sp.user_id = mi.user_id
    LEFT JOIN public.marketplace_plans plan ON plan.id = (
        CASE
            WHEN sp.user_id IS NULL THEN 'free'
            WHEN sp.plan_expires_at IS NOT NULL AND sp.plan_expires_at <= now() THEN 'free'
            ELSE sp.plan_id
        END
    )
    WHERE mi.status IN ('available', 'reserved')
      AND mi.deleted_at IS NULL
      AND (mi.expires_at IS NULL OR mi.expires_at > now())
      AND (
          mi.moderation_status IN (0, 1)
          OR (v_caller IS NOT NULL AND (
              mi.user_id = v_caller
              OR public.is_pemtree_admin(v_caller)
              OR public.is_pemtree_moderator(v_caller)
          ))
      )
      AND (p_sede IS NULL OR mi.sede = p_sede)
      AND (p_facultad IS NULL OR mi.facultad = p_facultad)
      AND (p_building_code IS NULL OR mi.building_code = p_building_code)
      AND (p_category IS NULL OR mi.category = p_category)
      AND (NOT p_only_free OR mi.is_free = true)
      AND (NOT p_sponsored_only OR (mi.is_sponsored = true OR COALESCE(plan.auto_sponsor_items, false) = true))
      AND (
          v_norm_search IS NULL
          OR translate(lower(mi.title), 'áéíóúüñÁÉÍÓÚÜÑ', 'aeiouunAEIOUUN') LIKE ('%' || v_norm_search || '%')
          OR translate(lower(mi.description), 'áéíóúüñÁÉÍÓÚÜÑ', 'aeiouunAEIOUUN') LIKE ('%' || v_norm_search || '%')
          OR translate(lower(COALESCE(mi.building_code, '')), 'áéíóúüñÁÉÍÓÚÜÑ', 'aeiouunAEIOUUN') LIKE ('%' || v_norm_search || '%')
      )
    ORDER BY
        CASE WHEN p_sponsored_only THEN
            CASE plan.id WHEN 'business_local' THEN 0 WHEN 'pro_student' THEN 1 ELSE 2 END
        ELSE 0 END ASC,
        score DESC,
        mi.upvotes DESC,
        mi.created_at DESC,
        mi.id DESC
    LIMIT v_limit
    OFFSET v_offset;
END;
$$;

-- 7.2 Ficha de detalle de producto con contexto completo de tienda
CREATE OR REPLACE FUNCTION public.get_marketplace_item_detail(p_item_id uuid)
RETURNS TABLE (
    id uuid,
    title text,
    description text,
    price numeric,
    is_free boolean,
    category text,
    facultad text,
    sede text,
    building_code text,
    location_detail text,
    contact_whatsapp text,
    contact_telegram text,
    contact_instagram text,
    contact_messenger text,
    social_links text[],
    image_urls text[],
    video_url text,
    is_sponsored boolean,
    sponsor_badge_text text,
    author_alias text,
    upvotes integer,
    reported_count integer,
    shares_count integer,
    moderation_status integer,
    status text,
    created_at timestamptz,
    updated_at timestamptz,
    expires_at timestamptz,
    is_legal_hold boolean,
    seller_public_id uuid,
    seller_business_name text,
    seller_plan_id text,
    seller_plan_name text,
    seller_badge_text text,
    seller_is_verified boolean,
    seller_is_on_campus boolean,
    seller_building_code text,
    is_mine boolean,
    is_upvoted_by_me boolean,
    is_bookmarked_by_me boolean,
    score numeric,
    is_hidden boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_caller uuid;
BEGIN
    v_caller := auth.uid();

    RETURN QUERY
    SELECT
        mi.id,
        mi.title,
        mi.description,
        mi.price,
        mi.is_free,
        mi.category,
        mi.facultad,
        mi.sede,
        mi.building_code,
        mi.location_detail,
        mi.contact_whatsapp,
        mi.contact_telegram,
        mi.contact_instagram,
        mi.contact_messenger,
        mi.social_links,
        mi.image_urls,
        mi.video_url,
        (mi.is_sponsored OR COALESCE(plan.auto_sponsor_items, false)) AS is_sponsored,
        mi.sponsor_badge_text,
        mi.author_alias,
        mi.upvotes,
        mi.reported_count,
        mi.shares_count,
        mi.moderation_status,
        mi.status,
        mi.created_at,
        mi.updated_at,
        mi.expires_at,
        mi.is_legal_hold,
        sp.public_id AS seller_public_id,
        sp.business_name AS seller_business_name,
        COALESCE(plan.id, 'free') AS seller_plan_id,
        COALESCE(plan.name, 'Estudiante') AS seller_plan_name,
        CASE WHEN public.is_verified_seller(mi.user_id) THEN COALESCE(plan.default_badge_text, mi.sponsor_badge_text) ELSE NULL END AS seller_badge_text,
        public.is_verified_seller(mi.user_id) AS seller_is_verified,
        COALESCE(sp.is_currently_on_campus, false) AS seller_is_on_campus,
        sp.current_building_code AS seller_building_code,
        (v_caller IS NOT NULL AND mi.user_id = v_caller) AS is_mine,
        (v_caller IS NOT NULL AND EXISTS (
            SELECT 1 FROM public.marketplace_upvotes mu
            WHERE mu.item_id = mi.id AND mu.user_id = v_caller
        )) AS is_upvoted_by_me,
        (v_caller IS NOT NULL AND EXISTS (
            SELECT 1 FROM public.marketplace_bookmarks mb
            WHERE mb.item_id = mi.id AND mb.user_id = v_caller
        )) AS is_bookmarked_by_me,
        ROUND(
            (
                mi.upvotes
                + CASE WHEN (mi.is_sponsored OR COALESCE(plan.auto_sponsor_items, false)) THEN 15.0 ELSE 0.0 END
                + CASE WHEN COALESCE(sp.is_currently_on_campus, false) THEN 8.0 ELSE 0.0 END
            )::numeric
            / POWER(
                GREATEST(EXTRACT(EPOCH FROM (now() - mi.created_at)) / 3600.0, 0.5) + 2.0,
                1.5
            )::numeric,
            6
        ) AS score,
        (mi.moderation_status IN (2, 3) OR (mi.expires_at IS NOT NULL AND mi.expires_at <= now())) AS is_hidden
    FROM public.marketplace_items mi
    LEFT JOIN public.seller_profiles sp ON sp.user_id = mi.user_id
    LEFT JOIN public.marketplace_plans plan ON plan.id = (
        CASE
            WHEN sp.user_id IS NULL THEN 'free'
            WHEN sp.plan_expires_at IS NOT NULL AND sp.plan_expires_at <= now() THEN 'free'
            ELSE sp.plan_id
        END
    )
    WHERE mi.id = p_item_id
      AND mi.deleted_at IS NULL
      AND (
          mi.moderation_status IN (0, 1)
          OR (v_caller IS NOT NULL AND (
              mi.user_id = v_caller
              OR public.is_pemtree_admin(v_caller)
              OR public.is_pemtree_moderator(v_caller)
          ))
      );
END;
$$;

-- 7.3 Perfil público de tienda (anon/auth sin exponer user_id)
CREATE OR REPLACE FUNCTION public.get_seller_public_profile(p_seller_public_id uuid)
RETURNS TABLE (
    public_id uuid,
    display_name text,
    business_name text,
    business_description text,
    business_logo_url text,
    business_banner_url text,
    business_hours jsonb,
    seller_type text,
    plan_id text,
    plan_name text,
    badge_text text,
    is_verified boolean,
    is_on_campus boolean,
    current_building_code text,
    current_location_note text,
    member_since timestamptz,
    active_items bigint,
    is_my_store boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_target_user uuid;
    v_plan public.marketplace_plans;
    v_latest_alias text;
BEGIN
    SELECT sp.user_id INTO v_target_user
    FROM public.seller_profiles sp
    WHERE sp.public_id = p_seller_public_id;

    IF v_target_user IS NULL THEN
        RETURN;
    END IF;

    v_plan := public.get_effective_seller_plan(v_target_user);

    SELECT mi.author_alias INTO v_latest_alias
    FROM public.marketplace_items mi
    WHERE mi.user_id = v_target_user
      AND mi.deleted_at IS NULL
    ORDER BY mi.created_at DESC
    LIMIT 1;

    RETURN QUERY
    SELECT
        sp.public_id,
        COALESCE(NULLIF(trim(sp.business_name), ''), v_latest_alias, 'Estudiante Emprendedor') AS display_name,
        sp.business_name,
        sp.business_description,
        sp.business_logo_url,
        sp.business_banner_url,
        sp.business_hours,
        sp.seller_type,
        v_plan.id AS plan_id,
        v_plan.name AS plan_name,
        CASE WHEN public.is_verified_seller(v_target_user) THEN v_plan.default_badge_text ELSE NULL END AS badge_text,
        public.is_verified_seller(v_target_user) AS is_verified,
        sp.is_currently_on_campus,
        sp.current_building_code,
        sp.current_location_note,
        sp.created_at AS member_since,
        COALESCE((
            SELECT COUNT(*)
            FROM public.marketplace_items mi
            WHERE mi.user_id = v_target_user
              AND mi.status IN ('available', 'reserved')
              AND mi.deleted_at IS NULL
              AND mi.moderation_status IN (0, 1)
              AND (mi.expires_at IS NULL OR mi.expires_at > now())
        ), 0)::bigint AS active_items,
        (auth.uid() IS NOT NULL AND v_target_user = auth.uid()) AS is_my_store
    FROM public.seller_profiles sp
    WHERE sp.user_id = v_target_user;
END;
$$;

-- 7.4 Catálogo del mismo vendedor ("Más productos de...")
CREATE OR REPLACE FUNCTION public.get_seller_catalog(
    p_seller_public_id uuid,
    p_exclude_item_id uuid DEFAULT NULL,
    p_limit integer DEFAULT 20,
    p_offset integer DEFAULT 0
)
RETURNS TABLE (
    id uuid,
    title text,
    description text,
    price numeric,
    is_free boolean,
    category text,
    facultad text,
    sede text,
    building_code text,
    location_detail text,
    contact_whatsapp text,
    contact_telegram text,
    contact_instagram text,
    contact_messenger text,
    social_links text[],
    image_urls text[],
    video_url text,
    is_sponsored boolean,
    sponsor_badge_text text,
    author_alias text,
    upvotes integer,
    reported_count integer,
    shares_count integer,
    moderation_status integer,
    status text,
    created_at timestamptz,
    updated_at timestamptz,
    expires_at timestamptz,
    is_legal_hold boolean,
    is_mine boolean,
    is_upvoted_by_me boolean,
    is_bookmarked_by_me boolean,
    score numeric,
    is_hidden boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_seller_user_id uuid;
    v_limit integer;
    v_offset integer;
    v_caller uuid;
BEGIN
    v_caller := auth.uid();
    v_limit := LEAST(GREATEST(COALESCE(p_limit, 20), 1), 100);
    v_offset := GREATEST(COALESCE(p_offset, 0), 0);

    -- Resolver el user_id a partir del public_id seguro
    SELECT sp.user_id INTO v_seller_user_id
    FROM public.seller_profiles sp
    WHERE sp.public_id = p_seller_public_id;

    IF v_seller_user_id IS NULL THEN
        -- Fallback de compatibilidad si se proporciona user_id
        IF EXISTS (SELECT 1 FROM public.marketplace_items WHERE user_id = p_seller_public_id) THEN
            v_seller_user_id := p_seller_public_id;
        ELSE
            RETURN;
        END IF;
    END IF;

    RETURN QUERY
    SELECT
        mi.id,
        mi.title,
        mi.description,
        mi.price,
        mi.is_free,
        mi.category,
        mi.facultad,
        mi.sede,
        mi.building_code,
        mi.location_detail,
        mi.contact_whatsapp,
        mi.contact_telegram,
        mi.contact_instagram,
        mi.contact_messenger,
        mi.social_links,
        mi.image_urls,
        mi.video_url,
        (mi.is_sponsored OR COALESCE(plan.auto_sponsor_items, false)) AS is_sponsored,
        mi.sponsor_badge_text,
        mi.author_alias,
        mi.upvotes,
        mi.reported_count,
        mi.shares_count,
        mi.moderation_status,
        mi.status,
        mi.created_at,
        mi.updated_at,
        mi.expires_at,
        mi.is_legal_hold,
        (v_caller IS NOT NULL AND mi.user_id = v_caller) AS is_mine,
        (v_caller IS NOT NULL AND EXISTS (
            SELECT 1 FROM public.marketplace_upvotes mu
            WHERE mu.item_id = mi.id AND mu.user_id = v_caller
        )) AS is_upvoted_by_me,
        (v_caller IS NOT NULL AND EXISTS (
            SELECT 1 FROM public.marketplace_bookmarks mb
            WHERE mb.item_id = mi.id AND mb.user_id = v_caller
        )) AS is_bookmarked_by_me,
        ROUND(
            (
                mi.upvotes
                + CASE WHEN (mi.is_sponsored OR COALESCE(plan.auto_sponsor_items, false)) THEN 15.0 ELSE 0.0 END
                + CASE WHEN COALESCE(sp.is_currently_on_campus, false) THEN 8.0 ELSE 0.0 END
            )::numeric
            / POWER(
                GREATEST(EXTRACT(EPOCH FROM (now() - mi.created_at)) / 3600.0, 0.5) + 2.0,
                1.5
            )::numeric,
            6
        ) AS score,
        (mi.moderation_status IN (2, 3)) AS is_hidden
    FROM public.marketplace_items mi
    LEFT JOIN public.seller_profiles sp ON sp.user_id = mi.user_id
    LEFT JOIN public.marketplace_plans plan ON plan.id = (
        CASE
            WHEN sp.user_id IS NULL THEN 'free'
            WHEN sp.plan_expires_at IS NOT NULL AND sp.plan_expires_at <= now() THEN 'free'
            ELSE sp.plan_id
        END
    )
    WHERE mi.user_id = v_seller_user_id
      AND (p_exclude_item_id IS NULL OR mi.id <> p_exclude_item_id)
      AND mi.status IN ('available', 'reserved')
      AND mi.deleted_at IS NULL
      AND (mi.expires_at IS NULL OR mi.expires_at > now())
      AND (
          mi.moderation_status IN (0, 1)
          OR (v_caller IS NOT NULL AND mi.user_id = v_caller)
      )
    ORDER BY
        (CASE WHEN mi.status = 'available' THEN 0 ELSE 1 END) ASC,
        (mi.is_sponsored OR COALESCE(plan.auto_sponsor_items, false)) DESC,
        mi.upvotes DESC,
        mi.created_at DESC,
        mi.id DESC
    LIMIT v_limit
    OFFSET v_offset;
END;
$$;

-- 7.5 Productos relacionados de otros vendedores con protección de escaparate
CREATE OR REPLACE FUNCTION public.get_related_marketplace_items(
    p_item_id uuid,
    p_limit integer DEFAULT 8
)
RETURNS TABLE (
    id uuid,
    title text,
    description text,
    price numeric,
    is_free boolean,
    category text,
    facultad text,
    sede text,
    building_code text,
    location_detail text,
    contact_whatsapp text,
    contact_telegram text,
    contact_instagram text,
    contact_messenger text,
    social_links text[],
    image_urls text[],
    video_url text,
    is_sponsored boolean,
    sponsor_badge_text text,
    author_alias text,
    upvotes integer,
    reported_count integer,
    shares_count integer,
    moderation_status integer,
    status text,
    created_at timestamptz,
    updated_at timestamptz,
    expires_at timestamptz,
    is_legal_hold boolean,
    seller_public_id uuid,
    seller_business_name text,
    seller_plan_id text,
    seller_plan_name text,
    seller_badge_text text,
    seller_is_verified boolean,
    seller_is_on_campus boolean,
    seller_building_code text,
    is_mine boolean,
    is_upvoted_by_me boolean,
    is_bookmarked_by_me boolean,
    score numeric,
    is_hidden boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_category text;
    v_sede text;
    v_facultad text;
    v_building text;
    v_price numeric;
    v_is_free boolean;
    v_seller_id uuid;
    v_mod_status integer;
    v_deleted_at timestamptz;
    v_seller_plan public.marketplace_plans;
    v_limit integer;
    v_caller uuid;
BEGIN
    v_caller := auth.uid();
    v_limit := LEAST(GREATEST(COALESCE(p_limit, 8), 1), 20);

    -- 1. Leer ítem de origen
    SELECT
        mi.category, mi.sede, mi.facultad, mi.building_code,
        mi.price, mi.is_free, mi.user_id, mi.moderation_status, mi.deleted_at
    INTO
        v_category, v_sede, v_facultad, v_building,
        v_price, v_is_free, v_seller_id, v_mod_status, v_deleted_at
    FROM public.marketplace_items mi
    WHERE mi.id = p_item_id;

    IF NOT FOUND OR v_deleted_at IS NOT NULL OR v_mod_status = 2 THEN
        RETURN;
    END IF;

    -- 2. Protección de escaparate para vendedores con hide_competitor_related = true
    IF v_seller_id IS NOT NULL THEN
        v_seller_plan := public.get_effective_seller_plan(v_seller_id);
        IF v_seller_plan.hide_competitor_related = true THEN
            RETURN;
        END IF;
    END IF;

    -- 3. Búsqueda y ponderación de candidatos
    RETURN QUERY
    SELECT
        cand.id,
        cand.title,
        cand.description,
        cand.price,
        cand.is_free,
        cand.category,
        cand.facultad,
        cand.sede,
        cand.building_code,
        cand.location_detail,
        cand.contact_whatsapp,
        cand.contact_telegram,
        cand.contact_instagram,
        cand.contact_messenger,
        cand.social_links,
        cand.image_urls,
        cand.video_url,
        (cand.is_sponsored OR COALESCE(cand_plan.auto_sponsor_items, false)) AS is_sponsored,
        cand.sponsor_badge_text,
        cand.author_alias,
        cand.upvotes,
        cand.reported_count,
        cand.shares_count,
        cand.moderation_status,
        cand.status,
        cand.created_at,
        cand.updated_at,
        cand.expires_at,
        cand.is_legal_hold,
        cand_sp.public_id AS seller_public_id,
        cand_sp.business_name AS seller_business_name,
        COALESCE(cand_plan.id, 'free') AS seller_plan_id,
        COALESCE(cand_plan.name, 'Estudiante') AS seller_plan_name,
        CASE WHEN public.is_verified_seller(cand.user_id) THEN COALESCE(cand_plan.default_badge_text, cand.sponsor_badge_text) ELSE NULL END AS seller_badge_text,
        public.is_verified_seller(cand.user_id) AS seller_is_verified,
        COALESCE(cand_sp.is_currently_on_campus, false) AS seller_is_on_campus,
        cand_sp.current_building_code AS seller_building_code,
        (v_caller IS NOT NULL AND cand.user_id = v_caller) AS is_mine,
        (v_caller IS NOT NULL AND EXISTS (
            SELECT 1 FROM public.marketplace_upvotes mu
            WHERE mu.item_id = cand.id AND mu.user_id = v_caller
        )) AS is_upvoted_by_me,
        (v_caller IS NOT NULL AND EXISTS (
            SELECT 1 FROM public.marketplace_bookmarks mb
            WHERE mb.item_id = cand.id AND mb.user_id = v_caller
        )) AS is_bookmarked_by_me,
        (
            (CASE WHEN cand.category = v_category THEN 50.0 ELSE 0.0 END) +
            (CASE WHEN cand.facultad = v_facultad THEN 25.0 ELSE 0.0 END) +
            (CASE WHEN v_building IS NOT NULL AND cand.building_code = v_building THEN 15.0 ELSE 0.0 END) +
            (CASE
                WHEN v_is_free AND cand.is_free THEN 10.0
                WHEN NOT v_is_free AND NOT cand.is_free AND v_price > 0
                     AND cand.price BETWEEN (v_price * 0.6) AND (v_price * 1.4) THEN 10.0
                ELSE 0.0
            END) +
            (CASE WHEN (cand.is_sponsored OR COALESCE(cand_plan.auto_sponsor_items, false)) THEN 20.0 ELSE 0.0 END) +
            LEAST(cand.upvotes, 10)::numeric
        )::numeric AS score,
        false AS is_hidden
    FROM public.marketplace_items cand
    LEFT JOIN public.seller_profiles cand_sp ON cand_sp.user_id = cand.user_id
    LEFT JOIN public.marketplace_plans cand_plan ON cand_plan.id = (
        CASE
            WHEN cand_sp.user_id IS NULL THEN 'free'
            WHEN cand_sp.plan_expires_at IS NOT NULL AND cand_sp.plan_expires_at <= now() THEN 'free'
            ELSE cand_sp.plan_id
        END
    )
    WHERE cand.id <> p_item_id
      AND (v_seller_id IS NULL OR cand.user_id <> v_seller_id)
      AND cand.sede = v_sede
      AND cand.status = 'available'
      AND cand.moderation_status IN (0, 1)
      AND cand.deleted_at IS NULL
      AND (cand.expires_at IS NULL OR cand.expires_at > now())
      AND (cand.category = v_category OR cand.facultad = v_facultad)
    ORDER BY
        score DESC,
        cand.created_at DESC,
        cand.id ASC
    LIMIT v_limit;
END;
$$;

-- 7.6 Alternar guardado / marcador de un producto
CREATE OR REPLACE FUNCTION public.toggle_marketplace_bookmark(p_item_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_caller uuid;
BEGIN
    v_caller := auth.uid();
    IF v_caller IS NULL THEN
        RAISE EXCEPTION 'Debes iniciar sesión para guardar productos en tus marcadores'
            USING ERRCODE = '42501';
    END IF;

    -- Validar que el ítem existe y no está purgado o bloqueado
    IF NOT EXISTS (
        SELECT 1
        FROM public.marketplace_items
        WHERE id = p_item_id
          AND deleted_at IS NULL
          AND (moderation_status IN (0, 1) OR user_id = auth.uid())
    ) THEN
        RAISE EXCEPTION 'El producto seleccionado no está disponible para ser guardado'
            USING ERRCODE = 'P0002';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.marketplace_bookmarks
        WHERE item_id = p_item_id AND user_id = v_caller
    ) THEN
        DELETE FROM public.marketplace_bookmarks
        WHERE item_id = p_item_id AND user_id = v_caller;
        RETURN false;
    ELSE
        INSERT INTO public.marketplace_bookmarks (item_id, user_id, created_at)
        VALUES (p_item_id, v_caller, now())
        ON CONFLICT (item_id, user_id) DO NOTHING;
        RETURN true;
    END IF;
END;
$$;

-- 7.7 Listado de productos guardados por el usuario autenticado
CREATE OR REPLACE FUNCTION public.get_my_bookmarked_items(
    p_limit integer DEFAULT 50,
    p_offset integer DEFAULT 0
)
RETURNS TABLE (
    id uuid,
    title text,
    description text,
    price numeric,
    is_free boolean,
    category text,
    facultad text,
    sede text,
    building_code text,
    location_detail text,
    contact_whatsapp text,
    contact_telegram text,
    contact_instagram text,
    contact_messenger text,
    social_links text[],
    image_urls text[],
    video_url text,
    is_sponsored boolean,
    sponsor_badge_text text,
    author_alias text,
    upvotes integer,
    reported_count integer,
    shares_count integer,
    moderation_status integer,
    status text,
    created_at timestamptz,
    updated_at timestamptz,
    expires_at timestamptz,
    is_legal_hold boolean,
    seller_public_id uuid,
    seller_business_name text,
    seller_plan_id text,
    seller_plan_name text,
    seller_badge_text text,
    seller_is_verified boolean,
    seller_is_on_campus boolean,
    seller_building_code text,
    is_mine boolean,
    is_upvoted_by_me boolean,
    is_bookmarked_by_me boolean,
    score numeric,
    is_hidden boolean,
    bookmarked_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_caller uuid;
    v_limit integer;
    v_offset integer;
BEGIN
    v_caller := auth.uid();
    IF v_caller IS NULL THEN
        RETURN;
    END IF;

    v_limit := LEAST(GREATEST(COALESCE(p_limit, 50), 1), 100);
    v_offset := GREATEST(COALESCE(p_offset, 0), 0);

    RETURN QUERY
    SELECT
        mi.id,
        mi.title,
        mi.description,
        mi.price,
        mi.is_free,
        mi.category,
        mi.facultad,
        mi.sede,
        mi.building_code,
        mi.location_detail,
        mi.contact_whatsapp,
        mi.contact_telegram,
        mi.contact_instagram,
        mi.contact_messenger,
        mi.social_links,
        mi.image_urls,
        mi.video_url,
        (mi.is_sponsored OR COALESCE(plan.auto_sponsor_items, false)) AS is_sponsored,
        mi.sponsor_badge_text,
        mi.author_alias,
        mi.upvotes,
        mi.reported_count,
        mi.shares_count,
        mi.moderation_status,
        mi.status,
        mi.created_at,
        mi.updated_at,
        mi.expires_at,
        mi.is_legal_hold,
        sp.public_id AS seller_public_id,
        sp.business_name AS seller_business_name,
        COALESCE(plan.id, 'free') AS seller_plan_id,
        COALESCE(plan.name, 'Estudiante') AS seller_plan_name,
        CASE WHEN public.is_verified_seller(mi.user_id) THEN COALESCE(plan.default_badge_text, mi.sponsor_badge_text) ELSE NULL END AS seller_badge_text,
        public.is_verified_seller(mi.user_id) AS seller_is_verified,
        COALESCE(sp.is_currently_on_campus, false) AS seller_is_on_campus,
        sp.current_building_code AS seller_building_code,
        (mi.user_id = v_caller) AS is_mine,
        (EXISTS (
            SELECT 1 FROM public.marketplace_upvotes mu
            WHERE mu.item_id = mi.id AND mu.user_id = v_caller
        )) AS is_upvoted_by_me,
        true AS is_bookmarked_by_me,
        ROUND(
            (
                mi.upvotes
                + CASE WHEN (mi.is_sponsored OR COALESCE(plan.auto_sponsor_items, false)) THEN 15.0 ELSE 0.0 END
                + CASE WHEN COALESCE(sp.is_currently_on_campus, false) THEN 8.0 ELSE 0.0 END
            )::numeric
            / POWER(
                GREATEST(EXTRACT(EPOCH FROM (now() - mi.created_at)) / 3600.0, 0.5) + 2.0,
                1.5
            )::numeric,
            6
        ) AS score,
        (mi.deleted_at IS NOT NULL OR mi.moderation_status = 2 OR (mi.expires_at IS NOT NULL AND mi.expires_at <= now())) AS is_hidden,
        mb.created_at AS bookmarked_at
    FROM public.marketplace_bookmarks mb
    JOIN public.marketplace_items mi ON mi.id = mb.item_id
    LEFT JOIN public.seller_profiles sp ON sp.user_id = mi.user_id
    LEFT JOIN public.marketplace_plans plan ON plan.id = (
        CASE
            WHEN sp.user_id IS NULL THEN 'free'
            WHEN sp.plan_expires_at IS NOT NULL AND sp.plan_expires_at <= now() THEN 'free'
            ELSE sp.plan_id
        END
    )
    WHERE mb.user_id = v_caller
    ORDER BY mb.created_at DESC, mi.id DESC
    LIMIT v_limit
    OFFSET v_offset;
END;
$$;

-- =============================================================================
-- BLOQUE 8: VISTAS SEGURAS (SIN EXPOSICIÓN DE user_id)
-- =============================================================================

-- Helper SECURITY DEFINER para resolver el contexto comercial sin exponer user_id en la vista invoker
CREATE OR REPLACE FUNCTION public.get_item_seller_context(p_item_id uuid)
RETURNS TABLE (
    seller_public_id uuid,
    seller_business_name text,
    seller_plan_id text,
    seller_plan_name text,
    seller_badge_text text,
    seller_is_verified boolean,
    seller_is_on_campus boolean,
    seller_building_code text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    RETURN QUERY
    SELECT
        sp.public_id AS seller_public_id,
        sp.business_name AS seller_business_name,
        COALESCE(plan.id, 'free') AS seller_plan_id,
        COALESCE(plan.name, 'Estudiante') AS seller_plan_name,
        CASE WHEN public.is_verified_seller(mi.user_id) THEN COALESCE(plan.default_badge_text, mi.sponsor_badge_text) ELSE NULL END AS seller_badge_text,
        public.is_verified_seller(mi.user_id) AS seller_is_verified,
        COALESCE(sp.is_currently_on_campus, false) AS seller_is_on_campus,
        sp.current_building_code AS seller_building_code
    FROM public.marketplace_items mi
    LEFT JOIN public.seller_profiles sp ON sp.user_id = mi.user_id
    LEFT JOIN public.marketplace_plans plan ON plan.id = (
        CASE
            WHEN sp.user_id IS NULL THEN 'free'
            WHEN sp.plan_expires_at IS NOT NULL AND sp.plan_expires_at <= now() THEN 'free'
            ELSE sp.plan_id
        END
    )
    WHERE mi.id = p_item_id;
END;
$$;

-- 7.8 Inventario propio para "Mis ventas" (incluye vendidos, pausados y en revisión)
CREATE OR REPLACE FUNCTION public.get_my_marketplace_items(
    p_status text DEFAULT NULL,
    p_limit integer DEFAULT 50,
    p_offset integer DEFAULT 0
)
RETURNS TABLE (
    id uuid,
    title text,
    description text,
    price numeric,
    is_free boolean,
    category text,
    facultad text,
    sede text,
    building_code text,
    location_detail text,
    contact_whatsapp text,
    contact_telegram text,
    contact_instagram text,
    contact_messenger text,
    social_links text[],
    image_urls text[],
    video_url text,
    is_sponsored boolean,
    sponsor_badge_text text,
    author_alias text,
    upvotes integer,
    reported_count integer,
    shares_count integer,
    moderation_status integer,
    status text,
    created_at timestamptz,
    updated_at timestamptz,
    expires_at timestamptz,
    is_legal_hold boolean,
    seller_public_id uuid,
    seller_business_name text,
    seller_plan_id text,
    seller_plan_name text,
    seller_badge_text text,
    seller_is_verified boolean,
    seller_is_on_campus boolean,
    seller_building_code text,
    is_mine boolean,
    is_upvoted_by_me boolean,
    is_bookmarked_by_me boolean,
    score numeric,
    is_hidden boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_caller uuid;
    v_limit integer;
    v_offset integer;
BEGIN
    v_caller := auth.uid();
    IF v_caller IS NULL THEN
        RETURN;
    END IF;

    v_limit := LEAST(GREATEST(COALESCE(p_limit, 50), 1), 100);
    v_offset := GREATEST(COALESCE(p_offset, 0), 0);

    RETURN QUERY
    SELECT
        mi.id,
        mi.title,
        mi.description,
        mi.price,
        mi.is_free,
        mi.category,
        mi.facultad,
        mi.sede,
        mi.building_code,
        mi.location_detail,
        mi.contact_whatsapp,
        mi.contact_telegram,
        mi.contact_instagram,
        mi.contact_messenger,
        mi.social_links,
        mi.image_urls,
        mi.video_url,
        (mi.is_sponsored OR COALESCE(plan.auto_sponsor_items, false)) AS is_sponsored,
        mi.sponsor_badge_text,
        mi.author_alias,
        mi.upvotes,
        mi.reported_count,
        mi.shares_count,
        mi.moderation_status,
        mi.status,
        mi.created_at,
        mi.updated_at,
        mi.expires_at,
        mi.is_legal_hold,
        sp.public_id AS seller_public_id,
        sp.business_name AS seller_business_name,
        COALESCE(plan.id, 'free') AS seller_plan_id,
        COALESCE(plan.name, 'Estudiante') AS seller_plan_name,
        CASE WHEN public.is_verified_seller(mi.user_id) THEN COALESCE(plan.default_badge_text, mi.sponsor_badge_text) ELSE NULL END AS seller_badge_text,
        public.is_verified_seller(mi.user_id) AS seller_is_verified,
        COALESCE(sp.is_currently_on_campus, false) AS seller_is_on_campus,
        sp.current_building_code AS seller_building_code,
        true AS is_mine,
        (EXISTS (
            SELECT 1 FROM public.marketplace_upvotes mu
            WHERE mu.item_id = mi.id AND mu.user_id = v_caller
        )) AS is_upvoted_by_me,
        (EXISTS (
            SELECT 1 FROM public.marketplace_bookmarks mb
            WHERE mb.item_id = mi.id AND mb.user_id = v_caller
        )) AS is_bookmarked_by_me,
        ROUND(
            (
                mi.upvotes
                + CASE WHEN (mi.is_sponsored OR COALESCE(plan.auto_sponsor_items, false)) THEN 15.0 ELSE 0.0 END
                + CASE WHEN COALESCE(sp.is_currently_on_campus, false) THEN 8.0 ELSE 0.0 END
            )::numeric
            / POWER(
                GREATEST(EXTRACT(EPOCH FROM (now() - mi.created_at)) / 3600.0, 0.5) + 2.0,
                1.5
            )::numeric,
            6
        ) AS score,
        (mi.moderation_status IN (2, 3) OR (mi.expires_at IS NOT NULL AND mi.expires_at <= now())) AS is_hidden
    FROM public.marketplace_items mi
    LEFT JOIN public.seller_profiles sp ON sp.user_id = mi.user_id
    LEFT JOIN public.marketplace_plans plan ON plan.id = (
        CASE
            WHEN sp.user_id IS NULL THEN 'free'
            WHEN sp.plan_expires_at IS NOT NULL AND sp.plan_expires_at <= now() THEN 'free'
            ELSE sp.plan_id
        END
    )
    WHERE mi.user_id = v_caller
      AND mi.deleted_at IS NULL
      AND (p_status IS NULL OR mi.status = p_status)
    ORDER BY mi.created_at DESC, mi.id DESC
    LIMIT v_limit
    OFFSET v_offset;
END;
$$;

-- Vista segura de perfiles comerciales (excluye user_id)
DROP VIEW IF EXISTS public.safe_seller_profiles;
CREATE VIEW public.safe_seller_profiles
WITH (security_invoker = true)
AS
SELECT
    sp.public_id,
    sp.plan_id,
    sp.seller_type,
    sp.verification_status,
    sp.business_name,
    sp.business_description,
    sp.business_logo_url,
    sp.business_banner_url,
    sp.business_hours,
    sp.is_currently_on_campus,
    sp.current_building_code,
    sp.current_location_note,
    sp.plan_expires_at,
    sp.created_at,
    sp.updated_at
FROM public.seller_profiles sp;

-- Reemplazo de vista segura de artículos de marketplace
DROP VIEW IF EXISTS public.safe_marketplace_items;
CREATE VIEW public.safe_marketplace_items
WITH (security_invoker = true)
AS
SELECT
    mi.id,
    mi.title,
    mi.description,
    mi.price,
    mi.is_free,
    mi.category,
    mi.facultad,
    mi.sede,
    mi.building_code,
    mi.location_detail,
    mi.contact_whatsapp,
    mi.contact_telegram,
    mi.contact_instagram,
    mi.contact_messenger,
    mi.social_links,
    mi.image_urls,
    mi.video_url,
    mi.is_sponsored,
    mi.sponsor_badge_text,
    mi.author_alias,
    mi.upvotes,
    mi.reported_count,
    mi.shares_count,
    mi.status,
    mi.moderation_status,
    mi.moderation_label,
    mi.moderation_confidence,
    mi.moderation_reason,
    mi.moderated_at,
    mi.moderated_by,
    mi.created_at,
    mi.updated_at,
    mi.expires_at,
    mi.deleted_at,
    mi.is_legal_hold,
    ctx.seller_public_id,
    ctx.seller_business_name,
    ctx.seller_plan_id,
    ctx.seller_plan_name,
    ctx.seller_badge_text,
    ctx.seller_is_verified,
    ctx.seller_is_on_campus,
    ctx.seller_building_code,
    public.is_my_marketplace_item(mi.id) AS is_mine,
    (auth.uid() IS NOT NULL AND EXISTS (
        SELECT 1 FROM public.marketplace_upvotes mu
        WHERE mu.item_id = mi.id AND mu.user_id = auth.uid()
    )) AS is_upvoted_by_me,
    (auth.uid() IS NOT NULL AND EXISTS (
        SELECT 1 FROM public.marketplace_bookmarks mb
        WHERE mb.item_id = mi.id AND mb.user_id = auth.uid()
    )) AS is_bookmarked_by_me
FROM public.marketplace_items mi
LEFT JOIN LATERAL public.get_item_seller_context(mi.id) ctx ON true
WHERE mi.deleted_at IS NULL
  AND (
      mi.moderation_status IN (0, 1)
      OR public.is_my_marketplace_item(mi.id)
  )
  AND (
      mi.status IN ('available', 'reserved')
      OR public.is_my_marketplace_item(mi.id)
  )
  AND (mi.expires_at IS NULL OR mi.expires_at > now());

-- =============================================================================
-- BLOQUE 9: ÍNDICES DE RENDIMIENTO
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_marketplace_items_feed
    ON public.marketplace_items (sede, status, created_at DESC)
    WHERE moderation_status IN (0, 1) AND deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_marketplace_items_seller
    ON public.marketplace_items (user_id, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_marketplace_items_expiry
    ON public.marketplace_items (expires_at)
    WHERE status IN ('available', 'reserved') AND expires_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_marketplace_events_item_date
    ON public.marketplace_item_events (item_id, event_type, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_marketplace_bookmarks_user
    ON public.marketplace_bookmarks (user_id, created_at DESC);

-- Índices de búsqueda trigram si pg_trgm está instalado
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_trgm') THEN
        CREATE INDEX IF NOT EXISTS idx_marketplace_items_title_lower_trgm
            ON public.marketplace_items USING gin (lower(title) gin_trgm_ops);
        CREATE INDEX IF NOT EXISTS idx_marketplace_items_desc_lower_trgm
            ON public.marketplace_items USING gin (lower(description) gin_trgm_ops);
    END IF;
END $$;

-- =============================================================================
-- BLOQUE 10: RLS Y POLÍTICAS DE SEGURIDAD
-- =============================================================================

-- 10.1 marketplace_plans
ALTER TABLE public.marketplace_plans ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Lectura pública de planes activos" ON public.marketplace_plans;
CREATE POLICY "Lectura pública de planes activos"
    ON public.marketplace_plans
    FOR SELECT
    TO anon, authenticated
    USING (is_active = true OR public.is_pemtree_admin(auth.uid()) OR public.is_pemtree_moderator(auth.uid()));

DROP POLICY IF EXISTS "Administración de planes por staff" ON public.marketplace_plans;
CREATE POLICY "Administración de planes por staff"
    ON public.marketplace_plans
    FOR ALL
    TO authenticated
    USING (public.is_pemtree_admin(auth.uid()))
    WITH CHECK (public.is_pemtree_admin(auth.uid()));

-- 10.2 seller_profiles
ALTER TABLE public.seller_profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Lectura pública de perfiles comerciales" ON public.seller_profiles;
CREATE POLICY "Lectura pública de perfiles comerciales"
    ON public.seller_profiles
    FOR SELECT
    TO anon, authenticated
    USING (true);

DROP POLICY IF EXISTS "Vendedor puede insertar su propio perfil" ON public.seller_profiles;
CREATE POLICY "Vendedor puede insertar su propio perfil"
    ON public.seller_profiles
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Vendedor puede actualizar su propio perfil" ON public.seller_profiles;
CREATE POLICY "Vendedor puede actualizar su propio perfil"
    ON public.seller_profiles
    FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Staff puede gestionar todos los perfiles de vendedor" ON public.seller_profiles;
CREATE POLICY "Staff puede gestionar todos los perfiles de vendedor"
    ON public.seller_profiles
    FOR ALL
    TO authenticated
    USING (public.is_pemtree_admin(auth.uid()) OR public.is_pemtree_moderator(auth.uid()))
    WITH CHECK (public.is_pemtree_admin(auth.uid()) OR public.is_pemtree_moderator(auth.uid()));

-- 10.3 marketplace_item_events
ALTER TABLE public.marketplace_item_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Permitir registrar eventos de items" ON public.marketplace_item_events;
CREATE POLICY "Permitir registrar eventos de items"
    ON public.marketplace_item_events
    FOR INSERT
    TO anon, authenticated
    WITH CHECK (viewer_id IS NULL OR (auth.uid() IS NOT NULL AND viewer_id = auth.uid()));

DROP POLICY IF EXISTS "Lectura de propios eventos de navegacion" ON public.marketplace_item_events;
CREATE POLICY "Lectura de propios eventos de navegacion"
    ON public.marketplace_item_events
    FOR SELECT
    TO authenticated
    USING (auth.uid() IS NOT NULL AND viewer_id = auth.uid());

DROP POLICY IF EXISTS "Staff puede auditar eventos de items" ON public.marketplace_item_events;
CREATE POLICY "Staff puede auditar eventos de items"
    ON public.marketplace_item_events
    FOR SELECT
    TO authenticated
    USING (public.is_pemtree_admin(auth.uid()) OR public.is_pemtree_moderator(auth.uid()));

-- 10.4 marketplace_bookmarks
ALTER TABLE public.marketplace_bookmarks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Gestionar mis propios marcadores de marketplace" ON public.marketplace_bookmarks;
CREATE POLICY "Gestionar mis propios marcadores de marketplace"
    ON public.marketplace_bookmarks
    FOR ALL
    TO authenticated
    USING (auth.uid() IS NOT NULL AND user_id = auth.uid())
    WITH CHECK (auth.uid() IS NOT NULL AND user_id = auth.uid());

-- 10.5 sponsor_requests
DROP POLICY IF EXISTS "Anyone can insert sponsor requests" ON public.sponsor_requests;
DROP POLICY IF EXISTS "Permitir crear solicitud propia de patrocinio" ON public.sponsor_requests;
CREATE POLICY "Permitir crear solicitud propia de patrocinio"
    ON public.sponsor_requests
    FOR INSERT
    TO authenticated
    WITH CHECK (
        auth.uid() IS NOT NULL
        AND user_id = auth.uid()
        AND status = 'pending'
    );

DROP POLICY IF EXISTS "Dueño y staff pueden leer sponsor_requests" ON public.sponsor_requests;
CREATE POLICY "Dueño y staff pueden leer sponsor_requests"
    ON public.sponsor_requests
    FOR SELECT
    TO authenticated
    USING (
        (auth.uid() IS NOT NULL AND user_id = auth.uid())
        OR public.is_pemtree_admin(auth.uid())
        OR public.is_pemtree_moderator(auth.uid())
    );

DROP POLICY IF EXISTS "Staff puede actualizar sponsor_requests" ON public.sponsor_requests;
CREATE POLICY "Staff puede actualizar sponsor_requests"
    ON public.sponsor_requests
    FOR UPDATE
    TO authenticated
    USING (
        public.is_pemtree_admin(auth.uid())
        OR public.is_pemtree_moderator(auth.uid())
    )
    WITH CHECK (
        public.is_pemtree_admin(auth.uid())
        OR public.is_pemtree_moderator(auth.uid())
    );

-- 10.6 marketplace_items: la verificación se valida en RLS y en el trigger.
-- Se alinea la política de INSERT con public.is_verified_seller (carné verificado
-- o cuenta comercial aprobada) para no depender de columnas legacy.
DROP POLICY IF EXISTS "Authenticated users can insert own marketplace items" ON public.marketplace_items;
DROP POLICY IF EXISTS "Verified sellers can insert own marketplace items" ON public.marketplace_items;
CREATE POLICY "Verified sellers can insert own marketplace items"
    ON public.marketplace_items
    FOR INSERT
    TO authenticated
    WITH CHECK (
        auth.uid() IS NOT NULL
        AND user_id = auth.uid()
        AND public.is_verified_seller(auth.uid())
    );

-- =============================================================================
-- BLOQUE 11: PRIVILEGIOS Y GRANTS EXPLÍCITOS
-- =============================================================================

-- 11.1 Revocaciones base
REVOKE ALL ON TABLE public.marketplace_plans FROM PUBLIC;
REVOKE ALL ON TABLE public.seller_profiles FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.marketplace_item_events FROM PUBLIC;
REVOKE ALL ON TABLE public.marketplace_bookmarks FROM PUBLIC;
REVOKE UPDATE, DELETE ON TABLE public.sponsor_requests FROM anon;
REVOKE ALL ON TABLE public.sponsor_requests FROM anon;
REVOKE DELETE ON TABLE public.sponsor_requests FROM authenticated;
-- La vigencia y los contadores del sistema no se editan a mano.
REVOKE UPDATE (expires_at, shares_count) ON TABLE public.marketplace_items FROM anon, authenticated;

-- 11.2 Concesiones a postgres y service_role
GRANT ALL ON TABLE public.marketplace_plans TO postgres, service_role;
GRANT ALL ON TABLE public.seller_profiles TO postgres, service_role;
GRANT ALL ON TABLE public.marketplace_item_events TO postgres, service_role;
GRANT ALL ON TABLE public.marketplace_bookmarks TO postgres, service_role;
GRANT ALL ON TABLE public.sponsor_requests TO postgres, service_role;

-- 11.3 Concesiones de tablas
GRANT SELECT ON TABLE public.marketplace_plans TO anon, authenticated;
GRANT SELECT (expires_at, shares_count) ON TABLE public.marketplace_items TO anon, authenticated;
-- La vigencia (expires_at) la calcula exclusivamente el trigger del plan;
-- no se concede UPDATE de esa columna al cliente.

-- Grants por columna en seller_profiles excluyendo user_id para anon y authenticated
GRANT SELECT (
    public_id, plan_id, seller_type, verification_status,
    business_name, business_description, business_logo_url, business_banner_url,
    business_hours, is_currently_on_campus, current_building_code,
    current_location_note, plan_expires_at, created_at, updated_at
) ON TABLE public.seller_profiles TO anon, authenticated;

-- El alta directa solo puede crear la fila propia; el trigger fuerza plan free,
-- seller_type student y verification_status pending para usuarios no staff.
GRANT INSERT ON TABLE public.seller_profiles TO authenticated;

GRANT UPDATE (
    business_name, business_description, business_logo_url, business_banner_url,
    business_hours, is_currently_on_campus, current_building_code,
    current_location_note, verification_status, plan_id, plan_expires_at, seller_type
) ON TABLE public.seller_profiles TO authenticated;

GRANT INSERT, SELECT ON TABLE public.marketplace_item_events TO anon, authenticated;
GRANT SELECT, INSERT, DELETE ON TABLE public.marketplace_bookmarks TO authenticated;
GRANT SELECT ON TABLE public.sponsor_requests TO authenticated;
GRANT INSERT ON TABLE public.sponsor_requests TO authenticated;
GRANT UPDATE (status, plan_id, reviewed_by, reviewed_at, admin_note) ON TABLE public.sponsor_requests TO authenticated;

-- 11.4 Concesiones de vistas seguras
GRANT SELECT ON public.safe_marketplace_items TO anon, authenticated;
GRANT SELECT ON public.safe_seller_profiles TO anon, authenticated;

-- 11.5 Concesiones de funciones
GRANT EXECUTE ON FUNCTION public.get_effective_seller_plan(uuid) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_verified_seller(uuid) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.marketplace_contains_prohibited_terms(text) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_item_seller_context(uuid) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.track_marketplace_event(uuid, text) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_marketplace_feed(text, text, text, text, text, boolean, boolean, integer, integer) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_marketplace_item_detail(uuid) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_seller_public_profile(uuid) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_seller_catalog(uuid, uuid, integer, integer) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_related_marketplace_items(uuid, integer) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_marketplace_metrics(integer) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_my_marketplace_status() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.toggle_marketplace_bookmark(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_my_bookmarked_items(integer, integer) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_my_marketplace_items(text, integer, integer) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.pause_expired_marketplace_items() TO postgres, service_role;
GRANT EXECUTE ON FUNCTION public.reconcile_seller_plan_limits(uuid) TO postgres, service_role;

-- =============================================================================
-- BLOQUE 12: PROGRAMACIÓN AUTOMATIZADA CON PG_CRON
-- =============================================================================

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'marketplace-pause-expired') THEN
            PERFORM cron.unschedule('marketplace-pause-expired');
        END IF;

        PERFORM cron.schedule(
            'marketplace-pause-expired',
            '10 3 * * *',
            'SELECT public.pause_expired_marketplace_items();'
        );
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'pg_cron no disponible o sin privilegios de configuración: %', SQLERRM;
END $$;

COMMIT;
