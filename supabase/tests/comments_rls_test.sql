-- =============================================================================
-- PEMTREE / Comunidad USAC · pgTAP Test: Comments RLS & Visibilidad
-- =============================================================================
begin;

select plan(11);

create extension if not exists pgtap;

-- -----------------------------------------------------------------------------
-- Fixtures
-- -----------------------------------------------------------------------------
do $$
declare
    v_user_a uuid := '11111111-1111-1111-1111-111111111111';
    v_user_b uuid := '22222222-2222-2222-2222-222222222222';
    v_post_id uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0001';
begin
    perform tests.create_supabase_user(v_user_a, 'user_a@test.com');
    perform tests.create_supabase_user(v_user_b, 'user_b@test.com');

    -- Post contenedor
    insert into public.posts (
        id, user_id, title, content, category, carrera, author_alias, moderation_status
    ) values (
        v_post_id, v_user_a, 'Post para comentarios', 'Discusion principal', 'general', 'sistemas', 'Alias A', 0
    ) on conflict (id) do nothing;

    -- Comentarios con diferentes estados
    insert into public.comments (
        id, post_id, user_id, content, author_alias, moderation_status
    ) values
        ('cccccccc-cccc-cccc-cccc-cccccccc0001', v_post_id, v_user_a, 'Comentario Activo', 'Alias A', 0),
        ('cccccccc-cccc-cccc-cccc-cccccccc0002', v_post_id, v_user_a, 'Comentario En Revision', 'Alias A', 1),
        ('cccccccc-cccc-cccc-cccc-cccccccc0003', v_post_id, v_user_a, 'Comentario Censurado', 'Alias A', 2),
        ('cccccccc-cccc-cccc-cccc-cccccccc0004', v_post_id, v_user_b, 'Comentario de Usuario B', 'Alias B', 0)
    on conflict (id) do nothing;
end $$;

-- -----------------------------------------------------------------------------
-- Bloque 1: Anon
-- -----------------------------------------------------------------------------
select tests.authenticate_as_anon();

-- Test 1: anon lee comentarios no bloqueados
select is(
    (select count(*)::integer from public.comments
      where id in (
        'cccccccc-cccc-cccc-cccc-cccccccc0001',
        'cccccccc-cccc-cccc-cccc-cccccccc0002',
        'cccccccc-cccc-cccc-cccc-cccccccc0004'
      )),
    3,
    'Anon puede consultar comentarios cuyo moderation_status es distinto de 2'
);

-- Test 2: anon no puede ver comentario bloqueado
select is(
    (select count(*)::integer from public.comments where id = 'cccccccc-cccc-cccc-cccc-cccccccc0003'),
    0,
    'Anon no puede ver comentarios bloqueados (moderation_status = 2)'
);

-- Test 3: anon no puede insertar comentarios
select throws_ok(
    $$insert into public.comments (id, post_id, user_id, content, author_alias)
      values (
        gen_random_uuid(),
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0001',
        '11111111-1111-1111-1111-111111111111',
        'Intento Anonimo',
        'Anon'
      )$$,
    null,
    'Anon no tiene permisos para insertar comentarios'
);

-- -----------------------------------------------------------------------------
-- Bloque 2: Authenticated (Usuario A)
-- -----------------------------------------------------------------------------
select tests.authenticate_as('11111111-1111-1111-1111-111111111111');

-- Test 4: Usuario autenticado lee comentarios públicos
select is(
    (select count(*)::integer from public.comments
      where id in ('cccccccc-cccc-cccc-cccc-cccccccc0001', 'cccccccc-cccc-cccc-cccc-cccccccc0004')),
    2,
    'Usuario autenticado lee comentarios con moderation_status activo'
);

-- Test 5: Usuario autenticado no lee comentarios con moderation_status = 2
select is(
    (select count(*)::integer from public.comments where id = 'cccccccc-cccc-cccc-cccc-cccccccc0003'),
    0,
    'Usuario autenticado no puede consultar comentarios con moderation_status = 2'
);

-- Test 6: Usuario A puede insertar un comentario a su propio nombre
select lives_ok(
    $$insert into public.comments (
        id, post_id, user_id, content, author_alias
      ) values (
        'cccccccc-cccc-cccc-cccc-cccccccc0099',
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0001',
        '11111111-1111-1111-1111-111111111111',
        'Nuevo Comentario Propio',
        'Alias A'
      )$$,
    'Usuario autenticado puede insertar un comentario enlazado a su user_id'
);

-- Test 7: Usuario A no puede insertar un comentario suplantando a Usuario B
select throws_ok(
    $$insert into public.comments (
        id, post_id, user_id, content, author_alias
      ) values (
        'cccccccc-cccc-cccc-cccc-cccccccc0098',
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0001',
        '22222222-2222-2222-2222-222222222222',
        'Comentario Falso',
        'Fake B'
      )$$,
    null,
    'Usuario no puede crear comentarios a nombre de un user_id ajeno'
);

-- Test 8: Usuario A puede editar su propio comentario
select lives_ok(
    $$update public.comments
         set content = 'Comentario Editado por Autor'
       where id = 'cccccccc-cccc-cccc-cccc-cccccccc0001'$$,
    'Usuario autor puede editar el contenido de su comentario'
);

-- Test 9: Se verifica la edición del comentario propio
select is(
    (select content from public.comments where id = 'cccccccc-cccc-cccc-cccc-cccccccc0001'),
    'Comentario Editado por Autor',
    'El cambio en el comentario propio persiste exitosamente'
);

-- Test 10: Usuario A no puede modificar el comentario de Usuario B
do $$
begin
    update public.comments
       set content = 'Alterado por A'
     where id = 'cccccccc-cccc-cccc-cccc-cccccccc0004';
end $$;

select is(
    (select content from public.comments where id = 'cccccccc-cccc-cccc-cccc-cccccccc0004'),
    'Comentario de Usuario B',
    'Usuario A no tiene permiso RLS para alterar comentarios ajenos'
);

-- Test 11: Usuario A puede eliminar su propio comentario
select lives_ok(
    $$delete from public.comments where id = 'cccccccc-cccc-cccc-cccc-cccccccc0099'$$,
    'Usuario autor puede eliminar su propio comentario'
);

select * from finish();
rollback;
