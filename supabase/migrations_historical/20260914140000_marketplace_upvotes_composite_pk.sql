-- =============================================================================
-- PEMTREE · Upvotes consistentes: marketplace_upvotes con PK compuesta
-- Fecha: 2026-09-14
--
-- Corrige el hallazgo "Upvotes inconsistentes":
--   - post_likes          → PK (post_id, user_id)
--   - student_group_upvotes → PK (group_id, user_id)
--   - marketplace_upvotes → tenía PK (id) + UNIQUE (item_id, user_id)
--
-- La unicidad funcional ya estaba garantizada por la UNIQUE, así que no se
-- podían emitir votos duplicados. Lo que faltaba era la consistencia
-- estructural: se convierte la PK a (item_id, user_id) y se elimina la
-- columna sustituta `id` (que no usa ni la app, ni las policies RLS, ni el
-- trigger de contador de upvotes).
--
-- Es idempotente.
-- =============================================================================

-- 1) Dedupe defensivo (la UNIQUE ya lo impide; por si acaso hubiera filas
--    cargadas antes de que existiera la restricción)
delete from public.marketplace_upvotes a
using public.marketplace_upvotes b
where a.item_id = b.item_id
  and a.user_id = b.user_id
  and a.ctid < b.ctid;

-- 2) Quitar la PK vieja (id) y la UNIQUE que quedará cubierta por la nueva PK
alter table public.marketplace_upvotes
  drop constraint if exists marketplace_upvotes_pkey;
alter table public.marketplace_upvotes
  drop constraint if exists marketplace_upvotes_item_id_user_id_key;

-- 3) Eliminar la columna sustituta id (nadie la referencia)
alter table public.marketplace_upvotes
  drop column if exists id;

-- 4) PK compuesta, igual que post_likes y student_group_upvotes
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.marketplace_upvotes'::regclass
      and conname = 'marketplace_upvotes_pkey'
  ) then
    alter table public.marketplace_upvotes
      add constraint marketplace_upvotes_pkey primary key (item_id, user_id);
  end if;
end $$;

comment on table public.marketplace_upvotes is
  'Upvotes de marketplace. PK compuesta (item_id, user_id) e igual esquema que post_likes y student_group_upvotes.';

-- 5) Resumen
do $$
declare
  v_pk text;
  v_unique text;
  v_has_id boolean;
begin
  select pg_get_constraintdef(oid) into v_pk
  from pg_constraint
  where conrelid = 'public.marketplace_upvotes'::regclass and contype = 'p';

  select coalesce(string_agg(conname, ', '), 'ninguna') into v_unique
  from pg_constraint
  where conrelid = 'public.marketplace_upvotes'::regclass and contype = 'u';

  select exists (
    select 1 from pg_attribute
    where attrelid = 'public.marketplace_upvotes'::regclass
      and attname = 'id' and attnum > 0 and not attisdropped
  ) into v_has_id;

  raise notice 'marketplace_upvotes → PK: % | UNIQUE extra: % | columna id: %',
    v_pk, v_unique, case when v_has_id then 'presente' else 'eliminada' end;
end $$;
