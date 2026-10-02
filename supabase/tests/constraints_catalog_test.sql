-- =============================================================================
-- PEMTREE / Comunidad USAC · pgTAP Test: Constraints, Integridad y Catálogos
-- =============================================================================
begin;

select plan(19);

create extension if not exists pgtap;

-- Usuario base referenciado por los inserts de prueba. Necesario porque la FK
-- marketplace_items.user_id -> auth.users se valida de verdad (el trigger de
-- propiedad ya no sobreescribe user_id con NULL en contextos sin sesión).
select tests.create_supabase_user('11111111-1111-1111-1111-111111111111');

-- -----------------------------------------------------------------------------
-- Bloque 1: Checks de moderation_status (rango 0..3)
-- -----------------------------------------------------------------------------
-- Test 1: posts.moderation_status invalido (4) viola check
select throws_ok(
    $$insert into public.posts (
        id, user_id, title, content, category, carrera, author_alias, moderation_status
      ) values (
        gen_random_uuid(),
        '11111111-1111-1111-1111-111111111111',
        'Post Invalido',
        'Contenido',
        'general',
        'sistemas',
        'Alias',
        4
      )$$,
    '23514',
    null,
    'posts_moderation_status_check impide valores fuera de 0..3'
);

-- Test 2: comments.moderation_status invalido (-1) viola check
select throws_ok(
    $$insert into public.comments (
        id, post_id, user_id, content, author_alias, moderation_status
      ) values (
        gen_random_uuid(),
        gen_random_uuid(),
        '11111111-1111-1111-1111-111111111111',
        'Comentario Invalido',
        'Alias',
        -1
      )$$,
    '23514',
    null,
    'comments_moderation_status_check impide valores negativos'
);

-- Test 3: marketplace_items.moderation_status invalido (5) viola check
select throws_ok(
    $$insert into public.marketplace_items (
        id, user_id, title, description, price, category, facultad, author_alias, moderation_status
      ) values (
        gen_random_uuid(),
        '11111111-1111-1111-1111-111111111111',
        'Item Invalido',
        'Desc',
        10.0,
        'otros_articulos',
        '08',
        'Alias',
        5
      )$$,
    '23514',
    null,
    'marketplace_items_moderation_status_check impide valores mayores a 3'
);

-- Test 4: student_groups.moderation_status invalido (9) viola check
select throws_ok(
    $$insert into public.student_groups (
        id, user_id, title, description, carrera, curso, section, link, author_alias, moderation_status
      ) values (
        gen_random_uuid(),
        '11111111-1111-1111-1111-111111111111',
        'Grupo Invalido',
        'Desc',
        'sistemas',
        'Curso',
        'A',
        'https://chat.whatsapp.com/inv',
        'Alias',
        9
      )$$,
    '23514',
    null,
    'student_groups_moderation_status_check impide valores fuera de 0..3'
);

-- Test 5: entity_reports.moderation_status invalido (10) viola check
select throws_ok(
    $$insert into public.entity_reports (
        id, reporter_id, entity_type, entity_id, reason, moderation_status
      ) values (
        gen_random_uuid(),
        '11111111-1111-1111-1111-111111111111',
        'group',
        gen_random_uuid(),
        'Motivo',
        10
      )$$,
    '23514',
    null,
    'entity_reports_moderation_status_check impide valores fuera de escala'
);

-- -----------------------------------------------------------------------------
-- Bloque 2: Check de marketplace_items.status
-- -----------------------------------------------------------------------------
-- Test 6: status invalido 'no_existe' es rechazado
select throws_ok(
    $$insert into public.marketplace_items (
        id, user_id, title, description, price, category, facultad, author_alias, status
      ) values (
        gen_random_uuid(),
        '11111111-1111-1111-1111-111111111111',
        'Item Estado Erroneo',
        'Desc',
        10.0,
        'otros_articulos',
        '08',
        'Alias',
        'estado_falso'
      )$$,
    '23514',
    null,
    'marketplace_items_status_check rechaza estados no enumerados'
);

-- Test 7: status valido 'paused' es aceptado
select lives_ok(
    $$insert into public.marketplace_items (
        id, user_id, title, description, price, category, facultad, author_alias, status
      ) values (
        '70000000-0000-0000-0000-000000000001',
        '11111111-1111-1111-1111-111111111111',
        'Item Pausado',
        'En pausa temporal',
        25.0,
        'otros_articulos',
        '08',
        'Alias',
        'paused'
      )$$,
    'marketplace_items_status_check permite el estado paused utilizado por la app'
);

-- -----------------------------------------------------------------------------
-- Bloque 3: Composite Primary Keys en tablas de upvotes/likes
-- -----------------------------------------------------------------------------
-- Test 8: marketplace_upvotes tiene PK (item_id, user_id)
select col_is_pk(
    'public',
    'marketplace_upvotes',
    array['item_id', 'user_id'],
    'marketplace_upvotes posee PK compuesta estructurada por (item_id, user_id)'
);

-- Test 9: post_likes tiene PK (post_id, user_id)
select col_is_pk(
    'public',
    'post_likes',
    array['post_id', 'user_id'],
    'post_likes posee PK compuesta estructurada por (post_id, user_id)'
);

-- Test 10: student_group_upvotes tiene PK (group_id, user_id)
select col_is_pk(
    'public',
    'student_group_upvotes',
    array['group_id', 'user_id'],
    'student_group_upvotes posee PK compuesta estructurada por (group_id, user_id)'
);

-- -----------------------------------------------------------------------------
-- Bloque 4: Foreign Keys hacia tablas de catálogo
-- -----------------------------------------------------------------------------
-- Test 11: post con categoría inexistente falla por FK
select throws_ok(
    $$insert into public.posts (
        id, user_id, title, content, category, carrera, author_alias
      ) values (
        gen_random_uuid(),
        '11111111-1111-1111-1111-111111111111',
        'Post Categoria Falsa',
        'Desc',
        'categoria_inexistente',
        'sistemas',
        'Alias'
      )$$,
    '23503',
    null,
    'posts_category_catalogo_fkey impide categorias de foro fuera del catalogo'
);

-- Test 12: post con carrera inexistente falla por FK
select throws_ok(
    $$insert into public.posts (
        id, user_id, title, content, category, carrera, author_alias
      ) values (
        gen_random_uuid(),
        '11111111-1111-1111-1111-111111111111',
        'Post Carrera Falsa',
        'Desc',
        'general',
        'carrera_falsa_999',
        'Alias'
      )$$,
    '23503',
    null,
    'posts_carrera_catalogo_fkey impide carreras fuera del catalogo de carreras'
);

-- Test 13: marketplace con facultad inexistente falla por FK
select throws_ok(
    $$insert into public.marketplace_items (
        id, user_id, title, description, price, category, facultad, author_alias
      ) values (
        gen_random_uuid(),
        '11111111-1111-1111-1111-111111111111',
        'Item Facultad Falsa',
        'Desc',
        10.0,
        'otros_articulos',
        'facultad_invalida_99',
        'Alias'
      )$$,
    '23503',
    null,
    'marketplace_items_facultad_catalogo_fkey rechaza facultades no catalogadas'
);

-- -----------------------------------------------------------------------------
-- Bloque 5: Verificación de Catálogos Sembrados
-- -----------------------------------------------------------------------------
-- Test 14: Catalogo de facultades sembrado
select ok(
    (select count(*) >= 11 from public.facultades),
    'El catalogo public.facultades contiene las 11 facultades oficiales de la USAC'
);

-- Test 15: Catalogo de carreras sembrado
select ok(
    (select count(*) >= 50 from public.carreras),
    'El catalogo public.carreras contiene al menos 50 carreras registradas'
);

-- Test 16: Catalogo de categorias de foro sembrado
select ok(
    (select count(*) >= 6 from public.categorias_foro),
    'El catalogo public.categorias_foro contiene al menos 6 categorias estandar'
);

-- Test 17: Catalogo de categorias de marketplace sembrado
select ok(
    (select count(*) >= 6 from public.categorias_marketplace),
    'El catalogo public.categorias_marketplace contiene al menos 6 categorias'
);

-- Test 18: Facultad '08' (Ingeniería) existe
select ok(
    (select exists(select 1 from public.facultades where id = '08' and nombre like '%Ingeniería%')),
    'La Facultad de Ingenieria (id 08) existe en el catalogo'
);

-- Test 19: Carrera 'sistemas' existe vinculada a facultad '08'
select ok(
    (select exists(select 1 from public.carreras where id = 'sistemas' and facultad_id = '08')),
    'La carrera sistemas pertenece a la facultad 08 en el catalogo'
);

select * from finish();
rollback;
