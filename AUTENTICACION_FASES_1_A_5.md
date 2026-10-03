# Autenticación y seguridad — Fases 1 a 5

Este documento registra lo implementado y verificado en el proyecto hasta la
Fase 5. No implica que las migraciones se hayan aplicado a Supabase remoto: las
pruebas y la configuración descritas aquí corresponden al entorno local.

## Estado general

| Fase | Alcance | Estado |
|---|---|---|
| 1 | Visitantes con acceso de solo lectura | Implementada; pruebas de base de datos aprobadas |
| 2 | Preparación de base de datos y permisos para cuentas | Migraciones locales presentes; el Worker de Cloudflare R2 sigue pendiente |
| 3 | Registro, inicio de sesión y confirmación de correo | Integrado en la app; Google depende de configuración del proveedor en Supabase |
| 4 | Sesión, cierre de sesión y recuperación de contraseña | Integrado en el servicio/modal; falta la prueba manual completa con correo real |
| 5 | MFA TOTP, requisito AAL2 y códigos de recuperación | Implementada en código; pruebas automatizadas aprobadas; pendiente smoke test manual Auth local |

> Las fases 2–4 se resumen por las funcionalidades y migraciones que existen en
> el repositorio. Este documento describe el estado del código; no sustituye la
> revisión de cambios de otros colaboradores ni la aprobación para publicar al
> proyecto remoto.

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

## Fase 2 — Base de datos y permisos para cuentas

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

**Pendiente asociado a esta fase:** el Worker de Cloudflare R2 no está incluido
ni probado en esta entrega. La configuración de Supabase Storage no significa
que ese Worker esté desplegado.

## Fase 3 — Registro e inicio de sesión

- `comunidad_universitaria/lib/features/shared/widgets/auth_modal.dart`
  contiene los formularios de login y registro.
- `SupabaseService` implementa registro y login por correo/contraseña,
  verificación y reenvío del OTP de confirmación, y acceso con Google OAuth.
- Con confirmación de correo habilitada, el registro solicita el código de seis
  dígitos enviado por Supabase antes de terminar el flujo de la cuenta.
- La app muestra errores de credenciales, código inválido/expirado y límites de
  intentos. La integración con Google necesita que el proveedor y las URL de
  retorno estén configurados en el proyecto Supabase que se vaya a utilizar.

Archivos principales:

- `comunidad_universitaria/lib/core/services/supabase_service.dart`
- `comunidad_universitaria/lib/features/shared/widgets/auth_modal.dart`
- `supabase/config.toml`

## Fase 4 — Sesión y recuperación de contraseña

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

## Fase 5 — MFA con TOTP y recuperación

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
  aprobadas en aproximadamente 1 minuto y 54 segundos.
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
240 pruebas aprobadas. Algunos tests imprimen mensajes de error simulados como
parte de sus casos de manejo de fallos; el resultado final de la suite fue
`All tests passed!`.

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
- `comunidad_universitaria/lib/features/shared/widgets/auth_modal.dart`
- `comunidad_universitaria/lib/features/shared/widgets/totp_session_guard.dart`
- `comunidad_universitaria/lib/features/profile/screens/totp_enrollment_screen.dart`
- `comunidad_universitaria/test/services/supabase_service_test.dart`
