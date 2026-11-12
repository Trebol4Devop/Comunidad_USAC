import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

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

  @visibleForTesting
  static void resetForTests() {
    debugClient = null;
    debugUserId = null;
    // ignore: invalid_use_of_visible_for_testing_member
    SupabaseConfig.debugOverrideConfigured = null;
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

  static Future<bool> signInWithGoogle({String? redirectTo}) async {
    if (!SupabaseConfig.isConfigured) return false;
    try {
      final redirectUrl =
          redirectTo ??
          (kIsWeb ? '${Uri.base.origin}/' : 'comunidadusac://login-callback/');
      return await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectUrl,
      );
    } catch (e) {
      debugPrint('Error en Google Sign-In: $e');
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
