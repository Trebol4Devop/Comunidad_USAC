import 'package:flutter/foundation.dart';
import '../config/supabase_config.dart';
import '../models/notification_item.dart';
import 'supabase_service.dart';

class NotificationService {
  /// Obtiene la bandeja de notificaciones del usuario autenticado actual.
  static Future<List<NotificationItem>> fetchNotifications({
    int limit = 25,
  }) async {
    if (!SupabaseConfig.isConfigured) return [];
    final uid = SupabaseService.currentUserId;
    if (uid == null) return [];

    try {
      final res = await SupabaseService.client
          .from('user_notifications')
          .select('*')
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(limit);

      final list = res as List<dynamic>;
      return list
          .map((item) => NotificationItem.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      debugPrint('Error al obtener notificaciones: $e');
      return [];
    }
  }

  /// Cuenta las notificaciones no leídas (read_at IS NULL).
  static Future<int> getUnreadCount() async {
    if (!SupabaseConfig.isConfigured) return 0;
    final uid = SupabaseService.currentUserId;
    if (uid == null) return 0;

    try {
      final res = await SupabaseService.client
          .from('user_notifications')
          .select('id')
          .eq('user_id', uid)
          .isFilter('read_at', null);

      return (res as List<dynamic>).length;
    } catch (e) {
      debugPrint('Error al contar notificaciones no leídas: $e');
      return 0;
    }
  }

  /// Marca una notificación como leída.
  static Future<bool> markAsRead(String notificationId) async {
    if (!SupabaseConfig.isConfigured) return false;
    final uid = SupabaseService.currentUserId;
    if (uid == null) return false;

    try {
      await SupabaseService.client
          .from('user_notifications')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', notificationId)
          .eq('user_id', uid);

      return true;
    } catch (e) {
      debugPrint('Error al marcar notificación como leída: $e');
      return false;
    }
  }

  /// Marca todas las notificaciones pendientes como leídas.
  static Future<bool> markAllAsRead() async {
    if (!SupabaseConfig.isConfigured) return false;
    final uid = SupabaseService.currentUserId;
    if (uid == null) return false;

    try {
      await SupabaseService.client
          .from('user_notifications')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('user_id', uid)
          .isFilter('read_at', null);

      return true;
    } catch (e) {
      debugPrint('Error al marcar todas las notificaciones como leídas: $e');
      return false;
    }
  }

  /// Obtiene las preferencias de notificación del usuario actual.
  static Future<NotificationPreferences> getPreferences() async {
    final uid = SupabaseService.currentUserId;
    if (!SupabaseConfig.isConfigured || uid == null) {
      return NotificationPreferences(userId: uid ?? '');
    }

    try {
      final res = await SupabaseService.client
          .from('notification_preferences')
          .select('*')
          .eq('user_id', uid)
          .maybeSingle();

      final carreras = await _fetchCareerPreferences(uid);

      if (res != null) {
        return NotificationPreferences.fromMap(
          Map<String, dynamic>.from(res),
        ).copyWith(carreras: carreras);
      }

      final defaultPrefs = NotificationPreferences(userId: uid);
      await SupabaseService.client
          .from('notification_preferences')
          .insert(defaultPrefs.toMap());
      return defaultPrefs;
    } catch (e) {
      debugPrint('Error al obtener preferencias de notificación: $e');
      return NotificationPreferences(userId: uid);
    }
  }

  /// Actualiza las preferencias de notificación del usuario.
  static Future<bool> savePreferences(NotificationPreferences prefs) async {
    if (!SupabaseConfig.isConfigured) return false;
    final uid = SupabaseService.currentUserId;
    if (uid == null) return false;

    try {
      await SupabaseService.client
          .from('notification_preferences')
          .upsert(prefs.toMap());
      await _saveCareerPreferences(uid, prefs.carreras);
      return true;
    } catch (e) {
      debugPrint('Error guardando preferencias de notificación: $e');
      return false;
    }
  }

  static Future<List<String>> _fetchCareerPreferences(String uid) async {
    try {
      final res = await SupabaseService.client
          .from('notification_preference_carreras')
          .select('carrera_id')
          .eq('user_id', uid);
      return (res as List<dynamic>)
          .map((row) => row['carrera_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> _saveCareerPreferences(
    String uid,
    List<String> carreras,
  ) async {
    await SupabaseService.client
        .from('notification_preference_carreras')
        .delete()
        .eq('user_id', uid);
    if (carreras.isEmpty) return;
    await SupabaseService.client
        .from('notification_preference_carreras')
        .insert([
          for (final carrera in carreras)
            {'user_id': uid, 'carrera_id': carrera},
        ]);
  }
}
