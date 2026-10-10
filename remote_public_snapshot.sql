


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE SCHEMA IF NOT EXISTS "public";


ALTER SCHEMA "public" OWNER TO "pg_database_owner";


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE OR REPLACE FUNCTION "public"."apply_moderation_batch"("p_items" "jsonb") RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_item jsonb;
    v_table text;
    v_id uuid;
    v_key uuid;
    v_label text;
    v_confidence double precision;
    v_reason text;
    v_status integer;
    v_updated integer := 0;
    v_audit_log uuid;
BEGIN
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_table  := v_item->>'table';
        v_id     := (v_item->>'id')::uuid;
        v_key    := NULLIF(v_item->>'key', '')::uuid;
        v_label  := COALESCE(v_item->>'label', 'error');
        v_confidence := COALESCE((v_item->>'confidence')::double precision, 0.0);
        v_reason := v_item->>'reason';

        v_status := CASE v_label
            WHEN 'appropriate' THEN 1
            WHEN 'inappropriate' THEN 2
            ELSE 3
        END;

        IF v_table = 'posts' THEN
            UPDATE public.posts SET moderation_status = v_status, moderation_label = v_label,
                moderation_confidence = v_confidence, moderation_reason = v_reason,
                moderated_at = now(), moderated_by = NULL
            WHERE id = v_id;
        ELSIF v_table = 'comments' THEN
            UPDATE public.comments SET moderation_status = v_status, moderation_label = v_label,
                moderation_confidence = v_confidence, moderation_reason = v_reason,
                moderated_at = now(), moderated_by = NULL
            WHERE id = v_id;
        ELSIF v_table = 'whatsapp_groups' THEN
            UPDATE public.whatsapp_groups SET moderation_status = v_status, moderation_label = v_label,
                moderation_confidence = v_confidence, moderation_reason = v_reason,
                moderated_at = now(), moderated_by = NULL
            WHERE id = v_id;
        ELSIF v_table = 'user_reports' THEN
            UPDATE public.user_reports SET moderation_status = v_status, moderation_label = v_label,
                moderation_confidence = v_confidence, moderation_reason = v_reason,
                moderated_at = now(), moderated_by = NULL
            WHERE id = v_id;
        ELSIF v_table = 'whatsapp_group_reports' THEN
            UPDATE public.whatsapp_group_reports SET moderation_status = v_status, moderation_label = v_label,
                moderation_confidence = v_confidence, moderation_reason = v_reason,
                moderated_at = now(), moderated_by = NULL
            WHERE group_id = v_id AND user_id = v_key;
        ELSE
            CONTINUE;
        END IF;

        IF FOUND THEN
            INSERT INTO public.moderation_audit_log
                (moderator_id, entity_table, entity_id, justification, is_automated, moderation_label, confidence)
            VALUES
                (NULL, v_table, v_id, COALESCE(v_reason, ''), true, v_label, v_confidence)
            RETURNING id INTO v_audit_log;
            v_updated := v_updated + 1;
        END IF;
    END LOOP;

    RETURN v_updated;
END;
$$;


ALTER FUNCTION "public"."apply_moderation_batch"("p_items" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."check_content_moderation"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'pg_catalog'
    AS $_$
            DECLARE
                new_row JSONB := to_jsonb(NEW);
                clean_text TEXT := '';
                compact_text TEXT;
                word TEXT;
                key TEXT;
                val TEXT;

                forbidden_words TEXT[] := ARRAY[
                    'cerote', 'cerota', 'cerotes', 'cerotas', 'mula', 'mulas', 'mulada', 'muladas',
                    'pisado', 'pisada', 'pisados', 'pisadas', 'shumo', 'shuma', 'marote', 'taliche',
                    'huevon', 'huevona', 'huevones', 'culero', 'culera', 'culeros', 'culo', 'culito',
                    'pija', 'pijas', 'pijazo', 'verga', 'vergas', 'vergazo', 'verguiza', 'cagada',
                    'cagadas', 'cagon', 'cagona', 'mierda', 'mierdas', 'mierdero', 'caca', 'cacas',
                    'malparido', 'malparida', 'hijueputa', 'hijueputas', 'hijo de puta', 'hp', 'hdp',
                    'ptm', 'alv', 'vtl',
                    'pendejo', 'pendeja', 'pendejos', 'pendejas', 'idiota', 'idiotas', 'estupido',
                    'estupida', 'estupidos', 'estupidas', 'imbecil', 'imbeciles', 'puta', 'putas',
                    'puto', 'putos', 'putazo', 'putazos', 'putero', 'cabron', 'cabrona', 'cabrones',
                    'chingar', 'chinga', 'chingada', 'chingadazo', 'pinche', 'pinches', 'gonorrea',
                    'mamahuevos', 'mamada', 'mamadas', 'tarado', 'tarada', 'tarados', 'zorete',
                    'zorra', 'zorras', 'perra', 'perras', 'asqueroso', 'asquerosa', 'puerco', 'puerca',
                    'mongol', 'mongoles', 'mongolito', 'mongolita', 'bastardo', 'bastarda', 'maricon',
                    'maricones', 'marica', 'maricas', 'joder', 'jodido', 'jodida', 'subnormal',
                    'subnormales', 'lacra', 'lacras', 'baboso', 'babosa', 'babosos', 'mamon', 'mamona',
                    'fuck', 'fucker', 'fuckers', 'fucking', 'motherfucker', 'motherfuckers', 'fucktard',
                    'shit', 'shits', 'shitty', 'bullshit', 'dipshit', 'shithead', 'bitch', 'bitches',
                    'asshole', 'assholes', 'dumbass', 'jackass', 'bastard', 'bastards', 'scumbag',
                    'dick', 'dickhead', 'cock', 'cocksucker', 'pussy', 'pussies', 'cunt', 'cunts',
                    'twat', 'wanker', 'prick', 'whore', 'slut', 'sluts', 'douchebag', 'skank',
                    'retard', 'retarded', 'nigger', 'niggers', 'nigga', 'niggas', 'faggot', 'fags'
                ];

                forbidden_links TEXT[] := ARRAY[
                    'porn', 'xxx', 'xvideos', 'pornhub', 'onlyfans', 'xhamster', 'redtube',
                    'brazzers', 'chaturbate', 'xnxx', 'eporner', 'youporn', 'spankbang', 'hentai',
                    'sex', 'nude', 'pack de', 'packs de', 'camgirls',
                    'casino', 'bet365', '1xbet', 'poker', 'slots', 'apuestas', 'rushbet',
                    'codere', 'sportingbet', 'roulette', 'jackpot',
                    'bit.ly', 'tinyurl.com', 't.co/', 'is.gd', 'cutt.ly', 'shorte.st', 'adf.ly',
                    'shrinkme', 'ow.ly', 'buff.ly', 'bl.ink',
                    '.exe', '.apk', '.bat', '.scr', '.vbs', '.msi', '.xyz', '.top', '.ru', '.tk', '.biz',
                    'trojan', 'keygen', 'phishing'
                ];
            BEGIN
                FOR key, val IN SELECT k, v FROM jsonb_each_text(new_row) AS e(k, v)
                LOOP
                    IF key = 'id'
                       OR key LIKE '%\_id'
                       OR key = 'image_url'
                       OR key LIKE 'moderation\_%'
                       OR key = 'moderated_by'
                       OR key LIKE '%\_at'
                    THEN
                        CONTINUE;
                    END IF;
                    clean_text := clean_text || ' ' || COALESCE(val, '');
                END LOOP;

                clean_text := LOWER(clean_text);

                clean_text := TRANSLATE(clean_text, '013457@$!v', 'oieastasiu');
                clean_text := TRANSLATE(clean_text, 'áéíóúüñÁÉÍÓÚÜÑ', 'aeiouunAEIOUUN');

                compact_text := REGEXP_REPLACE(clean_text, '[\s\-_\.\*\+\?\!|/()\[\]{}:,;~#%&^=]', '', 'g');

                IF compact_text ~* '(.)\1{12,}' THEN
                    RAISE EXCEPTION 'El mensaje contiene caracteres repetidos excesivamente. (Rechazado por moderación de Base de Datos)';
                END IF;

                FOREACH word IN ARRAY forbidden_words
                LOOP
                    IF clean_text ~* ('\y' || word || '\y') THEN
                        RAISE EXCEPTION 'El contenido contiene lenguaje inapropiado u ofensivo ("%"). (Rechazado por moderación de Base de Datos)', word;
                    END IF;
                END LOOP;

                FOREACH word IN ARRAY forbidden_links
                LOOP
                    IF LEFT(word, 1) = '.' THEN
                        IF clean_text ~* ('\' || word || '(\/|\?|\y|$)') THEN
                            RAISE EXCEPTION 'El contenido incluye enlaces inapropiados o no autorizados ("%"). (Rechazado por moderación de Base de Datos)', word;
                        END IF;
                    ELSE
                        IF clean_text ~* ('\y' || word || '\y') OR clean_text ~* ('\.' || word || '\.') OR clean_text ~* ('\/' || word || '(\/|\?|\y|$)') THEN
                            RAISE EXCEPTION 'El contenido incluye enlaces inapropiados o no autorizados ("%"). (Rechazado por moderación de Base de Datos)', word;
                        END IF;
                    END IF;
                END LOOP;

                RETURN NEW;
            END;
            $_$;


ALTER FUNCTION "public"."check_content_moderation"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."check_whatsapp_groups_limit"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
    DECLARE
        v_count integer;
        v_target_user uuid := COALESCE(auth.uid(), NEW.user_id);
    BEGIN
        IF public.is_pemtree_admin(auth.uid()) OR public.is_pemtree_moderator(auth.uid()) THEN
            RETURN NEW;
        END IF;

        SELECT COUNT(*) INTO v_count
        FROM public.whatsapp_groups
        WHERE user_id = v_target_user;

        IF v_count >= 5 THEN
            RAISE EXCEPTION 'Límite de 5 grupos alcanzado: Un usuario normal no puede publicar más de 5 grupos en la comunidad. Si necesitas publicar más, comunícate con un administrador o moderador.';
        END IF;

        RETURN NEW;
    END;
    $$;


ALTER FUNCTION "public"."check_whatsapp_groups_limit"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_inappropriate_posts"() RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_deleted integer;
BEGIN
    IF NOT public.is_pemtree_admin(v_user_id) THEN
        RAISE EXCEPTION 'Permiso denegado: solo los administradores pueden ejecutar esta limpieza.';
    END IF;

    DELETE FROM public.posts
    WHERE moderation_status = 2;

    GET DIAGNOSTICS v_deleted = ROW_COUNT;

    RETURN 'Se eliminaron ' || v_deleted || ' publicaciones no apropiadas.';
END;
$$;


ALTER FUNCTION "public"."delete_inappropriate_posts"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_old_posts"("months_old" integer DEFAULT 3) RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_deleted integer;
BEGIN
    IF NOT public.is_pemtree_admin(v_user_id) THEN
        RAISE EXCEPTION 'Permiso denegado: solo los administradores pueden ejecutar esta limpieza.';
    END IF;

    DELETE FROM public.posts
    WHERE created_at < NOW() - (months_old || ' months')::interval;

    GET DIAGNOSTICS v_deleted = ROW_COUNT;

    RETURN 'Se eliminaron ' || v_deleted || ' publicaciones con más de ' || months_old || ' meses de antigüedad.';
END;
$$;


ALTER FUNCTION "public"."delete_old_posts"("months_old" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."eliminar_contenido_moderado"("p_tabla" "text", "p_item_id" "uuid", "p_justificacion" "text" DEFAULT NULL::"text") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_owner_id uuid;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'No estás autenticado en el sistema.';
    END IF;

    IF p_tabla = 'whatsapp_groups' THEN
        SELECT user_id INTO v_owner_id FROM public.whatsapp_groups WHERE id = p_item_id;
    ELSIF p_tabla = 'posts' THEN
        SELECT user_id INTO v_owner_id FROM public.posts WHERE id = p_item_id;
    ELSIF p_tabla = 'comments' THEN
        SELECT user_id INTO v_owner_id FROM public.comments WHERE id = p_item_id;
    ELSE
        RAISE EXCEPTION 'Tabla (%) no válida para moderación.', p_tabla;
    END IF;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El registro ya no existe o fue eliminado previamente en la base de datos.';
    END IF;

    IF NOT public.is_pemtree_admin(v_user_id) THEN
        RAISE EXCEPTION 'Permiso denegado: Solo el administrador de PEMTREE puede eliminar contenido de forma definitiva. Si eres moderador o el autor, usa la acción de ocultar.';
    END IF;

    INSERT INTO public.moderation_audit_log (moderator_id, entity_table, entity_id, justification, is_automated, moderation_label)
    VALUES (v_user_id, p_tabla, p_item_id,
            COALESCE(NULLIF(TRIM(p_justificacion), ''), 'Eliminación definitiva por administrador'),
            false, 'deleted');

    IF p_tabla = 'whatsapp_groups' THEN
        DELETE FROM public.whatsapp_groups WHERE id = p_item_id;
    ELSIF p_tabla = 'posts' THEN
        DELETE FROM public.posts WHERE id = p_item_id;
    ELSIF p_tabla = 'comments' THEN
        DELETE FROM public.comments WHERE id = p_item_id;
    END IF;

    RETURN true;
END;
$$;


ALTER FUNCTION "public"."eliminar_contenido_moderado"("p_tabla" "text", "p_item_id" "uuid", "p_justificacion" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_push_secrets"() RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
    v_secret      text;
    v_public      text;
    v_private     text;
    v_subject     text;
begin
    select decrypted_secret into v_secret  from vault.decrypted_secrets where name = 'push_edge_secret';
    select decrypted_secret into v_public  from vault.decrypted_secrets where name = 'vapid_public_key';
    select decrypted_secret into v_private from vault.decrypted_secrets where name = 'vapid_private_key';
    select decrypted_secret into v_subject from vault.decrypted_secrets where name = 'vapid_subject';

    if v_secret is null or v_public is null or v_private is null or v_subject is null then
        raise exception 'Faltan secretos de push en el vault';
    end if;

    return jsonb_build_object(
        'edge_secret',   v_secret,
        'vapid_public',  v_public,
        'vapid_private', v_private,
        'vapid_subject', v_subject
    );
end;
$$;


ALTER FUNCTION "public"."get_push_secrets"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_profiles"("p_user_ids" "uuid"[]) RETURNS TABLE("user_id" "uuid", "email" "text", "full_name" "text", "avatar_url" "text")
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
    if not public.is_pemtree_admin() then
        raise exception 'Acceso denegado';
    end if;

    return query
        select u.id,
               u.email::text,
               u.raw_user_meta_data->>'full_name' as full_name,
               u.raw_user_meta_data->>'avatar_url' as avatar_url
        from auth.users u
        where u.id = any(p_user_ids);
end;
$$;


ALTER FUNCTION "public"."get_user_profiles"("p_user_ids" "uuid"[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_pemtree_admin"("p_user_id" "uuid" DEFAULT "auth"."uid"()) RETURNS boolean
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
BEGIN
    IF p_user_id::text = '10884922-e583-409e-b3e8-8a875ddaa5d9' THEN
        RETURN true;
    END IF;
    IF EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = p_user_id AND role = 'admin') THEN
        RETURN true;
    END IF;
    RETURN false;
END;
$$;


ALTER FUNCTION "public"."is_pemtree_admin"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_pemtree_moderator"("p_user_id" "uuid" DEFAULT "auth"."uid"()) RETURNS boolean
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
BEGIN
    IF public.is_pemtree_admin(p_user_id) THEN
        RETURN true;
    END IF;
    IF EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = p_user_id AND role = 'moderator') THEN
        RETURN true;
    END IF;
    RETURN false;
END;
$$;


ALTER FUNCTION "public"."is_pemtree_moderator"("p_user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."limpieza_semestral_pemtree"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
    DECLARE
        v_hoy_md text := TO_CHAR(CURRENT_DATE, 'MM-DD');
        v_es_fecha_grupos boolean := v_hoy_md IN ('01-01', '05-15', '07-01', '11-15');
    BEGIN
        RAISE NOTICE 'Iniciando limpieza automática de PEMTREE (fecha clave grupos: %)...', v_hoy_md;

        DELETE FROM public.posts
        WHERE created_at < NOW() - INTERVAL '3 months';

        DELETE FROM public.user_reports
        WHERE created_at < NOW() - INTERVAL '3 months';

        DELETE FROM public.comments
        WHERE created_at < NOW() - INTERVAL '3 months';

        DELETE FROM public.user_notifications
        WHERE created_at < NOW() - INTERVAL '3 months';

        IF v_es_fecha_grupos THEN
            DELETE FROM public.whatsapp_groups;
            RAISE NOTICE 'Fecha clave (%): se eliminaron todos los grupos de WhatsApp.', v_hoy_md;
        ELSE
            RAISE NOTICE 'No es fecha clave de grupos (%), se mantienen los grupos de WhatsApp.', v_hoy_md;
        END IF;

        RAISE NOTICE 'Limpieza automática de PEMTREE completada exitosamente.';
    END;
    $$;


ALTER FUNCTION "public"."limpieza_semestral_pemtree"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."marcar_pendientes_error"("p_horas" integer DEFAULT 1) RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_limite timestamptz := now() - make_interval(hours => p_horas);
    v_total integer := 0;
    v_cont integer;
BEGIN
    WITH marcados AS (
        UPDATE public.posts
        SET moderation_status = 3,
            moderation_label = 'error',
            moderation_confidence = 0,
            moderation_reason = 'Servicio de moderación no disponible',
            moderated_at = now(),
            moderated_by = NULL
        WHERE moderation_status = 0 AND created_at < v_limite
        RETURNING id
    )
    INSERT INTO public.moderation_audit_log
        (moderator_id, entity_table, entity_id, justification, is_automated, moderation_label, confidence)
    SELECT NULL, 'posts', id, 'Servicio de moderación no disponible', true, 'error', 0
    FROM marcados;
    GET DIAGNOSTICS v_cont = ROW_COUNT;
    v_total := v_total + v_cont;

    WITH marcados AS (
        UPDATE public.comments
        SET moderation_status = 3,
            moderation_label = 'error',
            moderation_confidence = 0,
            moderation_reason = 'Servicio de moderación no disponible',
            moderated_at = now(),
            moderated_by = NULL
        WHERE moderation_status = 0 AND created_at < v_limite
        RETURNING id
    )
    INSERT INTO public.moderation_audit_log
        (moderator_id, entity_table, entity_id, justification, is_automated, moderation_label, confidence)
    SELECT NULL, 'comments', id, 'Servicio de moderación no disponible', true, 'error', 0
    FROM marcados;
    GET DIAGNOSTICS v_cont = ROW_COUNT;
    v_total := v_total + v_cont;

    WITH marcados AS (
        UPDATE public.whatsapp_groups
        SET moderation_status = 3,
            moderation_label = 'error',
            moderation_confidence = 0,
            moderation_reason = 'Servicio de moderación no disponible',
            moderated_at = now(),
            moderated_by = NULL
        WHERE moderation_status = 0 AND created_at < v_limite
        RETURNING id
    )
    INSERT INTO public.moderation_audit_log
        (moderator_id, entity_table, entity_id, justification, is_automated, moderation_label, confidence)
    SELECT NULL, 'whatsapp_groups', id, 'Servicio de moderación no disponible', true, 'error', 0
    FROM marcados;
    GET DIAGNOSTICS v_cont = ROW_COUNT;
    v_total := v_total + v_cont;

    WITH marcados AS (
        UPDATE public.user_reports
        SET moderation_status = 3,
            moderation_label = 'error',
            moderation_confidence = 0,
            moderation_reason = 'Servicio de moderación no disponible',
            moderated_at = now(),
            moderated_by = NULL
        WHERE moderation_status = 0 AND created_at < v_limite
        RETURNING id
    )
    INSERT INTO public.moderation_audit_log
        (moderator_id, entity_table, entity_id, justification, is_automated, moderation_label, confidence)
    SELECT NULL, 'user_reports', id, 'Servicio de moderación no disponible', true, 'error', 0
    FROM marcados;
    GET DIAGNOSTICS v_cont = ROW_COUNT;
    v_total := v_total + v_cont;

    WITH marcados AS (
        UPDATE public.whatsapp_group_reports
        SET moderation_status = 3,
            moderation_label = 'error',
            moderation_confidence = 0,
            moderation_reason = 'Servicio de moderación no disponible',
            moderated_at = now(),
            moderated_by = NULL
        WHERE moderation_status = 0 AND created_at < v_limite
        RETURNING group_id, user_id
    )
    INSERT INTO public.moderation_audit_log
        (moderator_id, entity_table, entity_id, justification, is_automated, moderation_label, confidence)
    SELECT NULL, 'whatsapp_group_reports', group_id, 'Servicio de moderación no disponible', true, 'error', 0
    FROM marcados;
    GET DIAGNOSTICS v_cont = ROW_COUNT;
    v_total := v_total + v_cont;

    RETURN v_total;
END;
$$;


ALTER FUNCTION "public"."marcar_pendientes_error"("p_horas" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."ocultar_contenido_moderado"("p_tabla" "text", "p_item_id" "uuid", "p_justificacion" "text" DEFAULT NULL::"text") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_owner_id uuid;
    v_is_admin boolean := public.is_pemtree_admin(v_user_id);
    v_is_mod boolean := public.is_pemtree_moderator(v_user_id);
    v_justificacion text;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'No estás autenticado en el sistema.';
    END IF;

    IF p_tabla = 'whatsapp_groups' THEN
        SELECT user_id INTO v_owner_id FROM public.whatsapp_groups WHERE id = p_item_id;
    ELSIF p_tabla = 'posts' THEN
        SELECT user_id INTO v_owner_id FROM public.posts WHERE id = p_item_id;
    ELSIF p_tabla = 'comments' THEN
        SELECT user_id INTO v_owner_id FROM public.comments WHERE id = p_item_id;
    ELSE
        RAISE EXCEPTION 'Tabla (%) no válida para moderación.', p_tabla;
    END IF;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El registro ya no existe o fue eliminado previamente en la base de datos.';
    END IF;

    IF v_owner_id <> v_user_id AND NOT v_is_admin AND NOT v_is_mod THEN
        RAISE EXCEPTION 'Permiso denegado: No tienes autorización para ocultar este contenido.';
    END IF;

    IF v_owner_id <> v_user_id AND NOT v_is_admin THEN
        IF p_justificacion IS NULL OR TRIM(p_justificacion) = '' THEN
            RAISE EXCEPTION 'Justificación obligatoria: Como moderador, debes ingresar la razón por la cual ocultas este contenido.';
        END IF;
        v_justificacion := TRIM(p_justificacion);
    ELSE
        v_justificacion := COALESCE(NULLIF(TRIM(p_justificacion), ''), 'Ocultado por el autor o administrador');
    END IF;

    INSERT INTO public.moderation_audit_log (moderator_id, entity_table, entity_id, justification, is_automated, moderation_label)
    VALUES (v_user_id, p_tabla, p_item_id, v_justificacion, false, 'inappropriate');

    IF p_tabla = 'whatsapp_groups' THEN
        UPDATE public.whatsapp_groups
        SET moderation_status = 2, moderation_label = 'inappropriate', moderation_reason = v_justificacion,
            moderated_by = v_user_id, moderated_at = now()
        WHERE id = p_item_id;
    ELSIF p_tabla = 'posts' THEN
        UPDATE public.posts
        SET moderation_status = 2, moderation_label = 'inappropriate', moderation_reason = v_justificacion,
            moderated_by = v_user_id, moderated_at = now()
        WHERE id = p_item_id;
    ELSIF p_tabla = 'comments' THEN
        UPDATE public.comments
        SET moderation_status = 2, moderation_label = 'inappropriate', moderation_reason = v_justificacion,
            moderated_by = v_user_id, moderated_at = now()
        WHERE id = p_item_id;
    END IF;

    RETURN true;
END;
$$;


ALTER FUNCTION "public"."ocultar_contenido_moderado"("p_tabla" "text", "p_item_id" "uuid", "p_justificacion" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."prevent_nonmoderator_restore"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
DECLARE
    v_uid uuid := auth.uid();
BEGIN
    IF v_uid IS NULL THEN
        RETURN NEW;
    END IF;

    IF public.is_pemtree_admin(v_uid) OR public.is_pemtree_moderator(v_uid) THEN
        RETURN NEW;
    END IF;

    IF NEW.moderation_status IS DISTINCT FROM OLD.moderation_status
       AND NEW.moderation_status IS DISTINCT FROM 2 THEN
        RAISE EXCEPTION 'Permiso denegado: Una vez ocultado, solo un administrador o moderador puede restaurar este contenido.';
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."prevent_nonmoderator_restore"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."purge_inappropriate_content"() RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_posts integer := 0;
    v_comments integer := 0;
    v_groups integer := 0;
    v_ureports integer := 0;
    v_greports integer := 0;
BEGIN
    IF NOT public.is_pemtree_admin(v_user_id) THEN
        RAISE EXCEPTION 'Permiso denegado: solo los administradores pueden ejecutar esta limpieza.';
    END IF;

    DELETE FROM public.posts WHERE moderation_status = 2;
    GET DIAGNOSTICS v_posts = ROW_COUNT;

    DELETE FROM public.comments WHERE moderation_status = 2;
    GET DIAGNOSTICS v_comments = ROW_COUNT;

    DELETE FROM public.whatsapp_groups WHERE moderation_status = 2;
    GET DIAGNOSTICS v_groups = ROW_COUNT;

    DELETE FROM public.user_reports WHERE moderation_status = 2;
    GET DIAGNOSTICS v_ureports = ROW_COUNT;

    DELETE FROM public.whatsapp_group_reports WHERE moderation_status = 2;
    GET DIAGNOSTICS v_greports = ROW_COUNT;

    INSERT INTO public.moderation_audit_log (moderator_id, entity_table, entity_id, justification, is_automated, moderation_label)
    VALUES (v_user_id, 'cleanup', '00000000-0000-0000-0000-000000000000',
            'Limpieza administrador: todo el contenido inapropiado/bloqueado', false, 'cleanup');

    RETURN 'Limpieza completada — posts=' || v_posts || ', comentarios=' || v_comments ||
           ', grupos=' || v_groups || ', reportes de usuario=' || v_ureports || ', reportes de grupo=' || v_greports;
END;
$$;


ALTER FUNCTION "public"."purge_inappropriate_content"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."purge_old_content"("p_months" integer DEFAULT 3) RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_deleted integer;
    v_cutoff timestamptz := now() - make_interval(months => p_months);
BEGIN
    IF NOT public.is_pemtree_admin(v_user_id) THEN
        RAISE EXCEPTION 'Permiso denegado: solo los administradores pueden ejecutar esta limpieza.';
    END IF;

    DELETE FROM public.posts WHERE created_at < v_cutoff;
    GET DIAGNOSTICS v_deleted = ROW_COUNT;

    INSERT INTO public.moderation_audit_log (moderator_id, entity_table, entity_id, justification, is_automated, moderation_label)
    VALUES (v_user_id, 'cleanup', '00000000-0000-0000-0000-000000000000',
            'Limpieza administrador: posts con más de ' || p_months || ' meses de antigüedad', false, 'cleanup');

    RETURN 'Se eliminaron ' || v_deleted || ' publicaciones (y sus respuestas/likes) con más de ' || p_months || ' meses de antigüedad.';
END;
$$;


ALTER FUNCTION "public"."purge_old_content"("p_months" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."purge_reported_groups"() RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_deleted integer;
BEGIN
    IF NOT public.is_pemtree_admin(v_user_id) THEN
        RAISE EXCEPTION 'Permiso denegado: solo los administradores pueden ejecutar esta limpieza.';
    END IF;

    DELETE FROM public.whatsapp_groups
    WHERE reported_count > 0
       OR id IN (SELECT group_id FROM public.whatsapp_group_reports);
    GET DIAGNOSTICS v_deleted = ROW_COUNT;

    INSERT INTO public.moderation_audit_log (moderator_id, entity_table, entity_id, justification, is_automated, moderation_label)
    VALUES (v_user_id, 'cleanup', '00000000-0000-0000-0000-000000000000',
            'Limpieza administrador: grupos reportados', false, 'cleanup');

    RETURN 'Se eliminaron ' || v_deleted || ' grupos reportados (y sus reportes/votos asociados).';
END;
$$;


ALTER FUNCTION "public"."purge_reported_groups"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."reset_moderation_on_edit"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'pg_catalog'
    AS $$
BEGIN
    IF TG_TABLE_NAME = 'posts' THEN
        IF NEW.title IS DISTINCT FROM OLD.title
           OR NEW.content IS DISTINCT FROM OLD.content
           OR NEW.category IS DISTINCT FROM OLD.category
        THEN
            NEW.moderation_status := 0;
            NEW.moderation_label := NULL;
            NEW.moderation_confidence := NULL;
            NEW.moderation_reason := NULL;
            NEW.moderated_at := NULL;
            NEW.moderated_by := NULL;
        END IF;
        RETURN NEW;
    END IF;

    IF TG_TABLE_NAME = 'comments' THEN
        IF NEW.content IS DISTINCT FROM OLD.content
        THEN
            NEW.moderation_status := 0;
            NEW.moderation_label := NULL;
            NEW.moderation_confidence := NULL;
            NEW.moderation_reason := NULL;
            NEW.moderated_at := NULL;
            NEW.moderated_by := NULL;
        END IF;
        RETURN NEW;
    END IF;

    IF TG_TABLE_NAME = 'whatsapp_groups' THEN
        IF NEW.title IS DISTINCT FROM OLD.title
           OR NEW.carrera IS DISTINCT FROM OLD.carrera
           OR NEW.curso IS DISTINCT FROM OLD.curso
           OR NEW.section IS DISTINCT FROM OLD.section
           OR NEW.link IS DISTINCT FROM OLD.link
           OR NEW.description IS DISTINCT FROM OLD.description
        THEN
            NEW.moderation_status := 0;
            NEW.moderation_label := NULL;
            NEW.moderation_confidence := NULL;
            NEW.moderation_reason := NULL;
            NEW.moderated_at := NULL;
            NEW.moderated_by := NULL;
        END IF;
        RETURN NEW;
    END IF;

    IF TG_TABLE_NAME = 'user_reports' THEN
        IF NEW.reason IS DISTINCT FROM OLD.reason
        THEN
            NEW.moderation_status := 0;
            NEW.moderation_label := NULL;
            NEW.moderation_confidence := NULL;
            NEW.moderation_reason := NULL;
            NEW.moderated_at := NULL;
            NEW.moderated_by := NULL;
        END IF;
        RETURN NEW;
    END IF;

    IF TG_TABLE_NAME = 'whatsapp_group_reports' THEN
        IF NEW.reason IS DISTINCT FROM OLD.reason
        THEN
            NEW.moderation_status := 0;
            NEW.moderation_label := NULL;
            NEW.moderation_confidence := NULL;
            NEW.moderation_reason := NULL;
            NEW.moderated_at := NULL;
            NEW.moderated_by := NULL;
        END IF;
        RETURN NEW;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."reset_moderation_on_edit"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."restaurar_contenido_moderado"("p_tabla" "text", "p_item_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_is_admin boolean := public.is_pemtree_admin(v_user_id);
    v_is_mod boolean := public.is_pemtree_moderator(v_user_id);
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'No estás autenticado en el sistema.';
    END IF;

    IF p_tabla = 'whatsapp_groups' THEN
        PERFORM 1 FROM public.whatsapp_groups WHERE id = p_item_id;
    ELSIF p_tabla = 'posts' THEN
        PERFORM 1 FROM public.posts WHERE id = p_item_id;
    ELSIF p_tabla = 'comments' THEN
        PERFORM 1 FROM public.comments WHERE id = p_item_id;
    ELSE
        RAISE EXCEPTION 'Tabla (%) no válida para moderación.', p_tabla;
    END IF;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El registro ya no existe o fue eliminado previamente en la base de datos.';
    END IF;

    IF NOT v_is_admin AND NOT v_is_mod THEN
        RAISE EXCEPTION 'Permiso denegado: Solo un administrador o moderador puede restaurar contenido oculto. El autor ya no puede restaurar sus publicaciones una vez ocultadas.';
    END IF;

    INSERT INTO public.moderation_audit_log (moderator_id, entity_table, entity_id, justification, is_automated, moderation_label)
    VALUES (v_user_id, p_tabla, p_item_id, 'Contenido restaurado/aprobado', false, 'appropriate');

    IF p_tabla = 'whatsapp_groups' THEN
        UPDATE public.whatsapp_groups
        SET moderation_status = 1, moderation_label = 'appropriate', moderation_reason = NULL,
            moderated_by = NULL, moderated_at = NULL
        WHERE id = p_item_id;
    ELSIF p_tabla = 'posts' THEN
        UPDATE public.posts
        SET moderation_status = 1, moderation_label = 'appropriate', moderation_reason = NULL,
            moderated_by = NULL, moderated_at = NULL
        WHERE id = p_item_id;
    ELSIF p_tabla = 'comments' THEN
        UPDATE public.comments
        SET moderation_status = 1, moderation_label = 'appropriate', moderation_reason = NULL,
            moderated_by = NULL, moderated_at = NULL
        WHERE id = p_item_id;
    END IF;

    RETURN true;
END;
$$;


ALTER FUNCTION "public"."restaurar_contenido_moderado"("p_tabla" "text", "p_item_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."v_moderation_queue"() RETURNS TABLE("entity_table" "text", "entity_id" "uuid", "entity_key" "uuid", "content" "text", "created_at" timestamp with time zone)
    LANGUAGE "sql" STABLE
    SET "search_path" TO ''
    AS $$
    SELECT 'posts'::text, id, NULL::uuid,
           COALESCE(title, '') || ' ' || COALESCE(content, ''),
           created_at
    FROM public.posts
    WHERE moderation_status = 0
    UNION ALL
    SELECT 'comments', id, NULL::uuid,
           COALESCE(content, ''),
           created_at
    FROM public.comments
    WHERE moderation_status = 0
    UNION ALL
    SELECT 'whatsapp_groups', id, NULL::uuid,
           COALESCE(title, '') || ' ' || COALESCE(description, '') || ' ' || COALESCE(link, ''),
           created_at
    FROM public.whatsapp_groups
    WHERE moderation_status = 0
    UNION ALL
    SELECT 'user_reports', id, NULL::uuid,
           COALESCE(reason, '') || ' ' || COALESCE(reported_user_alias, ''),
           created_at
    FROM public.user_reports
    WHERE moderation_status = 0
    UNION ALL
    SELECT 'whatsapp_group_reports', group_id, user_id,
           COALESCE(reason, ''),
           created_at
    FROM public.whatsapp_group_reports
    WHERE moderation_status = 0
    ORDER BY created_at;
$$;


ALTER FUNCTION "public"."v_moderation_queue"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."comments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "post_id" "uuid",
    "author_alias" "text" NOT NULL,
    "content" "text" NOT NULL,
    "user_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "parent_id" "uuid",
    "moderation_status" integer DEFAULT 0,
    "moderation_label" "text",
    "moderation_confidence" double precision,
    "moderation_reason" "text",
    "moderated_at" timestamp with time zone,
    "moderated_by" "uuid"
);


ALTER TABLE "public"."comments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."moderation_audit_log" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "moderator_id" "uuid",
    "entity_table" "text" NOT NULL,
    "entity_id" "uuid" NOT NULL,
    "justification" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "is_automated" boolean DEFAULT false,
    "moderation_label" "text",
    "confidence" double precision
);


ALTER TABLE "public"."moderation_audit_log" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."notification_preferences" (
    "user_id" "uuid" NOT NULL,
    "comment_enabled" boolean DEFAULT true NOT NULL,
    "reply_enabled" boolean DEFAULT true NOT NULL,
    "like_enabled" boolean DEFAULT true NOT NULL,
    "new_post_enabled" boolean DEFAULT false NOT NULL,
    "carreras" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."notification_preferences" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."notification_subscriptions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "endpoint" "text" NOT NULL,
    "p256dh" "text" NOT NULL,
    "auth" "text" NOT NULL,
    "user_agent" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."notification_subscriptions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."post_likes" (
    "post_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."post_likes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."posts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "title" "text" NOT NULL,
    "category" "text" NOT NULL,
    "content" "text" NOT NULL,
    "author_alias" "text" NOT NULL,
    "likes" integer DEFAULT 0,
    "user_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "carrera" "text" DEFAULT 'sistemas'::"text",
    "image_url" "text",
    "moderation_status" integer DEFAULT 0,
    "moderation_label" "text",
    "moderation_confidence" double precision,
    "moderation_reason" "text",
    "moderated_at" timestamp with time zone,
    "moderated_by" "uuid"
);


ALTER TABLE "public"."posts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."seccion_reviews" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "curso_codigo" "text" NOT NULL,
    "seccion" "text" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "recomienda" boolean NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."seccion_reviews" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."seccion_reputation" WITH ("security_invoker"='true') AS
 SELECT "curso_codigo",
    "seccion",
    "count"("id") AS "total",
    "count"("id") FILTER (WHERE "recomienda") AS "recomendados",
        CASE
            WHEN ("count"("id") = 0) THEN NULL::numeric
            ELSE "round"(((("count"("id") FILTER (WHERE "recomienda"))::numeric / ("count"("id"))::numeric) * (100)::numeric))
        END AS "pct_recomienda"
   FROM "public"."seccion_reviews"
  GROUP BY "curso_codigo", "seccion";


ALTER VIEW "public"."seccion_reputation" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_notifications" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "type" "text" NOT NULL,
    "title" "text" NOT NULL,
    "body" "text" NOT NULL,
    "actor_alias" "text",
    "post_id" "uuid",
    "comment_id" "uuid",
    "read_at" timestamp with time zone,
    "push_sent_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "user_notifications_type_check" CHECK (("type" = ANY (ARRAY['comment'::"text", 'reply'::"text", 'like'::"text", 'new_post'::"text"])))
);


ALTER TABLE "public"."user_notifications" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_reports" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "reporter_id" "uuid" NOT NULL,
    "reported_user_id" "uuid" NOT NULL,
    "reported_user_alias" "text",
    "reason" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "moderation_status" integer DEFAULT 0,
    "moderation_label" "text",
    "moderation_confidence" double precision,
    "moderation_reason" "text",
    "moderated_at" timestamp with time zone,
    "moderated_by" "uuid"
);


ALTER TABLE "public"."user_reports" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_roles" (
    "user_id" "uuid" NOT NULL,
    "role" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "user_roles_role_check" CHECK (("role" = ANY (ARRAY['admin'::"text", 'moderator'::"text"])))
);


ALTER TABLE "public"."user_roles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."whatsapp_group_reports" (
    "group_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "reason" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "moderation_status" integer DEFAULT 0,
    "moderation_label" "text",
    "moderation_confidence" double precision,
    "moderation_reason" "text",
    "moderated_at" timestamp with time zone,
    "moderated_by" "uuid"
);


ALTER TABLE "public"."whatsapp_group_reports" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."whatsapp_group_upvotes" (
    "group_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."whatsapp_group_upvotes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."whatsapp_groups" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "title" "text" NOT NULL,
    "carrera" "text" DEFAULT 'todas'::"text" NOT NULL,
    "curso" "text" NOT NULL,
    "section" "text",
    "link" "text" NOT NULL,
    "description" "text",
    "user_id" "uuid",
    "author_alias" "text" DEFAULT 'Estudiante Anónimo'::"text" NOT NULL,
    "upvotes" integer DEFAULT 0,
    "reported_count" integer DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "image_url" "text",
    "moderation_status" integer DEFAULT 0,
    "moderation_label" "text",
    "moderation_confidence" double precision,
    "moderation_reason" "text",
    "moderated_at" timestamp with time zone,
    "moderated_by" "uuid"
);


ALTER TABLE "public"."whatsapp_groups" OWNER TO "postgres";


ALTER TABLE ONLY "public"."comments"
    ADD CONSTRAINT "comments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."moderation_audit_log"
    ADD CONSTRAINT "moderation_audit_log_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."notification_preferences"
    ADD CONSTRAINT "notification_preferences_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."notification_subscriptions"
    ADD CONSTRAINT "notification_subscriptions_endpoint_key" UNIQUE ("endpoint");



ALTER TABLE ONLY "public"."notification_subscriptions"
    ADD CONSTRAINT "notification_subscriptions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."post_likes"
    ADD CONSTRAINT "post_likes_pkey" PRIMARY KEY ("post_id", "user_id");



ALTER TABLE ONLY "public"."posts"
    ADD CONSTRAINT "posts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."seccion_reviews"
    ADD CONSTRAINT "seccion_reviews_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."seccion_reviews"
    ADD CONSTRAINT "seccion_reviews_unique" UNIQUE ("curso_codigo", "seccion", "user_id");



ALTER TABLE ONLY "public"."user_reports"
    ADD CONSTRAINT "unique_user_report" UNIQUE ("reporter_id", "reported_user_id");



ALTER TABLE ONLY "public"."user_notifications"
    ADD CONSTRAINT "user_notifications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_reports"
    ADD CONSTRAINT "user_reports_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_roles"
    ADD CONSTRAINT "user_roles_pkey" PRIMARY KEY ("user_id");



ALTER TABLE ONLY "public"."whatsapp_group_reports"
    ADD CONSTRAINT "whatsapp_group_reports_pkey" PRIMARY KEY ("group_id", "user_id");



ALTER TABLE ONLY "public"."whatsapp_group_upvotes"
    ADD CONSTRAINT "whatsapp_group_upvotes_pkey" PRIMARY KEY ("group_id", "user_id");



ALTER TABLE ONLY "public"."whatsapp_groups"
    ADD CONSTRAINT "whatsapp_groups_pkey" PRIMARY KEY ("id");



CREATE INDEX "idx_comments_created_at" ON "public"."comments" USING "btree" ("created_at");



CREATE INDEX "idx_comments_moderated_by" ON "public"."comments" USING "btree" ("moderated_by");



CREATE INDEX "idx_comments_moderation_status" ON "public"."comments" USING "btree" ("moderation_status");



CREATE INDEX "idx_comments_parent_id" ON "public"."comments" USING "btree" ("parent_id");



CREATE INDEX "idx_comments_post_id" ON "public"."comments" USING "btree" ("post_id");



CREATE INDEX "idx_comments_user_id" ON "public"."comments" USING "btree" ("user_id");



CREATE INDEX "idx_moderation_audit_log_moderator_id" ON "public"."moderation_audit_log" USING "btree" ("moderator_id");



CREATE INDEX "idx_notifications_pending_push" ON "public"."user_notifications" USING "btree" ("created_at") WHERE ("push_sent_at" IS NULL);



CREATE INDEX "idx_notifications_user_created" ON "public"."user_notifications" USING "btree" ("user_id", "created_at" DESC);



CREATE INDEX "idx_post_likes_user_id" ON "public"."post_likes" USING "btree" ("user_id");



CREATE INDEX "idx_posts_created_at" ON "public"."posts" USING "btree" ("created_at");



CREATE INDEX "idx_posts_moderated_by" ON "public"."posts" USING "btree" ("moderated_by");



CREATE INDEX "idx_posts_moderation_status" ON "public"."posts" USING "btree" ("moderation_status");



CREATE INDEX "idx_posts_user_id" ON "public"."posts" USING "btree" ("user_id");



CREATE INDEX "idx_seccion_reviews_curso_seccion" ON "public"."seccion_reviews" USING "btree" ("curso_codigo", "seccion");



CREATE INDEX "idx_seccion_reviews_user" ON "public"."seccion_reviews" USING "btree" ("user_id");



CREATE INDEX "idx_subscriptions_user" ON "public"."notification_subscriptions" USING "btree" ("user_id");



CREATE INDEX "idx_user_notifications_comment_id" ON "public"."user_notifications" USING "btree" ("comment_id");



CREATE INDEX "idx_user_notifications_post_id" ON "public"."user_notifications" USING "btree" ("post_id");



CREATE INDEX "idx_user_notifications_user_id" ON "public"."user_notifications" USING "btree" ("user_id");



CREATE INDEX "idx_user_reports_created_at" ON "public"."user_reports" USING "btree" ("created_at");



CREATE INDEX "idx_user_reports_moderated_by" ON "public"."user_reports" USING "btree" ("moderated_by");



CREATE INDEX "idx_user_reports_moderation_status" ON "public"."user_reports" USING "btree" ("moderation_status");



CREATE INDEX "idx_whatsapp_group_reports_created_at" ON "public"."whatsapp_group_reports" USING "btree" ("created_at");



CREATE INDEX "idx_whatsapp_group_reports_moderated_by" ON "public"."whatsapp_group_reports" USING "btree" ("moderated_by");



CREATE INDEX "idx_whatsapp_group_reports_moderation_status" ON "public"."whatsapp_group_reports" USING "btree" ("moderation_status");



CREATE INDEX "idx_whatsapp_group_upvotes_user_id" ON "public"."whatsapp_group_upvotes" USING "btree" ("user_id");



CREATE INDEX "idx_whatsapp_groups_carrera" ON "public"."whatsapp_groups" USING "btree" ("carrera");



CREATE INDEX "idx_whatsapp_groups_created_at" ON "public"."whatsapp_groups" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_whatsapp_groups_curso" ON "public"."whatsapp_groups" USING "btree" ("curso");



CREATE INDEX "idx_whatsapp_groups_moderated_by" ON "public"."whatsapp_groups" USING "btree" ("moderated_by");



CREATE INDEX "idx_whatsapp_groups_moderation_status" ON "public"."whatsapp_groups" USING "btree" ("moderation_status");



CREATE OR REPLACE TRIGGER "trg_check_whatsapp_groups_limit" BEFORE INSERT ON "public"."whatsapp_groups" FOR EACH ROW EXECUTE FUNCTION "public"."check_whatsapp_groups_limit"();



CREATE OR REPLACE TRIGGER "trg_moderate_comments" BEFORE INSERT OR UPDATE ON "public"."comments" FOR EACH ROW EXECUTE FUNCTION "public"."check_content_moderation"();



CREATE OR REPLACE TRIGGER "trg_moderate_posts" BEFORE INSERT OR UPDATE ON "public"."posts" FOR EACH ROW EXECUTE FUNCTION "public"."check_content_moderation"();



CREATE OR REPLACE TRIGGER "trg_moderate_user_reports" BEFORE INSERT OR UPDATE ON "public"."user_reports" FOR EACH ROW EXECUTE FUNCTION "public"."check_content_moderation"();



CREATE OR REPLACE TRIGGER "trg_moderate_whatsapp_group_reports" BEFORE INSERT OR UPDATE ON "public"."whatsapp_group_reports" FOR EACH ROW EXECUTE FUNCTION "public"."check_content_moderation"();



CREATE OR REPLACE TRIGGER "trg_moderate_whatsapp_groups" BEFORE INSERT OR UPDATE ON "public"."whatsapp_groups" FOR EACH ROW EXECUTE FUNCTION "public"."check_content_moderation"();



CREATE OR REPLACE TRIGGER "trg_notify_comment_inserted" AFTER INSERT ON "public"."comments" FOR EACH ROW EXECUTE FUNCTION "_triggers"."notify_comment_inserted"();



CREATE OR REPLACE TRIGGER "trg_notify_new_post" AFTER INSERT ON "public"."posts" FOR EACH ROW EXECUTE FUNCTION "_triggers"."notify_new_post"();



CREATE OR REPLACE TRIGGER "trg_notify_post_liked" AFTER INSERT ON "public"."post_likes" FOR EACH ROW EXECUTE FUNCTION "_triggers"."notify_post_liked"();



CREATE OR REPLACE TRIGGER "trg_prevent_nonmoderator_restore_comments" BEFORE UPDATE ON "public"."comments" FOR EACH ROW EXECUTE FUNCTION "public"."prevent_nonmoderator_restore"();



CREATE OR REPLACE TRIGGER "trg_prevent_nonmoderator_restore_groups" BEFORE UPDATE ON "public"."whatsapp_groups" FOR EACH ROW EXECUTE FUNCTION "public"."prevent_nonmoderator_restore"();



CREATE OR REPLACE TRIGGER "trg_prevent_nonmoderator_restore_posts" BEFORE UPDATE ON "public"."posts" FOR EACH ROW EXECUTE FUNCTION "public"."prevent_nonmoderator_restore"();



CREATE OR REPLACE TRIGGER "trg_reset_moderation_comments" BEFORE UPDATE ON "public"."comments" FOR EACH ROW EXECUTE FUNCTION "public"."reset_moderation_on_edit"();



CREATE OR REPLACE TRIGGER "trg_reset_moderation_posts" BEFORE UPDATE ON "public"."posts" FOR EACH ROW EXECUTE FUNCTION "public"."reset_moderation_on_edit"();



CREATE OR REPLACE TRIGGER "trg_reset_moderation_user_reports" BEFORE UPDATE ON "public"."user_reports" FOR EACH ROW EXECUTE FUNCTION "public"."reset_moderation_on_edit"();



CREATE OR REPLACE TRIGGER "trg_reset_moderation_whatsapp_group_reports" BEFORE UPDATE ON "public"."whatsapp_group_reports" FOR EACH ROW EXECUTE FUNCTION "public"."reset_moderation_on_edit"();



CREATE OR REPLACE TRIGGER "trg_reset_moderation_whatsapp_groups" BEFORE UPDATE ON "public"."whatsapp_groups" FOR EACH ROW EXECUTE FUNCTION "public"."reset_moderation_on_edit"();



CREATE OR REPLACE TRIGGER "trg_sync_group_reported" AFTER INSERT OR DELETE ON "public"."whatsapp_group_reports" FOR EACH ROW EXECUTE FUNCTION "_triggers"."sync_group_reported_counter"();



CREATE OR REPLACE TRIGGER "trg_sync_group_upvotes" AFTER INSERT OR DELETE ON "public"."whatsapp_group_upvotes" FOR EACH ROW EXECUTE FUNCTION "_triggers"."sync_group_upvotes_counter"();



CREATE OR REPLACE TRIGGER "trg_sync_post_likes" AFTER INSERT OR DELETE ON "public"."post_likes" FOR EACH ROW EXECUTE FUNCTION "_triggers"."sync_post_likes_counter"();



ALTER TABLE ONLY "public"."comments"
    ADD CONSTRAINT "comments_moderated_by_fkey" FOREIGN KEY ("moderated_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."comments"
    ADD CONSTRAINT "comments_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "public"."posts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."comments"
    ADD CONSTRAINT "comments_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."comments"
    ADD CONSTRAINT "fk_comments_parent_cascade" FOREIGN KEY ("parent_id") REFERENCES "public"."comments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."moderation_audit_log"
    ADD CONSTRAINT "moderation_audit_log_moderator_id_fkey" FOREIGN KEY ("moderator_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."notification_preferences"
    ADD CONSTRAINT "notification_preferences_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notification_subscriptions"
    ADD CONSTRAINT "notification_subscriptions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."post_likes"
    ADD CONSTRAINT "post_likes_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "public"."posts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."post_likes"
    ADD CONSTRAINT "post_likes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."posts"
    ADD CONSTRAINT "posts_moderated_by_fkey" FOREIGN KEY ("moderated_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."posts"
    ADD CONSTRAINT "posts_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."seccion_reviews"
    ADD CONSTRAINT "seccion_reviews_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_notifications"
    ADD CONSTRAINT "user_notifications_comment_id_fkey" FOREIGN KEY ("comment_id") REFERENCES "public"."comments"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."user_notifications"
    ADD CONSTRAINT "user_notifications_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "public"."posts"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."user_notifications"
    ADD CONSTRAINT "user_notifications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_reports"
    ADD CONSTRAINT "user_reports_moderated_by_fkey" FOREIGN KEY ("moderated_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."user_reports"
    ADD CONSTRAINT "user_reports_reporter_id_fkey" FOREIGN KEY ("reporter_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_roles"
    ADD CONSTRAINT "user_roles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."whatsapp_group_reports"
    ADD CONSTRAINT "whatsapp_group_reports_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "public"."whatsapp_groups"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."whatsapp_group_reports"
    ADD CONSTRAINT "whatsapp_group_reports_moderated_by_fkey" FOREIGN KEY ("moderated_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."whatsapp_group_upvotes"
    ADD CONSTRAINT "whatsapp_group_upvotes_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "public"."whatsapp_groups"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."whatsapp_group_upvotes"
    ADD CONSTRAINT "whatsapp_group_upvotes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."whatsapp_groups"
    ADD CONSTRAINT "whatsapp_groups_moderated_by_fkey" FOREIGN KEY ("moderated_by") REFERENCES "auth"."users"("id");



CREATE POLICY "Actualizar mis notificaciones (leídas)" ON "public"."user_notifications" FOR UPDATE USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Actualizar mis preferencias de notificación" ON "public"."notification_preferences" FOR UPDATE USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Actualizar mis suscripciones de notificación" ON "public"."notification_subscriptions" FOR UPDATE USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Actualizar propias publicaciones" ON "public"."posts" FOR UPDATE TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Actualizar propios comentarios" ON "public"."comments" FOR UPDATE TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Actualizar reportes de grupos admin o moderador" ON "public"."whatsapp_group_reports" FOR UPDATE TO "authenticated" USING (("public"."is_pemtree_admin"(( SELECT "auth"."uid"() AS "uid")) OR "public"."is_pemtree_moderator"(( SELECT "auth"."uid"() AS "uid"))));



CREATE POLICY "Actualizar reportes de usuarios dueño, admin o moderador" ON "public"."user_reports" FOR UPDATE TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") = "reporter_id") OR (("auth"."uid"() IS NOT NULL) AND "public"."is_pemtree_admin"(( SELECT "auth"."uid"() AS "uid"))) OR (("auth"."uid"() IS NOT NULL) AND "public"."is_pemtree_moderator"(( SELECT "auth"."uid"() AS "uid")))));



CREATE POLICY "Borrar grupos dueño, admin o moderador" ON "public"."whatsapp_groups" FOR DELETE TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") = "user_id") OR (("auth"."uid"() IS NOT NULL) AND "public"."is_pemtree_admin"(( SELECT "auth"."uid"() AS "uid"))) OR (("auth"."uid"() IS NOT NULL) AND "public"."is_pemtree_moderator"(( SELECT "auth"."uid"() AS "uid")))));



CREATE POLICY "Borrar mis notificaciones" ON "public"."user_notifications" FOR DELETE USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Borrar mis suscripciones de notificación" ON "public"."notification_subscriptions" FOR DELETE USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Borrar reportes de grupos dueño, admin o moderador" ON "public"."whatsapp_group_reports" FOR DELETE TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") = "user_id") OR (("auth"."uid"() IS NOT NULL) AND "public"."is_pemtree_admin"(( SELECT "auth"."uid"() AS "uid"))) OR (("auth"."uid"() IS NOT NULL) AND "public"."is_pemtree_moderator"(( SELECT "auth"."uid"() AS "uid")))));



CREATE POLICY "Borrar reportes de usuarios dueño, admin o moderador" ON "public"."user_reports" FOR DELETE TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") = "reporter_id") OR (("auth"."uid"() IS NOT NULL) AND "public"."is_pemtree_admin"(( SELECT "auth"."uid"() AS "uid"))) OR (("auth"."uid"() IS NOT NULL) AND "public"."is_pemtree_moderator"(( SELECT "auth"."uid"() AS "uid")))));



CREATE POLICY "Crear grupos solo autenticados" ON "public"."whatsapp_groups" FOR INSERT TO "authenticated" WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Crear mis preferencias de notificación" ON "public"."notification_preferences" FOR INSERT WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Crear mis suscripciones de notificación" ON "public"."notification_subscriptions" FOR INSERT WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Editar grupos dueño, admin o moderador" ON "public"."whatsapp_groups" FOR UPDATE TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") = "user_id") OR (("auth"."uid"() IS NOT NULL) AND "public"."is_pemtree_admin"(( SELECT "auth"."uid"() AS "uid"))) OR (("auth"."uid"() IS NOT NULL) AND "public"."is_pemtree_moderator"(( SELECT "auth"."uid"() AS "uid")))));



CREATE POLICY "El autor o admin pueden borrar la reseña de sección" ON "public"."seccion_reviews" FOR DELETE TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") = "user_id") OR "public"."is_pemtree_admin"(( SELECT "auth"."uid"() AS "uid"))));



CREATE POLICY "El autor puede actualizar su reseña de sección" ON "public"."seccion_reviews" FOR UPDATE TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id")) WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Eliminar propias publicaciones o admin" ON "public"."posts" FOR DELETE TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") = "user_id") OR "public"."is_pemtree_admin"(( SELECT "auth"."uid"() AS "uid"))));



CREATE POLICY "Eliminar propios comentarios o admin" ON "public"."comments" FOR DELETE TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") = "user_id") OR "public"."is_pemtree_admin"(( SELECT "auth"."uid"() AS "uid"))));



CREATE POLICY "Lectura pública de comentarios (anon)" ON "public"."comments" FOR SELECT TO "anon" USING (("moderation_status" IS DISTINCT FROM 2));



CREATE POLICY "Lectura pública de comentarios (auth)" ON "public"."comments" FOR SELECT TO "authenticated" USING ((("moderation_status" IS DISTINCT FROM 2) OR "public"."is_pemtree_moderator"(( SELECT "auth"."uid"() AS "uid"))));



CREATE POLICY "Lectura pública de grupos (anon)" ON "public"."whatsapp_groups" FOR SELECT TO "anon" USING (("moderation_status" IS DISTINCT FROM 2));



CREATE POLICY "Lectura pública de grupos (auth)" ON "public"."whatsapp_groups" FOR SELECT TO "authenticated" USING ((("moderation_status" IS DISTINCT FROM 2) OR "public"."is_pemtree_moderator"(( SELECT "auth"."uid"() AS "uid"))));



CREATE POLICY "Lectura pública de reseñas de secciones" ON "public"."seccion_reviews" FOR SELECT USING (true);



CREATE POLICY "Lectura pública de votos de grupos" ON "public"."whatsapp_group_upvotes" FOR SELECT USING (true);



CREATE POLICY "Lectura pública del foro (anon)" ON "public"."posts" FOR SELECT TO "anon" USING (("moderation_status" IS DISTINCT FROM 2));



CREATE POLICY "Lectura pública del foro (auth)" ON "public"."posts" FOR SELECT TO "authenticated" USING ((("moderation_status" IS DISTINCT FROM 2) OR "public"."is_pemtree_moderator"("auth"."uid"())));



CREATE POLICY "Leer rol propio" ON "public"."user_roles" FOR SELECT TO "authenticated" USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Permitir crear comentarios a usuarios autenticados" ON "public"."comments" FOR INSERT TO "authenticated" WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Permitir crear publicaciones a usuarios autenticados" ON "public"."posts" FOR INSERT TO "authenticated" WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Permitir crear reportes a usuarios autenticados" ON "public"."user_reports" FOR INSERT TO "authenticated" WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "reporter_id"));



CREATE POLICY "Permitir dar like a usuarios autenticados" ON "public"."post_likes" FOR INSERT TO "authenticated" WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Permitir lectura de likes a todos" ON "public"."post_likes" FOR SELECT USING (true);



CREATE POLICY "Permitir quitar el propio like" ON "public"."post_likes" FOR DELETE USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Permitir ver reportes propios o a admin/moderador" ON "public"."user_reports" FOR SELECT TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") = "reporter_id") OR (("auth"."uid"() IS NOT NULL) AND "public"."is_pemtree_admin"(( SELECT "auth"."uid"() AS "uid"))) OR (("auth"."uid"() IS NOT NULL) AND "public"."is_pemtree_moderator"(( SELECT "auth"."uid"() AS "uid")))));



CREATE POLICY "Reportar grupos solo autenticados" ON "public"."whatsapp_group_reports" FOR INSERT TO "authenticated" WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Retirar voto solo por el usuario que lo emitió" ON "public"."whatsapp_group_upvotes" FOR DELETE USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Solo admins pueden ver auditoría" ON "public"."moderation_audit_log" FOR SELECT TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") IS NOT NULL) AND "public"."is_pemtree_admin"(( SELECT "auth"."uid"() AS "uid"))));



CREATE POLICY "Usuarios autenticados pueden reseñar secciones" ON "public"."seccion_reviews" FOR INSERT TO "authenticated" WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Ver mis notificaciones" ON "public"."user_notifications" FOR SELECT USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Ver mis preferencias de notificación" ON "public"."notification_preferences" FOR SELECT USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Ver mis suscripciones de notificación" ON "public"."notification_subscriptions" FOR SELECT USING ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



CREATE POLICY "Ver reportes propios o admin/moderador" ON "public"."whatsapp_group_reports" FOR SELECT TO "authenticated" USING (((( SELECT "auth"."uid"() AS "uid") = "user_id") OR (("auth"."uid"() IS NOT NULL) AND "public"."is_pemtree_admin"(( SELECT "auth"."uid"() AS "uid"))) OR (("auth"."uid"() IS NOT NULL) AND "public"."is_pemtree_moderator"(( SELECT "auth"."uid"() AS "uid")))));



CREATE POLICY "Votar en grupos solo usuarios autenticados" ON "public"."whatsapp_group_upvotes" FOR INSERT WITH CHECK ((( SELECT "auth"."uid"() AS "uid") = "user_id"));



ALTER TABLE "public"."comments" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."moderation_audit_log" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."notification_preferences" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."notification_subscriptions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."post_likes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."posts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."seccion_reviews" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_notifications" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_reports" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_roles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."whatsapp_group_reports" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."whatsapp_group_upvotes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."whatsapp_groups" ENABLE ROW LEVEL SECURITY;


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";



REVOKE ALL ON FUNCTION "public"."apply_moderation_batch"("p_items" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."apply_moderation_batch"("p_items" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."check_content_moderation"() TO "anon";
GRANT ALL ON FUNCTION "public"."check_content_moderation"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_content_moderation"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."check_whatsapp_groups_limit"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."check_whatsapp_groups_limit"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."delete_inappropriate_posts"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."delete_inappropriate_posts"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."delete_old_posts"("months_old" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."delete_old_posts"("months_old" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."eliminar_contenido_moderado"("p_tabla" "text", "p_item_id" "uuid", "p_justificacion" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."eliminar_contenido_moderado"("p_tabla" "text", "p_item_id" "uuid", "p_justificacion" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."eliminar_contenido_moderado"("p_tabla" "text", "p_item_id" "uuid", "p_justificacion" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."get_push_secrets"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_push_secrets"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."get_user_profiles"("p_user_ids" "uuid"[]) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_user_profiles"("p_user_ids" "uuid"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_profiles"("p_user_ids" "uuid"[]) TO "service_role";



REVOKE ALL ON FUNCTION "public"."is_pemtree_admin"("p_user_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."is_pemtree_admin"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_pemtree_admin"("p_user_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."is_pemtree_moderator"("p_user_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."is_pemtree_moderator"("p_user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_pemtree_moderator"("p_user_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."limpieza_semestral_pemtree"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."limpieza_semestral_pemtree"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."marcar_pendientes_error"("p_horas" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."marcar_pendientes_error"("p_horas" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."ocultar_contenido_moderado"("p_tabla" "text", "p_item_id" "uuid", "p_justificacion" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."ocultar_contenido_moderado"("p_tabla" "text", "p_item_id" "uuid", "p_justificacion" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."ocultar_contenido_moderado"("p_tabla" "text", "p_item_id" "uuid", "p_justificacion" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."prevent_nonmoderator_restore"() TO "anon";
GRANT ALL ON FUNCTION "public"."prevent_nonmoderator_restore"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."prevent_nonmoderator_restore"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."purge_inappropriate_content"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."purge_inappropriate_content"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."purge_old_content"("p_months" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."purge_old_content"("p_months" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."purge_reported_groups"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."purge_reported_groups"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."reset_moderation_on_edit"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."reset_moderation_on_edit"() TO "anon";
GRANT ALL ON FUNCTION "public"."reset_moderation_on_edit"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."reset_moderation_on_edit"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."restaurar_contenido_moderado"("p_tabla" "text", "p_item_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."restaurar_contenido_moderado"("p_tabla" "text", "p_item_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."restaurar_contenido_moderado"("p_tabla" "text", "p_item_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."v_moderation_queue"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."v_moderation_queue"() TO "service_role";



GRANT ALL ON TABLE "public"."comments" TO "anon";
GRANT ALL ON TABLE "public"."comments" TO "authenticated";
GRANT ALL ON TABLE "public"."comments" TO "service_role";



GRANT ALL ON TABLE "public"."moderation_audit_log" TO "anon";
GRANT ALL ON TABLE "public"."moderation_audit_log" TO "authenticated";
GRANT ALL ON TABLE "public"."moderation_audit_log" TO "service_role";



GRANT ALL ON TABLE "public"."notification_preferences" TO "anon";
GRANT ALL ON TABLE "public"."notification_preferences" TO "authenticated";
GRANT ALL ON TABLE "public"."notification_preferences" TO "service_role";



GRANT ALL ON TABLE "public"."notification_subscriptions" TO "anon";
GRANT ALL ON TABLE "public"."notification_subscriptions" TO "authenticated";
GRANT ALL ON TABLE "public"."notification_subscriptions" TO "service_role";



GRANT ALL ON TABLE "public"."post_likes" TO "anon";
GRANT ALL ON TABLE "public"."post_likes" TO "authenticated";
GRANT ALL ON TABLE "public"."post_likes" TO "service_role";



GRANT ALL ON TABLE "public"."posts" TO "anon";
GRANT ALL ON TABLE "public"."posts" TO "authenticated";
GRANT ALL ON TABLE "public"."posts" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."seccion_reviews" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."seccion_reviews" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."seccion_reviews" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."seccion_reputation" TO "anon";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."seccion_reputation" TO "authenticated";
GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."seccion_reputation" TO "service_role";



GRANT ALL ON TABLE "public"."user_notifications" TO "anon";
GRANT ALL ON TABLE "public"."user_notifications" TO "authenticated";
GRANT ALL ON TABLE "public"."user_notifications" TO "service_role";



GRANT ALL ON TABLE "public"."user_reports" TO "anon";
GRANT ALL ON TABLE "public"."user_reports" TO "authenticated";
GRANT ALL ON TABLE "public"."user_reports" TO "service_role";



GRANT ALL ON TABLE "public"."user_roles" TO "anon";
GRANT ALL ON TABLE "public"."user_roles" TO "authenticated";
GRANT ALL ON TABLE "public"."user_roles" TO "service_role";



GRANT ALL ON TABLE "public"."whatsapp_group_reports" TO "anon";
GRANT ALL ON TABLE "public"."whatsapp_group_reports" TO "authenticated";
GRANT ALL ON TABLE "public"."whatsapp_group_reports" TO "service_role";



GRANT ALL ON TABLE "public"."whatsapp_group_upvotes" TO "anon";
GRANT ALL ON TABLE "public"."whatsapp_group_upvotes" TO "authenticated";
GRANT ALL ON TABLE "public"."whatsapp_group_upvotes" TO "service_role";



GRANT ALL ON TABLE "public"."whatsapp_groups" TO "anon";
GRANT ALL ON TABLE "public"."whatsapp_groups" TO "authenticated";
GRANT ALL ON TABLE "public"."whatsapp_groups" TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLES TO "service_role";







