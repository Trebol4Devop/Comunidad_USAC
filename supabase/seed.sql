-- =============================================================================
-- Seed local de catálogos base
-- =============================================================================
-- Las migraciones históricas ya están consolidadas en el baseline
-- (20260101000000_baseline_remote_schema.sql, schema-only). Este seed aporta
-- únicamente los DATOS de catálogo que la app espera, extraídos verbatim de
-- migrations_historical/20260914190000_add_catalogs.sql.
-- Idempotente: usa on conflict ... do update.
-- =============================================================================

insert into public.facultades (id, codigo, nombre) values
  ('todas', '00', 'Todas las Facultades'),
  ('01', '01', 'Facultad de Agronomía'),
  ('02', '02', 'Facultad de Arquitectura'),
  ('03', '03', 'Facultad de Ciencias Económicas'),
  ('04', '04', 'Facultad de Ciencias Jurídicas y Sociales'),
  ('05', '05', 'Facultad de Ciencias Médicas'),
  ('06', '06', 'Facultad de Ciencias Químicas y Farmacia'),
  ('07', '77', 'Facultad de Humanidades'),
  ('08', '08', 'Facultad de Ingeniería'),
  ('09', '09', 'Facultad de Odontología'),
  ('10', '10', 'Facultad de Medicina Veterinaria y Zootecnia')
on conflict (id) do update set codigo = excluded.codigo, nombre = excluded.nombre;

insert into public.carreras (id, facultad_id, codigo, nombre) values
  ('todas', 'todas', '00-00-00', 'Todas las Carreras'),
  ('area_comun', '08', '08-00-00-AC', 'Área Común'),
  ('01-00-02', '01', '01-00-02', 'Ingeniería Agronómica en Sistemas de Producción Agrícola'),
  ('01-00-03', '01', '01-00-03', 'Ingeniería Agronómica en Recursos Naturales Renovables'),
  ('01-00-04', '01', '01-00-04', 'Ingeniería en Industrias Agropecuarias y Forestales'),
  ('01-00-07', '01', '01-00-07', 'Ingeniería en Gestión Ambiental Local'),
  ('02-00-01', '02', '02-00-01', 'Licenciatura en Arquitectura'),
  ('02-00-03', '02', '02-00-03', 'Licenciatura en Diseño Gráfico'),
  ('03-00-01', '03', '03-00-01', 'Contaduría Pública y Auditoría'),
  ('03-00-02', '03', '03-00-02', 'Economía'),
  ('03-00-03', '03', '03-00-03', 'Administración de Empresas'),
  ('03-02-01', '03', '03-02-01', 'Contaduría Pública y Auditoría - Extensión'),
  ('03-02-02', '03', '03-02-02', 'Economía - Extensión'),
  ('03-02-03', '03', '03-02-03', 'Administración de Empresas - Extensión'),
  ('04-00-01', '04', '04-00-01', 'Licenciatura en Ciencias Jurídicas y Sociales'),
  ('05-00-01', '05', '05-00-01', 'Médico y Cirujano'),
  ('05-01-03', '05', '05-01-03', 'Técnico de Enfermería'),
  ('05-04-04', '05', '05-04-04', 'Técnico de Fisioterapia'),
  ('05-05-05', '05', '05-05-05', 'Técnico de Terapia Respiratoria'),
  ('05-02-03', '05', '05-02-03', 'Técnico en Enfermería - Quetzaltenango'),
  ('05-03-03', '05', '05-03-03', 'Licenciatura en Enfermería - Cobán'),
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
  ('77-00-53', '07', '77-00-53', 'Profesorado en Ciencias de la Información Documental'),
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

-- =============================================================================
-- Usuario E2E para las pruebas de integración (solo entorno local)
-- =============================================================================
-- Credenciales: e2e@test.com / password123
-- integration_test/helpers/app_launcher.dart inicia sesión con estas
-- credenciales para que las escrituras pasen RLS como rol authenticated y con
-- auth.uid() = user_id. Los tokens deben ser '' (no NULL): GoTrue no puede
-- escanear NULL en columnas de token al autenticar.
-- =============================================================================

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  confirmation_token, recovery_token, email_change_token_new, email_change,
  email_change_token_current, phone_change, phone_change_token, reauthentication_token,
  created_at, updated_at
) values (
  '00000000-0000-0000-0000-000000000000',
  '00000000-0000-0000-0000-000000000001',
  'authenticated', 'authenticated', 'e2e@test.com',
  extensions.crypt('password123', extensions.gen_salt('bf')),
  now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{}'::jsonb,
  '', '', '', '', '', '', '', '',
  now(), now()
)
on conflict (id) do update set
  encrypted_password = excluded.encrypted_password,
  email_confirmed_at = now(),
  confirmation_token = '', recovery_token = '',
  email_change_token_new = '', email_change = '',
  email_change_token_current = '', phone_change = '',
  phone_change_token = '', reauthentication_token = '',
  updated_at = now();

insert into auth.identities (
  provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at
) values (
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  jsonb_build_object('sub','00000000-0000-0000-0000-000000000001','email','e2e@test.com'),
  'email', now(), now(), now()
)
on conflict (provider_id, provider) do nothing;
