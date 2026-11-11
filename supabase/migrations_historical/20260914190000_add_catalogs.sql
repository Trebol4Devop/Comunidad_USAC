-- =============================================================================
-- PEMTREE · Catálogos de carreras, facultades y categorías
-- Fecha: 2026-09-14
--
-- Corrige el hallazgo "Categorías y carreras como texto libre":
--   - posts.category        -> FK a categorias_foro
--   - posts.carrera         -> FK a carreras
--   - student_groups.carrera-> FK a carreras
--   - profiles.carrera      -> FK a carreras
--   - marketplace_items.category -> FK a categorias_marketplace
--
-- Los catálogos se siembran desde las constantes de la app
-- (lib/core/constants/categories.dart): 11 facultades, 52 carreras,
-- 6 categorías de foro y 6 de marketplace.
-- Son de solo lectura para los clientes (RLS: solo SELECT) y se actualizan
-- con migraciones cuando la app agregue valores.
--
-- Es idempotente: re-ejecutar re-siembra (upsert) sin duplicar.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) Tablas de catálogo
-- -----------------------------------------------------------------------------
create table if not exists public.facultades (
  id text primary key,
  codigo text,
  nombre text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.carreras (
  id text primary key,
  facultad_id text not null references public.facultades(id) on update cascade,
  codigo text,
  nombre text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.categorias_foro (
  id text primary key,
  nombre text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.categorias_marketplace (
  id text primary key,
  nombre text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Triggers de timestamps (funciones creadas en migraciones anteriores)
do $$
declare
  t text;
  tablas text[] := array['facultades','carreras','categorias_foro','categorias_marketplace'];
begin
  foreach t in array tablas loop
    execute format('drop trigger if exists trg_set_created_at on public.%I', t);
    execute format('create trigger trg_set_created_at before insert on public.%I for each row execute function _triggers.set_created_at()', t);
    execute format('drop trigger if exists trg_set_updated_at on public.%I', t);
    execute format('create trigger trg_set_updated_at before update on public.%I for each row execute function _triggers.set_updated_at()', t);
  end loop;
end $$;

-- -----------------------------------------------------------------------------
-- 2) Seed (upsert desde el catálogo de la app)
-- -----------------------------------------------------------------------------
insert into public.facultades (id, codigo, nombre) values
  ('todas', '00', 'Todas las Facultades / General'),
  ('01', '01', 'Facultad de Agronomía'),
  ('02', '02', 'Facultad de Arquitectura'),
  ('03', '03', 'Facultad de Ciencias Económicas'),
  ('04', '04', 'Facultad de Ciencias Jurídicas y Sociales'),
  ('05', '05', 'Facultad de Ciencias Médicas (CUM)'),
  ('06', '06', 'Facultad de Ciencias Químicas y Farmacia'),
  ('07', '77', 'Facultad de Humanidades (Central & Extensiones)'),
  ('08', '08', 'Facultad de Ingeniería'),
  ('09', '09', 'Facultad de Odontología'),
  ('10', '10', 'Facultad de Medicina Veterinaria y Zootecnia')
on conflict (id) do update set codigo = excluded.codigo, nombre = excluded.nombre;

insert into public.carreras (id, facultad_id, codigo, nombre) values
  ('todas', 'todas', '00-00-00', 'Todas las Carreras'),
  ('area_comun', 'todas', '00-00-01', 'Área Común / Cursos Básicos'),
  ('01-00-02', '01', '01-00-02', 'Ingeniería Agronómica en Sistemas de Producción Agrícola'),
  ('01-00-03', '01', '01-00-03', 'Ingeniería Agronómica en Recursos Naturales Renovables'),
  ('01-00-04', '01', '01-00-04', 'Ingeniería en Industrias Agropecuarias y Forestales'),
  ('01-00-07', '01', '01-00-07', 'Ingeniería en Gestión Ambiental Local'),
  ('02-00-01', '02', '02-00-01', 'Licenciatura en Arquitectura'),
  ('02-00-03', '02', '02-00-03', 'Licenciatura en Diseño Gráfico'),
  ('03-00-01', '03', '03-00-01', 'Contaduría Pública y Auditoría (Campus Central)'),
  ('03-00-02', '03', '03-00-02', 'Economía (Campus Central)'),
  ('03-00-03', '03', '03-00-03', 'Administración de Empresas (Campus Central)'),
  ('03-02-01', '03', '03-02-01', 'Contaduría Pública y Auditoría (Extensión)'),
  ('03-02-02', '03', '03-02-02', 'Economía - Área común (Extensión)'),
  ('03-02-03', '03', '03-02-03', 'Administración de Empresas (Extensión)'),
  ('04-00-01', '04', '04-00-01', 'Licenciatura en Ciencias Jurídicas y Sociales (Abogado y Notario)'),
  ('05-00-01', '05', '05-00-01', 'Médico y Cirujano'),
  ('05-01-03', '05', '05-01-03', 'Técnico de Enfermería (ENF-Guatemala)'),
  ('05-04-04', '05', '05-04-04', 'Técnico de Fisioterapia (ETFOE)'),
  ('05-05-05', '05', '05-05-05', 'Técnico de Terapia Respiratoria (ETR)'),
  ('05-02-03', '05', '05-02-03', 'Técnico en Enfermería (Quetzaltenango - ENEO)'),
  ('05-03-03', '05', '05-03-03', 'Licenciatura en Enfermería nivel técnico (Cobán)'),
  ('06-00-01', '06', '06-00-01', 'Licenciatura en Química'),
  ('06-00-02', '06', '06-00-02', 'Licenciatura en Química Biológica'),
  ('06-00-03', '06', '06-00-03', 'Licenciatura en Química Farmacéutica'),
  ('06-00-04', '06', '06-00-04', 'Licenciatura en Biología'),
  ('06-00-05', '06', '06-00-05', 'Licenciatura en Nutrición'),
  ('77-00-55', '07', '77-00-55', 'PEM en Pedagogía y Técnico en Administración Educativa'),
  ('77-00-18', '07', '77-00-18', 'PEM en Pedagogía, Promotor de DDHH y Cultura de Paz'),
  ('77-00-28', '07', '77-00-28', 'PEM en Pedagogía, Ciencias Sociales y Formación Ciudadana'),
  ('77-00-23', '07', '77-00-23', 'PEM en Idioma Inglés'),
  ('77-00-78', '07', '77-00-78', 'PEM en Pedagogía y Ciencias Naturales con Orientación Ambiental'),
  ('77-00-17', '07', '77-00-17', 'PEM en Ciencias Económico Contables'),
  ('77-00-74', '07', '77-00-74', 'PEM en Pedagogía y Educación Intercultural'),
  ('77-00-26', '07', '77-00-26', 'PEM en Artes Plásticas e Historia del Arte'),
  ('77-00-27', '07', '77-00-27', 'PEM en Educación Musical'),
  ('77-00-46', '07', '77-00-46', 'Licenciatura en Filosofía'),
  ('77-00-07', '07', '77-00-07', 'Licenciatura en Arte'),
  ('77-00-53', '07', '77-00-53', 'Profesorado en Ciencias de la Información Documental (b-learning)'),
  ('77-00-67', '07', '77-00-67', 'PEM en Pedagogía y Técnico en Investigación Educativa'),
  ('sistemas', '08', '08-00-09', 'Ingeniería en Ciencias y Sistemas'),
  ('civil', '08', '08-00-01', 'Ingeniería Civil'),
  ('industrial', '08', '08-00-05', 'Ingeniería Industrial'),
  ('quimica', '08', '08-00-02', 'Ingeniería Química'),
  ('mecanica', '08', '08-00-03', 'Ingeniería Mecánica'),
  ('electrica', '08', '08-00-04', 'Ingeniería Eléctrica'),
  ('electronica', '08', '08-00-13', 'Ingeniería Electrónica'),
  ('mecanica_industrial', '08', '08-00-07', 'Ingeniería Mecánica Industrial'),
  ('mecanica_electrica', '08', '08-00-06', 'Ingeniería Mecánica Eléctrica'),
  ('ambiental', '08', '08-00-35', 'Ingeniería Ambiental'),
  ('09-00-01', '09', '09-00-01', 'Cirujano Dentista'),
  ('10-00-02', '10', '10-00-02', 'Medicina Veterinaria'),
  ('10-00-03', '10', '10-00-03', 'Zootecnia')
on conflict (id) do update set facultad_id = excluded.facultad_id, codigo = excluded.codigo, nombre = excluded.nombre;

insert into public.categorias_foro (id, nombre) values
  ('todos', 'Todas las áreas'),
  ('prerrequisitos', 'Prerrequisitos & Pensum'),
  ('catedraticos', 'Catedráticos & Auxiliares'),
  ('horarios', 'Horarios & Secciones'),
  ('apuntes', 'Apuntes & Exámenes'),
  ('general', 'Consultas Generales')
on conflict (id) do update set nombre = excluded.nombre;

insert into public.categorias_marketplace (id, nombre) values
  ('todos', 'Todo el Marketplace'),
  ('comida_postres', 'Comida & Postres'),
  ('tutorias_academica', 'Tutorías & Asesorías'),
  ('libros_materiales', 'Libros & Materiales'),
  ('servicios_estudiantiles', 'Servicios Estudiantiles'),
  ('otros_articulos', 'Otros Artículos')
on conflict (id) do update set nombre = excluded.nombre;

-- -----------------------------------------------------------------------------
-- 3) FKs desde las columnas de texto libre
-- -----------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_constraint where conrelid='public.posts'::regclass and conname='posts_category_catalogo_fkey') then
    alter table public.posts add constraint posts_category_catalogo_fkey
      foreign key (category) references public.categorias_foro(id) on update cascade;
  end if;

  if not exists (select 1 from pg_constraint where conrelid='public.posts'::regclass and conname='posts_carrera_catalogo_fkey') then
    alter table public.posts add constraint posts_carrera_catalogo_fkey
      foreign key (carrera) references public.carreras(id) on update cascade;
  end if;

  if not exists (select 1 from pg_constraint where conrelid='public.student_groups'::regclass and conname='student_groups_carrera_catalogo_fkey') then
    alter table public.student_groups add constraint student_groups_carrera_catalogo_fkey
      foreign key (carrera) references public.carreras(id) on update cascade;
  end if;

  if not exists (select 1 from pg_constraint where conrelid='public.profiles'::regclass and conname='profiles_carrera_catalogo_fkey') then
    alter table public.profiles add constraint profiles_carrera_catalogo_fkey
      foreign key (carrera) references public.carreras(id) on update cascade;
  end if;

  if not exists (select 1 from pg_constraint where conrelid='public.marketplace_items'::regclass and conname='marketplace_items_category_catalogo_fkey') then
    alter table public.marketplace_items add constraint marketplace_items_category_catalogo_fkey
      foreign key (category) references public.categorias_marketplace(id) on update cascade;
  end if;
end $$;

-- -----------------------------------------------------------------------------
-- 4) RLS: catálogos de solo lectura para clientes
-- -----------------------------------------------------------------------------
alter table public.facultades enable row level security;
alter table public.carreras enable row level security;
alter table public.categorias_foro enable row level security;
alter table public.categorias_marketplace enable row level security;

do $$
declare
  t text;
  tablas text[] := array['facultades','carreras','categorias_foro','categorias_marketplace'];
begin
  foreach t in array tablas loop
    execute format('drop policy if exists "Lectura publica de catalogo" on public.%I', t);
    execute format('create policy "Lectura publica de catalogo" on public.%I for select to public using (true)', t);
  end loop;
end $$;

grant select on public.facultades, public.carreras, public.categorias_foro, public.categorias_marketplace to anon, authenticated;

comment on table public.facultades is 'Catálogo de facultades USAC. Solo lectura; se actualiza por migración desde categories.dart.';
comment on table public.carreras is 'Catálogo de carreras USAC. Solo lectura; se actualiza por migración desde categories.dart.';
comment on table public.categorias_foro is 'Catálogo de categorías del foro. Solo lectura.';
comment on table public.categorias_marketplace is 'Catálogo de categorías del marketplace. Solo lectura.';

-- -----------------------------------------------------------------------------
-- 5) Resumen
-- -----------------------------------------------------------------------------
do $$
declare
  v_fac bigint; v_car bigint; v_foro bigint; v_mkt bigint; v_fks bigint;
begin
  select count(*) into v_fac from public.facultades;
  select count(*) into v_car from public.carreras;
  select count(*) into v_foro from public.categorias_foro;
  select count(*) into v_mkt from public.categorias_marketplace;

  select count(*) into v_fks from pg_constraint
  where conname in ('posts_category_catalogo_fkey','posts_carrera_catalogo_fkey',
                    'student_groups_carrera_catalogo_fkey','profiles_carrera_catalogo_fkey',
                    'marketplace_items_category_catalogo_fkey');

  raise notice 'Catalogos -> facultades=%, carreras=%, categorias_foro=%, categorias_marketplace=% | FKs=%',
    v_fac, v_car, v_foro, v_mkt, v_fks;
end $$;
