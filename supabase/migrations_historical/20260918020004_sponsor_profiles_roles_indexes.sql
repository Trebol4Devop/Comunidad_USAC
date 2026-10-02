-- =============================================================================
-- PEMTREE · Índices específicos faltantes
-- Fecha: 2026-09-18
--
-- El resto de la lista ya existía:
--   idx_post_poll_votes_option / _user_id, unique_user_seccion_review,
--   idx_seccion_reviews_curso_seccion, idx_profiles_carrera,
--   idx_subscriptions_user, idx_post_bookmarks_user, idx_post_likes_user_id.
--
-- Es idempotente.
-- =============================================================================

-- Sponsor requests: cola por estado ordenada por fecha (panel admin)
create index if not exists idx_sponsor_requests_status
  on public.sponsor_requests (status, created_at desc);

-- Profiles: pendientes de verificación. Parcial en vez de indexar el booleano
-- completo (baja cardinalidad): sirve a "WHERE is_verified = false".
create index if not exists idx_profiles_unverified
  on public.profiles (created_at)
  where not is_verified;

-- Roles: listados por rol (admin/moderador)
create index if not exists idx_user_roles_role
  on public.user_roles (role);
