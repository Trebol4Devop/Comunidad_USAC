-- =============================================================================
-- pgTAP: las sesiones autenticadas requieren AAL2 para escribir
-- =============================================================================
begin;

select plan(10);

create extension if not exists pgtap;

do $$
declare
    v_user uuid := '77777777-7777-7777-7777-777777777777';
begin
    perform tests.create_supabase_user(v_user, 'aal2_user@test.com');
    insert into public.posts (
        id, user_id, title, content, category, carrera, author_alias, moderation_status
    ) values (
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0077',
        v_user,
        'Post protegido por AAL2',
        'Contenido de prueba',
        'general',
        'sistemas',
        'Usuario de prueba',
        0
    ) on conflict (id) do nothing;
end;
$$;

select tests.authenticate_as_aal1(
    '77777777-7777-7777-7777-777777777777'
);

select is(
    (select count(*)::integer from public.posts
      where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0077'),
    1,
    'AAL1 conserva la lectura de contenido público'
);

select throws_ok(
    $$insert into public.posts (
        id, user_id, title, content, category, carrera, author_alias
      ) values (
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0078',
        '77777777-7777-7777-7777-777777777777',
        'Escritura sin segundo factor',
        'No debe persistir',
        'general',
        'sistemas',
        'Usuario de prueba'
      )$$,
    '42501',
    null,
    'AAL1 no puede insertar filas'
);

select lives_ok(
    $$update public.posts
         set title = 'Modificado sin segundo factor'
       where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0077'$$,
    'La política RLS filtra la actualización AAL1 sin modificar la fila'
);

select is(
    (select title from public.posts
      where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0077'),
    'Post protegido por AAL2',
    'El intento de actualización AAL1 no cambia la fila'
);

select lives_ok(
    $$delete from public.posts
       where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0077'$$,
    'La política RLS filtra la eliminación AAL1 y conserva la fila'
);

select is(
    (select count(*)::integer from public.posts
      where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0077'),
    1,
    'El intento de eliminación AAL1 conserva la fila'
);

select throws_ok(
    $$select public.report_forum_post(
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0077'::uuid,
        'spam'
      )$$,
    '42501',
    null,
    'AAL1 tampoco puede escribir mediante un RPC SECURITY DEFINER'
);

select tests.authenticate_as(
    '77777777-7777-7777-7777-777777777777'
);

select lives_ok(
    $$insert into public.posts (
        id, user_id, title, content, category, carrera, author_alias
      ) values (
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0079',
        '77777777-7777-7777-7777-777777777777',
        'Escritura con segundo factor',
        'Debe persistir',
        'general',
        'sistemas',
        'Usuario de prueba'
      )$$,
    'AAL2 puede insertar filas'
);

select lives_ok(
    $$update public.posts
         set title = 'Actualizado con segundo factor'
       where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0079'$$,
    'AAL2 puede actualizar filas'
);

select lives_ok(
    $$delete from public.posts
       where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0079'$$,
    'AAL2 puede eliminar filas'
);

select * from finish();
rollback;
