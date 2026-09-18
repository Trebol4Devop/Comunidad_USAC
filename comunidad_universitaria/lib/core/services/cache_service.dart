import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Caché genérica de lecturas con TTL para los feeds de la app
/// (foro, grupos estudiantiles y marketplace).
///
/// - Memoria: evita repetir consultas dentro del TTL.
/// - Persistencia: guarda la primera página en SharedPreferences para
///   arranque sin conexión; la copia persistida también respeta el TTL.
class CacheService {
  CacheService._();

  /// TTL por defecto de los feeds (rango recomendado: 30-60 segundos).
  static const Duration defaultTtl = Duration(seconds: 45);

  static const String _prefsPrefix = 'feed_cache_';

  static final Map<String, _CacheEntry> _memory = {};

  /// Construye una clave estable a partir de la combinación de filtros.
  static String buildKey(Map<String, dynamic> parts) {
    final keys = parts.keys.toList()..sort();
    return keys.map((k) => '$k=${parts[k]}').join('&');
  }

  /// Devuelve el valor en memoria si existe y no ha expirado.
  static T? get<T>(String namespace, String key) {
    final memoryKey = _memoryKey(namespace, key);
    final entry = _memory[memoryKey];
    if (entry == null) return null;

    if (entry.isExpired) {
      _memory.remove(memoryKey);
      return null;
    }

    final value = entry.value;
    if (value is T) return value;
    return null;
  }

  /// Guarda un valor en memoria con el TTL indicado.
  static void set<T>(String namespace, String key, T value, {Duration ttl = defaultTtl}) {
    _memory[_memoryKey(namespace, key)] = _CacheEntry(value, ttl);
  }

  /// Invalida todas las entradas en memoria de un namespace.
  static void invalidate(String namespace) {
    final prefix = '$namespace::';
    _memory.removeWhere((key, _) => key.startsWith(prefix));
  }

  /// Invalida memoria y persistencia de un namespace.
  static Future<void> invalidateAll(String namespace) async {
    invalidate(namespace);
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefix = '$_prefsPrefix$namespace::';
      final keys = prefs.getKeys().where((k) => k.startsWith(prefix)).toList();
      for (final k in keys) {
        await prefs.remove(k);
      }
    } catch (e) {
      debugPrint('Error al invalidar caché persistente ($namespace): $e');
    }
  }

  /// Guarda una copia JSON en SharedPreferences para arranque offline.
  static Future<void> setPersisted(
    String namespace,
    String key,
    Object? data, {
    Duration ttl = defaultTtl,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey(namespace, key),
        jsonEncode({
          'stored_at': DateTime.now().toIso8601String(),
          'ttl_ms': ttl.inMilliseconds,
          'data': data,
        }),
      );
    } catch (e) {
      debugPrint('Error al guardar caché persistente ($namespace): $e');
    }
  }

  /// Lee la copia persistida. Devuelve null si no existe o si superó el TTL.
  static Future<T?> getPersisted<T>(
    String namespace,
    String key,
    T Function(Object? data) decode,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey(namespace, key));
      if (raw == null) return null;

      final parsed = jsonDecode(raw);
      if (parsed is! Map) return null;

      final storedAt = DateTime.tryParse(parsed['stored_at']?.toString() ?? '');
      if (storedAt == null) return null;

      final ttlMs = parsed['ttl_ms'] is int ? parsed['ttl_ms'] as int : defaultTtl.inMilliseconds;
      if (DateTime.now().difference(storedAt).inMilliseconds > ttlMs) return null;

      return decode(parsed['data']);
    } catch (e) {
      debugPrint('Error al leer caché persistente ($namespace): $e');
      return null;
    }
  }

  static String _memoryKey(String namespace, String key) => '$namespace::$key';
  static String _prefsKey(String namespace, String key) => '$_prefsPrefix$namespace::$key';
}

class _CacheEntry {
  _CacheEntry(this.value, this.ttl) : storedAt = DateTime.now();

  final Object? value;
  final Duration ttl;
  final DateTime storedAt;

  bool get isExpired => DateTime.now().difference(storedAt) > ttl;
}
