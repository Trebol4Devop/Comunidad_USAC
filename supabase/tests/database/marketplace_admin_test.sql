-- =============================================================================
-- PEMTREE / Comunidad USAC · pgTAP Test: Backend administrativo del Marketplace
-- Archivo: supabase/tests/database/marketplace_admin_test.sql
-- Migración objetivo: 20261113130000_marketplace_admin_backend.sql
--
-- Cobertura:
--   * Helper de staff y RPCs SECURITY DEFINER (admin / moderador / no-staff / anon).
--   * Planes: alta, edición, activación y protección del plan free.
--   * Vendedores: cambio de plan/verificación, sincronización y auditoría.
--   * Publicaciones: estado comercial, patrocinio y retención legal.
--   * Analítica diaria y bitácora con RLS.
--   * Solicitudes de patrocinio: grants por columna y guard de workflow.
--
-- Fixtures con prefijo 53... para no colisionar con otras suites.
-- =============================================================================
begin;

select plan(54);

create extension if not exists pgtap;

-- Asegurar rol privilegiado inicial y limpiar claims residuales.
reset role;
set role postgres;
select set_config('request.jwt.claims', '', true);
select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claim.role', '', true);
select set_config('request.jwt.claim.email', '', true);

-- -----------------------------------------------------------------------------
-- Fixtures
-- -----------------------------------------------------------------------------
do $$
begin
    perform tests.create_supabase_user('53000000-0000-0000-0000-000000000001', 'u01_mktadm@test.com');
    perform tests.create_supabase_user('53000000-0000-0000-0000-000000000002', 'u02_mktadm@test.com');
    perform tests.create_supabase_user('53000000-0000-0000-0000-000000000003', 'u03_mktadm@test.com');
    perform tests.create_supabase_user('53000000-0000-0000-0000-000000000004', 'u04_mktadm@test.com');
    perform tests.create_supabase_user('53000000-0000-0000-0000-000000000005', 'u05_mktadm@test.com');
    perform tests.create_supabase_user('53000000-0000-0000-0000-000000000006', 'u06_mktadm@test.com');
    perform tests.create_supabase_user('53000000-0000-0000-0000-000000000007', 'u07_mktadm@test.com');
    perform tests.create_supabase_user('53000000-0000-0000-0000-000000000008', 'u08_mktadm@test.com');

    insert into public.profiles (id, full_name, carrera, is_verified)
    values
        ('53000000-0000-0000-0000-000000000003', 'Vendedor Cincuenta y Tres', 'sistemas', true),
        ('53000000-0000-0000-0000-000000000004', 'Usuario Sin Rol Cincuenta y Tres', 'sistemas', true),
        ('53000000-0000-0000-0000-000000000005', 'Solicitante Patrocinio Cincuenta y Tres', 'sistemas', true),
        ('53000000-0000-0000-0000-000000000006', 'Vendedor Free Vencido', 'sistemas', true),
        ('53000000-0000-0000-0000-000000000007', 'Vendedor a Suspender', 'sistemas', true),
        ('53000000-0000-0000-0000-000000000008', 'Estudiante Sin Carne', 'sistemas', false)
    on conflict (id) do update set
        full_name = excluded.full_name,
        carrera = excluded.carrera,
        is_verified = excluded.is_verified;

    insert into public.seller_profiles (user_id, plan_id, seller_type, verification_status, business_name)
    values
        ('53000000-0000-0000-0000-000000000003', 'free', 'student', 'pending', 'Tienda Cincuenta y Tres'),
        ('53000000-0000-0000-0000-000000000006', 'free', 'student', 'approved', 'Tienda Free Vencida'),
        ('53000000-0000-0000-0000-000000000007', 'free', 'student', 'pending', 'Tienda Suspendible')
    on conflict (user_id) do update set
        plan_id = excluded.plan_id,
        seller_type = excluded.seller_type,
        verification_status = excluded.verification_status,
        business_name = excluded.business_name;

    insert into public.marketplace_items (
        id, user_id, title, description, price, is_free, category, facultad, sede,
        contact_whatsapp, author_alias, status
    ) values (
        '53000000-0000-0000-0000-000000000101',
        '53000000-0000-0000-0000-000000000003',
        'Item Admin Uno',
        'Publicacion de prueba para el panel administrativo del marketplace',
        45.00, false, 'libros_materiales', 'todas', 'central',
        '50255550001', 'Estudiante Anónimo', 'available'
    ) on conflict (id) do nothing;

    insert into public.marketplace_items (
        id, user_id, title, description, price, is_free, category, facultad, sede,
        contact_whatsapp, author_alias, status, is_legal_hold
    ) values (
        '53000000-0000-0000-0000-000000000102',
        '53000000-0000-0000-0000-000000000003',
        'Item Admin Legal Hold',
        'Publicacion de prueba bajo retencion legal para el panel administrativo',
        50.00, false, 'libros_materiales', 'todas', 'central',
        '50255550002', 'Estudiante Anónimo', 'available', true
    ) on conflict (id) do nothing;

    -- B1: ítem free pausado y vencido que el panel debe poder reactivar.
    insert into public.marketplace_items (
        id, user_id, title, description, price, is_free, category, facultad, sede,
        contact_whatsapp, author_alias, status, expires_at
    ) values (
        '53000000-0000-0000-0000-000000000104',
        '53000000-0000-0000-0000-000000000006',
        'Item Free Vencido Pausado',
        'Publicacion free pausada y vencida para reactivar desde el panel',
        10.00, false, 'libros_materiales', 'todas', 'central',
        '50255550104', 'Estudiante Anónimo', 'paused', now() - interval '1 day'
    ) on conflict (id) do nothing;

    -- B2: vendedor con dos publicaciones activas y una bajo retención legal.
    insert into public.marketplace_items (
        id, user_id, title, description, price, is_free, category, facultad, sede,
        contact_whatsapp, author_alias, status, is_legal_hold
    ) values
        (
            '53000000-0000-0000-0000-000000000111',
            '53000000-0000-0000-0000-000000000007',
            'Item Suspendible Uno',
            'Primera publicacion activa del vendedor que sera suspendido',
            10.00, false, 'libros_materiales', 'todas', 'central',
            '50255550111', 'Estudiante Anónimo', 'available', false
        ),
        (
            '53000000-0000-0000-0000-000000000112',
            '53000000-0000-0000-0000-000000000007',
            'Item Suspendible Dos',
            'Segunda publicacion activa del vendedor que sera suspendido',
            20.00, false, 'libros_materiales', 'todas', 'central',
            '50255550112', 'Estudiante Anónimo', 'available', false
        ),
        (
            '53000000-0000-0000-0000-000000000113',
            '53000000-0000-0000-0000-000000000007',
            'Item Suspendible Legal Hold',
            'Publicacion activa con retencion legal que no debe pausarse',
            30.00, false, 'libros_materiales', 'todas', 'central',
            '50255550113', 'Estudiante Anónimo', 'available', true
        )
    on conflict (id) do nothing;

    -- Telemetría y guardados para la analítica del panel.
    insert into public.marketplace_item_events (item_id, viewer_id, event_type, created_at)
    values
        ('53000000-0000-0000-0000-000000000101', '53000000-0000-0000-0000-000000000004', 'view', now() - interval '1 day'),
        ('53000000-0000-0000-0000-000000000101', '53000000-0000-0000-0000-000000000004', 'click_whatsapp', now() - interval '1 day'),
        ('53000000-0000-0000-0000-000000000101', '53000000-0000-0000-0000-000000000004', 'share', now() - interval '1 day')
    on conflict do nothing;

    insert into public.marketplace_bookmarks (item_id, user_id, created_at)
    values ('53000000-0000-0000-0000-000000000101', '53000000-0000-0000-0000-000000000004', now() - interval '1 day')
    on conflict do nothing;

    insert into public.sponsor_requests (
        id, brand_name, contact_name, contact_phone, email, proposal_details,
        user_id, plan_id, status
    ) values (
        '53000000-0000-0000-0000-000000000901',
        'Marca Cincuenta y Tres',
        'Contacto Cincuenta y Tres',
        '50255550901',
        'marca53@test.com',
        'Propuesta de patrocinio para validar el flujo administrativo',
        '53000000-0000-0000-0000-000000000005',
        'pro_student',
        'pending'
    ) on conflict (id) do nothing;

    -- W11: solicitud destinada a borrado administrativo.
    insert into public.sponsor_requests (
        id, brand_name, contact_name, contact_phone, email, proposal_details,
        user_id, plan_id, status
    ) values (
        '53000000-0000-0000-0000-000000000902',
        'Marca Borrable',
        'Contacto Borrable',
        '50255550902',
        'borrable53@test.com',
        'Solicitud para validar el borrado administrativo auditado',
        '53000000-0000-0000-0000-000000000005',
        'pro_student',
        'rejected'
    ) on conflict (id) do nothing;
end $$;

-- =============================================================================
-- 1) Control de acceso a la vista general
-- =============================================================================

select tests.authenticate_as_anon();

select throws_ok(
    $$select public.admin_marketplace_overview()$$,
    '42501',
    null,
    '1. anon no puede invocar admin_marketplace_overview (42501)'
);

select tests.authenticate_as('53000000-0000-0000-0000-000000000004');

select throws_ok(
    $$select public.admin_marketplace_overview()$$,
    '42501',
    null,
    '2. usuario autenticado sin rol de staff no puede invocar admin_marketplace_overview (42501)'
);

select tests.authenticate_as_admin('53000000-0000-0000-0000-000000000001');

select ok(
    (select (v ? 'items') and (v ? 'sellers') and (v ? 'plans')
            and (v ? 'sponsor_requests') and (v ? 'engagement')
     from (select public.admin_marketplace_overview() as v) s),
    '3. admin obtiene el overview con las secciones items/sellers/plans/sponsor_requests/engagement'
);

select ok(
    (select (v -> 'items' ? 'total') and (v -> 'items' ? 'expired') and (v -> 'items' ? 'hidden')
            and (v -> 'items' ? 'in_review') and (v -> 'items' ? 'sponsored') and (v -> 'items' ? 'legal_hold')
     from (select public.admin_marketplace_overview() as v) s),
    '4. overview.items incluye total, expired, hidden, in_review, sponsored y legal_hold'
);

-- =============================================================================
-- 2) Listados accesibles a moderadores
-- =============================================================================

select tests.authenticate_as_moderator('53000000-0000-0000-0000-000000000002');

select ok(
    (select count(*) from public.admin_list_marketplace_items()) > 0,
    '5. moderador puede listar publicaciones del Marketplace'
);

select ok(
    (select count(*) from public.admin_list_marketplace_sellers()) > 0,
    '6. moderador puede listar vendedores del Marketplace'
);

-- =============================================================================
-- 3) Planes: solo administrador
-- =============================================================================

select tests.authenticate_as('53000000-0000-0000-0000-000000000004');

select throws_ok(
    $$select public.admin_upsert_marketplace_plan('{"id":"test_mkt53","name":"Plan de Prueba"}'::jsonb)$$,
    '42501',
    null,
    '7. usuario sin rol no puede crear planes (42501)'
);

select tests.authenticate_as_moderator('53000000-0000-0000-0000-000000000002');

select throws_ok(
    $$select public.admin_upsert_marketplace_plan('{"id":"test_mkt53","name":"Plan de Prueba"}'::jsonb)$$,
    '42501',
    null,
    '8. moderador no puede crear planes: la gestión de planes es exclusiva del administrador (42501)'
);

select tests.authenticate_as_admin('53000000-0000-0000-0000-000000000001');

select lives_ok(
    $$select public.admin_upsert_marketplace_plan(
        '{"id":"test_mkt53","name":"Plan de Prueba","price_monthly":15.5,
          "max_active_items":5,"max_images_per_item":4,"allow_video":true,
          "features":["uno","dos"],"sort_order":99,"is_active":true}'::jsonb
    )$$,
    '9. admin crea un plan de prueba correctamente'
);

select is(
    (select is_active from public.marketplace_plans where id = 'test_mkt53'),
    true,
    '10. el plan creado queda activo'
);

select lives_ok(
    $$select public.admin_upsert_marketplace_plan(
        '{"id":"test_mkt53","name":"Plan de Prueba Editado","price_monthly":20}'::jsonb
    )$$,
    '11. admin actualiza un plan existente'
);

select is(
    (select name from public.marketplace_plans where id = 'test_mkt53'),
    'Plan de Prueba Editado',
    '12. la actualización del plan persiste el nuevo nombre'
);

select is(
    (select (public.admin_set_marketplace_plan_active('test_mkt53', false)) ->> 'is_active'),
    'false',
    '13. admin desactiva el plan de prueba'
);

select throws_ok(
    $$select public.admin_set_marketplace_plan_active('free', false)$$,
    '23514',
    null,
    '14. no se puede desactivar el plan free (23514)'
);

-- =============================================================================
-- 4) Vendedores: plan, verificación, auditoría y sincronización
-- =============================================================================

select lives_ok(
    $$select public.admin_update_marketplace_seller(
        '53000000-0000-0000-0000-000000000003',
        'pro_student',
        'student',
        'approved',
        now() + interval '30 days',
        'Tienda Cincuenta y Tres',
        'Aprobación QA del plan Emprendedor'
    )$$,
    '15. admin actualiza plan y verificación de un vendedor'
);

-- Verificación directa en contexto privilegiado (seller_profiles no expone
-- la columna user_id al rol authenticated).
reset role;
set role postgres;
select set_config('request.jwt.claims', '', true);
select set_config('request.jwt.claim.sub', '', true);

select results_eq(
    $$select plan_id, verification_status
      from public.seller_profiles
      where user_id = '53000000-0000-0000-0000-000000000003'$$,
    $$values ('pro_student'::text, 'approved'::text)$$,
    '16. seller_profiles refleja el nuevo plan y estado de verificación'
);

select ok(
    exists (
        select 1
        from public.marketplace_admin_audit a
        where a.action = 'seller.update'
          and a.target_type = 'seller'
          and a.target_id = '53000000-0000-0000-0000-000000000003'
          and a.actor_id = '53000000-0000-0000-0000-000000000001'
    ),
    '17. se registra una fila de auditoría seller.update con el actor correcto'
);

select is(
    (select seller_verification_status
     from public.profiles
     where id = '53000000-0000-0000-0000-000000000003'),
    'verified',
    '18. profiles.seller_verification_status se sincroniza a verified'
);

select tests.authenticate_as('53000000-0000-0000-0000-000000000004');
select throws_ok(
    $$select public.admin_update_marketplace_seller(
        '53000000-0000-0000-0000-000000000003',
        'pro_student',
        'student',
        'approved'
    )$$,
    '42501',
    null,
    '19. usuario sin rol no puede actualizar vendedores (42501)'
);

-- =============================================================================
-- 5) Publicaciones: estado comercial, patrocinio y retención legal
-- =============================================================================

select tests.authenticate_as_admin('53000000-0000-0000-0000-000000000001');

select lives_ok(
    $$select public.admin_set_marketplace_item_state(
        '53000000-0000-0000-0000-000000000101',
        'paused',
        true,
        'Destacado QA',
        'Pausa administrativa QA'
    )$$,
    '20. admin cambia el estado comercial y el patrocinio de una publicación'
);

select is(
    (select status from public.marketplace_items where id = '53000000-0000-0000-0000-000000000101'),
    'paused',
    '21. el estado de la publicación queda en paused'
);

select throws_ok(
    $$select public.admin_set_marketplace_item_state(
        '53000000-0000-0000-0000-000000000102',
        'available'
    )$$,
    '23514',
    null,
    '22. una publicación con retención legal no puede modificarse (23514)'
);

-- =============================================================================
-- 6) Analítica diaria
-- =============================================================================

select is(
    (select count(*) from public.admin_get_marketplace_engagement(7)),
    7::bigint,
    '23. admin_get_marketplace_engagement(7) devuelve 7 filas para staff'
);

-- =============================================================================
-- 7) Solicitudes de patrocinio: guard de workflow y grants por columna
-- =============================================================================

select tests.authenticate_as_moderator('53000000-0000-0000-0000-000000000002');

select throws_ok(
    $$update public.sponsor_requests
         set status = 'approved'
       where id = '53000000-0000-0000-0000-000000000901'$$,
    '42501',
    null,
    '24. un moderador (no admin) no puede cambiar el status de una solicitud de patrocinio (42501)'
);

select tests.authenticate_as_admin('53000000-0000-0000-0000-000000000001');

select lives_ok(
    $$update public.sponsor_requests
         set status = 'approved',
             reviewed_at = now(),
             reviewed_by = '53000000-0000-0000-0000-000000000001'
       where id = '53000000-0000-0000-0000-000000000901'$$,
    '25. el administrador sí puede aprobar la solicitud de patrocinio'
);

select ok(
    has_column_privilege('authenticated', 'public.sponsor_requests', 'brand_name', 'UPDATE'),
    '26. authenticated conserva el grant UPDATE por columna para editar la solicitud'
);

select ok(
    not has_table_privilege('anon', 'public.sponsor_requests', 'UPDATE')
    and not has_table_privilege('anon', 'public.sponsor_requests', 'INSERT'),
    '27. anon sigue sin INSERT/UPDATE sobre sponsor_requests'
);

-- =============================================================================
-- 8) RLS de la bitácora de auditoría
-- =============================================================================

select tests.authenticate_as('53000000-0000-0000-0000-000000000004');

select is(
    (select count(*) from public.marketplace_admin_audit),
    0::bigint,
    '28. un usuario sin rol no ve filas de marketplace_admin_audit (RLS)'
);

select tests.authenticate_as_admin('53000000-0000-0000-0000-000000000001');

select ok(
    (select count(*) from public.marketplace_admin_audit) > 0,
    '29. el staff sí ve las filas de auditoría del Marketplace'
);

-- =============================================================================
-- 9) B1: reactivación de una publicación free vencida
-- =============================================================================

select lives_ok(
    $$select public.admin_set_marketplace_item_state(
        '53000000-0000-0000-0000-000000000104',
        'available',
        null,
        null,
        'Reactivación QA de publicación free vencida'
    )$$,
    '30. admin reactiva una publicación free pausada y vencida'
);

reset role;
set role postgres;
select set_config('request.jwt.claims', '', true);
select set_config('request.jwt.claim.sub', '', true);

select is(
    (select status from public.marketplace_items where id = '53000000-0000-0000-0000-000000000104'),
    'available',
    '31. la publicación reactivada queda en estado available'
);

select is(
    (select expires_at > now() + interval '13 days'
     from public.marketplace_items
     where id = '53000000-0000-0000-0000-000000000104'),
    true,
    '32. la reactivación free refresca expires_at a ~14 días'
);

select tests.authenticate_as_anon();

select ok(
    exists (
        select 1 from public.get_marketplace_feed()
        where id = '53000000-0000-0000-0000-000000000104'
    ),
    '33. la publicación reactivada vuelve a aparecer en get_marketplace_feed()'
);

reset role;
set role postgres;
select set_config('request.jwt.claims', '', true);
select set_config('request.jwt.claim.sub', '', true);

select ok(
    not exists (
        select 1 from public.marketplace_items
        where id = '53000000-0000-0000-0000-000000000104'
          and expires_at <= now()
          and status in ('available', 'reserved')
    ),
    '34. la publicación reactivada deja de contar como expired'
);

-- =============================================================================
-- 10) B2: suspender un vendedor lo retira del catálogo
-- =============================================================================

select tests.authenticate_as_admin('53000000-0000-0000-0000-000000000001');

select lives_ok(
    $$select public.admin_update_marketplace_seller(
        '53000000-0000-0000-0000-000000000007',
        'free',
        'student',
        'suspended',
        null,
        null,
        'Suspensión QA del vendedor'
    )$$,
    '35. admin suspende a un vendedor del Marketplace'
);

reset role;
set role postgres;
select set_config('request.jwt.claims', '', true);
select set_config('request.jwt.claim.sub', '', true);

select is(
    (select count(*) from public.marketplace_items
     where user_id = '53000000-0000-0000-0000-000000000007'
       and id in ('53000000-0000-0000-0000-000000000111',
                  '53000000-0000-0000-0000-000000000112')
       and status = 'paused'),
    2::bigint,
    '36. las dos publicaciones activas del vendedor suspendido quedan paused'
);

select is(
    (select status from public.marketplace_items where id = '53000000-0000-0000-0000-000000000113'),
    'available',
    '37. la publicación con is_legal_hold=true no se modifica al suspender'
);

select tests.authenticate_as_anon();

select ok(
    not exists (
        select 1 from public.get_marketplace_feed()
        where id in ('53000000-0000-0000-0000-000000000111',
                     '53000000-0000-0000-0000-000000000112')
    ),
    '38. las publicaciones del vendedor suspendido desaparecen del feed público'
);

reset role;
set role postgres;
select set_config('request.jwt.claims', '', true);
select set_config('request.jwt.claim.sub', '', true);

select ok(
    exists (
        select 1 from public.marketplace_admin_audit a
        where a.action = 'seller.update'
          and a.target_type = 'seller'
          and a.target_id = '53000000-0000-0000-0000-000000000007'
          and (a.details ->> 'items_paused') = '2'
    ),
    '39. la auditoría registra items_paused con el conteo pausado'
);

-- =============================================================================
-- 11) B3: aprobación de verificación sin auto-aprobación
-- =============================================================================

select tests.authenticate_as_moderator('53000000-0000-0000-0000-000000000002');

select throws_ok(
    $$select public.admin_update_marketplace_seller(
        '53000000-0000-0000-0000-000000000008',
        'free',
        'student',
        'approved'
    )$$,
    '42501',
    null,
    '40. un moderador no puede aprobar la verificación de un vendedor (42501)'
);

select tests.authenticate_as_admin('53000000-0000-0000-0000-000000000001');

select throws_ok(
    $$select public.admin_update_marketplace_seller(
        '53000000-0000-0000-0000-000000000001',
        'free',
        'student',
        'approved'
    )$$,
    '42501',
    null,
    '41. un administrador no puede aprobar su propia verificación (42501)'
);

select lives_ok(
    $$select public.admin_update_marketplace_seller(
        '53000000-0000-0000-0000-000000000008',
        'free',
        'student',
        'approved',
        null,
        null,
        'Aprobación QA de estudiante sin carné'
    )$$,
    '42. admin aprueba el perfil comercial de un estudiante sin carné'
);

reset role;
set role postgres;
select set_config('request.jwt.claims', '', true);
select set_config('request.jwt.claim.sub', '', true);

select is(
    (select verification_status from public.seller_profiles
     where user_id = '53000000-0000-0000-0000-000000000008'),
    'approved',
    '43. seller_profiles queda en approved para el estudiante aprobado'
);

select is(
    (select seller_verification_status from public.profiles
     where id = '53000000-0000-0000-0000-000000000008'),
    'pending',
    '44. profiles.seller_verification_status NO pasa a verified sin carné'
);

select ok(
    not public.is_verified_seller('53000000-0000-0000-0000-000000000008'),
    '45. is_verified_seller sigue false para el estudiante sin carné'
);

-- =============================================================================
-- 12) W2: blindaje del plan free y longitud de la insignia
-- =============================================================================

select tests.authenticate_as_admin('53000000-0000-0000-0000-000000000001');

select lives_ok(
    $$select public.admin_upsert_marketplace_plan(
        '{"id":"free","name":"X","price_monthly":99}'::jsonb
    )$$,
    '46. admin puede reenviar el plan free sin romper la operación'
);

select results_eq(
    $$select name, price_monthly from public.marketplace_plans where id = 'free'$$,
    $$values ('Estudiante'::text, 0.00::numeric)$$,
    '47. el plan free ignora name/price enviados y conserva Estudiante / 0'
);

select throws_ok(
    $$select public.admin_upsert_marketplace_plan(
        jsonb_build_object(
            'id', 'test_mkt54',
            'name', 'Plan Badge Largo',
            'default_badge_text', repeat('x', 41)
        )
    )$$,
    '23514',
    null,
    '48. default_badge_text de 41 caracteres se rechaza con 23514'
);

-- =============================================================================
-- 13) W11: borrado administrativo de solicitudes de patrocinio
-- =============================================================================

select tests.authenticate_as_moderator('53000000-0000-0000-0000-000000000002');

select throws_ok(
    $$select public.admin_delete_sponsor_request('53000000-0000-0000-0000-000000000902')$$,
    '42501',
    null,
    '49. un moderador no puede borrar solicitudes de patrocinio (42501)'
);

select tests.authenticate_as('53000000-0000-0000-0000-000000000004');

select throws_ok(
    $$select public.admin_delete_sponsor_request('53000000-0000-0000-0000-000000000902')$$,
    '42501',
    null,
    '50. un usuario sin rol no puede borrar solicitudes de patrocinio (42501)'
);

select tests.authenticate_as_admin('53000000-0000-0000-0000-000000000001');

select lives_ok(
    $$select public.admin_delete_sponsor_request(
        '53000000-0000-0000-0000-000000000902',
        'Borrado por QA'
    )$$,
    '51. el administrador borra la solicitud de patrocinio'
);

reset role;
set role postgres;
select set_config('request.jwt.claims', '', true);
select set_config('request.jwt.claim.sub', '', true);

select ok(
    exists (
        select 1 from public.marketplace_admin_audit a
        where a.action = 'sponsor_request.delete'
          and a.target_type = 'sponsor_request'
          and a.target_id = '53000000-0000-0000-0000-000000000902'
          and a.actor_id = '53000000-0000-0000-0000-000000000001'
    )
    and not exists (
        select 1 from public.sponsor_requests
        where id = '53000000-0000-0000-0000-000000000902'
    ),
    '52. el borrado deja auditoría sponsor_request.delete y elimina la fila'
);

select is(
    (
        select a.note
        from public.marketplace_admin_audit a
        where a.action = 'sponsor_request.delete'
          and a.target_id = '53000000-0000-0000-0000-000000000902'
        order by a.created_at desc
        limit 1
    ),
    'Borrado por QA',
    '53. la justificación del borrado queda registrada en la auditoría'
);

-- N1: un moderador puede seguir gestionando el plan de un vendedor ya aprobado.
select tests.authenticate_as_moderator('53000000-0000-0000-0000-000000000002');

select lives_ok(
    $$select public.admin_update_marketplace_seller(
        '53000000-0000-0000-0000-000000000008',
        'pro_student',
        'student',
        'approved',
        now() + interval '30 days',
        null,
        'Gestión de plan por moderador sobre vendedor ya aprobado'
    )$$,
    '54. un moderador puede cambiar el plan de un vendedor ya aprobado'
);

-- -----------------------------------------------------------------------------
select * from finish();
rollback;
