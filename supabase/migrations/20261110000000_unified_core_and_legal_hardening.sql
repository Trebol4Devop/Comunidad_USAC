-- =============================================================================
-- Migration: 20261110000000_unified_core_and_legal_hardening.sql
-- Description: Unified Core, Legal Hardening, Thread Identity & Performance
-- Author: Agente 1 (Arquitecto Senior de Base de Datos y Cumplimiento Legal)
-- =============================================================================

-- =============================================================================
-- BLOQUE 1 — Criptografía, schema private y perfiles
-- =============================================================================

-- 1. Habilitar extensión pgcrypto en schema extensions y crear schema private
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC, anon, authenticated;
GRANT USAGE ON SCHEMA private TO postgres, service_role;

-- 2. Crear private.app_secrets y sembrar clave criptográfica fuerte
CREATE TABLE IF NOT EXISTS private.app_secrets (
    key text PRIMARY KEY,
    value text NOT NULL
);

ALTER TABLE private.app_secrets DISABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE private.app_secrets FROM PUBLIC, anon, authenticated;
GRANT ALL ON TABLE private.app_secrets TO postgres, service_role;

INSERT INTO private.app_secrets (key, value)
VALUES ('author_hash_salt', encode(extensions.gen_random_bytes(32), 'hex'))
ON CONFLICT (key) DO NOTHING;

-- 3. Función SECURITY DEFINER para consultar la semilla sin exponerla
CREATE OR REPLACE FUNCTION private.get_secret_salt()
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $fn$
DECLARE
    v_salt text;
BEGIN
    SELECT value INTO v_salt FROM private.app_secrets WHERE key = 'author_hash_salt';
    RETURN v_salt;
END;
$fn$;

REVOKE ALL ON FUNCTION private.get_secret_salt() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.get_secret_salt() TO postgres, service_role;

-- 4. Extender public.profiles con campos anonimizados y términos legales
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS cui_hash text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS carne_hash text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS accepted_terms_version text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS accepted_terms_at timestamptz;

CREATE UNIQUE INDEX IF NOT EXISTS profiles_cui_hash_key ON public.profiles (cui_hash);
CREATE UNIQUE INDEX IF NOT EXISTS profiles_carne_hash_key ON public.profiles (carne_hash);

-- 5. Migrar datos existentes a HMAC-SHA256 y neutralizar columnas sensibles
UPDATE public.profiles
SET cui_hash = CASE
        WHEN cui IS NOT NULL AND btrim(cui) <> '' THEN
            encode(extensions.hmac(btrim(cui)::text, private.get_secret_salt()::text, 'sha256'::text), 'hex')
        ELSE cui_hash
    END,
    carne_hash = CASE
        WHEN carne IS NOT NULL AND btrim(carne) <> '' THEN
            encode(extensions.hmac(btrim(carne)::text, private.get_secret_salt()::text, 'sha256'::text), 'hex')
        ELSE carne_hash
    END;

UPDATE public.profiles
SET cui = NULL,
    carne = NULL;

-- 6. Trigger para neutralizar texto plano de cui/carne en INSERT/UPDATE y check constraint
CREATE OR REPLACE FUNCTION public.handle_profile_sensitive_data()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
DECLARE
    v_salt text;
BEGIN
    v_salt := private.get_secret_salt();

    IF NEW.cui IS NOT NULL AND btrim(NEW.cui) <> '' THEN
        NEW.cui_hash := encode(extensions.hmac(btrim(NEW.cui)::text, v_salt::text, 'sha256'::text), 'hex');
    END IF;
    NEW.cui := NULL;

    IF NEW.carne IS NOT NULL AND btrim(NEW.carne) <> '' THEN
        NEW.carne_hash := encode(extensions.hmac(btrim(NEW.carne)::text, v_salt::text, 'sha256'::text), 'hex');
    END IF;
    NEW.carne := NULL;

    RETURN NEW;
END;
$fn$;

DROP TRIGGER IF EXISTS trg_handle_profile_sensitive_data ON public.profiles;
CREATE TRIGGER trg_handle_profile_sensitive_data
    BEFORE INSERT OR UPDATE ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_profile_sensitive_data();

DO $fn$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'public.profiles'::regclass
          AND conname = 'profiles_cui_carne_null_check'
    ) THEN
        ALTER TABLE public.profiles
            ADD CONSTRAINT profiles_cui_carne_null_check
            CHECK (cui IS NULL AND carne IS NULL);
    END IF;
END;
$fn$;


-- =============================================================================
-- BLOQUE 2 — Identidad anónima por hilo, is_op, bóveda de autoría
-- =============================================================================

-- 1. Añadir is_op y likes_count a public.comments
ALTER TABLE public.comments ADD COLUMN IF NOT EXISTS is_op boolean NOT NULL DEFAULT false;
ALTER TABLE public.comments ADD COLUMN IF NOT EXISTS likes_count integer NOT NULL DEFAULT 0;

-- 2. Reemplazar handle_post_author_hash() con hash por publicación
CREATE OR REPLACE FUNCTION public.handle_post_author_hash()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
DECLARE
    v_user_id uuid;
    v_salt text;
BEGIN
    IF NEW.id IS NULL THEN
        NEW.id := gen_random_uuid();
    END IF;

    v_user_id := COALESCE(NEW.user_id, auth.uid());
    IF v_user_id IS NOT NULL THEN
        v_salt := private.get_secret_salt();
        NEW.author_hash := SUBSTRING(
            ENCODE(
                extensions.hmac(
                    v_user_id::text,
                    NEW.id::text || v_salt,
                    'sha256'
                ),
                'hex'
            )
            FROM 1 FOR 8
        );
    END IF;
    RETURN NEW;
END;
$fn$;

-- 3. Mantener/verificar after_post_insert_author()
CREATE OR REPLACE FUNCTION public.after_post_insert_author()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
DECLARE
    v_user_id uuid;
BEGIN
    v_user_id := COALESCE(NEW.user_id, auth.uid());
    IF v_user_id IS NOT NULL THEN
        INSERT INTO public.post_authors (post_id, user_id)
        VALUES (NEW.id, v_user_id)
        ON CONFLICT (post_id) DO NOTHING;
    END IF;
    RETURN NEW;
END;
$fn$;

-- 4. Reemplazar handle_comment_author_hash() con hash por hilo e is_op
CREATE OR REPLACE FUNCTION public.handle_comment_author_hash()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
DECLARE
    v_user_id uuid;
    v_salt text;
BEGIN
    v_user_id := COALESCE(NEW.user_id, auth.uid());
    IF v_user_id IS NOT NULL AND NEW.post_id IS NOT NULL THEN
        v_salt := private.get_secret_salt();
        NEW.author_hash := SUBSTRING(
            ENCODE(
                extensions.hmac(
                    v_user_id::text,
                    NEW.post_id::text || v_salt,
                    'sha256'
                ),
                'hex'
            )
            FROM 1 FOR 8
        );
        NEW.is_op := EXISTS (
            SELECT 1 FROM public.post_authors pa
            WHERE pa.post_id = NEW.post_id AND pa.user_id = v_user_id
        );
    ELSE
        NEW.is_op := false;
    END IF;
    RETURN NEW;
END;
$fn$;

-- 5. Mantener/verificar after_comment_insert_author()
CREATE OR REPLACE FUNCTION public.after_comment_insert_author()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
DECLARE
    v_user_id uuid;
BEGIN
    v_user_id := COALESCE(NEW.user_id, auth.uid());
    IF v_user_id IS NOT NULL THEN
        INSERT INTO public.comment_authors (comment_id, user_id)
        VALUES (NEW.id, v_user_id)
        ON CONFLICT (comment_id) DO NOTHING;
    END IF;
    RETURN NEW;
END;
$fn$;

-- 6. Poblar bóvedas y recalcular retroactivamente author_hash e is_op
INSERT INTO public.post_authors (post_id, user_id)
SELECT id, user_id FROM public.posts WHERE user_id IS NOT NULL
ON CONFLICT (post_id) DO NOTHING;

INSERT INTO public.comment_authors (comment_id, user_id)
SELECT id, user_id FROM public.comments WHERE user_id IS NOT NULL
ON CONFLICT (comment_id) DO NOTHING;

UPDATE public.posts p
SET author_hash = SUBSTRING(
    ENCODE(
        extensions.hmac(
            COALESCE(pa.user_id, p.user_id)::text,
            p.id::text || (SELECT private.get_secret_salt()),
            'sha256'
        ),
        'hex'
    )
    FROM 1 FOR 8
)
FROM public.post_authors pa
WHERE pa.post_id = p.id AND COALESCE(pa.user_id, p.user_id) IS NOT NULL;

UPDATE public.comments c
SET author_hash = SUBSTRING(
        ENCODE(
            extensions.hmac(
                COALESCE(ca.user_id, c.user_id)::text,
                c.post_id::text || (SELECT private.get_secret_salt()),
                'sha256'
            ),
            'hex'
        )
        FROM 1 FOR 8
    ),
    is_op = EXISTS (
        SELECT 1 FROM public.post_authors pa
        WHERE pa.post_id = c.post_id
          AND pa.user_id = COALESCE(ca.user_id, c.user_id)
    )
FROM public.comment_authors ca
WHERE ca.comment_id = c.id AND COALESCE(ca.user_id, c.user_id) IS NOT NULL;


-- =============================================================================
-- BLOQUE 3 — Preservación legal 90 días (Art. 20/21) e inmutabilidad de contenido (Art. 3)
-- =============================================================================

-- 1. Añadir deleted_at e is_legal_hold a las 4 tablas legales
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS deleted_at timestamptz NULL;
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS is_legal_hold boolean NOT NULL DEFAULT false;

ALTER TABLE public.comments ADD COLUMN IF NOT EXISTS deleted_at timestamptz NULL;
ALTER TABLE public.comments ADD COLUMN IF NOT EXISTS is_legal_hold boolean NOT NULL DEFAULT false;

ALTER TABLE public.student_groups ADD COLUMN IF NOT EXISTS deleted_at timestamptz NULL;
ALTER TABLE public.student_groups ADD COLUMN IF NOT EXISTS is_legal_hold boolean NOT NULL DEFAULT false;

ALTER TABLE public.marketplace_items ADD COLUMN IF NOT EXISTS deleted_at timestamptz NULL;
ALTER TABLE public.marketplace_items ADD COLUMN IF NOT EXISTS is_legal_hold boolean NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_posts_deleted_at ON public.posts (deleted_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_posts_legal_hold ON public.posts (is_legal_hold) WHERE is_legal_hold = true;

CREATE INDEX IF NOT EXISTS idx_comments_deleted_at ON public.comments (deleted_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_comments_legal_hold ON public.comments (is_legal_hold) WHERE is_legal_hold = true;

CREATE INDEX IF NOT EXISTS idx_student_groups_deleted_at ON public.student_groups (deleted_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_student_groups_legal_hold ON public.student_groups (is_legal_hold) WHERE is_legal_hold = true;

CREATE INDEX IF NOT EXISTS idx_marketplace_items_deleted_at ON public.marketplace_items (deleted_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_marketplace_items_legal_hold ON public.marketplace_items (is_legal_hold) WHERE is_legal_hold = true;

-- 2. Revocar DELETE a anon y authenticated en las 4 tablas; denegar por RLS
REVOKE DELETE ON TABLE public.posts FROM anon, authenticated;
REVOKE DELETE ON TABLE public.comments FROM anon, authenticated;
REVOKE DELETE ON TABLE public.student_groups FROM anon, authenticated;
REVOKE DELETE ON TABLE public.marketplace_items FROM anon, authenticated;

DROP POLICY IF EXISTS "Eliminar propias publicaciones o admin" ON public.posts;
DROP POLICY IF EXISTS "deny_all_delete_posts" ON public.posts;
CREATE POLICY "deny_all_delete_posts" ON public.posts AS RESTRICTIVE FOR DELETE TO anon, authenticated USING (false);

DROP POLICY IF EXISTS "Eliminar propios comentarios o admin" ON public.comments;
DROP POLICY IF EXISTS "deny_all_delete_comments" ON public.comments;
CREATE POLICY "deny_all_delete_comments" ON public.comments AS RESTRICTIVE FOR DELETE TO anon, authenticated USING (false);

DROP POLICY IF EXISTS "Borrar grupos dueño, admin o moderador" ON public.student_groups;
DROP POLICY IF EXISTS "deny_all_delete_student_groups" ON public.student_groups;
CREATE POLICY "deny_all_delete_student_groups" ON public.student_groups AS RESTRICTIVE FOR DELETE TO anon, authenticated USING (false);

DROP POLICY IF EXISTS "Users can delete their own marketplace items" ON public.marketplace_items;
DROP POLICY IF EXISTS "deny_all_delete_marketplace_items" ON public.marketplace_items;
CREATE POLICY "deny_all_delete_marketplace_items" ON public.marketplace_items AS RESTRICTIVE FOR DELETE TO anon, authenticated USING (false);

-- 3. Bóveda de autoría: desasociación en ON DELETE SET NULL y bloqueo de cuentas con retención activa
ALTER TABLE public.post_authors ALTER COLUMN user_id DROP NOT NULL;
ALTER TABLE public.post_authors DROP CONSTRAINT IF EXISTS post_authors_user_id_fkey;
ALTER TABLE public.post_authors
    ADD CONSTRAINT post_authors_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;

ALTER TABLE public.comment_authors ALTER COLUMN user_id DROP NOT NULL;
ALTER TABLE public.comment_authors DROP CONSTRAINT IF EXISTS comment_authors_user_id_fkey;
ALTER TABLE public.comment_authors
    ADD CONSTRAINT comment_authors_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;

-- Cumplimiento de los Artículos 20 y 21:
-- La preservación de evidencia requiere retener íntegramente todo contenido y metadato
-- asociado durante una orden judicial o investigación activa (is_legal_hold = true).
-- Por tanto, se bloquea el borrado de la cuenta en auth.users si existen publicaciones
-- o comentarios bajo retención. En cuentas ordinarias (sin retención), el borrado de
-- cuenta se autoriza plenamente y la clave foránea ON DELETE SET NULL desvincula el
-- user_id en la bóveda, garantizando la inmutabilidad de los registros históricos.
CREATE OR REPLACE FUNCTION private.protect_authorship_on_user_delete()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM public.post_authors pa
        JOIN public.posts p ON p.id = pa.post_id
        WHERE pa.user_id = OLD.id AND p.is_legal_hold = true
    ) OR EXISTS (
        SELECT 1
        FROM public.comment_authors ca
        JOIN public.comments c ON c.id = ca.comment_id
        WHERE ca.user_id = OLD.id AND c.is_legal_hold = true
    ) OR EXISTS (
        SELECT 1
        FROM public.student_groups sg
        WHERE sg.user_id = OLD.id AND sg.is_legal_hold = true
    ) OR EXISTS (
        SELECT 1
        FROM public.marketplace_items mi
        WHERE mi.user_id = OLD.id AND mi.is_legal_hold = true
    ) THEN
        RAISE EXCEPTION 'Account deletion blocked: User has content subject to active legal hold (Art. 20/21)'
            USING ERRCODE = '55000';
    END IF;
    RETURN OLD;
END;
$fn$;

DROP TRIGGER IF EXISTS trg_protect_authorship_on_user_delete ON auth.users;
CREATE TRIGGER trg_protect_authorship_on_user_delete
    BEFORE DELETE ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION private.protect_authorship_on_user_delete();

-- 4. Inmutabilidad de contenido (Art. 3) y atribución estricta de edición
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
    v_is_moderator := public.is_pemtree_moderator(v_caller);

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

    -- Regla: is_legal_hold solo puede ser modificado por moderador/admin
    IF NEW.is_legal_hold IS DISTINCT FROM OLD.is_legal_hold THEN
        IF NOT v_is_moderator THEN
            RAISE EXCEPTION 'Only moderators and administrators can modify is_legal_hold'
                USING ERRCODE = '42501';
        END IF;
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

-- Actualizar políticas RLS de UPDATE para permitir moderación controlada
DROP POLICY IF EXISTS "Actualizar propias publicaciones" ON public.posts;
DROP POLICY IF EXISTS "Actualizar propias publicaciones o moderador" ON public.posts;
CREATE POLICY "Actualizar propias publicaciones o moderador" ON public.posts
    FOR UPDATE TO authenticated
    USING (
        (auth.uid() IS NOT NULL AND (auth.uid() = user_id OR EXISTS (SELECT 1 FROM public.post_authors WHERE post_id = posts.id AND user_id = auth.uid())))
        OR public.is_pemtree_moderator(auth.uid())
    );

DROP POLICY IF EXISTS "Actualizar propios comentarios" ON public.comments;
DROP POLICY IF EXISTS "Actualizar propios comentarios o moderador" ON public.comments;
CREATE POLICY "Actualizar propios comentarios o moderador" ON public.comments
    FOR UPDATE TO authenticated
    USING (
        (auth.uid() IS NOT NULL AND (auth.uid() = user_id OR EXISTS (SELECT 1 FROM public.comment_authors WHERE comment_id = comments.id AND user_id = auth.uid())))
        OR public.is_pemtree_moderator(auth.uid())
    );

DROP POLICY IF EXISTS "Users can update their own marketplace items" ON public.marketplace_items;
DROP POLICY IF EXISTS "Users can update their own marketplace items o moderador" ON public.marketplace_items;
CREATE POLICY "Users can update their own marketplace items o moderador" ON public.marketplace_items
    FOR UPDATE TO authenticated
    USING (
        (auth.uid() IS NOT NULL AND auth.uid() = user_id)
        OR public.is_pemtree_moderator(auth.uid())
    );

-- 5. Purga física a 90 días (Art. 20/21) excluyendo registros en retención
CREATE OR REPLACE FUNCTION public.purge_expired_soft_deletes()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
BEGIN
    -- 1. Comentarios expirados
    DELETE FROM public.comments
    WHERE deleted_at IS NOT NULL
      AND deleted_at < (now() - interval '90 days')
      AND is_legal_hold = false
      AND NOT EXISTS (
          SELECT 1 FROM public.posts p
          WHERE p.id = public.comments.post_id AND p.is_legal_hold = true
      );

    -- 2. Publicaciones expiradas (si ningún comentario asociado está en retención)
    DELETE FROM public.posts p
    WHERE p.deleted_at IS NOT NULL
      AND p.deleted_at < (now() - interval '90 days')
      AND p.is_legal_hold = false
      AND NOT EXISTS (
          SELECT 1 FROM public.comments c
          WHERE c.post_id = p.id AND c.is_legal_hold = true
      );

    -- 3. Grupos estudiantiles expirados
    DELETE FROM public.student_groups
    WHERE deleted_at IS NOT NULL
      AND deleted_at < (now() - interval '90 days')
      AND is_legal_hold = false;

    -- 4. Ítems de marketplace expirados
    DELETE FROM public.marketplace_items
    WHERE deleted_at IS NOT NULL
      AND deleted_at < (now() - interval '90 days')
      AND is_legal_hold = false;
END;
$fn$;

REVOKE ALL ON FUNCTION public.purge_expired_soft_deletes() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.purge_expired_soft_deletes() TO postgres, service_role;

-- Programar purga diaria con pg_cron
DO $fn$
DECLARE
    v_job_id bigint;
BEGIN
    SELECT jobid INTO v_job_id FROM cron.job WHERE jobname = 'purge-expired-soft-deletes';
    IF v_job_id IS NOT NULL THEN
        PERFORM cron.unschedule(v_job_id);
    END IF;
    PERFORM cron.schedule(
        'purge-expired-soft-deletes',
        '0 3 * * *',
        'SELECT public.purge_expired_soft_deletes();'
    );
END;
$fn$;


-- =============================================================================
-- BLOQUE 4 — Hot Feed y contadores
-- =============================================================================

-- 1. Añadir métricas en public.posts
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS comments_count integer NOT NULL DEFAULT 0;
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS hot_score double precision NOT NULL DEFAULT 0;
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS expires_at timestamptz NULL;

-- 2. Función de cálculo de Hot Score (algoritmo algorítmico USAC)
CREATE OR REPLACE FUNCTION public.calculate_hot_score(
    p_likes integer,
    p_comments integer,
    p_reposts integer,
    p_created_at timestamptz
)
RETURNS double precision
LANGUAGE plpgsql
STABLE
SET search_path = ''
AS $fn$
DECLARE
    v_points double precision;
    v_hours_age double precision;
BEGIN
    v_points := COALESCE(p_likes, 0) * 1.0 + COALESCE(p_comments, 0) * 2.5 + COALESCE(p_reposts, 0) * 3.0 + 1.0;
    v_hours_age := GREATEST(EXTRACT(EPOCH FROM (now() - COALESCE(p_created_at, now()))) / 3600.0, 0.1);
    RETURN ROUND((v_points / POWER(v_hours_age + 2.0, 1.5))::numeric, 6)::double precision;
END;
$fn$;

GRANT EXECUTE ON FUNCTION public.calculate_hot_score(integer, integer, integer, timestamptz) TO anon, authenticated, service_role;

-- 3. Triggers de sincronización de contadores y hot score

-- a) posts BEFORE INSERT
CREATE OR REPLACE FUNCTION public.handle_post_initial_scores()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
BEGIN
    IF NEW.comments_count IS NULL THEN
        NEW.comments_count := 0;
    END IF;
    NEW.hot_score := public.calculate_hot_score(
        COALESCE(NEW.likes, 0),
        COALESCE(NEW.comments_count, 0),
        COALESCE(NEW.reposts_count, 0),
        COALESCE(NEW.created_at, now())
    );
    RETURN NEW;
END;
$fn$;

DROP TRIGGER IF EXISTS trg_set_post_initial_scores ON public.posts;
CREATE TRIGGER trg_set_post_initial_scores
    BEFORE INSERT ON public.posts
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_post_initial_scores();

-- b) post_likes AFTER INSERT OR DELETE OR UPDATE
CREATE OR REPLACE FUNCTION _triggers.sync_post_likes_counter()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.posts
        SET likes = (SELECT COUNT(*) FROM public.post_likes WHERE post_id = NEW.post_id),
            hot_score = public.calculate_hot_score(
                (SELECT COUNT(*) FROM public.post_likes WHERE post_id = NEW.post_id)::integer,
                comments_count,
                reposts_count,
                created_at
            )
        WHERE id = NEW.post_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.posts
        SET likes = (SELECT COUNT(*) FROM public.post_likes WHERE post_id = OLD.post_id),
            hot_score = public.calculate_hot_score(
                (SELECT COUNT(*) FROM public.post_likes WHERE post_id = OLD.post_id)::integer,
                comments_count,
                reposts_count,
                created_at
            )
        WHERE id = OLD.post_id;
    ELSIF TG_OP = 'UPDATE' THEN
        IF NEW.post_id <> OLD.post_id THEN
            UPDATE public.posts
            SET likes = (SELECT COUNT(*) FROM public.post_likes WHERE post_id = OLD.post_id),
                hot_score = public.calculate_hot_score(
                    (SELECT COUNT(*) FROM public.post_likes WHERE post_id = OLD.post_id)::integer,
                    comments_count,
                    reposts_count,
                    created_at
                )
            WHERE id = OLD.post_id;
            UPDATE public.posts
            SET likes = (SELECT COUNT(*) FROM public.post_likes WHERE post_id = NEW.post_id),
                hot_score = public.calculate_hot_score(
                    (SELECT COUNT(*) FROM public.post_likes WHERE post_id = NEW.post_id)::integer,
                    comments_count,
                    reposts_count,
                    created_at
                )
            WHERE id = NEW.post_id;
        END IF;
    END IF;
    RETURN NULL;
END;
$fn$;

-- c) comments AFTER INSERT OR DELETE OR UPDATE OF moderation_status, deleted_at, post_id
CREATE OR REPLACE FUNCTION public.sync_post_comments_counter()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
DECLARE
    v_post_id uuid;
    v_count integer;
BEGIN
    IF TG_OP = 'INSERT' THEN
        v_post_id := NEW.post_id;
    ELSIF TG_OP = 'DELETE' THEN
        v_post_id := OLD.post_id;
    ELSIF TG_OP = 'UPDATE' THEN
        v_post_id := NEW.post_id;
        IF OLD.post_id IS DISTINCT FROM NEW.post_id AND OLD.post_id IS NOT NULL THEN
            SELECT COUNT(*) INTO v_count
            FROM public.comments
            WHERE post_id = OLD.post_id
              AND moderation_status = 0
              AND deleted_at IS NULL;

            UPDATE public.posts
            SET comments_count = v_count,
                hot_score = public.calculate_hot_score(likes, v_count, reposts_count, created_at)
            WHERE id = OLD.post_id;
        END IF;
    END IF;

    IF v_post_id IS NOT NULL THEN
        SELECT COUNT(*) INTO v_count
        FROM public.comments
        WHERE post_id = v_post_id
          AND moderation_status = 0
          AND deleted_at IS NULL;

        UPDATE public.posts
        SET comments_count = v_count,
            hot_score = public.calculate_hot_score(likes, v_count, reposts_count, created_at)
        WHERE id = v_post_id;
    END IF;

    RETURN NULL;
END;
$fn$;

DROP TRIGGER IF EXISTS trg_sync_post_comments_counter ON public.comments;
CREATE TRIGGER trg_sync_post_comments_counter
    AFTER INSERT OR DELETE OR UPDATE OF moderation_status, deleted_at, post_id
    ON public.comments
    FOR EACH ROW
    EXECUTE FUNCTION public.sync_post_comments_counter();

-- 4. Función y cron para refrescar hot score y soft-delete de posts efímeros
CREATE OR REPLACE FUNCTION public.refresh_active_posts_hot_score()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
BEGIN
    -- Marcar deleted_at en posts efímeros expirados no sujetos a retención
    UPDATE public.posts
    SET deleted_at = now()
    WHERE expires_at IS NOT NULL
      AND expires_at <= now()
      AND deleted_at IS NULL
      AND is_legal_hold = false;

    -- Recalcular hot score de publicaciones activas de las últimas 72 horas
    UPDATE public.posts
    SET hot_score = public.calculate_hot_score(likes, comments_count, reposts_count, created_at)
    WHERE created_at >= (now() - interval '72 hours')
      AND deleted_at IS NULL;
END;
$fn$;

REVOKE ALL ON FUNCTION public.refresh_active_posts_hot_score() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.refresh_active_posts_hot_score() TO postgres, service_role;

DO $fn$
DECLARE
    v_job_id bigint;
BEGIN
    SELECT jobid INTO v_job_id FROM cron.job WHERE jobname = 'refresh-active-posts-hot-score';
    IF v_job_id IS NOT NULL THEN
        PERFORM cron.unschedule(v_job_id);
    END IF;
    PERFORM cron.schedule(
        'refresh-active-posts-hot-score',
        '*/15 * * * *',
        'SELECT public.refresh_active_posts_hot_score();'
    );
END;
$fn$;

-- 5. Índice optimizado para el feed HOT
CREATE INDEX IF NOT EXISTS idx_posts_hot_feed
    ON public.posts (moderation_status, is_pinned DESC, hot_score DESC, created_at DESC)
    WHERE moderation_status = 0 AND deleted_at IS NULL;

-- 6. Inicializar contadores y scores de posts existentes
UPDATE public.posts p
SET comments_count = (
    SELECT COUNT(*)
    FROM public.comments c
    WHERE c.post_id = p.id
      AND c.moderation_status = 0
      AND c.deleted_at IS NULL
);

UPDATE public.posts
SET hot_score = public.calculate_hot_score(likes, comments_count, reposts_count, created_at);


-- =============================================================================
-- BLOQUE 5 — Encuestas y reseñas
-- =============================================================================

-- 1. Asegurar integridad compuesta de encuestas
DO $fn$
DECLARE
    v_confkey int2[];
BEGIN
    SELECT confkey INTO v_confkey
    FROM pg_constraint
    WHERE conrelid = 'public.post_poll_votes'::regclass
      AND conname = 'post_poll_votes_poll_option_fkey';

    IF array_length(v_confkey, 1) = 1 THEN
        ALTER TABLE public.post_poll_votes DROP CONSTRAINT post_poll_votes_poll_option_fkey;
    END IF;
END;
$fn$;

DO $fn$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'public.post_poll_options'::regclass
          AND conname = 'post_poll_options_id_poll_unique'
    ) THEN
        ALTER TABLE public.post_poll_options
            ADD CONSTRAINT post_poll_options_id_poll_unique UNIQUE (id, poll_id);
    END IF;
END;
$fn$;

DO $fn$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'public.post_poll_votes'::regclass
          AND conname = 'post_poll_votes_option_poll_fkey'
    ) THEN
        ALTER TABLE public.post_poll_votes
            ADD CONSTRAINT post_poll_votes_option_poll_fkey
            FOREIGN KEY (option_id, poll_id) REFERENCES public.post_poll_options(id, poll_id) ON DELETE CASCADE;
    END IF;
END;
$fn$;

-- 2. Extender public.seccion_reviews
ALTER TABLE public.seccion_reviews ADD COLUMN IF NOT EXISTS catedratico_nombre text;
ALTER TABLE public.seccion_reviews ADD COLUMN IF NOT EXISTS dificultad smallint;
ALTER TABLE public.seccion_reviews ADD COLUMN IF NOT EXISTS carga_tareas smallint;
ALTER TABLE public.seccion_reviews ADD COLUMN IF NOT EXISTS comentario text;
ALTER TABLE public.seccion_reviews ADD COLUMN IF NOT EXISTS semestre text NOT NULL DEFAULT '1S-2026';
ALTER TABLE public.seccion_reviews ADD COLUMN IF NOT EXISTS upvotes integer NOT NULL DEFAULT 0;

DO $fn$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'public.seccion_reviews'::regclass
          AND conname = 'seccion_reviews_dificultad_check'
    ) THEN
        ALTER TABLE public.seccion_reviews
            ADD CONSTRAINT seccion_reviews_dificultad_check
            CHECK (dificultad IS NULL OR (dificultad BETWEEN 1 AND 5));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'public.seccion_reviews'::regclass
          AND conname = 'seccion_reviews_carga_tareas_check'
    ) THEN
        ALTER TABLE public.seccion_reviews
            ADD CONSTRAINT seccion_reviews_carga_tareas_check
            CHECK (carga_tareas IS NULL OR (carga_tareas BETWEEN 1 AND 5));
    END IF;
END;
$fn$;

-- Sustituir constraint única antigua por seccion_reviews_unique_per_semester
ALTER TABLE public.seccion_reviews DROP CONSTRAINT IF EXISTS unique_user_seccion_review;

DO $fn$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'public.seccion_reviews'::regclass
          AND conname = 'seccion_reviews_unique_per_semester'
    ) THEN
        ALTER TABLE public.seccion_reviews
            ADD CONSTRAINT seccion_reviews_unique_per_semester
            UNIQUE (curso_codigo, seccion, semestre, user_id);
    END IF;
END;
$fn$;


-- =============================================================================
-- BLOQUE 6 — Blindaje RLS y vistas públicas sin user_id
-- =============================================================================

-- 1. Bóveda de autoría: RLS activa, solo autor puede ver su propio registro
ALTER TABLE public.post_authors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comment_authors ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.post_authors FROM anon, authenticated;
REVOKE ALL ON TABLE public.comment_authors FROM anon, authenticated;

GRANT SELECT ON TABLE public.post_authors TO authenticated;
GRANT SELECT ON TABLE public.comment_authors TO authenticated;

DROP POLICY IF EXISTS "Authors can view own post ownership" ON public.post_authors;
CREATE POLICY "Authors can view own post ownership" ON public.post_authors
    FOR SELECT TO authenticated
    USING (auth.uid() IS NOT NULL AND auth.uid() = user_id);

DROP POLICY IF EXISTS "Authors can view own comment ownership" ON public.comment_authors;
CREATE POLICY "Authors can view own comment ownership" ON public.comment_authors
    FOR SELECT TO authenticated
    USING (auth.uid() IS NOT NULL AND auth.uid() = user_id);

-- 2. Funciones auxiliares para verificar pertenencia sin exponer user_id en invoker
CREATE OR REPLACE FUNCTION public.is_my_post(p_post_id uuid)
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
        FROM public.post_authors
        WHERE post_id = p_post_id AND user_id = auth.uid()
    );
END;
$fn$;

CREATE OR REPLACE FUNCTION public.is_my_comment(p_comment_id uuid)
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
        FROM public.comment_authors
        WHERE comment_id = p_comment_id AND user_id = auth.uid()
    );
END;
$fn$;

CREATE OR REPLACE FUNCTION public.is_my_seccion_review(p_review_id uuid)
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
        FROM public.seccion_reviews
        WHERE id = p_review_id AND user_id = auth.uid()
    );
END;
$fn$;

GRANT EXECUTE ON FUNCTION public.is_my_post(uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.is_my_comment(uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.is_my_seccion_review(uuid) TO anon, authenticated;

-- 3. Vistas seguras con security_invoker
CREATE OR REPLACE VIEW public.safe_posts_feed
WITH (security_invoker = true)
AS
SELECT
    p.id,
    p.title,
    p.category,
    p.content,
    p.author_alias,
    p.author_hash,
    p.likes,
    p.reposts_count,
    p.comments_count,
    p.comments_count AS comment_count,
    p.hot_score,
    p.carrera,
    p.image_url,
    p.gif_url,
    p.is_pinned,
    p.quoted_post_id,
    p.created_at,
    p.updated_at,
    p.moderation_status,
    p.moderation_label,
    p.moderation_confidence,
    p.moderation_reason,
    p.moderated_at,
    p.moderated_by,
    p.expires_at,
    p.deleted_at,
    p.is_legal_hold,
    public.is_my_post(p.id) AS is_mine
FROM public.posts p
WHERE p.deleted_at IS NULL
  AND p.moderation_status = 0
  AND (p.expires_at IS NULL OR p.expires_at > now());

CREATE OR REPLACE VIEW public.safe_comments
WITH (security_invoker = true)
AS
SELECT
    c.id,
    c.post_id,
    c.parent_id,
    c.content,
    c.author_alias,
    c.author_hash,
    c.is_op,
    c.is_op AS is_post_author,
    c.likes_count,
    c.gif_url,
    c.created_at,
    c.updated_at,
    c.moderation_status,
    c.moderation_label,
    c.moderation_confidence,
    c.moderation_reason,
    c.moderated_at,
    c.moderated_by,
    c.deleted_at,
    c.is_legal_hold,
    public.is_my_comment(c.id) AS is_mine
FROM public.comments c
WHERE c.deleted_at IS NULL
  AND c.moderation_status = 0;

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
FROM public.seccion_reviews sr;

GRANT SELECT ON public.safe_posts_feed TO anon, authenticated;
GRANT SELECT ON public.safe_comments TO anon, authenticated;
GRANT SELECT ON public.safe_seccion_reviews TO anon, authenticated;

-- Redefinir vistas históricas v_public_posts y v_public_comments por compatibilidad
DROP VIEW IF EXISTS public.v_public_posts;
CREATE VIEW public.v_public_posts
WITH (security_invoker = true)
AS
SELECT
    id,
    title,
    category,
    content,
    author_alias,
    author_hash,
    likes,
    reposts_count,
    carrera,
    image_url,
    gif_url,
    is_pinned,
    quoted_post_id,
    created_at,
    moderation_status,
    comments_count AS comment_count,
    is_mine AS is_my_post
FROM public.safe_posts_feed;

DROP VIEW IF EXISTS public.v_public_comments;
CREATE VIEW public.v_public_comments
WITH (security_invoker = true)
AS
SELECT
    id,
    post_id,
    parent_id,
    content,
    author_alias,
    author_hash,
    gif_url,
    created_at,
    moderation_status,
    is_op AS is_post_author,
    is_mine AS is_my_comment
FROM public.safe_comments;

GRANT SELECT ON public.v_public_posts TO anon, authenticated;
GRANT SELECT ON public.v_public_comments TO anon, authenticated;

-- 4. Revocar SELECT a nivel de tabla en posts, comments, seccion_reviews y otorgar a nivel de columna
REVOKE SELECT ON TABLE public.posts FROM anon, authenticated;
GRANT SELECT (
    id, title, category, content, author_alias, author_hash, likes, carrera,
    image_url, gif_url, is_pinned, quoted_post_id, created_at, moderation_status,
    moderation_label, moderation_confidence, moderation_reason, moderated_at,
    moderated_by, updated_at, reposts_count, comments_count, hot_score, expires_at,
    deleted_at, is_legal_hold
) ON TABLE public.posts TO anon, authenticated;

REVOKE SELECT ON TABLE public.comments FROM anon, authenticated;
GRANT SELECT (
    id, post_id, parent_id, content, author_alias, author_hash, is_op, likes_count,
    gif_url, created_at, updated_at, moderation_status, moderation_label,
    moderation_confidence, moderation_reason, moderated_at, moderated_by,
    deleted_at, is_legal_hold
) ON TABLE public.comments TO anon, authenticated;

REVOKE SELECT ON TABLE public.seccion_reviews FROM anon, authenticated;
GRANT SELECT (
    id, curso_codigo, seccion, recomienda, catedratico_nombre, dificultad,
    carga_tareas, comentario, semestre, upvotes, created_at, updated_at
) ON TABLE public.seccion_reviews TO anon, authenticated;

-- Revocar escrituras de anon en tablas públicas
REVOKE INSERT, UPDATE, DELETE ON TABLE public.posts FROM anon;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.comments FROM anon;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.student_groups FROM anon;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.marketplace_items FROM anon;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.seccion_reviews FROM anon;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.post_authors FROM anon;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.comment_authors FROM anon;

-- =============================================================================
-- HARDENING ADICIONAL (Auditoría del orquestador)
-- =============================================================================

-- DEFECTO 3: Evidencia no destruible mediante TRUNCATE / REFERENCES / TRIGGER / MAINTAIN
REVOKE TRUNCATE, REFERENCES, TRIGGER ON TABLE public.posts FROM anon, authenticated;
REVOKE TRUNCATE, REFERENCES, TRIGGER ON TABLE public.comments FROM anon, authenticated;
REVOKE TRUNCATE, REFERENCES, TRIGGER ON TABLE public.student_groups FROM anon, authenticated;
REVOKE TRUNCATE, REFERENCES, TRIGGER ON TABLE public.marketplace_items FROM anon, authenticated;

DO $maintain$
BEGIN
    REVOKE MAINTAIN ON TABLE public.posts, public.comments, public.student_groups, public.marketplace_items FROM anon, authenticated;
EXCEPTION
    WHEN OTHERS THEN
        NULL;
END;
$maintain$;

-- DEFECTO 2: Mitigación de fuga de user_id en tablas auxiliares y vistas legacy
DROP POLICY IF EXISTS "Permitir lectura de likes a todos" ON public.post_likes;
DROP POLICY IF EXISTS "Leer solo mis likes" ON public.post_likes;
CREATE POLICY "Leer solo mis likes" ON public.post_likes
    FOR SELECT TO authenticated
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Lectura pública de votos" ON public.post_poll_votes;
DROP POLICY IF EXISTS "Leer solo mis votos de encuesta" ON public.post_poll_votes;
CREATE POLICY "Leer solo mis votos de encuesta" ON public.post_poll_votes
    FOR SELECT TO authenticated
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can view upvotes" ON public.marketplace_upvotes;
DROP POLICY IF EXISTS "Leer solo mis upvotes de marketplace" ON public.marketplace_upvotes;
CREATE POLICY "Leer solo mis upvotes de marketplace" ON public.marketplace_upvotes
    FOR SELECT TO authenticated
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Lectura pública de votos de grupos" ON public.student_group_upvotes;
DROP POLICY IF EXISTS "Leer solo mis upvotes de grupos" ON public.student_group_upvotes;
CREATE POLICY "Leer solo mis upvotes de grupos" ON public.student_group_upvotes
    FOR SELECT TO authenticated
    USING (auth.uid() = user_id);

REVOKE SELECT ON TABLE public.post_likes FROM anon;
REVOKE SELECT ON TABLE public.post_poll_votes FROM anon;
REVOKE SELECT ON TABLE public.marketplace_upvotes FROM anon;
REVOKE SELECT ON TABLE public.student_group_upvotes FROM anon;

-- Recrear vistas legacy con WITH (security_invoker = true) y revocar SELECT de anon
CREATE OR REPLACE VIEW public.marketplace_reports WITH (security_invoker = true) AS
SELECT id,
    entity_id AS item_id,
    reporter_id AS user_id,
    reason,
    created_at,
    entity_owner_id AS seller_user_id,
    (metadata ->> 'seller_alias'::text) AS seller_alias,
    COALESCE((metadata ->> 'legacy_status'::text), 'pending'::text) AS status,
    moderation_status,
    moderation_label,
    moderation_confidence,
    moderation_reason,
    moderated_at,
    moderated_by
FROM public.entity_reports er
WHERE (entity_type = 'marketplace_item'::text);

CREATE OR REPLACE VIEW public.student_group_reports WITH (security_invoker = true) AS
SELECT entity_id AS group_id,
    reporter_id AS user_id,
    reason,
    created_at,
    moderation_status,
    moderation_label,
    moderation_confidence,
    moderation_reason,
    moderated_at,
    moderated_by
FROM public.entity_reports er
WHERE (entity_type = 'group'::text);

CREATE OR REPLACE VIEW public.user_reports WITH (security_invoker = true) AS
SELECT id,
    reporter_id,
    reported_user_id,
    (metadata ->> 'reported_user_alias'::text) AS reported_user_alias,
    reason,
    created_at,
    moderation_status,
    moderation_label,
    moderation_confidence,
    moderation_reason,
    moderated_at,
    moderated_by
FROM public.entity_reports er
WHERE (entity_type = 'user'::text);

CREATE OR REPLACE VIEW public.whatsapp_group_upvotes WITH (security_invoker = true) AS
SELECT group_id,
    user_id,
    created_at
FROM public.student_group_upvotes;

CREATE OR REPLACE VIEW public.whatsapp_group_reports WITH (security_invoker = true) AS
SELECT group_id,
    user_id,
    reason,
    created_at,
    moderation_status,
    moderation_label,
    moderation_confidence,
    moderation_reason,
    moderated_at,
    moderated_by
FROM public.student_group_reports;

REVOKE SELECT ON public.whatsapp_group_upvotes FROM anon;
REVOKE SELECT ON public.marketplace_reports FROM anon;
REVOKE SELECT ON public.student_group_reports FROM anon;
REVOKE SELECT ON public.user_reports FROM anon;
REVOKE SELECT ON public.whatsapp_group_reports FROM anon;
