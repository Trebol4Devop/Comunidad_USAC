-- =============================================================================
-- PEMTREE / Comunidad USAC · pgTAP Test: Verificación Estudiantil USAC
-- Archivo: supabase/tests/database/student_verification_test.sql
-- Rama: feature/verification-db-hardening
-- =============================================================================

BEGIN;

SELECT plan(95);

CREATE EXTENSION IF NOT EXISTS pgtap;

-- Asegurar rol privilegiado inicial y claims limpios
RESET ROLE;
SET ROLE postgres;
SELECT set_config('request.jwt.claims', '', true);
SELECT set_config('request.jwt.claim.sub', '', true);
SELECT set_config('request.jwt.claim.role', '', true);
SELECT set_config('request.jwt.claim.email', '', true);

-- -----------------------------------------------------------------------------
-- Fixtures Globales: Identidades de prueba
-- -----------------------------------------------------------------------------
DO $$
DECLARE
    v_u1 uuid := '77000000-0000-0000-0000-000000000001';
    v_u2 uuid := '77000000-0000-0000-0000-000000000002';
    v_u3 uuid := '77000000-0000-0000-0000-000000000003';
    v_u4 uuid := '77000000-0000-0000-0000-000000000004';
    v_u5 uuid := '77000000-0000-0000-0000-000000000005';
    v_mod uuid := '77000000-0000-0000-0000-000000000010';
    v_adm uuid := '77000000-0000-0000-0000-000000000020';
    v_other uuid := '77000000-0000-0000-0000-000000000099';
BEGIN
    PERFORM tests.create_supabase_user(v_u1, 'estudiante1@test.com');
    PERFORM tests.create_supabase_user(v_u2, 'estudiante2@test.com');
    PERFORM tests.create_supabase_user(v_u3, 'estudiante3@test.com');
    PERFORM tests.create_supabase_user(v_u4, 'estudiante4@test.com');
    PERFORM tests.create_supabase_user(v_u5, 'estudiante5@test.com');
    PERFORM tests.create_supabase_user(v_mod, 'moderador@test.com');
    PERFORM tests.create_supabase_user(v_adm, 'admin@test.com');
    PERFORM tests.create_supabase_user(v_other, 'otro@test.com');

    -- Asignar roles de moderador y admin en public.user_roles
    INSERT INTO public.user_roles (user_id, role)
    VALUES (v_mod, 'moderator')
    ON CONFLICT (user_id) DO UPDATE SET role = 'moderator';

    INSERT INTO public.user_roles (user_id, role)
    VALUES (v_adm, 'admin')
    ON CONFLICT (user_id) DO UPDATE SET role = 'admin';

    -- Asegurar perfiles base
    INSERT INTO public.profiles (id, carrera, is_verified, verification_status)
    VALUES
        (v_u1, 'sistemas', false, 'unverified'),
        (v_u2, 'sistemas', false, 'unverified'),
        (v_u3, 'sistemas', false, 'unverified'),
        (v_u4, 'sistemas', false, 'unverified'),
        (v_u5, 'sistemas', false, 'unverified'),
        (v_mod, 'sistemas', true, 'verified'),
        (v_adm, 'sistemas', true, 'verified'),
        (v_other, 'sistemas', false, 'unverified')
    ON CONFLICT (id) DO UPDATE SET
        carrera = EXCLUDED.carrera,
        is_verified = EXCLUDED.is_verified,
        verification_status = EXCLUDED.verification_status;
END $$;

-- =============================================================================
-- SECCIÓN 1: Estructura, Catálogo y Dominios (§2 del Contrato)
-- =============================================================================

SELECT has_column('public', 'facultades', 'allowed_domains', '1. facultades posee columna allowed_domains');

SELECT is(
    (SELECT allowed_domains FROM public.facultades WHERE id = '08'),
    ARRAY['ingenieria.usac.edu.gt', 'ecys.org'],
    '2. Facultad 08 (Ingenieria) contiene dominios oficiales normativos'
);

SELECT is(
    (SELECT allowed_domains FROM public.facultades WHERE id = '05'),
    ARRAY['medicina.usac.edu.gt'],
    '3. Facultad 05 (Medicina) contiene medicina.usac.edu.gt'
);

SELECT is(
    (SELECT allowed_domains FROM public.facultades WHERE id = '04'),
    ARRAY['derecho.usac.edu.gt'],
    '4. Facultad 04 (Derecho) contiene derecho.usac.edu.gt'
);

SELECT is(
    (SELECT allowed_domains FROM public.facultades WHERE id = '03'),
    ARRAY['economicas.usac.edu.gt'],
    '5. Facultad 03 (Economicas) contiene economicas.usac.edu.gt'
);

SELECT is(
    (SELECT allowed_domains FROM public.facultades WHERE id = '06'),
    ARRAY['farusac.edu.gt'],
    '6. Facultad 06 (Farmacia) contiene farusac.edu.gt'
);

SELECT is(
    (SELECT allowed_domains FROM public.facultades WHERE id = '01'),
    ARRAY['fausac.gt'],
    '7. Facultad 01 (Agronomia) contiene fausac.gt'
);

SELECT has_column('public', 'profiles', 'verification_method', '8. profiles posee columna verification_method');
SELECT has_column('public', 'profiles', 'verification_status', '9. profiles posee columna verification_status');
SELECT has_column('public', 'profiles', 'institutional_email_domain', '10. profiles posee columna institutional_email_domain');

SELECT has_table('public', 'verification_requests', '11. Tabla public.verification_requests existe');
SELECT has_column('public', 'verification_requests', 'carne_hash', '12. verification_requests posee carne_hash');
SELECT hasnt_column('public', 'verification_requests', 'cui_hash', '13. verification_requests no posee cui_hash (Zero-PII)');
SELECT has_column('public', 'verification_requests', 'document_type', '14. verification_requests posee document_type');
SELECT has_column('public', 'verification_requests', 'r2_object_key', '15. verification_requests posee r2_object_key');
SELECT has_column('public', 'verification_requests', 'status', '16. verification_requests posee status');

SELECT has_index('public', 'verification_requests', 'idx_verification_requests_user_created', '17. Indice idx_verification_requests_user_created existe');
SELECT has_index('public', 'verification_requests', 'idx_verification_requests_status_expires', '18. Indice idx_verification_requests_status_expires existe');
SELECT has_index('public', 'verification_requests', 'idx_verification_requests_r2_object_key', '19. Indice parcial idx_verification_requests_r2_object_key existe');
SELECT has_index('public', 'verification_requests', 'idx_verification_requests_reviewed_by', '20. Indice idx_verification_requests_reviewed_by existe');

-- Test 21: moderation_jobs_entity_table_check permite 'verification_requests'
SELECT lives_ok(
    $$INSERT INTO public.moderation_jobs (
        entity_table, entity_id, content_hash, priority, status
    ) VALUES (
        'verification_requests', gen_random_uuid(), 'test_hash_init', 50, 'pending'
    )$$,
    '21. moderation_jobs acepta entity_table = verification_requests'
);

-- =============================================================================
-- SECCIÓN 2: Función Criptográfica privada (§3 del Contrato)
-- =============================================================================

-- Test 22: Cálculo exacto de HMAC-SHA256 con salt secreto
SELECT is(
    private.hash_credential('202012345'),
    encode(extensions.hmac('202012345', private.get_secret_salt(), 'sha256'), 'hex'),
    '22. private.hash_credential genera hash HMAC-SHA256 con salt secreto'
);

-- Test 23: Devuelve NULL para entrada NULL o vacía
SELECT is(
    private.hash_credential(NULL),
    NULL::text,
    '23. private.hash_credential devuelve NULL para valor nulo'
);

-- Test 24: anon no puede ejecutar private.hash_credential
SELECT tests.authenticate_as_anon();
SELECT throws_ok(
    $$SELECT private.hash_credential('202012345')$$,
    '42501',
    NULL,
    '24. anon no tiene permiso de ejecucion sobre private.hash_credential'
);

-- Test 25: authenticated no puede ejecutar private.hash_credential
SELECT tests.authenticate_as('77000000-0000-0000-0000-000000000001');
SELECT throws_ok(
    $$SELECT private.hash_credential('202012345')$$,
    '42501',
    NULL,
    '25. authenticated no tiene permiso de ejecucion sobre private.hash_credential'
);

-- =============================================================================
-- SECCIÓN 3: public.is_user_verified (§4.1 del Contrato)
-- =============================================================================

RESET ROLE;
SET ROLE postgres;
SELECT tests.authenticate_as('77000000-0000-0000-0000-000000000001');

SELECT is(
    public.is_user_verified(),
    false,
    '26. is_user_verified devuelve false para usuario no verificado'
);

SELECT tests.authenticate_as_anon();
SELECT throws_ok(
    $$SELECT public.is_user_verified()$$,
    '42501',
    NULL,
    '27. anon no puede ejecutar is_user_verified'
);

-- =============================================================================
-- SECCIÓN 4: public.claim_student_credentials (§4.2 del Contrato)
-- =============================================================================

-- Test 28: Rechaza llamada autenticada sin claim sub (auth.uid() nulo)
DO $$
BEGIN
    SET LOCAL ROLE authenticated;
    PERFORM set_config('request.jwt.claims', '{"role":"authenticated"}', true);
    PERFORM set_config('request.jwt.claim.sub', '', true);
    PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
END $$;

SELECT is(
    public.claim_student_credentials('202012345'),
    '{"ok": false, "code": "not_authenticated"}'::jsonb,
    '28. claim_student_credentials devuelve not_authenticated cuando auth.uid() es nulo'
);

-- Autenticar como Usuario 1
SELECT tests.authenticate_as('77000000-0000-0000-0000-000000000001');

-- Test 29: Rechaza carné no numérico o de longitud errónea
SELECT is(
    public.claim_student_credentials('carne_invalido'),
    '{"ok": false, "code": "invalid_carne_format"}'::jsonb,
    '29. claim_student_credentials rechaza carne con formato invalido'
);

-- Test 30: Rechaza carné con año futuro
SELECT is(
    public.claim_student_credentials((EXTRACT(YEAR FROM now()) + 1)::text || '12345'),
    '{"ok": false, "code": "invalid_carne_year"}'::jsonb,
    '30. claim_student_credentials rechaza carne con anio posterior al vigente'
);

-- Test 31: Rechaza carné con año anterior a 1980
SELECT is(
    public.claim_student_credentials('197812345'),
    '{"ok": false, "code": "invalid_carne_year"}'::jsonb,
    '31. claim_student_credentials rechaza carne con anio anterior a 1980'
);

-- Test 32: Rechaza carné con longitud menor a 9 dígitos
SELECT is(
    public.claim_student_credentials('12345'),
    '{"ok": false, "code": "invalid_carne_format"}'::jsonb,
    '32. claim_student_credentials rechaza carne con longitud menor a 9 digitos'
);

-- Test 33: Rechaza carné con longitud mayor a 9 dígitos
SELECT is(
    public.claim_student_credentials('20201234567'),
    '{"ok": false, "code": "invalid_carne_format"}'::jsonb,
    '33. claim_student_credentials rechaza carne con longitud mayor a 9 digitos'
);

-- Test 34: Reclamo exitoso con carné válido
SELECT is(
    public.claim_student_credentials('202012345'),
    '{"ok": true, "verification_status": "unverified", "is_verified": false}'::jsonb,
    '34. claim_student_credentials procesa credenciales validas exitosamente'
);

-- Test 35 y 36: Los hashes quedaron persistidos en profiles
RESET ROLE;
SET ROLE postgres;
SELECT is(
    (SELECT carne_hash FROM public.profiles WHERE id = '77000000-0000-0000-0000-000000000001'),
    private.hash_credential('202012345'),
    '35. carne_hash almacenado en profiles coincide con private.hash_credential'
);

SELECT hasnt_column(
    'public', 'profiles', 'cui_hash',
    '36. cui_hash no existe en profiles (Zero-PII)'
);

-- Test 37: No altera is_verified (sigue false)
SELECT is(
    (SELECT is_verified FROM public.profiles WHERE id = '77000000-0000-0000-0000-000000000001'),
    false,
    '37. claim_student_credentials no otorga is_verified = true'
);

-- Test 38: Usuario 2 intenta reclamar el carné del Usuario 1 -> credential_unavailable
SELECT tests.authenticate_as('77000000-0000-0000-0000-000000000002');
SELECT is(
    public.claim_student_credentials('202012345'),
    '{"ok": false, "code": "credential_unavailable"}'::jsonb,
    '38. Reclamo de carne duplicado por otro usuario devuelve credential_unavailable'
);

-- Test 39: Usuario 2 intenta reclamar carné disponible -> exitoso
SELECT is(
    public.claim_student_credentials('202154321'),
    '{"ok": true, "verification_status": "unverified", "is_verified": false}'::jsonb,
    '39. Reclamo de carne disponible por segundo usuario devuelve ok true'
);

-- Test 40: Mismo Usuario 1 puede re-reclamar sus propias credenciales sin error
SELECT tests.authenticate_as('77000000-0000-0000-0000-000000000001');
SELECT is(
    public.claim_student_credentials('202012345'),
    '{"ok": true, "verification_status": "unverified", "is_verified": false}'::jsonb,
    '40. Usuario original puede actualizar o re-reclamar sus propias credenciales'
);

-- =============================================================================
-- SECCIÓN 5: Trigger de Correo Institucional (§4.5 del Contrato)
-- =============================================================================

RESET ROLE;
SET ROLE postgres;

-- Test 41 y 42: Correo @gmail.com no verifica el perfil
DO $$
DECLARE
    v_u_gmail uuid := '77000000-0000-0000-0000-000000000030';
BEGIN
    PERFORM tests.create_supabase_user(v_u_gmail, 'alumno_comun@gmail.com');
END $$;

SELECT is(
    (SELECT verification_status FROM public.profiles WHERE id = '77000000-0000-0000-0000-000000000030'),
    'unverified',
    '41. Correo @gmail.com no cambia verification_status (permanece unverified)'
);

SELECT is(
    (SELECT is_verified FROM public.profiles WHERE id = '77000000-0000-0000-0000-000000000030'),
    false,
    '42. Correo @gmail.com no otorga is_verified'
);

-- Test 43, 44 y 45: Correo @ingenieria.usac.edu.gt verifica automáticamente
DO $$
DECLARE
    v_u_ing uuid := '77000000-0000-0000-0000-000000000031';
BEGIN
    PERFORM tests.create_supabase_user(v_u_ing, 'estudiante@ingenieria.usac.edu.gt');
END $$;

SELECT is(
    (SELECT verification_status FROM public.profiles WHERE id = '77000000-0000-0000-0000-000000000031'),
    'verified',
    '43. Correo @ingenieria.usac.edu.gt establece verification_status = verified'
);

SELECT is(
    (SELECT is_verified FROM public.profiles WHERE id = '77000000-0000-0000-0000-000000000031'),
    true,
    '44. Correo @ingenieria.usac.edu.gt establece is_verified = true'
);

SELECT is(
    (SELECT institutional_email_domain FROM public.profiles WHERE id = '77000000-0000-0000-0000-000000000031'),
    'ingenieria.usac.edu.gt',
    '45. Registra institutional_email_domain correcto'
);

-- Test 46: Correo @usac.edu.gt verifica automáticamente
DO $$
DECLARE
    v_u_usac uuid := '77000000-0000-0000-0000-000000000032';
BEGIN
    PERFORM tests.create_supabase_user(v_u_usac, 'rectoria@usac.edu.gt');
END $$;

SELECT is(
    (SELECT is_verified FROM public.profiles WHERE id = '77000000-0000-0000-0000-000000000032'),
    true,
    '46. Correo @usac.edu.gt verifica al usuario'
);

-- Test 47 y 48: Correo @fausac.gt (Facultad 01) verifica automáticamente
DO $$
DECLARE
    v_u_fau uuid := '77000000-0000-0000-0000-000000000033';
BEGIN
    PERFORM tests.create_supabase_user(v_u_fau, 'agronomia@fausac.gt');
END $$;

SELECT is(
    (SELECT is_verified FROM public.profiles WHERE id = '77000000-0000-0000-0000-000000000033'),
    true,
    '47. Correo @fausac.gt de catalogo de facultades verifica al usuario'
);

SELECT is(
    (SELECT institutional_email_domain FROM public.profiles WHERE id = '77000000-0000-0000-0000-000000000033'),
    'fausac.gt',
    '48. Registra institutional_email_domain = fausac.gt'
);

-- Test 49 y 50: No degrada un perfil verificado por OCR
DO $$
DECLARE
    v_u_ocr uuid := '77000000-0000-0000-0000-000000000034';
BEGIN
    PERFORM tests.create_supabase_user(v_u_ocr, 'inicial_ocr@test.com');
    UPDATE public.profiles
    SET is_verified = true,
        verification_status = 'verified',
        verification_method = 'ocr_document',
        verified_at = now() - interval '2 days'
    WHERE id = v_u_ocr;

    -- Usuario confirma correo institucional posterior
    UPDATE auth.users
    SET email = 'nuevo_ing@ingenieria.usac.edu.gt',
        email_confirmed_at = now()
    WHERE id = v_u_ocr;
END $$;

SELECT is(
    (SELECT verification_method FROM public.profiles WHERE id = '77000000-0000-0000-0000-000000000034'),
    'ocr_document',
    '49. Confirmacion de correo institucional no degrada verification_method = ocr_document'
);

-- Cambio a correo @gmail.com no degrada la verificación OCR
DO $$
BEGIN
    UPDATE auth.users
    SET email = 'cambio_gmail@gmail.com',
        email_confirmed_at = now()
    WHERE id = '77000000-0000-0000-0000-000000000034';
END $$;

SELECT is(
    (SELECT is_verified FROM public.profiles WHERE id = '77000000-0000-0000-0000-000000000034'),
    true,
    '50. Cambio de correo a gmail no degrada verificacion existente'
);

-- Test 51: Idempotencia del trigger (no altera verified_at existente)
DO $$
DECLARE
    v_u_idem uuid := '77000000-0000-0000-0000-000000000035';
    v_ts timestamptz := '2026-01-15 10:00:00+00'::timestamptz;
BEGIN
    PERFORM tests.create_supabase_user(v_u_idem, 'primero@ingenieria.usac.edu.gt');
    UPDATE public.profiles
    SET verified_at = v_ts
    WHERE id = v_u_idem;

    -- Disparar trigger de nuevo en auth.users
    UPDATE auth.users
    SET email_confirmed_at = now()
    WHERE id = v_u_idem;
END $$;

SELECT is(
    (SELECT verified_at FROM public.profiles WHERE id = '77000000-0000-0000-0000-000000000035'),
    '2026-01-15 10:00:00+00'::timestamptz,
    '51. Trigger de correo es idempotente y preserva verified_at previo'
);

-- =============================================================================
-- SECCIÓN 6: public.admin_create_verification_request (§4.3 del Contrato)
-- =============================================================================

-- Test 52: Rechaza llamador no autorizado (rol authenticated)
SELECT tests.authenticate_as('77000000-0000-0000-0000-000000000001');
SELECT throws_ok(
    $$SELECT public.admin_create_verification_request(
        '77000000-0000-0000-0000-000000000001',
        '202210001',
        'constancia_inscripcion'
    )$$,
    '42501',
    NULL,
    '52. admin_create_verification_request no permite ejecucion a authenticated'
);

RESET ROLE;
SET ROLE postgres;

-- Test 53 a 58: Aprobación automática (auto_approved => true)
SELECT is(
    (public.admin_create_verification_request(
        '77000000-0000-0000-0000-000000000002',
        '202210002',
        'constancia_inscripcion',
        'pending/temp_key.jpg',
        'https://usac.edu.gt/qr',
        true,
        true,
        true,
        true
    ) ->> 'status'),
    'verified',
    '53. admin_create_verification_request con auto_approved devuelve status verified'
);

SELECT is(
    (SELECT is_verified FROM public.profiles WHERE id = '77000000-0000-0000-0000-000000000002'),
    true,
    '54. auto_approved establece is_verified = true en perfil'
);

SELECT is(
    (SELECT verification_status FROM public.profiles WHERE id = '77000000-0000-0000-0000-000000000002'),
    'verified',
    '55. auto_approved establece verification_status = verified'
);

SELECT is(
    (SELECT verification_method FROM public.profiles WHERE id = '77000000-0000-0000-0000-000000000002'),
    'ocr_document',
    '56. auto_approved establece verification_method = ocr_document'
);

SELECT is(
    (SELECT r2_object_key FROM public.verification_requests WHERE user_id = '77000000-0000-0000-0000-000000000002'),
    NULL::text,
    '57. auto_approved fuerza r2_object_key a NULL (no almacena objeto en bucket)'
);

SELECT is(
    (SELECT count(*)::integer FROM public.moderation_jobs
     WHERE entity_table = 'verification_requests'
       AND entity_id = (SELECT id FROM public.verification_requests WHERE user_id = '77000000-0000-0000-0000-000000000002')),
    0,
    '58. auto_approved no crea entrada en moderation_jobs'
);

-- Test 59 a 63: Revisión manual (auto_approved => false)
SELECT is(
    (public.admin_create_verification_request(
        '77000000-0000-0000-0000-000000000003',
        '202210003',
        'carne_fisico',
        'pending/77003/doc.jpg',
        NULL,
        false,
        false,
        false,
        false
    ) ->> 'status'),
    'manual_review',
    '59. Creacion sin auto_approved devuelve status manual_review'
);

SELECT is(
    (SELECT verification_status FROM public.profiles WHERE id = '77000000-0000-0000-0000-000000000003'),
    'pending_review',
    '60. manual_review deja verification_status = pending_review'
);

SELECT is(
    (SELECT is_verified FROM public.profiles WHERE id = '77000000-0000-0000-0000-000000000003'),
    false,
    '61. manual_review no otorga is_verified (permanece false)'
);

SELECT is(
    (SELECT r2_object_key FROM public.verification_requests WHERE user_id = '77000000-0000-0000-0000-000000000003'),
    'pending/77003/doc.jpg',
    '62. manual_review conserva r2_object_key'
);

SELECT is(
    (SELECT count(*)::integer FROM public.moderation_jobs
     WHERE entity_table = 'verification_requests'
       AND entity_id = (SELECT id FROM public.verification_requests WHERE user_id = '77000000-0000-0000-0000-000000000003')
       AND priority = 50),
    1,
    '63. manual_review crea entrada en moderation_jobs con prioridad 50'
);

-- Test 64 a 66: Rate limit (máx 3 intentos en 24h, 4to falla)
SELECT is(
    (public.admin_create_verification_request(
        '77000000-0000-0000-0000-000000000004',
        '202210004', 'carne_fisico', NULL, NULL, false, false, false, false
    ) ->> 'ok')::boolean,
    true,
    '64. Intento 1 de verificacion para usuario 4 es aceptado'
);

SELECT is(
    (public.admin_create_verification_request(
        '77000000-0000-0000-0000-000000000004',
        '202210004', 'carne_fisico', NULL, NULL, false, false, false, false
    ) ->> 'ok')::boolean,
    true,
    '65. Intento 2 de verificacion para usuario 4 es aceptado'
);

SELECT is(
    (public.admin_create_verification_request(
        '77000000-0000-0000-0000-000000000004',
        '202210004', 'carne_fisico', NULL, NULL, false, false, false, false
    ) ->> 'ok')::boolean,
    true,
    '66. Intento 3 de verificacion para usuario 4 es aceptado'
);

SELECT is(
    public.admin_create_verification_request(
        '77000000-0000-0000-0000-000000000004',
        '202210004', 'carne_fisico', NULL, NULL, false, false, false, false
    ),
    '{"ok": false, "code": "rate_limited"}'::jsonb,
    '67. Intento 4 dentro de 24h es rechazado por rate_limited'
);

-- Test 67 (continuación): Detección de duplicado por otro usuario en admin_create
SELECT is(
    public.admin_create_verification_request(
        '77000000-0000-0000-0000-000000000005',
        '202210002', -- Ya tomado por Usuario 2
        'carne_fisico', NULL, NULL, false, false, false, false
    ),
    '{"ok": false, "code": "credential_unavailable"}'::jsonb,
    '68. admin_create_verification_request rechaza carné duplicado con credential_unavailable'
);

-- =============================================================================
-- SECCIÓN 7: public.admin_review_verification (§4.4 del Contrato)
-- =============================================================================

-- Test 69: Rechaza llamador no autorizado (authenticated)
SELECT tests.authenticate_as('77000000-0000-0000-0000-000000000001');
SELECT throws_ok(
    $$SELECT public.admin_review_verification(
        '77000000-0000-0000-0000-000000000010',
        gen_random_uuid(),
        'approved'
    )$$,
    '42501',
    NULL,
    '69. admin_review_verification rechaza invocacion de rol authenticated'
);

RESET ROLE;
SET ROLE postgres;

-- Test 70: Revisor sin rol admin/moderador
SELECT is(
    public.admin_review_verification(
        '77000000-0000-0000-0000-000000000099', -- Usuario común
        (SELECT id FROM public.verification_requests WHERE user_id = '77000000-0000-0000-0000-000000000003' LIMIT 1),
        'approved'
    ),
    '{"ok": false, "code": "not_authorized"}'::jsonb,
    '70. admin_review_verification rechaza revisor que no es admin ni moderador'
);

-- Test 71: Decisión inválida
SELECT is(
    public.admin_review_verification(
        '77000000-0000-0000-0000-000000000010',
        (SELECT id FROM public.verification_requests WHERE user_id = '77000000-0000-0000-0000-000000000003' LIMIT 1),
        'invalida'
    ),
    '{"ok": false, "code": "invalid_decision"}'::jsonb,
    '71. admin_review_verification rechaza decision invalida'
);

-- Test 72: Solicitud inexistente
SELECT is(
    public.admin_review_verification(
        '77000000-0000-0000-0000-000000000010',
        gen_random_uuid(),
        'approved'
    ),
    '{"ok": false, "code": "not_found"}'::jsonb,
    '72. admin_review_verification devuelve not_found si solicitud no existe'
);

-- Test 73 a 75: Aprobación por moderador
DO $$
DECLARE
    v_req_id uuid;
BEGIN
    SELECT id INTO v_req_id FROM public.verification_requests
    WHERE user_id = '77000000-0000-0000-0000-000000000003' LIMIT 1;

    PERFORM public.admin_review_verification(
        '77000000-0000-0000-0000-000000000010',
        v_req_id,
        'approved'
    );
END $$;

SELECT is(
    (SELECT status FROM public.verification_requests WHERE user_id = '77000000-0000-0000-0000-000000000003'),
    'approved',
    '73. Aprobacion establece status = approved en la solicitud'
);

SELECT is(
    (SELECT is_verified FROM public.profiles WHERE id = '77000000-0000-0000-0000-000000000003'),
    true,
    '74. Aprobacion manual establece is_verified = true en perfil'
);

SELECT is(
    (SELECT verification_method FROM public.profiles WHERE id = '77000000-0000-0000-0000-000000000003'),
    'manual_review',
    '75. Aprobacion manual establece verification_method = manual_review'
);

-- Test 76 a 78: Rechazo por moderador
DO $$
DECLARE
    v_req_rej uuid;
    v_u_rej uuid := '77000000-0000-0000-0000-000000000005';
BEGIN
    PERFORM tests.create_supabase_user(v_u_rej, 'estudiante_rechazo@test.com');
    SELECT (public.admin_create_verification_request(
        v_u_rej,
        '202210005',
        'carne_fisico',
        'pending/rej.jpg'
    ) ->> 'request_id')::uuid INTO v_req_rej;

    PERFORM public.admin_review_verification(
        '77000000-0000-0000-0000-000000000010',
        v_req_rej,
        'rejected',
        'Documento borroso e ilegible'
    );
END $$;

SELECT is(
    (SELECT status FROM public.verification_requests WHERE user_id = '77000000-0000-0000-0000-000000000005'),
    'rejected',
    '76. Rechazo administrativo marca status = rejected en la solicitud'
);

SELECT is(
    (SELECT verification_status FROM public.profiles WHERE id = '77000000-0000-0000-0000-000000000005'),
    'rejected',
    '77. Rechazo administrativo marca verification_status = rejected en el perfil'
);

-- Test 78: Rechazo administrativo NO degrada a un usuario verificado institucionalmente
DO $$
DECLARE
    v_u_inst uuid := '77000000-0000-0000-0000-000000000031'; -- Verificado por @ingenieria
    v_req_inst uuid;
BEGIN
    -- Crea una solicitud manual de prueba para el mismo usuario
    SELECT (public.admin_create_verification_request(
        v_u_inst,
        '202210031',
        'carne_fisico',
        'pending/inst.jpg'
    ) ->> 'request_id')::uuid INTO v_req_inst;

    PERFORM public.admin_review_verification(
        '77000000-0000-0000-0000-000000000010',
        v_req_inst,
        'rejected',
        'Carné secundario rechazado'
    );
END $$;

SELECT is(
    (SELECT is_verified FROM public.profiles WHERE id = '77000000-0000-0000-0000-000000000031'),
    true,
    '78. Rechazo de solicitud manual NUNCA degrada usuario verificado por correo institucional'
);

-- Test 79: admin_review_verification no limpia r2_object_key (tarea del Worker)
SELECT is(
    (SELECT r2_object_key FROM public.verification_requests WHERE user_id = '77000000-0000-0000-0000-000000000005'),
    'pending/rej.jpg',
    '79. admin_review_verification preserva r2_object_key para limpieza del Worker'
);

-- =============================================================================
-- SECCIÓN 8: Políticas RLS en public.verification_requests (§5.1 del Contrato)
-- =============================================================================

RESET ROLE;
SET ROLE postgres;

-- Test 80: Dueño ve solo sus solicitudes
SELECT tests.authenticate_as('77000000-0000-0000-0000-000000000003');
SELECT is(
    (SELECT count(*)::integer FROM public.verification_requests),
    1,
    '80. Duenio de solicitud puede ver su propia solicitud en verification_requests'
);

-- Test 81: Otro usuario no ve las solicitudes del dueño
SELECT tests.authenticate_as('77000000-0000-0000-0000-000000000001');
SELECT is(
    (SELECT count(*)::integer FROM public.verification_requests WHERE user_id = '77000000-0000-0000-0000-000000000003'),
    0,
    '81. Usuario no autorizado ve 0 filas de solicitudes ajenas'
);

-- Test 82: Moderador puede ver solicitudes de cualquier usuario
SELECT tests.authenticate_as_moderator('77000000-0000-0000-0000-000000000010');
SELECT is(
    (SELECT count(*)::integer FROM public.verification_requests WHERE user_id = '77000000-0000-0000-0000-000000000003'),
    1,
    '82. Moderador de staff puede consultar solicitudes de otros usuarios'
);

-- Test 83: Authenticated no puede insertar directamente en verification_requests
SELECT tests.authenticate_as('77000000-0000-0000-0000-000000000001');
SELECT throws_ok(
    $$INSERT INTO public.verification_requests (
        user_id, carne_hash, document_type
    ) VALUES (
        '77000000-0000-0000-0000-000000000001', 'fakehash', 'carne_fisico'
    )$$,
    '42501',
    NULL,
    '83. Usuario autenticado no puede insertar directamente en verification_requests'
);

-- Test 84: Authenticated no puede actualizar directamente en verification_requests
SELECT throws_ok(
    $$UPDATE public.verification_requests
      SET status = 'approved'
      WHERE user_id = '77000000-0000-0000-0000-000000000001'$$,
    '42501',
    NULL,
    '84. Usuario autenticado no puede actualizar directamente en verification_requests'
);

-- Test 85: Anon no puede leer verification_requests
SELECT tests.authenticate_as_anon();
SELECT throws_ok(
    $$SELECT count(*) FROM public.verification_requests$$,
    '42501',
    NULL,
    '85. anon no tiene permiso de lectura sobre verification_requests'
);

-- =============================================================================
-- SECCIÓN 9: Integración con Marketplace (§5.2 del Contrato)
-- =============================================================================

-- Test 86: Usuario autenticado NO verificado no puede publicar en marketplace_items
SELECT tests.authenticate_as('77000000-0000-0000-0000-000000000001');
SELECT throws_ok(
    $$INSERT INTO public.marketplace_items (
        title, description, price, category, facultad, user_id, contact_whatsapp
    ) VALUES (
        'Libro de Calculo Stewart', 'Libro usado en perfecto estado para ingenieria',
        120.00, 'otros_articulos', '08', '77000000-0000-0000-0000-000000000001', '50212345678'
    )$$,
    '42501',
    NULL,
    '86. Usuario autenticado no verificado no puede insertar en marketplace_items'
);

-- Test 87: Usuario verificado con el nuevo flujo SÍ puede publicar en marketplace_items
SELECT tests.authenticate_as('77000000-0000-0000-0000-000000000002');
SELECT lives_ok(
    $$INSERT INTO public.marketplace_items (
        title, description, price, category, facultad, user_id, contact_whatsapp
    ) VALUES (
        'Calculadora Cientifica fx-991', 'Calculadora en perfecto estado para ingenieria',
        180.00, 'otros_articulos', '08', '77000000-0000-0000-0000-000000000002', '50212345678'
    )$$,
    '87. Usuario verificado por el flujo nuevo si puede publicar en marketplace_items'
);

-- Test 88: Usuario no verificado puede consultar el marketplace (lectura pública)
SELECT tests.authenticate_as('77000000-0000-0000-0000-000000000001');
SELECT is(
    (SELECT count(*)::integer FROM public.marketplace_items WHERE title = 'Calculadora Cientifica fx-991'),
    1,
    '88. Usuario no verificado puede leer items publicados en el marketplace'
);

-- =============================================================================
-- SECCIÓN 10: Inmutabilidad y Protección de Campos Sensibles (§5.3 del Contrato)
-- =============================================================================

-- Test 89: Usuario autenticado no puede alterar is_verified directamente
SELECT throws_ok(
    $$UPDATE public.profiles SET is_verified = true WHERE id = '77000000-0000-0000-0000-000000000001'$$,
    '42501',
    NULL,
    '89. Usuario autenticado no puede auto-otorgarse is_verified = true'
);

-- Test 90: Usuario autenticado no puede alterar verification_status directamente
SELECT throws_ok(
    $$UPDATE public.profiles SET verification_status = 'verified' WHERE id = '77000000-0000-0000-0000-000000000001'$$,
    '42501',
    NULL,
    '90. Usuario autenticado no puede modificar verification_status directamente'
);

-- Test 91: Usuario autenticado no puede alterar verification_method directamente
SELECT throws_ok(
    $$UPDATE public.profiles SET verification_method = 'ocr_document' WHERE id = '77000000-0000-0000-0000-000000000001'$$,
    '42501',
    NULL,
    '91. Usuario autenticado no puede modificar verification_method directamente'
);

-- Test 92: Usuario autenticado no puede alterar institutional_email_domain directamente
SELECT throws_ok(
    $$UPDATE public.profiles SET institutional_email_domain = 'usac.edu.gt' WHERE id = '77000000-0000-0000-0000-000000000001'$$,
    '42501',
    NULL,
    '92. Usuario autenticado no puede modificar institutional_email_domain directamente'
);

-- Test 93: Usuario autenticado sí puede actualizar campos permitidos (ej. carrera)
SELECT lives_ok(
    $$UPDATE public.profiles SET carrera = 'mecanica' WHERE id = '77000000-0000-0000-0000-000000000001'$$,
    '93. Usuario autenticado puede modificar campos no protegidos como carrera'
);

-- Test 94: Invariante: public.is_user_verified devuelve true para usuario verificado
SELECT tests.authenticate_as('77000000-0000-0000-0000-000000000002');
SELECT is(
    public.is_user_verified(),
    true,
    '94. is_user_verified devuelve true para usuario validado'
);

-- Test 95: Invariante: verification_status = 'verified' implica is_verified = true
RESET ROLE;
SET ROLE postgres;
SELECT is(
    (SELECT count(*)::integer FROM public.profiles
     WHERE (verification_status = 'verified' AND is_verified = false)
        OR (verification_status <> 'verified' AND is_verified = true)),
    0,
    '95. Invariante verification_status = verified <=> is_verified = true se cumple en 100% de filas'
);

SELECT * FROM finish();
ROLLBACK;
