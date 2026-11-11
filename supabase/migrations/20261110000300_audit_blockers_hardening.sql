-- ==============================================================================
-- Migración: 20261110000300_audit_blockers_hardening.sql
-- Propósito: Corrección de los 3 bloqueantes del Red Team (B-01, B-02, B-03)
--            y advertencia de retención en seccion_reviews.
-- Idempotente y compatible con supabase db reset.
-- ==============================================================================

-- ==============================================================================
-- BLOQUEANTE B-01 — Revocación de TRUNCATE, REFERENCES, TRIGGER públicos
-- ==============================================================================

DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT quote_ident(c.relname) AS tbl
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public'
          AND c.relkind IN ('r', 'p')
    ) LOOP
        EXECUTE format('REVOKE TRUNCATE, REFERENCES, TRIGGER ON TABLE public.%s FROM anon, authenticated;', r.tbl);
    END LOOP;
END;
$$;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE TRUNCATE, REFERENCES, TRIGGER ON TABLES FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE TRUNCATE, REFERENCES, TRIGGER ON TABLES FROM anon, authenticated;

-- ==============================================================================
-- ADVERTENCIA DEL AUDITOR — Retención y columnas de auditoría en seccion_reviews
-- (Se aplica antes de B-02 para que existan las columnas si fueran necesarias)
-- ==============================================================================

ALTER TABLE public.seccion_reviews ADD COLUMN IF NOT EXISTS deleted_at timestamptz NULL;
ALTER TABLE public.seccion_reviews ADD COLUMN IF NOT EXISTS is_legal_hold boolean NOT NULL DEFAULT false;

-- Revocar DELETE en seccion_reviews
REVOKE DELETE ON TABLE public.seccion_reviews FROM anon, authenticated;

DROP POLICY IF EXISTS "El autor o admin pueden borrar la reseña de sección" ON public.seccion_reviews;
DROP POLICY IF EXISTS "deny_all_delete_seccion_reviews" ON public.seccion_reviews;
CREATE POLICY "deny_all_delete_seccion_reviews" ON public.seccion_reviews
    AS RESTRICTIVE
    FOR DELETE
    TO anon, authenticated
    USING (false);

CREATE OR REPLACE VIEW public.safe_seccion_reviews
WITH (security_invoker = true)
AS
SELECT
    sr.id,
    sr.curso_codigo,
    sr.seccion,
    sr.recomienda,
    sr.catedratico_nombre,
    sr.dificultad,
    sr.carga_tareas,
    sr.comentario,
    sr.semestre,
    sr.upvotes,
    sr.created_at,
    sr.updated_at,
    public.is_my_seccion_review(sr.id) AS is_mine
FROM public.seccion_reviews sr
WHERE sr.deleted_at IS NULL;

GRANT SELECT ON public.safe_seccion_reviews TO anon, authenticated;

-- ==============================================================================
-- BLOQUEANTE B-02 — Spoofing de OP y manipulación de métricas vía UPDATE
-- ==============================================================================

-- 1. Restringir privilegios de UPDATE a nivel de columna
-- posts
REVOKE UPDATE ON TABLE public.posts FROM anon, authenticated;
GRANT UPDATE (
    title, content, category, carrera, author_alias, image_url, gif_url, quoted_post_id,
    is_pinned, expires_at, deleted_at, moderation_status, moderation_label,
    moderation_confidence, moderation_reason, moderated_at, moderated_by, is_legal_hold
) ON TABLE public.posts TO authenticated;

-- comments
REVOKE UPDATE ON TABLE public.comments FROM anon, authenticated;
GRANT UPDATE (
    content, gif_url, parent_id, author_alias, deleted_at, moderation_status, moderation_label,
    moderation_confidence, moderation_reason, moderated_at, moderated_by, is_legal_hold
) ON TABLE public.comments TO authenticated;

-- student_groups
REVOKE UPDATE ON TABLE public.student_groups FROM anon, authenticated;
GRANT UPDATE (
    title, carrera, curso, section, link, description, image_url, platform, author_alias,
    deleted_at, moderation_status, moderation_label, moderation_confidence, moderation_reason,
    moderated_at, moderated_by, is_legal_hold
) ON TABLE public.student_groups TO authenticated;

-- marketplace_items
REVOKE UPDATE ON TABLE public.marketplace_items FROM anon, authenticated;
GRANT UPDATE (
    title, description, price, is_free, category, facultad, sede, building_code, location_detail,
    contact_whatsapp, contact_telegram, contact_instagram, contact_messenger, social_links,
    image_urls, video_url, author_alias, status, deleted_at, moderation_status, moderation_label,
    moderation_confidence, moderation_reason, moderated_at, moderated_by, is_legal_hold
) ON TABLE public.marketplace_items TO authenticated;

-- seccion_reviews
REVOKE UPDATE ON TABLE public.seccion_reviews FROM anon, authenticated;
GRANT UPDATE (
    recomienda, catedratico_nombre, dificultad, carga_tareas, comentario, semestre
) ON TABLE public.seccion_reviews TO authenticated;

-- profiles
REVOKE UPDATE ON TABLE public.profiles FROM anon, authenticated;
GRANT UPDATE (
    full_name, carrera, accepted_terms_version, accepted_terms_at
) ON TABLE public.profiles TO authenticated;

-- 2. Reemplazar public.enforce_content_immutability_and_legal_hold()
CREATE OR REPLACE FUNCTION public.enforce_content_immutability_and_legal_hold()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
DECLARE
    v_caller uuid;
    v_role text;
    v_jwt jsonb;
    v_is_moderator boolean := false;
    v_author_id uuid := NULL;
    v_is_author boolean := false;
    v_content_changed boolean := false;
BEGIN
    -- Las escrituras anidadas (contadores, cuarentena automática, cron) son del sistema.
    IF pg_trigger_depth() > 1 THEN
        RETURN NEW;
    END IF;

    -- Bypass explícito para procesos administrativos, service_role y tareas sin JWT
    v_caller := auth.uid();
    IF v_caller IS NULL THEN
        RETURN NEW;
    END IF;

    v_jwt := NULLIF(current_setting('request.jwt.claims', true), '')::jsonb;
    IF v_jwt IS NOT NULL AND (v_jwt ->> 'role') = 'service_role' THEN
        RETURN NEW;
    END IF;

    v_role := current_setting('role', true);
    IF v_role IN ('postgres', 'service_role', 'supabase_admin') THEN
        RETURN NEW;
    END IF;

    -- Inmutables para todos (autor y moderador incluidos)
    IF NEW.id IS DISTINCT FROM OLD.id THEN
        RAISE EXCEPTION 'Column id is immutable' USING ERRCODE = '42501';
    END IF;
    IF NEW.user_id IS DISTINCT FROM OLD.user_id THEN
        RAISE EXCEPTION 'Column user_id is immutable' USING ERRCODE = '42501';
    END IF;
    IF NEW.created_at IS DISTINCT FROM OLD.created_at THEN
        RAISE EXCEPTION 'Column created_at is immutable' USING ERRCODE = '42501';
    END IF;

    -- Reglas de inmutabilidad específicas por entidad
    IF TG_TABLE_NAME = 'posts' THEN
        IF NEW.author_hash IS DISTINCT FROM OLD.author_hash THEN
            RAISE EXCEPTION 'Column author_hash is immutable' USING ERRCODE = '42501';
        END IF;
        IF pg_trigger_depth() <= 1 THEN
            IF (NEW.likes IS DISTINCT FROM OLD.likes)
               OR (NEW.reposts_count IS DISTINCT FROM OLD.reposts_count)
               OR (NEW.comments_count IS DISTINCT FROM OLD.comments_count)
               OR (NEW.hot_score IS DISTINCT FROM OLD.hot_score) THEN
                RAISE EXCEPTION 'Metrics columns (likes, reposts_count, comments_count, hot_score) are immutable directly'
                    USING ERRCODE = '42501';
            END IF;
        END IF;
    ELSIF TG_TABLE_NAME = 'comments' THEN
        IF (NEW.post_id IS DISTINCT FROM OLD.post_id)
           OR (NEW.author_hash IS DISTINCT FROM OLD.author_hash)
           OR (NEW.is_op IS DISTINCT FROM OLD.is_op) THEN
            RAISE EXCEPTION 'Columns post_id, author_hash, and is_op are immutable'
                USING ERRCODE = '42501';
        END IF;
        IF pg_trigger_depth() <= 1 THEN
            IF NEW.likes_count IS DISTINCT FROM OLD.likes_count THEN
                RAISE EXCEPTION 'Column likes_count is immutable directly'
                    USING ERRCODE = '42501';
            END IF;
        END IF;
    ELSIF TG_TABLE_NAME = 'student_groups' THEN
        IF pg_trigger_depth() <= 1 THEN
            IF (NEW.upvotes IS DISTINCT FROM OLD.upvotes)
               OR (NEW.reported_count IS DISTINCT FROM OLD.reported_count) THEN
                RAISE EXCEPTION 'Metrics columns (upvotes, reported_count) are immutable directly'
                    USING ERRCODE = '42501';
            END IF;
        END IF;
    ELSIF TG_TABLE_NAME = 'marketplace_items' THEN
        IF pg_trigger_depth() <= 1 THEN
            IF (NEW.upvotes IS DISTINCT FROM OLD.upvotes)
               OR (NEW.reported_count IS DISTINCT FROM OLD.reported_count) THEN
                RAISE EXCEPTION 'Metrics columns (upvotes, reported_count) are immutable directly'
                    USING ERRCODE = '42501';
            END IF;
        END IF;
    END IF;

    v_is_moderator := public.is_pemtree_moderator(v_caller);

    -- Solo moderador/admin puede cambiar is_pinned, moderation_status, moderation_label,
    -- moderation_confidence, moderation_reason, moderated_at, moderated_by, is_legal_hold
    -- (cuando el que llama es un usuario autenticado normal)
    IF NOT v_is_moderator THEN
        IF TG_TABLE_NAME = 'posts' THEN
            IF NEW.is_pinned IS DISTINCT FROM OLD.is_pinned THEN
                RAISE EXCEPTION 'Only moderators and administrators can modify is_pinned'
                    USING ERRCODE = '42501';
            END IF;
        END IF;
        IF (NEW.moderation_status IS DISTINCT FROM OLD.moderation_status)
           OR (NEW.moderation_label IS DISTINCT FROM OLD.moderation_label)
           OR (NEW.moderation_confidence IS DISTINCT FROM OLD.moderation_confidence)
           OR (NEW.moderation_reason IS DISTINCT FROM OLD.moderation_reason)
           OR (NEW.moderated_at IS DISTINCT FROM OLD.moderated_at)
           OR (NEW.moderated_by IS DISTINCT FROM OLD.moderated_by)
           OR (NEW.is_legal_hold IS DISTINCT FROM OLD.is_legal_hold) THEN
            RAISE EXCEPTION 'Only moderators and administrators can modify moderation fields and is_legal_hold'
                USING ERRCODE = '42501';
        END IF;
    END IF;

    -- Si OLD.is_legal_hold = true, bloquea también cualquier cambio de deleted_at
    -- (el autor no puede ocultar evidencia de un registro bajo retención)
    IF OLD.is_legal_hold = true AND (NEW.deleted_at IS DISTINCT FROM OLD.deleted_at) THEN
        RAISE EXCEPTION 'Content under legal hold cannot be deleted or restored (Art. 3)'
            USING ERRCODE = '42501';
    END IF;

    -- Obtener autor de la entidad
    IF TG_TABLE_NAME = 'posts' THEN
        SELECT user_id INTO v_author_id FROM public.post_authors WHERE post_id = OLD.id;
        IF v_author_id IS NULL THEN
            v_author_id := OLD.user_id;
        END IF;
    ELSIF TG_TABLE_NAME = 'comments' THEN
        SELECT user_id INTO v_author_id FROM public.comment_authors WHERE comment_id = OLD.id;
        IF v_author_id IS NULL THEN
            v_author_id := OLD.user_id;
        END IF;
    ELSIF TG_TABLE_NAME IN ('student_groups', 'marketplace_items') THEN
        v_author_id := OLD.user_id;
    END IF;

    v_is_author := (v_author_id IS NOT NULL AND v_caller = v_author_id);

    -- Detección de cambios de contenido por entidad
    IF TG_TABLE_NAME = 'posts' THEN
        v_content_changed := (NEW.title IS DISTINCT FROM OLD.title)
            OR (NEW.content IS DISTINCT FROM OLD.content)
            OR (NEW.category IS DISTINCT FROM OLD.category)
            OR (NEW.image_url IS DISTINCT FROM OLD.image_url)
            OR (NEW.gif_url IS DISTINCT FROM OLD.gif_url)
            OR (NEW.quoted_post_id IS DISTINCT FROM OLD.quoted_post_id);
    ELSIF TG_TABLE_NAME = 'comments' THEN
        v_content_changed := (NEW.content IS DISTINCT FROM OLD.content)
            OR (NEW.gif_url IS DISTINCT FROM OLD.gif_url)
            OR (NEW.parent_id IS DISTINCT FROM OLD.parent_id);
    ELSIF TG_TABLE_NAME = 'student_groups' THEN
        v_content_changed := (NEW.title IS DISTINCT FROM OLD.title)
            OR (NEW.description IS DISTINCT FROM OLD.description)
            OR (NEW.link IS DISTINCT FROM OLD.link)
            OR (NEW.image_url IS DISTINCT FROM OLD.image_url)
            OR (NEW.curso IS DISTINCT FROM OLD.curso)
            OR (NEW.section IS DISTINCT FROM OLD.section)
            OR (NEW.platform IS DISTINCT FROM OLD.platform)
            OR (NEW.carrera IS DISTINCT FROM OLD.carrera);
    ELSIF TG_TABLE_NAME = 'marketplace_items' THEN
        v_content_changed := (NEW.title IS DISTINCT FROM OLD.title)
            OR (NEW.description IS DISTINCT FROM OLD.description)
            OR (NEW.price IS DISTINCT FROM OLD.price)
            OR (NEW.image_urls IS DISTINCT FROM OLD.image_urls)
            OR (NEW.video_url IS DISTINCT FROM OLD.video_url)
            OR (NEW.contact_whatsapp IS DISTINCT FROM OLD.contact_whatsapp)
            OR (NEW.contact_telegram IS DISTINCT FROM OLD.contact_telegram)
            OR (NEW.contact_instagram IS DISTINCT FROM OLD.contact_instagram)
            OR (NEW.contact_messenger IS DISTINCT FROM OLD.contact_messenger)
            OR (NEW.social_links IS DISTINCT FROM OLD.social_links)
            OR (NEW.category IS DISTINCT FROM OLD.category)
            OR (NEW.facultad IS DISTINCT FROM OLD.facultad)
            OR (NEW.sede IS DISTINCT FROM OLD.sede)
            OR (NEW.building_code IS DISTINCT FROM OLD.building_code)
            OR (NEW.location_detail IS DISTINCT FROM OLD.location_detail);
    END IF;

    -- Regla Art. 3: Si está bajo retención legal, el contenido es absolutamente inmutable
    IF OLD.is_legal_hold = true AND v_content_changed THEN
        RAISE EXCEPTION 'Content under legal hold cannot be modified (Art. 3)'
            USING ERRCODE = '42501';
    END IF;

    -- Regla: Únicamente el autor original puede alterar su contenido (ni admin ni moderador)
    IF v_content_changed AND NOT v_is_author THEN
        RAISE EXCEPTION 'Only the original author can edit content'
            USING ERRCODE = '42501';
    END IF;

    -- Regla: Moderador modificando entidad ajena solo puede alterar metadatos de moderación
    IF NOT v_is_author AND v_is_moderator THEN
        IF TG_TABLE_NAME = 'posts' THEN
            IF (NEW.title IS DISTINCT FROM OLD.title)
               OR (NEW.category IS DISTINCT FROM OLD.category)
               OR (NEW.content IS DISTINCT FROM OLD.content)
               OR (NEW.author_alias IS DISTINCT FROM OLD.author_alias)
               OR (NEW.author_hash IS DISTINCT FROM OLD.author_hash)
               OR (NEW.user_id IS DISTINCT FROM OLD.user_id)
               OR (NEW.carrera IS DISTINCT FROM OLD.carrera)
               OR (NEW.image_url IS DISTINCT FROM OLD.image_url)
               OR (NEW.gif_url IS DISTINCT FROM OLD.gif_url)
               OR (NEW.quoted_post_id IS DISTINCT FROM OLD.quoted_post_id)
               OR (NEW.expires_at IS DISTINCT FROM OLD.expires_at)
               OR (NEW.deleted_at IS DISTINCT FROM OLD.deleted_at) THEN
                RAISE EXCEPTION 'Moderators can only modify moderation fields, is_pinned, and is_legal_hold'
                    USING ERRCODE = '42501';
            END IF;
        ELSIF TG_TABLE_NAME = 'comments' THEN
            IF (NEW.post_id IS DISTINCT FROM OLD.post_id)
               OR (NEW.author_alias IS DISTINCT FROM OLD.author_alias)
               OR (NEW.content IS DISTINCT FROM OLD.content)
               OR (NEW.user_id IS DISTINCT FROM OLD.user_id)
               OR (NEW.parent_id IS DISTINCT FROM OLD.parent_id)
               OR (NEW.gif_url IS DISTINCT FROM OLD.gif_url)
               OR (NEW.author_hash IS DISTINCT FROM OLD.author_hash)
               OR (NEW.is_op IS DISTINCT FROM OLD.is_op)
               OR (NEW.likes_count IS DISTINCT FROM OLD.likes_count)
               OR (NEW.deleted_at IS DISTINCT FROM OLD.deleted_at) THEN
                RAISE EXCEPTION 'Moderators can only modify moderation fields and is_legal_hold'
                    USING ERRCODE = '42501';
            END IF;
        ELSIF TG_TABLE_NAME = 'student_groups' THEN
            IF (NEW.title IS DISTINCT FROM OLD.title)
               OR (NEW.carrera IS DISTINCT FROM OLD.carrera)
               OR (NEW.curso IS DISTINCT FROM OLD.curso)
               OR (NEW.section IS DISTINCT FROM OLD.section)
               OR (NEW.link IS DISTINCT FROM OLD.link)
               OR (NEW.description IS DISTINCT FROM OLD.description)
               OR (NEW.user_id IS DISTINCT FROM OLD.user_id)
               OR (NEW.author_alias IS DISTINCT FROM OLD.author_alias)
               OR (NEW.upvotes IS DISTINCT FROM OLD.upvotes)
               OR (NEW.reported_count IS DISTINCT FROM OLD.reported_count)
               OR (NEW.image_url IS DISTINCT FROM OLD.image_url)
               OR (NEW.platform IS DISTINCT FROM OLD.platform)
               OR (NEW.deleted_at IS DISTINCT FROM OLD.deleted_at) THEN
                RAISE EXCEPTION 'Moderators can only modify moderation fields and is_legal_hold'
                    USING ERRCODE = '42501';
            END IF;
        ELSIF TG_TABLE_NAME = 'marketplace_items' THEN
            IF (NEW.title IS DISTINCT FROM OLD.title)
               OR (NEW.description IS DISTINCT FROM OLD.description)
               OR (NEW.price IS DISTINCT FROM OLD.price)
               OR (NEW.is_free IS DISTINCT FROM OLD.is_free)
               OR (NEW.category IS DISTINCT FROM OLD.category)
               OR (NEW.facultad IS DISTINCT FROM OLD.facultad)
               OR (NEW.sede IS DISTINCT FROM OLD.sede)
               OR (NEW.building_code IS DISTINCT FROM OLD.building_code)
               OR (NEW.location_detail IS DISTINCT FROM OLD.location_detail)
               OR (NEW.contact_whatsapp IS DISTINCT FROM OLD.contact_whatsapp)
               OR (NEW.contact_telegram IS DISTINCT FROM OLD.contact_telegram)
               OR (NEW.contact_instagram IS DISTINCT FROM OLD.contact_instagram)
               OR (NEW.contact_messenger IS DISTINCT FROM OLD.contact_messenger)
               OR (NEW.social_links IS DISTINCT FROM OLD.social_links)
               OR (NEW.image_urls IS DISTINCT FROM OLD.image_urls)
               OR (NEW.video_url IS DISTINCT FROM OLD.video_url)
               OR (NEW.is_sponsored IS DISTINCT FROM OLD.is_sponsored)
               OR (NEW.sponsor_badge_text IS DISTINCT FROM OLD.sponsor_badge_text)
               OR (NEW.author_alias IS DISTINCT FROM OLD.author_alias)
               OR (NEW.user_id IS DISTINCT FROM OLD.user_id)
               OR (NEW.upvotes IS DISTINCT FROM OLD.upvotes)
               OR (NEW.reported_count IS DISTINCT FROM OLD.reported_count)
               OR (NEW.status IS DISTINCT FROM OLD.status)
               OR (NEW.deleted_at IS DISTINCT FROM OLD.deleted_at) THEN
                RAISE EXCEPTION 'Moderators can only modify moderation fields and is_legal_hold'
                    USING ERRCODE = '42501';
            END IF;
        END IF;
    END IF;

    -- Regla: Usuarios que no son autores ni moderadores no pueden alterar estado ni borrado
    IF NOT v_is_author AND NOT v_is_moderator THEN
        IF (NEW.deleted_at IS DISTINCT FROM OLD.deleted_at)
           OR (NEW.is_legal_hold IS DISTINCT FROM OLD.is_legal_hold)
           OR v_content_changed THEN
            RAISE EXCEPTION 'Permission denied' USING ERRCODE = '42501';
        END IF;
    END IF;

    RETURN NEW;
END;
$fn$;

-- Re-asociar triggers de immutabilidad
DROP TRIGGER IF EXISTS trg_enforce_legal_immutability_posts ON public.posts;
CREATE TRIGGER trg_enforce_legal_immutability_posts
    BEFORE UPDATE ON public.posts
    FOR EACH ROW
    EXECUTE FUNCTION public.enforce_content_immutability_and_legal_hold();

DROP TRIGGER IF EXISTS trg_enforce_legal_immutability_comments ON public.comments;
CREATE TRIGGER trg_enforce_legal_immutability_comments
    BEFORE UPDATE ON public.comments
    FOR EACH ROW
    EXECUTE FUNCTION public.enforce_content_immutability_and_legal_hold();

DROP TRIGGER IF EXISTS trg_enforce_legal_immutability_student_groups ON public.student_groups;
CREATE TRIGGER trg_enforce_legal_immutability_student_groups
    BEFORE UPDATE ON public.student_groups
    FOR EACH ROW
    EXECUTE FUNCTION public.enforce_content_immutability_and_legal_hold();

DROP TRIGGER IF EXISTS trg_enforce_legal_immutability_marketplace_items ON public.marketplace_items;
CREATE TRIGGER trg_enforce_legal_immutability_marketplace_items
    BEFORE UPDATE ON public.marketplace_items
    FOR EACH ROW
    EXECUTE FUNCTION public.enforce_content_immutability_and_legal_hold();

-- 3. Defensa en profundidad para INSERT
CREATE OR REPLACE FUNCTION public.enforce_system_defaults_on_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
DECLARE
    v_role text;
    v_jwt jsonb;
    v_caller uuid;
BEGIN
    IF pg_trigger_depth() > 1 THEN
        RETURN NEW;
    END IF;

    v_caller := auth.uid();
    v_jwt := NULLIF(current_setting('request.jwt.claims', true), '')::jsonb;

    IF v_jwt IS NOT NULL AND (v_jwt ->> 'role') = 'service_role' THEN
        RETURN NEW;
    END IF;

    v_role := current_setting('role', true);
    IF v_role IN ('postgres', 'service_role', 'supabase_admin') AND v_caller IS NULL THEN
        RETURN NEW;
    END IF;

    IF TG_TABLE_NAME = 'posts' THEN
        NEW.likes := 0;
        NEW.reposts_count := 0;
        NEW.comments_count := 0;
        NEW.hot_score := 0;
        NEW.is_pinned := false;
        NEW.moderation_status := 0;
        NEW.moderation_label := NULL;
        NEW.moderation_confidence := NULL;
        NEW.moderation_reason := NULL;
        NEW.moderated_at := NULL;
        NEW.moderated_by := NULL;
        NEW.is_legal_hold := false;
        NEW.created_at := now();
    ELSIF TG_TABLE_NAME = 'comments' THEN
        NEW.likes_count := 0;
        NEW.is_op := false;
        NEW.moderation_status := 0;
        NEW.moderation_label := NULL;
        NEW.moderation_confidence := NULL;
        NEW.moderation_reason := NULL;
        NEW.moderated_at := NULL;
        NEW.moderated_by := NULL;
        NEW.is_legal_hold := false;
        NEW.created_at := now();
    ELSIF TG_TABLE_NAME = 'student_groups' THEN
        NEW.upvotes := 0;
        NEW.reported_count := 0;
        NEW.moderation_status := 0;
        NEW.moderation_label := NULL;
        NEW.moderation_confidence := NULL;
        NEW.moderation_reason := NULL;
        NEW.moderated_at := NULL;
        NEW.moderated_by := NULL;
        NEW.is_legal_hold := false;
        NEW.created_at := now();
    ELSIF TG_TABLE_NAME = 'marketplace_items' THEN
        NEW.upvotes := 0;
        NEW.reported_count := 0;
        NEW.moderation_status := 0;
        NEW.moderation_label := NULL;
        NEW.moderation_confidence := NULL;
        NEW.moderation_reason := NULL;
        NEW.moderated_at := NULL;
        NEW.moderated_by := NULL;
        NEW.is_legal_hold := false;
        NEW.created_at := now();
        NEW.is_sponsored := false;
        NEW.sponsor_badge_text := NULL;
    ELSIF TG_TABLE_NAME = 'seccion_reviews' THEN
        NEW.upvotes := 0;
        NEW.created_at := now();
    END IF;

    RETURN NEW;
END;
$fn$;

DROP TRIGGER IF EXISTS trg_aa_system_defaults_posts ON public.posts;
CREATE TRIGGER trg_aa_system_defaults_posts
    BEFORE INSERT ON public.posts
    FOR EACH ROW
    EXECUTE FUNCTION public.enforce_system_defaults_on_insert();

DROP TRIGGER IF EXISTS trg_aa_system_defaults_comments ON public.comments;
CREATE TRIGGER trg_aa_system_defaults_comments
    BEFORE INSERT ON public.comments
    FOR EACH ROW
    EXECUTE FUNCTION public.enforce_system_defaults_on_insert();

DROP TRIGGER IF EXISTS trg_aa_system_defaults_student_groups ON public.student_groups;
CREATE TRIGGER trg_aa_system_defaults_student_groups
    BEFORE INSERT ON public.student_groups
    FOR EACH ROW
    EXECUTE FUNCTION public.enforce_system_defaults_on_insert();

DROP TRIGGER IF EXISTS trg_aa_system_defaults_marketplace_items ON public.marketplace_items;
CREATE TRIGGER trg_aa_system_defaults_marketplace_items
    BEFORE INSERT ON public.marketplace_items
    FOR EACH ROW
    EXECUTE FUNCTION public.enforce_system_defaults_on_insert();

DROP TRIGGER IF EXISTS trg_aa_system_defaults_seccion_reviews ON public.seccion_reviews;
CREATE TRIGGER trg_aa_system_defaults_seccion_reviews
    BEFORE INSERT ON public.seccion_reviews
    FOR EACH ROW
    EXECUTE FUNCTION public.enforce_system_defaults_on_insert();

-- ==============================================================================
-- BLOQUEANTE B-03 — user_id público en groups/marketplace
-- ==============================================================================

-- 1. Funciones helper SECURITY DEFINER / STABLE
CREATE OR REPLACE FUNCTION public.is_my_group(p_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $fn$
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN false;
    END IF;
    RETURN EXISTS (
        SELECT 1
        FROM public.student_groups
        WHERE id = p_id AND user_id = auth.uid()
    );
END;
$fn$;

CREATE OR REPLACE FUNCTION public.is_my_marketplace_item(p_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $fn$
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN false;
    END IF;
    RETURN EXISTS (
        SELECT 1
        FROM public.marketplace_items
        WHERE id = p_id AND user_id = auth.uid()
    );
END;
$fn$;

GRANT EXECUTE ON FUNCTION public.is_my_group(uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.is_my_marketplace_item(uuid) TO anon, authenticated;

-- 2. Vistas seguras sin exposición de user_id
CREATE OR REPLACE VIEW public.safe_student_groups
WITH (security_invoker = true)
AS
SELECT
    id,
    title,
    carrera,
    curso,
    section,
    link,
    description,
    author_alias,
    upvotes,
    reported_count,
    created_at,
    image_url,
    moderation_status,
    moderation_label,
    moderation_confidence,
    moderation_reason,
    moderated_at,
    moderated_by,
    platform,
    updated_at,
    deleted_at,
    is_legal_hold,
    public.is_my_group(id) AS is_mine
FROM public.student_groups
WHERE deleted_at IS NULL
  AND (moderation_status <> 2 OR public.is_my_group(id));

CREATE OR REPLACE VIEW public.safe_marketplace_items
WITH (security_invoker = true)
AS
SELECT
    id,
    title,
    description,
    price,
    is_free,
    category,
    facultad,
    sede,
    building_code,
    location_detail,
    contact_whatsapp,
    contact_telegram,
    image_urls,
    video_url,
    is_sponsored,
    sponsor_badge_text,
    author_alias,
    upvotes,
    moderation_status,
    created_at,
    contact_instagram,
    contact_messenger,
    social_links,
    reported_count,
    status,
    moderation_label,
    moderation_confidence,
    moderation_reason,
    moderated_at,
    moderated_by,
    updated_at,
    deleted_at,
    is_legal_hold,
    public.is_my_marketplace_item(id) AS is_mine
FROM public.marketplace_items
WHERE deleted_at IS NULL
  AND (moderation_status <> 2 OR public.is_my_marketplace_item(id))
  AND (status IN ('available', 'reserved') OR public.is_my_marketplace_item(id));

GRANT SELECT ON public.safe_student_groups TO anon, authenticated;
GRANT SELECT ON public.safe_marketplace_items TO anon, authenticated;

-- 3. Revocar SELECT a nivel de tabla y conceder SELECT por columna (sin user_id)
REVOKE SELECT ON TABLE public.student_groups FROM anon, authenticated;
GRANT SELECT (
    id, title, carrera, curso, section, link, description, author_alias,
    upvotes, reported_count, created_at, image_url, moderation_status,
    moderation_label, moderation_confidence, moderation_reason,
    moderated_at, moderated_by, platform, updated_at, deleted_at, is_legal_hold
) ON TABLE public.student_groups TO anon, authenticated;

REVOKE SELECT ON TABLE public.marketplace_items FROM anon, authenticated;
GRANT SELECT (
    id, title, description, price, is_free, category, facultad, sede,
    building_code, location_detail, contact_whatsapp, contact_telegram,
    image_urls, video_url, is_sponsored, sponsor_badge_text, author_alias,
    upvotes, moderation_status, created_at, contact_instagram, contact_messenger,
    social_links, reported_count, status, moderation_label, moderation_confidence,
    moderation_reason, moderated_at, moderated_by, updated_at, deleted_at, is_legal_hold
) ON TABLE public.marketplace_items TO anon, authenticated;
