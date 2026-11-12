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

      if (res != null) {
        return NotificationPreferences.fromMap(Map<String, dynamic>.from(res));
      }

      // Si no existe, crear registro por defecto
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
      return true;
    } catch (e) {
      debugPrint('Error guardando preferencias de notificación: $e');
      return false;
    }
  }
}
