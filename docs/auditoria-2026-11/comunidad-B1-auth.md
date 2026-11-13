# Auditoría Inicialización Supabase, Autenticación e Identidad — Comunidad_USAC (comunidad_universitaria)

## Resumen
Se auditó la integración de Supabase, autenticación, identidad, almacenamiento local y el mecanismo de SSO en el cliente Flutter de Comunidad USAC contrastándolo con el volcado real de base de datos (`EVIDENCIA-BD.md`). Se identificaron fallas críticas en el flujo SSO (uso del antipatrón Implicit Grant exponiendo access y refresh tokens en URL sin PKCE ni validación de state/audiencia), imposibilidad funcional de registrar la aceptación de términos por falta de GRANT UPDATE sobre `profiles` (error 42501), ineficacia del guardián TOTP (no está montado en la app y no existe enforcement RLS en BD) y almacenamiento en texto plano de datos identificativos en SharedPreferences.

---

## Respuestas Concretas a Preguntas de la Auditoría

### 1. `supabase_config.dart`: URL y anon key hardcodeadas
- **Evaluación del riesgo vs. mala práctica**:
  - *Naturaleza técnica*: En la arquitectura de Supabase (PostgREST/GoTrue), la `anon key` es una clave pública/publishable por diseño (JWT con claim `"role": "anon"`). Todo cliente web o móvil la expone forzosamente en sus peticiones REST mediante el encabezado `apikey`.
  - *Mala práctica*: Definir la URL de producción (`https://hfvsstkfqszpjrsrwhql.supabase.co`) y la anon key como `defaultValue` dentro del control de versiones Git. Provoca que entornos locales de desarrollo, ejecuciones de prueba y CI/CD apunten por defecto a la base de datos de producción, con riesgo de polución de datos o dependencia accidental. Dificulta además la rotación de credenciales.
  - *Riesgo real*: La seguridad de la `anon key` descansa íntegramente en las políticas RLS y los privilegios de PostgreSQL. Al estar expuesta públicamente en el repo junto a la URL, cualquier agente externo puede interactuar directamente con la API REST (`/rest/v1/`). Contrastando con `EVIDENCIA-BD.md` (§7 y §8), esto permite explotación directa de endpoints permisivos sin pasar por la UI (e.g. `POST /rest/v1/sponsor_requests` sin rate-limit/captcha, o lectura de `posts` incluyendo `author_hash`).
- **Sobreescritura por `--dart-define`**: SÍ. En `comunidad_universitaria/lib/core/config/supabase_config.dart:5-13`, las constantes se declaran con `String.fromEnvironment('SUPABASE_URL', ...)` y `String.fromEnvironment('SUPABASE_ANON_KEY', ...)`.
- **¿Funciona en release?**: SÍ. `String.fromEnvironment` en Dart se resuelve en tiempo de compilación tanto en modo `debug` como en `profile` y `release` (`flutter build apk --release`, `flutter build web --release`). Al estar asociadas a constantes `static const`, el compilador AOT/dart2js sustituye los valores en el árbol de sintaxis.

### 2. Flujo PKCE, Persistencia de Sesión y Refresh de Token
- **PKCE**:
  - En la inicialización del cliente (`supabase_config.dart:46-48`), se configura `authFlowType: AuthFlowType.pkce`.
  - Para el login federado con Google (`SupabaseService.signInWithGoogle` en `supabase_service.dart:61-64`), el SDK `supabase_flutter` implementa PKCE correctamente intercambiando el `code_verifier` por tokens mediante el callback del navegador/esquema de app.
  - **Sin embargo**, en el flujo SSO hacia aplicaciones cliente como PEMTREE (`sso_authorize_screen.dart:208-214`), **NO se utiliza PKCE**: se extraen directamente los tokens de sesión del SDK y se entregan en el fragmento de la URL (`#access_token=...&refresh_token=...`), incurriendo en el flujo Implicit Grant prohibido por RFC 8252.
- **Persistencia de sesión**:
  - `pubspec.yaml:12-13` no incluye `flutter_secure_storage`. La sesión se persiste mediante la implementación predeterminada de `supabase_flutter: ^2.8.3`, la cual almacena el token JWT y metadata en `shared_preferences` (archivo XML en texto plano en `/data/data/...` en Android, o `localStorage` en Web).
- **Refresh de token**:
  - El SDK `supabase_flutter` gestiona automáticamente la renovación del access token en segundo plano mediante un temporizador antes de su expiración, utilizando el `refresh_token` persistido.
  - Al compartir el `refresh_token` con PEMTREE mediante SSO en la URL, se introduce un conflicto de rotación: si ambos clientes intentan refrescar token de manera independiente, la rotación de tokens de Supabase (Refresh Token Rotation) invalidará la sesión del otro o revocará la sesión global por detección de reuso.

### 3. Revisión Línea por Línea de SSO (`sso_security_validator.dart`)
- **Validación de origen**:
  - Líneas 24-64 (`isValidRedirectUri`): Valida que el `redirect_uri` tenga esquema y autoridad válidos, rechaza asteriscos/wildcards (`effectiveUri.contains('*')`), rechaza `userInfo` (evita `https://evil.com@attacker.com`), permite `localhost` y `127.0.0.1` en `http`/`https` con ruta estricta `/auth/callback`, y para producción exige `https` con sufijos permitidos (`pemtree.netlify.app` y sus previews `<deploy>--pemtree.netlify.app`, `pemtree.com`, `pemtree.app`, `pemtree.org`) requiriendo ruta `/auth/callback`.
  - **No valida** el origen del iniciador HTTP (referrer/origen de la pestaña web que abrió la vista de autorización).
- **Validación de `state`**:
  - **NO se valida**. En líneas 66-102 (`buildSuccessRedirectUrl`) y 104-136 (`buildCancelRedirectUrl`), el parámetro `state` es opcional (`String? state`). Si existe, se añade al hash sin validar formato, entropía, firma ni cotejo contra una cookie o sesión local previa de CSRF. Si el cliente no lo envía, la autorización continúa.
- **Validación de expiración**:
  - **NO se valida**. Líneas 75, 85: Recibe un entero opcional `int? expiresIn` y lo serializa en el hash. No inspecciona el JWT, no comprueba la fecha de expiración del `accessToken` antes de transferirlo ni verifica si el token ya expiró.
- **Validación de firma**:
  - **NO se valida**. Los tokens se manipulan como cadenas de texto opacas. La app no valida la firma criptográfica del JWT ni firma el payload de redirección.
- **Validación de audience (`aud`)**:
  - **NO se valida**. No se comprueba el claim `aud` del JWT para asegurar que esté acotado o restringido a PEMTREE.
- **Comparación de secretos no constante en tiempo**:
  - En `sso_security_validator.dart` **no existe ninguna comparación de secretos**.
  - En `sso_authorize_screen.dart:67-68`, se evalúa `widget.clientId?.trim().toLowerCase() == 'pemtree'`. Es una comparación de cadenas no constante en tiempo, pero `client_id` es un identificador público, no un secreto criptográfico. No existen secretos de cliente involucrados.

### 4. Confianza en Datos Locales y Operaciones sobre `profiles`
- **¿Se confía en SharedPreferences/SecureStorage para roles o verificación?**:
  - *Roles*: NO. En `LocalStorageService.getUserProfile()` (`local_storage_service.dart:60`), el rol se consulta siempre al servidor mediante `SupabaseService.getUserRole()` (`supabase_service.dart:215-230`), consultando la tabla `user_roles`. Si falla, hace fallback a `'student'`.
  - *Verificación*: NO. En `local_storage_service.dart:55-58, 105`, el flag local `isCarneVerified` se resetea forzosamente a `false` en cada lectura y guardado (`isCarneVerified = false`).
  - *Problema de privacidad*: Sin embargo, `local_storage_service.dart:94, 100` almacena el carné (`usac_student_carne`) y el nombre real (`usac_student_name`) en texto plano en `SharedPreferences`.
- **Falla de permisos en escritura sobre `profiles`**:
  - *Evidencia en BD*: En `EVIDENCIA-BD.md` §7:
    `authenticated` → `has_table_privilege(profiles,'UPDATE')` | **false** → la política de UPDATE existe pero el GRANT no.
    En `EVIDENCIA-BD.md` §3, la tabla `profiles` tiene concedido UPDATE sobre solo 4 columnas (`accepted_terms_at, accepted_terms_version, carrera, full_name`).
  - *Flujo que falla con "permission denied"*:
    En `comunidad_universitaria/lib/core/services/profile_service.dart:50-56` (`ProfileService.acceptTerms()`):
    ```dart
    await SupabaseService.client
        .from('profiles')
        .update({
          'accepted_terms_version': termsVersion,
          'accepted_terms_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', uid);
    ```
    Invocado desde el modal de términos (`comunidad_universitaria/lib/features/legal/widgets/terms_consent_modal.dart:40`). Al no contar el rol `authenticated` con el privilegio SQL de UPDATE a nivel de tabla sobre `profiles`, la consulta REST `PATCH /rest/v1/profiles?id=eq.<uid>` de PostgREST es rechazada por PostgreSQL con error `42501 permission denied for table profiles`.
  - *Consecuencia*: El usuario autenticado no puede completar la aceptación de términos; el modal captura la excepción, muestra error en rojo y aborta el flujo.

### 5. Guardián TOTP (`TotpSessionGuard`)
- **¿Es solo UI o bloquea operaciones?**:
  - **No está montado**: En la aplicación real (`lib/main.dart` y `lib/features/navigation/app_shell.dart`), `TotpSessionGuard` **no está instanciado ni montado** en ninguna ruta ni envolviendo el árbol de widgets. Solo existe en su archivo de definición y en `test/widgets/totp_session_guard_test.dart`.
  - **Es solo UI**: En `totp_session_guard.dart:160-184`, el guardián únicamente dibuja un `Stack` con un `OverlayEntry` tapando la pantalla. No intercepta llamadas HTTP de Supabase, no retiene tokens y no cancela operaciones asíncronas de fondo.
  - **Cero enforcement en backend**: En `EVIDENCIA-BD.md`, ninguna política RLS ni función en PostgreSQL valida el claim `aal` (`auth.jwt() ->> 'aal' = 'aal2'`). Cualquier cliente HTTP con el JWT de nivel 1 (AAL1) puede consultar y mutar la base de datos sin haber verificado el código TOTP. Es **100% cosmético**.

### 6. Logs (`debugPrint`/`print`) con Información Sensible
- **Tokens**: SÍ. En `comunidad_universitaria/lib/features/sso/screens/sso_authorize_screen.dart:258`, la función `_performRedirect(String url)` ejecuta:
  `debugPrint('Error al redirigir a PEMTREE: $e');`.
  La variable `url` contiene `#access_token=...&refresh_token=...`. Cuando el plugin `url_launcher` lanza una excepción (por ejemplo `PlatformException`), el mensaje de error incluye la URL completa con los tokens de acceso y refresco en texto plano, quedando registrados en la consola y logs del sistema.
- **Correos**: Potencialmente en excepciones de autenticación en `lib/core/services/supabase_service.dart:83, 100` (`debugPrint('Error en inicio de sesión: $e')` y `debugPrint('Error en registro: $e')`), donde el objeto `AuthException` retornado por GoTrue puede reflejar la dirección de correo electrónico involucrada.
- **CUI / Carné / User ID**: No se identificaron llamadas a `debugPrint` o `print` que concatenen directamente el CUI, número de carné o el `user_id` del usuario.

---

## Hallazgos

### H-1: Falla de ejecución en aceptación de términos por falta de GRANT UPDATE sobre `profiles`
- Severidad: ALTA
- Tipo: GRANTS
- Ubicación: `comunidad_universitaria/lib/core/services/profile_service.dart:50-56` (llamado desde `lib/features/legal/widgets/terms_consent_modal.dart:40`)
- Evidencia:
  - Código:
    ```dart
    // lib/core/services/profile_service.dart:50-56
    await SupabaseService.client
        .from('profiles')
        .update({
          'accepted_terms_version': termsVersion,
          'accepted_terms_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', uid);
    ```
  - Base de Datos (`EVIDENCIA-BD.md` §7):
    `authenticated` → `has_table_privilege(profiles,'UPDATE')` | **false** → la política de UPDATE existe pero el GRANT no.
- Impacto: Cuando un usuario autenticado acepta los términos de uso en `TermsConsentModal`, la petición `PATCH /rest/v1/profiles?id=eq.<uid>` falla con `42501 permission denied for table profiles`. La excepción es capturada en `terms_consent_modal.dart:46-57`, mostrando un mensaje de error y retornando `false`, impidiendo el consentimiento legal exigido para participar en la plataforma.
- Corrección propuesta: Otorgar el privilegio SQL necesario en la base de datos de Supabase para el rol autenticado:
  ```sql
  GRANT UPDATE (accepted_terms_version, accepted_terms_at) ON public.profiles TO authenticated;
  -- O a nivel de tabla si PostgREST lo requiere para la validación previa de RLS:
  GRANT UPDATE ON public.profiles TO authenticated;
  ```
  La política RLS `Users can update own profile` (`USING (auth.uid() = id) WITH CHECK (auth.uid() = id)`) garantiza que los usuarios solo puedan modificar su propia fila.

---

### H-2: Fuga de credenciales maestras y uso de Implicit Grant en SSO hacia PEMTREE
- Severidad: CRÍTICA
- Tipo: AUTH
- Ubicación: `comunidad_universitaria/lib/features/sso/screens/sso_authorize_screen.dart:170-176, 208-223` y `comunidad_universitaria/lib/features/sso/sso_security_validator.dart:66-102`
- Evidencia:
  - Código en `sso_authorize_screen.dart`:
    ```dart
    // Líneas 171-175
    final session = SupabaseConfig.client.auth.currentSession;
    if (session != null) {
      accessToken = session.accessToken;
      refreshToken = session.refreshToken ?? '';
      expiresIn = session.expiresIn;
    }
    // Líneas 208-214
    final targetUrl = SsoSecurityValidator.buildSuccessRedirectUrl(
      redirectUri: _effectiveRedirectUri,
      accessToken: accessToken,
      refreshToken: refreshToken,
      state: widget.state,
      expiresIn: expiresIn,
    );
    ```
  - Código en `sso_security_validator.dart`:
    ```dart
    // Líneas 81-87
    final params = <String, String>{
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'token_type': tokenType,
      if (expiresIn != null) 'expires_in': expiresIn.toString(),
      if (state != null && state.trim().isNotEmpty) 'state': state.trim(),
    };
    ```
- Impacto:
  1. La aplicación utiliza el flujo *OAuth 2.0 Implicit Grant* desaconsejado y revocado por RFC 8252 y OAuth 2.0 Security BCP.
  2. Transmite el `refresh_token` maestro de la cuenta del estudiante en el hash fragment del navegador (`#access_token=...&refresh_token=...`). El hash queda expuesto en el historial del cliente, en scripts de terceros en el dominio receptor y en logs.
  3. Supabase Auth implementa *Refresh Token Rotation*. Al entregarse el mismo refresh token a PEMTREE y conservarse en Comunidad USAC, las peticiones concurrentes de refresco invalidan las sesiones entre ambas aplicaciones por detección de reuso de token.
- Corrección propuesta:
  1. Reemplazar la transferencia directa de tokens por un flujo *Authorization Code with PKCE*.
  2. La app Comunidad USAC debe generar un código de autorización temporal y de un solo uso asociado al usuario, para que PEMTREE intercambie dicho código directamente con el backend mediante `code_verifier`. Nunca transferir `refresh_token` en fragmentos de URL.

---

### H-3: Ausencia de validación de `state` (anti-CSRF), expiración y audiencia en SSO
- Severidad: ALTA
- Tipo: AUTH
- Ubicación: `comunidad_universitaria/lib/features/sso/sso_security_validator.dart:26-64, 69-102` y `lib/features/sso/screens/sso_authorize_screen.dart:66-76`
- Evidencia:
  - En `sso_security_validator.dart`:
    ```dart
    // Línea 86: el state solo se reenvía si existe, no se exige ni valida
    if (state != null && state.trim().isNotEmpty) 'state': state.trim(),
    ```
  - En `sso_authorize_screen.dart:66-76`, la validación de cliente se limita a:
    ```dart
    bool get _isClientValid {
      final client = widget.clientId?.trim().toLowerCase();
      return client == 'pemtree';
    }
    ```
- Impacto: El parámetro `state` no es obligatorio ni verificado contra almacenamiento de sesión. Un atacante puede engañar a un usuario para que autorice una sesión en un flujo de phishing o fijación de sesión (Session Fixation / CSRF) conectando la cuenta de la víctima con una instancia controlada por el atacante. Además, al no validarse el claim `aud` (audience), cualquier token válido de Supabase emitido para la app móvil puede presentarse ante cualquier receptor sin restricción de ámbito.
- Corrección propuesta:
  1. Hacer obligatorio el parámetro `state` y exigir una longitud mínima de 32 caracteres con alta entropía.
  2. Validar que el token de sesión no esté expirado antes de construir la redirección.
  3. Restringir los tokens mediante scopes y audience correspondientes al cliente destinatario.

---

### H-4: Guardián TOTP (`TotpSessionGuard`) deshabilitado en ejecución y sin validación RLS en base de datos
- Severidad: MEDIA
- Tipo: AUTH
- Ubicación: `comunidad_universitaria/lib/features/shared/widgets/totp_session_guard.dart:10-184` (ausente en `lib/main.dart` y `lib/features/navigation/app_shell.dart`)
- Evidencia:
  - Búsqueda en el monorepo confirma que `TotpSessionGuard` únicamente se referencia en su propio archivo de definición y en `test/widgets/totp_session_guard_test.dart:60`.
  - En `lib/main.dart:12-31` y `lib/features/navigation/app_shell.dart`, la aplicación arranca sin envolver el árbol de widgets con `TotpSessionGuard`.
  - En `EVIDENCIA-BD.md` §2, las políticas RLS de `posts`, `comments`, `marketplace_items`, etc. solo verifican roles y `auth.uid()`, sin inspeccionar `auth.jwt() ->> 'aal'`.
- Impacto: La protección de doble factor (2FA/TOTP) implementada en la app no tiene efecto en producción. Los usuarios que hayan vinculado un factor TOTP no son desafiados al iniciar sesión. Incluso si se integrara en la UI, cualquier petición directa a la API de Supabase con el access token inicial (AAL1) continuará siendo procesada con éxito por la base de datos.
- Corrección propuesta:
  1. Envolver la vista principal en `main.dart` / `app_shell.dart` con `TotpSessionGuard` para activar el desafío en la interfaz de usuario.
  2. Si se desea que el segundo factor sea obligatorio para operaciones críticas (e.g. publicar en Marketplace, editar perfiles, calificar), añadir en las políticas RLS de PostgreSQL la condición:
     ```sql
     (auth.jwt() ->> 'aal') = 'aal2'
     ```
     para usuarios que tengan factores TOTP verificados.

---

### H-5: Almacenamiento no cifrado de carné y nombre oficial en `SharedPreferences`
- Severidad: MEDIA
- Tipo: PRIVACIDAD
- Ubicación: `comunidad_universitaria/lib/core/services/local_storage_service.dart:18-19, 93-103` y `lib/features/profile/widgets/carne_validation_modal.dart:78-85`
- Evidencia:
  - Código en `local_storage_service.dart`:
    ```dart
    if (profile.carne != null && profile.carne!.trim().isNotEmpty) {
      await prefs.setString(_keyCarne, profile.carne!.trim());
    }
    if (profile.studentName != null && profile.studentName!.trim().isNotEmpty) {
      await prefs.setString(_keyStudentName, profile.studentName!.trim());
    }
    ```
  - En `TermsConsentModal` (`terms_consent_modal.dart:181-184`), la app estipula: *"Tu CUI y número de carné estudiantil se almacenan exclusivamente como una huella HMAC irreversible... garantizando que nunca se guarden en texto plano"*.
  - En `pubspec.yaml`, no se utiliza ningún almacenamiento cifrado seguro (`flutter_secure_storage`).
- Impacto: En plataformas móviles (Android/iOS) y Web, `SharedPreferences` almacena los datos en archivos XML o almacenamiento de navegador sin cifrar. En caso de acceso físico al dispositivo, respaldos o dispositivos rooteados, el número de carné y nombre completo pueden ser leídos directamente, contradiciendo los términos de privacidad comunicados al usuario.
- Corrección propuesta: Reemplazar el almacenamiento en `SharedPreferences` de campos de identidad sensible por `flutter_secure_storage` (utilizando Android Keystore y Apple Keychain), o evitar el almacenamiento persistente de carné y nombre en texto plano, conservando únicamente el hash irreversible en servidor.

---

### H-6: Consultas a columnas inexistentes en `profiles` (`seller_verification_status` y `alias`)
- Severidad: MEDIA
- Tipo: ESQUEMA
- Ubicación:
  - `comunidad_universitaria/lib/core/services/marketplace_service.dart:247`
  - `comunidad_universitaria/lib/features/map/services/campus_community_supabase_service.dart:124`
- Evidencia:
  - En `marketplace_service.dart`:
    ```dart
    final profile = await SupabaseService.client
        .from('profiles')
        .select('seller_verification_status')
        .eq('id', userId)
        .maybeSingle();
    ```
  - En `campus_community_supabase_service.dart`:
    ```dart
    final profile = await client
        .from('profiles')
        .select('alias')
        .eq('id', user.id)
        .maybeSingle();
    ```
  - En `EVIDENCIA-BD.md` §1 y §3, las columnas de `profiles` son estrictamente:
    `accepted_terms_at, accepted_terms_version, carne, carne_hash, carrera, created_at, cui, cui_hash, full_name, id, is_verified, reputation_score, updated_at, verified_at`.
- Impacto: Ambas consultas fallan en PostgreSQL con el error `42703 column profiles.<columna> does not exist`. La validación de vendedor en Marketplace siempre retorna `false`, y en el mapa se fuerza siempre el alias genérico por error de esquema no controlado.
- Corrección propuesta:
  1. En `marketplace_service.dart`, consultar la columna real `is_verified` de la tabla `profiles`.
  2. En `campus_community_supabase_service.dart`, no consultar `alias` en `profiles` (dado que los alias se gestionan localmente y por publicación); leer el alias de `LocalStorageService` o del parámetro `fallbackAlias`.

---

### H-7: Filtración de tokens de acceso y refresco en logs de depuración durante excepciones de SSO
- Severidad: BAJA
- Tipo: PRIVACIDAD
- Ubicación: `comunidad_universitaria/lib/features/sso/screens/sso_authorize_screen.dart:246-260`
- Evidencia:
  - Código:
    ```dart
    Future<void> _performRedirect(String url) async {
      try {
        final uri = Uri.parse(url);
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
          webOnlyWindowName: '_self',
        );
        if (!launched) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (e) {
        debugPrint('Error al redirigir a PEMTREE: $e');
      }
    }
    ```
- Impacto: La cadena `url` contiene `#access_token=...&refresh_token=...`. Cuando `launchUrl` falla y lanza una excepción (por ejemplo `PlatformException: Could not launch URL...`), la excepción incluye la URL completa con los tokens de sesión, imprimiéndolos en texto plano en la consola o log del dispositivo mediante `debugPrint`.
- Corrección propuesta: Sanitizar el mensaje de excepción para registrar únicamente el error genérico sin exponer el objeto de excepción con la URL de redirección:
  ```dart
  debugPrint('Error al redirigir a PEMTREE: ${e.runtimeType}');
  ```

---

### H-8: Anon key y URL de producción en el repositorio
- Severidad: BAJA
- Tipo: SECRETOS
- Ubicación: `comunidad_universitaria/lib/core/config/supabase_config.dart:5-13`
- Evidencia:
  - `defaultValue: 'https://hfvsstkfqszpjrsrwhql.supabase.co'`
  - `defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'`
- Impacto: Aunque la anon key no es un secreto administrativo, fijar la base de datos de producción como fallback por defecto permite a cualquier desarrollador, test o atacante con acceso al código interactuar directamente contra el backend de producción.
- Corrección propuesta: Remover los valores por defecto de producción del código fuente y exigir su provisión explícita en tiempo de compilación mediante `--dart-define=SUPABASE_URL=...` y `--dart-define=SUPABASE_ANON_KEY=...`.

---

## No verificado
1. **Comportamiento en navegadores móviles externos**: No se pudo verificar la interacción de `launchUrl` en navegadores iOS Safari en modo privado al retornar a la aplicación mediante esquemas de URL personalizados (`comunidadusac://`).
2. **Configuración de Google OAuth Client ID**: No se tiene acceso a la consola de Google Cloud para verificar las restricciones de orígenes y URIs de redirección autorizadas asociadas al proveedor de Google Sign-In.
3. **Mecanismo de validación oficial de carné**: En la app no hay endpoints o Edge Functions implementados para contrastar los datos de carné con los sistemas de Registro y Estadística de la USAC; el modal actual opera únicamente en modo borrador local.
