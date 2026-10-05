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
| 3 | Verificación y reenvío de OTP de correo | Integrados; entrega real depende de la configuración de correo |
| 4 | Sesión, cierre de sesión y navegación | SDK y logout integrados; mantener acceso invitado sigue siendo el comportamiento esperado |
| 5 | Perfil y compatibilidad con el esquema | Trigger existente se preserva/restaura en local; pendiente prueba E2E del alta y perfil |
| 6 | Google OAuth con PKCE | Código y callbacks web/móvil preparados; pendiente configurar proveedor/redirects y probar con credenciales reales |
| 7 | Recuperación de contraseña | Flujo y UI integrados; falta probar entrega real de correo |
| 8 | Seguridad adicional y pruebas | RLS/AAL2 y suites automatizadas aprobadas; queda smoke test manual de MFA/códigos en Auth local |

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

La migración y las pruebas locales cubren el trigger, pero falta verificar el
flujo completo de registro de una cuenta y comprobar su fila de perfil con un
usuario de prueba. La política de conservar o migrar contribuciones de cuentas
guest antiguas debe decidirse antes de vincularlas a cuentas nuevas; no se debe
atribuir contenido anónimo automáticamente sin esa decisión.

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

## Fases 2 y 3 — Pantallas de acceso y verificación de correo

- `comunidad_universitaria/lib/features/shared/widgets/auth_modal.dart`
  contiene los formularios de login y registro.
- `SupabaseService` implementa registro y login por correo/contraseña,
  verificación y reenvío del OTP de confirmación.
- Con confirmación de correo habilitada, el registro solicita el código de seis
  dígitos enviado por Supabase antes de terminar el flujo de la cuenta.
- La app muestra errores de credenciales, código inválido/expirado y límites de
  intentos. Google se documenta en la Fase 6.

Archivos principales:

- `comunidad_universitaria/lib/core/services/supabase_service.dart`
- `comunidad_universitaria/lib/features/shared/widgets/auth_modal.dart`
- `supabase/config.toml`

## Fases 4 y 7 — Sesión y recuperación de contraseña

- `SupabaseService` expone cierre de sesión, solicitud de recuperación por
  correo, verificación del OTP de recuperación y actualización de contraseña.
- El modal de autenticación contiene los estados de confirmación de correo y
  recuperación de contraseña.
- La sesión la administra el SDK de Supabase. La interfaz del cliente ayuda a
  guiar al usuario, pero la autorización efectiva de datos debe permanecer en
  Postgres mediante permisos y RLS.

La recuperación por correo depende de que los ajustes de Auth y la entrega de
correo estén configurados correctamente en el entorno. Las pruebas unitarias
simuladas no demuestran entrega real de emails.

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

### 5.3 Escrituras protegidas por AAL2

`supabase/migrations/20261003010000_require_aal2_for_authenticated_writes.sql`
requiere `aal = aal2` para escrituras del rol `authenticated`. Aplica políticas
RLS restrictivas y un trigger adicional para cubrir escrituras que podrían
pasar por funciones `SECURITY DEFINER`. Las lecturas públicas y operaciones
internas con otros roles no se cambian por esta regla.

AAL1 representa la autenticación inicial; AAL2 indica que se completó el
segundo factor. La pantalla bloqueante mejora el flujo de usuario, pero la
protección de la base de datos es la que evita que una petición directa eluda
la interfaz.

### 5.4 Códigos de recuperación y baja de TOTP

- Se usan los endpoints de códigos de recuperación de Supabase Auth; no se
  creó una tabla propia para guardar secretos o códigos.
- Los códigos se muestran al generarlos, son de un solo uso y se pueden
  regenerar; la regeneración invalida los anteriores.
- La app comprueba AAL2 antes de generar/regenerar códigos y usa el endpoint de
  Supabase para verificarlos durante el desafío.
- La configuración local habilita 10 códigos, longitud 16, y configura hasta
  5 intentos de verificación con bloqueo de 15 minutos para los códigos de
  recuperación. Estos parámetros no deben interpretarse como un bloqueo
  idéntico para cada intento TOTP.
- Para desactivar TOTP, se solicita el código TOTP vigente, se verifica el
  factor, se elimina y se cierra la sesión para volver a autenticarse.

Configuración relacionada: `supabase/config.toml`, secciones
`[auth.mfa.totp]` y `[auth.mfa.recovery_codes]`.

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

- `npx --yes supabase test db --local` — **PASS**, 10 archivos y 117 pruebas.
  Incluye pruebas de lectura de visitantes y escrituras AAL1/AAL2.
- Desde `comunidad_universitaria/`,
  `flutter test test/services/supabase_service_test.dart` — **PASS**, 16 pruebas.
- Desde `comunidad_universitaria/`, `flutter analyze` — **PASS**, sin issues.
- Desde `comunidad_universitaria/`, `flutter test` — **PASS**, 240 pruebas
  aprobadas en aproximadamente 2 minutos y 10 segundos (ejecución posterior a
  los cambios de OAuth).
- El health check local de Supabase Auth respondió HTTP 200 al confirmar que
  el servicio estaba disponible.

Las pruebas de recuperación de códigos en Flutter usan respuestas HTTP
simuladas. Por tanto, **queda como verificación manual pendiente** completar el
flujo real con un usuario descartable en Auth local: inscribir TOTP, generar y
guardar códigos, iniciar una sesión nueva, probar un código de recuperación y
comprobar que ese código ya no pueda reutilizarse. No se debe hacer esta prueba
contra el proyecto remoto.

Una ejecución anterior de la suite Flutter completa había excedido el límite
de tiempo. Se volvió a ejecutar con un límite mayor y terminó correctamente:
240 pruebas aprobadas. También se repitió después de los cambios de OAuth y
volvió a pasar. Algunos tests imprimen mensajes de error simulados como parte de
sus casos de manejo de fallos; el resultado final fue `All tests passed!`.

## Archivos principales

- `supabase/config.toml`
- `supabase/migrations/20261002000000_fix_generate_author_hash_overload.sql`
- `supabase/migrations/20261002000100_harden_moderation_rls.sql`
- `supabase/migrations/20261002000200_restore_auth_user_profile_trigger.sql`
- `supabase/migrations/20261002000300_grant_post_trigger_and_table_permissions.sql`
- `supabase/migrations/20261003000000_enforce_anonymous_read_only.sql`
- `supabase/migrations/20261003010000_require_aal2_for_authenticated_writes.sql`
- `supabase/tests/anonymous_read_only_test.sql`
- `supabase/tests/totp_aal2_writes_test.sql`
- `comunidad_universitaria/lib/core/services/supabase_service.dart`
- `comunidad_universitaria/lib/core/config/supabase_config.dart`
- `comunidad_universitaria/lib/features/shared/widgets/auth_modal.dart`
- `comunidad_universitaria/lib/features/sso/screens/sso_authorize_screen.dart`
- `comunidad_universitaria/android/app/src/main/AndroidManifest.xml`
- `comunidad_universitaria/ios/Runner/Info.plist`
- `comunidad_universitaria/lib/features/shared/widgets/totp_session_guard.dart`
- `comunidad_universitaria/lib/features/profile/screens/totp_enrollment_screen.dart`
- `comunidad_universitaria/test/services/supabase_service_test.dart`
