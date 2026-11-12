-- =============================================================================
-- pgTAP: verified seller gate and server-authoritative sponsorship flags
-- =============================================================================
begin;

select plan(5);

create extension if not exists pgtap;

do $$
begin
  perform tests.create_supabase_user('77777777-7777-7777-7777-777777777777');
  perform tests.create_supabase_user('88888888-8888-8888-8888-888888888888');
  insert into public.profiles (id, full_name)
  values
    ('77777777-7777-7777-7777-777777777777', 'Vendedor de prueba'),
    ('88888888-8888-8888-8888-888888888888', 'Admin de prueba')
  on conflict (id) do nothing;
end;
$$;

select tests.authenticate_as_aal1(
  '77777777-7777-7777-7777-777777777777'
);

select throws_ok(
  $$insert into public.marketplace_items (
      title, description, author_alias, user_id
    ) values (
      'Anuncio no verificado', 'Debe ser rechazado', 'Usuario',
      '77777777-7777-7777-7777-777777777777'
    )$$,
  '42501',
  'AAL1 y vendedor no verificado no pueden publicar'
);

select tests.authenticate_as_admin(
  '88888888-8888-8888-8888-888888888888'
);

select lives_ok(
  $$update public.profiles
       set seller_verification_status = 'verified',
           seller_verified_at = now(),
           seller_verified_by = '88888888-8888-8888-8888-888888888888'
     where id = '77777777-7777-7777-7777-777777777777'$$,
  'El personal autorizado puede verificar al vendedor'
);

select tests.authenticate_as(
  '77777777-7777-7777-7777-777777777777'
);

select lives_ok(
  $$insert into public.marketplace_items (
      title, description, author_alias, user_id, is_sponsored,
      sponsor_badge_text, sponsor_brand_name
    ) values (
      'Anuncio regular', 'Publicación de prueba', 'Usuario',
      '77777777-7777-7777-7777-777777777777', true,
      'Patrocinado', 'Marca falsa'
    )$$,
  'El vendedor verificado puede publicar pero no asignarse patrocinio'
);

select is(
  (select is_sponsored from public.marketplace_items
    where title = 'Anuncio regular'),
  false,
  'El trigger ignora el autopatrocinio enviado por el cliente'
);

select is(
  (select sponsor_brand_name from public.marketplace_items
    where title = 'Anuncio regular'),
  null::text,
  'El trigger elimina la marca que no aprobó el personal'
);

select * from finish();
rollback;
