-- =============================================================================
-- pgTAP: una sesión autenticada AAL1 puede escribir sin exigir OTP
-- =============================================================================
begin;

select plan(7);

create extension if not exists pgtap;

do $$
declare
    v_user uuid := '77777777-7777-7777-7777-777777777777';
begin
    perform tests.create_supabase_user(v_user, 'authenticated_user@test.com');
end;
$$;

select tests.authenticate_as_aal1(
    '77777777-7777-7777-7777-777777777777'
);

select lives_ok(
    $$insert into public.posts (
        id, user_id, title, content, category, carrera, author_alias, moderation_status
      ) values (
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0077',
        '77777777-7777-7777-7777-777777777777',
        'Post sin requisito de OTP',
        'Contenido de prueba',
        'general',
        'sistemas',
        'Usuario de prueba',
        0
      )$$,
    'AAL1 puede insertar contenido autenticado'
);

select is(
    (select count(*)::integer from public.posts
      where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0077'),
    1,
    'La fila insertada por AAL1 queda guardada'
);

select lives_ok(
    $$update public.posts
         set title = 'Post actualizado sin requisito de OTP'
       where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0077'$$,
    'AAL1 puede actualizar su contenido'
);

select is(
    (select title from public.posts
      where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0077'),
    'Post actualizado sin requisito de OTP',
    'La actualización de AAL1 queda guardada'
);

select lives_ok(
    $$select public.report_forum_post(
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0077'::uuid,
        'spam'
      )$$,
    'AAL1 puede llamar al RPC de reporte sin exigir OTP'
);

select lives_ok(
    $$delete from public.posts
       where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0077'$$,
    'AAL1 puede eliminar su contenido según las políticas existentes'
);

select is(
    (select count(*)::integer from public.posts
      where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaa0077'),
    0,
    'La fila eliminada por AAL1 ya no existe'
);

select * from finish();
rollback;
