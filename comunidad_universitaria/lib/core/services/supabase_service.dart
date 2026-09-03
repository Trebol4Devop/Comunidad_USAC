import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class SupabaseService {
  static SupabaseClient get client => SupabaseConfig.client;

  static User? get currentUser => SupabaseConfig.isConfigured ? client.auth.currentUser : null;
  static String? get currentUserId => currentUser?.id;
  static bool get isAuthenticated => currentUser != null && !(currentUser!.isAnonymous);

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
      final redirectUrl = redirectTo ?? (kIsWeb ? '${Uri.base.origin}/' : 'comunidadusac://login-callback/');
      return await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectUrl,
      );
    } catch (e) {
      debugPrint('Error en Google Sign-In: $e');
      return false;
    }
  }

  static Future<String?> signInWithPassword({required String email, required String password}) async {
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

  static Future<String?> signUp({required String email, required String password}) async {
    if (!SupabaseConfig.isConfigured) return null;
    try {
      final res = await client.auth.signUp(
        email: email.trim(),
        password: password,
      );
      return res.user?.id;
    } catch (e) {
      debugPrint('Error en registro: $e');
      rethrow;
    }
  }

  static Future<void> sendMagicLink(String email) async {
    if (!SupabaseConfig.isConfigured) return;
    try {
      final redirectUrl = kIsWeb ? '${Uri.base.origin}/' : 'comunidadusac://login-callback/';
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
