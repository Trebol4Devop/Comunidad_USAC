-- =============================================================================
-- PEMTREE · notification_preference_carreras
-- Fecha: 2026-09-18
--
-- Reemplaza notification_preferences.carreras (text[] sin FK) por una tabla
-- intermedia con integridad referencial contra el catálogo carreras.
--
-- Incluye:
--   1. Tabla notification_preference_carreras(user_id, carrera_id) con FKs.
--   2. Backfill desde el array (idempotente).
--   3. RLS: cada usuario solo ve/crea/borra sus propias carreras.
--   4. Reemplazo de _triggers.notify_new_post() para usar la tabla intermedia.
--   5. Eliminación de la columna notification_preferences.carreras.
--
-- Es idempotente.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) Tabla intermedia con FK a carreras
-- -----------------------------------------------------------------------------
create table if not exists public.notification_preference_carreras (
  user_id uuid not null
    references public.notification_preferences(user_id) on delete cascade,
  carrera_id text not null
    references public.carreras(id) on update cascade on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, carrera_id)
);

comment on table public.notification_preference_carreras is
  'Carreras suscritas por usuario para notificaciones (reemplaza notification_preferences.carreras text[]). Integridad garantizada por FK a carreras.';

-- -----------------------------------------------------------------------------
-- 2) Backfill desde el array (idempotente)
-- -----------------------------------------------------------------------------
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='notification_preferences' and column_name='carreras'
  ) then
    insert into public.notification_preference_carreras (user_id, carrera_id)
    select np.user_id, c
    from public.notification_preferences np
    cross join lateral unnest(np.carreras) as c
    where c is not null and btrim(c) <> ''
    on conflict (user_id, carrera_id) do nothing;
  end if;
end $$;

-- -----------------------------------------------------------------------------
-- 3) RLS
-- -----------------------------------------------------------------------------
alter table public.notification_preference_carreras enable row level security;

drop policy if exists "Ver mis carreras de notificación" on public.notification_preference_carreras;
create policy "Ver mis carreras de notificación"
  on public.notification_preference_carreras
  for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Crear mis carreras de notificación" on public.notification_preference_carreras;
create policy "Crear mis carreras de notificación"
  on public.notification_preference_carreras
  for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "Borrar mis carreras de notificación" on public.notification_preference_carreras;
create policy "Borrar mis carreras de notificación"
  on public.notification_preference_carreras
  for delete to authenticated
  using ((select auth.uid()) = user_id);

grant select, insert, delete on public.notification_preference_carreras to authenticated;

-- -----------------------------------------------------------------------------
-- 4) notify_new_post pasa a usar la tabla intermedia
-- -----------------------------------------------------------------------------
create or replace function _triggers.notify_new_post()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
declare
    r record;
    v_carrera text := coalesce(NEW.carrera, 'todas');
begin
    for r in
        select np.user_id
          from public.notification_preferences np
         where np.new_post_enabled
           and exists (
               select 1
                 from public.notification_preference_carreras npc
                where npc.user_id = np.user_id
                  and npc.carrera_id in (v_carrera, 'todas')
           )
    loop
        perform _triggers.crear_notificacion_foro(
            p_user_id     := r.user_id,
            p_type        := 'new_post',
            p_title       := left(coalesce(NEW.title, 'Nueva publicación'), 60),
            p_body        := coalesce(NEW.author_alias, 'Estudiante') || ' · ' || v_carrera || ' · ' || left(coalesce(NEW.content, ''), 100),
            p_actor_alias := coalesce(NEW.author_alias, 'Estudiante'),
            p_post_id     := NEW.id,
            p_comment_id  := null,
            p_actor_id    := NEW.user_id
        );
    end loop;

    return null;
end;
$function$;

-- -----------------------------------------------------------------------------
-- 5) Eliminar la columna text[] sin FK (ya sin consumidores)
-- -----------------------------------------------------------------------------
alter table public.notification_preferences drop column if exists carreras;
