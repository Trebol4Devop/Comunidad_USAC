-- =============================================================================
-- PEMTREE / Comunidad USAC · pgTAP Test: Vistas Públicas v_public_posts y v_public_comments
-- =============================================================================
begin;

select plan(14);

create extension if not exists pgtap;

-- -----------------------------------------------------------------------------
-- Fixtures
-- -----------------------------------------------------------------------------
do $$
declare
    v_user_a uuid := '11111111-1111-1111-1111-111111111111';
    v_user_b uuid := '22222222-2222-2222-2222-222222222222';
    v_hash_a text;
    v_hash_b text;
    v_post_id uuid := '80000000-0000-0000-0000-000000000001';
    v_post_blocked uuid := '80000000-0000-0000-0000-000000000002';
begin
    perform tests.create_supabase_user(v_user_a, 'user_a@test.com');
    perform tests.create_supabase_user(v_user_b, 'user_b@test.com');

    v_hash_a := public.generate_author_hash(v_user_a);
    v_hash_b := public.generate_author_hash(v_user_b);

    -- Post activo de Usuario A
    insert into public.posts (
        id, user_id, title, content, category, carrera, author_alias, author_hash, moderation_status
    ) values (
        v_post_id, v_user_a, 'Post de Discusion Hash', 'Contenido visible', 'general', 'sistemas', 'Alias A', v_hash_a, 0
    ) on conflict (id) do nothing;

    -- Post bloqueado (moderation_status = 2)
    insert into public.posts (
        id, user_id, title, content, category, carrera, author_alias, author_hash, moderation_status
    ) values (
        v_post_blocked, v_user_a, 'Post Bloqueado Oculto', 'Censurado', 'general', 'sistemas', 'Alias A', v_hash_a, 2
    ) on conflict (id) do nothing;

    -- Comentarios asociados al Post activo
    -- C1: Creado por Usuario A (mismo autor del post)
    insert into public.comments (
        id, post_id, user_id, content, author_alias, author_hash, moderation_status
    ) values (
        '90000000-0000-0000-0000-000000000001', v_post_id, v_user_a, 'Respuesta del autor original', 'Alias A', v_hash_a, 0
    ) on conflict (id) do nothing;

    -- C2: Creado por Usuario B (otro usuario)
    insert into public.comments (
        id, post_id, user_id, content, author_alias, author_hash, moderation_status
    ) values (
        '90000000-0000-0000-0000-000000000002', v_post_id, v_user_b, 'Aporte de companero B', 'Alias B', v_hash_b, 0
    ) on conflict (id) do nothing;

    -- C3: Creado por Usuario B pero bloqueado (moderation_status = 2)
    insert into public.comments (
        id, post_id, user_id, content, author_alias, author_hash, moderation_status
    ) values (
        '90000000-0000-0000-0000-000000000003', v_post_id, v_user_b, 'Comentario con spam bloqueado', 'Alias B', v_hash_b, 2
    ) on conflict (id) do nothing;
end $$;

-- -----------------------------------------------------------------------------
-- Bloque 1: Perspectiva de Usuario A (autor del post y comentario 1)
-- -----------------------------------------------------------------------------
select tests.authenticate_as('11111111-1111-1111-1111-111111111111');

-- Test 1: comment_count excluye comentarios bloqueados (cuenta 2, excluye C3)
select is(
    (select comment_count from public.v_public_posts where id = '80000000-0000-0000-0000-000000000001'),
    2,
    'v_public_posts calcula comment_count ignorando comentarios con moderation_status = 2'
);

-- Test 2: is_my_post es true para el autor del post
select is(
    (select is_my_post from public.v_public_posts where id = '80000000-0000-0000-0000-000000000001'),
    true,
    'v_public_posts marca is_my_post = true cuando el author_hash coincide con la sesion del autor'
);

-- Test 3: post con moderation_status = 2 queda excluido de la vista
select is(
    (select count(*)::integer from public.v_public_posts where id = '80000000-0000-0000-0000-000000000002'),
    0,
    'v_public_posts filtra posts con moderation_status = 2'
);

-- Test 4: is_post_author es true para C1 (mismo hash que el post)
select is(
    (select is_post_author from public.v_public_comments where id = '90000000-0000-0000-0000-000000000001'),
    true,
    'v_public_comments marca is_post_author = true cuando author_hash del comentario coincide con el post'
);

-- Test 5: is_my_comment es true para C1 desde la sesión de Usuario A
select is(
    (select is_my_comment from public.v_public_comments where id = '90000000-0000-0000-0000-000000000001'),
    true,
    'v_public_comments marca is_my_comment = true para comentarios propios de Usuario A'
);

-- Test 6: is_post_author es false para C2 (hash de Usuario B)
select is(
    (select is_post_author from public.v_public_comments where id = '90000000-0000-0000-0000-000000000002'),
    false,
    'v_public_comments marca is_post_author = false cuando el comentario es de otro usuario'
);

-- Test 7: is_my_comment es false para C2 desde la sesión de Usuario A
select is(
    (select is_my_comment from public.v_public_comments where id = '90000000-0000-0000-0000-000000000002'),
    false,
    'v_public_comments marca is_my_comment = false para comentarios ajenos'
);

-- Test 8: C3 (bloqueado) queda excluido de v_public_comments
select is(
    (select count(*)::integer from public.v_public_comments where id = '90000000-0000-0000-0000-000000000003'),
    0,
    'v_public_comments excluye comentarios con moderation_status = 2'
);

-- -----------------------------------------------------------------------------
-- Bloque 2: Perspectiva de Usuario B
-- -----------------------------------------------------------------------------
select tests.authenticate_as('22222222-2222-2222-2222-222222222222');

-- Test 9: is_my_post es false para Usuario B sobre el post de Usuario A
select is(
    (select is_my_post from public.v_public_posts where id = '80000000-0000-0000-0000-000000000001'),
    false,
    'v_public_posts marca is_my_post = false para usuarios que no crearon el post'
);

-- Test 10: is_my_comment es true para C2 desde la sesión de Usuario B
select is(
    (select is_my_comment from public.v_public_comments where id = '90000000-0000-0000-0000-000000000002'),
    true,
    'v_public_comments marca is_my_comment = true para el autor del comentario C2'
);

-- Test 11: is_my_comment es false para C1 desde la sesión de Usuario B
select is(
    (select is_my_comment from public.v_public_comments where id = '90000000-0000-0000-0000-000000000001'),
    false,
    'v_public_comments marca is_my_comment = false para C1 visto por Usuario B'
);

-- -----------------------------------------------------------------------------
-- Bloque 3: Perspectiva anon (visitante público)
-- -----------------------------------------------------------------------------
select tests.authenticate_as_anon();

-- Test 12: is_my_post es siempre false para anon
select is(
    (select is_my_post from public.v_public_posts where id = '80000000-0000-0000-0000-000000000001'),
    false,
    'v_public_posts devuelve is_my_post = false para anon sin romper la consulta'
);

-- Test 13: comment_count es visible y correcto para anon
select is(
    (select comment_count from public.v_public_posts where id = '80000000-0000-0000-0000-000000000001'),
    2,
    'v_public_posts calcula comment_count de forma consistente para visitantes publicos'
);

-- Test 14: is_my_comment es siempre false para anon
select is(
    (select is_my_comment from public.v_public_comments where id = '90000000-0000-0000-0000-000000000001'),
    false,
    'v_public_comments devuelve is_my_comment = false para sesiones anonimas'
);

select * from finish();
rollback;
