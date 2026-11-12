import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/supabase_config.dart';
import 'supabase_service.dart';

/// Servicio para registrar y sincronizar la cantidad de veces que una publicación
/// (post de foro o anuncio de marketplace) ha sido compartida por los estudiantes.
class ShareCountService {
  static final Map<String, int> _cache = {};

  /// Obtiene el conteo en memoria de forma inmediata.
  static int getCachedCount(String id) {
    return _cache[id] ?? 0;
  }

  /// Precarga los contadores de una lista de IDs para acceso síncrono ultra-rápido en UI.
  static Future<void> preload(List<String> ids) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final id in ids) {
        if (id.isEmpty) continue;
        final saved = prefs.getInt('share_count_$id');
        if (saved != null) {
          _cache[id] = saved;
        }
      }
    } catch (e) {
      debugPrint('Error precargando contadores de compartidos: $e');
    }
  }

  /// Obtiene el número de veces que se ha compartido un elemento.
  static Future<int> getShareCount(String id) async {
    if (_cache.containsKey(id)) return _cache[id]!;
    try {
      final prefs = await SharedPreferences.getInstance();
      final count = prefs.getInt('share_count_$id') ?? 0;
      _cache[id] = count;
      return count;
    } catch (_) {
      return _cache[id] ?? 0;
    }
  }

  /// Incrementa el contador de compartidos de una publicación y lo persiste localmente
  /// y de forma remota en Supabase si la columna está disponible.
  static Future<int> incrementShare(String id, {String table = 'posts'}) async {
    if (id.isEmpty) return 0;
    int nextCount = 1;
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getInt('share_count_$id') ?? (_cache[id] ?? 0);
      nextCount = current + 1;
      _cache[id] = nextCount;
      await prefs.setInt('share_count_$id', nextCount);
    } catch (e) {
      debugPrint('Error guardando share local: $e');
      nextCount = (_cache[id] ?? 0) + 1;
      _cache[id] = nextCount;
    }

    // Intento no bloqueante de persistencia en backend
    try {
      if (SupabaseConfig.isConfigured) {
        // Intenta actualizar columna shares_count si existe en la tabla
        await SupabaseService.client
            .from(table)
            .update({'shares_count': nextCount})
            .eq('id', id);
      }
    } catch (_) {
      // Ignora silenciosamente si la tabla o columna no tiene permisos o no existe en Supabase
    }

    return nextCount;
  }
}
