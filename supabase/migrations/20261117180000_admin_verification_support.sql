-- =============================================================================
-- Migración: 20261117180000_admin_verification_support.sql
-- Actualiza el panel administrativo al modelo Zero-PII y al alta de comercios
-- por soporte: sin nombre real, CUI, carné en claro ni DPI.
-- =============================================================================

-- =============================================================================
-- 0. Auditoría de verificaciones administrativas
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.verification_admin_audit (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id       uuid REFERENCES auth.users(id) ON DELETE SET NULL,
    target_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    action         text NOT NULL CHECK (action IN (
        'student_verified', 'student_rejected', 'student_unverified',
        'merchant_upserted'
    )),
    note           text,
    details        jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_verification_admin_audit_target
    ON public.verification_admin_audit (target_user_id, created_at DESC);

ALTER TABLE public.verification_admin_audit ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS verification_admin_audit_staff_read
    ON public.verification_admin_audit;
CREATE POLICY verification_admin_audit_staff_read
    ON public.verification_admin_audit
    FOR SELECT
    TO authenticated
    USING (
        public.is_pemtree_admin(auth.uid())
        OR public.is_pemtree_moderator(auth.uid())
    );

REVOKE ALL ON TABLE public.verification_admin_audit FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.verification_admin_audit TO authenticated, service_role;

COMMENT ON TABLE public.verification_admin_audit IS
    'Bitácora de verificaciones manuales de estudiantes y altas de comercios. Sin PII: solo IDs, acción y metadatos.';

-- =============================================================================
-- 1. seller_profiles.business_category
-- =============================================================================
ALTER TABLE public.seller_profiles
    ADD COLUMN IF NOT EXISTS business_category text;

ALTER TABLE public.seller_profiles
    DROP CONSTRAINT IF EXISTS seller_profiles_business_category_len;

ALTER TABLE public.seller_profiles
    ADD CONSTRAINT seller_profiles_business_category_len
    CHECK (business_category IS NULL OR char_length(business_category) <= 50);

-- =============================================================================
-- 2. get_admin_users_summary sin PII
-- =============================================================================
DROP FUNCTION IF EXISTS public.get_admin_users_summary();

CREATE OR REPLACE FUNCTION public.get_admin_users_summary()
RETURNS TABLE (
    user_id                  uuid,
    email                    text,
    alias                    text,
    carrera                  text,
    is_verified              boolean,
    verification_status      text,
    seller_verification_status text,
    has_carne_hash           boolean,
    reputation_score         numeric,
    posts                    bigint,
    comments                 bigint,
    groups                   bigint,
    marketplace              bigint,
    likes                    bigint,
    upvotes                  bigint,
    reviews                  bigint,
    reports                  bigint,
    actions                  bigint,
    "lastActivity"           timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_uid uuid := auth.uid();
BEGIN
    IF v_uid IS NULL OR NOT (
        public.is_pemtree_admin(v_uid) OR public.is_pemtree_moderator(v_uid)
    ) THEN
        RAISE EXCEPTION 'Permiso denegado: se requieren privilegios de administrador o moderador.'
            USING ERRCODE = '42501';
    END IF;

    RETURN QUERY
    WITH relevant_users AS (
        SELECT p.id AS uid FROM public.profiles p
        UNION
        SELECT pa.user_id FROM public.post_authors pa WHERE pa.user_id IS NOT NULL
        UNION
        SELECT ca.user_id FROM public.comment_authors ca WHERE ca.user_id IS NOT NULL
        UNION
        SELECT sg.user_id FROM public.student_groups sg WHERE sg.user_id IS NOT NULL
        UNION
        SELECT mi.user_id FROM public.marketplace_items mi WHERE mi.user_id IS NOT NULL
        UNION
        SELECT er.reporter_id FROM public.entity_reports er WHERE er.reporter_id IS NOT NULL
        UNION
        SELECT mal.moderator_id FROM public.moderation_audit_log mal WHERE mal.moderator_id IS NOT NULL
    ),
    posts_agg AS (
        SELECT pa.user_id, count(*)::bigint AS cnt, max(pa.created_at) AS last_dt
        FROM public.post_authors pa
        WHERE pa.user_id IS NOT NULL
        GROUP BY pa.user_id
    ),
    comments_agg AS (
        SELECT ca.user_id, count(*)::bigint AS cnt, max(ca.created_at) AS last_dt
        FROM public.comment_authors ca
        WHERE ca.user_id IS NOT NULL
        GROUP BY ca.user_id
    ),
    groups_agg AS (
        SELECT
            sg.user_id,
            count(*)::bigint AS cnt,
            max(sg.created_at) AS last_dt,
            (array_agg(sg.author_alias ORDER BY sg.created_at ASC)
                FILTER (WHERE sg.author_alias IS NOT NULL AND btrim(sg.author_alias) <> ''))[1] AS first_alias
        FROM public.student_groups sg
        WHERE sg.user_id IS NOT NULL
        GROUP BY sg.user_id
    ),
    marketplace_agg AS (
        SELECT
            mi.user_id,
            count(*)::bigint AS cnt,
            max(mi.created_at) AS last_dt,
            (array_agg(mi.author_alias ORDER BY mi.created_at ASC)
                FILTER (WHERE mi.author_alias IS NOT NULL AND btrim(mi.author_alias) <> ''))[1] AS first_alias
        FROM public.marketplace_items mi
        WHERE mi.user_id IS NOT NULL
        GROUP BY mi.user_id
    ),
    likes_agg AS (
        SELECT pl.user_id, count(*)::bigint AS cnt, max(pl.created_at) AS last_dt
        FROM public.post_likes pl
        WHERE pl.user_id IS NOT NULL
        GROUP BY pl.user_id
    ),
    group_upvotes_agg AS (
        SELECT sgu.user_id, count(*)::bigint AS cnt, max(sgu.created_at) AS last_dt
        FROM public.student_group_upvotes sgu
        WHERE sgu.user_id IS NOT NULL
        GROUP BY sgu.user_id
    ),
    marketplace_upvotes_agg AS (
        SELECT mu.user_id, count(*)::bigint AS cnt, max(mu.created_at) AS last_dt
        FROM public.marketplace_upvotes mu
        WHERE mu.user_id IS NOT NULL
        GROUP BY mu.user_id
    ),
    reviews_agg AS (
        SELECT sr.user_id, count(*)::bigint AS cnt, max(sr.created_at) AS last_dt
        FROM public.seccion_reviews sr
        WHERE sr.user_id IS NOT NULL
        GROUP BY sr.user_id
    ),
    reports_agg AS (
        SELECT er.reporter_id AS user_id, count(*)::bigint AS cnt, max(er.created_at) AS last_dt
        FROM public.entity_reports er
        WHERE er.reporter_id IS NOT NULL
        GROUP BY er.reporter_id
    ),
    audit_agg AS (
        SELECT mal.moderator_id AS user_id, count(*)::bigint AS cnt, max(mal.created_at) AS last_dt
        FROM public.moderation_audit_log mal
        WHERE mal.moderator_id IS NOT NULL
        GROUP BY mal.moderator_id
    )
    SELECT
        u.uid AS user_id,
        COALESCE(au.email, '')::text AS email,
        COALESCE(g.first_alias, m.first_alias, '')::text AS alias,
        COALESCE(p.carrera, '')::text AS carrera,
        COALESCE(p.is_verified, false)::boolean AS is_verified,
        COALESCE(p.verification_status, 'unverified')::text AS verification_status,
        COALESCE(p.seller_verification_status, 'unverified')::text AS seller_verification_status,
        (p.carne_hash IS NOT NULL)::boolean AS has_carne_hash,
        COALESCE(p.reputation_score, 5.0)::numeric AS reputation_score,
        COALESCE(po.cnt, 0)::bigint AS posts,
        COALESCE(co.cnt, 0)::bigint AS comments,
        COALESCE(g.cnt, 0)::bigint AS groups,
        COALESCE(m.cnt, 0)::bigint AS marketplace,
        COALESCE(l.cnt, 0)::bigint AS likes,
        (COALESCE(gu.cnt, 0) + COALESCE(mu.cnt, 0))::bigint AS upvotes,
        COALESCE(r.cnt, 0)::bigint AS reviews,
        COALESCE(rep.cnt, 0)::bigint AS reports,
        COALESCE(aud.cnt, 0)::bigint AS actions,
        GREATEST(
            p.created_at,
            po.last_dt,
            co.last_dt,
            g.last_dt,
            m.last_dt,
            l.last_dt,
            gu.last_dt,
            mu.last_dt,
            r.last_dt,
            rep.last_dt,
            aud.last_dt
        ) AS "lastActivity"
    FROM relevant_users u
    LEFT JOIN auth.users au ON au.id = u.uid
    LEFT JOIN public.profiles p ON p.id = u.uid
    LEFT JOIN posts_agg po ON po.user_id = u.uid
    LEFT JOIN comments_agg co ON co.user_id = u.uid
    LEFT JOIN groups_agg g ON g.user_id = u.uid
    LEFT JOIN marketplace_agg m ON m.user_id = u.uid
    LEFT JOIN likes_agg l ON l.user_id = u.uid
    LEFT JOIN group_upvotes_agg gu ON gu.user_id = u.uid
    LEFT JOIN marketplace_upvotes_agg mu ON mu.user_id = u.uid
    LEFT JOIN reviews_agg r ON r.user_id = u.uid
    LEFT JOIN reports_agg rep ON rep.user_id = u.uid
    LEFT JOIN audit_agg aud ON aud.user_id = u.uid
    ORDER BY "lastActivity" DESC NULLS LAST;
END;
$$;

REVOKE ALL ON FUNCTION public.get_admin_users_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_admin_users_summary() TO authenticated, service_role;

COMMENT ON FUNCTION public.get_admin_users_summary() IS
    'Resumen administrativo de usuarios sin PII: correo de cuenta, alias, carrera, estados y métricas.';

-- =============================================================================
-- 3. Verificación manual de estudiantes (solo administradores)
-- =============================================================================
CREATE OR REPLACE FUNCTION public.admin_set_student_verification(
    p_user_id uuid,
    p_status  text,
    p_carne   text DEFAULT NULL,
    p_note    text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_actor       uuid := auth.uid();
    v_status      text := lower(btrim(COALESCE(p_status, '')));
    v_carne       text := btrim(COALESCE(p_carne, ''));
    v_carne_year  integer;
    v_carne_hash  text;
    v_note        text := NULLIF(btrim(COALESCE(p_note, '')), '');
    v_has_hash    boolean := false;
    v_prev_claims text;
BEGIN
    IF v_actor IS NULL OR NOT public.is_pemtree_admin(v_actor) THEN
        RETURN jsonb_build_object('ok', false, 'code', 'not_authorized');
    END IF;

    IF p_user_id IS NULL OR NOT EXISTS (
        SELECT 1 FROM auth.users u WHERE u.id = p_user_id
    ) THEN
        RETURN jsonb_build_object('ok', false, 'code', 'user_not_found');
    END IF;

    IF v_status NOT IN ('verified', 'rejected', 'unverified') THEN
        RETURN jsonb_build_object('ok', false, 'code', 'invalid_status');
    END IF;

    v_prev_claims := current_setting('request.jwt.claims', true);
    PERFORM set_config(
        'request.jwt.claims',
        jsonb_build_object('role', 'service_role', 'sub', v_actor::text)::text,
        true
    );

    INSERT INTO public.profiles (id)
    VALUES (p_user_id)
    ON CONFLICT (id) DO NOTHING;

    IF v_status = 'verified' THEN
        IF v_carne !~ '^\d{9}$' THEN
            RETURN jsonb_build_object('ok', false, 'code', 'invalid_carne_format');
        END IF;

        v_carne_year := substring(v_carne FROM 1 FOR 4)::integer;
        IF v_carne_year < 1980 OR v_carne_year > EXTRACT(YEAR FROM now())::integer THEN
            RETURN jsonb_build_object('ok', false, 'code', 'invalid_carne_year');
        END IF;

        v_carne_hash := private.hash_credential(v_carne);
        IF v_carne_hash IS NULL THEN
            RETURN jsonb_build_object('ok', false, 'code', 'invalid_carne_format');
        END IF;

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

        UPDATE public.profiles
        SET carne_hash = v_carne_hash,
            is_verified = true,
            verification_status = 'verified',
            verification_method = 'manual_review',
            verified_at = COALESCE(verified_at, now()),
            updated_at = now()
        WHERE id = p_user_id;
    ELSIF v_status = 'rejected' THEN
        UPDATE public.profiles
        SET is_verified = false,
            verification_status = 'rejected',
            verification_method = 'manual_review',
            updated_at = now()
        WHERE id = p_user_id;
    ELSE
        UPDATE public.profiles
        SET is_verified = false,
            verification_status = 'unverified',
            verification_method = NULL,
            verified_at = NULL,
            updated_at = now()
        WHERE id = p_user_id;
    END IF;

    SELECT (carne_hash IS NOT NULL)
    INTO v_has_hash
    FROM public.profiles
    WHERE id = p_user_id;

    INSERT INTO public.verification_admin_audit (
        actor_id, target_user_id, action, note, details
    ) VALUES (
        v_actor,
        p_user_id,
        CASE v_status
            WHEN 'verified' THEN 'student_verified'
            WHEN 'rejected' THEN 'student_rejected'
            ELSE 'student_unverified'
        END,
        v_note,
        jsonb_build_object(
            'status', v_status,
            'carne_hash_present', COALESCE(v_has_hash, false)
        )
    );

    PERFORM set_config('request.jwt.claims', COALESCE(v_prev_claims, ''), true);

    RETURN jsonb_build_object(
        'ok', true,
        'user_id', p_user_id,
        'status', v_status,
        'has_carne_hash', COALESCE(v_has_hash, false)
    );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_set_student_verification(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_set_student_verification(uuid, text, text, text) TO authenticated, service_role;

COMMENT ON FUNCTION public.admin_set_student_verification(uuid, text, text, text) IS
    'Verifica, rechaza o desverifica manualmente a un estudiante. Carné obligatorio para verificar; solo admin.';

-- =============================================================================
-- 4. Alta/edición manual de comercio desde soporte
-- =============================================================================
CREATE OR REPLACE FUNCTION public.admin_upsert_merchant_profile(
    p_user_id              uuid,
    p_business_name        text,
    p_business_description text DEFAULT NULL,
    p_current_location_note text DEFAULT NULL,
    p_business_category    text DEFAULT NULL,
    p_plan_id              text DEFAULT 'free',
    p_verification_status  text DEFAULT 'approved',
    p_note                 text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_actor       uuid := auth.uid();
    v_name        text := btrim(COALESCE(p_business_name, ''));
    v_description text := NULLIF(btrim(COALESCE(p_business_description, '')), '');
    v_location    text := NULLIF(btrim(COALESCE(p_current_location_note, '')), '');
    v_category    text := NULLIF(btrim(COALESCE(p_business_category, '')), '');
    v_plan_id     text := btrim(COALESCE(p_plan_id, 'free'));
    v_status      text := lower(btrim(COALESCE(p_verification_status, 'approved')));
    v_note        text := NULLIF(btrim(COALESCE(p_note, '')), '');
    v_profile_status text;
    v_was_on_campus boolean;
    v_old_status text;
    v_prev_claims text;
BEGIN
    IF v_actor IS NULL OR NOT public.is_marketplace_staff(v_actor) THEN
        RETURN jsonb_build_object('ok', false, 'code', 'not_authorized');
    END IF;

    IF p_user_id IS NULL OR NOT EXISTS (
        SELECT 1 FROM auth.users u WHERE u.id = p_user_id
    ) THEN
        RETURN jsonb_build_object('ok', false, 'code', 'user_not_found');
    END IF;

    IF char_length(v_name) < 2 OR char_length(v_name) > 80 THEN
        RETURN jsonb_build_object('ok', false, 'code', 'invalid_business_name');
    END IF;

    IF v_description IS NOT NULL AND char_length(v_description) > 300 THEN
        RETURN jsonb_build_object('ok', false, 'code', 'invalid_description');
    END IF;

    IF v_location IS NOT NULL AND char_length(v_location) > 120 THEN
        RETURN jsonb_build_object('ok', false, 'code', 'invalid_location');
    END IF;

    IF v_category IS NOT NULL AND char_length(v_category) > 50 THEN
        RETURN jsonb_build_object('ok', false, 'code', 'invalid_category');
    END IF;

    IF v_status NOT IN ('pending', 'approved', 'rejected', 'suspended') THEN
        RETURN jsonb_build_object('ok', false, 'code', 'invalid_verification_status');
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.marketplace_plans mp
        WHERE mp.id = v_plan_id AND mp.is_active IS TRUE
    ) THEN
        RETURN jsonb_build_object('ok', false, 'code', 'invalid_plan');
    END IF;

    SELECT sp.is_currently_on_campus, sp.verification_status
    INTO v_was_on_campus, v_old_status
    FROM public.seller_profiles sp
    WHERE sp.user_id = p_user_id;

    -- La aprobación (o el cambio a aprobado) es exclusiva de administradores.
    IF v_status = 'approved'
       AND NOT public.is_pemtree_admin(v_actor)
       AND v_old_status IS DISTINCT FROM 'approved' THEN
        RETURN jsonb_build_object('ok', false, 'code', 'not_authorized');
    END IF;

    IF v_status = 'approved'
       AND p_user_id = v_actor
       AND v_old_status IS DISTINCT FROM 'approved' THEN
        RETURN jsonb_build_object('ok', false, 'code', 'self_approval_not_allowed');
    END IF;

    v_prev_claims := current_setting('request.jwt.claims', true);
    PERFORM set_config(
        'request.jwt.claims',
        jsonb_build_object('role', 'service_role', 'sub', v_actor::text)::text,
        true
    );

    INSERT INTO public.seller_profiles AS sp (
        user_id,
        plan_id,
        seller_type,
        verification_status,
        business_name,
        business_description,
        business_category,
        current_location_note,
        is_currently_on_campus
    ) VALUES (
        p_user_id,
        v_plan_id,
        'local_business',
        v_status,
        v_name,
        v_description,
        v_category,
        v_location,
        (v_status = 'approved' AND v_location IS NOT NULL)
    )
    ON CONFLICT (user_id) DO UPDATE SET
        plan_id                = EXCLUDED.plan_id,
        seller_type            = 'local_business',
        verification_status    = EXCLUDED.verification_status,
        business_name          = EXCLUDED.business_name,
        business_description   = EXCLUDED.business_description,
        business_category      = EXCLUDED.business_category,
        current_location_note  = EXCLUDED.current_location_note,
        is_currently_on_campus = EXCLUDED.is_currently_on_campus,
        updated_at             = now();

    v_profile_status := CASE
        WHEN v_status = 'approved' THEN 'verified'
        WHEN v_status = 'rejected' THEN 'rejected'
        WHEN v_status = 'pending'  THEN 'pending'
        ELSE 'unverified'
    END;

    UPDATE public.profiles
    SET seller_verification_status = v_profile_status,
        updated_at = now()
    WHERE id = p_user_id;

    INSERT INTO public.verification_admin_audit (
        actor_id, target_user_id, action, note, details
    ) VALUES (
        v_actor,
        p_user_id,
        'merchant_upserted',
        v_note,
        jsonb_build_object(
            'plan_id', v_plan_id,
            'verification_status', v_status,
            'business_name', v_name,
            'business_category', v_category,
            'had_campus_presence', COALESCE(v_was_on_campus, false)
        )
    );

    PERFORM set_config('request.jwt.claims', COALESCE(v_prev_claims, ''), true);

    RETURN jsonb_build_object(
        'ok', true,
        'user_id', p_user_id,
        'verification_status', v_status,
        'plan_id', v_plan_id,
        'business_name', v_name
    );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_upsert_merchant_profile(uuid, text, text, text, text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_upsert_merchant_profile(uuid, text, text, text, text, text, text, text) TO authenticated, service_role;

COMMENT ON FUNCTION public.admin_upsert_merchant_profile(uuid, text, text, text, text, text, text, text) IS
    'Crea o actualiza un comercio local desde soporte. Staff puede editar; la aprobación es solo admin.';

-- =============================================================================
-- 5. Listado administrativo de vendedores sin PII y con correo/categoría
-- =============================================================================
DROP FUNCTION IF EXISTS public.admin_list_marketplace_sellers(text, text, text, integer, integer);

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
    email                  text,
    is_verified            boolean,
    plan_id                text,
    plan_name              text,
    plan_monthly           numeric,
    seller_type            text,
    verification_status    text,
    business_name          text,
    business_description   text,
    business_category      text,
    current_location_note  text,
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
        COALESCE(au.email, '')::text AS email,
        public.is_verified_seller(sp.user_id) AS is_verified,
        COALESCE(ep.id, 'free')               AS plan_id,
        COALESCE(ep.name, 'Estudiante')       AS plan_name,
        COALESCE(ep.price_monthly, 0)         AS plan_monthly,
        sp.seller_type,
        sp.verification_status,
        sp.business_name,
        sp.business_description,
        sp.business_category,
        sp.current_location_note,
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
    LEFT JOIN auth.users au ON au.id = sp.user_id
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
            OR COALESCE(au.email, '') ILIKE '%' || v_search || '%'
            OR sp.user_id::text ILIKE '%' || v_search || '%'
          )
      AND (p_plan IS NULL OR COALESCE(ep.id, 'free') = p_plan)
      AND (p_verification IS NULL OR sp.verification_status = p_verification)
    ORDER BY sp.created_at DESC, sp.user_id
    LIMIT v_limit
    OFFSET v_offset;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_list_marketplace_sellers(text, text, text, integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_list_marketplace_sellers(text, text, text, integer, integer) TO authenticated, service_role;

COMMENT ON FUNCTION public.admin_list_marketplace_sellers(text, text, text, integer, integer) IS
    'Inventario administrativo de vendedores con correo, categoría, plan efectivo y métricas de 30 días.';
