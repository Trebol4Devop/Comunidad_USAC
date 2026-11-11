create schema if not exists _triggers;

create or replace function public.is_pemtree_admin(p_user_id uuid default auth.uid())
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $function$
BEGIN
    IF p_user_id::text = '10884922-e583-409e-b3e8-8a875ddaa5d9' THEN
        RETURN true;
    END IF;
    IF EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = p_user_id AND role = 'admin') THEN
        RETURN true;
    END IF;
    RETURN false;
END;
$function$;

create or replace function public.is_pemtree_moderator(p_user_id uuid default auth.uid())
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $function$
BEGIN
    IF public.is_pemtree_admin(p_user_id) THEN
        RETURN true;
    END IF;
    IF EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = p_user_id AND role = 'moderator') THEN
        RETURN true;
    END IF;
    RETURN false;
END;
$function$;

create or replace function public.check_content_moderation()
returns trigger
language plpgsql
set search_path to 'pg_catalog'
as $function$
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
            $function$;

create or replace function public.check_whatsapp_groups_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
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
    $function$;

create or replace function public.reset_moderation_on_edit()
returns trigger
language plpgsql
set search_path to 'pg_catalog'
as $function$
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
$function$;

create or replace function public.prevent_nonmoderator_restore()
returns trigger
language plpgsql
set search_path = ''
as $function$
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
$function$;

create or replace function public.v_moderation_queue()
returns table (entity_table text, entity_id uuid, entity_key uuid, content text, created_at timestamptz)
language sql
stable
set search_path = ''
as $function$
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
$function$;

create or replace function public.get_push_secrets()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
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
$function$;

create or replace function public.apply_moderation_batch(p_items jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $function$
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
$function$;

create or replace function public.marcar_pendientes_error(p_horas integer default 1)
returns integer
language plpgsql
security definer
set search_path = ''
as $function$
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
$function$;

create or replace function public.ocultar_contenido_moderado(p_tabla text, p_item_id uuid, p_justificacion text default null)
returns boolean
language plpgsql
security definer
set search_path = ''
as $function$
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
$function$;

create or replace function public.restaurar_contenido_moderado(p_tabla text, p_item_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $function$
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
$function$;

create or replace function public.eliminar_contenido_moderado(p_tabla text, p_item_id uuid, p_justificacion text default null)
returns boolean
language plpgsql
security definer
set search_path = ''
as $function$
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
$function$;

create or replace function public.delete_inappropriate_posts()
returns text
language plpgsql
security definer
set search_path = ''
as $function$
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
$function$;

create or replace function public.delete_old_posts(months_old integer default 3)
returns text
language plpgsql
security definer
set search_path = ''
as $function$
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
$function$;

create or replace function public.purge_inappropriate_content()
returns text
language plpgsql
security definer
set search_path = ''
as $function$
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
$function$;

create or replace function public.purge_old_content(p_months integer default 3)
returns text
language plpgsql
security definer
set search_path = ''
as $function$
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
$function$;

create or replace function public.purge_reported_groups()
returns text
language plpgsql
security definer
set search_path = ''
as $function$
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
$function$;

create or replace function public.limpieza_semestral_pemtree()
returns void
language plpgsql
security definer
set search_path = ''
as $function$
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
    $function$;

create or replace function public.get_user_profiles(p_user_ids uuid[])
returns table (user_id uuid, email text, full_name text, avatar_url text)
language plpgsql
stable
security definer
set search_path = ''
as $function$
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
$function$;

create or replace function _triggers.sync_post_likes_counter()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.posts
        SET likes = (SELECT COUNT(*) FROM public.post_likes WHERE post_id = NEW.post_id)
        WHERE id = NEW.post_id;
    ELSE
        UPDATE public.posts
        SET likes = (SELECT COUNT(*) FROM public.post_likes WHERE post_id = OLD.post_id)
        WHERE id = OLD.post_id;
    END IF;
    RETURN NULL;
END;
$function$;

create or replace function _triggers.sync_group_upvotes_counter()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
DECLARE
    v_group_id uuid;
BEGIN
    v_group_id := COALESCE(NEW.group_id, OLD.group_id);
    UPDATE public.whatsapp_groups
    SET upvotes = (SELECT COUNT(*) FROM public.whatsapp_group_upvotes WHERE group_id = v_group_id)
    WHERE id = v_group_id;
    RETURN NULL;
END;
$function$;

create or replace function _triggers.sync_group_reported_counter()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
DECLARE
    v_group_id uuid;
BEGIN
    v_group_id := COALESCE(NEW.group_id, OLD.group_id);
    UPDATE public.whatsapp_groups
    SET reported_count = (SELECT COUNT(*) FROM public.whatsapp_group_reports WHERE group_id = v_group_id)
    WHERE id = v_group_id;
    RETURN NULL;
END;
$function$;

create or replace function _triggers.crear_notificacion_foro(p_user_id uuid, p_type text, p_title text, p_body text, p_actor_alias text, p_post_id uuid, p_comment_id uuid, p_actor_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $function$
declare
    v_id     uuid;
    v_secret text;
    v_url    text := 'https://jsdshvnkbrkwobfhdysh.supabase.co/functions/v1/send-push';
    v_pref   record;
    v_subs   bigint;
begin
    if p_user_id is null or p_user_id = p_actor_id then
        return;
    end if;

    select comment_enabled, reply_enabled, like_enabled, new_post_enabled
      into v_pref
      from public.notification_preferences
     where user_id = p_user_id;

    if v_pref is not null then
        if p_type = 'comment'  and not v_pref.comment_enabled  then return; end if;
        if p_type = 'reply'    and not v_pref.reply_enabled    then return; end if;
        if p_type = 'like'     and not v_pref.like_enabled     then return; end if;
        if p_type = 'new_post' and not v_pref.new_post_enabled then return; end if;
    end if;

    insert into public.user_notifications
        (user_id, type, title, body, actor_alias, post_id, comment_id)
    values
        (p_user_id, p_type, p_title, p_body, p_actor_alias, p_post_id, p_comment_id)
    returning id into v_id;

    delete from public.user_notifications
     where user_id = p_user_id
       and id not in (
           select id
             from public.user_notifications
            where user_id = p_user_id
            order by created_at desc
            limit 20
       );

    select count(*) into v_subs
      from public.notification_subscriptions
     where user_id = p_user_id;

    if v_subs > 0 then
        select decrypted_secret into v_secret
          from vault.decrypted_secrets
         where name = 'push_edge_secret';

        if v_secret is not null then
            perform net.http_post(
                url     := v_url,
                body    := jsonb_build_object('notification_id', v_id),
                headers := jsonb_build_object(
                    'Content-Type',    'application/json',
                    'x-pemtree-secret', v_secret
                ),
                timeout_milliseconds := 5000
            );
        end if;
    end if;
end;
$function$;

create or replace function _triggers.notify_comment_inserted()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
    v_post  record;
    v_recip uuid;
begin
    select user_id, title
      into v_post
      from public.posts
     where id = NEW.post_id;

    if v_post is null or v_post.user_id is null then
        return null;
    end if;

    if NEW.parent_id is not null then
        select user_id into v_recip
          from public.comments
         where id = NEW.parent_id;
        if v_recip is null then
            return null;
        end if;
        perform _triggers.crear_notificacion_foro(
            p_user_id     := v_recip,
            p_type        := 'reply',
            p_title       := left(coalesce(v_post.title, 'Te respondieron en el foro'), 60),
            p_body        := coalesce(NEW.author_alias, 'Estudiante') || ' respondió: ' || left(coalesce(NEW.content, ''), 100),
            p_actor_alias := coalesce(NEW.author_alias, 'Estudiante'),
            p_post_id     := NEW.post_id,
            p_comment_id  := NEW.id,
            p_actor_id    := NEW.user_id
        );
    else
        perform _triggers.crear_notificacion_foro(
            p_user_id     := v_post.user_id,
            p_type        := 'comment',
            p_title       := left(coalesce(v_post.title, 'Nuevo comentario'), 60),
            p_body        := coalesce(NEW.author_alias, 'Estudiante') || ' comentó: ' || left(coalesce(NEW.content, ''), 100),
            p_actor_alias := coalesce(NEW.author_alias, 'Estudiante'),
            p_post_id     := NEW.post_id,
            p_comment_id  := NEW.id,
            p_actor_id    := NEW.user_id
        );
    end if;

    return null;
end;
$function$;

create or replace function _triggers.notify_new_post()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
    r record;
    v_carrera text := coalesce(NEW.carrera, 'todas');
begin
    for r in
        select user_id
          from public.notification_preferences
         where new_post_enabled
           and (v_carrera = any(carreras) or 'todas' = any(carreras))
    loop
        perform _triggers.crear_notificacion_foro(
            p_user_id     := r.user_id,
            p_type        := 'new_post',
            p_title       := left(coalesce(NEW.title, 'Nueva publicación'), 60),
            p_body        := coalesce(NEW.author_alias, 'Estudiante') || ' · ' || v_carrera || ' · ' || left(coalesce(NEW.content, ''), 100),
            p_actor_alias := coalesce(NEW.author_alias, 'Estudiante'),
            p_post_id     := NEW.id,
            p_comment_id  := null,
            p_actor_id    := NEW.user_id
        );
    end loop;

    return null;
end;
$function$;

create or replace function _triggers.notify_post_liked()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
    v_post record;
    v_alias text;
begin
    select user_id, title
      into v_post
      from public.posts
     where id = NEW.post_id;

    if v_post is null or v_post.user_id is null then
        return null;
    end if;

    select coalesce(
        (select author_alias from public.posts    where user_id = NEW.user_id order by created_at desc limit 1),
        (select author_alias from public.comments where user_id = NEW.user_id order by created_at desc limit 1),
        'Estudiante'
    ) into v_alias;

    perform _triggers.crear_notificacion_foro(
        p_user_id     := v_post.user_id,
        p_type        := 'like',
        p_title       := left(coalesce(v_post.title, 'Me gusta en tu publicación'), 60),
        p_body        := 'A ' || v_alias || ' le gustó tu publicación',
        p_actor_alias := v_alias,
        p_post_id     := NEW.post_id,
        p_comment_id  := null,
        p_actor_id    := NEW.user_id
    );

    return null;
end;
$function$;;
