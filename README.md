# Comunidad USAC

Aplicación Flutter para la comunidad universitaria, con backend Supabase y
almacenamiento de imágenes mediante un Cloudflare Worker/R2 desplegado.

Este README describe el estado observado del repositorio al **6 de noviembre de
2026**. No reemplaza las guías enlazadas abajo ni significa que las funciones
pendientes estén desplegadas en producción.

## Componentes

- `comunidad_universitaria/`: aplicación Flutter para web, Windows, Android,
  iOS, macOS y Linux.
- `supabase/migrations/`: migraciones SQL que se aplican en orden al entorno
  local y, mediante un procedimiento revisado, al remoto.
- `supabase/migrations_historical/`: archivos históricos; no son la carpeta de
  migraciones activas de la CLI.
- `remote_public_snapshot.sql`: snapshot SQL de referencia del esquema remoto;
  no es una migración activa, no es un respaldo de datos y no debe ejecutarse
  directamente.
- `supabase/seed.sql`: catálogos y cuenta de prueba E2E para el entorno local.
- `supabase/tests/`: pruebas pgTAP de RLS, triggers, RPC y reglas de datos.
- `docs/ux/`: especificaciones funcionales y de UX; algunos requisitos son
  aspiracionales y no describen necesariamente lo desplegado.
- `scripts/`: runners de pruebas.
- `worker/README.md`: notas del Worker de imágenes. El código del Worker
  desplegado no está incluido en este repositorio.

## Requisitos

- Flutter/Dart compatible con la versión declarada en
  `comunidad_universitaria/pubspec.yaml`.
- Docker Desktop en ejecución para Supabase local.
- Supabase CLI para iniciar el backend local y ejecutar migraciones/pruebas.

## Inicio local seguro

Ejecuta los comandos de Supabase desde la raíz del repositorio:

```powershell
supabase start
supabase status
```

`supabase status` muestra las credenciales locales; copia la URL del API
(normalmente `http://127.0.0.1:54321`) y la `anon` key local.

> **Importante:** la app tiene valores predeterminados de Supabase alojado en
> `comunidad_universitaria/lib/core/config/supabase_config.dart`. Al ejecutar
> la app sin `--dart-define`, no asumas que estás conectado a la base local ni
> al proyecto remoto de Comunidad USAC que esperas. Para desarrollo local,
> proporciona siempre la URL y la key que muestra `supabase status`.

Desde PowerShell, en otra terminal:

```powershell
cd comunidad_universitaria
flutter pub get
flutter devices
flutter run -d chrome --dart-define=SUPABASE_URL=http://127.0.0.1:54321 --dart-define=SUPABASE_ANON_KEY=PEGA_AQUI_LA_ANON_KEY_LOCAL
```

Si usas otro dispositivo disponible, sustituye `chrome` por el identificador
que muestra `flutter devices`. La `anon` key es una clave pública de cliente;
**nunca** uses ni incluyas una `service_role` key en Flutter, en el repositorio
o en documentación.

La configuración local está en `supabase/config.toml`. La CLI aplica las
migraciones de `supabase/migrations/`; `supabase/seed.sql` inserta datos de
catálogo y el usuario E2E local.

### Advertencia sobre `supabase db reset`

`supabase db reset` **destruye los datos de la base local**, reconstruye el
esquema desde las migraciones activas y vuelve a cargar el seed. No importa los
datos del proyecto remoto y, ejecutado localmente sin opciones de enlace, no lo
modifica. Úsalo solo si aceptas perder usuarios y datos de prueba locales; haz
una copia antes si necesitas conservarlos. No ejecutes `supabase db reset --linked`.

La cuenta `e2e@test.com` / `password123` del seed existe solo para pruebas
locales. No la crees ni la uses en Supabase remoto.

## Esquema y migraciones de base de datos

- La CLI procesa en orden los archivos de `supabase/migrations/`. Los cambios
  de esquema van como nuevas migraciones versionadas; no edites los archivos
  históricos para cambiar una base ya existente.
- `supabase/migrations_historical/` es un archivo histórico y no se aplica como
  parte de la secuencia activa.
- `remote_public_snapshot.sql` es material de referencia del esquema, no una
  migración ni un volcado para restaurar datos. No lo ejecutes manualmente ni
  lo uses para reemplazar las migraciones versionadas.
- Algunos archivos activos tienen nombres `replica_pemtree_*` y contienen SQL
  que crea objetos en `public` y `_triggers` de la base donde se ejecuten. El
  nombre por sí solo no significa que la CLI se conecte a la base de datos
  separada de PEMTREE ni que copie sus filas: revisa el SQL y el proyecto
  destino antes de aplicar una migración.
- Un reset local reconstruye el esquema desde las migraciones y agrega el seed;
  **no trae los datos del remoto**. Para cambios remotos, verifica el Reference
  ID correcto y revisa un `supabase db push --dry-run` antes de cualquier push.
  AAL2 y la verificación de vendedores siguen pendientes y no deben publicarse
  hasta aprobar ese alcance.

### Flujo para agregar una migración

1. Desde la raíz, crea un archivo versionado con `supabase migration new
   descripcion_del_cambio` y escribe el cambio en el archivo nuevo de
   `supabase/migrations/`. No edites el snapshot ni archivos históricos.
2. Revisa el SQL y agrega/actualiza pruebas pgTAP en `supabase/tests/` para los
   permisos o cambios de esquema relevantes.
3. Valida contra el stack local con `supabase test db --local`. Si necesitas
   reconstruir el esquema para incluir todas las migraciones y el seed, ejecuta
   `supabase db reset` solo después de respaldar o aceptar perder los datos
   locales; la advertencia anterior aplica.
4. La publicación remota es un paso distinto. Confirma el Reference ID en el
   Dashboard y revisa el plan con
   `supabase db push --dry-run --project-ref jsdshvnkbrkwobfhdysh`. No ejecutes
   un push real sin revisión y aprobación explícitas. La migración AAL2 sigue
   aplazada.

## Pruebas y análisis

Pruebas Flutter, desde `comunidad_universitaria/`:

```powershell
flutter analyze
flutter test
```

Pruebas pgTAP, desde la raíz y con el stack local iniciado:

```powershell
supabase test db --local
```

Las pruebas E2E y sus condiciones están documentadas en
[`comunidad_universitaria/integration_test/README.md`](comunidad_universitaria/integration_test/README.md).
El runner `scripts/e2e/run_e2e.sh` está escrito para Bash/Linux; la guía actual
no proporciona todavía un runner equivalente para PowerShell/Windows.

> Las pruebas E2E de escritura validan que su URL sea local y se omiten si
> detectan un host remoto. Esa protección es específica de las pruebas; la app
> ejecutada normalmente puede conectarse a su URL predeterminada, así que pasa
> explícitamente las credenciales locales.

## Estado actual de autenticación

- El registro e inicio de sesión por correo/contraseña y el acceso con Google
  están presentes en la app.
- La decisión acordada es **sin OTP por correo; con TOTP mediante app
  autenticadora** para MFA. La app incluye inscripción y desafío TOTP.
- La confirmación de correo está desactivada en la configuración local. Ese
  archivo no modifica la configuración Auth del proyecto alojado; además, el
  registro sin confirmación no demuestra que se controle la dirección.
- La recuperación de contraseña por correo y los códigos de recuperación MFA
  no forman parte del flujo actual.
- El código de Google OAuth requiere credenciales y redirects configurados en
  el proveedor/proyecto para probar el flujo real.
- La exigencia de AAL2 en la base de datos **está pendiente**. No es lo mismo que
  el guard TOTP de la app.

### Migración AAL2 pendiente en remoto

El `dry-run` realizado el 6 de noviembre de 2026 para el proyecto
`jsdshvnkbrkwobfhdysh` mostró como única migración pendiente
`20261004000000_require_aal2_and_verified_sellers.sql`. No se aplicó.

Además de exigir AAL2 para escrituras autenticadas en tablas con RLS, esa
migración agrega reglas para que solo vendedores verificados publiquen en
Marketplace y ajusta permisos del flujo de patrocinio. Debe revisarse y probarse
antes de aprobar un `db push`; hasta entonces, la base remota no tiene esa
política por efecto de esta migración.

Un `db push` sincroniza migraciones SQL, **no** opciones de Auth como Confirm
email ni credenciales/redirects de Google. No ejecutes operaciones remotas sin
confirmar el Reference ID, revisar el `--dry-run` y contar con aprobación.

## Imágenes y almacenamiento

`StorageService` usa `R2_WORKER_URL`; su valor predeterminado apunta al Worker
alojado de Cloudflare. El Worker no está desplegado desde este repositorio y su
código fuente no está aquí. Las cargas de imágenes pueden afectar ese servicio
remoto; no las uses como si hubiera un R2 local aislado.

## Documentación relacionada

- [Estado de autenticación y fases](AUTENTICACION_FASES_1_A_8.md)
- [Guía técnica de Supabase Auth](auth-supabase-login-signup.md)
- [Requisitos UX](docs/ux/README.md)
- [Pruebas E2E](comunidad_universitaria/integration_test/README.md)
- [Worker de imágenes](worker/README.md)
- [Datos de facultades y carreras](facultades_usac_db.md)
