-- =============================================================================
-- Fix: ambigüedad de public.generate_author_hash(uuid)
-- =============================================================================
-- El baseline define dos variantes:
--   generate_author_hash(uuid)
--   generate_author_hash(uuid, text DEFAULT 'USAC_COMMUNITY_ANON_SECRET_SALT_2026_KEY')
--
-- Como la segunda tiene DEFAULT en p_salt, una llamada con un solo uuid es
-- ambigua (SQLSTATE 42725 "function is not unique") y rompía el trigger
-- handle_post_author_hash() y, con él, cualquier INSERT en public.posts.
--
-- La variante de 1 argumento es un wrapper redundante: solo delega en la de
-- 2 argumentos con el salt estándar, exactamente lo que ya hace su DEFAULT.
-- Se elimina el wrapper y queda una única función, resolviendo la ambigüedad
-- tanto para Postgres como para la capa PostgREST:
--   generate_author_hash(uuid)        -> usa el DEFAULT
--   generate_author_hash(uuid, salt)  -> salt explícito
-- =============================================================================

drop function if exists public.generate_author_hash(uuid);
