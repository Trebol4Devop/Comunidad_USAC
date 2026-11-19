import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/google_auth_config.dart';
import '../config/supabase_config.dart';
import 'google_auth_desktop_service.dart';

class SupabaseService {
  @visibleForTesting
  static SupabaseClient? debugClient;

  static SupabaseClient get client => debugClient ?? SupabaseConfig.client;

  @visibleForTesting
  static String? debugUserId;

  static User? get currentUser =>
      SupabaseConfig.isConfigured ? client.auth.currentUser : null;
  static String? get currentUserId => debugUserId ?? currentUser?.id;
  static bool get isAuthenticated =>
      currentUser != null && !(currentUser!.isAnonymous);

  /// URL de retorno para OAuth en web.
  ///
  /// Descarta el fragmento (`#/...`) porque Supabase y el intercambio PKCE
  /// esperan una URL sin hash: si se envía, el callback vuelve a una ruta
  /// distinta y la sesión no se completa.
  static String? get oauthRedirectUrl {
    if (!kIsWeb) return null;
    final base = Uri.base;
    return base.replace(fragment: '').toString();
  }

  /// Controla si en escritorio se debe usar el flujo directo con Google loopback en vez de deep link.
  /// Por defecto es `false` para usar el flujo nativo de Supabase vía `comunidadusac://login-callback/`.
  static const bool useDirectGoogleAuthOnDesktop = bool.fromEnvironment(
    'USE_DIRECT_GOOGLE_AUTH_DESKTOP',
    defaultValue: false,
  );

  @visibleForTesting
  static bool? debugUseDirectGoogleAuthOnDesktop;

  static bool get effectiveUseDirectGoogleAuthOnDesktop =>
      debugUseDirectGoogleAuthOnDesktop ?? useDirectGoogleAuthOnDesktop;

  @visibleForTesting
  static void resetForTests() {
    debugUseDirectGoogleAuthOnDesktop = null;
    debugClient = null;
    debugUserId = null;
    lastGoogleAuthError = null;
    // ignore: invalid_use_of_visible_for_testing_member
    SupabaseConfig.debugOverrideConfigured = null;
    // ignore: invalid_use_of_visible_for_testing_member
    GoogleAuthConfig.resetForTests();
    // ignore: invalid_use_of_visible_for_testing_member
    GoogleAuthDesktopService.resetForTests();
  }

  static Future<void> ensureSession() async {
    if (!SupabaseConfig.isConfigured) return;
    try {
      if (client.auth.currentSession == null) {
        // Only try anonymous sign-in if enabled, otherwise proceed in guest mode with local alias
        try {
          await client.auth.signInAnonymously();
        } catch (_) {
          // Guest mode is active
        }
      }
    } catch (e) {
      debugPrint('Aviso de sesión: $e');
    }
  }

  /// Último error registrado durante la autenticación con Google.
  static String? lastGoogleAuthError;

  static Future<bool> signInWithGoogle({String? redirectTo}) async {
    lastGoogleAuthError = null;
    if (!SupabaseConfig.isConfigured) {
      lastGoogleAuthError = 'Supabase no está configurado.';
      return false;
    }
    try {
      if (GoogleAuthConfig.isDesktop && effectiveUseDirectGoogleAuthOnDesktop) {
        if (!GoogleAuthConfig.isConfigured) {
          final errorMsg =
              'Faltan credenciales de Google OAuth para escritorio.\n'
              'Inicia la app con:\n'
              '--dart-define=GOOGLE_CLIENT_ID="tu-client-id.apps.googleusercontent.com"\n'
              '--dart-define=GOOGLE_CLIENT_SECRET="tu-client-secret"';
          debugPrint('Aviso de configuración Google Desktop:\n$errorMsg');
          lastGoogleAuthError = errorMsg;
          return false;
        }

        final creds = await GoogleAuthDesktopService.signIn();
        if (creds == null) {
          final errorMsg = GoogleAuthDesktopService.lastError ??
              'Google Sign-In fue cancelado, expiró el tiempo de espera o no se recibieron credenciales en el navegador.';
          debugPrint(errorMsg);
          lastGoogleAuthError = errorMsg;
          return false;
        }

        final idToken = creds.idToken;
        if (idToken == null || idToken.isEmpty) {
          final errorMsg =
              'Google no retornó un id_token válido. Verifica que el cliente OAuth incluya el scope "openid".';
          debugPrint('Error: $errorMsg');
          lastGoogleAuthError = errorMsg;
          return false;
        }

        final response = await client.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
          accessToken: creds.accessToken,
        );

        if (response.session == null) {
          lastGoogleAuthError =
              'Supabase no pudo inicializar la sesión con el token de Google.';
          return false;
        }

        return true;
      }

      final redirectUrl =
          redirectTo ??
          (kIsWeb ? '${Uri.base.origin}/' : 'comunidadusac://login-callback/');
      final res = await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectUrl,
      );
      if (!res) {
        lastGoogleAuthError = 'No se pudo abrir el proveedor de OAuth de Google.';
      }
      return res;
    } on AuthException catch (e) {
      final msg = 'Error de Supabase Auth: ${e.message}';
      debugPrint(msg);
      lastGoogleAuthError = msg;
      return false;
    } catch (e) {
      final msg = 'Error en Google Sign-In: $e';
      debugPrint(msg);
      lastGoogleAuthError = msg;
      return false;
    }
  }

  static Future<String?> signInWithPassword({
    required String email,
    required String password,
  }) async {
    if (!SupabaseConfig.isConfigured) return null;
    try {
      final res = await client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return res.user?.id;
    } catch (e) {
      debugPrint('Error en inicio de sesión: $e');
      rethrow;
    }
  }

  static Future<AuthResponse?> signUp({
    required String email,
    required String password,
  }) async {
    if (!SupabaseConfig.isConfigured) return null;
    try {
      final res = await client.auth.signUp(
        email: email.trim(),
        password: password,
      );
      return res;
    } catch (e) {
      debugPrint('Error en registro: $e');
      rethrow;
    }
  }

  static Future<List<Factor>> listTotpFactors() async {
    if (!isAuthenticated) {
      throw StateError('Inicia sesión para administrar la autenticación TOTP.');
    }
    try {
      final response = await client.auth.mfa.listFactors();
      return response.all
          .where((factor) => factor.factorType == FactorType.totp)
          .toList();
    } catch (e) {
      debugPrint('Error consultando factores TOTP: $e');
      rethrow;
    }
  }

  static Future<AuthMFAGetAuthenticatorAssuranceLevelResponse>
  getTotpAssuranceLevel() async {
    if (!isAuthenticated) {
      throw StateError(
        'Inicia sesión para consultar el nivel de autenticación.',
      );
    }
    return client.auth.mfa.getAuthenticatorAssuranceLevel();
  }

  static Future<AuthMFAEnrollResponse> beginTotpEnrollment() async {
    final factors = await listTotpFactors();
    if (factors.any((factor) => factor.status == FactorStatus.verified)) {
      throw StateError('Ya hay un autenticador TOTP activo en esta cuenta.');
    }

    try {
      for (final factor in factors.where(
        (factor) => factor.status == FactorStatus.unverified,
      )) {
        await client.auth.mfa.unenroll(factor.id);
      }
      return await client.auth.mfa.enroll(
        factorType: FactorType.totp,
        issuer: 'Comunidad USAC',
        friendlyName: 'Comunidad USAC',
      );
    } catch (e) {
      debugPrint('Error iniciando inscripción TOTP: $e');
      rethrow;
    }
  }

  static Future<AuthMFAVerifyResponse> verifyTotpEnrollment({
    required String factorId,
    required String code,
  }) => verifyTotpChallenge(factorId: factorId, code: code);

  static Future<AuthMFAVerifyResponse> verifyTotpChallenge({
    required String factorId,
    required String code,
  }) async {
    if (!isAuthenticated) {
      throw StateError('Inicia sesión para verificar la autenticación TOTP.');
    }
    final normalizedCode = code.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(normalizedCode)) {
      throw ArgumentError('El código TOTP debe tener 6 dígitos.');
    }
    try {
      return await client.auth.mfa.challengeAndVerify(
        factorId: factorId,
        code: normalizedCode,
      );
    } catch (e) {
      debugPrint('Error verificando código TOTP: $e');
      rethrow;
    }
  }

  static Future<void> disableTotpWithCurrentCode({
    required String factorId,
    required String code,
  }) async {
    if (!isAuthenticated) {
      throw StateError('Inicia sesión para administrar la autenticación TOTP.');
    }
    final normalizedCode = code.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(normalizedCode)) {
      throw ArgumentError('El código TOTP debe tener 6 dígitos.');
    }

    final factors = await listTotpFactors();
    final factorExists = factors.any(
      (factor) =>
          factor.id == factorId && factor.status == FactorStatus.verified,
    );
    if (!factorExists) {
      throw StateError('No se encontró el factor TOTP verificado.');
    }

    await verifyTotpChallenge(factorId: factorId, code: normalizedCode);
    await client.auth.mfa.unenroll(factorId);
    try {
      await signOut();
    } catch (_) {
      await client.auth.signOut(scope: SignOutScope.local);
    }
  }

  static Future<void> signOut() async {
    if (GoogleAuthConfig.isDesktop && effectiveUseDirectGoogleAuthOnDesktop) {
      try {
        await GoogleAuthDesktopService.signOut();
      } catch (e) {
        debugPrint('Aviso al cerrar sesión Google Desktop: $e');
      }
    }
    if (!SupabaseConfig.isConfigured) return;
    await client.auth.signOut();
  }

  static Future<String> getUserRole() async {
    if (!SupabaseConfig.isConfigured || currentUser == null) return 'student';
    try {
      final res = await client
          .from('user_roles')
          .select('role')
          .eq('user_id', currentUser!.id)
          .maybeSingle();
      if (res != null && res['role'] != null) {
        return res['role'].toString();
      }
    } catch (e) {
      debugPrint('Error obteniendo rol de usuario: $e');
    }
    return 'student';
  }

  /// Genera un alias anónimo aleatorio y autorizado por las políticas de la comunidad.
  /// Llama a la función RPC `generate_anonymous_alias` de PostgreSQL.
  static Future<String> generateAnonymousAlias() async {
    if (!SupabaseConfig.isConfigured) return 'Estudiante Anónimo';
    try {
      final res = await client.rpc('generate_anonymous_alias');
      if (res != null && res.toString().trim().isNotEmpty) {
        return res.toString().trim();
      }
    } catch (e) {
      debugPrint('Error generando alias anónimo en servidor: $e');
    }
    return 'Estudiante USAC';
  }

  /// Valida si un alias propuesto cumple con las directrices de anonimato y seguridad
  /// llamando a la función RPC `is_valid_anonymous_alias`.
  static Future<bool> isValidAnonymousAlias(String alias) async {
    if (!SupabaseConfig.isConfigured) {
      final norm = alias.trim();
      return norm.isNotEmpty &&
          norm.length <= 48 &&
          !norm.contains('@') &&
          !norm.contains('.');
    }
    try {
      final res = await client.rpc(
        'is_valid_anonymous_alias',
        params: {'p_alias': alias.trim()},
      );
      return res == true;
    } catch (e) {
      debugPrint('Error validando alias: $e');
      final norm = alias.trim();
      return norm.isNotEmpty && norm.length <= 48 && !norm.contains('@');
    }
  }
}
