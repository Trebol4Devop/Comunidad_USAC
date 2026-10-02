-- =============================================================================
-- PEMTREE / Comunidad USAC · pgTAP Test: Sincronización de Contadores y Triggers
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
begin
    perform tests.create_supabase_user(v_u1, 'u1@test.com');
    perform tests.create_supabase_user(v_u2, 'u2@test.com');
    perform tests.create_supabase_user(v_u3, 'u3@test.com');

    -- Post con likes en 0
    insert into public.posts (
        id, user_id, title, content, category, carrera, author_alias, likes, moderation_status
    ) values (
        '10000000-0000-0000-0000-000000000001', v_u1, 'Post para Contador de Likes', 'Contenido', 'general', 'sistemas', 'U1', 0, 0
    ) on conflict (id) do nothing;

    -- Grupo con upvotes y reports en 0
    insert into public.student_groups (
        id, user_id, title, description, carrera, curso, section, link, upvotes, reported_count, moderation_status
    ) values (
        '20000000-0000-0000-0000-000000000001', v_u1, 'Grupo para Contadores', 'Desc', 'sistemas', 'Curso A', 'A', 'https://chat.whatsapp.com/cnt', 0, 0, 0
    ) on conflict (id) do nothing;

    -- Marketplace con upvotes y reports en 0
    insert into public.marketplace_items (
        id, user_id, title, description, price, category, facultad, upvotes, reported_count, status, moderation_status, author_alias
    ) values (
        '30000000-0000-0000-0000-000000000001', v_u1, 'Item para Contadores', 'Desc', 50.0, 'otros_articulos', '08', 0, 0, 'available', 0, 'U1'
    ) on conflict (id) do nothing;
end $$;

-- -----------------------------------------------------------------------------
-- Bloque 1: Triggers de posts.likes (trg_sync_post_likes / post_likes)
-- -----------------------------------------------------------------------------
-- Test 1: Insert primer like -> posts.likes = 1
insert into public.post_likes (post_id, user_id)
values ('10000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111');

select is(
    (select likes from public.posts where id = '10000000-0000-0000-0000-000000000001'),
    1,
    'trg_sync_post_likes incrementa posts.likes a 1 al insertar primer like'
);

-- Test 2: Insert segundo like -> posts.likes = 2
insert into public.post_likes (post_id, user_id)
values ('10000000-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222');

select is(
    (select likes from public.posts where id = '10000000-0000-0000-0000-000000000001'),
    2,
    'trg_sync_post_likes incrementa posts.likes a 2 al registrar otro usuario'
);

-- Test 3: Delete un like -> posts.likes = 1
delete from public.post_likes
 where post_id = '10000000-0000-0000-0000-000000000001'
   and user_id = '11111111-1111-1111-1111-111111111111';

select is(
    (select likes from public.posts where id = '10000000-0000-0000-0000-000000000001'),
    1,
    'trg_sync_post_likes decrementa posts.likes a 1 al eliminar el like'
);

-- -----------------------------------------------------------------------------
-- Bloque 2: Triggers de student_groups.upvotes (trg_sync_group_upvotes)
-- -----------------------------------------------------------------------------
-- Test 4: Insert primer upvote en grupo -> student_groups.upvotes = 1
insert into public.student_group_upvotes (group_id, user_id)
values ('20000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111');

select is(
    (select upvotes from public.student_groups where id = '20000000-0000-0000-0000-000000000001'),
    1,
    'trg_sync_group_upvotes sincroniza student_groups.upvotes a 1 tras el primer upvote'
);

-- Test 5: Insert segundo upvote en grupo -> student_groups.upvotes = 2
insert into public.student_group_upvotes (group_id, user_id)
values ('20000000-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222');

select is(
    (select upvotes from public.student_groups where id = '20000000-0000-0000-0000-000000000001'),
    2,
    'trg_sync_group_upvotes sincroniza student_groups.upvotes a 2 tras el segundo upvote'
);

-- Test 6: Delete upvote en grupo -> student_groups.upvotes = 1
delete from public.student_group_upvotes
 where group_id = '20000000-0000-0000-0000-000000000001'
   and user_id = '11111111-1111-1111-1111-111111111111';

select is(
    (select upvotes from public.student_groups where id = '20000000-0000-0000-0000-000000000001'),
    1,
    'trg_sync_group_upvotes reduce student_groups.upvotes al remover un upvote'
);

-- -----------------------------------------------------------------------------
-- Bloque 3: Triggers de marketplace_items.upvotes (trg_sync_marketplace_upvotes)
-- -----------------------------------------------------------------------------
-- Test 7: Insert primer upvote en marketplace -> marketplace_items.upvotes = 1
insert into public.marketplace_upvotes (item_id, user_id)
values ('30000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111');

select is(
    (select upvotes from public.marketplace_items where id = '30000000-0000-0000-0000-000000000001'),
    1,
    'trg_sync_marketplace_upvotes incrementa marketplace_items.upvotes a 1'
);

-- Test 8: Insert segundo upvote en marketplace -> marketplace_items.upvotes = 2
insert into public.marketplace_upvotes (item_id, user_id)
values ('30000000-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222');

select is(
    (select upvotes from public.marketplace_items where id = '30000000-0000-0000-0000-000000000001'),
    2,
    'trg_sync_marketplace_upvotes incrementa marketplace_items.upvotes a 2'
);

-- Test 9: Delete upvote en marketplace -> marketplace_items.upvotes = 1
delete from public.marketplace_upvotes
 where item_id = '30000000-0000-0000-0000-000000000001'
   and user_id = '11111111-1111-1111-1111-111111111111';

select is(
    (select upvotes from public.marketplace_items where id = '30000000-0000-0000-0000-000000000001'),
    1,
    'trg_sync_marketplace_upvotes decrementa marketplace_items.upvotes tras delete'
);

-- -----------------------------------------------------------------------------
-- Bloque 4: Triggers de reported_count (trg_sync_entity_report_counters)
-- -----------------------------------------------------------------------------
-- Test 10: Insert reporte para grupo -> student_groups.reported_count = 1
insert into public.entity_reports (
    id, reporter_id, entity_type, entity_id, reason
) values (
    '40000000-0000-0000-0000-000000000001',
    '11111111-1111-1111-1111-111111111111',
    'group',
    '20000000-0000-0000-0000-000000000001',
    'Enlace caido'
);

select is(
    (select reported_count from public.student_groups where id = '20000000-0000-0000-0000-000000000001'),
    1,
    'trg_sync_entity_report_counters actualiza student_groups.reported_count a 1'
);

-- Test 11: Insert segundo reporte para grupo con otro reportero -> reported_count = 2
insert into public.entity_reports (
    id, reporter_id, entity_type, entity_id, reason
) values (
    '40000000-0000-0000-0000-000000000002',
    '22222222-2222-2222-2222-222222222222',
    'group',
    '20000000-0000-0000-0000-000000000001',
    'Spam publicitario'
);

select is(
    (select reported_count from public.student_groups where id = '20000000-0000-0000-0000-000000000001'),
    2,
    'trg_sync_entity_report_counters acumula student_groups.reported_count a 2'
);

-- Test 12: Delete un reporte de grupo -> student_groups.reported_count = 1
delete from public.entity_reports where id = '40000000-0000-0000-0000-000000000001';

select is(
    (select reported_count from public.student_groups where id = '20000000-0000-0000-0000-000000000001'),
    1,
    'trg_sync_entity_report_counters decrementa student_groups.reported_count tras delete'
);

-- Test 13: Insert reporte en marketplace_item -> marketplace_items.reported_count = 1
insert into public.entity_reports (
    id, reporter_id, entity_type, entity_id, reason
) values (
    '40000000-0000-0000-0000-000000000003',
    '11111111-1111-1111-1111-111111111111',
    'marketplace_item',
    '30000000-0000-0000-0000-000000000001',
    'Precio enganoso'
);

select is(
    (select reported_count from public.marketplace_items where id = '30000000-0000-0000-0000-000000000001'),
    1,
    'trg_sync_entity_report_counters actualiza marketplace_items.reported_count a 1'
);

-- Test 14: Delete reporte de marketplace -> marketplace_items.reported_count = 0
delete from public.entity_reports where id = '40000000-0000-0000-0000-000000000003';

select is(
    (select reported_count from public.marketplace_items where id = '30000000-0000-0000-0000-000000000001'),
    0,
    'trg_sync_entity_report_counters resetea marketplace_items.reported_count a 0 tras eliminar el reporte'
);

select * from finish();
rollback;
