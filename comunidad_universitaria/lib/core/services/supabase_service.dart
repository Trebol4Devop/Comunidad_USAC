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
