-- =============================================================================
-- PEMTREE / Comunidad USAC · pgTAP Test: Suite Legal Completa & Hardening
-- Archivo: supabase/tests/database/full_system_and_legal_test.sql
-- =============================================================================
begin;

select plan(53);

create extension if not exists pgtap;

-- Asegurar rol privilegiado inicial
reset role;
set role postgres;

-- -----------------------------------------------------------------------------
-- Declaración y creación de identidades de prueba
-- -----------------------------------------------------------------------------
do $$
declare
    v_u1 uuid := '11111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
    v_u2 uuid := '22222222-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
    v_u3 uuid := '33333333-cccc-cccc-cccc-cccccccccccc';
    v_mod uuid := '55555555-dddd-dddd-dddd-dddddddddddd';
begin
    perform tests.create_supabase_user(v_u1, 'user1_legal@test.com');
    perform tests.create_supabase_user(v_u2, 'user2_legal@test.com');
    perform tests.create_supabase_user(v_u3, 'user3_legal@test.com');
    perform tests.create_supabase_user(v_mod, 'mod_legal@test.com');

    insert into public.profiles (id, full_name, carrera)
    values (v_u1, 'Usuario Legal Uno', 'sistemas'),
           (v_u2, 'Usuario Legal Dos', 'sistemas'),
           (v_u3, 'Usuario Legal Tres', 'sistemas'),
           (v_mod, 'Moderador Legal', 'sistemas')
    on conflict (id) do nothing;
end $$;

-- =============================================================================
-- SECCIÓN 1: CUI y Carné hasheados (Art. 12 / PII Protection)
-- =============================================================================
reset role;
set role postgres;

update public.profiles
   set cui = '1234567890101',
       carne = '202300001'
 where id = '11111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

-- Test 1: cui en texto plano debe quedar NULL
select is(
    (select cui from public.profiles where id = '11111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
    NULL,
    '1. CUI en texto plano queda forzado a NULL tras trigger de seguridad'
);

-- Test 2: carne en texto plano debe quedar NULL
select is(
    (select carne from public.profiles where id = '11111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
    NULL,
    '2. Carné en texto plano queda forzado a NULL tras trigger de seguridad'
);

-- Test 3: cui_hash generado con 64 caracteres hexadecimales (SHA-256 HMAC)
select is(
    (select length(cui_hash) from public.profiles where id = '11111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
    64,
    '3. cui_hash posee 64 caracteres hex'
);

-- Test 4: carne_hash generado con 64 caracteres hexadecimales (SHA-256 HMAC)
select is(
    (select length(carne_hash) from public.profiles where id = '11111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
    64,
    '4. carne_hash posee 64 caracteres hex'
);

-- =============================================================================
-- SECCIÓN 2: Perfiles: control de acceso a columnas
-- =============================================================================
select tests.authenticate_as('11111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa');

-- Test 5: Usuario no puede modificar is_verified
select throws_ok(
    $$update public.profiles set is_verified = true where id = '11111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa'$$,
    '42501',
    null,
    '5. Usuario autenticado no puede actualizar is_verified en profiles'
);

-- Test 6: Usuario no puede modificar cui_hash
select throws_ok(
    $$update public.profiles set cui_hash = 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' where id = '11111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa'$$,
    '42501',
    null,
    '6. Usuario autenticado no puede actualizar cui_hash directamente'
);

-- Test 7: Usuario no puede modificar carne_hash
select throws_ok(
    $$update public.profiles set carne_hash = 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff' where id = '11111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa'$$,
    '42501',
    null,
    '7. Usuario autenticado no puede actualizar carne_hash directamente'
);

-- Test 8: Usuario puede actualizar full_name y accepted_terms_*
select lives_ok(
    $$update public.profiles
         set full_name = 'Estudiante Sancarlista Legal',
             accepted_terms_version = 'v2.1',
             accepted_terms_at = now()
       where id = '11111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa'$$,
    '8. Usuario autenticado puede actualizar full_name y accepted_terms_*'
);

-- Test 9: Se verifica persistencia de campos permitidos
select is(
    (select full_name from public.profiles where id = '11111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
    'Estudiante Sancarlista Legal',
    '9. Los cambios permitidos en profiles son persistidos'
);

-- =============================================================================
-- SECCIÓN 3: author_hash por hilo e is_op
-- =============================================================================
-- Usuario A crea Post 1 y Post 2
select tests.authenticate_as('11111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa');

insert into public.posts (
    id, user_id, title, content, category, carrera, author_alias
) values
    ('10000000-0000-0000-0000-000000000001', '11111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Post 1 Legal', 'Contenido 1', 'general', 'sistemas', 'Compilador Desvelado'),
    ('10000000-0000-0000-0000-000000000002', '11111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Post 2 Legal', 'Contenido 2', 'general', 'sistemas', 'Compilador Desvelado');

-- Usuario A comenta 2 veces en Post 1
insert into public.comments (
    id, post_id, user_id, content, author_alias
) values
    ('11000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', '11111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Comentario A1 en Post 1', 'Compilador Desvelado'),
    ('11000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001', '11111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Comentario A2 en Post 1', 'Compilador Desvelado');

-- Usuario B comenta en Post 1 y en Post 2
select tests.authenticate_as('22222222-bbbb-bbbb-bbbb-bbbbbbbbbbbb');

insert into public.comments (
    id, post_id, user_id, content, author_alias
) values
    ('22000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', '22222222-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Comentario B en Post 1', 'Puntero Nocturno'),
    ('22000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002', '22222222-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Comentario B en Post 2', 'Puntero Nocturno');

-- Test 10: Comentario A1 en Post 1 tiene is_op = true
select is(
    (select is_op from public.comments where id = '11000000-0000-0000-0000-000000000001'),
    true,
    '10. Comentario 1 del autor del hilo tiene is_op = true'
);

-- Test 11: Comentario A2 en Post 1 tiene is_op = true
select is(
    (select is_op from public.comments where id = '11000000-0000-0000-0000-000000000002'),
    true,
    '11. Comentario 2 del autor del hilo tiene is_op = true'
);

-- Test 12: Hash de comentario A1 coincide con author_hash de Post 1
select is(
    (select author_hash from public.comments where id = '11000000-0000-0000-0000-000000000001'),
    (select author_hash from public.posts where id = '10000000-0000-0000-0000-000000000001'),
    '12. author_hash de comentario A1 coincide con el author_hash de Post 1'
);

-- Test 13: Hash de comentario A2 coincide con author_hash de Post 1
select is(
    (select author_hash from public.comments where id = '11000000-0000-0000-0000-000000000002'),
    (select author_hash from public.posts where id = '10000000-0000-0000-0000-000000000001'),
    '13. author_hash de comentario A2 coincide con el author_hash de Post 1'
);

-- Test 14: Comentario B en Post 1 tiene is_op = false
select is(
    (select is_op from public.comments where id = '22000000-0000-0000-0000-000000000001'),
    false,
    '14. Comentario de Usuario B en Post 1 tiene is_op = false'
);

-- Test 15: Hash de B en Post 1 es diferente al hash de Post 1
select isnt(
    (select author_hash from public.comments where id = '22000000-0000-0000-0000-000000000001'),
    (select author_hash from public.posts where id = '10000000-0000-0000-0000-000000000001'),
    '15. author_hash de Usuario B en Post 1 difiere del hash de Post 1'
);

-- Test 16: Hash de B en Post 2 es diferente al hash de B en Post 1 (diferente hilo)
select isnt(
    (select author_hash from public.comments where id = '22000000-0000-0000-0000-000000000002'),
    (select author_hash from public.comments where id = '22000000-0000-0000-0000-000000000001'),
    '16. author_hash de Usuario B difiere entre Post 1 y Post 2 (aislamiento por hilo)'
);

-- =============================================================================
-- SECCIÓN 4: Ocultamiento de user_id/RLS y vistas seguras
-- =============================================================================
-- Como Usuario B:
select tests.authenticate_as('22222222-bbbb-bbbb-bbbb-bbbbbbbbbbbb');

-- Test 17: Usuario B no puede ver autoría en post_authors para Post 1
select is(
    (select count(*)::integer from public.post_authors where post_id = '10000000-0000-0000-0000-000000000001'),
    0,
    '17. post_authors oculta autoría ajena a Usuario B mediante RLS'
);

-- Test 18: safe_posts_feed.is_mine es false para Usuario B en Post 1
select is(
    (select is_mine from public.safe_posts_feed where id = '10000000-0000-0000-0000-000000000001'),
    false,
    '18. safe_posts_feed.is_mine = false para Usuario B sobre Post 1'
);

-- Como Usuario A:
select tests.authenticate_as('11111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa');

-- Test 19: safe_posts_feed.is_mine es true para Usuario A en Post 1
select is(
    (select is_mine from public.safe_posts_feed where id = '10000000-0000-0000-0000-000000000001'),
    true,
    '19. safe_posts_feed.is_mine = true para autor A sobre Post 1'
);

-- Test 20: SELECT user_id en posts falla para authenticated
select throws_ok(
    $$select user_id from public.posts limit 1$$,
    '42501',
    null,
    '20. SELECT user_id en posts bloqueado con 42501 para authenticated'
);

-- Como Anon:
select tests.authenticate_as_anon();

-- Test 21: SELECT user_id en posts falla para anon
select throws_ok(
    $$select user_id from public.posts limit 1$$,
    '42501',
    null,
    '21. SELECT user_id en posts bloqueado con 42501 para anon'
);

-- Test 22: SELECT user_id en student_groups falla para anon
select throws_ok(
    $$select user_id from public.student_groups limit 1$$,
    '42501',
    null,
    '22. SELECT user_id en student_groups bloqueado con 42501 para anon'
);

-- Test 23: SELECT user_id en marketplace_items falla para anon
select throws_ok(
    $$select user_id from public.marketplace_items limit 1$$,
    '42501',
    null,
    '23. SELECT user_id en marketplace_items bloqueado con 42501 para anon'
);

-- Test 24: safe_student_groups no expone columna user_id en el catálogo
select hasnt_column(
    'public',
    'safe_student_groups',
    'user_id',
    '24. safe_student_groups no expone la columna user_id'
);

-- Test 25: safe_marketplace_items no expone columna user_id en el catálogo
select hasnt_column(
    'public',
    'safe_marketplace_items',
    'user_id',
    '25. safe_marketplace_items no expone la columna user_id'
);

-- Test 26: safe_student_groups opera limpiamente para anon
select lives_ok(
    $$select id, title, is_mine from public.safe_student_groups limit 1$$,
    '26. anon puede consultar safe_student_groups sin exponer user_id'
);

-- Test 27: safe_marketplace_items opera limpiamente para anon
select lives_ok(
    $$select id, title, is_mine from public.safe_marketplace_items limit 1$$,
    '27. anon puede consultar safe_marketplace_items sin exponer user_id'
);

-- =============================================================================
-- SECCIÓN 5: Inmutabilidad Art. 3 y Prevención de Spoofing
-- =============================================================================
select tests.authenticate_as_moderator('55555555-dddd-dddd-dddd-dddddddddddd');

-- Test 28: Moderador puede actualizar moderation_status
select lives_ok(
    $$update public.posts
         set moderation_status = 1
       where id = '10000000-0000-0000-0000-000000000001'$$,
    '28. Moderador puede actualizar moderation_status de una publicación'
);

-- Test 29: Moderador NO puede editar content de post ajeno
select throws_ok(
    $$update public.posts
         set content = 'Contenido censurado por moderador'
       where id = '10000000-0000-0000-0000-000000000001'$$,
    '42501',
    null,
    '29. Inmutabilidad Art. 3: Moderador no puede editar content ajeno en posts'
);

-- Test 30: Moderador NO puede editar content de comentario ajeno
select throws_ok(
    $$update public.comments
         set content = 'Comentario censurado por moderador'
       where id = '11000000-0000-0000-0000-000000000001'$$,
    '42501',
    null,
    '30. Inmutabilidad Art. 3: Moderador no puede editar content ajeno en comments'
);

-- Como Autor A:
select tests.authenticate_as('11111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa');

-- Test 31: Autor SÍ puede editar su propio content de post
select lives_ok(
    $$update public.posts
         set content = 'Contenido legítimamente editado por el autor'
       where id = '10000000-0000-0000-0000-000000000001'$$,
    '31. Autor puede editar legítimamente el content de su publicación propia'
);

-- Test 32: Autor SÍ puede editar su propio content de comentario
select lives_ok(
    $$update public.comments
         set content = 'Comentario legítimamente editado por el autor'
       where id = '11000000-0000-0000-0000-000000000001'$$,
    '32. Autor puede editar legítimamente el content de su comentario propio'
);

-- Test 33: Intento de spoofing de hot_score por usuario
select throws_ok(
    $$update public.posts
         set hot_score = 999
       where id = '10000000-0000-0000-0000-000000000001'$$,
    '42501',
    null,
    '33. Anti-spoofing: UPDATE hot_score bloqueado con 42501'
);

-- Test 34: Intento de spoofing de is_op en comentarios por usuario B
select tests.authenticate_as('22222222-bbbb-bbbb-bbbb-bbbbbbbbbbbb');
select throws_ok(
    $$update public.comments
         set is_op = true
       where id = '22000000-0000-0000-0000-000000000001'$$,
    '42501',
    null,
    '34. Anti-spoofing: UPDATE comments.is_op bloqueado con 42501'
);

-- =============================================================================
-- SECCIÓN 6: Soft delete + legal hold Art. 20
-- =============================================================================
-- Como Autor A:
select tests.authenticate_as('11111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa');

-- Test 35: DELETE físico del autor falla con 42501
select throws_ok(
    $$delete from public.posts where id = '10000000-0000-0000-0000-000000000002'$$,
    '42501',
    null,
    '35. DELETE físico de post revocado para autor (Art. 20)'
);

-- Test 36: UPDATE deleted_at = now() (soft-delete) funciona para el autor
select lives_ok(
    $$update public.posts
         set deleted_at = now()
       where id = '10000000-0000-0000-0000-000000000002'$$,
    '36. Autor puede ejecutar soft-delete vía UPDATE deleted_at'
);

-- Preparar posts para verificación de purge_expired_soft_deletes
reset role;
set role postgres;
select set_config('request.jwt.claims', '', true);
select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claim.role', '', true);

insert into public.posts (
    id, user_id, title, content, category, carrera, author_alias, deleted_at, is_legal_hold
) values
    ('10000000-0000-0000-0000-000000000088', '11111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Post Con Legal Hold', 'Preservado', 'general', 'sistemas', 'Compilador Desvelado', now() - interval '95 days', true),
    ('10000000-0000-0000-0000-000000000099', '11111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Post Sin Legal Hold', 'Para purgar', 'general', 'sistemas', 'Compilador Desvelado', now() - interval '95 days', false)
on conflict (id) do update set
    deleted_at = excluded.deleted_at,
    is_legal_hold = excluded.is_legal_hold;

update public.posts
   set is_legal_hold = true,
       deleted_at = now() - interval '95 days'
 where id = '10000000-0000-0000-0000-000000000088';

-- Ejecutar purga de registros soft-deleted expirados
select public.purge_expired_soft_deletes();

-- Test 37: Post con is_legal_hold = true SOBREVIVE a la purga
select is(
    (select count(*)::integer from public.posts where id = '10000000-0000-0000-0000-000000000088'),
    1,
    '37. Post con is_legal_hold = true sobrevive a purge_expired_soft_deletes()'
);

-- Test 38: Post sin legal hold expirado (>90 días) es eliminado físicamente por la purga
select is(
    (select count(*)::integer from public.posts where id = '10000000-0000-0000-0000-000000000099'),
    0,
    '38. Post expirado sin legal hold es purgado efectivamente'
);

-- =============================================================================
-- SECCIÓN 7: Hot score y contadores
-- =============================================================================
reset role;
set role postgres;

insert into public.posts (
    id, user_id, title, content, category, carrera, author_alias
) values (
    '10000000-0000-0000-0000-000000000050',
    '11111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'Post para Hot Score',
    'Evaluación de relevancia',
    'general',
    'sistemas',
    'Compilador Desvelado'
) on conflict (id) do nothing;

-- 2 post_likes de 2 usuarios
insert into public.post_likes (post_id, user_id)
values
    ('10000000-0000-0000-0000-000000000050', '11111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
    ('10000000-0000-0000-0000-000000000050', '22222222-bbbb-bbbb-bbbb-bbbbbbbbbbbb')
on conflict do nothing;

-- 1 comentario válido
insert into public.comments (
    id, post_id, user_id, content, author_alias
) values (
    '11000000-0000-0000-0000-000000000050',
    '10000000-0000-0000-0000-000000000050',
    '22222222-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
    'Comentario para contador',
    'Puntero Nocturno'
) on conflict (id) do nothing;

-- Test 39: posts.likes sincronizado a 2
select is(
    (select likes from public.posts where id = '10000000-0000-0000-0000-000000000050'),
    2,
    '39. posts.likes sincronizado automáticamente a 2'
);

-- Test 40: posts.comments_count sincronizado a 1
select is(
    (select comments_count from public.posts where id = '10000000-0000-0000-0000-000000000050'),
    1,
    '40. posts.comments_count sincronizado automáticamente a 1'
);

-- Test 41: posts.hot_score > 1.0 tras interacción
select ok(
    (select hot_score > 1.0 from public.posts where id = '10000000-0000-0000-0000-000000000050'),
    '41. posts.hot_score se incrementa por encima de 1.0'
);

-- Test 42: calculate_hot_score calcula valor coherente según ponderación
select ok(
    (select public.calculate_hot_score(10, 3, 1, now() - interval '5 hours') > 1.0),
    '42. calculate_hot_score(10, 3, 1, 5h) retorna valor ponderado > 1.0'
);

-- =============================================================================
-- SECCIÓN 8: Encuestas (Integridad referencial poll_id / option_id)
-- =============================================================================
reset role;
set role postgres;

insert into public.post_polls (id, post_id, question)
values
    ('70000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Pregunta Encuesta A'),
    ('70000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002', 'Pregunta Encuesta B')
on conflict (id) do nothing;

insert into public.post_poll_options (id, poll_id, option_text)
values
    ('71000000-0000-0000-0000-000000000001', '70000000-0000-0000-0000-000000000001', 'Opcion A1'),
    ('72000000-0000-0000-0000-000000000001', '70000000-0000-0000-0000-000000000002', 'Opcion B1')
on conflict (id) do nothing;

select tests.authenticate_as('11111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa');

-- Test 43: Voto con (poll_id = A, option_id = B1) debe fallar por FK 23503
select throws_ok(
    $$insert into public.post_poll_votes (poll_id, option_id, user_id)
      values (
        '70000000-0000-0000-0000-000000000001',
        '72000000-0000-0000-0000-000000000001',
        '11111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
      )$$,
    '23503',
    null,
    '43. Voto cruzado (poll_id=A, option_id=B1) rechazado por FK (23503)'
);

-- Test 44: Voto válido en encuesta se registra con éxito
select lives_ok(
    $$insert into public.post_poll_votes (poll_id, option_id, user_id)
      values (
        '70000000-0000-0000-0000-000000000001',
        '71000000-0000-0000-0000-000000000001',
        '11111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
      )$$,
    '44. Voto válido en encuesta se inserta correctamente'
);

-- Test 45: post_poll_options.votes_count se incrementa a 1
select is(
    (select votes_count from public.post_poll_options where id = '71000000-0000-0000-0000-000000000001'),
    1,
    '45. post_poll_options.votes_count sincronizado a 1 tras el voto'
);

-- =============================================================================
-- SECCIÓN 9: Auto-cuarentena (3 reportes de riesgo sobre un post)
-- =============================================================================
reset role;
set role postgres;

insert into public.posts (
    id, user_id, title, content, category, carrera, author_alias, moderation_status, is_legal_hold
) values (
    '10000000-0000-0000-0000-000000000060',
    '11111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'Post para Auto-Cuarentena',
    'Post reportado por múltiples usuarios',
    'general',
    'sistemas',
    'Compilador Desvelado',
    0,
    false
) on conflict (id) do nothing;

-- 3 reportes independientes por causas de riesgo: doxxing / Información personal expuesta
insert into public.entity_reports (id, reporter_id, entity_type, entity_id, reason)
values
    ('40000000-0000-0000-0000-000000000061', '11111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'post', '10000000-0000-0000-0000-000000000060', 'doxxing'),
    ('40000000-0000-0000-0000-000000000062', '22222222-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'post', '10000000-0000-0000-0000-000000000060', 'Información personal expuesta'),
    ('40000000-0000-0000-0000-000000000063', '33333333-cccc-cccc-cccc-cccccccccccc', 'post', '10000000-0000-0000-0000-000000000060', 'doxxing')
on conflict (id) do nothing;

-- Test 46: moderation_status = 1 (cuarentena)
select is(
    (select moderation_status from public.posts where id = '10000000-0000-0000-0000-000000000060'),
    1,
    '46. Auto-cuarentena: moderation_status se actualiza automáticamente a 1'
);

-- Test 47: is_legal_hold = true
select is(
    (select is_legal_hold from public.posts where id = '10000000-0000-0000-0000-000000000060'),
    true,
    '47. Auto-cuarentena: is_legal_hold se activa automáticamente a true'
);

-- Test 48: moderation_jobs con priority = 10
select is(
    (select priority from public.moderation_jobs where entity_table = 'posts' and entity_id = '10000000-0000-0000-0000-000000000060' limit 1),
    10,
    '48. Auto-cuarentena: encola trabajo en moderation_jobs con prioridad 10'
);

-- Test 49: moderation_audit_log con is_automated = true
select is(
    (select is_automated from public.moderation_audit_log where entity_table = 'posts' and entity_id = '10000000-0000-0000-0000-000000000060' limit 1),
    true,
    '49. Auto-cuarentena: asienta bitácora con is_automated = true'
);

-- =============================================================================
-- SECCIÓN 10: Revocación de privilegios TRUNCATE (B-01)
-- =============================================================================
-- Test 50: has_table_privilege TRUNCATE en moderation_audit_log = false para authenticated
select is(
    has_table_privilege('authenticated', 'public.moderation_audit_log', 'TRUNCATE'),
    false,
    '50. authenticated no posee privilegio TRUNCATE sobre moderation_audit_log'
);

-- Test 51: has_table_privilege TRUNCATE en posts = false para authenticated
select is(
    has_table_privilege('authenticated', 'public.posts', 'TRUNCATE'),
    false,
    '51. authenticated no posee privilegio TRUNCATE sobre posts'
);

select tests.authenticate_as('11111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa');

-- Test 52: TRUNCATE sobre moderation_audit_log como authenticated falla con 42501
select throws_ok(
    $$TRUNCATE TABLE public.moderation_audit_log$$,
    '42501',
    null,
    '52. TRUNCATE TABLE public.moderation_audit_log bloqueado fulminantemente (42501)'
);

-- Test 53: TRUNCATE sobre posts como authenticated falla con 42501
select throws_ok(
    $$TRUNCATE TABLE public.posts$$,
    '42501',
    null,
    '53. TRUNCATE TABLE public.posts bloqueado fulminantemente (42501)'
);

-- Finalizar suite
select * from finish();
rollback;
