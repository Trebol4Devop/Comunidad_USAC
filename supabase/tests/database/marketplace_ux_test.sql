-- =============================================================================
-- PEMTREE / Comunidad USAC · pgTAP Test: Marketplace UX, Planes, Privacidad y RPCs
-- Archivo: supabase/tests/database/marketplace_ux_test.sql
-- Rama: feature/marketplace-ux-supabase
-- =============================================================================
begin;

select plan(84);

create extension if not exists pgtap;

-- Asegurar rol privilegiado inicial y limpiar claims residuales
reset role;
set role postgres;
select set_config('request.jwt.claims', '', true);
select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claim.role', '', true);
select set_config('request.jwt.claim.email', '', true);

-- -----------------------------------------------------------------------------
-- Fixtures Globales: Creación de identidades de prueba
-- -----------------------------------------------------------------------------
do $$
begin
    -- Usuarios de prueba con prefijo 51...
    perform tests.create_supabase_user('51000000-0000-0000-0000-000000000001', 'u01_mkt@test.com');
    perform tests.create_supabase_user('51000000-0000-0000-0000-000000000002', 'u02_mkt@test.com');
    perform tests.create_supabase_user('51000000-0000-0000-0000-000000000003', 'u03_mkt@test.com');
    perform tests.create_supabase_user('51000000-0000-0000-0000-000000000004', 'u04_mkt@test.com');
    perform tests.create_supabase_user('51000000-0000-0000-0000-000000000005', 'u05_mkt@test.com');
    perform tests.create_supabase_user('51000000-0000-0000-0000-000000000006', 'u06_mkt@test.com');
    perform tests.create_supabase_user('51000000-0000-0000-0000-000000000007', 'u07_mkt@test.com');
    perform tests.create_supabase_user('51000000-0000-0000-0000-000000000008', 'u08_mkt@test.com');
    perform tests.create_supabase_user('51000000-0000-0000-0000-000000000009', 'u09_mkt@test.com');
    perform tests.create_supabase_user('51000000-0000-0000-0000-000000000010', 'u10_mkt@test.com');
    perform tests.create_supabase_user('51000000-0000-0000-0000-000000000011', 'u11_mkt@test.com');
    perform tests.create_supabase_user('51000000-0000-0000-0000-000000000012', 'u12_mkt@test.com');
    perform tests.create_supabase_user('51000000-0000-0000-0000-000000000013', 'u13_mkt@test.com');
    perform tests.create_supabase_user('51000000-0000-0000-0000-000000000014', 'u14_mkt@test.com');
    perform tests.create_supabase_user('51000000-0000-0000-0000-000000000015', 'u15_mkt@test.com');
    perform tests.create_supabase_user('51000000-0000-0000-0000-000000000016', 'u16_mkt@test.com');
    perform tests.create_supabase_user('51000000-0000-0000-0000-000000000017', 'u17_mkt@test.com');
    perform tests.create_supabase_user('51000000-0000-0000-0000-000000000018', 'u18_mod@test.com');
    perform tests.create_supabase_user('51000000-0000-0000-0000-000000000019', 'u19_mkt@test.com');
    perform tests.create_supabase_user('51000000-0000-0000-0000-000000000020', 'u20_adm@test.com');
    perform tests.create_supabase_user('51000000-0000-0000-0000-000000000021', 'u21_mkt@test.com');
    perform tests.create_supabase_user('51000000-0000-0000-0000-000000000022', 'u22_mkt@test.com');
    perform tests.create_supabase_user('51000000-0000-0000-0000-000000000023', 'u23_mkt@test.com');

    -- Perfiles base
    insert into public.profiles (id, full_name, carrera, is_verified)
    values
        ('51000000-0000-0000-0000-000000000001', 'Usuario Verificado 01', 'sistemas', true),
        ('51000000-0000-0000-0000-000000000002', 'Usuario No Verificado 02', 'sistemas', false),
        ('51000000-0000-0000-0000-000000000003', 'Comercio Local 03', 'sistemas', false),
        ('51000000-0000-0000-0000-000000000004', 'Usuario Cuota Free 04', 'sistemas', true),
        ('51000000-0000-0000-0000-000000000005', 'Usuario Vigencia 05', 'sistemas', true),
        ('51000000-0000-0000-0000-000000000006', 'Usuario Filtros 06', 'sistemas', true),
        ('51000000-0000-0000-0000-000000000007', 'Usuario Comercio 07', 'sistemas', true),
        ('51000000-0000-0000-0000-000000000008', 'Usuario Moderacion 08', 'sistemas', true),
        ('51000000-0000-0000-0000-000000000009', 'Vendedor Catalogo 09', 'sistemas', true),
        ('51000000-0000-0000-0000-000000000010', 'Vendedor Competidor 10', 'sistemas', true),
        ('51000000-0000-0000-0000-000000000011', 'Usuario Marcadores 11', 'sistemas', true),
        ('51000000-0000-0000-0000-000000000012', 'Usuario Marcadores 12', 'sistemas', true),
        ('51000000-0000-0000-0000-000000000013', 'Usuario Telemetria 13', 'sistemas', true),
        ('51000000-0000-0000-0000-000000000014', 'Visitante Telemetria 14', 'sistemas', true),
        ('51000000-0000-0000-0000-000000000015', 'Usuario Anti Escalada 15', 'sistemas', true),
        ('51000000-0000-0000-0000-000000000016', 'Usuario Filtro Semantico 16', 'sistemas', true),
        ('51000000-0000-0000-0000-000000000017', 'Usuario Legal Hold 17', 'sistemas', true),
        ('51000000-0000-0000-0000-000000000018', 'Moderador 18', 'sistemas', true),
        ('51000000-0000-0000-0000-000000000019', 'Usuario Sponsor Req 19', 'sistemas', true),
        ('51000000-0000-0000-0000-000000000020', 'Administrador 20', 'sistemas', true),
        ('51000000-0000-0000-0000-000000000021', 'Usuario Delete Fisico 21', 'sistemas', true),
        ('51000000-0000-0000-0000-000000000022', 'Usuario Event Privacy 22', 'sistemas', true),
        ('51000000-0000-0000-0000-000000000023', 'Usuario Event Privacy 23', 'sistemas', true)
    on conflict (id) do update set is_verified = excluded.is_verified, carrera = excluded.carrera;

    -- Perfil comercial pre-aprobado para Usuario 3 (comercio local sin verificación estudiantil)
    insert into public.seller_profiles (user_id, plan_id, seller_type, verification_status, business_name)
    values ('51000000-0000-0000-0000-000000000003', 'business_local', 'local_business', 'approved', 'Libreria Universitaria Central')
    on conflict (user_id) do update set
        plan_id = excluded.plan_id,
        seller_type = excluded.seller_type,
        verification_status = excluded.verification_status,
        business_name = excluded.business_name;
end $$;

-- =============================================================================
-- SECCIÓN 1: Planes base y límites normativos
-- =============================================================================

-- Test 1: Plan free posee límites normativos (3 activas / 2 fotos / allow_video false / hide_competitor false)
select results_eq(
    $$select max_active_items, max_images_per_item, allow_video, auto_sponsor_items, hide_competitor_related, default_badge_text
      from public.marketplace_plans where id = 'free'$$,
    $$values (3, 2, false, false, false, 'Estudiante Verificado')$$,
    '1. Plan free posee limites normativos exactos (3/2/false/false/false)'
);

-- Test 2: Plan pro_student posee límites normativos (20 activas / 6 fotos / allow_video true / auto_sponsor true)
select results_eq(
    $$select max_active_items, max_images_per_item, allow_video, auto_sponsor_items, hide_competitor_related, default_badge_text
      from public.marketplace_plans where id = 'pro_student'$$,
    $$values (20, 6, true, true, false, 'Emprendedor Verificado')$$,
    '2. Plan pro_student posee limites normativos exactos (20/6/true/true/false)'
);

-- Test 3: Plan business_local posee límites normativos (0 ilimitadas / 10 fotos / video true / hide_competitor true)
select results_eq(
    $$select max_active_items, max_images_per_item, allow_video, auto_sponsor_items, hide_competitor_related, default_badge_text
      from public.marketplace_plans where id = 'business_local'$$,
    $$values (0, 10, true, true, true, 'Tienda / Local Oficial')$$,
    '3. Plan business_local posee limites normativos exactos (0/10/true/true/true)'
);

-- =============================================================================
-- SECCIÓN 2: Alta de vendedor y privacidad
-- =============================================================================

select tests.authenticate_as('51000000-0000-0000-0000-000000000001');

-- Test 4: Inserción de ítem por usuario verificado
select lives_ok(
    $$insert into public.marketplace_items (
        id, user_id, title, description, price, is_free, category, facultad, sede,
        contact_whatsapp, author_alias, status
      ) values (
        '52000000-0000-0000-0000-000000000001',
        '51000000-0000-0000-0000-000000000001',
        'Libro Calculo Leithold',
        'Texto en buen estado de calculo con geometria analitica',
        75.00,
        false,
        'libros_materiales',
        'todas',
        'central',
        '50255551111',
        'Estudiante Anónimo',
        'available'
      )$$,
    '4. Usuario verificado inserta publicacion correctamente'
);

-- Volver a rol postgres para verificaciones directas
reset role;
set role postgres;
select set_config('request.jwt.claims', '', true);
select set_config('request.jwt.claim.sub', '', true);

-- Test 5: Trigger trg_ensure_seller_profile_marketplace_items crea seller_profiles con public_id no nulo
select ok(
    exists (
        select 1 from public.seller_profiles
        where user_id = '51000000-0000-0000-0000-000000000001'
          and public_id is not null
    ),
    '5. Trigger crea automaticamente seller_profiles con public_id no nulo'
);

-- Test 6: safe_seller_profiles no expone user_id
select hasnt_column('public', 'safe_seller_profiles', 'user_id', '6. safe_seller_profiles no expone columna user_id');

-- Test 7: safe_marketplace_items no expone user_id
select hasnt_column('public', 'safe_marketplace_items', 'user_id', '7. safe_marketplace_items no expone columna user_id');

-- Test 8: get_marketplace_feed no define argumento ni columna de retorno user_id
select ok(
    (select not ('user_id' = ANY (proargnames)) from pg_proc where proname = 'get_marketplace_feed'),
    '8. get_marketplace_feed no expone columna user_id en su contrato RPC'
);

-- Test 9: get_marketplace_feed devuelve seller_public_id no nulo para el item insertado
select isnt(
    (select seller_public_id from public.get_marketplace_feed() where id = '52000000-0000-0000-0000-000000000001'),
    NULL,
    '9. get_marketplace_feed devuelve seller_public_id no nulo'
);

-- =============================================================================
-- SECCIÓN 3: Verificación obligatoria
-- =============================================================================

select tests.authenticate_as('51000000-0000-0000-0000-000000000002');

-- Test 10: Usuario no verificado (is_verified = false) recibe 42501 al intentar publicar
select throws_ok(
    $$insert into public.marketplace_items (
        id, user_id, title, description, price, is_free, category, facultad, sede,
        contact_whatsapp, author_alias, status
      ) values (
        '52000000-0000-0000-0000-000000000002',
        '51000000-0000-0000-0000-000000000002',
        'Libro No Autorizado',
        'Intento de publicacion sin contar con carné verificado',
        50.00,
        false,
        'libros_materiales',
        'todas',
        'central',
        '50255552222',
        'Estudiante Anónimo',
        'available'
      )$$,
    '42501',
    null,
    '10. Usuario no verificado y sin comercio recibe 42501 al intentar publicar'
);

-- Test 11: Usuario no verificado pero con cuenta comercial local_business aprobada sí puede publicar
select tests.authenticate_as('51000000-0000-0000-0000-000000000003');

select lives_ok(
    $$insert into public.marketplace_items (
        id, user_id, title, description, price, is_free, category, facultad, sede,
        contact_whatsapp, author_alias, status
      ) values (
        '52000000-0000-0000-0000-000000000003',
        '51000000-0000-0000-0000-000000000003',
        'Calculadora Graficadora HP Prime',
        'Equipo oficial para ingenieria con garantia de tienda central',
        850.00,
        false,
        'libros_materiales',
        'todas',
        'central',
        '50255553333',
        'Estudiante Anónimo',
        'available'
      )$$,
    '11. Comercio local aprobado puede publicar aun sin verificacion estudiantil'
);

-- =============================================================================
-- SECCIÓN 4: Cuota de publicaciones activas (plan free)
-- =============================================================================

select tests.authenticate_as('51000000-0000-0000-0000-000000000004');

-- Test 12: Publicación 1 de 3 (disponible)
select lives_ok(
    $$insert into public.marketplace_items (id, user_id, title, description, price, is_free, category, facultad, sede, contact_whatsapp, author_alias, status)
      values ('52000000-0000-0000-0000-000000000041', '51000000-0000-0000-0000-000000000004', 'Item Cuota Uno', 'Primera publicacion activa valida para estudiante', 10, false, 'libros_materiales', 'todas', 'central', '50255554441', 'Estudiante Anónimo', 'available')$$,
    '12. Usuario free inserta publicacion activa 1 de 3'
);

-- Test 13: Publicación 2 de 3 (disponible)
select lives_ok(
    $$insert into public.marketplace_items (id, user_id, title, description, price, is_free, category, facultad, sede, contact_whatsapp, author_alias, status)
      values ('52000000-0000-0000-0000-000000000042', '51000000-0000-0000-0000-000000000004', 'Item Cuota Dos', 'Segunda publicacion activa valida para estudiante', 20, false, 'libros_materiales', 'todas', 'central', '50255554442', 'Estudiante Anónimo', 'available')$$,
    '13. Usuario free inserta publicacion activa 2 de 3'
);

-- Test 14: Publicación 3 de 3 (disponible, tope de plan free alcanzado)
select lives_ok(
    $$insert into public.marketplace_items (id, user_id, title, description, price, is_free, category, facultad, sede, contact_whatsapp, author_alias, status)
      values ('52000000-0000-0000-0000-000000000043', '51000000-0000-0000-0000-000000000004', 'Item Cuota Tres', 'Tercera publicacion activa valida para estudiante', 30, false, 'libros_materiales', 'todas', 'central', '50255554443', 'Estudiante Anónimo', 'available')$$,
    '14. Usuario free inserta publicacion activa 3 de 3'
);

-- Test 15: Publicación 4 de 3 falla por cupo excedido (23514)
select throws_ok(
    $$insert into public.marketplace_items (id, user_id, title, description, price, is_free, category, facultad, sede, contact_whatsapp, author_alias, status)
      values ('52000000-0000-0000-0000-000000000044', '51000000-0000-0000-0000-000000000004', 'Item Cuota Cuatro', 'Cuarta publicacion debe fallar por tope de 3 activas', 40, false, 'libros_materiales', 'todas', 'central', '50255554444', 'Estudiante Anónimo', 'available')$$,
    '23514',
    null,
    '15. 4ta publicacion activa en plan free falla por cupo excedido (23514)'
);

-- Test 16: Marcar publicación 1 como sold libera cupo
select lives_ok(
    $$update public.marketplace_items set status = 'sold' where id = '52000000-0000-0000-0000-000000000041'$$,
    '16. Actualizar publicacion 1 a sold libera cupo activo'
);

-- Test 17: Con cupo liberado, publicación 4 ahora ingresa exitosamente
select lives_ok(
    $$insert into public.marketplace_items (id, user_id, title, description, price, is_free, category, facultad, sede, contact_whatsapp, author_alias, status)
      values ('52000000-0000-0000-0000-000000000044', '51000000-0000-0000-0000-000000000004', 'Item Cuota Cuatro', 'Cuarta publicacion entra tras liberar cupo vendido', 40, false, 'libros_materiales', 'todas', 'central', '50255554444', 'Estudiante Anónimo', 'available')$$,
    '17. Publicacion entra tras liberar cupo marcando otra como sold'
);

-- Test 18: Marcar publicación 2 como paused libera cupo sin eliminar
select lives_ok(
    $$update public.marketplace_items set status = 'paused' where id = '52000000-0000-0000-0000-000000000042'$$,
    '18. Actualizar publicacion 2 a paused no consume cupo activo'
);

-- Test 19: Con ítem 2 en paused (activas: 43 y 44 = 2), entra publicación 5
select lives_ok(
    $$insert into public.marketplace_items (id, user_id, title, description, price, is_free, category, facultad, sede, contact_whatsapp, author_alias, status)
      values ('52000000-0000-0000-0000-000000000045', '51000000-0000-0000-0000-000000000004', 'Item Cuota Cinco', 'Quinta publicacion entra porque paused no cuenta', 50, false, 'libros_materiales', 'todas', 'central', '50255554445', 'Estudiante Anónimo', 'available')$$,
    '19. Publicacion paused no consume cupo activo y permite nueva publicacion'
);

-- =============================================================================
-- SECCIÓN 5: Vigencia free y purga/pausa automática
-- =============================================================================

select tests.authenticate_as('51000000-0000-0000-0000-000000000005');

-- Test 20: Inserción de ítem en plan free
select lives_ok(
    $$insert into public.marketplace_items (id, user_id, title, description, price, is_free, category, facultad, sede, contact_whatsapp, author_alias, status)
      values ('52000000-0000-0000-0000-000000000051', '51000000-0000-0000-0000-000000000005', 'Item Vigencia Test', 'Publicacion sujeta a vencimiento de catorce dias', 35, false, 'libros_materiales', 'todas', 'central', '50255555551', 'Estudiante Anónimo', 'available')$$,
    '20. Insercion de publicacion para prueba de vigencia'
);

reset role;
set role postgres;
select set_config('request.jwt.claims', '', true);
select set_config('request.jwt.claim.sub', '', true);

-- Test 21: Publicación en plan free recibe expires_at de approx +14 días
select ok(
    (select expires_at between now() + interval '13 days' and now() + interval '15 days'
     from public.marketplace_items where id = '52000000-0000-0000-0000-000000000051'),
    '21. Publicacion en plan free recibe expires_at de aprox. +14 dias'
);

-- Preparar vencimiento en el pasado para item 51 e insertar item 52 con legal hold y deleted_at antiguo
update public.marketplace_items
   set expires_at = now() - interval '2 hours'
 where id = '52000000-0000-0000-0000-000000000051';

insert into public.marketplace_items (
    id, user_id, title, description, price, is_free, category, facultad, sede,
    contact_whatsapp, author_alias, status, is_legal_hold, deleted_at
) values (
    '52000000-0000-0000-0000-000000000052',
    '51000000-0000-0000-0000-000000000005',
    'Item Legal Hold Antiguo',
    'Publicacion bajo retencion legal y eliminada logica hace 60 dias',
    10,
    false,
    'libros_materiales',
    'todas',
    'central',
    '50255555552',
    'Estudiante Anónimo',
    'available',
    true,
    now() - interval '60 days'
);

-- Ejecutar mantenimiento de vencimiento
select cmp_ok(public.pause_expired_marketplace_items(), '>=', 1, '22. pause_expired_marketplace_items ejecuta y procesa filas');

-- Test 23: Item 51 vencido pasa automáticamente a estado 'paused'
select is(
    (select status from public.marketplace_items where id = '52000000-0000-0000-0000-000000000051'),
    'paused',
    '23. pause_expired_marketplace_items cambia estado a paused para publicaciones vencidas'
);

-- Test 24: Item con is_legal_hold=true y deleted_at antiguo NO desaparece por purga
select ok(
    exists (
        select 1 from public.marketplace_items
        where id = '52000000-0000-0000-0000-000000000052'
          and is_legal_hold = true
          and deleted_at is not null
    ),
    '24. Item con is_legal_hold=true y deleted_at antiguo no desaparece por purga'
);

-- =============================================================================
-- SECCIÓN 6: Filtros del feed principal
-- =============================================================================

reset role;
set role postgres;
select set_config('request.jwt.claims', '', true);
select set_config('request.jwt.claim.sub', '', true);

-- Asegurar perfil comercial de Usuario 7 como business_local (auto_sponsor_items = true)
insert into public.seller_profiles (user_id, plan_id, seller_type, verification_status, business_name)
values ('51000000-0000-0000-0000-000000000007', 'business_local', 'local_business', 'approved', 'Comercio Siete')
on conflict (user_id) do update set plan_id = 'business_local', verification_status = 'approved';

insert into public.marketplace_items (id, user_id, title, description, price, is_free, category, facultad, sede, building_code, contact_whatsapp, author_alias, status, is_sponsored)
values
    -- Item 61: Central, Fac 01, Edificio T-3, Libros, con tilde en título, de pago
    ('52000000-0000-0000-0000-000000000061', '51000000-0000-0000-0000-000000000006', 'Libro de Cálculo Diferencial', 'Texto guia para curso de matematica basica uno', 80.00, false, 'libros_materiales', '01', 'central', 'T-3', '50255556661', 'Estudiante Anónimo', 'available', false),
    -- Item 62: Central, Fac todas, Edificio S-12, Servicios, gratuito
    ('52000000-0000-0000-0000-000000000062', '51000000-0000-0000-0000-000000000006', 'Tutoría Gratuita de Física', 'Resolucion de dudas para estudiantes de ingenieria', 0.00, true, 'servicios_estudiantiles', 'todas', 'central', 'S-12', '50255556662', 'Estudiante Anónimo', 'available', false),
    -- Item 63: Regional CUNUOC, Fac 01, Edificio A-1, Libros, patrocinado manual
    ('52000000-0000-0000-0000-000000000063', '51000000-0000-0000-0000-000000000006', 'Libro de Química General', 'Quimica general en buenas condiciones tomo uno', 50.00, false, 'libros_materiales', '01', 'regional_cunuoc', 'A-1', '50255556663', 'Estudiante Anónimo', 'available', true),
    -- Items 71-76: 6 items patrocinados (Item 71 auto_sponsor por plan business_local + 72-76 con is_sponsored true)
    ('52000000-0000-0000-0000-000000000071', '51000000-0000-0000-0000-000000000007', 'Calculadora Comercial Pro', 'Herramienta para ingenieria tienda oficial', 200.00, false, 'otros_articulos', 'todas', 'central', 'T-3', '50255557771', 'Estudiante Anónimo', 'available', false),
    ('52000000-0000-0000-0000-000000000072', '51000000-0000-0000-0000-000000000006', 'Patrocinado Extra Dos', 'Articulo de prueba con patrocinio activo extra', 10.00, false, 'libros_materiales', 'todas', 'central', 'T-3', '50255557772', 'Estudiante Anónimo', 'available', true),
    ('52000000-0000-0000-0000-000000000073', '51000000-0000-0000-0000-000000000006', 'Patrocinado Extra Tres', 'Articulo de prueba con patrocinio activo extra', 10.00, false, 'libros_materiales', 'todas', 'central', 'T-3', '50255557773', 'Estudiante Anónimo', 'available', true),
    ('52000000-0000-0000-0000-000000000074', '51000000-0000-0000-0000-000000000006', 'Patrocinado Extra Cuatro', 'Articulo de prueba con patrocinio activo extra', 10.00, false, 'libros_materiales', 'todas', 'central', 'T-3', '50255557774', 'Estudiante Anónimo', 'available', true),
    ('52000000-0000-0000-0000-000000000075', '51000000-0000-0000-0000-000000000006', 'Patrocinado Extra Cinco', 'Articulo de prueba con patrocinio activo extra', 10.00, false, 'libros_materiales', 'todas', 'central', 'T-3', '50255557775', 'Estudiante Anónimo', 'available', true),
    ('52000000-0000-0000-0000-000000000076', '51000000-0000-0000-0000-000000000006', 'Patrocinado Extra Seis', 'Articulo de prueba con patrocinio activo extra', 10.00, false, 'libros_materiales', 'todas', 'central', 'T-3', '50255557776', 'Estudiante Anónimo', 'available', true);

-- Test 25: Filtro por sede (regional_cunuoc devuelve solo item 63)
select results_eq(
    $$select id from public.get_marketplace_feed(p_sede := 'regional_cunuoc')$$,
    $$values ('52000000-0000-0000-0000-000000000063'::uuid)$$,
    '25. Feed filtra correctamente por sede'
);

-- Test 26: Filtro por facultad
select ok(
    not exists (
        select 1 from public.get_marketplace_feed(p_facultad := '01')
        where facultad <> '01'
    ),
    '26. Feed filtra correctamente por facultad'
);

-- Test 27: Filtro por building_code
select ok(
    not exists (
        select 1 from public.get_marketplace_feed(p_building_code := 'S-12')
        where building_code <> 'S-12'
    ),
    '27. Feed filtra correctamente por building_code'
);

-- Test 28: Filtro por categoría
select ok(
    not exists (
        select 1 from public.get_marketplace_feed(p_category := 'servicios_estudiantiles')
        where category <> 'servicios_estudiantiles'
    ),
    '28. Feed filtra correctamente por categoria'
);

-- Test 29: Búsqueda insensible a tildes (busca 'calculo' y encuentra 'Cálculo')
select ok(
    exists (
        select 1 from public.get_marketplace_feed(p_search := 'calculo')
        where id = '52000000-0000-0000-0000-000000000061'
    ),
    '29. Busqueda textual sin tilde encuentra titulo con tilde'
);

-- Test 30: Parámetro p_only_free devuelve solo items con is_free = true
select ok(
    not exists (
        select 1 from public.get_marketplace_feed(p_only_free := true)
        where is_free = false
    ),
    '30. p_only_free devuelve unicamente publicaciones gratuitas'
);

-- Test 31: Parámetro p_sponsored_only devuelve solo publicaciones patrocinadas o auto-sponsor
select ok(
    not exists (
        select 1 from public.get_marketplace_feed(p_sponsored_only := true)
        where is_sponsored = false
    ),
    '31. p_sponsored_only devuelve unicamente publicaciones patrocinadas'
);

-- Test 32: p_sponsored_only limita resultados a máximo 5 items aunque se pida p_limit := 20
select cmp_ok(
    (select count(*) from public.get_marketplace_feed(p_sponsored_only := true, p_limit := 20)),
    '<=',
    5::bigint,
    '32. p_sponsored_only limita resultados a maximo 5 items'
);

-- =============================================================================
-- SECCIÓN 7: Visibilidad según estado de moderación
-- =============================================================================

reset role;
set role postgres;
select set_config('request.jwt.claims', '', true);
select set_config('request.jwt.claim.sub', '', true);

-- Insertar items con moderation_status 1 (aprobado), 3 (en revisión), 2 (oculto)
insert into public.marketplace_items (id, user_id, title, description, price, is_free, category, facultad, sede, contact_whatsapp, author_alias, status, moderation_status)
values
    ('52000000-0000-0000-0000-000000000081', '51000000-0000-0000-0000-000000000008', 'Item Aprobado Uno', 'Item con estado de moderacion aprobado visible publico', 10, false, 'libros_materiales', 'todas', 'central', '50255558881', 'Estudiante Anónimo', 'available', 1),
    ('52000000-0000-0000-0000-000000000082', '51000000-0000-0000-0000-000000000008', 'Item En Revision Tres', 'Item con estado tres en revision oculto al publico', 10, false, 'libros_materiales', 'todas', 'central', '50255558882', 'Estudiante Anónimo', 'available', 3),
    ('52000000-0000-0000-0000-000000000083', '51000000-0000-0000-0000-000000000008', 'Item Oculto Dos', 'Item con estado dos bloqueado u oculto permanentemente', 10, false, 'libros_materiales', 'todas', 'central', '50255558883', 'Estudiante Anónimo', 'available', 2);

-- Autenticar como anónimo
select tests.authenticate_as_anon();

-- Test 33: moderation_status=1 aparece en feed anon
select ok(
    exists (
        select 1 from public.get_marketplace_feed()
        where id = '52000000-0000-0000-0000-000000000081'
    ),
    '33. Item moderation_status=1 aparece en feed para anon'
);

-- Test 34: moderation_status=3 NO aparece en feed anon
select ok(
    not exists (
        select 1 from public.get_marketplace_feed()
        where id = '52000000-0000-0000-0000-000000000082'
    ),
    '34. Item moderation_status=3 NO aparece en feed para anon'
);

-- Test 35: moderation_status=2 NO aparece en feed anon
select ok(
    not exists (
        select 1 from public.get_marketplace_feed()
        where id = '52000000-0000-0000-0000-000000000083'
    ),
    '35. Item moderation_status=2 NO aparece en feed para anon'
);

-- Autenticar como el autor (Usuario 8)
select tests.authenticate_as('51000000-0000-0000-0000-000000000008');

-- Test 36: moderation_status=3 SÍ aparece en feed para su autor
select ok(
    exists (
        select 1 from public.get_marketplace_feed()
        where id = '52000000-0000-0000-0000-000000000082'
    ),
    '36. Item moderation_status=3 SI aparece en feed para su autor'
);

-- Test 37: moderation_status=2 es visible en detalle para su autor
select is(
    (select count(*) from public.get_marketplace_item_detail('52000000-0000-0000-0000-000000000083')),
    1::bigint,
    '37. Item moderation_status=2 es visible en detalle para su autor'
);

-- Autenticar como usuario ajeno (Usuario 1)
select tests.authenticate_as('51000000-0000-0000-0000-000000000001');

-- Test 38: moderation_status=2 NO aparece en feed para usuario ajeno
select ok(
    not exists (
        select 1 from public.get_marketplace_feed()
        where id = '52000000-0000-0000-0000-000000000083'
    ),
    '38. Item moderation_status=2 NO aparece para usuario ajeno'
);

-- Test 39: moderation_status=2 devuelve 0 filas en detalle para usuario ajeno
select is(
    (select count(*) from public.get_marketplace_item_detail('52000000-0000-0000-0000-000000000083')),
    0::bigint,
    '39. Item moderation_status=2 devuelve 0 filas en detalle para usuario ajeno'
);

-- Autenticar como moderador (Usuario 18)
select tests.authenticate_as_moderator('51000000-0000-0000-0000-000000000018');

-- Test 40: moderation_status=2 es visible en detalle para moderador
select is(
    (select count(*) from public.get_marketplace_item_detail('52000000-0000-0000-0000-000000000083')),
    1::bigint,
    '40. Item moderation_status=2 es visible en detalle para moderador'
);

-- =============================================================================
-- SECCIÓN 8: Detalle de producto (get_marketplace_item_detail)
-- =============================================================================

select tests.authenticate_as_anon();

-- Test 41: get_marketplace_item_detail devuelve 1 fila para item activo aprobado en anon
select is(
    (select count(*) from public.get_marketplace_item_detail('52000000-0000-0000-0000-000000000081')),
    1::bigint,
    '41. get_marketplace_item_detail devuelve 1 fila para item activo y visible en anon'
);

-- Test 42: get_marketplace_item_detail devuelve 0 filas para id inexistente
select is(
    (select count(*) from public.get_marketplace_item_detail('52000000-0000-0000-0000-000000000099')),
    0::bigint,
    '42. get_marketplace_item_detail devuelve 0 filas para item inexistente'
);

-- Test 43: get_marketplace_item_detail devuelve 0 filas en anon para item oculto (status 2)
select is(
    (select count(*) from public.get_marketplace_item_detail('52000000-0000-0000-0000-000000000083')),
    0::bigint,
    '43. get_marketplace_item_detail devuelve 0 filas para anon en item oculto ajeno'
);

-- =============================================================================
-- SECCIÓN 9: Catálogo del vendedor y productos relacionados
-- =============================================================================

reset role;
set role postgres;
select set_config('request.jwt.claims', '', true);
select set_config('request.jwt.claim.sub', '', true);

-- Asegurar perfiles de Usuario 9 (vendedor) y Usuario 10 (competidor)
insert into public.marketplace_items (id, user_id, title, description, price, is_free, category, facultad, sede, contact_whatsapp, author_alias, status)
values
    ('52000000-0000-0000-0000-000000000091', '51000000-0000-0000-0000-000000000009', 'Item Vendedor 9 Uno', 'Articulo activo principal del vendedor nueve', 10.00, false, 'tutorias_academica', '08', 'central', '50255559991', 'Estudiante Anónimo', 'available'),
    ('52000000-0000-0000-0000-000000000092', '51000000-0000-0000-0000-000000000009', 'Item Vendedor 9 Dos', 'Segundo articulo activo del vendedor nueve', 20.00, false, 'tutorias_academica', '08', 'central', '50255559992', 'Estudiante Anónimo', 'available'),
    ('52000000-0000-0000-0000-000000000093', '51000000-0000-0000-0000-000000000009', 'Item Vendedor 9 Vendido', 'Articulo vendido que no debe mostrarse en catalogo', 30.00, false, 'tutorias_academica', '08', 'central', '50255559993', 'Estudiante Anónimo', 'sold'),
    ('52000000-0000-0000-0000-000000000094', '51000000-0000-0000-0000-000000000009', 'Item Vendedor 9 Pausado', 'Articulo pausado que no debe mostrarse en catalogo', 40.00, false, 'tutorias_academica', '08', 'central', '50255559994', 'Estudiante Anónimo', 'paused'),
    ('52000000-0000-0000-0000-000000000101', '51000000-0000-0000-0000-000000000010', 'Item Competidor 10', 'Articulo de otro vendedor competidor relacionado', 15.00, false, 'tutorias_academica', '08', 'central', '50255551010', 'Estudiante Anónimo', 'available');

-- Test 44: get_seller_catalog excluye el ítem actual proporcionado en p_exclude_item_id
select ok(
    not exists (
        select 1 from public.get_seller_catalog(
            (select public_id from public.seller_profiles where user_id = '51000000-0000-0000-0000-000000000009'),
            '52000000-0000-0000-0000-000000000091'
        ) where id = '52000000-0000-0000-0000-000000000091'
    ),
    '44. get_seller_catalog excluye el item actual'
);

-- Test 45: get_seller_catalog incluye otros ítems disponibles del vendedor (Item 92)
select ok(
    exists (
        select 1 from public.get_seller_catalog(
            (select public_id from public.seller_profiles where user_id = '51000000-0000-0000-0000-000000000009'),
            '52000000-0000-0000-0000-000000000091'
        ) where id = '52000000-0000-0000-0000-000000000092'
    ),
    '45. get_seller_catalog incluye otros items activos del vendedor'
);

-- Test 46: get_seller_catalog excluye publicaciones con status sold o paused
select ok(
    not exists (
        select 1 from public.get_seller_catalog(
            (select public_id from public.seller_profiles where user_id = '51000000-0000-0000-0000-000000000009'),
            '52000000-0000-0000-0000-000000000091'
        ) where status in ('sold', 'paused')
    ),
    '46. get_seller_catalog excluye publicaciones vendidas o pausadas'
);

-- Test 47: get_seller_catalog NO incluye ítems de otros vendedores (Item 101)
select ok(
    not exists (
        select 1 from public.get_seller_catalog(
            (select public_id from public.seller_profiles where user_id = '51000000-0000-0000-0000-000000000009'),
            '52000000-0000-0000-0000-000000000091'
        ) where id = '52000000-0000-0000-0000-000000000101'
    ),
    '47. get_seller_catalog solo devuelve items del vendedor consultado'
);

-- Test 48: get_related_marketplace_items excluye ítems del mismo vendedor
select ok(
    not exists (
        select 1 from public.get_related_marketplace_items('52000000-0000-0000-0000-000000000091')
        where id in ('52000000-0000-0000-0000-000000000091', '52000000-0000-0000-0000-000000000092')
    ),
    '48. get_related_marketplace_items excluye items del mismo vendedor'
);

-- Test 49: get_related_marketplace_items devuelve items relacionados de competidores (Item 101)
select ok(
    exists (
        select 1 from public.get_related_marketplace_items('52000000-0000-0000-0000-000000000091')
        where id = '52000000-0000-0000-0000-000000000101'
    ),
    '49. get_related_marketplace_items devuelve items relacionados de competidores'
);

-- Asignar plan business_local al vendedor del ítem origen (hide_competitor_related = true)
update public.seller_profiles
   set plan_id = 'business_local', verification_status = 'approved'
 where user_id = '51000000-0000-0000-0000-000000000009';

-- Test 50: Vendedor con plan business_local (hide_competitor_related) devuelve 0 filas en relacionados
select is(
    (select count(*) from public.get_related_marketplace_items('52000000-0000-0000-0000-000000000091')),
    0::bigint,
    '50. get_related_marketplace_items devuelve 0 filas si vendedor tiene plan business_local (hide_competitor_related)'
);

-- =============================================================================
-- SECCIÓN 10: Marcadores / Bookmarks
-- =============================================================================

reset role;
set role postgres;
select set_config('request.jwt.claims', '', true);
select set_config('request.jwt.claim.sub', '', true);

-- Crear item de prueba para marcadores
insert into public.marketplace_items (id, user_id, title, description, price, is_free, category, facultad, sede, contact_whatsapp, author_alias, status)
values ('52000000-0000-0000-0000-000000000110', '51000000-0000-0000-0000-000000000011', 'Item Bookmark Base', 'Descripcion de prueba de bookmark con mas de 10 car', 25, false, 'libros_materiales', 'todas', 'central', '50255551110', 'Estudiante Anónimo', 'available');

select tests.authenticate_as('51000000-0000-0000-0000-000000000012');

-- Test 51: Primer toggle guarda y devuelve true
select is(
    (select public.toggle_marketplace_bookmark('52000000-0000-0000-0000-000000000110')),
    true,
    '51. toggle_marketplace_bookmark guarda y retorna true'
);

-- Test 52: get_my_bookmarked_items devuelve el ítem guardado
select is(
    (select count(*) from public.get_my_bookmarked_items() where id = '52000000-0000-0000-0000-000000000110'),
    1::bigint,
    '52. get_my_bookmarked_items devuelve el item guardado'
);

-- Test 53: Segundo toggle elimina el marcador y devuelve false
select is(
    (select public.toggle_marketplace_bookmark('52000000-0000-0000-0000-000000000110')),
    false,
    '53. toggle_marketplace_bookmark elimina y retorna false al segundo llamado'
);

-- Test 54: get_my_bookmarked_items ya no contiene el ítem
select is(
    (select count(*) from public.get_my_bookmarked_items() where id = '52000000-0000-0000-0000-000000000110'),
    0::bigint,
    '54. get_my_bookmarked_items refleja la eliminacion'
);

-- Usuario 11 guarda su propio marcador
select tests.authenticate_as('51000000-0000-0000-0000-000000000011');
select public.toggle_marketplace_bookmark('52000000-0000-0000-0000-000000000110');

-- Usuario 12 no puede ver el marcador de Usuario 11
select tests.authenticate_as('51000000-0000-0000-0000-000000000012');

-- Test 55: RLS impide a Usuario 12 leer marcadores de Usuario 11
select is_empty(
    $$select 1 from public.marketplace_bookmarks where user_id = '51000000-0000-0000-0000-000000000011'$$,
    '55. RLS impide a Usuario 12 leer marcadores de Usuario 11'
);

-- Test 56: RLS impide a Usuario 12 insertar marcador a nombre de Usuario 11
select throws_ok(
    $$insert into public.marketplace_bookmarks (item_id, user_id) values ('52000000-0000-0000-0000-000000000110', '51000000-0000-0000-0000-000000000011')$$,
    '42501',
    null,
    '56. RLS impide a Usuario 12 insertar marcador a nombre de Usuario 11'
);

-- =============================================================================
-- SECCIÓN 11: Telemetría y métricas agregadas
-- =============================================================================

reset role;
set role postgres;
select set_config('request.jwt.claims', '', true);
select set_config('request.jwt.claim.sub', '', true);

insert into public.marketplace_items (id, user_id, title, description, price, is_free, category, facultad, sede, contact_whatsapp, author_alias, status)
values ('52000000-0000-0000-0000-000000000130', '51000000-0000-0000-0000-000000000013', 'Item Telemetria Trece', 'Descripcion para metricas y conversion de eventos', 30, false, 'libros_materiales', 'todas', 'central', '50255551313', 'Estudiante Anónimo', 'available');

-- Autenticar como autor (Usuario 13) y generar auto-visita
select tests.authenticate_as('51000000-0000-0000-0000-000000000013');

-- Test 57: Auto-visita del autor devuelve true
select is(
    (select public.track_marketplace_event('52000000-0000-0000-0000-000000000130', 'view')),
    true,
    '57. track_marketplace_event view del autor retorna true sin error'
);

-- Test 58: Auto-visita del autor no inserta registro en marketplace_item_events
reset role;
set role postgres;
select set_config('request.jwt.claims', '', true);
select set_config('request.jwt.claim.sub', '', true);

select is(
    (select count(*) from public.marketplace_item_events where item_id = '52000000-0000-0000-0000-000000000130'),
    0::bigint,
    '58. Auto-visita del autor no inserta registro en marketplace_item_events'
);

-- Autenticar como visitante (Usuario 14) y registrar primera visita
select tests.authenticate_as('51000000-0000-0000-0000-000000000014');

-- Test 59: Visita de usuario distinto registra evento correctamente
select is(
    (select public.track_marketplace_event('52000000-0000-0000-0000-000000000130', 'view')),
    true,
    '59. track_marketplace_event view de visitante registra evento'
);

reset role;
set role postgres;
select set_config('request.jwt.claims', '', true);
select set_config('request.jwt.claim.sub', '', true);

-- Test 60: La tabla de eventos contiene exactamente 1 registro tras la primera visita
select is(
    (select count(*) from public.marketplace_item_events where item_id = '52000000-0000-0000-0000-000000000130'),
    1::bigint,
    '60. marketplace_item_events contiene 1 fila tras primera visita'
);

-- Test 61: Segunda visita del mismo visitante dentro de 30 min es deduplicada
select tests.authenticate_as('51000000-0000-0000-0000-000000000014');

select is(
    (select public.track_marketplace_event('52000000-0000-0000-0000-000000000130', 'view')),
    true,
    '61. Segunda visita en menos de 30 min retorna true por deduplicacion'
);

reset role;
set role postgres;
select set_config('request.jwt.claims', '', true);
select set_config('request.jwt.claim.sub', '', true);

-- Test 62: El contador de eventos sigue siendo 1 tras deduplicación
select is(
    (select count(*) from public.marketplace_item_events where item_id = '52000000-0000-0000-0000-000000000130'),
    1::bigint,
    '62. Event count se mantiene en 1 tras deduplicacion'
);

-- Test 63: get_marketplace_metrics reporta métricas de items propios al autor
select tests.authenticate_as('51000000-0000-0000-0000-000000000013');

select is(
    (select views from public.get_marketplace_metrics(7) where item_id = '52000000-0000-0000-0000-000000000130'),
    1::bigint,
    '63. get_marketplace_metrics reporta 1 view al autor'
);

-- Test 64: get_marketplace_metrics para visitante no expone métricas ajenas
select tests.authenticate_as('51000000-0000-0000-0000-000000000014');

select is(
    (select count(*) from public.get_marketplace_metrics(7) where item_id = '52000000-0000-0000-0000-000000000130'),
    0::bigint,
    '64. get_marketplace_metrics no devuelve metricas ajenas'
);

-- Test 65: get_marketplace_metrics no expone viewer_id en su firma
select ok(
    (select not ('viewer_id' = ANY (proargnames)) from pg_proc where proname = 'get_marketplace_metrics'),
    '65. get_marketplace_metrics no expone columna viewer_id'
);

-- =============================================================================
-- SECCIÓN 12: Anti-escalada de plan y restricciones comerciales
-- =============================================================================

select tests.authenticate_as('51000000-0000-0000-0000-000000000015');

-- Test 66: Inserción directa de seller_profiles procesada por trigger guard
select lives_ok(
    $$insert into public.seller_profiles (user_id, plan_id, verification_status, is_currently_on_campus)
      values ('51000000-0000-0000-0000-000000000015', 'business_local', 'approved', true)$$,
    '66. Insercion directa de seller_profiles procesada por trigger de seguridad'
);

reset role;
set role postgres;
select set_config('request.jwt.claims', '', true);
select set_config('request.jwt.claim.sub', '', true);

-- Test 67: Trigger fuerza plan 'free', 'pending' y campus false para usuario estándar
select results_eq(
    $$select plan_id, verification_status, is_currently_on_campus
      from public.seller_profiles where user_id = '51000000-0000-0000-0000-000000000015'$$,
    $$values ('free', 'pending', false)$$,
    '67. Trigger fuerza plan free, pending y campus false en insercion de usuario estandar'
);

-- Test 68: UPDATE de plan_id por usuario autenticado arroja 42501
select tests.authenticate_as('51000000-0000-0000-0000-000000000015');

select throws_ok(
    $$update public.seller_profiles set plan_id = 'business_local'$$,
    '42501',
    null,
    '68. Usuario autenticado no staff recibe 42501 al intentar escalar plan_id en UPDATE'
);

-- Test 69: Intento de activar is_currently_on_campus en plan free se ejecuta sin error
select lives_ok(
    $$update public.seller_profiles set is_currently_on_campus = true$$,
    '69. Update de campus ejecutado sin error sintactico'
);

reset role;
set role postgres;
select set_config('request.jwt.claims', '', true);
select set_config('request.jwt.claim.sub', '', true);

-- Test 70: Trigger fuerza is_currently_on_campus a false porque plan_id es free
select is(
    (select is_currently_on_campus from public.seller_profiles where user_id = '51000000-0000-0000-0000-000000000015'),
    false,
    '70. Plan free no puede activar is_currently_on_campus (forzado a false)'
);

-- =============================================================================
-- SECCIÓN 13: Alias y filtro semántico
-- =============================================================================

select tests.authenticate_as('51000000-0000-0000-0000-000000000016');

-- Test 71: Título con término prohibido ("Resuelvo examen de Cálculo 1") falla con 23514
select throws_ok(
    $$insert into public.marketplace_items (
        id, user_id, title, description, price, is_free, category, facultad, sede,
        contact_whatsapp, author_alias, status
      ) values (
        '52000000-0000-0000-0000-000000000161',
        '51000000-0000-0000-0000-000000000016',
        'Resuelvo examen de Cálculo 1',
        'Descripcion valida con mas de diez caracteres academicos',
        50,
        false,
        'libros_materiales',
        'todas',
        'central',
        '50255551616',
        'Estudiante Anónimo',
        'available'
      )$$,
    '23514',
    null,
    '71. Publicacion con termino prohibido (resuelvo examen) es rechazada con 23514'
);

-- Test 72: author_alias con nombre real o título profesional ("Ing. Juan Pérez") falla con 23514
select throws_ok(
    $$insert into public.marketplace_items (
        id, user_id, title, description, price, is_free, category, facultad, sede,
        contact_whatsapp, author_alias, status
      ) values (
        '52000000-0000-0000-0000-000000000162',
        '51000000-0000-0000-0000-000000000016',
        'Libro de Algebra Lineal',
        'Descripcion valida con mas de diez caracteres academicos',
        50,
        false,
        'libros_materiales',
        'todas',
        'central',
        '50255551616',
        'Ing. Juan Pérez',
        'available'
      )$$,
    '23514',
    null,
    '72. author_alias con nombre real o titulo profesional es rechazado con 23514'
);

-- Test 73: author_alias válido del catálogo ("Estudiante Anónimo") pasa exitosamente
select lives_ok(
    $$insert into public.marketplace_items (
        id, user_id, title, description, price, is_free, category, facultad, sede,
        contact_whatsapp, author_alias, status
      ) values (
        '52000000-0000-0000-0000-000000000016',
        '51000000-0000-0000-0000-000000000016',
        'Libro de Algebra Lineal',
        'Descripcion valida con mas de diez caracteres academicos',
        50,
        false,
        'libros_materiales',
        'todas',
        'central',
        '50255551616',
        'Estudiante Anónimo',
        'available'
      )$$,
    '73. author_alias valido del catalogo es aceptado'
);

-- =============================================================================
-- SECCIÓN 14: Art. 3 y Legal Hold
-- =============================================================================

reset role;
set role postgres;
select set_config('request.jwt.claims', '', true);
select set_config('request.jwt.claim.sub', '', true);

insert into public.marketplace_items (id, user_id, title, description, price, is_free, category, facultad, sede, contact_whatsapp, author_alias, status)
values ('52000000-0000-0000-0000-000000000170', '51000000-0000-0000-0000-000000000017', 'Item Legal Mod Test', 'Descripcion de prueba valida con mas de 10 car', 10, false, 'libros_materiales', 'todas', 'central', '50255551717', 'Estudiante Anónimo', 'available');

-- Autenticar como moderador
select tests.authenticate_as_moderator('51000000-0000-0000-0000-000000000018');

-- Test 74: Moderador puede actualizar moderation_status
select lives_ok(
    $$update public.marketplace_items set moderation_status = 1 where id = '52000000-0000-0000-0000-000000000170'$$,
    '74. Moderador puede actualizar moderation_status'
);

-- Test 75: Moderador NO puede modificar contenido (title/description/price) -> 42501
select throws_ok(
    $$update public.marketplace_items set title = 'Titulo cambiado por moderador' where id = '52000000-0000-0000-0000-000000000170'$$,
    '42501',
    null,
    '75. Moderador no puede alterar title/description/price (Art. 3)'
);

-- Test 76: Moderador fija is_legal_hold = true
select lives_ok(
    $$update public.marketplace_items set is_legal_hold = true where id = '52000000-0000-0000-0000-000000000170'$$,
    '76. Moderador puede fijar is_legal_hold=true'
);

-- Autenticar como autor original (Usuario 17)
select tests.authenticate_as('51000000-0000-0000-0000-000000000017');

-- Test 77: Autor intenta modificar contenido bajo legal hold -> 42501
select throws_ok(
    $$update public.marketplace_items set title = 'Titulo cambiado bajo legal hold' where id = '52000000-0000-0000-0000-000000000170'$$,
    '42501',
    null,
    '77. Publicacion con is_legal_hold=true no permite cambios de contenido por el autor (Art. 3)'
);

-- =============================================================================
-- SECCIÓN 15: Sponsor Request y resolución administrativa
-- =============================================================================

select tests.authenticate_as('51000000-0000-0000-0000-000000000019');

-- Test 78: Dueño registra sponsor_requests con plan_id = 'pro_student'
select lives_ok(
    $$insert into public.sponsor_requests (
        id, brand_name, contact_name, contact_phone, email, proposal_details, user_id, plan_id, status
      ) values (
        '53000000-0000-0000-0000-000000000019',
        'Emprendimiento Diecinueve',
        'Carlos Ruiz',
        '50255551919',
        'carlos19@test.com',
        'Propuesta comercial de articulos de dibujo tecnico',
        '51000000-0000-0000-0000-000000000019',
        'pro_student',
        'pending'
      )$$,
    '78. Dueño puede registrar solicitud de patrocinio con plan pro_student'
);

-- Autenticar como administrador
select tests.authenticate_as_admin('51000000-0000-0000-0000-000000000020');

-- Test 79: Administrador aprueba la solicitud
select lives_ok(
    $$update public.sponsor_requests
         set status = 'approved'
       where id = '53000000-0000-0000-0000-000000000019'$$,
    '79. Administrador puede aprobar solicitud de patrocinio'
);

reset role;
set role postgres;
select set_config('request.jwt.claims', '', true);
select set_config('request.jwt.claim.sub', '', true);

-- Test 80: seller_profiles del dueño queda actualizado a pro_student, approved y plan_expires_at futuro
select results_eq(
    $$select plan_id, verification_status, plan_expires_at > now()
      from public.seller_profiles where user_id = '51000000-0000-0000-0000-000000000019'$$,
    $$values ('pro_student', 'approved', true)$$,
    '80. Aprobacion actualiza seller_profiles a pro_student, approved y vigencia futura'
);

-- =============================================================================
-- SECCIÓN 16: Eliminación física denegada
-- =============================================================================

reset role;
set role postgres;
select set_config('request.jwt.claims', '', true);
select set_config('request.jwt.claim.sub', '', true);

insert into public.marketplace_items (id, user_id, title, description, price, is_free, category, facultad, sede, contact_whatsapp, author_alias, status)
values ('52000000-0000-0000-0000-000000000210', '51000000-0000-0000-0000-000000000021', 'Item Delete Test', 'Descripcion de prueba delete con mas de 10 car', 10, false, 'libros_materiales', 'todas', 'central', '50255552121', 'Estudiante Anónimo', 'available');

select tests.authenticate_as('51000000-0000-0000-0000-000000000021');

-- Test 81: Intento de DELETE por el autor es rechazado por política deny / falta de permiso
select throws_ok(
    $$delete from public.marketplace_items where id = '52000000-0000-0000-0000-000000000210'$$,
    '42501',
    null,
    '81. DELETE fisico en marketplace_items es denegado al autor por politica de seguridad'
);

reset role;
set role postgres;
select set_config('request.jwt.claims', '', true);
select set_config('request.jwt.claim.sub', '', true);

-- Test 82: La fila de marketplace_items permanece intacta
select ok(
    exists (
        select 1 from public.marketplace_items
        where id = '52000000-0000-0000-0000-000000000210'
    ),
    '82. La fila permanece intacta tras intento de DELETE'
);

-- =============================================================================
-- SECCIÓN 17: Privacidad de eventos de telemetría (RLS)
-- =============================================================================

reset role;
set role postgres;
select set_config('request.jwt.claims', '', true);
select set_config('request.jwt.claim.sub', '', true);

insert into public.marketplace_items (id, user_id, title, description, price, is_free, category, facultad, sede, contact_whatsapp, author_alias, status)
values ('52000000-0000-0000-0000-000000000220', '51000000-0000-0000-0000-000000000022', 'Item Event Privacy Test', 'Descripcion de prueba privacidad eventos mas diez car', 10, false, 'libros_materiales', 'todas', 'central', '50255552222', 'Estudiante Anónimo', 'available');

-- Usuario 22 interactúa con el ítem (click_whatsapp)
select tests.authenticate_as('51000000-0000-0000-0000-000000000022');
select public.track_marketplace_event('52000000-0000-0000-0000-000000000220', 'click_whatsapp');

-- Autenticar como Usuario 23 (otro usuario sin permisos de staff)
select tests.authenticate_as('51000000-0000-0000-0000-000000000023');

-- Test 83: Usuario 23 no puede consultar eventos ajenos por viewer_id (RLS retorna vacío)
select is_empty(
    $$select 1 from public.marketplace_item_events where viewer_id = '51000000-0000-0000-0000-000000000022'$$,
    '83. RLS impide a Usuario 23 ver eventos de navegacion de Usuario 22'
);

-- Test 84: Usuario 23 ve 0 eventos ajenos al consultar por item_id
select is(
    (select count(*) from public.marketplace_item_events where item_id = '52000000-0000-0000-0000-000000000220'),
    0::bigint,
    '84. Usuario 23 ve 0 eventos ajenos en marketplace_item_events'
);

-- -----------------------------------------------------------------------------
-- Finalización de la suite
-- -----------------------------------------------------------------------------
select * from finish();
rollback;
