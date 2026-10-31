-- =============================================================================
-- pgTAP: las escrituras autenticadas requieren assurance level AAL2
-- =============================================================================
begin;

select plan(7);

create extension if not exists pgtap;

do $$
declare
    v_user uuid := '77777777-7777-7777-7777-777777777777';
begin
    perform tests.create_supabase_user(v_user, 'authenticated_user@test.com');
    insert into public.posts (
        id, user_id, title, content, category, carrera, author_alias, moderation_status
    ) values (
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0077',
        v_user,
        'Post previo',
        'Contenido de prueba',
        'general',
        'sistemas',
        'Usuario de prueba',
        0
    );
end;
$$;

select tests.authenticate_as_aal1(
    '77777777-7777-7777-7777-777777777777'
);

select throws_ok(
    $$insert into public.posts (
        id, user_id, title, content, category, carrera, author_alias, moderation_status
      ) values (
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0078',
        '77777777-7777-7777-7777-777777777777',
        'Post AAL1', 'Contenido', 'general', 'sistemas', 'Usuario', 0
      )$$,
    '42501',
    'AAL1 no puede crear publicaciones'
);

select lives_ok(
    $$update public.posts
         set title = 'Cambio AAL1'
       where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0077'$$,
    'La consulta de actualización AAL1 termina sin elevar privilegios'
);

select is(
    (select title from public.posts
      where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0077'),
    'Post previo',
    'La política impide que AAL1 modifique la fila'
);

select throws_ok(
    $$select public.report_forum_post(
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0077'::uuid,
        'spam'
      )$$,
    '42501',
    'AAL1 no puede reportar mediante SECURITY DEFINER'
);

select lives_ok(
    $$delete from public.posts
       where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0077'$$,
    'La consulta de eliminación AAL1 termina sin elevar privilegios'
);

select is(
    (select count(*)::integer from public.posts
      where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0077'),
    1,
    'La política impide que AAL1 elimine la fila'
);

select tests.authenticate_as(
    '77777777-7777-7777-7777-777777777777'
);

select lives_ok(
    $$insert into public.posts (
        id, user_id, title, content, category, carrera, author_alias, moderation_status
      ) values (
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0079',
        '77777777-7777-7777-7777-777777777777',
        'Post AAL2', 'Contenido', 'general', 'sistemas', 'Usuario', 0
      )$$,
    'AAL2 puede crear publicaciones'
);

select * from finish();
rollback;
