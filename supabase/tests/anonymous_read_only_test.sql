-- =============================================================================
-- Visitante con sesión anónima de Supabase Auth: solo lectura
-- =============================================================================
begin;

select plan(8);

create extension if not exists pgtap;

do $$
declare
    v_guest uuid := '44444444-4444-4444-4444-444444444444';
    v_user uuid := '55555555-5555-5555-5555-555555555555';
begin
    perform tests.create_supabase_user(v_guest, 'anonymous_guest@test.com');
    perform tests.create_supabase_user(v_user, 'registered_user@test.com');

    insert into public.posts (
        id, user_id, title, content, category, carrera, author_alias, moderation_status
    ) values (
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0044',
        v_guest,
        'Post visible para visitante',
        'Contenido de prueba',
        'general',
        'sistemas',
        'Visitante',
        0
    ) on conflict (id) do nothing;
end $$;

-- Simular un JWT emitido para un usuario de signInAnonymously().
set local role authenticated;
select set_config(
    'request.jwt.claims',
    '{"sub":"44444444-4444-4444-4444-444444444444","role":"authenticated","aud":"authenticated","is_anonymous":true}',
    true
);
select set_config('request.jwt.claim.sub', '44444444-4444-4444-4444-444444444444', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

select is(
    (select count(*)::integer from public.posts
      where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0044'),
    1,
    'La sesión anónima conserva la lectura de contenido público'
);

select throws_ok(
    $$insert into public.posts (
        id, user_id, title, content, category, carrera, author_alias
      ) values (
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0045',
        '44444444-4444-4444-4444-444444444444',
        'Intento anónimo',
        'No debe guardarse',
        'general',
        'sistemas',
        'Visitante'
      )$$,
    '42501',
    null,
    'La sesión anónima no puede crear publicaciones'
);

update public.posts
   set title = 'Título modificado por visitante'
 where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0044';

select is(
    (select title from public.posts where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0044'),
    'Post visible para visitante',
    'La sesión anónima no puede modificar publicaciones'
);

delete from public.posts
 where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0044';

select is(
    (select count(*)::integer from public.posts
      where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0044'),
    1,
    'La sesión anónima no puede eliminar publicaciones'
);

select throws_ok(
    $$select public.report_forum_post(
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0044'::uuid,
        'spam'
      )$$,
    '42501',
    'Debes iniciar sesión con una cuenta para reportar.',
    'La sesión anónima tampoco puede escribir mediante el RPC de reportes'
);

select is(
    public.report_marketplace_item(
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0044'::uuid,
        'spam'
    ),
    false,
    'El RPC de reportes de marketplace rechaza sesiones anónimas'
);

-- Confirmar que la restricción no impide las escrituras de cuentas reales.
reset role;
select tests.authenticate_as('55555555-5555-5555-5555-555555555555');

select lives_ok(
    $$insert into public.posts (
        id, user_id, title, content, category, carrera, author_alias
      ) values (
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0055',
        '55555555-5555-5555-5555-555555555555',
        'Post de cuenta registrada',
        'Contenido permitido',
        'general',
        'sistemas',
        'Usuario registrado'
      )$$,
    'Una cuenta registrada conserva permiso para crear publicaciones'
);

select is(
    (select count(*)::integer from public.posts
      where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0055'),
    1,
    'La publicación de la cuenta registrada queda guardada'
);

select * from finish();
rollback;
