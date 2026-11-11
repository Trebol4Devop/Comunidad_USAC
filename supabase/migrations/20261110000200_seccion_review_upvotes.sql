-- =====================================================================
-- Migración: 20261110000200_seccion_review_upvotes.sql
-- Módulo: Upvotes de Reseñas de Secciones y Recálculo Automático
-- Agente 3D
-- =====================================================================

-- 1. Tabla public.seccion_review_upvotes
CREATE TABLE IF NOT EXISTS public.seccion_review_upvotes (
    review_id uuid NOT NULL REFERENCES public.seccion_reviews(id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (review_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_seccion_review_upvotes_user_id
    ON public.seccion_review_upvotes(user_id);

CREATE INDEX IF NOT EXISTS idx_seccion_review_upvotes_review_id
    ON public.seccion_review_upvotes(review_id);

-- 2. Habilitar RLS y políticas de acceso
ALTER TABLE public.seccion_review_upvotes ENABLE ROW LEVEL SECURITY;

-- Revocar acceso a anon
REVOKE ALL ON TABLE public.seccion_review_upvotes FROM anon;

-- Concesión de operaciones estrictas a authenticated y service_role
GRANT SELECT, INSERT, DELETE ON TABLE public.seccion_review_upvotes TO authenticated;
GRANT ALL ON TABLE public.seccion_review_upvotes TO service_role;

-- Políticas RLS
DROP POLICY IF EXISTS "seccion_review_upvotes_select_own" ON public.seccion_review_upvotes;
CREATE POLICY "seccion_review_upvotes_select_own"
    ON public.seccion_review_upvotes
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "seccion_review_upvotes_insert_own" ON public.seccion_review_upvotes;
CREATE POLICY "seccion_review_upvotes_insert_own"
    ON public.seccion_review_upvotes
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "seccion_review_upvotes_delete_own" ON public.seccion_review_upvotes;
CREATE POLICY "seccion_review_upvotes_delete_own"
    ON public.seccion_review_upvotes
    FOR DELETE
    TO authenticated
    USING (auth.uid() = user_id);

-- 3. Trigger para sincronizar upvotes en public.seccion_reviews
CREATE OR REPLACE FUNCTION public.sync_seccion_review_upvotes()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
DECLARE
    v_review_id uuid;
BEGIN
    IF TG_OP = 'INSERT' THEN
        v_review_id := NEW.review_id;
    ELSE
        v_review_id := OLD.review_id;
    END IF;

    UPDATE public.seccion_reviews
    SET upvotes = (
        SELECT COUNT(*)::integer
        FROM public.seccion_review_upvotes
        WHERE review_id = v_review_id
    )
    WHERE id = v_review_id;

    RETURN NULL;
END;
$fn$;

DROP TRIGGER IF EXISTS trg_sync_seccion_review_upvotes ON public.seccion_review_upvotes;
CREATE TRIGGER trg_sync_seccion_review_upvotes
    AFTER INSERT OR DELETE ON public.seccion_review_upvotes
    FOR EACH ROW
    EXECUTE FUNCTION public.sync_seccion_review_upvotes();

-- 4. Función RPC para toggle de upvote de reseña
CREATE OR REPLACE FUNCTION public.upvote_seccion_review(p_review_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
DECLARE
    v_user_id uuid;
    v_exists boolean;
    v_has_upvoted boolean;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'No autenticado' USING ERRCODE = '42501';
    END IF;

    -- Verificar que la reseña exista
    SELECT EXISTS (
        SELECT 1 FROM public.seccion_reviews WHERE id = p_review_id
    ) INTO v_exists;

    IF NOT v_exists THEN
        RETURN false;
    END IF;

    -- Comprobar si ya existe el upvote del usuario
    SELECT EXISTS (
        SELECT 1
        FROM public.seccion_review_upvotes
        WHERE review_id = p_review_id
          AND user_id = v_user_id
    ) INTO v_has_upvoted;

    IF v_has_upvoted THEN
        -- Ya existe el upvote -> lo borra y devuelve false
        DELETE FROM public.seccion_review_upvotes
        WHERE review_id = p_review_id
          AND user_id = v_user_id;
        RETURN false;
    ELSE
        -- No existe -> lo inserta y devuelve true
        INSERT INTO public.seccion_review_upvotes (review_id, user_id, created_at)
        VALUES (p_review_id, v_user_id, pg_catalog.now());
        RETURN true;
    END IF;
END;
$fn$;

REVOKE ALL ON FUNCTION public.upvote_seccion_review(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.upvote_seccion_review(uuid) TO authenticated, service_role;

-- 5. Inicializar conteo de upvotes para reseñas existentes
UPDATE public.seccion_reviews sr
SET upvotes = (
    SELECT COUNT(*)::integer
    FROM public.seccion_review_upvotes sru
    WHERE sru.review_id = sr.id
);
