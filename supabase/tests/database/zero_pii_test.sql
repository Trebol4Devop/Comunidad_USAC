-- =============================================================================
-- PEMTREE / Comunidad USAC · pgTAP Test: Verificación y Modelo Zero-PII
-- Archivo: supabase/tests/database/zero_pii_test.sql
-- Módulo: Endurecimiento de Seguridad Zero-PII
-- =============================================================================

BEGIN;

SELECT plan(32);

CREATE EXTENSION IF NOT EXISTS pgtap;

-- Asegurar rol privilegiado inicial y claims limpios
RESET ROLE;
SET ROLE postgres;
SELECT set_config('request.jwt.claims', '', true);
SELECT set_config('request.jwt.claim.sub', '', true);
SELECT set_config('request.jwt.claim.role', '', true);
SELECT set_config('request.jwt.claim.email', '', true);

-- -----------------------------------------------------------------------------
-- Fixtures Globales para Pruebas Zero-PII
-- -----------------------------------------------------------------------------
DO $$
DECLARE
    v_u1 uuid := '99000000-0000-0000-0000-000000000001';
    v_u2 uuid := '99000000-0000-0000-0000-000000000002';
    v_u3 uuid := '99000000-0000-0000-0000-000000000003';
    v_mod uuid := '99000000-0000-0000-0000-000000000010';
BEGIN
    PERFORM tests.create_supabase_user(v_u1, 'zero_user1@test.com');
    PERFORM tests.create_supabase_user(v_u2, 'zero_user2@test.com');
    PERFORM tests.create_supabase_user(v_u3, 'zero_user3@test.com');
    PERFORM tests.create_supabase_user(v_mod, 'zero_mod@test.com');

    INSERT INTO public.user_roles (user_id, role)
    VALUES (v_mod, 'moderator')
    ON CONFLICT (user_id) DO NOTHING;

    INSERT INTO public.profiles (id, carrera)
    VALUES (v_u1, 'sistemas'),
           (v_u2, 'sistemas'),
           (v_u3, 'sistemas')
    ON CONFLICT (id) DO NOTHING;
END $$;

-- =============================================================================
-- 1. AUSENCIA DE COLUMNAS PII / OCR CRUDO / DPI
-- =============================================================================

SELECT hasnt_column('public', 'profiles', 'cui', '1. profiles NO posee columna cui');
SELECT hasnt_column('public', 'profiles', 'carne', '2. profiles NO posee columna carne');
SELECT hasnt_column('public', 'profiles', 'full_name', '3. profiles NO posee columna full_name');
SELECT hasnt_column('public', 'profiles', 'cui_hash', '4. profiles NO posee columna cui_hash');

SELECT hasnt_column('public', 'verification_requests', 'cui_hash', '5. verification_requests NO posee columna cui_hash');
SELECT hasnt_column('public', 'verification_requests', 'extracted_ocr_text', '6. verification_requests NO posee columna extracted_ocr_text');

SELECT hasnt_column('public', 'merchant_verification_requests', 'dpi_hash', '7. merchant_verification_requests NO posee columna dpi_hash');
SELECT hasnt_column('public', 'merchant_verification_requests', 'dpi_front_key', '8. merchant_verification_requests NO posee columna dpi_front_key');
SELECT hasnt_column('public', 'merchant_verification_requests', 'dpi_back_key', '9. merchant_verification_requests NO posee columna dpi_back_key');

-- =============================================================================
-- 2. CONSTRAINT profiles_carne_hash_unique
-- =============================================================================

SELECT ok(
    EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conrelid = 'public.profiles'::regclass
          AND conname = 'profiles_carne_hash_unique'
    ),
    '10. Constraint profiles_carne_hash_unique existe en public.profiles'
);

-- Verificar que bloquee duplicados directos en profiles
DO $$
BEGIN
    UPDATE public.profiles
    SET carne_hash = private.hash_credential('202012345')
    WHERE id = '99000000-0000-0000-0000-000000000001';
END $$;

SELECT throws_ok(
    $$UPDATE public.profiles
      SET carne_hash = private.hash_credential('202012345')
      WHERE id = '99000000-0000-0000-0000-000000000002'$$,
    '23505',
    NULL,
    '11. profiles_carne_hash_unique bloquea duplicados de carne_hash'
);

-- =============================================================================
-- 3. verification_requests: BANDERAS BOOLEANAS Y CARNE_HASH
-- =============================================================================

SELECT has_column('public', 'verification_requests', 'matched_keywords', '12. verification_requests posee matched_keywords');
SELECT has_column('public', 'verification_requests', 'matched_carne', '13. verification_requests posee matched_carne');
SELECT has_column('public', 'verification_requests', 'matched_current_year', '14. verification_requests posee matched_current_year');
SELECT col_not_null('public', 'verification_requests', 'matched_keywords', '15. matched_keywords es NOT NULL');
SELECT col_default_is('public', 'verification_requests', 'matched_keywords', 'false', '16. matched_keywords default es false');
SELECT col_not_null('public', 'verification_requests', 'carne_hash', '17. carne_hash es NOT NULL en verification_requests');

-- =============================================================================
-- 4. merchant_verification_requests: contact_phone_hash Y campus_zone
-- =============================================================================

SELECT has_column('public', 'merchant_verification_requests', 'contact_phone_hash', '18. merchant_verification_requests posee contact_phone_hash');
SELECT col_not_null('public', 'merchant_verification_requests', 'contact_phone_hash', '19. contact_phone_hash es NOT NULL');
SELECT has_column('public', 'merchant_verification_requests', 'campus_zone', '20. merchant_verification_requests posee campus_zone');
SELECT col_is_null('public', 'merchant_verification_requests', 'campus_zone', '21. campus_zone es nullable');

-- =============================================================================
-- 5. ÍNDICE ÚNICO PARCIAL DE TELÉFONO ACTIVO Y REUTILIZACIÓN TRAS REJECTED
-- =============================================================================

SELECT has_index(
    'public',
    'merchant_verification_requests',
    'idx_merchant_unique_active_phone_hash',
    '22. Indice unico parcial idx_merchant_unique_active_phone_hash existe'
);

-- Crear solicitud 1 con teléfono 55554444 (status pending)
DO $$
DECLARE
    v_req1 uuid := '99100000-0000-0000-0000-000000000001';
    v_u1 uuid := '99000000-0000-0000-0000-000000000001';
BEGIN
    PERFORM public.admin_create_merchant_verification_request(
        v_req1,
        v_u1,
        'Comercio Uno',
        '55554444',
        'pending/merchant/' || v_u1::text || '/' || v_req1::text || '/est.jpg',
        'Nota Uno'
    );
END $$;

-- Intentar crear solicitud 2 con mismo teléfono desde otro usuario -> rechaza con credential_unavailable
SELECT is(
    (public.admin_create_merchant_verification_request(
        '99100000-0000-0000-0000-000000000002',
        '99000000-0000-0000-0000-000000000002',
        'Comercio Dos',
        '55554444',
        'pending/merchant/99000000-0000-0000-0000-000000000002/99100000-0000-0000-0000-000000000002/est.jpg',
        'Nota Dos'
    ) ->> 'code'),
    'credential_unavailable',
    '23. admin_create_merchant_verification_request rechaza telefono duplicado activo'
);

-- Rechazar administrativamente la solicitud 1
DO $$
BEGIN
    PERFORM public.admin_review_merchant_verification(
        '99000000-0000-0000-0000-000000000010',
        '99100000-0000-0000-0000-000000000001',
        'rejected',
        'Documentacion de local incompleta'
    );
END $$;

-- Ahora con solicitud 1 en estado rejected, el teléfono 55554444 puede ser reutilizado
SELECT is(
    (public.admin_create_merchant_verification_request(
        '99100000-0000-0000-0000-000000000002',
        '99000000-0000-0000-0000-000000000002',
        'Comercio Dos Reintento',
        '+502 5555-4444',
        'pending/merchant/99000000-0000-0000-0000-000000000002/99100000-0000-0000-0000-000000000002/est.jpg',
        'Reintento'
    ) ->> 'ok')::boolean,
    true,
    '24. Indice unico parcial permite reutilizar telefono tras estado rejected'
);

-- =============================================================================
-- 6. FIRMA Y PRIVILEGIOS DE claim_student_credentials
-- =============================================================================

SELECT has_function('public', 'claim_student_credentials', ARRAY['text'], '25. claim_student_credentials(text) existe');
SELECT hasnt_function('public', 'claim_student_credentials', ARRAY['text', 'text'], '26. claim_student_credentials(text, text) fue eliminada');
SELECT ok(
    has_function_privilege('authenticated', 'public.claim_student_credentials(text)', 'EXECUTE'),
    '27. authenticated posee GRANT EXECUTE sobre claim_student_credentials(text)'
);

-- Pruebas de validación en claim_student_credentials
SELECT tests.authenticate_as('99000000-0000-0000-0000-000000000003');

SELECT is(
    public.claim_student_credentials('letras_no_validas'),
    '{"ok": false, "code": "invalid_carne_format"}'::jsonb,
    '28. claim_student_credentials retorna invalid_carne_format ante formato incorrecto'
);

SELECT is(
    public.claim_student_credentials('197012345'),
    '{"ok": false, "code": "invalid_carne_year"}'::jsonb,
    '29. claim_student_credentials retorna invalid_carne_year ante anio previo a 1980'
);

-- =============================================================================
-- 7. VALIDACIÓN DE TELÉFONO EN admin_create_merchant_verification_request
-- =============================================================================

RESET ROLE;
SET ROLE postgres;

SELECT is(
    (public.admin_create_merchant_verification_request(
        '99100000-0000-0000-0000-000000000003',
        '99000000-0000-0000-0000-000000000003',
        'Comercio Tres',
        '12345',
        'pending/merchant/99000000-0000-0000-0000-000000000003/99100000-0000-0000-0000-000000000003/est.jpg',
        'Nota'
    ) ->> 'code'),
    'invalid_phone',
    '30. admin_create_merchant_verification_request rechaza telefono con longitud invalida'
);

-- =============================================================================
-- 8. RPC admin_clear_merchant_keys
-- =============================================================================

SELECT lives_ok(
    $$SELECT public.admin_clear_merchant_keys('99100000-0000-0000-0000-000000000002')$$,
    '31. admin_clear_merchant_keys se ejecuta exitosamente'
);

SELECT is(
    (SELECT establishment_key FROM public.merchant_verification_requests WHERE id = '99100000-0000-0000-0000-000000000002'),
    NULL::text,
    '32. admin_clear_merchant_keys deja establishment_key en NULL'
);

SELECT * FROM finish();
ROLLBACK;
