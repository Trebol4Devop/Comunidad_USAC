# Integración de Google Sign-In en Escritorio (Windows y Linux)

Este documento detalla la integración de la biblioteca [`google_sign_in_all_platforms`](https://pub.dev/packages/google_sign_in_all_platforms) en la aplicación Comunidad USAC (Zanate), permitiendo el inicio de sesión nativo con cuentas de Google en entornos de escritorio **Windows** y **Linux**, preservando las sesiones de navegador existentes del usuario y sincronizando la sesión con **Supabase Auth**.

---

## 1. Arquitectura y Funcionamiento

### El problema en plataformas de escritorio convencionales
En entornos móviles y web, OAuth funciona mediante deep links (`comunidadusac://login-callback/`) o redirecciones directas de URL en la pestaña del navegador. Sin embargo, en Windows y Linux:
- Las aplicaciones de escritorio no registran esquemas de URI personalizados de forma estandarizada ni tienen un navegador embebido por defecto para interceptar callbacks de OAuth.
- Redirigir a esquemas como `comunidadusac://` en el navegador del sistema provoca errores de protocolo no reconocido.

### La solución con `google_sign_in_all_platforms`
La biblioteca implementa el estándar recomendado por Google y el **RFC 8252 (OAuth 2.0 for Native Apps - Loopback Interface)**:
1. Al pulsar "Continuar con Google", la app inicia un servidor HTTP temporal en `http://localhost:8000`.
2. Abre el navegador web predeterminado del sistema operativo (Google Chrome, Microsoft Edge, Firefox, etc.) mediante `url_launcher`.
3. El usuario selecciona su cuenta de Google ya iniciada en su navegador sin tener que escribir contraseñas nuevamente.
4. Google redirige a `http://localhost:8000/?code=...`.
5. El servidor local captura el código de autorización, lo intercambia con `oauth2.googleapis.com/token` utilizando el Client ID y Client Secret, y obtiene el `id_token`, `access_token` y `refresh_token`.
6. La app muestra una pantalla de confirmación en el navegador ("Autenticación exitosa") y cierra el servidor local.
7. `SupabaseService` toma el `idToken` y llama a:
   ```dart
   await client.auth.signInWithIdToken(
     provider: OAuthProvider.google,
     idToken: creds.idToken!,
     accessToken: creds.accessToken,
   );
   ```
8. Supabase valida criptográficamente el token con Google y emite la sesión JWT activa en la app, disparando `onAuthStateChange` y conectando al usuario automáticamente.

---

## 2. Configuración en Google Cloud Console

Para que el flujo de escritorio funcione, se requiere un conjunto de credenciales OAuth 2.0:

1. Ve a la consola de desarrolladores de Google: [Google Cloud Console - Credentials](https://console.cloud.google.com/apis/credentials).
2. Asegúrate de tener seleccionado el proyecto correspondiente.
3. Si aún no lo has hecho, configura la **Pantalla de consentimiento de OAuth** (*OAuth consent screen*):
   - Tipo de usuario: **Externo** (*External*).
   - Completa el nombre de la app, correos de soporte y guarda.
4. En el menú lateral izquierdo, selecciona **Credenciales** (*Credentials*) → **Crear credenciales** (*Create Credentials*) → **ID de cliente de OAuth** (*OAuth client ID*).
5. Selecciona tipo de aplicación: **Aplicación web** (*Web application*).
   > **Nota técnica:** Aunque se ejecute en Windows/Linux, Google exige que el tipo sea *Web application* para permitir redirecciones loopback hacia `http://localhost:<puerto>`.
6. En la sección **URIs de redireccionamiento autorizados** (*Authorized redirect URIs*), agrega:
   - `http://localhost:8000` (puerto predeterminado usado por la app)
   - `https://hfvsstkfqszpjrsrwhql.supabase.co/auth/v1/callback` (callback del proyecto Supabase)
7. Guarda y copia el **ID de cliente** (*Client ID*) y el **Secreto de cliente** (*Client Secret*).

> **Aviso de seguridad (RFC 8252 §8.5):** En aplicaciones de escritorio y móviles públicas, el *Client Secret* no es considerado un secreto criptográfico estricto por Google, sino un identificador de canal. Sin embargo, es exigido por el endpoint `/token` de Google OAuth para clientes de escritorio.

---

## 3. Configuración en el Dashboard de Supabase

1. Accede al Dashboard de Supabase → Proyecto `hfvsstkfqszpjrsrwhql`.
2. Ve a **Authentication** → **Providers** → **Google**.
3. Asegúrate de que el proveedor esté **habilitado**.
4. En **Client ID**, pega tu ID de cliente de Google Cloud.
5. En **Client Secret**, pega tu Secreto de cliente.
6. En **Authorized Client IDs** (si está visible), asegúrate de que incluya el Client ID.

---

## 4. Ejecución del Proyecto en Windows y Linux

Para ejecutar la aplicación con soporte de Google Sign-In en escritorio, proporciona tus credenciales de Google Cloud OAuth mediante `--dart-define`:

### Ejecución con `--dart-define`
```powershell
cd comunidad_universitaria
flutter run -d windows `
  --dart-define=GOOGLE_CLIENT_ID="YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com" `
  --dart-define=GOOGLE_CLIENT_SECRET="YOUR_GOOGLE_CLIENT_SECRET"
```

### Parámetros configurables

| Variable | Tipo | Valor Predeterminado | Descripción |
| :--- | :--- | :--- | :--- |
| `GOOGLE_CLIENT_ID` | String | `""` (vía `--dart-define`) | Client ID de Google Cloud OAuth |
| `GOOGLE_CLIENT_SECRET` | String | `""` (vía `--dart-define`) | Client Secret de Google Cloud OAuth |
| `GOOGLE_REDIRECT_PORT` | int | `8000` | Puerto local donde escucha el servidor loopback |

*Ejemplo con puerto personalizado (si el 8000 estuviese ocupado):*
```powershell
flutter run -d windows `
  --dart-define=GOOGLE_CLIENT_ID="..." `
  --dart-define=GOOGLE_CLIENT_SECRET="..." `
  --dart-define=GOOGLE_REDIRECT_PORT=8080
```
*(Recuerda haber agregado `http://localhost:8080` en los URIs autorizados de Google Cloud).*

---

## 5. Componentes y Código Implementado

### `lib/core/config/google_auth_config.dart`
Centraliza las constantes de entorno, scopes y validaciones de plataforma:
- Detecta si la plataforma actual es de escritorio (`Windows`, `Linux` o `macOS`).
- Requiere los scopes `openid`, `userinfo.profile` y `userinfo.email` para garantizar la recepción del `id_token`.
- Valida si las credenciales mínimas necesarias están provistas antes de iniciar el flujo.
- Ofrece overrides `@visibleForTesting` para pruebas unitarias.

### `lib/core/services/google_auth_desktop_service.dart`
Servicio especializado para gestionar el ciclo de vida de `google_sign_in_all_platforms`:
- Inicialización perezosa (*lazy*) de `GoogleSignIn`.
- `signIn()`: inicia el servidor loopback, abre el navegador y devuelve `GoogleSignInCredentials`.
- `silentSignIn()`: restaura tokens persistidos sin intervención del usuario.
- `signOut()`: revoca y elimina los tokens almacenados en el disco local.

### `lib/core/services/supabase_service.dart`
Punto de entrada unificado para la autenticación:
- En plataformas de escritorio (`GoogleAuthConfig.isDesktop`), redirige transparentemente la llamada `SupabaseService.signInWithGoogle()` a `GoogleAuthDesktopService.signIn()` y luego valida el token con `client.auth.signInWithIdToken(...)`.
- En Web y Móvil, mantiene el flujo tradicional mediante `client.auth.signInWithOAuth(OAuthProvider.google, redirectTo: ...)`.
- Al hacer `signOut()`, limpia tanto la sesión de Supabase como los tokens de Google en escritorio.

### `lib/features/onboarding/screens/auth_gateway_screen.dart` y `no_institutional_email_screen.dart`
- Adaptados para detectar cuando la sesión concluye de forma directa en escritorio y proceder con la navegación adecuada (Camino A, Comerciante, o verificación existente) sin depender únicamente de callbacks externos.

---

## 6. Pruebas Automatizadas

Se añadieron pruebas unitarias completas en:
- `test/core/services/google_auth_desktop_service_test.dart`

Para ejecutar las pruebas del módulo:
```bash
cd comunidad_universitaria
flutter test test/core/services/google_auth_desktop_service_test.dart
```

Para verificar análisis estático de código:
```bash
cd comunidad_universitaria
dart analyze lib test
```

---

## 7. Control de Versiones

- Rama de integración: `feature/google-sign-in-desktop`
- Los cambios se encuentran aplicados en el espacio de trabajo listos para revisión y **no se ha realizado ningún commit**, respetando la instrucción solicitada.
