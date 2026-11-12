import 'package:flutter/foundation.dart';
import '../config/supabase_config.dart';
import 'supabase_service.dart';

class ModerationService {
  /// Verifica si el usuario actual tiene permisos de Administrador PEMTREE.
  static Future<bool> isAdmin() async {
    if (!SupabaseConfig.isConfigured) return false;
    final uid = SupabaseService.currentUserId;
    if (uid == null) return false;

    try {
      final res = await SupabaseService.client
          .rpc('is_pemtree_admin', params: {'p_user_id': uid});
      return res == true;
    } catch (e) {
      debugPrint('Error verificando admin: $e');
      final role = await SupabaseService.getUserRole();
      return role == 'admin';
    }
  }

  /// Verifica si el usuario actual tiene permisos de Moderador PEMTREE.
  static Future<bool> isModerator() async {
    if (!SupabaseConfig.isConfigured) return false;
    final uid = SupabaseService.currentUserId;
    if (uid == null) return false;

    try {
      final res = await SupabaseService.client
          .rpc('is_pemtree_moderator', params: {'p_user_id': uid});
      return res == true;
    } catch (e) {
      debugPrint('Error verificando moderador: $e');
      final role = await SupabaseService.getUserRole();
      return role == 'moderator' || role == 'admin';
    }
  }

  /// Obtiene las estadísticas generales del panel de administración (JSONB).
  static Future<Map<String, dynamic>?> getDashboardStats() async {
    if (!SupabaseConfig.isConfigured) return null;

    try {
      final res = await SupabaseService.client.rpc('get_admin_dashboard_stats');
      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }
      return null;
    } catch (e) {
      debugPrint('Error al obtener estadísticas del dashboard admin: $e');
      return null;
    }
  }

  /// Obtiene el resumen de usuarios para la consola de administración.
  static Future<List<Map<String, dynamic>>> getUsersSummary() async {
    if (!SupabaseConfig.isConfigured) return [];

    try {
      final res = await SupabaseService.client.rpc('get_admin_users_summary');
      if (res is List) {
        return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error al obtener resumen de usuarios: $e');
      return [];
    }
  }

  /// Obtiene estadísticas de verificación de perfiles y hashes de estudiantes.
  static Future<Map<String, dynamic>?> getVerificationStats() async {
    if (!SupabaseConfig.isConfigured) return null;

    try {
      final res = await SupabaseService.client.rpc('get_verification_stats');
      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }
      return null;
    } catch (e) {
      debugPrint('Error al obtener estadísticas de verificación: $e');
      return null;
    }
  }

  /// Obtiene los elementos en la cola de revisión humana pendientes.
  static Future<List<Map<String, dynamic>>> getColaRevision({
    double umbral = 0.5,
  }) async {
    if (!SupabaseConfig.isConfigured) return [];

    try {
      final res = await SupabaseService.client.rpc(
        'panel_cola_revision',
        params: {'p_umbral': umbral},
      );
      if (res is List) {
        return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error al obtener cola de revisión humana: $e');
      return [];
    }
  }

  /// Oculta contenido reportado o inapropiado (moderation_status = 2) y registra en auditoría.
  static Future<bool> ocultarContenido({
    required String tabla, // 'posts', 'comments', 'whatsapp_groups', 'marketplace_items'
    required String itemId,
    required String justificacion,
  }) async {
    if (!SupabaseConfig.isConfigured) return false;

    try {
      final res = await SupabaseService.client.rpc(
        'ocultar_contenido_moderado',
        params: {
          'p_tabla': tabla,
          'p_item_id': itemId,
          'p_justificacion': justificacion.trim(),
        },
      );
      return res == true;
    } catch (e) {
      debugPrint('Error al ocultar contenido: $e');
      return false;
    }
  }

  /// Restaura contenido a estado visible/aprobado (moderation_status = 0 o 1).
  static Future<bool> restaurarContenido({
    required String tabla,
    required String itemId,
  }) async {
    if (!SupabaseConfig.isConfigured) return false;

    try {
      final res = await SupabaseService.client.rpc(
        'restaurar_contenido_moderado',
        params: {
          'p_tabla': tabla,
          'p_item_id': itemId,
        },
      );
      return res == true;
    } catch (e) {
      debugPrint('Error al restaurar contenido: $e');
      return false;
    }
  }

  /// Elimina definitivamente un contenido inapropiado respetando la retención legal.
  static Future<bool> eliminarContenido({
    required String tabla,
    required String itemId,
    required String justificacion,
  }) async {
    if (!SupabaseConfig.isConfigured) return false;

    try {
      final res = await SupabaseService.client.rpc(
        'eliminar_contenido_moderado',
        params: {
          'p_tabla': tabla,
          'p_item_id': itemId,
          'p_justificacion': justificacion.trim(),
        },
      );
      return res == true;
    } catch (e) {
      debugPrint('Error al eliminar contenido moderado: $e');
      return false;
    }
  }

  /// Aprueba un elemento en el panel de revisión humana.
  static Future<bool> panelAprobar({
    required String tabla,
    required String itemId,
    String? comentario,
  }) async {
    if (!SupabaseConfig.isConfigured) return false;

    try {
      final res = await SupabaseService.client.rpc(
        'panel_aprobar',
        params: {
          'p_tabla': tabla,
          'p_item_id': itemId,
          'p_comentario': comentario?.trim(),
        },
      );
      return res == true;
    } catch (e) {
      debugPrint('Error al aprobar en panel de moderación: $e');
      return false;
    }
  }

  /// Rechaza y oculta un elemento en el panel de revisión humana.
  static Future<bool> panelRechazar({
    required String tabla,
    required String itemId,
    required String motivo,
  }) async {
    if (!SupabaseConfig.isConfigured) return false;

    try {
      final res = await SupabaseService.client.rpc(
        'panel_rechazar',
        params: {
          'p_tabla': tabla,
          'p_item_id': itemId,
          'p_motivo': motivo.trim(),
        },
      );
      return res == true;
    } catch (e) {
      debugPrint('Error al rechazar en panel de moderación: $e');
      return false;
    }
  }

  /// Envía un elemento nuevamente a revisión automática del clasificador.
  static Future<bool> panelRemoderar({
    required String tabla,
    required String itemId,
  }) async {
    if (!SupabaseConfig.isConfigured) return false;

    try {
      final res = await SupabaseService.client.rpc(
        'panel_remoderar',
        params: {
          'p_tabla': tabla,
          'p_item_id': itemId,
        },
      );
      return res == true;
    } catch (e) {
      debugPrint('Error al re-moderar en panel: $e');
      return false;
    }
  }
}
