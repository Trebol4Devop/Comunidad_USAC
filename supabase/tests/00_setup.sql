-- =============================================================================
-- PEMTREE / Comunidad USAC · pgTAP Test Suite Setup & Auth Helpers
-- =============================================================================
create extension if not exists pgtap;

create schema if not exists tests;

-- Helper: Crea o asegura un usuario de prueba en auth.users
create or replace function tests.create_supabase_user(
    p_id uuid,
    p_email text default null
) returns uuid
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
begin
    insert into auth.users (
        id,
        aud,
        role,
        email,
        encrypted_password,
        email_confirmed_at,
        created_at,
        updated_at,
        raw_app_meta_data,
        raw_user_meta_data
    ) values (
        p_id,
        'authenticated',
        'authenticated',
        coalesce(p_email, 'user_' || replace(p_id::text, '-', '_') || '@test.com'),
        '$2a$10$abcdefghijklmnopqrstuvwxyz1234567890',
        now(),
        now(),
        now(),
        '{"provider":"email","providers":["email"]}'::jsonb,
        '{}'::jsonb
    )
    on conflict (id) do update set
        email = coalesce(excluded.email, auth.users.email),
        updated_at = now();

    return p_id;
end;
$$;

-- Elimina una sobrecarga de tres argumentos que pudo quedar de una ejecución
-- anterior de las pruebas locales.
drop function if exists tests.authenticate_as(uuid, text, text);

-- Helper: Autentica una sesión AAL2 (nivel normal para las pruebas autorizadas).
create or replace function tests.authenticate_as(
    p_user_id uuid,
    p_role text default 'authenticated'
) returns void
language plpgsql
as $$
declare
    v_email text := 'user_' || replace(p_user_id::text, '-', '_') || '@test.com';
    v_claims text;
begin
    perform tests.create_supabase_user(p_user_id, v_email);

    v_claims := json_build_object(
        'sub', p_user_id::text,
        'role', p_role,
        'email', v_email,
        'aud', 'authenticated',
        'aal', 'aal2',
        'app_metadata', json_build_object('provider', 'email'),
        'user_metadata', '{}'::jsonb
    )::text;

    execute format('set local role %I', p_role);
    perform set_config('request.jwt.claims', v_claims, true);
    perform set_config('request.jwt.claim.sub', p_user_id::text, true);
    perform set_config('request.jwt.claim.role', p_role, true);
    perform set_config('request.jwt.claim.email', v_email, true);
end;
$$;

-- Helper para los casos que deben simular una sesión con solo el primer factor.
create or replace function tests.authenticate_as_aal1(
    p_user_id uuid
) returns void
language plpgsql
as $$
declare
    v_claims jsonb;
begin
    perform tests.authenticate_as(p_user_id);
    v_claims := current_setting('request.jwt.claims', true)::jsonb
        || jsonb_build_object('aal', 'aal1');
    perform set_config('request.jwt.claims', v_claims::text, true);
end;
$$;

-- Helper: Autentica la sesión actual como anon (visitante público)
create or replace function tests.authenticate_as_anon()
returns void
language plpgsql
as $$
begin
    set local role anon;
    perform set_config('request.jwt.claims', '{"role":"anon"}', true);
    perform set_config('request.jwt.claim.sub', '', true);
    perform set_config('request.jwt.claim.role', 'anon', true);
    perform set_config('request.jwt.claim.email', '', true);
end;
$$;

-- Helper: Asigna rol administrativo en public.user_roles y autentica al usuario
create or replace function tests.authenticate_as_admin(
    p_user_id uuid
) returns void
language plpgsql
as $$
begin
    -- Volver a la sesión privilegiada: el helper puede invocarse cuando ya se
    -- cambió de rol (p. ej. tras authenticate_as_anon) y el INSERT en
    -- public.user_roles está sujeto a RLS.
    reset role;
    perform tests.create_supabase_user(p_user_id);
    insert into public.user_roles (user_id, role)
    values (p_user_id, 'admin')
    on conflict (user_id) do update set role = 'admin';

    perform tests.authenticate_as(p_user_id, 'authenticated');
end;
$$;

-- Helper: Asigna rol de moderador en public.user_roles y autentica al usuario
create or replace function tests.authenticate_as_moderator(
    p_user_id uuid
) returns void
language plpgsql
as $$
begin
    -- Ver comentario en authenticate_as_admin: resetear el rol antes de
    -- escribir en public.user_roles.
    reset role;
    perform tests.create_supabase_user(p_user_id);
    insert into public.user_roles (user_id, role)
    values (p_user_id, 'moderator')
    on conflict (user_id) do update set role = 'moderator';

    perform tests.authenticate_as(p_user_id, 'authenticated');
end;
$$;

-- Helper: Limpia roles asignados en public.user_roles
create or replace function tests.clear_user_roles(
    p_user_id uuid
) returns void
language plpgsql
as $$
begin
    reset role;
    delete from public.user_roles where user_id = p_user_id;
end;
$$;

-- Permisos de los helpers.
-- Los tests corren dentro de una transacción y conservan el rol asignado con
-- `set local role`. Una vez autenticado como anon/authenticated, el schema
-- `tests` debe seguir siendo accesible para poder cambiar de identidad en la
-- misma transacción (si no: "permission denied for schema tests").
grant usage on schema tests to anon, authenticated, service_role;
grant execute on all functions in schema tests to anon, authenticated, service_role;
alter default privileges in schema tests
    grant execute on functions to anon, authenticated, service_role;

-- Verificación de instalación de pgTAP y extensiones
begin;
select plan(5);

select has_extension('pgtap', 'La extension pgtap debe estar instalada.');
select has_schema('public', 'El schema public debe existir.');
select has_schema('tests', 'El schema tests con helpers debe existir.');
select has_table('public', 'posts', 'La tabla public.posts debe existir en el esquema.');
select has_table('public', 'comments', 'La tabla public.comments debe existir en el esquema.');

select * from finish();
rollback;
