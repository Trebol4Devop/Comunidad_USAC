-- =============================================================================
-- PEMTREE · Políticas RLS para Paneles de Administración (Sponsors, Roles, Perfiles)
-- Fecha: 2026-09-18
--
-- Habilita permisos completos de administración para:
--   1. sponsor_requests: lectura y gestión de solicitudes de patrocinio
--   2. user_roles: alta, modificación y revocación de moderadores y administradores
--   3. profiles: actualización administrativa para verificación de carné/CUI
--
-- Es idempotente.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) sponsor_requests
-- -----------------------------------------------------------------------------
alter table if exists public.sponsor_requests enable row level security;

drop policy if exists "Anyone can insert sponsor requests" on public.sponsor_requests;
drop policy if exists "Admins and moderators can view sponsor requests" on public.sponsor_requests;
drop policy if exists "Admins and moderators can update sponsor requests" on public.sponsor_requests;
drop policy if exists "Admins can delete sponsor requests" on public.sponsor_requests;

create policy "Anyone can insert sponsor requests"
  on public.sponsor_requests
  for insert
  to anon, authenticated
  with check (true);

create policy "Admins and moderators can view sponsor requests"
  on public.sponsor_requests
  for select
  to authenticated
  using (
    user_id = (select auth.uid())
    or (select public.is_pemtree_admin((select auth.uid())))
    or (select public.is_pemtree_moderator((select auth.uid())))
  );

create policy "Admins and moderators can update sponsor requests"
  on public.sponsor_requests
  for update
  to authenticated
  using (
    (select public.is_pemtree_admin((select auth.uid())))
    or (select public.is_pemtree_moderator((select auth.uid())))
  )
  with check (
    (select public.is_pemtree_admin((select auth.uid())))
    or (select public.is_pemtree_moderator((select auth.uid())))
  );

create policy "Admins can delete sponsor requests"
  on public.sponsor_requests
  for delete
  to authenticated
  using (
    (select public.is_pemtree_admin((select auth.uid())))
  );

-- -----------------------------------------------------------------------------
-- 2) user_roles
-- -----------------------------------------------------------------------------
alter table if exists public.user_roles enable row level security;

drop policy if exists "Admins can insert user roles" on public.user_roles;
drop policy if exists "Admins can update user roles" on public.user_roles;
drop policy if exists "Admins can delete user roles" on public.user_roles;
drop policy if exists "Users and staff can view user roles" on public.user_roles;

create policy "Users and staff can view user roles"
  on public.user_roles
  for select
  to authenticated
  using (
    user_id = (select auth.uid())
    or (select public.is_pemtree_admin((select auth.uid())))
    or (select public.is_pemtree_moderator((select auth.uid())))
  );

create policy "Admins can insert user roles"
  on public.user_roles
  for insert
  to authenticated
  with check (
    (select public.is_pemtree_admin((select auth.uid())))
  );

create policy "Admins can update user roles"
  on public.user_roles
  for update
  to authenticated
  using (
    (select public.is_pemtree_admin((select auth.uid())))
  )
  with check (
    (select public.is_pemtree_admin((select auth.uid())))
  );

create policy "Admins can delete user roles"
  on public.user_roles
  for delete
  to authenticated
  using (
    (select public.is_pemtree_admin((select auth.uid())))
  );

-- -----------------------------------------------------------------------------
-- 3) profiles: actualización por administradores
-- -----------------------------------------------------------------------------
drop policy if exists "Users and admins can update profiles" on public.profiles;
drop policy if exists "Users can update own profile" on public.profiles;

create policy "Users and admins can update profiles"
  on public.profiles
  for update
  to authenticated
  using (
    id = (select auth.uid())
    or (select public.is_pemtree_admin((select auth.uid())))
  )
  with check (
    id = (select auth.uid())
    or (select public.is_pemtree_admin((select auth.uid())))
  );
