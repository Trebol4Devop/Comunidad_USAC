import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static const String _keyAlias = 'usac_forum_alias';
  static const String _keyThemeMode = 'usac_theme_mode';
  static const String _keySelectedFacultad = 'usac_selected_facultad';
  static const String _keyCleanupDismissed = 'usac_cleanup_dismissed';

  static Future<String> getOrGenerateAlias() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_keyAlias);
    if (saved != null && saved.trim().isNotEmpty) {
      return saved.trim();
    }
    // Generate a random student alias (e.g., "Estudiante USAC #482")
    final randomNum = 100 + Random().nextInt(900);
    final defaultAlias = 'Estudiante USAC #$randomNum';
    await prefs.setString(_keyAlias, defaultAlias);
    return defaultAlias;
  }

  static Future<void> saveAlias(String alias) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAlias, alias.trim());
  }

  static Future<bool> isDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyThemeMode) ?? false;
  }

  static Future<void> saveThemeMode(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyThemeMode, isDark);
  }

  static Future<String?> getSelectedFacultad() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySelectedFacultad);
  }

  static Future<void> saveSelectedFacultad(String facultadId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySelectedFacultad, facultadId);
  }

  static Future<bool> isCleanupNoticeDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyCleanupDismissed) ?? false;
  }

  static Future<void> dismissCleanupNotice() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyCleanupDismissed, true);
  }
}
