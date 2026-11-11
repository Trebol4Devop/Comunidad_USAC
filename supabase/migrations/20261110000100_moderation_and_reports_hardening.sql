-- =====================================================================
-- Migración: 20261110000100_moderation_and_reports_hardening.sql
-- Módulo: Hardening de Moderación Automatizada y Prevención de Ciberdelitos
-- Agente 2
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. TAREA 1: Validación estricta de author_alias (Art. 12)
-- ---------------------------------------------------------------------

-- Catálogos cerrados de sustantivos y adjetivos para alias anónimos
CREATE TABLE IF NOT EXISTS public.alias_nouns (
    term text PRIMARY KEY
);

CREATE TABLE IF NOT EXISTS public.alias_adjectives (
    term text PRIMARY KEY
);

ALTER TABLE public.alias_nouns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.alias_adjectives ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Permitir lectura publica alias_nouns" ON public.alias_nouns;
CREATE POLICY "Permitir lectura publica alias_nouns"
    ON public.alias_nouns
    FOR SELECT
    TO anon, authenticated
    USING (true);

DROP POLICY IF EXISTS "Permitir lectura publica alias_adjectives" ON public.alias_adjectives;
CREATE POLICY "Permitir lectura publica alias_adjectives"
    ON public.alias_adjectives
    FOR SELECT
    TO anon, authenticated
    USING (true);

GRANT SELECT ON TABLE public.alias_nouns TO anon, authenticated, service_role;
GRANT SELECT ON TABLE public.alias_adjectives TO anon, authenticated, service_role;

-- Siembra de sustantivos autorizados (idempotente)
INSERT INTO public.alias_nouns (term) VALUES
    ('Compilador'),
    ('Puntero'),
    ('Fantasma'),
    ('Sobreviviente'),
    ('Recursivo'),
    ('Kernel'),
    ('Bit'),
    ('Array'),
    ('Servidor'),
    ('Algoritmo'),
    ('Depurador'),
    ('Hilo'),
    ('Buffer'),
    ('Binario'),
    ('Parqueo'),
    ('Cafetero'),
    ('Sancarlista'),
    ('Búho'),
    ('Volcán'),
    ('Chicharra'),
    ('Referencia'),
    ('Mutex'),
    ('Paquete'),
    ('Semáforo'),
    ('Nodo'),
    ('Byte'),
    ('Caché'),
    ('Correo'),
    ('Monitor'),
    ('Teclado'),
    ('Código'),
    ('Parcial'),
    ('Laboratorio'),
    ('Examen'),
    ('Proyecto'),
    ('Carrera'),
    ('Catedrático'),
    ('Estudiante')
ON CONFLICT (term) DO NOTHING;

-- Siembra de adjetivos autorizados (idempotente, sin duplicados)
INSERT INTO public.alias_adjectives (term) VALUES
    ('Desvelado'),
    ('Sin Semestre'),
    ('En Llamas'),
    ('Del T-3'),
    ('Nocturno'),
    ('Ansioso'),
    ('Perdido'),
    ('Sin Café'),
    ('De Madrugada'),
    ('Empapelado'),
    ('Reprobado'),
    ('Recursivo'),
    ('Sin Sueño'),
    ('Del Lab'),
    ('En Parciales'),
    ('Caffeinado'),
    ('Fantasmal'),
    ('Anónimo'),
    ('Clandestino'),
    ('Invisible'),
    ('Sin Créditos'),
    ('Del Bloque'),
    ('De Turno'),
    ('Sin Notas'),
    ('Iluminado'),
    ('Confundido'),
    ('Apurado'),
    ('Del Bus'),
    ('En Crisis'),
    ('Sin WiFi'),
    ('Sin Almuerzo'),
    ('Del Grupo'),
    ('En Línea'),
    ('De Siempre'),
    ('Sin Plan')
ON CONFLICT (term) DO NOTHING;

-- Función de validación de alias anónimos cerrados (Art. 12)
CREATE OR REPLACE FUNCTION public.is_valid_anonymous_alias(p_alias text)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $fn$
DECLARE
    v_norm text;
    v_first_space integer;
    v_noun text;
    v_adj text;
BEGIN
    IF p_alias IS NULL THEN
        RETURN false;
    END IF;

    -- Normalizar: trim y colapsar espacios en blanco consecutivos
    v_norm := trim(regexp_replace(p_alias, '\s+', ' ', 'g'));
    IF v_norm = '' THEN
        RETURN false;
    END IF;

    -- Longitud máxima 48 caracteres
    IF char_length(v_norm) > 48 THEN
        RETURN false;
    END IF;

    -- No debe contener @ ni secuencias de dominio/correo web
    IF v_norm ~ '@' OR v_norm ~* '\.[a-z]{2,}' THEN
        RETURN false;
    END IF;

    -- No debe contener 5 o más dígitos consecutivos (carné, CUI, teléfono)
    IF v_norm ~ '\d{5,}' THEN
        RETURN false;
    END IF;

    -- No debe contener títulos académicos seguidos de nombre propio
    IF v_norm ~* '(^|\s)(ing|lic|dr|dra|arq|msc|mtra|prof|doctor|doctora|licenciado|licenciada|ingeniero|ingeniera)\.?\s+[A-ZÁÉÍÓÚÑ]' THEN
        RETURN false;
    END IF;

    -- Valores estándar por defecto permitidos
    IF v_norm IN ('Estudiante Anónimo', 'Estudiante Emprendedor', 'Estudiante') THEN
        RETURN true;
    END IF;

    -- Patrón legacy permitido
    IF v_norm ~ '^Estudiante [A-Za-zÁÉÍÓÚÑáéíóúñ]+ #[0-9]{1,4}$' THEN
        RETURN true;
    END IF;

    -- Formato SUSTANTIVO ADJETIVO: sustantivo = primera palabra, adjetivo = resto
    v_first_space := position(' ' in v_norm);
    IF v_first_space = 0 THEN
        RETURN false;
    END IF;

    v_noun := substring(v_norm from 1 for v_first_space - 1);
    v_adj := substring(v_norm from v_first_space + 1);

    IF v_noun = '' OR v_adj = '' THEN
        RETURN false;
    END IF;

    -- Comparación exacta case-sensitive en los catálogos autorizados
    RETURN EXISTS (
        SELECT 1 FROM public.alias_nouns n WHERE n.term = v_noun
    ) AND EXISTS (
        SELECT 1 FROM public.alias_adjectives a WHERE a.term = v_adj
    );
END;
$fn$;

REVOKE ALL ON FUNCTION public.is_valid_anonymous_alias(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_valid_anonymous_alias(text) TO anon, authenticated, service_role;

-- Función generadora de alias anónimos aleatorios autorizados
CREATE OR REPLACE FUNCTION public.generate_anonymous_alias()
RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = ''
AS $fn$
DECLARE
    v_noun text;
    v_adj text;
BEGIN
    SELECT term INTO v_noun
    FROM public.alias_nouns
    ORDER BY random()
    LIMIT 1;

    SELECT term INTO v_adj
    FROM public.alias_adjectives
    ORDER BY random()
    LIMIT 1;

    IF v_noun IS NULL OR v_adj IS NULL THEN
        RETURN 'Estudiante Anónimo';
    END IF;

    RETURN v_noun || ' ' || v_adj;
END;
$fn$;

REVOKE ALL ON FUNCTION public.generate_anonymous_alias() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.generate_anonymous_alias() FROM anon;
GRANT EXECUTE ON FUNCTION public.generate_anonymous_alias() TO authenticated, service_role;

-- Función trigger para validar y normalizar author_alias antes de insertar o modificar
CREATE OR REPLACE FUNCTION public.check_author_alias_validity()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
DECLARE
    v_norm text;
BEGIN
    IF NEW.author_alias IS NULL THEN
        RAISE EXCEPTION 'Alias no permitido: usa el generador anónimo (Art. 12)'
            USING ERRCODE = '23514';
    END IF;

    v_norm := trim(regexp_replace(NEW.author_alias, '\s+', ' ', 'g'));
    NEW.author_alias := v_norm;

    IF NOT public.is_valid_anonymous_alias(v_norm) THEN
        RAISE EXCEPTION 'Alias no permitido: usa el generador anónimo (Art. 12)'
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$fn$;

REVOKE ALL ON FUNCTION public.check_author_alias_validity() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.check_author_alias_validity() TO anon, authenticated, service_role;

-- Triggers de validación en posts, comments, student_groups y marketplace_items
DROP TRIGGER IF EXISTS trg_validate_author_alias_posts ON public.posts;
CREATE TRIGGER trg_validate_author_alias_posts
    BEFORE INSERT OR UPDATE OF author_alias ON public.posts
    FOR EACH ROW
    EXECUTE FUNCTION public.check_author_alias_validity();

DROP TRIGGER IF EXISTS trg_validate_author_alias_comments ON public.comments;
CREATE TRIGGER trg_validate_author_alias_comments
    BEFORE INSERT OR UPDATE OF author_alias ON public.comments
    FOR EACH ROW
    EXECUTE FUNCTION public.check_author_alias_validity();

DROP TRIGGER IF EXISTS trg_validate_author_alias_student_groups ON public.student_groups;
CREATE TRIGGER trg_validate_author_alias_student_groups
    BEFORE INSERT OR UPDATE OF author_alias ON public.student_groups
    FOR EACH ROW
    EXECUTE FUNCTION public.check_author_alias_validity();

DROP TRIGGER IF EXISTS trg_validate_author_alias_marketplace_items ON public.marketplace_items;
CREATE TRIGGER trg_validate_author_alias_marketplace_items
    BEFORE INSERT OR UPDATE OF author_alias ON public.marketplace_items
    FOR EACH ROW
    EXECUTE FUNCTION public.check_author_alias_validity();


-- ---------------------------------------------------------------------
-- 2. Actualización de prevent_nonmoderator_restore para permitir triggers anidados
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.prevent_nonmoderator_restore()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
DECLARE
    v_uid uuid := auth.uid();
BEGIN
    -- Permitir operaciones internas del sistema y triggers anidados (auto-cuarentena)
    IF pg_trigger_depth() > 1 THEN
        RETURN NEW;
    END IF;

    IF v_uid IS NULL THEN
        RETURN NEW;
    END IF;

    IF public.is_pemtree_admin(v_uid) OR public.is_pemtree_moderator(v_uid) THEN
        RETURN NEW;
    END IF;

    -- Si el contenido fue ocultado (2), ningún usuario común puede restaurarlo
    IF OLD.moderation_status = 2 AND NEW.moderation_status IS DISTINCT FROM 2 THEN
        RAISE EXCEPTION 'Permiso denegado: Una vez ocultado, solo un administrador o moderador puede restaurar este contenido.';
    END IF;

    -- Los usuarios comunes no pueden modificar manualmente moderation_status
    IF NEW.moderation_status IS DISTINCT FROM OLD.moderation_status AND NEW.moderation_status IS DISTINCT FROM 2 THEN
        RAISE EXCEPTION 'Permiso denegado: Una vez ocultado, solo un administrador o moderador puede restaurar este contenido.';
    END IF;

    RETURN NEW;
END;
$fn$;

REVOKE ALL ON FUNCTION public.prevent_nonmoderator_restore() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.prevent_nonmoderator_restore() TO anon, authenticated, service_role;


-- ---------------------------------------------------------------------
-- 3. TAREA 2: Auto-cuarentena por 3 reportes (entity_reports)
-- ---------------------------------------------------------------------

-- Helper para categorizar razones de reporte de alto riesgo
CREATE OR REPLACE FUNCTION public.is_risk_report_reason(p_reason text)
RETURNS boolean
LANGUAGE plpgsql
IMMUTABLE
SECURITY DEFINER
SET search_path = ''
AS $fn$
DECLARE
    v_norm text;
BEGIN
    IF p_reason IS NULL THEN
        RETURN false;
    END IF;

    v_norm := lower(translate(trim(regexp_replace(p_reason, '\s+', ' ', 'g')), 'áéíóúÁÉÍÓÚ', 'aeiouaeiou'));

    RETURN (
        v_norm ~ '(acoso|difamacion|informacion personal|doxxing|pii|venta ilegal|servicios prohibidos|suplantacion|impersonation|amenaza|threat|fraude|fraud|extorsion|acceso ilicito|access_abuse)'
    );
END;
$fn$;

REVOKE ALL ON FUNCTION public.is_risk_report_reason(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_risk_report_reason(text) TO anon, authenticated, service_role;

-- Trigger AFTER INSERT en entity_reports para auto-cuarentena inmediata
CREATE OR REPLACE FUNCTION public.handle_entity_report_auto_quarantine()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
DECLARE
    v_table text;
    v_risk_count integer;
    v_entity_updated boolean := false;
BEGIN
    -- 1. Mapeo de entity_type a tabla física
    v_table := CASE NEW.entity_type
        WHEN 'post' THEN 'posts'
        WHEN 'comment' THEN 'comments'
        WHEN 'group' THEN 'student_groups'
        WHEN 'student_group' THEN 'student_groups'
        WHEN 'marketplace_item' THEN 'marketplace_items'
        ELSE NULL
    END;

    IF v_table IS NULL THEN
        RETURN NEW;
    END IF;

    -- 2. Conteo de usuarios únicos que reportaron por motivos de riesgo
    SELECT COUNT(DISTINCT er.reporter_id)
    INTO v_risk_count
    FROM public.entity_reports er
    WHERE er.entity_type = NEW.entity_type
      AND er.entity_id = NEW.entity_id
      AND public.is_risk_report_reason(er.reason);

    -- 3. Si hay 3 o más reportes de riesgo, aplicar auto-cuarentena
    IF v_risk_count >= 3 THEN
        IF v_table = 'posts' THEN
            UPDATE public.posts
            SET moderation_status = 1,
                is_legal_hold = true,
                updated_at = now()
            WHERE id = NEW.entity_id;
            v_entity_updated := FOUND;
        ELSIF v_table = 'comments' THEN
            UPDATE public.comments
            SET moderation_status = 1,
                is_legal_hold = true,
                updated_at = now()
            WHERE id = NEW.entity_id;
            v_entity_updated := FOUND;
        ELSIF v_table = 'student_groups' THEN
            UPDATE public.student_groups
            SET moderation_status = 1,
                is_legal_hold = true,
                updated_at = now()
            WHERE id = NEW.entity_id;
            v_entity_updated := FOUND;
        ELSIF v_table = 'marketplace_items' THEN
            UPDATE public.marketplace_items
            SET moderation_status = 1,
                is_legal_hold = true,
                updated_at = now()
            WHERE id = NEW.entity_id;
            v_entity_updated := FOUND;
        END IF;

        -- No continuar si la entidad ya no existe
        IF NOT v_entity_updated THEN
            RETURN NEW;
        END IF;

        -- Asegurar trabajo en public.moderation_jobs con prioridad 10
        UPDATE public.moderation_jobs
        SET priority = 10,
            updated_at = now()
        WHERE id = (
            SELECT id
            FROM public.moderation_jobs
            WHERE entity_table = v_table
              AND entity_id = NEW.entity_id
              AND status IN ('pending', 'processing')
            ORDER BY priority ASC, created_at ASC
            LIMIT 1
        );

        IF NOT FOUND THEN
            INSERT INTO public.moderation_jobs (
                entity_table,
                entity_id,
                content_hash,
                priority,
                status
            ) VALUES (
                v_table,
                NEW.entity_id,
                'autoquarantine:' || NEW.id::text,
                10,
                'pending'
            )
            ON CONFLICT (entity_table, entity_id, content_hash)
            DO UPDATE SET priority = 10, updated_at = now();
        END IF;

        -- Registro de auditoría automatizada (idempotente)
        IF NOT EXISTS (
            SELECT 1
            FROM public.moderation_audit_log
            WHERE entity_table = v_table
              AND entity_id = NEW.entity_id
              AND moderation_label = 'COMMUNITY_AUTO_QUARANTINE'
        ) THEN
            INSERT INTO public.moderation_audit_log (
                moderator_id,
                entity_table,
                entity_id,
                justification,
                is_automated,
                moderation_label,
                confidence,
                created_at
            ) VALUES (
                NULL,
                v_table,
                NEW.entity_id,
                'Auto-cuarentena: 3+ reportes de riesgo',
                true,
                'COMMUNITY_AUTO_QUARANTINE',
                1.0,
                now()
            );
        END IF;
    END IF;

    RETURN NEW;
END;
$fn$;

REVOKE ALL ON FUNCTION public.handle_entity_report_auto_quarantine() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.handle_entity_report_auto_quarantine() TO anon, authenticated, service_role;

DROP TRIGGER IF EXISTS trg_entity_reports_auto_quarantine ON public.entity_reports;
CREATE TRIGGER trg_entity_reports_auto_quarantine
    AFTER INSERT ON public.entity_reports
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_entity_report_auto_quarantine();


-- ---------------------------------------------------------------------
-- 4. TAREA 3 (SQL): claim_moderation_jobs con FOR UPDATE SKIP LOCKED
-- ---------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.claim_moderation_jobs(
    p_worker_id text,
    p_limit integer DEFAULT 10
)
RETURNS SETOF public.moderation_jobs
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $fn$
BEGIN
    -- Liberar jobs colgados en processing por más de 10 minutos
    UPDATE public.moderation_jobs AS mj
    SET status = CASE WHEN mj.attempts >= mj.max_attempts THEN 'failed' ELSE 'pending' END,
        last_error = coalesce(mj.last_error, 'Worker sin respuesta (job colgado)'),
        locked_by = NULL,
        locked_at = NULL,
        updated_at = now()
    WHERE mj.status = 'processing'
      AND mj.locked_at < now() - interval '10 minutes';

    -- Reclamar concurrentemente usando FOR UPDATE SKIP LOCKED
    RETURN QUERY
    WITH candidate_jobs AS (
        SELECT id
        FROM public.moderation_jobs
        WHERE status = 'pending'
          AND run_after <= now()
          AND attempts < max_attempts
        ORDER BY priority ASC, created_at ASC
        FOR UPDATE SKIP LOCKED
        LIMIT GREATEST(1, coalesce(p_limit, 10))
    )
    UPDATE public.moderation_jobs j
    SET status = 'processing',
        locked_by = p_worker_id,
        locked_at = now(),
        attempts = j.attempts + 1,
        updated_at = now()
    FROM candidate_jobs c
    WHERE j.id = c.id
    RETURNING j.*;
END;
$fn$;

REVOKE ALL ON FUNCTION public.claim_moderation_jobs(text, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.claim_moderation_jobs(text, integer) FROM anon;
REVOKE ALL ON FUNCTION public.claim_moderation_jobs(text, integer) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.claim_moderation_jobs(text, integer) TO service_role, postgres;
