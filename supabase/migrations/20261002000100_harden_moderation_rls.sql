-- =============================================================================
-- Endurecimiento de RLS de moderación (posts / comments)
-- =============================================================================
-- 1) Los triggers handle_post_author_hash / handle_comment_author_hash
--    reescribían NEW.user_id := auth.uid(), lo que neutralizaba el WITH CHECK
--    de las políticas INSERT ("auth.uid() = user_id"): un intento de
--    suplantación no fallaba, quedaba reescrito en silencio. Se deja de
--    reescribir user_id para que RLS rechace la suplantación con excepción.
--    El author_hash se sigue calculando a partir del usuario autenticado.
--
-- 2) La política SELECT de authenticated permitía al DUEÑO ver su propio
--    contenido con moderation_status = 2. La app excluye explícitamente ese
--    estado en todas sus lecturas (.neq('moderation_status', 2)) y el estado 2
--    significa "oculto/bloqueado" de forma global. Se retira la excepción del
--    dueño; admin y moderador conservan el acceso.
-- =============================================================================

create or replace function public.handle_post_author_hash() returns trigger
    language plpgsql security definer
    set search_path to 'public'
    as $$
declare
  v_uid uuid := coalesce(auth.uid(), new.user_id);
begin
  if v_uid is not null then
    new.author_hash := public.generate_author_hash(v_uid);
  end if;
  return new;
end;
$$;

create or replace function public.handle_comment_author_hash() returns trigger
    language plpgsql security definer
    set search_path to 'public'
    as $$
declare
  v_uid uuid := coalesce(auth.uid(), new.user_id);
begin
  if v_uid is not null then
    new.author_hash := public.generate_author_hash(v_uid);
  end if;
  return new;
end;
$$;

drop policy if exists "Lectura de posts (auth: dueño/admin/moderador ven estado 2)" on public.posts;
create policy "Lectura de posts (auth: admin/moderador ven estado 2)"
    on public.posts
    for select
    to authenticated
    using (
        (moderation_status is distinct from 2)
        or public.is_pemtree_admin((select auth.uid()))
        or public.is_pemtree_moderator((select auth.uid()))
    );

drop policy if exists "Lectura de comentarios (auth: dueño/admin/moderador ven estado 2)" on public.comments;
create policy "Lectura de comentarios (auth: admin/moderador ven estado 2)"
    on public.comments
    for select
    to authenticated
    using (
        (moderation_status is distinct from 2)
        or public.is_pemtree_admin((select auth.uid()))
        or public.is_pemtree_moderator((select auth.uid()))
    );

-- =============================================================================
-- 3) force_marketplace_item_owner() asignaba NEW.user_id := auth.uid() de forma
--    incondicional. En contextos privilegiados (service_role, migraciones,
--    fixtures de pgTAP) auth.uid() es NULL, por lo que dejaba user_id = NULL y
--    el dueño real del item se perdía. Se preserva el user_id explícito cuando
--    no hay sesión autenticada.
-- =============================================================================

create or replace function public.force_marketplace_item_owner() returns trigger
    language plpgsql security definer
    set search_path to 'public'
    as $$
begin
  new.user_id := coalesce(auth.uid(), new.user_id);
  return new;
end;
$$;
