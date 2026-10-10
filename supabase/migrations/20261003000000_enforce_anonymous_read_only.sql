-- =============================================================================
-- Visitantes solo lectura, incluyendo sesiones anónimas de Supabase Auth
-- =============================================================================
-- El rol `anon` recibe únicamente permisos de lectura sobre las tablas públicas.
-- Una sesión de signInAnonymously() usa el rol `authenticated`; sus escrituras
-- se bloquean con políticas RLS restrictivas sin afectar a usuarios registrados.
-- =============================================================================

-- Quitar permisos de escritura y administración al rol público `anon`,
-- conservando los permisos SELECT ya configurados por tabla.
do $$
declare
    v_relation record;
begin
    for v_relation in
        select n.nspname, c.relname, c.relkind
        from pg_class c
        join pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'public'
          and c.relkind in ('r', 'p', 'v', 'f')
    loop
        if v_relation.relkind in ('r', 'p') then
            execute format(
                'revoke insert, update, delete, truncate, references, trigger, maintain on table %I.%I from anon',
                v_relation.nspname,
                v_relation.relname
            );
        elsif v_relation.relkind in ('v', 'f') then
            execute format(
                'revoke insert, update, delete on table %I.%I from anon',
                v_relation.nspname,
                v_relation.relname
            );
        end if;
    end loop;
end;
$$;

-- Evitar que las tablas y secuencias nuevas reciban permisos de escritura
-- automáticamente para `anon` por los default privileges del proyecto.
alter default privileges for role postgres in schema public
    revoke insert, update, delete, truncate, references, trigger on tables from anon;
alter default privileges for role postgres in schema public
    revoke all on sequences from anon;
revoke all on all sequences in schema public from anon;

-- Las políticas restrictivas se combinan con AND con las políticas permisivas
-- existentes. Esto bloquea escrituras incluso donde ya existe una política
-- `FOR ALL` o una política abierta como la de sponsor_requests.
do $$
declare
    v_table record;
    v_command text;
    v_policy text;
    v_using text;
    v_check text;
begin
    for v_table in
        select n.nspname, c.relname
        from pg_class c
        join pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'public'
          and c.relkind in ('r', 'p')
          and c.relrowsecurity
    loop
        foreach v_command in array array['insert', 'update', 'delete']
        loop
            v_policy := 'deny_anon_' || v_command;
            execute format('drop policy if exists %I on %I.%I', v_policy, v_table.nspname, v_table.relname);

            if v_command = 'insert' then
                execute format(
                    'create policy %I on %I.%I as restrictive for insert to anon with check (false)',
                    v_policy, v_table.nspname, v_table.relname
                );
            elsif v_command = 'update' then
                execute format(
                    'create policy %I on %I.%I as restrictive for update to anon using (false) with check (false)',
                    v_policy, v_table.nspname, v_table.relname
                );
            else
                execute format(
                    'create policy %I on %I.%I as restrictive for delete to anon using (false)',
                    v_policy, v_table.nspname, v_table.relname
                );
            end if;

            v_policy := 'deny_anonymous_auth_' || v_command;
            execute format('drop policy if exists %I on %I.%I', v_policy, v_table.nspname, v_table.relname);

            v_using := '(select nullif(current_setting(''request.jwt.claims'', true), '''')::jsonb ->> ''is_anonymous'') is distinct from ''true''';
            v_check := v_using;
            if v_command = 'insert' then
                execute format(
                    'create policy %I on %I.%I as restrictive for insert to authenticated with check (%s)',
                    v_policy, v_table.nspname, v_table.relname, v_check
                );
            elsif v_command = 'update' then
                execute format(
                    'create policy %I on %I.%I as restrictive for update to authenticated using (%s) with check (%s)',
                    v_policy, v_table.nspname, v_table.relname, v_using, v_check
                );
            else
                execute format(
                    'create policy %I on %I.%I as restrictive for delete to authenticated using (%s)',
                    v_policy, v_table.nspname, v_table.relname, v_using
                );
            end if;
        end loop;
    end loop;
end;
$$;

-- Los RPC SECURITY DEFINER no están sujetos a las políticas RLS de las tablas
-- que escriben. Rechazar explícitamente sesiones anónimas antes de insertar.
create or replace function public.report_forum_comment(
    p_comment_id uuid,
    p_reason text,
    p_details text default null
) returns boolean
    language plpgsql security definer
    set search_path to 'public'
as $$
begin
    if auth.uid() is null or (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'is_anonymous') = 'true' then
        raise exception 'Debes iniciar sesión con una cuenta para reportar.'
            using errcode = '42501';
    end if;

    insert into public.entity_reports (reporter_id, entity_type, entity_id, reason, details)
    values (auth.uid(), 'comment', p_comment_id, p_reason, p_details)
    on conflict (reporter_id, entity_type, entity_id) do nothing;

    return true;
end;
$$;

create or replace function public.report_forum_post(
    p_post_id uuid,
    p_reason text,
    p_details text default null
) returns boolean
    language plpgsql security definer
    set search_path to 'public'
as $$
begin
    if auth.uid() is null or (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'is_anonymous') = 'true' then
        raise exception 'Debes iniciar sesión con una cuenta para reportar.'
            using errcode = '42501';
    end if;

    insert into public.entity_reports (reporter_id, entity_type, entity_id, reason, details)
    values (auth.uid(), 'post', p_post_id, p_reason, p_details)
    on conflict (reporter_id, entity_type, entity_id) do nothing;

    return true;
end;
$$;

create or replace function public.report_marketplace_item(
    target_item_id uuid,
    report_reason text,
    target_seller_id uuid default null,
    target_seller_alias text default null
) returns boolean
    language plpgsql security definer
    set search_path to 'public'
as $$
declare
    v_count int;
begin
    if auth.uid() is null or (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'is_anonymous') = 'true' then
        return false;
    end if;

    insert into public.entity_reports (
        reporter_id,
        entity_type,
        entity_id,
        entity_owner_id,
        reason,
        metadata
    ) values (
        auth.uid(),
        'marketplace_item',
        target_item_id,
        case when target_seller_id is not null and public.user_exists(target_seller_id)
             then target_seller_id else null end,
        report_reason,
        jsonb_strip_nulls(jsonb_build_object('seller_alias', target_seller_alias))
    )
    on conflict (reporter_id, entity_type, entity_id) do nothing;

    select reported_count into v_count
    from public.marketplace_items
    where id = target_item_id;

    if v_count >= 3 then
        update public.marketplace_items
           set moderation_status = 2
         where id = target_item_id;
    end if;

    return true;
exception
    when others then
        return false;
end;
$$;
