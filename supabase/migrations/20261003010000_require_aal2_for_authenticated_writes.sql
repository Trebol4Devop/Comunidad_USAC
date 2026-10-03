-- =============================================================================
-- Exigir AAL2 para escrituras de sesiones autenticadas
-- =============================================================================
-- Las políticas RLS protegen DML normal. El trigger adicional cubre RPC con
-- SECURITY DEFINER, que de otro modo podrían saltarse RLS.
-- Lecturas públicas y escrituras de service_role/procesos internos no cambian.
-- =============================================================================

create or replace function public.enforce_aal2_for_authenticated_writes()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
    v_jwt jsonb := auth.jwt();
begin
    if v_jwt ->> 'role' = 'authenticated'
       and (v_jwt ->> 'aal') is distinct from 'aal2' then
        raise exception 'Se requiere autenticación de dos factores (AAL2) para modificar datos.'
            using errcode = '42501';
    end if;

    if tg_op = 'DELETE' then
        return old;
    end if;
    return new;
end;
$$;

-- Añadir el trigger a las tablas públicas existentes. Las tablas creadas en
-- migraciones futuras deben incluir este guard y sus políticas AAL2.
do $$
declare
    v_table record;
begin
    for v_table in
        select n.nspname, c.relname
        from pg_class c
        join pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'public'
          and c.relkind in ('r', 'p')
          and not c.relispartition
    loop
        execute format(
            'drop trigger if exists require_aal2_for_writes on %I.%I',
            v_table.nspname,
            v_table.relname
        );
        execute format(
            'create trigger require_aal2_for_writes before insert or update or delete on %I.%I for each row execute function public.enforce_aal2_for_authenticated_writes()',
            v_table.nspname,
            v_table.relname
        );
    end loop;
end;
$$;

-- AND restrictivo con las políticas permisivas existentes: toda escritura
-- directa desde el rol authenticated requiere un JWT con aal = aal2.
do $$
declare
    v_table record;
    v_command text;
    v_policy text;
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
            v_policy := 'require_aal2_' || v_command;
            execute format(
                'drop policy if exists %I on %I.%I',
                v_policy,
                v_table.nspname,
                v_table.relname
            );

            if v_command = 'insert' then
                execute format(
                    'create policy %I on %I.%I as restrictive for insert to authenticated with check ((select auth.jwt() ->> ''aal'') = ''aal2'')',
                    v_policy,
                    v_table.nspname,
                    v_table.relname
                );
            elsif v_command = 'update' then
                execute format(
                    'create policy %I on %I.%I as restrictive for update to authenticated using ((select auth.jwt() ->> ''aal'') = ''aal2'') with check ((select auth.jwt() ->> ''aal'') = ''aal2'')',
                    v_policy,
                    v_table.nspname,
                    v_table.relname
                );
            else
                execute format(
                    'create policy %I on %I.%I as restrictive for delete to authenticated using ((select auth.jwt() ->> ''aal'') = ''aal2'')',
                    v_policy,
                    v_table.nspname,
                    v_table.relname
                );
            end if;
        end loop;
    end loop;
end;
$$;
