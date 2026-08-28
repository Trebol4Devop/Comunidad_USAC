import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';
import 'supabase_service.dart';

class LocalStorageService {
  static const String _keyAlias = 'usac_forum_alias';
  static const String _keyThemeMode = 'usac_theme_mode';
  static const String _keySelectedFacultad = 'usac_selected_facultad';
  static const String _keySelectedCarrera = 'usac_selected_carrera';
  static const String _keySelectedSede = 'usac_selected_sede';
  static const String _keyUserBio = 'usac_user_bio';
  static const String _keyAvatarColor = 'usac_avatar_color';
  static const String _keyAvatarIcon = 'usac_avatar_icon';
  static const String _keyWhatsapp = 'usac_contact_whatsapp';
  static const String _keyTelegram = 'usac_contact_telegram';
  static const String _keyInstagram = 'usac_contact_instagram';
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

  static Future<UserProfile> getUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final alias = await getOrGenerateAlias();
    final facultad = prefs.getString(_keySelectedFacultad) ?? '08';
    final carrera = prefs.getString(_keySelectedCarrera) ?? 'sistemas';
    final sede = prefs.getString(_keySelectedSede) ?? 'central';
    final bio = prefs.getString(_keyUserBio) ?? '';
    final avatarColor = prefs.getInt(_keyAvatarColor) ?? 0;
    final avatarIcon = prefs.getInt(_keyAvatarIcon) ?? 0;
    final whatsapp = prefs.getString(_keyWhatsapp);
    final telegram = prefs.getString(_keyTelegram);
    final instagram = prefs.getString(_keyInstagram);
    final userId = SupabaseService.currentUserId ?? 'local_user';
    final role = await SupabaseService.getUserRole();
    final email = SupabaseService.currentUser?.email;

    return UserProfile(
      userId: userId,
      alias: alias,
      role: role,
      facultadId: facultad,
      carreraId: carrera,
      sedeId: sede,
      bio: bio,
      avatarColorIndex: avatarColor,
      avatarIconIndex: avatarIcon,
      contactWhatsapp: whatsapp,
      contactTelegram: telegram,
      contactInstagram: instagram,
      email: email,
    );
  }

  static Future<void> saveUserProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAlias, profile.alias.trim());
    await prefs.setString(_keySelectedFacultad, profile.facultadId);
    await prefs.setString(_keySelectedCarrera, profile.carreraId);
    await prefs.setString(_keySelectedSede, profile.sedeId);
    await prefs.setString(_keyUserBio, profile.bio.trim());
    await prefs.setInt(_keyAvatarColor, profile.avatarColorIndex);
    await prefs.setInt(_keyAvatarIcon, profile.avatarIconIndex);

    if (profile.contactWhatsapp != null) {
      await prefs.setString(_keyWhatsapp, profile.contactWhatsapp!.trim());
    } else {
      await prefs.remove(_keyWhatsapp);
    }

    if (profile.contactTelegram != null) {
      await prefs.setString(_keyTelegram, profile.contactTelegram!.trim());
    } else {
      await prefs.remove(_keyTelegram);
    }

    if (profile.contactInstagram != null) {
      await prefs.setString(_keyInstagram, profile.contactInstagram!.trim());
    } else {
      await prefs.remove(_keyInstagram);
    }
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
