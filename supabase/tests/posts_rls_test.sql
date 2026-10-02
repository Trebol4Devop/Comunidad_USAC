-- =============================================================================
-- PEMTREE / Comunidad USAC · pgTAP Test: Posts RLS & Visibilidad
-- =============================================================================
begin;

select plan(11);

-- -----------------------------------------------------------------------------
-- Fixtures
-- -----------------------------------------------------------------------------
create extension if not exists pgtap;

do $$
declare
    v_user_a uuid := '11111111-1111-1111-1111-111111111111';
    v_user_b uuid := '22222222-2222-2222-2222-222222222222';
begin
    perform tests.create_supabase_user(v_user_a, 'user_a@test.com');
    perform tests.create_supabase_user(v_user_b, 'user_b@test.com');

    -- Insertar publicaciones bajo superusuario/postgres
    insert into public.posts (
        id, user_id, title, content, category, carrera, author_alias, moderation_status
    ) values
        ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0001', v_user_a, 'Post Activo', 'Contenido normal', 'general', 'sistemas', 'Alias A', 0),
        ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0002', v_user_a, 'Post En Revision', 'En analisis', 'general', 'sistemas', 'Alias A', 1),
        ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0003', v_user_a, 'Post Bloqueado', 'Contenido censurado', 'general', 'sistemas', 'Alias A', 2),
        ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0004', v_user_a, 'Post Error', 'Falla de clasificador', 'general', 'sistemas', 'Alias A', 3),
        ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbb0001', v_user_b, 'Post de Usuario B', 'Contenido de B', 'general', 'sistemas', 'Alias B', 0)
    on conflict (id) do nothing;
end $$;

-- -----------------------------------------------------------------------------
-- Bloque 1: Pruebas con rol anon (visitante no autenticado)
-- -----------------------------------------------------------------------------
select tests.authenticate_as_anon();

-- Test 1: anon lee los posts permitidos (moderation_status != 2)
select is(
    (select count(*)::integer from public.posts
      where id in (
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0001',
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0002',
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0004',
        'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbb0001'
      )),
    4,
    'Anon puede leer publicaciones cuyo moderation_status es distinto de 2'
);

-- Test 2: anon NO puede ver posts bloqueados (moderation_status = 2)
select is(
    (select count(*)::integer from public.posts where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0003'),
    0,
    'Anon no puede ver publicaciones bloqueadas (moderation_status = 2)'
);

-- Test 3: anon no tiene permiso de INSERT en posts
select throws_ok(
    $$insert into public.posts (id, user_id, title, content, category, carrera, author_alias)
      values (gen_random_uuid(), '11111111-1111-1111-1111-111111111111', 'Anon Post', 'Content', 'general', 'sistemas', 'Anon')$$,
    null,
    'Anon no puede crear publicaciones'
);

-- -----------------------------------------------------------------------------
-- Bloque 2: Pruebas con rol authenticated (Usuario A)
-- -----------------------------------------------------------------------------
select tests.authenticate_as('11111111-1111-1111-1111-111111111111');

-- Test 4: Usuario A lee posts públicos activos
select is(
    (select count(*)::integer from public.posts
      where id in ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0001', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbb0001')),
    2,
    'Usuario autenticado lee publicaciones activas permitidas'
);

-- Test 5: Usuario A tampoco ve el post bloqueado (moderation_status = 2)
select is(
    (select count(*)::integer from public.posts where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0003'),
    0,
    'Usuario regular autenticado no puede ver publicaciones con moderation_status = 2'
);

-- Test 6: Usuario A puede insertar una publicación a su propio nombre
select lives_ok(
    $$insert into public.posts (
        id, user_id, title, content, category, carrera, author_alias
      ) values (
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0099',
        '11111111-1111-1111-1111-111111111111',
        'Nuevo Post Propio',
        'Contenido propio',
        'general',
        'sistemas',
        'Alias A'
      )$$,
    'Usuario autenticado puede insertar publicaciones asignadas a su propio user_id'
);

-- Test 7: Usuario A no puede insertar a nombre de otro usuario
select throws_ok(
    $$insert into public.posts (
        id, user_id, title, content, category, carrera, author_alias
      ) values (
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0098',
        '22222222-2222-2222-2222-222222222222',
        'Suplantacion de Autor',
        'Contenido ajeno',
        'general',
        'sistemas',
        'Fake Alias'
      )$$,
    null,
    'Usuario autenticado no puede crear una publicacion suplantando el user_id de otro usuario'
);

-- Test 8: Usuario A puede actualizar su propia publicación
select lives_ok(
    $$update public.posts
         set title = 'Titulo Modificado por Autor'
       where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0001'$$,
    'Usuario puede ejecutar UPDATE sobre su propia publicacion'
);

-- Test 9: Se confirma que el título de la publicación propia cambió
select is(
    (select title from public.posts where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0001'),
    'Titulo Modificado por Autor',
    'El cambio en el post propio es efectivo en base de datos'
);

-- Test 10: Usuario A no puede actualizar la publicación de Usuario B (RLS filtra la fila)
do $$
begin
    update public.posts
       set title = 'Hackeado por A'
     where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbb0001';
end $$;

select is(
    (select title from public.posts where id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbb0001'),
    'Post de Usuario B',
    'Usuario A no puede alterar el contenido ni titulo de publicaciones de Usuario B'
);

-- Test 11: Usuario A puede eliminar su propia publicación
select lives_ok(
    $$delete from public.posts where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0099'$$,
    'Usuario autenticado puede eliminar su propia publicacion'
);

select * from finish();
rollback;
