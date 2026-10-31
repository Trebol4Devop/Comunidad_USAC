import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_service.dart';

/// Guarda ocultamientos de anuncios patrocinados en este dispositivo.
/// Los identificadores son públicos y se aíslan por usuario autenticado.
class SponsoredPreferencesService {
  SponsoredPreferencesService._();

  static final Map<String, Set<String>> _memoryHiddenItems = {};

  static String _preferenceKey(String? userId) =>
      'sponsored_hidden_items_${userId ?? 'anonymous'}';

  static Future<Set<String>> hiddenItemIds({String? userId}) async {
    try {
      final key = _preferenceKey(userId ?? SupabaseService.currentUserId);
      final prefs = await SharedPreferences.getInstance();
      return {...?prefs.getStringList(key), ...?_memoryHiddenItems[key]};
    } catch (_) {
      return <String>{};
    }
  }

  static Future<void> hideItem(String itemId, {String? userId}) async {
    if (itemId.trim().isEmpty) return;

    final key = _preferenceKey(userId ?? SupabaseService.currentUserId);
    (_memoryHiddenItems[key] ??= <String>{}).add(itemId);

    try {
      final prefs = await SharedPreferences.getInstance();
      final hiddenItems = prefs.getStringList(key) ?? <String>[];
      if (!hiddenItems.contains(itemId)) {
        await prefs.setStringList(key, [...hiddenItems, itemId]);
      }
    } catch (_) {
      // La preferencia queda activa al menos en memoria durante esta sesión.
    }
  }
}
