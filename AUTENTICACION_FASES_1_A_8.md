# Autenticación y seguridad — Estado de las fases 1 a 8

Este documento registra el código y las pruebas disponibles según la propuesta
de fases compartida. No implica que las migraciones se hayan aplicado a
Supabase remoto. El desglose TOTP 5.1–5.4 se conserva como el plan de seguridad
adicional que ya se acordó e implementó en paralelo.

## Estado general

| Fase | Alcance | Estado |
|---|---|---|
| 1 | Flujo invitado y lectura pública | Implementada; pgTAP verifica restricciones de escritura |
| 2 | Pantallas de login y registro | Integradas en `AuthModal` |
| 3 | Confirmación de registro por correo | OTP eliminado de la app; `enable_confirmations = false` localmente. El proyecto remoto debe configurarse por separado |
| 4 | Sesión, cierre de sesión y navegación | Login/logout probados en Auth local; persistencia tras cerrar y reabrir la app queda pendiente de E2E |
| 5 | Perfil y compatibilidad con el esquema | Trigger y perfil comprobados en la prueba E2E local; migración de contribuciones guest antiguas sigue siendo una decisión de producto |
| 6 | Google OAuth con PKCE | Código y callbacks web/móvil preparados; pendiente configurar proveedor/redirects y probar con credenciales reales |
| 7 | Recuperación de contraseña | Aplazada; el flujo de recuperación por correo se retiró de la app por límites del SMTP incluido |
| 8 | Seguridad adicional y pruebas | RLS de perfiles, visitantes y AAL2 cubiertos por pgTAP; TOTP validado localmente y en el proyecto remoto; verificación Flutter actualizada tras retirar códigos MFA; Google requiere credenciales externas |

Las pruebas y configuración descritas aquí son locales o simuladas; no
sustituyen una prueba real contra el proveedor. No se han publicado estas
migraciones al proyecto remoto.

## Fase 1 — Visitantes solo lectura

- La app usa la clave pública de Supabase (`anon`/publishable key), nunca una
  `service_role` key en el cliente. La clave pública identifica el rol de API;
  **no concede permisos de escritura por sí sola**: los permisos SQL y las
  políticas RLS son los que restringen el acceso.
- `supabase/migrations/20261003000000_enforce_anonymous_read_only.sql` revoca
  permisos de escritura del rol `anon` y agrega políticas restrictivas para
  que las sesiones anónimas de Auth tampoco puedan insertar, modificar o
  eliminar filas.
- Las funciones privilegiadas de reportes rechazan a visitantes anónimos; no
  se permite eludir RLS llamando directamente a esos RPC.
- La lectura pública que ya permiten las tablas/vistas se conserva.
- En `supabase/config.toml`, `enable_anonymous_sign_ins = false`: la app no
  crea cuentas anónimas de Supabase Auth. El visitante sin cuenta accede con
  la clave pública y las operaciones disponibles al rol `anon`. Si se habilita
  en el futuro `signInAnonymously()`, la sesión usa el rol `authenticated` y
  debe continuar sujeta a las políticas que detectan `is_anonymous`.

**Pruebas:** `supabase/tests/anonymous_read_only_test.sql` verifica lectura,
rechazo de inserción/modificación/eliminación y bloqueo de RPC para sesiones
anónimas; además confirma que una cuenta registrada conserva las escrituras
permitidas por sus políticas.

## Migraciones locales de soporte al esquema y los permisos

Las migraciones locales de octubre preparan y corrigen el esquema usado por la
app y sus cuentas:

- `20261002000000_fix_generate_author_hash_overload.sql`: elimina una
  sobrecarga ambigua de `generate_author_hash` que podía romper inserciones.
- `20261002000100_harden_moderation_rls.sql`: endurece lectura de contenido
  moderado y evita que triggers reescriban silenciosamente el dueño de posts y
  comentarios.
- `20261002000200_restore_auth_user_profile_trigger.sql`: asegura el trigger
  de creación de perfil asociado a `auth.users` en instalaciones locales.
- `20261002000300_grant_post_trigger_and_table_permissions.sql`: restaura
  permisos necesarios para que las operaciones de cuentas autenticadas pasen
  por las políticas RLS correspondientes.

El Worker de Cloudflare R2 es una tarea separada de este plan de autenticación;
la configuración de Supabase Storage no significa que ese Worker esté desplegado.

## Fase 5 — Perfil y compatibilidad con el esquema

La migración `20261002000200_restore_auth_user_profile_trigger.sql` usa la
función existente `public.handle_new_user_profile()` y garantiza el trigger
`trg_on_auth_user_created` si falta. No se agregó una tabla de perfiles
alternativa.

Una prueba E2E local histórica creó una cuenta descartable, confirmó el OTP y
comprobó la fila en `public.profiles` creada por el trigger. La confirmación
OTP ya no forma parte del flujo actual. La política de conservar o migrar
contribuciones de cuentas guest antiguas debe decidirse antes de vincularlas a
cuentas nuevas; no se debe atribuir contenido anónimo automáticamente sin esa
decisión.

## Fase 6 — Google OAuth con PKCE

El flujo ya tenía el botón y la llamada a `signInWithOAuth`; en esta fase se
completaron los puntos que faltaban en la app:

- `SupabaseConfig.initialize()` fija explícitamente `AuthFlowType.pkce`.
- `AndroidManifest.xml` ya declaraba `comunidadusac://login-callback/`; se agregó
  el mismo esquema de retorno a `ios/Runner/Info.plist`.
- `supabase/config.toml` permite el callback móvil y redirects web locales en
  `localhost:3000` y `127.0.0.1:3000`.
- `AuthModal` y `SsoAuthorizeScreen` ahora esperan el evento real
  `signedIn` de Supabase antes de continuar. Que el navegador se abra solo
  significa que el OAuth comenzó, no que la cuenta ya inició sesión.

**Configuración manual pendiente para completar la prueba E2E:**

1. En el proyecto correcto de Supabase, habilitar Google y agregar el OAuth
   Client ID y Client Secret de Google Cloud. No guardar el Client Secret en el
   repositorio ni compartirlo en el chat.
2. En Google Cloud, registrar como redirect URI la URL de callback que indique
   Supabase para ese proyecto (`https://<project-ref>.supabase.co/auth/v1/callback`).
3. En Supabase Authentication → URL Configuration, agregar los dominios web
   usados en desarrollo/producción y `comunidadusac://login-callback/` para la
   vuelta a la app móvil.
4. Probar con una cuenta Google en web y en dispositivos Android/iOS. Las
   pruebas unitarias actuales no contactan Google ni prueban el callback real.

No se ejecutó esa configuración ni una autenticación real porque depende de
credenciales del proveedor y acceso al proyecto remoto correcto.

## Fases 2 y 3 — Pantallas de acceso y registro sin OTP de correo

- `AuthModal` contiene los formularios de login y registro por correo/
  contraseña, y el acceso mediante Google OAuth.
- La confirmación por OTP de correo se retiró. La configuración local establece
  `auth.email.enable_confirmations = false`, para que el registro devuelva una
  sesión y continúe al guard TOTP.
- Si el proyecto remoto aún exige confirmación, hay que desactivar **Confirm
  email** en Authentication > Sign In / Providers > Email. No se cambió ese
  ajuste remoto.
- Quitar confirmación significa que una cuenta de correo/contraseña puede
  registrarse sin demostrar que controla esa dirección. TOTP es un segundo
  factor y no comprueba la propiedad del correo.

Archivos principales:

- `comunidad_universitaria/lib/core/services/supabase_service.dart`
- `comunidad_universitaria/lib/features/shared/widgets/auth_modal.dart`
- `supabase/config.toml`

## Fases 4 y 7 — Sesión y recuperación de contraseña

- El modal mantiene registro e inicio de sesión con correo/contraseña o Google,
  sin solicitar ni enviar OTP de confirmación por correo.
- La recuperación de contraseña por correo se retiró de la app y queda
  aplazada hasta contar con un servicio de correo con límites adecuados.
- TOTP es un segundo factor posterior al registro; no demuestra propiedad del
  correo ni es un mecanismo para restablecer contraseñas.
- La sesión la administra el SDK de Supabase. La autorización efectiva de datos
  debe permanecer en Postgres mediante permisos y RLS.

La prueba E2E local histórica incluyó recuperación de contraseña con OTP y
Mailpit antes de retirar ese flujo. La configuración actual ya no incluye la
plantilla de recuperación ni un servidor SMTP local. No se modificó Supabase
remoto.

## MFA TOTP — Subfases 5.1–5.4 y controles de seguridad de Fase 8

### 5.1 Inscripción TOTP

`TotpEnrollmentScreen` permite iniciar la inscripción, mostrar el QR/datos del
autenticador y verificar el primer código de seis dígitos. El acceso a la
pantalla está disponible desde el perfil.

### 5.2 Desafío requerido en la sesión

`TotpSessionGuard`, instalado como envoltura de la app en `main.dart`, revisa el
estado Auth de cada cuenta registrada:

- Si no existe un TOTP verificado, solicita inscribirlo.
- Si existe un factor verificado pero la sesión está en AAL1, solicita el
  desafío TOTP antes de mostrar el contenido de la app.
- Si la verificación falla o no se puede consultar Auth, muestra una pantalla
  de error/reintento/cierre de sesión.
- Los visitantes sin cuenta no quedan sujetos al paso de MFA.

### 5.3 Escrituras protegidas por AAL2 en la base de datos (retirado)

Se retiró la migración pendiente que imponía `aal = aal2` a todas las escrituras
del rol `authenticated`. Esa regla no debe publicarse: la base de datos conserva
sus permisos y políticas RLS habituales, y la prueba
`supabase/tests/authenticated_writes_without_otp_test.sql` comprueba que una
sesión AAL1 puede escribir cuando las políticas existentes lo permiten.

El control de sesión TOTP de la interfaz descrito en 5.2 es independiente de
esta política global de base de datos.

### 5.4 Recuperación y baja de TOTP

- Los códigos de recuperación quedan aplazados: el proyecto Supabase alojado
  no ofrece el soporte de Auth necesario para este flujo. No se implementan en
  la app ni se habilitan en la configuración local.
- Si se pierde el autenticador, la app no tiene un flujo de recuperación MFA;
  la cuenta requiere asistencia administrativa para recuperar el acceso.
- Para desactivar TOTP desde la app, se solicita el código TOTP vigente, se
  verifica el factor, se elimina y se cierra la sesión para volver a
  autenticarse.

Configuración relacionada: `supabase/config.toml`, sección
`[auth.mfa.totp]`.

## Migraciones y entorno remoto

Las migraciones nuevas descritas aquí están en el repositorio local. **No se
hizo `db push`, `migration repair`, `db pull` ni otra operación contra Supabase
remoto** durante estas pruebas. El historial remoto ya había mostrado versiones
que no existen localmente y el usuario indicó que algunos cambios pertenecen a
otra persona; por ello no se debe reparar ni publicar ese historial sin
confirmación y sin verificar dos veces el Reference ID del proyecto Comunidad_USAC.

El `project_id` de `supabase/config.toml` identifica el proyecto local de la
CLI; no confirma por sí solo a cuál proyecto remoto se encuentra enlazado.
Antes de cualquier operación remota, revisar explícitamente el proyecto
vinculado y su Reference ID. Ejecutar primero un `--dry-run` y revisar el
resultado; no aplicar reparaciones de historial sugeridas automáticamente sin
comparar las migraciones con el equipo.

## Verificación ejecutada

En el entorno local levantado por Supabase:

- `npx --yes supabase test db --local` — **PASS**, 11 archivos y 123 pruebas.
  Incluye RLS de perfiles, lectura de visitantes y escrituras AAL1/AAL2.

- Después de retirar recovery codes, desde `comunidad_universitaria/`:
  - Las pruebas dirigidas de servicio, guard y enrolamiento TOTP pasaron: **14**.
  - `flutter analyze` sobre los seis archivos Dart afectados — **PASS**, sin
    issues.
  - La suite completa reportó 261 pruebas aprobadas y una falla fuera de este
    cambio en `test/widgets/profile_screen_test.dart:69` (no encontró "Editar
    perfil"); la falla se reproduce al ejecutar solo esa prueba.
  - El `flutter analyze` global reporta cuatro issues en
    `create_post_dialog.dart`, `popular_servers_sidebar.dart` y `profile_screen.dart`,
    fuera de los archivos de este cambio.
- El health check local de Supabase Auth respondió HTTP 200 al confirmar que
  el servicio estaba disponible.

Además de las pruebas simuladas, se completó una prueba E2E histórica en
Supabase local y Mailpit con una cuenta descartable: registro sin sesión previa
a confirmar, rechazo del login con correo pendiente, recepción y validación del
OTP, creación del perfil, recuperación de contraseña por OTP, login, logout y
eliminación de la cuenta de prueba. El flujo de recuperación fue retirado
posteriormente.

El usuario confirmó que el flujo TOTP funciona localmente y en el proyecto
remoto. Los códigos de recuperación MFA se aplazaron y ya no forman parte de la
app. La prueba de Google requiere credenciales del proveedor y configuración de
redirects; no se ejecutó. No se configuró SMTP de producción y se retiró
el servidor Mailpit de la configuración local actual.

Los resultados históricos de ejecuciones anteriores no sustituyen la
verificación descrita arriba, que se hizo después de retirar los códigos de
recuperación MFA.

## Archivos principales

- `supabase/config.toml`
- `supabase/migrations/20261002000000_fix_generate_author_hash_overload.sql`
- `supabase/migrations/20261002000100_harden_moderation_rls.sql`
- `supabase/migrations/20261002000200_restore_auth_user_profile_trigger.sql`
- `supabase/migrations/20261002000300_grant_post_trigger_and_table_permissions.sql`
- `supabase/migrations/20261003000000_enforce_anonymous_read_only.sql`

- `supabase/tests/anonymous_read_only_test.sql`
- `supabase/tests/profiles_rls_test.sql`
- `supabase/tests/authenticated_writes_without_otp_test.sql`
- `comunidad_universitaria/lib/core/services/supabase_service.dart`
- `comunidad_universitaria/lib/core/config/supabase_config.dart`
- `comunidad_universitaria/lib/features/shared/widgets/auth_modal.dart`
- `comunidad_universitaria/lib/features/sso/screens/sso_authorize_screen.dart`
- `comunidad_universitaria/android/app/src/main/AndroidManifest.xml`
- `comunidad_universitaria/ios/Runner/Info.plist`
- `comunidad_universitaria/lib/features/shared/widgets/totp_session_guard.dart`
- `comunidad_universitaria/lib/features/profile/screens/totp_enrollment_screen.dart`
- `comunidad_universitaria/test/services/supabase_service_test.dart`
