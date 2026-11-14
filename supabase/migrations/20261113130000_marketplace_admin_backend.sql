-- =============================================================================
-- Migración: 20261113130000_marketplace_admin_backend.sql
-- Módulo: Marketplace & Tutorías — Backend del panel administrativo
-- Rol: Agente 1 — Arquitecto Senior de Base de Datos (PostgreSQL / Supabase)
--
-- Objetivo:
--   El panel admin (React + publishable key, rol `authenticated`) no puede
--   administrar `marketplace_plans` (solo lectura) ni ejecutar cambios
--   sensibles de vendedores de forma auditable. Esta migración expone RPCs
--   SECURITY DEFINER restringidas a staff (admin/moderador) y una bitácora
--   inmutable de auditoría.
--
-- Normativa aplicada:
--   * UX-MKT-014 / 017 / 018 / 026.
--   * Art. 3: el contenido ajeno (título, descripción, precio, imágenes,
--     contactos) es inmutable; el staff solo altera estado comercial,
--     patrocinio y metadatos administrativos.
--   * Art. 12: sin PII en la bitácora (sin CUI, carné ni teléfonos completos).
--   * Art. 20/21: soft delete y retención legal (`is_legal_hold`) respetados.
--
-- Idempotente. No modifica la migración 20261113120000_marketplace_ux_backend.
-- =============================================================================

BEGIN;

-- =============================================================================
-- BLOQUE 1: HELPER DE STAFF
-- =============================================================================

-- Staff del Marketplace = administrador o moderador de PEMTREE.
-- SECURITY DEFINER para consultar `public.user_roles` sin depender de RLS.
CREATE OR REPLACE FUNCTION public.is_marketplace_staff(p_user_id uuid DEFAULT auth.uid())
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT public.is_pemtree_admin(p_user_id) OR public.is_pemtree_moderator(p_user_id);
$$;

COMMENT ON FUNCTION public.is_marketplace_staff(uuid) IS
    'Verdadero si el usuario es administrador o moderador de PEMTREE (staff del Marketplace).';

-- =============================================================================
-- BLOQUE 2: BITÁCORA DE AUDITORÍA
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.marketplace_admin_audit (
    id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id    uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
    action      text        NOT NULL,
    target_type text        NOT NULL CHECK (target_type IN ('item', 'seller', 'plan', 'sponsor_request')),
    target_id   text        NOT NULL,
    details     jsonb       NOT NULL DEFAULT '{}'::jsonb,
    note        text,
    created_at  timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.marketplace_admin_audit IS
    'Bitácora de acciones administrativas del Marketplace. Sin PII: solo identificadores y metadatos operativos.';

CREATE INDEX IF NOT EXISTS idx_marketplace_admin_audit_created_at
    ON public.marketplace_admin_audit (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_marketplace_admin_audit_target
    ON public.marketplace_admin_audit (target_type, target_id);

ALTER TABLE public.marketplace_admin_audit ENABLE ROW LEVEL SECURITY;

-- Solo staff puede leer la bitácora. Las inserciones provienen exclusivamente
-- de las RPC SECURITY DEFINER; por eso no hay política de INSERT/UPDATE/DELETE.
DROP POLICY IF EXISTS "Staff puede leer la auditoria del marketplace" ON public.marketplace_admin_audit;
CREATE POLICY "Staff puede leer la auditoria del marketplace"
    ON public.marketplace_admin_audit
    FOR SELECT
    TO authenticated
    USING (public.is_marketplace_staff(auth.uid()));

-- =============================================================================
-- BLOQUE 3: RPCs DEL PANEL ADMINISTRATIVO
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 3.1 Resumen general del Marketplace
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_marketplace_overview()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_items      jsonb;
    v_sellers    jsonb;
    v_plans      jsonb;
    v_sponsors   jsonb;
    v_engagement jsonb;
BEGIN
    IF NOT public.is_marketplace_staff(auth.uid()) THEN
        RAISE EXCEPTION 'Solo el personal de PEMTREE (administrador o moderador) puede consultar el panel del Marketplace'
            USING ERRCODE = '42501';
    END IF;

    -- Ítems: universos sin eliminar lógicamente (soft delete, Art. 20/21).
    SELECT jsonb_build_object(
        'total',       count(*),
        'available',   count(*) FILTER (WHERE mi.status = 'available'),
        'reserved',    count(*) FILTER (WHERE mi.status = 'reserved'),
        'sold',        count(*) FILTER (WHERE mi.status = 'sold'),
        'paused',      count(*) FILTER (WHERE mi.status = 'paused'),
        'archived',    count(*) FILTER (WHERE mi.status = 'archived'),
        'expired',     count(*) FILTER (
                           WHERE mi.expires_at IS NOT NULL
                             AND mi.expires_at <= now()
                             AND mi.status IN ('available', 'reserved')
                       ),
        'hidden',      count(*) FILTER (WHERE mi.moderation_status = 2),
        'in_review',   count(*) FILTER (WHERE mi.moderation_status = 3),
        'sponsored',   count(*) FILTER (WHERE mi.is_sponsored = true),
        'legal_hold',  count(*) FILTER (WHERE mi.is_legal_hold = true)
    )
    INTO v_items
    FROM public.marketplace_items mi
    WHERE mi.deleted_at IS NULL;

    -- Vendedores y distribución por plan efectivo (respeta vencimientos).
    SELECT jsonb_build_object(
        'total',          count(*),
        'verified',       count(*) FILTER (WHERE public.is_verified_seller(sp.user_id)),
        'pending',        count(*) FILTER (WHERE sp.verification_status = 'pending'),
        'local_business', count(*) FILTER (WHERE sp.seller_type = 'local_business'),
        'on_campus',      count(*) FILTER (WHERE sp.is_currently_on_campus = true),
        'by_plan', COALESCE((
            SELECT jsonb_agg(
                       jsonb_build_object(
                           'plan_id',   t.plan_id,
                           'plan_name', t.plan_name,
                           'count',     t.cnt
                       )
                       ORDER BY t.sort_order, t.plan_id
                   )
            FROM (
                SELECT COALESCE(ep.id, 'free')          AS plan_id,
                       COALESCE(ep.name, 'Estudiante')  AS plan_name,
                       COALESCE(ep.sort_order, 0)       AS sort_order,
                       count(*)                         AS cnt
                FROM public.seller_profiles sp2
                LEFT JOIN LATERAL public.get_effective_seller_plan(sp2.user_id) ep ON true
                GROUP BY 1, 2, 3
            ) t
        ), '[]'::jsonb)
    )
    INTO v_sellers
    FROM public.seller_profiles sp;

    SELECT jsonb_build_object(
        'total',  count(*),
        'active', count(*) FILTER (WHERE p.is_active = true)
    )
    INTO v_plans
    FROM public.marketplace_plans p;

    SELECT jsonb_build_object(
        'pending',   count(*) FILTER (WHERE sr.status = 'pending'),
        'in_review', count(*) FILTER (WHERE sr.status = 'in_review'),
        'approved',  count(*) FILTER (WHERE sr.status = 'approved'),
        'rejected',  count(*) FILTER (WHERE sr.status = 'rejected')
    )
    INTO v_sponsors
    FROM public.sponsor_requests sr;

    SELECT jsonb_build_object(
        'views_7d',          (SELECT count(*)
                                FROM public.marketplace_item_events e
                               WHERE e.event_type = 'view'
                                 AND e.created_at >= now() - interval '7 days'),
        'contact_clicks_7d', (SELECT count(*)
                                FROM public.marketplace_item_events e
                               WHERE e.event_type LIKE 'click\_%'
                                 AND e.created_at >= now() - interval '7 days'),
        'shares_7d',         (SELECT count(*)
                                FROM public.marketplace_item_events e
                               WHERE e.event_type = 'share'
                                 AND e.created_at >= now() - interval '7 days'),
        'bookmarks_total',   (SELECT count(*) FROM public.marketplace_bookmarks)
    )
    INTO v_engagement;

    RETURN jsonb_build_object(
        'items',            v_items,
        'sellers',          v_sellers,
        'plans',            v_plans,
        'sponsor_requests', v_sponsors,
        'engagement',       v_engagement,
        'generated_at',     now()
    );
END;
$$;

COMMENT ON FUNCTION public.admin_marketplace_overview() IS
    'Resumen del Marketplace para el panel administrativo (solo staff).';

-- -----------------------------------------------------------------------------
-- 3.2 Listado administrativo de publicaciones
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_list_marketplace_items(
    p_search     text    DEFAULT NULL,
    p_status     text    DEFAULT NULL,
    p_moderation integer DEFAULT NULL,
    p_plan       text    DEFAULT NULL,
    p_limit      integer DEFAULT 100,
    p_offset     integer DEFAULT 0
)
RETURNS TABLE (
    id                uuid,
    title             text,
    status            text,
    moderation_status integer,
    moderation_label  text,
    price             numeric,
    is_free           boolean,
    category          text,
    sede              text,
    faculty           text,
    building_code     text,
    image_urls        text[],
    author_alias      text,
    seller_user_id    uuid,
    seller_public_id  uuid,
    plan_id           text,
    plan_name         text,
    seller_verified   boolean,
    is_sponsored      boolean,
    sponsor_badge_text text,
    expires_at        timestamptz,
    shares_count      integer,
    upvotes           integer,
    reported_count    integer,
    created_at        timestamptz,
    updated_at        timestamptz,
    deleted_at        timestamptz,
    is_legal_hold     boolean,
    views_7d          bigint,
    contact_clicks_7d bigint
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
        RAISE EXCEPTION 'Solo el personal de PEMTREE (administrador o moderador) puede listar publicaciones del Marketplace'
            USING ERRCODE = '42501';
    END IF;

    v_limit  := LEAST(GREATEST(COALESCE(p_limit, 100), 1), 500);
    v_offset := GREATEST(COALESCE(p_offset, 0), 0);
    v_search := NULLIF(btrim(COALESCE(p_search, '')), '');

    RETURN QUERY
    SELECT
        mi.id,
        mi.title,
        mi.status,
        mi.moderation_status,
        mi.moderation_label,
        mi.price,
        mi.is_free,
        mi.category,
        mi.sede,
        mi.facultad                    AS faculty,
        mi.building_code,
        mi.image_urls,
        mi.author_alias,
        mi.user_id                     AS seller_user_id,
        sp.public_id                   AS seller_public_id,
        COALESCE(ep.id, 'free')        AS plan_id,
        COALESCE(ep.name, 'Estudiante') AS plan_name,
        public.is_verified_seller(mi.user_id) AS seller_verified,
        (mi.is_sponsored OR COALESCE(ep.auto_sponsor_items, false)) AS is_sponsored,
        mi.sponsor_badge_text,
        mi.expires_at,
        mi.shares_count,
        mi.upvotes,
        mi.reported_count,
        mi.created_at,
        mi.updated_at,
        mi.deleted_at,
        mi.is_legal_hold,
        COALESCE(ev.views_7d, 0)::bigint          AS views_7d,
        COALESCE(ev.contact_clicks_7d, 0)::bigint AS contact_clicks_7d
    FROM public.marketplace_items mi
    LEFT JOIN public.seller_profiles sp ON sp.user_id = mi.user_id
    LEFT JOIN LATERAL public.get_effective_seller_plan(mi.user_id) ep ON true
    LEFT JOIN LATERAL (
        SELECT count(*) FILTER (WHERE e.event_type = 'view')         AS views_7d,
               count(*) FILTER (WHERE e.event_type LIKE 'click\_%')  AS contact_clicks_7d
        FROM public.marketplace_item_events e
        WHERE e.item_id = mi.id
          AND e.created_at >= now() - interval '7 days'
    ) ev ON true
    WHERE (
            v_search IS NULL
            OR mi.title ILIKE '%' || v_search || '%'
            OR COALESCE(mi.author_alias, '') ILIKE '%' || v_search || '%'
          )
      AND (p_status IS NULL OR mi.status = p_status)
      AND (p_moderation IS NULL OR mi.moderation_status = p_moderation)
      AND (p_plan IS NULL OR COALESCE(ep.id, 'free') = p_plan)
    ORDER BY mi.created_at DESC, mi.id DESC
    LIMIT v_limit
    OFFSET v_offset;
END;
$$;

COMMENT ON FUNCTION public.admin_list_marketplace_items(text, text, integer, text, integer, integer) IS
    'Inventario administrativo de publicaciones del Marketplace, con plan efectivo y métricas de 7 días (solo staff).';

-- -----------------------------------------------------------------------------
-- 3.3 Listado administrativo de vendedores
-- -----------------------------------------------------------------------------
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
        p.full_name,
        -- profiles.carne se neutraliza en reposo (Art. 12); se expone el campo
        -- por contrato del panel, pero nunca contiene el dato en claro.
        p.carne,
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
            OR COALESCE(p.full_name, '') ILIKE '%' || v_search || '%'
            OR COALESCE(p.carne, '') ILIKE '%' || v_search || '%'
          )
      AND (p_plan IS NULL OR COALESCE(ep.id, 'free') = p_plan)
      AND (p_verification IS NULL OR sp.verification_status = p_verification)
    ORDER BY sp.created_at DESC, sp.user_id
    LIMIT v_limit
    OFFSET v_offset;
END;
$$;

COMMENT ON FUNCTION public.admin_list_marketplace_sellers(text, text, text, integer, integer) IS
    'Inventario administrativo de vendedores con plan efectivo y métricas de 30 días (solo staff).';

-- -----------------------------------------------------------------------------
-- 3.4 Actualización administrativa de un vendedor
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_update_marketplace_seller(
    p_user_id             uuid,
    p_plan_id             text,
    p_seller_type         text,
    p_verification_status text,
    p_plan_expires_at     timestamptz DEFAULT NULL,
    p_business_name       text        DEFAULT NULL,
    p_note                text        DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_actor        uuid := auth.uid();
    v_plan         public.marketplace_plans;
    v_found        boolean;
    v_old_plan     text;
    v_old_ver      text;
    v_old_on_campus boolean;
    v_old_building text;
    v_old_expires  timestamptz;
    v_old_business text;
    v_expires      timestamptz;
    v_on_campus    boolean;
    v_building     text;
    v_business     text;
    v_profile_status text;
    v_items_paused integer := 0;
    v_claims       text;
    v_sub          text;
BEGIN
    IF NOT public.is_marketplace_staff(v_actor) THEN
        RAISE EXCEPTION 'Solo el personal de PEMTREE (administrador o moderador) puede actualizar vendedores del Marketplace'
            USING ERRCODE = '42501';
    END IF;

    IF p_user_id IS NULL OR NOT EXISTS (SELECT 1 FROM auth.users u WHERE u.id = p_user_id) THEN
        RAISE EXCEPTION 'El usuario % no existe', p_user_id
            USING ERRCODE = 'P0002';
    END IF;

    SELECT * INTO v_plan
    FROM public.marketplace_plans mp
    WHERE mp.id = p_plan_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El plan % no existe', p_plan_id
            USING ERRCODE = '23503';
    END IF;

    IF v_plan.is_active IS NOT TRUE THEN
        RAISE EXCEPTION 'El plan % está inactivo y no puede asignarse', p_plan_id
            USING ERRCODE = '23514';
    END IF;

    IF p_seller_type IS NULL OR p_seller_type NOT IN ('student', 'local_business') THEN
        RAISE EXCEPTION 'Tipo de vendedor inválido: % (válidos: student, local_business)', p_seller_type
            USING ERRCODE = '22023';
    END IF;

    IF p_verification_status IS NULL
       OR p_verification_status NOT IN ('pending', 'approved', 'rejected', 'suspended') THEN
        RAISE EXCEPTION 'Estado de verificación inválido: % (válidos: pending, approved, rejected, suspended)', p_verification_status
            USING ERRCODE = '22023';
    END IF;

    -- Estado previo (para auditoría y para preservar campos no enviados).
    SELECT sp.plan_id, sp.verification_status, sp.is_currently_on_campus,
           sp.current_building_code, sp.plan_expires_at, sp.business_name
    INTO v_old_plan, v_old_ver, v_old_on_campus,
         v_old_building, v_old_expires, v_old_business
    FROM public.seller_profiles sp
    WHERE sp.user_id = p_user_id;
    v_found := FOUND;

    -- B3.1: la aprobación de verificación es exclusiva del administrador.
    -- Solo se exige cuando la verificación CAMBIA a 'approved'; así un moderador
    -- puede seguir gestionando plan/tipo de un vendedor ya aprobado.
    IF p_verification_status = 'approved'
       AND NOT public.is_pemtree_admin(v_actor)
       AND (NOT v_found OR v_old_ver IS DISTINCT FROM 'approved') THEN
        RAISE EXCEPTION 'Solo un administrador de PEMTREE puede aprobar la verificación de un vendedor'
            USING ERRCODE = '42501';
    END IF;

    -- B3.2: nadie puede aprobar su propia verificación (anti auto-aprobación).
    IF p_verification_status = 'approved'
       AND p_user_id = v_actor
       AND (NOT v_found OR v_old_ver IS DISTINCT FROM 'approved') THEN
        RAISE EXCEPTION 'Nadie puede aprobar su propia verificación de vendedor'
            USING ERRCODE = '42501';
    END IF;

    -- Plan free nunca tiene vigencia de pago.
    v_expires := CASE
        WHEN p_plan_id = 'free'              THEN NULL
        WHEN p_plan_expires_at IS NOT NULL   THEN p_plan_expires_at
        ELSE v_old_expires
    END;

    -- Retención/suspensión retira la presencia en campus; plan free tampoco la admite.
    v_on_campus := CASE
        WHEN p_verification_status = 'suspended' OR p_plan_id = 'free' THEN false
        ELSE COALESCE(v_old_on_campus, false)
    END;
    v_building := CASE
        WHEN p_verification_status = 'suspended' OR p_plan_id = 'free' THEN NULL
        ELSE v_old_building
    END;

    v_business := CASE
        WHEN p_business_name IS NULL THEN v_old_business
        ELSE NULLIF(btrim(p_business_name), '')
    END;

    -- Upsert preservando `public_id` (identificador público inmutable).
    INSERT INTO public.seller_profiles AS sp (
        user_id, plan_id, seller_type, verification_status, business_name,
        plan_expires_at, is_currently_on_campus, current_building_code
    ) VALUES (
        p_user_id, p_plan_id, p_seller_type, p_verification_status, v_business,
        v_expires, v_on_campus, v_building
    )
    ON CONFLICT (user_id) DO UPDATE SET
        plan_id                = EXCLUDED.plan_id,
        seller_type            = EXCLUDED.seller_type,
        verification_status    = EXCLUDED.verification_status,
        business_name          = EXCLUDED.business_name,
        plan_expires_at        = EXCLUDED.plan_expires_at,
        is_currently_on_campus = EXCLUDED.is_currently_on_campus,
        current_building_code  = EXCLUDED.current_building_code,
        updated_at             = now();

    -- B2: la suspensión retira al vendedor del catálogo público.
    -- El trigger de inmutabilidad impide a staff no-autor cambiar `status`,
    -- por lo que se ejecuta como tarea de sistema (GUC locales, restauradas
    -- de inmediato). Nunca se tocan ítems bajo retención legal.
    IF p_verification_status = 'suspended' THEN
        v_claims := current_setting('request.jwt.claims', true);
        v_sub    := current_setting('request.jwt.claim.sub', true);

        PERFORM set_config('request.jwt.claims', '', true);
        PERFORM set_config('request.jwt.claim.sub', '', true);

        UPDATE public.marketplace_items
        SET status = 'paused',
            updated_at = now()
        WHERE user_id = p_user_id
          AND status IN ('available', 'reserved')
          AND is_legal_hold = false
          AND deleted_at IS NULL;

        GET DIAGNOSTICS v_items_paused = ROW_COUNT;

        PERFORM set_config('request.jwt.claims', COALESCE(v_claims, ''), true);
        PERFORM set_config('request.jwt.claim.sub', COALESCE(v_sub, ''), true);
    END IF;

    -- B3.3: Sincronización mínima del perfil público: solo la columna de
    -- verificación. Un estudiante sin carné verificado no queda habilitado
    -- para publicar aunque el administrador apruebe su perfil comercial.
    v_profile_status := CASE
        WHEN p_verification_status = 'approved' THEN
            CASE
                WHEN COALESCE((
                         SELECT pr.is_verified
                         FROM public.profiles pr
                         WHERE pr.id = p_user_id
                     ), false) = true
                     OR p_seller_type = 'local_business'
                THEN 'verified'
                ELSE 'pending'
            END
        WHEN p_verification_status = 'rejected' THEN 'rejected'
        WHEN p_verification_status = 'pending'  THEN 'pending'
        ELSE 'unverified'
    END;

    UPDATE public.profiles
    SET seller_verification_status = v_profile_status
    WHERE id = p_user_id;

    INSERT INTO public.marketplace_admin_audit (
        actor_id, action, target_type, target_id, details, note
    ) VALUES (
        v_actor,
        'seller.update',
        'seller',
        p_user_id::text,
        jsonb_build_object(
            'plan_before',         CASE WHEN v_found THEN v_old_plan ELSE NULL END,
            'plan_after',          p_plan_id,
            'verification_before', CASE WHEN v_found THEN v_old_ver ELSE NULL END,
            'verification_after',  p_verification_status,
            'seller_type',         p_seller_type,
            'plan_expires_at',     v_expires,
            'items_paused',        v_items_paused
        ),
        p_note
    );

    RETURN jsonb_build_object(
        'ok', true,
        'user_id', p_user_id,
        'plan_id', p_plan_id,
        'verification_status', p_verification_status
    );
END;
$$;

COMMENT ON FUNCTION public.admin_update_marketplace_seller(uuid, text, text, text, timestamptz, text, text) IS
    'Actualiza plan, tipo y verificación de un vendedor, sincroniza profiles y registra auditoría (solo staff).';

-- -----------------------------------------------------------------------------
-- 3.5 Cambio de estado comercial / patrocinio de una publicación
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_set_marketplace_item_state(
    p_item_id              uuid,
    p_status               text    DEFAULT NULL,
    p_is_sponsored         boolean DEFAULT NULL,
    p_sponsor_badge_text   text    DEFAULT NULL,
    p_note                 text    DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_actor          uuid := auth.uid();
    v_old_status     text;
    v_old_sponsored  boolean;
    v_old_badge      text;
    v_old_expires    timestamptz;
    v_item_user      uuid;
    v_legal_hold     boolean;
    v_new_status     text;
    v_new_sponsored  boolean;
    v_new_badge      text;
    v_new_expires    timestamptz;
    v_item_plan      public.marketplace_plans;
    v_claims         text;
    v_sub            text;
BEGIN
    IF NOT public.is_marketplace_staff(v_actor) THEN
        RAISE EXCEPTION 'Solo el personal de PEMTREE (administrador o moderador) puede cambiar el estado de una publicación'
            USING ERRCODE = '42501';
    END IF;

    SELECT mi.status, mi.is_sponsored, mi.sponsor_badge_text, mi.is_legal_hold,
           mi.expires_at, mi.user_id
    INTO v_old_status, v_old_sponsored, v_old_badge, v_legal_hold,
         v_old_expires, v_item_user
    FROM public.marketplace_items mi
    WHERE mi.id = p_item_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La publicación % no existe', p_item_id
            USING ERRCODE = 'P0002';
    END IF;

    -- Art. 20/21: una publicación bajo retención legal es intocable.
    IF v_legal_hold THEN
        RAISE EXCEPTION 'No se puede modificar un ítem con retención legal'
            USING ERRCODE = '23514';
    END IF;

    -- El estado de moderación NO se toca aquí: existen ocultar/restaurar_contenido_moderado.
    IF p_status IS NOT NULL
       AND p_status NOT IN ('available', 'reserved', 'sold', 'paused', 'archived') THEN
        RAISE EXCEPTION 'Estado % no permitido (válidos: available, reserved, sold, paused, archived)', p_status
            USING ERRCODE = '22023';
    END IF;

    IF p_sponsor_badge_text IS NULL THEN
        v_new_badge := v_old_badge;
    ELSE
        v_new_badge := NULLIF(btrim(p_sponsor_badge_text), '');
        IF v_new_badge IS NOT NULL AND length(v_new_badge) > 40 THEN
            RAISE EXCEPTION 'La insignia de patrocinio no puede superar los 40 caracteres'
                USING ERRCODE = '23514';
        END IF;
    END IF;

    v_new_status    := COALESCE(p_status, v_old_status);
    v_new_sponsored := COALESCE(p_is_sponsored, v_old_sponsored);

    -- B1: el trigger `enforce_marketplace_item_rules` no recalcula la vigencia
    -- cuando se suspende el contexto JWT, así que se replica aquí la regla del
    -- plan: free reactivado desde pausa/vencido renueva 14 días; los planes de
    -- pago no caducan; y los estados no activos conservan la vigencia previa.
    v_item_plan := public.get_effective_seller_plan(v_item_user);

    v_new_expires := CASE
        WHEN v_new_status IN ('available', 'reserved') AND v_item_plan.id = 'free' THEN
            CASE
                WHEN v_old_status NOT IN ('available', 'reserved')
                     OR v_old_expires IS NULL
                     OR v_old_expires <= now()
                THEN now() + interval '14 days'
                ELSE v_old_expires
            END
        WHEN v_new_status IN ('available', 'reserved') THEN NULL
        ELSE v_old_expires
    END;

    IF v_new_status IS DISTINCT FROM v_old_status
       OR v_new_sponsored IS DISTINCT FROM v_old_sponsored
       OR v_new_badge IS DISTINCT FROM v_old_badge
       OR v_new_expires IS DISTINCT FROM v_old_expires THEN

        -- El trigger público `enforce_content_immutability_and_legal_hold`
        -- (migración 20261110000000) restringe a moderadores/administradores a
        -- metadatos de moderación, impidiendo status/patrocinio. Esta operación
        -- ya fue autorizada como staff y valida la retención legal arriba, así
        -- que se ejecuta como tarea de sistema: se suspende temporalmente el
        -- contexto JWT (las GUC son locales a la transacción) y se restaura de
        -- inmediato. NO se altera contenido del autor (Art. 3).
        v_claims := current_setting('request.jwt.claims', true);
        v_sub    := current_setting('request.jwt.claim.sub', true);

        PERFORM set_config('request.jwt.claims', '', true);
        PERFORM set_config('request.jwt.claim.sub', '', true);

        UPDATE public.marketplace_items
        SET status              = v_new_status,
            is_sponsored        = v_new_sponsored,
            sponsor_badge_text  = v_new_badge,
            expires_at          = v_new_expires,
            updated_at          = now()
        WHERE id = p_item_id;

        PERFORM set_config('request.jwt.claims', COALESCE(v_claims, ''), true);
        PERFORM set_config('request.jwt.claim.sub', COALESCE(v_sub, ''), true);
    END IF;

    INSERT INTO public.marketplace_admin_audit (
        actor_id, action, target_type, target_id, details, note
    ) VALUES (
        v_actor,
        'item.state',
        'item',
        p_item_id::text,
        jsonb_build_object(
            'status_before',       v_old_status,
            'status_after',        v_new_status,
            'is_sponsored_before', v_old_sponsored,
            'is_sponsored_after',  v_new_sponsored,
            'badge_before',        v_old_badge,
            'badge_after',         v_new_badge,
            'expires_before',      v_old_expires,
            'expires_after',       v_new_expires
        ),
        p_note
    );

    RETURN jsonb_build_object(
        'ok', true,
        'id', p_item_id,
        'status', v_new_status,
        'is_sponsored', v_new_sponsored
    );
END;
$$;

COMMENT ON FUNCTION public.admin_set_marketplace_item_state(uuid, text, boolean, text, text) IS
    'Cambia estado comercial y patrocinio de una publicación sin tocar contenido ni moderación (solo staff).';

-- -----------------------------------------------------------------------------
-- 3.6 Catálogo de planes (incluye inactivos y conteos)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_list_marketplace_plans()
RETURNS TABLE (
    id                      text,
    name                    text,
    price_monthly           numeric,
    max_active_items        integer,
    max_images_per_item     integer,
    allow_video             boolean,
    auto_sponsor_items      boolean,
    hide_competitor_related boolean,
    default_badge_text      text,
    features                jsonb,
    sort_order              integer,
    is_active               boolean,
    sellers_count           bigint,
    active_items            bigint,
    created_at              timestamptz,
    updated_at              timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF NOT public.is_marketplace_staff(auth.uid()) THEN
        RAISE EXCEPTION 'Solo el personal de PEMTREE (administrador o moderador) puede consultar el catálogo administrativo de planes'
            USING ERRCODE = '42501';
    END IF;

    RETURN QUERY
    WITH effective AS (
        SELECT sp.user_id, COALESCE(ep.id, 'free') AS plan_id
        FROM public.seller_profiles sp
        LEFT JOIN LATERAL public.get_effective_seller_plan(sp.user_id) ep ON true
    ),
    seller_counts AS (
        SELECT e.plan_id, count(*)::bigint AS cnt
        FROM effective e
        GROUP BY e.plan_id
    ),
    active_by_seller AS (
        SELECT mi.user_id, count(*)::bigint AS cnt
        FROM public.marketplace_items mi
        WHERE mi.deleted_at IS NULL
          AND mi.status IN ('available', 'reserved')
        GROUP BY mi.user_id
    ),
    item_counts AS (
        SELECT e.plan_id, sum(a.cnt)::bigint AS cnt
        FROM effective e
        JOIN active_by_seller a ON a.user_id = e.user_id
        GROUP BY e.plan_id
    )
    SELECT
        mp.id,
        mp.name,
        mp.price_monthly,
        mp.max_active_items,
        mp.max_images_per_item,
        mp.allow_video,
        mp.auto_sponsor_items,
        mp.hide_competitor_related,
        mp.default_badge_text,
        mp.features,
        mp.sort_order,
        mp.is_active,
        COALESCE(sc.cnt, 0)::bigint AS sellers_count,
        COALESCE(ic.cnt, 0)::bigint AS active_items,
        mp.created_at,
        mp.updated_at
    FROM public.marketplace_plans mp
    LEFT JOIN seller_counts sc ON sc.plan_id = mp.id
    LEFT JOIN item_counts   ic ON ic.plan_id = mp.id
    ORDER BY mp.sort_order, mp.id;
END;
$$;

COMMENT ON FUNCTION public.admin_list_marketplace_plans() IS
    'Catálogo completo de planes con conteos de vendedores y publicaciones activas (solo staff).';

-- -----------------------------------------------------------------------------
-- 3.7 Alta / edición de planes (exclusivo administrador)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_upsert_marketplace_plan(p_payload jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_actor    uuid := auth.uid();
    v_id       text;
    v_existing public.marketplace_plans;
    v_name     text;
    v_price    numeric;
    v_max_items integer;
    v_max_imgs integer;
    v_video    boolean;
    v_auto     boolean;
    v_hide     boolean;
    v_badge    text;
    v_features jsonb;
    v_sort     integer;
    v_active   boolean;
BEGIN
    -- Los planes son configuración global: solo el administrador (no moderador).
    IF NOT public.is_pemtree_admin(v_actor) THEN
        RAISE EXCEPTION 'Solo un administrador de PEMTREE puede crear o modificar planes del Marketplace'
            USING ERRCODE = '42501';
    END IF;

    IF p_payload IS NULL OR jsonb_typeof(p_payload) <> 'object' THEN
        RAISE EXCEPTION 'El payload del plan debe ser un objeto JSON'
            USING ERRCODE = '22023';
    END IF;

    v_id := NULLIF(btrim(COALESCE(p_payload ->> 'id', '')), '');
    IF v_id IS NULL OR v_id !~ '^[a-z0-9_]{2,40}$' THEN
        RAISE EXCEPTION 'Identificador de plan inválido: debe cumplir ^[a-z0-9_]{2,40}$'
            USING ERRCODE = '22023';
    END IF;

    SELECT * INTO v_existing
    FROM public.marketplace_plans mp
    WHERE mp.id = v_id;

    -- name: obligatorio en alta, no vacío y <= 60 caracteres.
    -- W2: el plan base `free` es inmutable en nombre y precio.
    IF v_id = 'free' THEN
        v_name := 'Estudiante';
    ELSIF p_payload ? 'name' THEN
        v_name := NULLIF(btrim(p_payload ->> 'name'), '');
        IF v_name IS NULL OR length(v_name) > 60 THEN
            RAISE EXCEPTION 'El nombre del plan es obligatorio y no puede superar 60 caracteres'
                USING ERRCODE = '22023';
        END IF;
    ELSIF v_existing.id IS NULL THEN
        RAISE EXCEPTION 'El nombre del plan es obligatorio'
            USING ERRCODE = '22023';
    ELSE
        v_name := v_existing.name;
    END IF;

    -- price_monthly >= 0
    IF v_id = 'free' THEN
        v_price := 0;
    ELSIF p_payload ? 'price_monthly' THEN
        BEGIN
            v_price := (p_payload ->> 'price_monthly')::numeric;
        EXCEPTION WHEN others THEN
            RAISE EXCEPTION 'price_monthly debe ser numérico'
                USING ERRCODE = '22023';
        END;
        IF v_price < 0 THEN
            RAISE EXCEPTION 'price_monthly no puede ser negativo'
                USING ERRCODE = '22023';
        END IF;
    ELSIF v_existing.id IS NULL THEN
        v_price := 0;
    ELSE
        v_price := v_existing.price_monthly;
    END IF;

    -- max_active_items >= 0 (0 = ilimitado)
    IF p_payload ? 'max_active_items' THEN
        BEGIN
            v_max_items := (p_payload ->> 'max_active_items')::integer;
        EXCEPTION WHEN others THEN
            RAISE EXCEPTION 'max_active_items debe ser un entero'
                USING ERRCODE = '22023';
        END;
        IF v_max_items < 0 THEN
            RAISE EXCEPTION 'max_active_items no puede ser negativo (0 = ilimitado)'
                USING ERRCODE = '22023';
        END IF;
    ELSIF v_existing.id IS NULL THEN
        v_max_items := 3;
    ELSE
        v_max_items := v_existing.max_active_items;
    END IF;

    -- max_images_per_item entre 0 y 20
    IF p_payload ? 'max_images_per_item' THEN
        BEGIN
            v_max_imgs := (p_payload ->> 'max_images_per_item')::integer;
        EXCEPTION WHEN others THEN
            RAISE EXCEPTION 'max_images_per_item debe ser un entero'
                USING ERRCODE = '22023';
        END;
        IF v_max_imgs < 0 OR v_max_imgs > 20 THEN
            RAISE EXCEPTION 'max_images_per_item debe estar entre 0 y 20'
                USING ERRCODE = '22023';
        END IF;
    ELSIF v_existing.id IS NULL THEN
        v_max_imgs := 2;
    ELSE
        v_max_imgs := v_existing.max_images_per_item;
    END IF;

    IF p_payload ? 'allow_video' THEN
        BEGIN
            v_video := (p_payload ->> 'allow_video')::boolean;
        EXCEPTION WHEN others THEN
            RAISE EXCEPTION 'allow_video debe ser booleano' USING ERRCODE = '22023';
        END;
    ELSIF v_existing.id IS NULL THEN
        v_video := false;
    ELSE
        v_video := v_existing.allow_video;
    END IF;

    IF p_payload ? 'auto_sponsor_items' THEN
        BEGIN
            v_auto := (p_payload ->> 'auto_sponsor_items')::boolean;
        EXCEPTION WHEN others THEN
            RAISE EXCEPTION 'auto_sponsor_items debe ser booleano' USING ERRCODE = '22023';
        END;
    ELSIF v_existing.id IS NULL THEN
        v_auto := false;
    ELSE
        v_auto := v_existing.auto_sponsor_items;
    END IF;

    IF p_payload ? 'hide_competitor_related' THEN
        BEGIN
            v_hide := (p_payload ->> 'hide_competitor_related')::boolean;
        EXCEPTION WHEN others THEN
            RAISE EXCEPTION 'hide_competitor_related debe ser booleano' USING ERRCODE = '22023';
        END;
    ELSIF v_existing.id IS NULL THEN
        v_hide := false;
    ELSE
        v_hide := v_existing.hide_competitor_related;
    END IF;

    IF p_payload ? 'default_badge_text' THEN
        v_badge := NULLIF(btrim(COALESCE(p_payload ->> 'default_badge_text', '')), '');
    ELSIF v_existing.id IS NULL THEN
        v_badge := NULL;
    ELSE
        v_badge := v_existing.default_badge_text;
    END IF;

    IF v_badge IS NOT NULL AND length(v_badge) > 40 THEN
        RAISE EXCEPTION 'default_badge_text no puede superar los 40 caracteres'
            USING ERRCODE = '23514';
    END IF;

    -- features: arreglo JSON de cadenas.
    IF p_payload ? 'features' THEN
        v_features := p_payload -> 'features';
        IF v_features IS NULL OR jsonb_typeof(v_features) <> 'array' THEN
            RAISE EXCEPTION 'features debe ser un arreglo JSON de cadenas'
                USING ERRCODE = '22023';
        END IF;
        IF EXISTS (
            SELECT 1
            FROM jsonb_array_elements(v_features) AS f(elem)
            WHERE jsonb_typeof(f.elem) <> 'string'
        ) THEN
            RAISE EXCEPTION 'features solo admite cadenas de texto'
                USING ERRCODE = '22023';
        END IF;
    ELSIF v_existing.id IS NULL THEN
        v_features := '[]'::jsonb;
    ELSE
        v_features := v_existing.features;
    END IF;

    IF p_payload ? 'sort_order' THEN
        BEGIN
            v_sort := (p_payload ->> 'sort_order')::integer;
        EXCEPTION WHEN others THEN
            RAISE EXCEPTION 'sort_order debe ser un entero' USING ERRCODE = '22023';
        END;
    ELSIF v_existing.id IS NULL THEN
        v_sort := 0;
    ELSE
        v_sort := v_existing.sort_order;
    END IF;

    IF p_payload ? 'is_active' THEN
        BEGIN
            v_active := (p_payload ->> 'is_active')::boolean;
        EXCEPTION WHEN others THEN
            RAISE EXCEPTION 'is_active debe ser booleano' USING ERRCODE = '22023';
        END;
    ELSIF v_existing.id IS NULL THEN
        v_active := true;
    ELSE
        v_active := v_existing.is_active;
    END IF;

    -- El plan base del Marketplace no puede quedar inactivo (UX-MKT-018).
    IF v_id = 'free' AND v_active = false THEN
        RAISE EXCEPTION 'El plan free es obligatorio y no puede desactivarse'
            USING ERRCODE = '23514';
    END IF;

    INSERT INTO public.marketplace_plans (
        id, name, price_monthly, max_active_items, max_images_per_item,
        allow_video, auto_sponsor_items, hide_competitor_related,
        default_badge_text, features, sort_order, is_active
    ) VALUES (
        v_id, v_name, v_price, v_max_items, v_max_imgs,
        v_video, v_auto, v_hide,
        v_badge, v_features, v_sort, v_active
    )
    ON CONFLICT (id) DO UPDATE SET
        name                    = EXCLUDED.name,
        price_monthly           = EXCLUDED.price_monthly,
        max_active_items        = EXCLUDED.max_active_items,
        max_images_per_item     = EXCLUDED.max_images_per_item,
        allow_video             = EXCLUDED.allow_video,
        auto_sponsor_items      = EXCLUDED.auto_sponsor_items,
        hide_competitor_related = EXCLUDED.hide_competitor_related,
        default_badge_text      = EXCLUDED.default_badge_text,
        features                = EXCLUDED.features,
        sort_order              = EXCLUDED.sort_order,
        is_active               = EXCLUDED.is_active,
        updated_at              = now();

    INSERT INTO public.marketplace_admin_audit (
        actor_id, action, target_type, target_id, details, note
    ) VALUES (
        v_actor,
        'plan.upsert',
        'plan',
        v_id,
        jsonb_build_object(
            'created',              v_existing.id IS NULL,
            'name',                 v_name,
            'price_monthly',        v_price,
            'max_active_items',     v_max_items,
            'max_images_per_item',  v_max_imgs,
            'is_active',            v_active
        ),
        NULL
    );

    RETURN jsonb_build_object('ok', true, 'plan_id', v_id);
END;
$$;

COMMENT ON FUNCTION public.admin_upsert_marketplace_plan(jsonb) IS
    'Crea o edita un plan del Marketplace con validación estricta (solo administrador).';

-- -----------------------------------------------------------------------------
-- 3.8 Activación / desactivación de planes (exclusivo administrador)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_set_marketplace_plan_active(
    p_plan_id   text,
    p_is_active boolean,
    p_note      text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_actor     uuid := auth.uid();
    v_old_active boolean;
BEGIN
    IF NOT public.is_pemtree_admin(v_actor) THEN
        RAISE EXCEPTION 'Solo un administrador de PEMTREE puede activar o desactivar planes del Marketplace'
            USING ERRCODE = '42501';
    END IF;

    IF p_is_active IS NULL THEN
        RAISE EXCEPTION 'p_is_active es obligatorio'
            USING ERRCODE = '22023';
    END IF;

    SELECT mp.is_active INTO v_old_active
    FROM public.marketplace_plans mp
    WHERE mp.id = p_plan_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El plan % no existe', p_plan_id
            USING ERRCODE = 'P0002';
    END IF;

    -- El plan base del Marketplace no puede desaparecer del catálogo público.
    IF p_is_active = false AND p_plan_id = 'free' THEN
        RAISE EXCEPTION 'El plan free es obligatorio y no puede desactivarse'
            USING ERRCODE = '23514';
    END IF;

    UPDATE public.marketplace_plans
    SET is_active = p_is_active,
        updated_at = now()
    WHERE id = p_plan_id;

    INSERT INTO public.marketplace_admin_audit (
        actor_id, action, target_type, target_id, details, note
    ) VALUES (
        v_actor,
        CASE WHEN p_is_active THEN 'plan.activate' ELSE 'plan.deactivate' END,
        'plan',
        p_plan_id,
        jsonb_build_object('is_active_before', v_old_active, 'is_active_after', p_is_active),
        p_note
    );

    RETURN jsonb_build_object('ok', true, 'plan_id', p_plan_id, 'is_active', p_is_active);
END;
$$;

COMMENT ON FUNCTION public.admin_set_marketplace_plan_active(text, boolean, text) IS
    'Activa o desactiva un plan del Marketplace, impidiendo desactivar el plan free (solo administrador).';

-- -----------------------------------------------------------------------------
-- 3.9 Serie diaria de engagement
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_get_marketplace_engagement(p_days integer DEFAULT 7)
RETURNS TABLE (
    day            date,
    views          bigint,
    contact_clicks bigint,
    shares         bigint,
    bookmarks      bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_days  integer;
    v_start date;
BEGIN
    IF NOT public.is_marketplace_staff(auth.uid()) THEN
        RAISE EXCEPTION 'Solo el personal de PEMTREE (administrador o moderador) puede consultar la analítica del Marketplace'
            USING ERRCODE = '42501';
    END IF;

    v_days  := LEAST(GREATEST(COALESCE(p_days, 7), 1), 90);
    v_start := current_date - (v_days - 1);

    RETURN QUERY
    WITH span AS (
        SELECT generate_series(v_start, current_date, interval '1 day')::date AS d
    ),
    ev AS (
        SELECT e.created_at::date                                    AS d,
               count(*) FILTER (WHERE e.event_type = 'view')          AS views,
               count(*) FILTER (WHERE e.event_type LIKE 'click\_%')   AS contact_clicks,
               count(*) FILTER (WHERE e.event_type = 'share')         AS shares
        FROM public.marketplace_item_events e
        WHERE e.created_at >= v_start
        GROUP BY 1
    ),
    bm AS (
        SELECT b.created_at::date AS d, count(*) AS bookmarks
        FROM public.marketplace_bookmarks b
        WHERE b.created_at >= v_start
        GROUP BY 1
    )
    SELECT s.d,
           COALESCE(ev.views, 0)::bigint,
           COALESCE(ev.contact_clicks, 0)::bigint,
           COALESCE(ev.shares, 0)::bigint,
           COALESCE(bm.bookmarks, 0)::bigint
    FROM span s
    LEFT JOIN ev ON ev.d = s.d
    LEFT JOIN bm ON bm.d = s.d
    ORDER BY s.d;
END;
$$;

COMMENT ON FUNCTION public.admin_get_marketplace_engagement(integer) IS
    'Serie diaria de vistas, clics de contacto, compartidos y guardados (1..90 días, solo staff).';

-- -----------------------------------------------------------------------------
-- 3.10 Bitácora de auditoría
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_list_marketplace_audit(p_limit integer DEFAULT 100)
RETURNS SETOF public.marketplace_admin_audit
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_limit integer;
BEGIN
    IF NOT public.is_marketplace_staff(auth.uid()) THEN
        RAISE EXCEPTION 'Solo el personal de PEMTREE (administrador o moderador) puede consultar la auditoría del Marketplace'
            USING ERRCODE = '42501';
    END IF;

    v_limit := LEAST(GREATEST(COALESCE(p_limit, 100), 1), 500);

    RETURN QUERY
    SELECT a.*
    FROM public.marketplace_admin_audit a
    ORDER BY a.created_at DESC, a.id DESC
    LIMIT v_limit;
END;
$$;

COMMENT ON FUNCTION public.admin_list_marketplace_audit(integer) IS
    'Últimas acciones administrativas del Marketplace, más recientes primero (solo staff).';

-- -----------------------------------------------------------------------------
-- 3.11 Borrado administrativo de una solicitud de patrocinio
-- -----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.admin_delete_sponsor_request(uuid);

CREATE OR REPLACE FUNCTION public.admin_delete_sponsor_request(
    p_request_id uuid,
    p_note       text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_actor      uuid := auth.uid();
    v_brand_name text;
    v_status     text;
BEGIN
    -- Las solicitudes de patrocinio solo las elimina el administrador.
    IF NOT public.is_pemtree_admin(v_actor) THEN
        RAISE EXCEPTION 'Solo un administrador de PEMTREE puede eliminar solicitudes de patrocinio'
            USING ERRCODE = '42501';
    END IF;

    IF p_request_id IS NULL THEN
        RAISE EXCEPTION 'La solicitud de patrocinio no existe'
            USING ERRCODE = 'P0002';
    END IF;

    SELECT sr.brand_name, sr.status
    INTO v_brand_name, v_status
    FROM public.sponsor_requests sr
    WHERE sr.id = p_request_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'La solicitud de patrocinio % no existe', p_request_id
            USING ERRCODE = 'P0002';
    END IF;

    -- Auditoría previa al borrado (guarda la foto mínima, sin PII de contacto).
    INSERT INTO public.marketplace_admin_audit (
        actor_id, action, target_type, target_id, details, note
    ) VALUES (
        v_actor,
        'sponsor_request.delete',
        'sponsor_request',
        p_request_id::text,
        jsonb_build_object(
            'brand_name', v_brand_name,
            'status',     v_status
        ),
        NULLIF(btrim(p_note), '')
    );

    DELETE FROM public.sponsor_requests
    WHERE id = p_request_id;

    RETURN jsonb_build_object('ok', true, 'request_id', p_request_id);
END;
$$;

COMMENT ON FUNCTION public.admin_delete_sponsor_request(uuid, text) IS
    'Elimina una solicitud de patrocinio dejando rastro y motivo en la auditoría (solo administrador).';

-- =============================================================================
-- BLOQUE 4: PRIVILEGIOS
-- =============================================================================

-- 4.1 Bitácora: solo lectura para staff; escritura exclusiva de las RPC definer.
REVOKE ALL ON TABLE public.marketplace_admin_audit FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.marketplace_admin_audit TO authenticated;
GRANT ALL    ON TABLE public.marketplace_admin_audit TO postgres, service_role;

-- 4.2 Helper de staff.
REVOKE ALL ON FUNCTION public.is_marketplace_staff(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_marketplace_staff(uuid) TO authenticated, service_role;

-- 4.3 RPCs administrativas: nunca anon ni PUBLIC.
REVOKE ALL ON FUNCTION public.admin_marketplace_overview() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_list_marketplace_items(text, text, integer, text, integer, integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_list_marketplace_sellers(text, text, text, integer, integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_update_marketplace_seller(uuid, text, text, text, timestamptz, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_set_marketplace_item_state(uuid, text, boolean, text, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_list_marketplace_plans() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_upsert_marketplace_plan(jsonb) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_set_marketplace_plan_active(text, boolean, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_get_marketplace_engagement(integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_list_marketplace_audit(integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_delete_sponsor_request(uuid, text) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.admin_marketplace_overview() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_list_marketplace_items(text, text, integer, text, integer, integer) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_list_marketplace_sellers(text, text, text, integer, integer) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_update_marketplace_seller(uuid, text, text, text, timestamptz, text, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_set_marketplace_item_state(uuid, text, boolean, text, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_list_marketplace_plans() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_upsert_marketplace_plan(jsonb) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_set_marketplace_plan_active(text, boolean, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_get_marketplace_engagement(integer) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_list_marketplace_audit(integer) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_delete_sponsor_request(uuid, text) TO authenticated, service_role;

-- =============================================================================
-- BLOQUE 5: SOPORTE AL PANEL EXISTENTE (SOLICITUDES DE PATROCINIO)
-- =============================================================================
-- El panel edita los datos de contacto de una solicitud. Se concede UPDATE
-- únicamente por columna: `user_id` y `status` siguen fuera del alcance del
-- cliente y el trigger `guard_sponsor_request_workflow` impide que un no-admin
-- cambie `status`/`user_id` (42501) incluso con el privilegio de columna.
GRANT UPDATE (brand_name, contact_name, contact_phone, email, proposal_details, expected_placement)
    ON TABLE public.sponsor_requests TO authenticated;

-- Defensa en profundidad: anon no debe poder escribir solicitudes.
REVOKE INSERT, UPDATE, DELETE ON TABLE public.sponsor_requests FROM anon;

COMMIT;
