-- =============================================================================
-- PEMTREE · Unificación de columnas de moderación
-- Fecha: 2026-09-14
--
-- Corrige el hallazgo "Moderación dispersa y desigual":
--   - posts, comments, student_groups y entity_reports ya tienen el juego
--     completo: moderation_status, moderation_label, moderation_confidence,
--     moderation_reason, moderated_at, moderated_by.
--   - marketplace_items solo tenía moderation_status. Se le agregan las 5
--     columnas faltantes + FK de moderated_by.
--   - Se alinea la lógica de moderación para que marketplace_items sea tratado
--     igual que el resto: reset al editar, batch automático, marcado de
--     pendientes con error, cola de moderación y acciones admin
--     (ocultar / restaurar / eliminar).
--   - Toda acción de moderación queda registrada en moderation_audit_log, que
--     es el log central de acciones (no se crea una tabla nueva para no
--     duplicar la que ya existe).
--   - La vista de compatibilidad marketplace_reports expone además las
--     columnas estándar de moderación.
--
-- Es idempotente.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) marketplace_items: columnas de moderación completas
-- -----------------------------------------------------------------------------
alter table public.marketplace_items
  add column if not exists moderation_label text,
  add column if not exists moderation_confidence double precision,
  add column if not exists moderation_reason text,
  add column if not exists moderated_at timestamptz,
  add column if not exists moderated_by uuid;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.marketplace_items'::regclass
      and conname = 'marketplace_items_moderated_by_fkey'
  ) then
    alter table public.marketplace_items
      add constraint marketplace_items_moderated_by_fkey
      foreign key (moderated_by) references auth.users(id) on delete set null;
  end if;
end $$;

create index if not exists idx_marketplace_items_moderation
  on public.marketplace_items (moderation_status, created_at desc);

comment on column public.marketplace_items.moderation_label is
  'Etiqueta de moderación: appropriate | inappropriate | error | ...';
comment on column public.marketplace_items.moderation_confidence is
  'Confianza del clasificador de moderación (0.0 - 1.0).';
comment on column public.marketplace_items.moderation_reason is
  'Justificación o motivo de la decisión de moderación.';

-- -----------------------------------------------------------------------------
-- 2) reset_moderation_on_edit: rama marketplace_items
--    (se reemplaza la función completa conservando todas las ramas existentes)
-- -----------------------------------------------------------------------------
create or replace function public.reset_moderation_on_edit()
returns trigger
language plpgsql
set search_path to 'public'
as $$
begin
    if tg_table_name = 'posts' then
        if new.title is distinct from old.title
           or new.content is distinct from old.content
           or new.category is distinct from old.category
        then
            new.moderation_status := 0;
            new.moderation_label := null;
            new.moderation_confidence := null;
            new.moderation_reason := null;
            new.moderated_at := null;
            new.moderated_by := null;
        end if;
        return new;
    end if;

    if tg_table_name = 'comments' then
        if new.content is distinct from old.content then
            new.moderation_status := 0;
            new.moderation_label := null;
            new.moderation_confidence := null;
            new.moderation_reason := null;
            new.moderated_at := null;
            new.moderated_by := null;
        end if;
        return new;
    end if;

    if tg_table_name in ('student_groups', 'whatsapp_groups') then
        if new.title is distinct from old.title
           or new.carrera is distinct from old.carrera
           or new.curso is distinct from old.curso
           or new.section is distinct from old.section
           or new.link is distinct from old.link
           or new.description is distinct from old.description
        then
            new.moderation_status := 0;
            new.moderation_label := null;
            new.moderation_confidence := null;
            new.moderation_reason := null;
            new.moderated_at := null;
            new.moderated_by := null;
        end if;
        return new;
    end if;

    if tg_table_name = 'marketplace_items' then
        if new.title is distinct from old.title
           or new.description is distinct from old.description
           or new.category is distinct from old.category
           or new.price is distinct from old.price
           or new.image_urls is distinct from old.image_urls
        then
            new.moderation_status := 0;
            new.moderation_label := null;
            new.moderation_confidence := null;
            new.moderation_reason := null;
            new.moderated_at := null;
            new.moderated_by := null;
        end if;
        return new;
    end if;

    if tg_table_name = 'user_reports' then
        if new.reason is distinct from old.reason then
            new.moderation_status := 0;
            new.moderation_label := null;
            new.moderation_confidence := null;
            new.moderation_reason := null;
            new.moderated_at := null;
            new.moderated_by := null;
        end if;
        return new;
    end if;

    if tg_table_name in ('student_group_reports', 'whatsapp_group_reports') then
        if new.reason is distinct from old.reason then
            new.moderation_status := 0;
            new.moderation_label := null;
            new.moderation_confidence := null;
            new.moderation_reason := null;
            new.moderated_at := null;
            new.moderated_by := null;
        end if;
        return new;
    end if;

    if tg_table_name = 'entity_reports' then
        if new.reason is distinct from old.reason
           or new.details is distinct from old.details
           or new.metadata is distinct from old.metadata
        then
            new.moderation_status := 0;
            new.moderation_label := null;
            new.moderation_confidence := null;
            new.moderation_reason := null;
            new.moderated_at := null;
            new.moderated_by := null;
        end if;
        return new;
    end if;

    return new;
end $$;

drop trigger if exists trg_reset_moderation_marketplace_items on public.marketplace_items;
create trigger trg_reset_moderation_marketplace_items
  before update on public.marketplace_items
  for each row execute function public.reset_moderation_on_edit();

-- -----------------------------------------------------------------------------
-- 3) moderate_marketplace_item: campos completos + audit log
--    (misma firma base; label/confidence/reason son opcionales)
--    Se elimina la versión de 2 argumentos para que PostgREST no quede con
--    dos candidatos ambiguos al llamar la RPC.
-- -----------------------------------------------------------------------------
drop function if exists public.moderate_marketplace_item(uuid, integer);

create or replace function public.moderate_marketplace_item(
    target_item_id uuid,
    new_status integer,
    p_label text default null,
    p_confidence double precision default null,
    p_reason text default null
)
returns boolean
language plpgsql
security definer
set search_path to 'public'
as $$
declare
    user_role_val text;
    v_user_id uuid := auth.uid();
begin
    select role into user_role_val
    from public.user_roles
    where user_id = v_user_id;

    if user_role_val = 'admin' or user_role_val = 'moderator' then
        update public.marketplace_items
           set moderation_status = new_status,
               moderation_label = coalesce(p_label, moderation_label),
               moderation_confidence = coalesce(p_confidence, moderation_confidence),
               moderation_reason = coalesce(nullif(trim(p_reason), ''), moderation_reason),
               moderated_at = now(),
               moderated_by = v_user_id
         where id = target_item_id;

        if not found then
            return false;
        end if;

        insert into public.moderation_audit_log
            (moderator_id, entity_table, entity_id, justification, is_automated, moderation_label, confidence)
        values
            (v_user_id, 'marketplace_items', target_item_id,
             coalesce(nullif(trim(p_reason), ''), 'Moderación manual de publicación de marketplace'),
             false, p_label, p_confidence);

        return true;
    else
        return false;
    end if;
end $$;

-- -----------------------------------------------------------------------------
-- 4) apply_moderation_batch: soporta marketplace_items
--    (se reemplaza conservando todas las ramas existentes)
-- -----------------------------------------------------------------------------
create or replace function public.apply_moderation_batch(p_items jsonb)
returns integer
language plpgsql
security definer
set search_path to ''
as $$
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
        ELSIF v_table = 'marketplace_items' THEN
            UPDATE public.marketplace_items SET moderation_status = v_status, moderation_label = v_label,
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

-- -----------------------------------------------------------------------------
-- 5) marcar_pendientes_error: incluye marketplace_items
--    (se reemplaza conservando todos los bloques existentes)
-- -----------------------------------------------------------------------------
create or replace function public.marcar_pendientes_error(p_horas integer default 1)
returns integer
language plpgsql
security definer
set search_path to ''
as $$
DECLARE
    v_limite timestamptz := now() - make_interval(hours => p_horas);
    v_total integer := 0;
    v_cont integer;
BEGIN
    -- posts
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

    -- comments
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

    -- whatsapp_groups
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

    -- marketplace_items
    WITH marcados AS (
        UPDATE public.marketplace_items
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
    SELECT NULL, 'marketplace_items', id, 'Servicio de moderación no disponible', true, 'error', 0
    FROM marcados;
    GET DIAGNOSTICS v_cont = ROW_COUNT;
    v_total := v_total + v_cont;

    -- user_reports
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

    -- whatsapp_group_reports (PK compuesta group_id + user_id)
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

-- -----------------------------------------------------------------------------
-- 6) Acciones admin: soporte marketplace_items
--    (se reemplazan conservando la lógica y las tablas existentes)
-- -----------------------------------------------------------------------------
create or replace function public.ocultar_contenido_moderado(p_tabla text, p_item_id uuid, p_justificacion text default null::text)
returns boolean
language plpgsql
security definer
set search_path to ''
as $$
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
    ELSIF p_tabla = 'marketplace_items' THEN
        SELECT user_id INTO v_owner_id FROM public.marketplace_items WHERE id = p_item_id;
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
    ELSIF p_tabla = 'marketplace_items' THEN
        UPDATE public.marketplace_items
        SET moderation_status = 2, moderation_label = 'inappropriate', moderation_reason = v_justificacion,
            moderated_by = v_user_id, moderated_at = now()
        WHERE id = p_item_id;
    END IF;

    RETURN true;
END;
$$;

create or replace function public.restaurar_contenido_moderado(p_tabla text, p_item_id uuid)
returns boolean
language plpgsql
security definer
set search_path to ''
as $$
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
    ELSIF p_tabla = 'marketplace_items' THEN
        PERFORM 1 FROM public.marketplace_items WHERE id = p_item_id;
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
    ELSIF p_tabla = 'marketplace_items' THEN
        UPDATE public.marketplace_items
        SET moderation_status = 1, moderation_label = 'appropriate', moderation_reason = NULL,
            moderated_by = NULL, moderated_at = NULL
        WHERE id = p_item_id;
    END IF;

    RETURN true;
END;
$$;

create or replace function public.eliminar_contenido_moderado(p_tabla text, p_item_id uuid, p_justificacion text default null::text)
returns boolean
language plpgsql
security definer
set search_path to ''
as $$
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
    ELSIF p_tabla = 'marketplace_items' THEN
        SELECT user_id INTO v_owner_id FROM public.marketplace_items WHERE id = p_item_id;
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
    ELSIF p_tabla = 'marketplace_items' THEN
        DELETE FROM public.marketplace_items WHERE id = p_item_id;
    END IF;

    RETURN true;
END;
$$;

-- -----------------------------------------------------------------------------
-- 7) v_moderation_queue: incluye marketplace_items
-- -----------------------------------------------------------------------------
create or replace function public.v_moderation_queue()
returns TABLE(entity_table text, entity_id uuid, entity_key uuid, content text, created_at timestamp with time zone)
language sql
stable
set search_path to ''
as $$
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
    SELECT 'marketplace_items', id, NULL::uuid,
           COALESCE(title, '') || ' ' || COALESCE(description, ''),
           created_at
    FROM public.marketplace_items
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

-- -----------------------------------------------------------------------------
-- 8) marketplace_reports (vista de compatibilidad): expone las columnas
--    estándar de moderación (se agregan al final, se conservan las existentes)
-- -----------------------------------------------------------------------------
create or replace view public.marketplace_reports
with (security_invoker = true) as
select er.id,
       er.entity_id as item_id,
       er.reporter_id as user_id,
       er.reason,
       er.created_at,
       er.entity_owner_id as seller_user_id,
       er.metadata->>'seller_alias' as seller_alias,
       coalesce(er.metadata->>'legacy_status', 'pending') as status,
       er.moderation_status,
       er.moderation_label,
       er.moderation_confidence,
       er.moderation_reason,
       er.moderated_at,
       er.moderated_by
from public.entity_reports er
where er.entity_type = 'marketplace_item';

-- -----------------------------------------------------------------------------
-- 9) Resumen
-- -----------------------------------------------------------------------------
do $$
declare
  v_missing text;
begin
  select string_agg(t.tabla || '.' || t.col, ', ')
    into v_missing
  from (
    select c.relname as tabla, col as col
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    cross join (values
      ('moderation_status'), ('moderation_label'), ('moderation_confidence'),
      ('moderation_reason'), ('moderated_at'), ('moderated_by')
    ) as cols(col)
    where n.nspname = 'public'
      and c.relname in ('posts', 'comments', 'student_groups', 'marketplace_items', 'entity_reports')
      and not exists (
        select 1 from pg_attribute a
        where a.attrelid = c.oid and a.attname = cols.col
          and a.attnum > 0 and not a.attisdropped
      )
  ) t;

  if v_missing is null then
    raise notice 'Moderación unificada: posts, comments, student_groups, marketplace_items y entity_reports tienen las 6 columnas.';
  else
    raise notice 'Faltan columnas de moderación en: %', v_missing;
  end if;
end $$;
