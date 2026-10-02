-- =============================================================================
-- PEMTREE / Comunidad USAC · pgTAP Test: RPCs de Moderación y Auto-moderación
-- =============================================================================
begin;

select plan(14);

create extension if not exists pgtap;

-- -----------------------------------------------------------------------------
-- Fixtures
-- -----------------------------------------------------------------------------
do $$
declare
    v_u1 uuid := '11111111-1111-1111-1111-111111111111';
    v_u2 uuid := '22222222-2222-2222-2222-222222222222';
    v_u3 uuid := '33333333-3333-3333-3333-333333333333';
    v_seller uuid := '44444444-4444-4444-4444-444444444444';
    v_mod uuid := '55555555-5555-5555-5555-555555555555';
begin
    perform tests.create_supabase_user(v_u1, 'u1@test.com');
    perform tests.create_supabase_user(v_u2, 'u2@test.com');
    perform tests.create_supabase_user(v_u3, 'u3@test.com');
    perform tests.create_supabase_user(v_seller, 'seller@test.com');
    perform tests.create_supabase_user(v_mod, 'mod@test.com');

    -- Publicación en marketplace que será reportada hasta el umbral
    insert into public.marketplace_items (
        id, user_id, title, description, price, category, facultad, reported_count, moderation_status, author_alias, status
    ) values (
        '50000000-0000-0000-0000-000000000001', v_seller, 'Libro de Fisica con plagio', 'Edicion no autorizada', 40.0, 'libros_materiales', '08', 0, 0, 'Vendedor Pirata', 'available'
    ) on conflict (id) do nothing;

    -- Post para pruebas de ocultar/restaurar
    insert into public.posts (
        id, user_id, title, content, category, carrera, author_alias, moderation_status
    ) values (
        '60000000-0000-0000-0000-000000000001', v_u1, 'Post para Moderacion Admin', 'Contenido sujeto a revision', 'general', 'sistemas', 'Autor Post', 0
    ) on conflict (id) do nothing;
end $$;

-- -----------------------------------------------------------------------------
-- Bloque 1: report_marketplace_item y umbral de auto-moderación (3 reportes)
-- -----------------------------------------------------------------------------
-- Test 1: Primer reporte por Usuario 1
select tests.authenticate_as('11111111-1111-1111-1111-111111111111');

select is(
    (select public.report_marketplace_item(
        '50000000-0000-0000-0000-000000000001'::uuid,
        'Material no permitido',
        '44444444-4444-4444-4444-444444444444'::uuid,
        'Vendedor Pirata'
    )),
    true,
    'report_marketplace_item registra exitosamente el primer reporte'
);

-- Test 2: reported_count es 1 y moderation_status sigue activo (0)
select is(
    (select reported_count from public.marketplace_items where id = '50000000-0000-0000-0000-000000000001'),
    1,
    'reported_count es 1 tras el primer reporte'
);

-- Test 3: Reporte duplicado por el mismo usuario no duplica
select tests.authenticate_as('11111111-1111-1111-1111-111111111111');
select public.report_marketplace_item(
    '50000000-0000-0000-0000-000000000001'::uuid,
    'Reporte repetido',
    '44444444-4444-4444-4444-444444444444'::uuid,
    'Vendedor Pirata'
);

select is(
    (select reported_count from public.marketplace_items where id = '50000000-0000-0000-0000-000000000001'),
    1,
    'report_marketplace_item es idempotente para el mismo reportero y no incrementa el contador'
);

-- Test 4: Segundo reporte por Usuario 2
select tests.authenticate_as('22222222-2222-2222-2222-222222222222');
select is(
    (select public.report_marketplace_item(
        '50000000-0000-0000-0000-000000000001'::uuid,
        'Copia no autorizada',
        '44444444-4444-4444-4444-444444444444'::uuid,
        'Vendedor Pirata'
    )),
    true,
    'Segundo reporte registrado correctamente'
);

-- Test 5: Tercer reporte por Usuario 3 (alcanza umbral >= 3)
select tests.authenticate_as('33333333-3333-3333-3333-333333333333');
select is(
    (select public.report_marketplace_item(
        '50000000-0000-0000-0000-000000000001'::uuid,
        'Infringe derechos de autor',
        '44444444-4444-4444-4444-444444444444'::uuid,
        'Vendedor Pirata'
    )),
    true,
    'Tercer reporte registrado correctamente'
);

-- Test 6: Umbral de auto-moderación cumplido: moderation_status se actualizó a 2
-- (se lee como el dueño: la política RLS solo deja ver estado 2 a dueño/staff)
select tests.authenticate_as('44444444-4444-4444-4444-444444444444');
select is(
    (select moderation_status from public.marketplace_items where id = '50000000-0000-0000-0000-000000000001'),
    2,
    'Auto-moderacion disparada: al alcanzar 3 reportes, moderation_status cambia automaticamente a 2 (oculto)'
);

-- -----------------------------------------------------------------------------
-- Bloque 2: moderate_marketplace_item (Staff vs Usuario regular)
-- -----------------------------------------------------------------------------
-- Test 7: Usuario regular intenta restaurar/moderar -> recibe false
select tests.authenticate_as('11111111-1111-1111-1111-111111111111');
select is(
    (select public.moderate_marketplace_item(
        '50000000-0000-0000-0000-000000000001'::uuid,
        0,
        'appropriate',
        1.0,
        'Intento de reactivacion no autorizada'
    )),
    false,
    'Usuario sin rol de moderador recibe false al invocar moderate_marketplace_item'
);

-- Test 8: El estado se mantuvo en 2
-- (nuevamente como dueño, para poder observar el estado 2 bajo RLS)
select tests.authenticate_as('44444444-4444-4444-4444-444444444444');
select is(
    (select moderation_status from public.marketplace_items where id = '50000000-0000-0000-0000-000000000001'),
    2,
    'El estado del item no se modifica por llamadas no autorizadas'
);

-- Test 9: Moderador autenticado aprueba y reactiva el item (new_status = 1: en revisión / aprobado)
select tests.authenticate_as_moderator('55555555-5555-5555-5555-555555555555');
select is(
    (select public.moderate_marketplace_item(
        '50000000-0000-0000-0000-000000000001'::uuid,
        1,
        'appropriate',
        0.99,
        'Revision manual: articulo conforme a las normas'
    )),
    true,
    'Moderador oficial puede actualizar moderation_status vía moderate_marketplace_item'
);

-- Test 10: Se confirman columnas de moderación actualizadas
select is(
    (select moderation_status from public.marketplace_items where id = '50000000-0000-0000-0000-000000000001'),
    1,
    'moderation_status se actualizo a 1'
);

-- Test 11: Se confirma auditoría en moderation_audit_log
-- (lectura admin-only: se autentica un admin para poder consultarla)
select tests.authenticate_as_admin('66666666-6666-6666-6666-666666666666');
select is(
    (select count(*)::integer from public.moderation_audit_log
      where entity_table = 'marketplace_items'
        and entity_id = '50000000-0000-0000-0000-000000000001'
        and moderator_id = '55555555-5555-5555-5555-555555555555'),
    1,
    'La accion de moderacion quedo registrada en public.moderation_audit_log'
);

-- -----------------------------------------------------------------------------
-- Bloque 3: ocultar_contenido_moderado y restaurar_contenido_moderado
-- -----------------------------------------------------------------------------
-- Test 12: Moderador oculta un post vía ocultar_contenido_moderado
select tests.authenticate_as_moderator('55555555-5555-5555-5555-555555555555');
select is(
    (select public.ocultar_contenido_moderado(
        'posts',
        '60000000-0000-0000-0000-000000000001'::uuid,
        'Contenido inapropiado detectado'
    )),
    true,
    'Moderador puede ocultar publicaciones con justificacion valida'
);

-- Test 13: Usuario regular intenta restaurar -> lanza excepción de permiso denegado
select tests.authenticate_as('11111111-1111-1111-1111-111111111111');
select throws_ok(
    $$select public.restaurar_contenido_moderado('posts', '60000000-0000-0000-0000-000000000001'::uuid)$$,
    null,
    'Usuario regular no puede restaurar contenido oculto'
);

-- Test 14: Moderador restaura la publicación
select tests.authenticate_as_moderator('55555555-5555-5555-5555-555555555555');
select is(
    (select public.restaurar_contenido_moderado('posts', '60000000-0000-0000-0000-000000000001'::uuid)),
    true,
    'Moderador autorizado puede restaurar publicaciones ocultas'
);

select * from finish();
rollback;
