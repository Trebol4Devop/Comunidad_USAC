-- =============================================================================
-- pgTAP: perfiles privados y escritura propia con RLS + AAL2
-- =============================================================================
begin;

select plan(6);

create extension if not exists pgtap;

do $$
declare
    v_user_a uuid := '88888888-8888-8888-8888-888888888881';
    v_user_b uuid := '88888888-8888-8888-8888-888888888882';
begin
    perform tests.create_supabase_user(v_user_a, 'profile_a@test.com');
    perform tests.create_supabase_user(v_user_b, 'profile_b@test.com');

    update public.profiles
       set full_name = 'Perfil A'
     where id = v_user_a;
    update public.profiles
       set full_name = 'Perfil B'
     where id = v_user_b;
end;
$$;

select tests.authenticate_as_anon();

select is(
    (select count(*)::integer from public.profiles
      where id in (
        '88888888-8888-8888-8888-888888888881',
        '88888888-8888-8888-8888-888888888882'
      )),
    0,
    'Anon no puede leer perfiles de cuentas registradas'
);

select tests.authenticate_as('88888888-8888-8888-8888-888888888881');

select is(
    (select count(*)::integer from public.profiles
      where id = '88888888-8888-8888-8888-888888888881'),
    1,
    'Una cuenta autenticada puede leer su propio perfil'
);

select is(
    (select count(*)::integer from public.profiles
      where id = '88888888-8888-8888-8888-888888888882'),
    0,
    'Una cuenta autenticada no puede leer el perfil de otra cuenta'
);

select lives_ok(
    $$update public.profiles
         set full_name = 'Perfil A actualizado'
       where id = '88888888-8888-8888-8888-888888888881'$$,
    'AAL2 permite actualizar el perfil propio'
);

update public.profiles
   set full_name = 'Modificado por otra cuenta'
 where id = '88888888-8888-8888-8888-888888888882';

reset role;

select is(
    (select full_name from public.profiles
      where id = '88888888-8888-8888-8888-888888888882'),
    'Perfil B',
    'RLS impide modificar el perfil de otra cuenta'
);

select tests.authenticate_as('88888888-8888-8888-8888-888888888881');

select throws_ok(
    $$insert into public.profiles (id, full_name)
      values (
        '88888888-8888-8888-8888-888888888881',
        'Inserción directa no permitida'
      )$$,
    '42501',
    null,
    'Las cuentas no pueden insertar perfiles directamente; los crea el trigger'
);

select * from finish();
rollback;
