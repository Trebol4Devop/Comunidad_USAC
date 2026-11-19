import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in_all_platforms/google_sign_in_all_platforms.dart';
import '../config/google_auth_config.dart';

/// Servicio para gestionar Google Sign-In en plataformas de escritorio (Windows / Linux / macOS)
/// utilizando la biblioteca [google_sign_in_all_platforms].
///
/// En escritorio, este servicio:
/// 1. Inicia un servidor web local loopback (ej. `http://localhost:8000`).
/// 2. Abre el navegador web predeterminado del sistema operativo con la URL de autorización de Google.
/// 3. Recibe el código de autorización tras el consentimiento del usuario.
/// 4. Intercambia el código por tokens ([idToken], [accessToken], [refreshToken]).
/// 5. Entrega las credenciales para su uso con Supabase ([signInWithIdToken]).
class GoogleAuthDesktopService {
  @visibleForTesting
  static GoogleSignIn? debugGoogleSignIn;

  static GoogleSignIn? _instance;

  /// Último error registrado durante la autenticación de escritorio.
  static String? lastError;

  /// Retorna o crea la instancia de [GoogleSignIn] con los parámetros configurados.
  static GoogleSignIn get googleSignIn {
    if (debugGoogleSignIn != null) return debugGoogleSignIn!;
    return _instance ??= GoogleSignIn(
      params: GoogleSignInParams(
        clientId: GoogleAuthConfig.effectiveClientId,
        clientSecret: GoogleAuthConfig.effectiveClientSecret,
        redirectPort: GoogleAuthConfig.effectiveRedirectPort,
        scopes: GoogleAuthConfig.scopes,
      ),
    );
  }

  /// Stream reactivo de credenciales de Google Sign-In.
  static Stream<GoogleSignInCredentials?> get authenticationState =>
      googleSignIn.authenticationState;

  /// Inicia el flujo de autenticación de Google en plataformas de escritorio.
  ///
  /// Retorna las credenciales [GoogleSignInCredentials] obtenidas (incluyendo [idToken] y [accessToken]),
  /// o `null` si fue cancelado, ocurrió un error o no se configuraron credenciales.
  static Future<GoogleSignInCredentials?> signIn() async {
    lastError = null;
    if (!GoogleAuthConfig.isConfigured) {
      lastError =
          'Faltan GOOGLE_CLIENT_ID y/o GOOGLE_CLIENT_SECRET. Debes ejecutar la aplicación con:\n'
          '--dart-define=GOOGLE_CLIENT_ID="tu-client-id.apps.googleusercontent.com"\n'
          '--dart-define=GOOGLE_CLIENT_SECRET="tu-client-secret"';
      debugPrint('Aviso [GoogleAuthDesktopService]: $lastError');
      return null;
    }

    try {
      final creds = await googleSignIn.signIn();
      if (creds == null) {
        lastError =
            'La autenticación fue cancelada en el navegador, expiró el tiempo de espera o Google denegó el acceso.';
      }
      return creds;
    } catch (e) {
      lastError = 'Error ejecutando Google Sign-In en escritorio: $e';
      debugPrint(lastError);
      return null;
    }
  }

  /// Intenta restaurar de forma silenciosa credenciales previamente persistidas.
  static Future<GoogleSignInCredentials?> silentSignIn() async {
    if (!GoogleAuthConfig.isConfigured) return null;
    try {
      return await googleSignIn.silentSignIn();
    } catch (e) {
      debugPrint('Error en GoogleAuthDesktopService.silentSignIn: $e');
      return null;
    }
  }

  /// Cierra la sesión en Google eliminando los tokens guardados localmente.
  static Future<void> signOut() async {
    try {
      if (_instance != null || debugGoogleSignIn != null) {
        await googleSignIn.signOut();
      }
    } catch (e) {
      debugPrint('Error en GoogleAuthDesktopService.signOut: $e');
    }
  }

  /// Restablece la instancia y anulaciones para pruebas unitarias.
  @visibleForTesting
  static void resetForTests() {
    debugGoogleSignIn = null;
    _instance = null;
    lastError = null;
  }
}
