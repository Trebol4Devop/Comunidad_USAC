import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class RecoveryCodeStatus {
  const RecoveryCodeStatus({required this.total, required this.remaining});

  final int total;
  final int remaining;
}

class RecoveryCodeRequestException implements Exception {
  const RecoveryCodeRequestException(this.statusCode);

  final int statusCode;
}

class SupabaseService {
  @visibleForTesting
  static SupabaseClient? debugClient;

  @visibleForTesting
  static http.Client? debugRecoveryCodesHttpClient;

  static SupabaseClient get client => debugClient ?? SupabaseConfig.client;

  @visibleForTesting
  static String? debugUserId;

  static User? get currentUser =>
      SupabaseConfig.isConfigured ? client.auth.currentUser : null;
  static String? get currentUserId => debugUserId ?? currentUser?.id;
  static bool get isAuthenticated =>
      currentUser != null && !(currentUser!.isAnonymous);

  @visibleForTesting
  static void resetForTests() {
    debugClient = null;
    debugRecoveryCodesHttpClient = null;
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

  static Future<AuthResponse?> verifySignupOtp({
    required String email,
    required String token,
  }) async {
    if (!SupabaseConfig.isConfigured) return null;
    try {
      return await client.auth.verifyOTP(
        type: OtpType.signup,
        email: email.trim(),
        token: token.trim(),
      );
    } catch (e) {
      debugPrint('Error verificando correo: $e');
      rethrow;
    }
  }

  static Future<void> resendSignupOtp(String email) async {
    if (!SupabaseConfig.isConfigured) return;
    try {
      await client.auth.resend(type: OtpType.signup, email: email.trim());
    } catch (e) {
      debugPrint('Error reenviando código de verificación: $e');
      rethrow;
    }
  }

  static Future<bool> requestPasswordReset(String email) async {
    if (!SupabaseConfig.isConfigured) return false;
    try {
      await client.auth.resetPasswordForEmail(email.trim());
      return true;
    } catch (e) {
      debugPrint('Error solicitando recuperación de contraseña: $e');
      rethrow;
    }
  }

  static Future<AuthResponse?> verifyPasswordResetOtp({
    required String email,
    required String token,
  }) async {
    if (!SupabaseConfig.isConfigured) return null;
    try {
      return await client.auth.verifyOTP(
        type: OtpType.recovery,
        email: email.trim(),
        token: token.trim(),
      );
    } catch (e) {
      debugPrint('Error verificando código de recuperación: $e');
      rethrow;
    }
  }

  static Future<void> updatePassword(String password) async {
    if (!SupabaseConfig.isConfigured) return;
    try {
      await client.auth.updateUser(UserAttributes(password: password));
    } catch (e) {
      debugPrint('Error actualizando contraseña: $e');
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

  static Future<RecoveryCodeStatus> getRecoveryCodeStatus() async {
    final response = await _recoveryCodesRequest('GET', allowNotFound: true);
    final payload = _decodeRecoveryCodesPayload(response);
    if (response.statusCode == 404 &&
        (payload['error_code'] ?? payload['code']) == 'mfa_factor_not_found') {
      return const RecoveryCodeStatus(total: 0, remaining: 0);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('No se pudo consultar el estado de códigos.');
    }
    final total = payload['total'];
    final remaining = payload['remaining'];
    if (total is! num || remaining is! num || total < 0 || remaining < 0) {
      throw StateError('Supabase devolvió un estado de códigos inválido.');
    }
    return RecoveryCodeStatus(
      total: total.toInt(),
      remaining: remaining.toInt(),
    );
  }

  static Future<List<String>> generateRecoveryCodes({
    bool regenerate = false,
  }) async {
    final assurance = await getTotpAssuranceLevel();
    if (assurance.currentLevel != AuthenticatorAssuranceLevels.aal2) {
      throw StateError('Se requiere una sesión AAL2 para administrar códigos.');
    }

    final response = await _recoveryCodesRequest(
      'POST',
      path: regenerate
          ? '/factors/recovery-codes/regenerate'
          : '/factors/recovery-codes',
    );
    final payload = _decodeRecoveryCodesPayload(response);
    final rawCodes =
        payload['codes'] ??
        payload['recovery_codes'] ??
        payload['recoveryCodes'];
    if (rawCodes is! List || rawCodes.any((code) => code is! String)) {
      throw StateError('Supabase no devolvió los códigos de recuperación.');
    }
    return rawCodes.cast<String>();
  }

  static Future<void> verifyRecoveryCode(String code) async {
    if (!isAuthenticated) {
      throw StateError('Inicia sesión para usar un código de recuperación.');
    }
    final normalizedCode = code.trim();
    if (normalizedCode.isEmpty) {
      throw ArgumentError('Ingresa un código de recuperación.');
    }

    final response = await _recoveryCodesRequest(
      'POST',
      path: '/factors/recovery-codes/verify',
      body: {'code': normalizedCode},
    );
    final payload = _decodeRecoveryCodesPayload(response);
    final accessToken = payload['access_token'];
    final refreshToken = payload['refresh_token'];
    if (accessToken is! String ||
        accessToken.isEmpty ||
        refreshToken is! String ||
        refreshToken.isEmpty) {
      throw StateError('Supabase no devolvió una sesión verificada.');
    }
    await client.auth.setSession(refreshToken, accessToken: accessToken);
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

  static Future<http.Response> _recoveryCodesRequest(
    String method, {
    String path = '/factors/recovery-codes',
    Map<String, dynamic>? body,
    bool allowNotFound = false,
  }) async {
    if (!isAuthenticated) {
      throw StateError(
        'Inicia sesión para administrar códigos de recuperación.',
      );
    }
    final accessToken = client.auth.currentSession?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw StateError('No hay una sesión válida para esta operación.');
    }

    final uri = Uri.parse('${SupabaseConfig.supabaseUrl}/auth/v1$path');
    final request = http.Request(method, uri)
      ..headers.addAll({
        'apikey': SupabaseConfig.supabaseAnonKey,
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      });
    if (body != null) request.body = jsonEncode(body);

    final httpClient = debugRecoveryCodesHttpClient ?? http.Client();
    try {
      final streamedResponse = await httpClient.send(request);
      final response = await http.Response.fromStream(streamedResponse);
      if ((response.statusCode < 200 || response.statusCode >= 300) &&
          !(allowNotFound && response.statusCode == 404)) {
        throw RecoveryCodeRequestException(response.statusCode);
      }
      return response;
    } finally {
      if (debugRecoveryCodesHttpClient == null) httpClient.close();
    }
  }

  static Map<String, dynamic> _decodeRecoveryCodesPayload(
    http.Response response,
  ) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final data = decoded['data'];
        return data is Map<String, dynamic> ? data : decoded;
      }
    } catch (_) {
      // Do not include response content; it may contain one-time recovery codes.
    }
    throw StateError('Supabase devolvió una respuesta inválida.');
  }

  static Future<void> sendMagicLink(String email) async {
    if (!SupabaseConfig.isConfigured) return;
    try {
      final redirectUrl = kIsWeb
          ? '${Uri.base.origin}/'
          : 'comunidadusac://login-callback/';
      await client.auth.signInWithOtp(
        email: email.trim(),
        emailRedirectTo: redirectUrl,
      );
    } catch (e) {
      debugPrint('Error enviando enlace mágico: $e');
      rethrow;
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
}
