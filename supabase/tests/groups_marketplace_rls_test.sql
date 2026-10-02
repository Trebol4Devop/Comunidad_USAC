-- =============================================================================
-- PEMTREE / Comunidad USAC · pgTAP Test: Groups & Marketplace RLS & Moderación
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
    v_user_mod uuid := '33333333-3333-3333-3333-333333333333';
begin
    perform tests.create_supabase_user(v_user_a, 'user_a@test.com');
    perform tests.create_supabase_user(v_user_b, 'user_b@test.com');
    perform tests.create_supabase_user(v_user_mod, 'mod@test.com');

    -- Grupos estudiantiles
    insert into public.student_groups (
        id, user_id, title, description, carrera, curso, section, link, moderation_status
    ) values
        ('11111111-0000-0000-0000-000000000001', v_user_a, 'Grupo Activo Mate', 'Grupo oficial de repaso', 'sistemas', 'Mate 1', 'A', 'https://chat.whatsapp.com/mate1', 0),
        ('11111111-0000-0000-0000-000000000002', v_user_a, 'Grupo Bloqueado Spam', 'Grupo con enlaces no autorizados', 'sistemas', 'Mate 2', 'B', 'https://chat.whatsapp.com/spam', 2)
    on conflict (id) do nothing;

    -- Marketplace items
    insert into public.marketplace_items (
        id, user_id, title, description, price, is_free, category, facultad, status, moderation_status, author_alias
    ) values
        ('22222222-0000-0000-0000-000000000001', v_user_a, 'Calculadora Casio fx-991', 'Buen estado', 150.0, false, 'otros_articulos', '08', 'available', 0, 'Vendedor A'),
        ('22222222-0000-0000-0000-000000000002', v_user_a, 'Articulo Prohibido', 'Copia no permitida', 50.0, false, 'otros_articulos', '08', 'available', 2, 'Vendedor A')
    on conflict (id) do nothing;
end $$;

-- -----------------------------------------------------------------------------
-- Bloque 1: Anon y visibilidad
-- -----------------------------------------------------------------------------
select tests.authenticate_as_anon();

-- Test 1: anon lee grupo activo
select is(
    (select count(*)::integer from public.student_groups where id = '11111111-0000-0000-0000-000000000001'),
    1,
    'Anon puede ver grupos estudiantiles activos (moderation_status < 2)'
);

-- Test 2: anon no puede ver grupo bloqueado
select is(
    (select count(*)::integer from public.student_groups where id = '11111111-0000-0000-0000-000000000002'),
    0,
    'Anon no puede ver grupos con moderation_status = 2'
);

-- Test 3: anon no puede insertar grupos
select throws_ok(
    $$insert into public.student_groups (
        id, user_id, title, description, carrera, curso, section, link
      ) values (
        gen_random_uuid(),
        '11111111-1111-1111-1111-111111111111',
        'Grupo Anon',
        'Desc',
        'sistemas',
        'Curso',
        'A',
        'https://chat.whatsapp.com/anon'
      )$$,
    null,
    'Anon no tiene permisos para crear grupos estudiantiles'
);

-- Test 4: Usuario autenticado puede insertar un grupo con su user_id
select tests.authenticate_as('11111111-1111-1111-1111-111111111111');
select lives_ok(
    $$insert into public.student_groups (
        id, user_id, title, description, carrera, curso, section, link, author_alias
      ) values (
        '11111111-0000-0000-0000-000000000099',
        '11111111-1111-1111-1111-111111111111',
        'Grupo IPC 2',
        'Estudio de laboratorio',
        'sistemas',
        'IPC 2',
        'Unica',
        'https://chat.whatsapp.com/ipc2',
        'Alias A'
      )$$,
    'Usuario autenticado puede registrar un nuevo grupo estudiantil'
);

-- -----------------------------------------------------------------------------
-- Bloque 2: Marketplace items
-- -----------------------------------------------------------------------------
select tests.authenticate_as_anon();

-- Test 5: anon lee marketplace activo
select is(
    (select count(*)::integer from public.marketplace_items where id = '22222222-0000-0000-0000-000000000001'),
    1,
    'Anon puede ver publicaciones de marketplace con moderation_status < 2'
);

-- Test 6: anon no ve marketplace bloqueado
select is(
    (select count(*)::integer from public.marketplace_items where id = '22222222-0000-0000-0000-000000000002'),
    0,
    'Anon no puede ver publicaciones de marketplace con moderation_status = 2'
);

-- Test 7: anon no puede insertar en marketplace
select throws_ok(
    $$insert into public.marketplace_items (
        id, user_id, title, description, price, category, facultad, author_alias
      ) values (
        gen_random_uuid(),
        '11111111-1111-1111-1111-111111111111',
        'Anon Item',
        'Desc',
        10.0,
        'otros_articulos',
        '08',
        'Anon'
      )$$,
    null,
    'Anon no puede publicar articulos en el marketplace'
);

-- Test 8: Usuario autenticado inserta en marketplace
select tests.authenticate_as('11111111-1111-1111-1111-111111111111');
select lives_ok(
    $$insert into public.marketplace_items (
        id, user_id, title, description, price, category, facultad, author_alias, status
      ) values (
        '22222222-0000-0000-0000-000000000099',
        '11111111-1111-1111-1111-111111111111',
        'Bata de Laboratorio Quimica',
        'Talla M, nueva',
        85.0,
        'otros_articulos',
        '06',
        'Alias A',
        'available'
      )$$,
    'Usuario autenticado puede publicar un nuevo articulo en marketplace'
);

-- -----------------------------------------------------------------------------
-- Bloque 3: Moderación por roles
-- -----------------------------------------------------------------------------
-- Test 9: Usuario regular (sin rol staff) no puede ejecutar moderate_marketplace_item
select tests.authenticate_as('22222222-2222-2222-2222-222222222222');
select is(
    (select public.moderate_marketplace_item(
        '22222222-0000-0000-0000-000000000001'::uuid,
        2,
        'inappropriate',
        0.9,
        'Intento de moderacion no autorizada'
    )),
    false,
    'Usuario regular sin rol de moderador recibe false al intentar moderar marketplace'
);

-- Test 10: Moderador ejecuta moderate_marketplace_item con éxito
select tests.authenticate_as_moderator('33333333-3333-3333-3333-333333333333');
select is(
    (select public.moderate_marketplace_item(
        '22222222-0000-0000-0000-000000000001'::uuid,
        2,
        'inappropriate',
        0.98,
        'Moderado por moderador certificado'
    )),
    true,
    'Moderador con rol en public.user_roles puede cambiar moderation_status vía RPC'
);

-- Test 11: Moderador puede ocultar contenido vía ocultar_contenido_moderado
select is(
    (select public.ocultar_contenido_moderado(
        'whatsapp_groups',
        '11111111-0000-0000-0000-000000000001'::uuid,
        'Grupo con enlace no valido reportado'
    )),
    true,
    'Moderador puede ocultar grupos estudiantiles con justificacion valida'
);

select * from finish();
rollback;
