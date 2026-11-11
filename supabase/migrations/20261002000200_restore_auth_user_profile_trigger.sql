-- =============================================================================
-- Garantizar el trigger de auto-creación de perfiles en auth.users
-- =============================================================================
-- La función public.handle_new_user_profile() existe y viene del baseline. El
-- dump schema-only no incluyó su trigger sobre auth.users, así que en local
-- ningún usuario nuevo obtenía fila en public.profiles.
--
-- En el proyecto remoto el trigger YA existe, pero con el nombre
-- "trg_on_auth_user_created". Esta migración es idempotente y usa ese mismo
-- nombre:
--   - En remoto: el trigger ya existe -> no hace nada.
--   - En local:    no existe -> lo crea.
-- =============================================================================

do $$
begin
    if not exists (
        select 1
        from pg_trigger t
        join pg_class c on c.oid = t.tgrelid
        join pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'auth'
          and c.relname = 'users'
          and t.tgname = 'trg_on_auth_user_created'
          and not t.tgisinternal
    ) then
        create trigger trg_on_auth_user_created
            after insert on auth.users
            for each row execute function public.handle_new_user_profile();
    end if;
end $$;
