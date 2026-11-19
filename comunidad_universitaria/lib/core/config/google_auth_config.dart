import 'package:flutter/foundation.dart';

/// Configuración de OAuth para Google Sign-In con soporte multiplataforma
/// (especialmente Windows y Linux vía [google_sign_in_all_platforms]).
///
/// En plataformas de escritorio (Windows, Linux, macOS), Google requiere:
/// - Un Client ID de tipo "Web Application" o "Desktop" en Google Cloud Console.
/// - Un Client Secret (requerido para plataformas de escritorio según RFC 8252 / OAuth loopback).
/// - Un puerto local de redirección para el servidor loopback (por defecto 8000: http://localhost:8000).
class GoogleAuthConfig {
  /// Client ID de Google OAuth 2.0 (Web / Desktop).
  static const String clientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue: '',
  );

  /// Client Secret de Google OAuth 2.0 (requerido para escritorio).
  static const String clientSecret = String.fromEnvironment(
    'GOOGLE_CLIENT_SECRET',
    defaultValue: '',
  );

  /// Puerto local donde escucha el servidor loopback durante la autenticación de escritorio.
  static const int redirectPort = int.fromEnvironment(
    'GOOGLE_REDIRECT_PORT',
    defaultValue: 8000,
  );

  /// Scopes requeridos para Google OAuth.
  /// Incluye 'openid' para garantizar que Google retorne el [idToken] requerido por Supabase.
  static const List<String> scopes = [
    'openid',
    'https://www.googleapis.com/auth/userinfo.profile',
    'https://www.googleapis.com/auth/userinfo.email',
  ];

  @visibleForTesting
  static String? debugClientId;

  @visibleForTesting
  static String? debugClientSecret;

  @visibleForTesting
  static int? debugRedirectPort;

  @visibleForTesting
  static bool? debugOverrideIsDesktop;

  /// Retorna el Client ID efectivo (soporta override para pruebas unitarias).
  static String get effectiveClientId => debugClientId ?? clientId;

  /// Retorna el Client Secret efectivo (soporta override para pruebas unitarias).
  static String get effectiveClientSecret => debugClientSecret ?? clientSecret;

  /// Retorna el puerto de redirección loopback efectivo.
  static int get effectiveRedirectPort => debugRedirectPort ?? redirectPort;

  /// Indica si la plataforma de ejecución actual es de escritorio (Windows, Linux o macOS).
  static bool get isDesktop {
    if (debugOverrideIsDesktop != null) return debugOverrideIsDesktop!;
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  /// Indica si las credenciales mínimas necesarias para escritorio están configuradas.
  static bool get isConfigured {
    if (!isDesktop) return effectiveClientId.isNotEmpty;
    return effectiveClientId.isNotEmpty && effectiveClientSecret.isNotEmpty;
  }

  /// Restablece los valores sobreescritos durante pruebas unitarias.
  @visibleForTesting
  static void resetForTests() {
    debugClientId = null;
    debugClientSecret = null;
    debugRedirectPort = null;
    debugOverrideIsDesktop = null;
  }
}
