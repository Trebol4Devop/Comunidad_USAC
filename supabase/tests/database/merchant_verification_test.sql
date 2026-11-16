-- =============================================================================
-- PEMTREE / Comunidad USAC · pgTAP Test: Verificación de Comerciantes USAC
-- Archivo: supabase/tests/database/merchant_verification_test.sql
-- Rama: feature/merchant-verification-db
-- =============================================================================

BEGIN;

SELECT plan(115);

CREATE EXTENSION IF NOT EXISTS pgtap;

-- Asegurar rol privilegiado inicial y claims limpios
RESET ROLE;
SET ROLE postgres;
SELECT set_config('request.jwt.claims', '', true);
SELECT set_config('request.jwt.claim.sub', '', true);
SELECT set_config('request.jwt.claim.role', '', true);
SELECT set_config('request.jwt.claim.email', '', true);

-- -----------------------------------------------------------------------------
-- Fixtures Globales: Identidades de prueba para Verificación de Comerciantes
-- -----------------------------------------------------------------------------
DO $$
DECLARE
    v_u1 uuid := '88000000-0000-0000-0000-000000000001'; -- comerciante principal
    v_u2 uuid := '88000000-0000-0000-0000-000000000002'; -- rate limit
    v_u3 uuid := '88000000-0000-0000-0000-000000000003'; -- duplicados y rechazo
    v_u4 uuid := '88000000-0000-0000-0000-000000000004'; -- comerciante con plan previo
    v_u5 uuid := '88000000-0000-0000-0000-000000000005'; -- estudiante verificado
    v_u6 uuid := '88000000-0000-0000-0000-000000000006'; -- usuario sin rol de staff
    v_mod uuid := '88000000-0000-0000-0000-000000000010'; -- moderador de staff
    v_adm uuid := '88000000-0000-0000-0000-000000000020'; -- admin de staff
BEGIN
    PERFORM tests.create_supabase_user(v_u1, 'comerciante1@test.com');
    PERFORM tests.create_supabase_user(v_u2, 'comerciante2@test.com');
    PERFORM tests.create_supabase_user(v_u3, 'comerciante3@test.com');
    PERFORM tests.create_supabase_user(v_u4, 'comerciante_plan@test.com');
    PERFORM tests.create_supabase_user(v_u5, 'estudiante_verificado@test.com');
    PERFORM tests.create_supabase_user(v_u6, 'usuario_comun@test.com');
    PERFORM tests.create_supabase_user(v_mod, 'staff_moderador@test.com');
    PERFORM tests.create_supabase_user(v_adm, 'staff_admin@test.com');

    -- Asignar roles de staff en public.user_roles
    INSERT INTO public.user_roles (user_id, role)
    VALUES (v_mod, 'moderator')
    ON CONFLICT (user_id) DO UPDATE SET role = 'moderator';

    INSERT INTO public.user_roles (user_id, role)
    VALUES (v_adm, 'admin')
    ON CONFLICT (user_id) DO UPDATE SET role = 'admin';

    -- Limpiar roles de usuarios comunes si existieran
    DELETE FROM public.user_roles WHERE user_id IN (v_u1, v_u2, v_u3, v_u4, v_u5, v_u6);

    -- Asegurar perfiles base
    INSERT INTO public.profiles (id, full_name, carrera, is_verified, verification_status, seller_verification_status)
    VALUES
        (v_u1, 'Comerciante Uno', 'sistemas', false, 'unverified', 'unverified'),
        (v_u2, 'Comerciante Dos', 'sistemas', false, 'unverified', 'unverified'),
        (v_u3, 'Comerciante Tres', 'sistemas', false, 'unverified', 'unverified'),
        (v_u4, 'Comerciante Con Plan', 'sistemas', false, 'unverified', 'unverified'),
        (v_u5, 'Estudiante Verificado', 'sistemas', true, 'verified', 'unverified'),
        (v_u6, 'Usuario Sin Rol', 'sistemas', false, 'unverified', 'unverified'),
        (v_mod, 'Moderador Staff', 'sistemas', true, 'verified', 'verified'),
        (v_adm, 'Admin Staff', 'sistemas', true, 'verified', 'verified')
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        carrera = EXCLUDED.carrera,
        is_verified = EXCLUDED.is_verified,
        verification_status = EXCLUDED.verification_status,
        seller_verification_status = EXCLUDED.seller_verification_status;

    -- Preconfigurar perfil del estudiante verificado u5
    UPDATE public.profiles
    SET is_verified = true,
        verification_status = 'verified',
        verification_method = 'ocr_document',
        verified_at = now()
    WHERE id = v_u5;

    -- Preconfigurar seller_profiles para u4 con plan_id = 'business_local'
    INSERT INTO public.seller_profiles (
        user_id,
        plan_id,
        seller_type,
        verification_status,
        business_name
    ) VALUES (
        v_u4,
        'business_local',
        'student',
        'pending',
        'Tienda Universitaria Original'
    ) ON CONFLICT (user_id) DO UPDATE SET
        plan_id = 'business_local',
        seller_type = 'student',
        verification_status = 'pending',
        business_name = 'Tienda Universitaria Original';
END $$;

-- =============================================================================
-- SECCIÓN 1: Estructura, Columnas, Restricciones CHECK, Índices y Moderation Jobs
-- =============================================================================

SELECT has_table('public', 'merchant_verification_requests', '1. Tabla public.merchant_verification_requests existe');
SELECT has_column('public', 'merchant_verification_requests', 'id', '2. Columna id existe');
SELECT has_column('public', 'merchant_verification_requests', 'user_id', '3. Columna user_id existe');
SELECT has_column('public', 'merchant_verification_requests', 'business_name', '4. Columna business_name existe');
SELECT has_column('public', 'merchant_verification_requests', 'dpi_hash', '5. Columna dpi_hash existe');
SELECT has_column('public', 'merchant_verification_requests', 'dpi_front_key', '6. Columna dpi_front_key existe');
SELECT has_column('public', 'merchant_verification_requests', 'dpi_back_key', '7. Columna dpi_back_key existe');
SELECT has_column('public', 'merchant_verification_requests', 'establishment_key', '8. Columna establishment_key existe');
SELECT has_column('public', 'merchant_verification_requests', 'establishment_note', '9. Columna establishment_note existe');
SELECT has_column('public', 'merchant_verification_requests', 'status', '10. Columna status existe');
SELECT has_column('public', 'merchant_verification_requests', 'rejection_reason', '11. Columna rejection_reason existe');
SELECT has_column('public', 'merchant_verification_requests', 'reviewed_by', '12. Columna reviewed_by existe');
SELECT has_column('public', 'merchant_verification_requests', 'reviewed_at', '13. Columna reviewed_at existe');
SELECT has_column('public', 'merchant_verification_requests', 'expires_at', '14. Columna expires_at existe');
SELECT has_column('public', 'merchant_verification_requests', 'created_at', '15. Columna created_at existe');
SELECT has_column('public', 'merchant_verification_requests', 'updated_at', '16. Columna updated_at existe');

-- Test 17: CHECK business_name < 2 falla
SELECT throws_ok(
    $$INSERT INTO public.merchant_verification_requests (
        user_id, business_name, dpi_hash
    ) VALUES (
        '88000000-0000-0000-0000-000000000001', 'A', 'abc'
    )$$,
    '23514',
    NULL,
    '17. CHECK de business_name rechaza nombres con longitud menor a 2'
);

-- Test 18: CHECK business_name > 80 falla
SELECT throws_ok(
    $$INSERT INTO public.merchant_verification_requests (
        user_id, business_name, dpi_hash
    ) VALUES (
        '88000000-0000-0000-0000-000000000001', repeat('X', 81), 'abc'
    )$$,
    '23514',
    NULL,
    '18. CHECK de business_name rechaza nombres con longitud mayor a 80'
);

-- Test 19: CHECK establishment_note > 160 falla
SELECT throws_ok(
    $$INSERT INTO public.merchant_verification_requests (
        user_id, business_name, dpi_hash, establishment_note
    ) VALUES (
        '88000000-0000-0000-0000-000000000001', 'Tienda Valida', 'abc', repeat('N', 161)
    )$$,
    '23514',
    NULL,
    '19. CHECK de establishment_note rechaza notas con longitud mayor a 160'
);

-- Test 20: CHECK status con valor inválido falla
SELECT throws_ok(
    $$INSERT INTO public.merchant_verification_requests (
        user_id, business_name, dpi_hash, status
    ) VALUES (
        '88000000-0000-0000-0000-000000000001', 'Tienda Valida', 'abc', 'in_progress'
    )$$,
    '23514',
    NULL,
    '20. CHECK de status rechaza estados no contemplados en contrato'
);

-- Índices normativos
SELECT has_index('public', 'merchant_verification_requests', 'idx_merchant_verification_requests_user_created', '21. Indice idx_merchant_verification_requests_user_created existe');
SELECT has_index('public', 'merchant_verification_requests', 'idx_merchant_verification_requests_status_expires', '22. Indice idx_merchant_verification_requests_status_expires existe');
SELECT has_index('public', 'merchant_verification_requests', 'idx_merchant_verification_requests_dpi_hash', '23. Indice idx_merchant_verification_requests_dpi_hash existe');
SELECT has_index('public', 'merchant_verification_requests', 'idx_merchant_verification_requests_keys', '24. Indice parcial idx_merchant_verification_requests_keys existe');

-- Test 25: moderation_jobs extendido acepta 'merchant_verification_requests'
SELECT lives_ok(
    $$INSERT INTO public.moderation_jobs (
        entity_table, entity_id, content_hash, priority, status
    ) VALUES (
        'merchant_verification_requests', gen_random_uuid(), 'hash_test_init', 40, 'pending'
    )$$,
    '25. moderation_jobs acepta entity_table = merchant_verification_requests'
);

-- =============================================================================
-- SECCIÓN 2: Creación Válida de Solicitud (§2.3 del Contrato)
-- =============================================================================

SELECT is(
    (public.admin_create_merchant_verification_request(
        '88000000-0000-0000-0000-000000000001',
        '88000000-0000-0000-0000-000000000001',
        'Librería Central USAC',
        '1234567890101',
        'pending/merchant/88000000-0000-0000-0000-000000000001/88000000-0000-0000-0000-000000000001/dpi_front.jpg',
        'pending/merchant/88000000-0000-0000-0000-000000000001/88000000-0000-0000-0000-000000000001/dpi_back.jpg',
        'pending/merchant/88000000-0000-0000-0000-000000000001/88000000-0000-0000-0000-000000000001/establishment.jpg',
        'Frente a la plaza de los mártires'
    ) ->> 'ok')::boolean,
    true,
    '26. Creacion valida de solicitud retorna ok: true'
);

SELECT is(
    (SELECT status FROM public.merchant_verification_requests WHERE id = '88000000-0000-0000-0000-000000000001'),
    'pending',
    '27. Solicitud creada tiene status pending'
);

SELECT is(
    (SELECT business_name FROM public.merchant_verification_requests WHERE id = '88000000-0000-0000-0000-000000000001'),
    'Librería Central USAC',
    '28. Solicitud creada conserva el business_name'
);

SELECT is(
    (SELECT length(dpi_hash) FROM public.merchant_verification_requests WHERE id = '88000000-0000-0000-0000-000000000001'),
    64,
    '29. dpi_hash tiene longitud exacta de 64 caracteres hex'
);

SELECT is(
    (SELECT dpi_hash FROM public.merchant_verification_requests WHERE id = '88000000-0000-0000-0000-000000000001'),
    private.hash_credential('1234567890101'),
    '30. dpi_hash coincide exactamente con private.hash_credential(dpi)'
);

SELECT is(
    (SELECT count(*) FROM public.merchant_verification_requests WHERE dpi_hash LIKE '%1234567890101%'),
    0::bigint,
    '31. Nunca se almacena el DPI en claro en la base de datos'
);

SELECT is(
    (SELECT seller_verification_status FROM public.profiles WHERE id = '88000000-0000-0000-0000-000000000001'),
    'pending',
    '32. profiles.seller_verification_status se actualiza a pending'
);

SELECT is(
    (SELECT is_verified FROM public.profiles WHERE id = '88000000-0000-0000-0000-000000000001'),
    false,
    '33. Creación de solicitud de comerciante no altera is_verified (sigue false)'
);

SELECT is(
    (SELECT priority FROM public.moderation_jobs
     WHERE entity_table = 'merchant_verification_requests'
       AND entity_id = '88000000-0000-0000-0000-000000000001'),
    40,
    '34. moderation_jobs se inserta con prioridad 40'
);

SELECT is(
    (SELECT has_image FROM public.moderation_jobs
     WHERE entity_table = 'merchant_verification_requests'
       AND entity_id = '88000000-0000-0000-0000-000000000001'),
    true,
    '35. moderation_jobs se inserta con has_image = true'
);

SELECT is(
    (SELECT content_hash FROM public.moderation_jobs
     WHERE entity_table = 'merchant_verification_requests'
       AND entity_id = '88000000-0000-0000-0000-000000000001'),
    'merchant_request:88000000-0000-0000-0000-000000000001',
    '36. moderation_jobs posee content_hash = merchant_request:UUID'
);

SELECT is(
    (SELECT status FROM public.moderation_jobs
     WHERE entity_table = 'merchant_verification_requests'
       AND entity_id = '88000000-0000-0000-0000-000000000001'),
    'pending',
    '37. moderation_jobs posee status = pending'
);

-- =============================================================================
-- SECCIÓN 3: Validaciones de Entrada y Manejo de Errores
-- =============================================================================

-- Test 38: Invocación por rol authenticated debe fallar por permisos
SELECT tests.authenticate_as('88000000-0000-0000-0000-000000000001');
SELECT throws_ok(
    $$SELECT public.admin_create_merchant_verification_request(
        gen_random_uuid(),
        '88000000-0000-0000-0000-000000000001',
        'Tienda Directa',
        '1234567890101',
        'k1', 'k2', 'k3'
    )$$,
    '42501',
    NULL,
    '38. admin_create_merchant_verification_request deniega ejecucion a authenticated'
);

RESET ROLE;
SET ROLE postgres;
SELECT set_config('request.jwt.claims', '', true);
SELECT set_config('request.jwt.claim.sub', '', true);
SELECT set_config('request.jwt.claim.role', '', true);
SELECT set_config('request.jwt.claim.email', '', true);

-- Test 39 a 42: Validaciones de business_name
SELECT is(
    public.admin_create_merchant_verification_request(
        gen_random_uuid(), '88000000-0000-0000-0000-000000000001',
        NULL, '1234567890101', 'k1', 'k2', 'k3'
    ),
    '{"ok": false, "code": "invalid_business_name"}'::jsonb,
    '39. business_name NULL retorna invalid_business_name'
);

SELECT is(
    public.admin_create_merchant_verification_request(
        gen_random_uuid(), '88000000-0000-0000-0000-000000000001',
        'A', '1234567890101', 'k1', 'k2', 'k3'
    ),
    '{"ok": false, "code": "invalid_business_name"}'::jsonb,
    '40. business_name < 2 chars retorna invalid_business_name'
);

SELECT is(
    public.admin_create_merchant_verification_request(
        gen_random_uuid(), '88000000-0000-0000-0000-000000000001',
        repeat('X', 81), '1234567890101', 'k1', 'k2', 'k3'
    ),
    '{"ok": false, "code": "invalid_business_name"}'::jsonb,
    '41. business_name > 80 chars retorna invalid_business_name'
);

SELECT is(
    public.admin_create_merchant_verification_request(
        gen_random_uuid(), '88000000-0000-0000-0000-000000000001',
        '    ', '1234567890101', 'k1', 'k2', 'k3'
    ),
    '{"ok": false, "code": "invalid_business_name"}'::jsonb,
    '42. business_name con solo espacios tras btrim retorna invalid_business_name'
);

-- Test 43 a 48: Validaciones de DPI
SELECT is(
    public.admin_create_merchant_verification_request(
        gen_random_uuid(), '88000000-0000-0000-0000-000000000001',
        'Tienda Valida', NULL, 'k1', 'k2', 'k3'
    ),
    '{"ok": false, "code": "invalid_dpi"}'::jsonb,
    '43. dpi_number NULL retorna invalid_dpi'
);

SELECT is(
    public.admin_create_merchant_verification_request(
        gen_random_uuid(), '88000000-0000-0000-0000-000000000001',
        'Tienda Valida', '123456789010', 'k1', 'k2', 'k3'
    ),
    '{"ok": false, "code": "invalid_dpi"}'::jsonb,
    '44. dpi_number con 12 digitos retorna invalid_dpi'
);

SELECT is(
    public.admin_create_merchant_verification_request(
        gen_random_uuid(), '88000000-0000-0000-0000-000000000001',
        'Tienda Valida', '12345678901010', 'k1', 'k2', 'k3'
    ),
    '{"ok": false, "code": "invalid_dpi"}'::jsonb,
    '45. dpi_number con 14 digitos retorna invalid_dpi'
);

SELECT is(
    public.admin_create_merchant_verification_request(
        gen_random_uuid(), '88000000-0000-0000-0000-000000000001',
        'Tienda Valida', '123456789ABCD', 'k1', 'k2', 'k3'
    ),
    '{"ok": false, "code": "invalid_dpi"}'::jsonb,
    '46. dpi_number con caracteres alfabeticos retorna invalid_dpi'
);

SELECT is(
    public.admin_create_merchant_verification_request(
        gen_random_uuid(), '88000000-0000-0000-0000-000000000001',
        'Tienda Valida', '1234567890001', 'k1', 'k2', 'k3'
    ),
    '{"ok": false, "code": "invalid_dpi"}'::jsonb,
    '47. dpi_number con codigo de departamento 00 retorna invalid_dpi'
);

SELECT is(
    public.admin_create_merchant_verification_request(
        gen_random_uuid(), '88000000-0000-0000-0000-000000000001',
        'Tienda Valida', '1234567892301', 'k1', 'k2', 'k3'
    ),
    '{"ok": false, "code": "invalid_dpi"}'::jsonb,
    '48. dpi_number con codigo de departamento 23 retorna invalid_dpi'
);

-- Test 49 a 54: Validaciones de Claves R2
SELECT is(
    public.admin_create_merchant_verification_request(
        '88000000-0000-0000-0000-000000000099', '88000000-0000-0000-0000-000000000001',
        'Tienda Valida', '1234567890101',
        NULL, 'k2', 'k3'
    ),
    '{"ok": false, "code": "invalid_keys"}'::jsonb,
    '49. front_key NULL retorna invalid_keys'
);

SELECT is(
    public.admin_create_merchant_verification_request(
        '88000000-0000-0000-0000-000000000099', '88000000-0000-0000-0000-000000000001',
        'Tienda Valida', '1234567890101',
        'pending/merchant/88000000-0000-0000-0000-000000000001/88000000-0000-0000-0000-000000000099/same.jpg',
        'pending/merchant/88000000-0000-0000-0000-000000000001/88000000-0000-0000-0000-000000000099/same.jpg',
        'pending/merchant/88000000-0000-0000-0000-000000000001/88000000-0000-0000-0000-000000000099/est.jpg'
    ),
    '{"ok": false, "code": "invalid_keys"}'::jsonb,
    '50. front_key y back_key identicas retorna invalid_keys'
);

SELECT is(
    public.admin_create_merchant_verification_request(
        '88000000-0000-0000-0000-000000000099', '88000000-0000-0000-0000-000000000001',
        'Tienda Valida', '1234567890101',
        'pending/otro_path/front.jpg',
        'pending/merchant/88000000-0000-0000-0000-000000000001/88000000-0000-0000-0000-000000000099/back.jpg',
        'pending/merchant/88000000-0000-0000-0000-000000000001/88000000-0000-0000-0000-000000000099/est.jpg'
    ),
    '{"ok": false, "code": "invalid_keys"}'::jsonb,
    '51. Clave que no comienza con el prefijo normativo retorna invalid_keys'
);

SELECT is(
    public.admin_create_merchant_verification_request(
        '88000000-0000-0000-0000-000000000099', '88000000-0000-0000-0000-000000000001',
        'Tienda Valida', '1234567890101',
        -- Clave con prefijo de otro usuario (u2)
        'pending/merchant/88000000-0000-0000-0000-000000000002/88000000-0000-0000-0000-000000000099/front.jpg',
        'pending/merchant/88000000-0000-0000-0000-000000000001/88000000-0000-0000-0000-000000000099/back.jpg',
        'pending/merchant/88000000-0000-0000-0000-000000000001/88000000-0000-0000-0000-000000000099/est.jpg'
    ),
    '{"ok": false, "code": "invalid_keys"}'::jsonb,
    '52. Clave perteneciente a otro usuario retorna invalid_keys'
);

SELECT is(
    public.admin_create_merchant_verification_request(
        '88000000-0000-0000-0000-000000000099', '88000000-0000-0000-0000-000000000001',
        'Tienda Valida', '1234567890101',
        -- Clave con prefijo de otra solicitud
        'pending/merchant/88000000-0000-0000-0000-000000000001/88000000-0000-0000-0000-000000000001/front.jpg',
        'pending/merchant/88000000-0000-0000-0000-000000000001/88000000-0000-0000-0000-000000000099/back.jpg',
        'pending/merchant/88000000-0000-0000-0000-000000000001/88000000-0000-0000-0000-000000000099/est.jpg'
    ),
    '{"ok": false, "code": "invalid_keys"}'::jsonb,
    '53. Clave perteneciente a otra solicitud retorna invalid_keys'
);

SELECT is(
    public.admin_create_merchant_verification_request(
        '88000000-0000-0000-0000-000000000099', '88000000-0000-0000-0000-000000000001',
        'Tienda Valida', '1234567890101',
        -- Clave vacía o igual al prefijo sin nombre de archivo
        'pending/merchant/88000000-0000-0000-0000-000000000001/88000000-0000-0000-0000-000000000099/',
        'pending/merchant/88000000-0000-0000-0000-000000000001/88000000-0000-0000-0000-000000000099/back.jpg',
        'pending/merchant/88000000-0000-0000-0000-000000000001/88000000-0000-0000-0000-000000000099/est.jpg'
    ),
    '{"ok": false, "code": "invalid_keys"}'::jsonb,
    '54. Clave sin nombre de archivo retorna invalid_keys'
);

-- =============================================================================
-- SECCIÓN 4: Rate Limiting (Máximo 2 solicitudes en 24h)
-- =============================================================================

SELECT is(
    (public.admin_create_merchant_verification_request(
        '88000000-0000-0000-0000-000000000021', '88000000-0000-0000-0000-000000000002',
        'Negocio Dos', '2222222220101',
        'pending/merchant/88000000-0000-0000-0000-000000000002/88000000-0000-0000-0000-000000000021/front.jpg',
        'pending/merchant/88000000-0000-0000-0000-000000000002/88000000-0000-0000-0000-000000000021/back.jpg',
        'pending/merchant/88000000-0000-0000-0000-000000000002/88000000-0000-0000-0000-000000000021/est.jpg'
    ) ->> 'ok')::boolean,
    true,
    '55. Intento 1 de usuario 2 es aceptado'
);

SELECT is(
    (public.admin_create_merchant_verification_request(
        '88000000-0000-0000-0000-000000000022', '88000000-0000-0000-0000-000000000002',
        'Negocio Dos Reintento', '2222222220101',
        'pending/merchant/88000000-0000-0000-0000-000000000002/88000000-0000-0000-0000-000000000022/front.jpg',
        'pending/merchant/88000000-0000-0000-0000-000000000002/88000000-0000-0000-0000-000000000022/back.jpg',
        'pending/merchant/88000000-0000-0000-0000-000000000002/88000000-0000-0000-0000-000000000022/est.jpg'
    ) ->> 'ok')::boolean,
    true,
    '56. Intento 2 de usuario 2 es aceptado'
);

SELECT is(
    public.admin_create_merchant_verification_request(
        '88000000-0000-0000-0000-000000000023', '88000000-0000-0000-0000-000000000002',
        'Negocio Dos Tercero', '2222222220101',
        'pending/merchant/88000000-0000-0000-0000-000000000002/88000000-0000-0000-0000-000000000023/front.jpg',
        'pending/merchant/88000000-0000-0000-0000-000000000002/88000000-0000-0000-0000-000000000023/back.jpg',
        'pending/merchant/88000000-0000-0000-0000-000000000002/88000000-0000-0000-0000-000000000023/est.jpg'
    ),
    '{"ok": false, "code": "rate_limited"}'::jsonb,
    '57. Intento 3 dentro de 24h es rechazado con rate_limited'
);

-- =============================================================================
-- SECCIÓN 5: Detección de DPI Duplicado (§2.3 del Contrato)
-- =============================================================================

SELECT is(
    public.admin_create_merchant_verification_request(
        '88000000-0000-0000-0000-000000000031', '88000000-0000-0000-0000-000000000003',
        'Comercio Duplicado',
        '1234567890101', -- Ya tomado por u1 (estado pending)
        'pending/merchant/88000000-0000-0000-0000-000000000003/88000000-0000-0000-0000-000000000031/front.jpg',
        'pending/merchant/88000000-0000-0000-0000-000000000003/88000000-0000-0000-0000-000000000031/back.jpg',
        'pending/merchant/88000000-0000-0000-0000-000000000003/88000000-0000-0000-0000-000000000031/est.jpg'
    ),
    '{"ok": false, "code": "credential_unavailable"}'::jsonb,
    '58. DPI en estado pending en otra cuenta es rechazado con credential_unavailable'
);

-- =============================================================================
-- SECCIÓN 6: Seguridad RLS y Permisos en merchant_verification_requests
-- =============================================================================

-- Test 59: Dueño de la solicitud ve solo su fila
SELECT tests.authenticate_as('88000000-0000-0000-0000-000000000001');
SELECT is(
    (SELECT count(*) FROM public.merchant_verification_requests),
    1::bigint,
    '59. Duenio ve unicamente su propia solicitud'
);

-- Test 60: Otro usuario (u3) que no tiene solicitudes activas ve 0 filas
SELECT tests.authenticate_as('88000000-0000-0000-0000-000000000003');
SELECT is(
    (SELECT count(*) FROM public.merchant_verification_requests),
    0::bigint,
    '60. Usuario ajeno ve 0 solicitudes'
);

-- Test 61: Moderador de staff ve todas las solicitudes
SELECT tests.authenticate_as_moderator('88000000-0000-0000-0000-000000000010');
SELECT is(
    (SELECT count(*) >= 3 FROM public.merchant_verification_requests),
    true,
    '61. Moderador de staff puede consultar todas las solicitudes'
);

-- Test 62: Admin de staff ve todas las solicitudes
SELECT tests.authenticate_as_admin('88000000-0000-0000-0000-000000000020');
SELECT is(
    (SELECT count(*) >= 3 FROM public.merchant_verification_requests),
    true,
    '62. Admin de staff puede consultar todas las solicitudes'
);

-- Test 63 a 65: Usuario authenticated no puede INSERT, UPDATE ni DELETE directo
SELECT tests.authenticate_as('88000000-0000-0000-0000-000000000001');
SELECT throws_ok(
    $$INSERT INTO public.merchant_verification_requests (
        user_id, business_name, dpi_hash
    ) VALUES (
        '88000000-0000-0000-0000-000000000001', 'Directo', 'abc'
    )$$,
    '42501',
    NULL,
    '63. Usuario authenticated no tiene permiso INSERT directo'
);

SELECT throws_ok(
    $$UPDATE public.merchant_verification_requests
      SET status = 'approved'
      WHERE id = '88000000-0000-0000-0000-000000000001'$$,
    '42501',
    NULL,
    '64. Usuario authenticated no tiene permiso UPDATE directo'
);

SELECT throws_ok(
    $$DELETE FROM public.merchant_verification_requests
      WHERE id = '88000000-0000-0000-0000-000000000001'$$,
    '42501',
    NULL,
    '65. Usuario authenticated no tiene permiso DELETE directo'
);

-- Test 66: Rol anon no tiene permiso SELECT
SELECT tests.authenticate_as_anon();
SELECT throws_ok(
    $$SELECT count(*) FROM public.merchant_verification_requests$$,
    '42501',
    NULL,
    '66. anon no tiene permiso SELECT sobre merchant_verification_requests'
);

RESET ROLE;
SET ROLE postgres;
SELECT set_config('request.jwt.claims', '', true);
SELECT set_config('request.jwt.claim.sub', '', true);
SELECT set_config('request.jwt.claim.role', '', true);
SELECT set_config('request.jwt.claim.email', '', true);

-- =============================================================================
-- SECCIÓN 7: Aprobación de Solicitud (§2.4 del Contrato)
-- =============================================================================

-- Test 67: Revisor sin rol de staff en user_roles falla con not_authorized
SELECT is(
    public.admin_review_merchant_verification(
        '88000000-0000-0000-0000-000000000006', -- usuario común sin rol staff
        '88000000-0000-0000-0000-000000000001',
        'approved'
    ),
    '{"ok": false, "code": "not_authorized"}'::jsonb,
    '67. Revisor sin rol de staff es rechazado con not_authorized'
);

-- Test 68: Revisor NULL falla con not_authorized
SELECT is(
    public.admin_review_merchant_verification(
        NULL,
        '88000000-0000-0000-0000-000000000001',
        'approved'
    ),
    '{"ok": false, "code": "not_authorized"}'::jsonb,
    '68. Revisor NULL es rechazado con not_authorized'
);

-- Test 69: Decisión inválida
SELECT is(
    public.admin_review_merchant_verification(
        '88000000-0000-0000-0000-000000000010',
        '88000000-0000-0000-0000-000000000001',
        'maybe'
    ),
    '{"ok": false, "code": "invalid_decision"}'::jsonb,
    '69. Decision invalida es rechazada con invalid_decision'
);

-- Test 70: Solicitud inexistente
SELECT is(
    public.admin_review_merchant_verification(
        '88000000-0000-0000-0000-000000000010',
        gen_random_uuid(),
        'approved'
    ),
    '{"ok": false, "code": "not_found"}'::jsonb,
    '70. Solicitud no encontrada retorna not_found'
);

-- Test 71: Aprobación válida por moderador
SELECT is(
    public.admin_review_merchant_verification(
        '88000000-0000-0000-0000-000000000010',
        '88000000-0000-0000-0000-000000000001',
        'approved'
    ),
    jsonb_build_object(
        'ok', true,
        'status', 'approved',
        'request_id', '88000000-0000-0000-0000-000000000001'::uuid
    ),
    '71. Aprobacion exitosa retorna estructura correcta'
);

-- Verificaciones de estado tras aprobación
SELECT is(
    (SELECT status FROM public.merchant_verification_requests WHERE id = '88000000-0000-0000-0000-000000000001'),
    'approved',
    '72. merchant_verification_requests queda en status approved'
);

SELECT is(
    (SELECT reviewed_by FROM public.merchant_verification_requests WHERE id = '88000000-0000-0000-0000-000000000001'),
    '88000000-0000-0000-0000-000000000010'::uuid,
    '73. reviewed_by almacena el UUID del moderador'
);

SELECT is(
    (SELECT reviewed_at IS NOT NULL FROM public.merchant_verification_requests WHERE id = '88000000-0000-0000-0000-000000000001'),
    true,
    '74. reviewed_at queda registrado con timestamp no nulo'
);

SELECT is(
    (SELECT rejection_reason FROM public.merchant_verification_requests WHERE id = '88000000-0000-0000-0000-000000000001'),
    NULL,
    '75. rejection_reason es NULL al aprobar'
);

SELECT is(
    (SELECT dpi_front_key IS NOT NULL AND dpi_back_key IS NOT NULL AND establishment_key IS NOT NULL
     FROM public.merchant_verification_requests WHERE id = '88000000-0000-0000-0000-000000000001'),
    true,
    '76. Claves R2 se conservan intactas tras aprobacion (no se borran ni nulan aqui)'
);

SELECT is(
    (SELECT seller_type FROM public.seller_profiles WHERE user_id = '88000000-0000-0000-0000-000000000001'),
    'local_business',
    '77. seller_profiles queda con seller_type = local_business'
);

SELECT is(
    (SELECT verification_status FROM public.seller_profiles WHERE user_id = '88000000-0000-0000-0000-000000000001'),
    'approved',
    '78. seller_profiles queda con verification_status = approved'
);

SELECT is(
    (SELECT business_name FROM public.seller_profiles WHERE user_id = '88000000-0000-0000-0000-000000000001'),
    'Librería Central USAC',
    '79. seller_profiles sincroniza el business_name de la solicitud'
);

SELECT is(
    (SELECT seller_verification_status FROM public.profiles WHERE id = '88000000-0000-0000-0000-000000000001'),
    'verified',
    '80. profiles.seller_verification_status se actualiza a verified'
);

SELECT is(
    (SELECT seller_verified_at IS NOT NULL FROM public.profiles WHERE id = '88000000-0000-0000-0000-000000000001'),
    true,
    '81. profiles.seller_verified_at queda registrado'
);

SELECT is(
    (SELECT seller_verified_by FROM public.profiles WHERE id = '88000000-0000-0000-0000-000000000001'),
    '88000000-0000-0000-0000-000000000010'::uuid,
    '82. profiles.seller_verified_by almacena el ID del revisor'
);

SELECT is(
    (SELECT is_verified FROM public.profiles WHERE id = '88000000-0000-0000-0000-000000000001'),
    false,
    '83. Aprobar comerciante no otorga verificacion estudiantil (is_verified sigue false)'
);

SELECT is(
    (SELECT status FROM public.moderation_jobs
     WHERE entity_table = 'merchant_verification_requests'
       AND entity_id = '88000000-0000-0000-0000-000000000001'),
    'done',
    '84. moderation_jobs queda en status done tras aprobacion'
);

SELECT is(
    public.is_verified_seller('88000000-0000-0000-0000-000000000001'),
    true,
    '85. is_verified_seller devuelve true para comerciante aprobado'
);

-- Test 86: Comerciante verificado puede insertar items en marketplace
SELECT tests.authenticate_as('88000000-0000-0000-0000-000000000001');
SELECT lives_ok(
    $$INSERT INTO public.marketplace_items (
        id, user_id, title, description, price, category, status, contact_whatsapp
    ) VALUES (
        gen_random_uuid(),
        '88000000-0000-0000-0000-000000000001',
        'Calculadora Científica USAC',
        'Calculadora para ingeniería',
        150.00,
        'libros_materiales',
        'available',
        '50212345678'
    )$$,
    '86. Comerciante aprobado puede publicar productos en el marketplace'
);

RESET ROLE;
SET ROLE postgres;
SELECT set_config('request.jwt.claims', '', true);
SELECT set_config('request.jwt.claim.sub', '', true);
SELECT set_config('request.jwt.claim.role', '', true);
SELECT set_config('request.jwt.claim.email', '', true);

-- Test 87: DPI en estado approved en otra cuenta también es rechazado con credential_unavailable
SELECT is(
    public.admin_create_merchant_verification_request(
        '88000000-0000-0000-0000-000000000032', '88000000-0000-0000-0000-000000000003',
        'Comercio Duplicado 2',
        '1234567890101', -- Aprobado en u1
        'pending/merchant/88000000-0000-0000-0000-000000000003/88000000-0000-0000-0000-000000000032/front.jpg',
        'pending/merchant/88000000-0000-0000-0000-000000000003/88000000-0000-0000-0000-000000000032/back.jpg',
        'pending/merchant/88000000-0000-0000-0000-000000000003/88000000-0000-0000-0000-000000000032/est.jpg'
    ),
    '{"ok": false, "code": "credential_unavailable"}'::jsonb,
    '87. DPI en estado approved en otra cuenta es rechazado con credential_unavailable'
);

-- =============================================================================
-- SECCIÓN 8: Rechazo de Solicitud (§2.4 del Contrato)
-- =============================================================================

-- Crear solicitud limpia para u3
SELECT is(
    (public.admin_create_merchant_verification_request(
        '88000000-0000-0000-0000-000000000033', '88000000-0000-0000-0000-000000000003',
        'Comercio Tres', '3333333330101',
        'pending/merchant/88000000-0000-0000-0000-000000000003/88000000-0000-0000-0000-000000000033/front.jpg',
        'pending/merchant/88000000-0000-0000-0000-000000000003/88000000-0000-0000-0000-000000000033/back.jpg',
        'pending/merchant/88000000-0000-0000-0000-000000000003/88000000-0000-0000-0000-000000000033/est.jpg'
    ) ->> 'ok')::boolean,
    true,
    '88. Solicitud para usuario 3 creada correctamente'
);

-- Rechazo por moderador con motivo
SELECT is(
    public.admin_review_merchant_verification(
        '88000000-0000-0000-0000-000000000010',
        '88000000-0000-0000-0000-000000000033',
        'rejected',
        'Documentos borrosos o establecimiento no identificable'
    ),
    jsonb_build_object(
        'ok', true,
        'status', 'rejected',
        'request_id', '88000000-0000-0000-0000-000000000033'::uuid
    ),
    '89. Rechazo de solicitud retorna estructura correcta'
);

SELECT is(
    (SELECT status FROM public.merchant_verification_requests WHERE id = '88000000-0000-0000-0000-000000000033'),
    'rejected',
    '90. Solicitud rechazada queda en status rejected'
);

SELECT is(
    (SELECT rejection_reason FROM public.merchant_verification_requests WHERE id = '88000000-0000-0000-0000-000000000033'),
    'Documentos borrosos o establecimiento no identificable',
    '91. rejection_reason almacena el motivo enviado por el moderador'
);

SELECT is(
    (SELECT reviewed_by FROM public.merchant_verification_requests WHERE id = '88000000-0000-0000-0000-000000000033'),
    '88000000-0000-0000-0000-000000000010'::uuid,
    '92. reviewed_by almacena el ID del moderador que rechazo'
);

SELECT is(
    (SELECT dpi_front_key IS NOT NULL AND dpi_back_key IS NOT NULL AND establishment_key IS NOT NULL
     FROM public.merchant_verification_requests WHERE id = '88000000-0000-0000-0000-000000000033'),
    true,
    '93. Claves R2 siguen intactas tras rechazo (purga delegada a Worker/cron)'
);

SELECT is(
    (SELECT seller_verification_status FROM public.profiles WHERE id = '88000000-0000-0000-0000-000000000003'),
    'rejected',
    '94. profiles.seller_verification_status se actualiza a rejected'
);

SELECT is(
    (SELECT seller_verified_at FROM public.profiles WHERE id = '88000000-0000-0000-0000-000000000003'),
    NULL,
    '95. profiles.seller_verified_at es NULL tras rechazo'
);

SELECT is(
    (SELECT status FROM public.moderation_jobs
     WHERE entity_table = 'merchant_verification_requests'
       AND entity_id = '88000000-0000-0000-0000-000000000033'),
    'done',
    '96. moderation_jobs queda en done tras rechazo'
);

-- =============================================================================
-- SECCIÓN 9: Rechazo de Comerciante No Degrada al Estudiante Verificado
-- =============================================================================

-- u5 ya es estudiante verificado (is_verified = true, verification_status = 'verified')
SELECT is(
    (public.admin_create_merchant_verification_request(
        '88000000-0000-0000-0000-000000000051', '88000000-0000-0000-0000-000000000005',
        'Estudiante Negocio', '5555555550101',
        'pending/merchant/88000000-0000-0000-0000-000000000005/88000000-0000-0000-0000-000000000051/front.jpg',
        'pending/merchant/88000000-0000-0000-0000-000000000005/88000000-0000-0000-0000-000000000051/back.jpg',
        'pending/merchant/88000000-0000-0000-0000-000000000005/88000000-0000-0000-0000-000000000051/est.jpg'
    ) ->> 'ok')::boolean,
    true,
    '97. Solicitud de comerciante para estudiante verificado creada'
);

SELECT is(
    (public.admin_review_merchant_verification(
        '88000000-0000-0000-0000-000000000010',
        '88000000-0000-0000-0000-000000000051',
        'rejected',
        'Falta de permisos del establecimiento'
    ) ->> 'ok')::boolean,
    true,
    '98. Rechazo de solicitud de comerciante completado'
);

SELECT is(
    (SELECT seller_verification_status FROM public.profiles WHERE id = '88000000-0000-0000-0000-000000000005'),
    'rejected',
    '99. profiles.seller_verification_status queda rejected'
);

SELECT is(
    (SELECT is_verified FROM public.profiles WHERE id = '88000000-0000-0000-0000-000000000005'),
    true,
    '100. profiles.is_verified de estudiante NO se degrada (se mantiene true)'
);

SELECT is(
    (SELECT verification_status FROM public.profiles WHERE id = '88000000-0000-0000-0000-000000000005'),
    'verified',
    '101. profiles.verification_status de estudiante se mantiene verified'
);

-- =============================================================================
-- SECCIÓN 10: Preservación de plan_id en seller_profiles al Aprobar
-- =============================================================================

-- u4 ya contaba con plan_id = 'business_local' antes de solicitar
SELECT is(
    (public.admin_create_merchant_verification_request(
        '88000000-0000-0000-0000-000000000041', '88000000-0000-0000-0000-000000000004',
        'Tienda Plan Preservado', '4444444440101',
        'pending/merchant/88000000-0000-0000-0000-000000000004/88000000-0000-0000-0000-000000000041/front.jpg',
        'pending/merchant/88000000-0000-0000-0000-000000000004/88000000-0000-0000-0000-000000000041/back.jpg',
        'pending/merchant/88000000-0000-0000-0000-000000000004/88000000-0000-0000-0000-000000000041/est.jpg'
    ) ->> 'ok')::boolean,
    true,
    '102. Solicitud para usuario 4 (con plan previo) creada'
);

SELECT is(
    (public.admin_review_merchant_verification(
        '88000000-0000-0000-0000-000000000020', -- aprobado por admin
        '88000000-0000-0000-0000-000000000041',
        'approved'
    ) ->> 'ok')::boolean,
    true,
    '103. Aprobacion de usuario 4 exitosa'
);

SELECT is(
    (SELECT seller_type FROM public.seller_profiles WHERE user_id = '88000000-0000-0000-0000-000000000004'),
    'local_business',
    '104. seller_profiles.seller_type se actualiza a local_business'
);

SELECT is(
    (SELECT verification_status FROM public.seller_profiles WHERE user_id = '88000000-0000-0000-0000-000000000004'),
    'approved',
    '105. seller_profiles.verification_status se actualiza a approved'
);

SELECT is(
    (SELECT business_name FROM public.seller_profiles WHERE user_id = '88000000-0000-0000-0000-000000000004'),
    'Tienda Plan Preservado',
    '106. seller_profiles.business_name se actualiza al nombre verificado'
);

SELECT is(
    (SELECT plan_id FROM public.seller_profiles WHERE user_id = '88000000-0000-0000-0000-000000000004'),
    'business_local',
    '107. seller_profiles CONSERVA su plan_id previo (business_local)'
);

-- =============================================================================
-- SECCIÓN 11: Limpieza de Claves R2 (public.admin_clear_merchant_keys)
-- =============================================================================

-- Test 108: Llamada por authenticated falla con 42501
SELECT tests.authenticate_as('88000000-0000-0000-0000-000000000001');
SELECT throws_ok(
    $$SELECT public.admin_clear_merchant_keys('88000000-0000-0000-0000-000000000001')$$,
    '42501',
    NULL,
    '108. admin_clear_merchant_keys deniega ejecucion a authenticated'
);

RESET ROLE;
SET ROLE postgres;
SELECT set_config('request.jwt.claims', '', true);
SELECT set_config('request.jwt.claim.sub', '', true);
SELECT set_config('request.jwt.claim.role', '', true);
SELECT set_config('request.jwt.claim.email', '', true);

-- Test 109: Ejecución autorizada
SELECT lives_ok(
    $$SELECT public.admin_clear_merchant_keys('88000000-0000-0000-0000-000000000001')$$,
    '109. admin_clear_merchant_keys completa con exito para llamada autorizada'
);

SELECT is(
    (SELECT dpi_front_key FROM public.merchant_verification_requests WHERE id = '88000000-0000-0000-0000-000000000001'),
    NULL,
    '110. dpi_front_key queda en NULL'
);

SELECT is(
    (SELECT dpi_back_key FROM public.merchant_verification_requests WHERE id = '88000000-0000-0000-0000-000000000001'),
    NULL,
    '111. dpi_back_key queda en NULL'
);

SELECT is(
    (SELECT establishment_key FROM public.merchant_verification_requests WHERE id = '88000000-0000-0000-0000-000000000001'),
    NULL,
    '112. establishment_key queda en NULL'
);

SELECT is(
    (SELECT status FROM public.merchant_verification_requests WHERE id = '88000000-0000-0000-0000-000000000001'),
    'approved',
    '113. status de la solicitud permanece intacto (approved) tras limpiar claves'
);

SELECT is(
    (SELECT count(*) FROM public.merchant_verification_requests
     WHERE id = '88000000-0000-0000-0000-000000000001'
       AND (dpi_front_key IS NOT NULL OR dpi_back_key IS NOT NULL OR establishment_key IS NOT NULL)),
    0::bigint,
    '114. La fila ya no califica en el indice parcial de claves activas'
);

-- Test 115: Comprobar idempotencia y seguridad con p_request_id nulo
SELECT lives_ok(
    $$SELECT public.admin_clear_merchant_keys(NULL)$$,
    '115. admin_clear_merchant_keys con NULL no produce error'
);

SELECT * FROM finish();
ROLLBACK;
