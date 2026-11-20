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
  static const String _keyMessenger = 'usac_contact_messenger';
  static const String _keyCarne = 'usac_student_carne';
  static const String _keyStudentName = 'usac_student_name';
  static const String _keyCarneVerified = 'usac_carne_verified';
  static const String _keyCleanupDismissed = 'usac_cleanup_dismissed';
  static const String _keyGuestMode = 'usac_guest_mode';
  static const String _keyPendingAuthIntent = 'usac_pending_auth_intent';

  static Future<String?> getPendingAuthIntent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPendingAuthIntent);
  }

  static Future<void> setPendingAuthIntent(String intent) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPendingAuthIntent, intent);
  }

  static Future<void> clearPendingAuthIntent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPendingAuthIntent);
  }

  static Future<bool> isGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyGuestMode) ?? false;
  }

  static Future<void> setGuestMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value) {
      await prefs.setBool(_keyGuestMode, true);
    } else {
      await prefs.remove(_keyGuestMode);
    }
  }

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
    final messenger = prefs.getString(_keyMessenger);
    // Anti-doxxing: el carné no se persiste en claro. Limpiar si existe valor previo.
    if (prefs.containsKey(_keyCarne)) {
      await prefs.remove(_keyCarne);
    }
    const String? carne = null;
    final studentName = prefs.getString(_keyStudentName);
    if (prefs.getBool(_keyCarneVerified) == true) {
      await prefs.setBool(_keyCarneVerified, false);
    }
    const isCarneVerified = false;
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
      contactMessenger: messenger,
      email: email,
      carne: carne,
      studentName: studentName,
      isCarneVerified: isCarneVerified,
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

    // Anti-doxxing: el carné no se persiste en claro en shared_preferences.
    await prefs.remove(_keyCarne);

    if (profile.studentName != null && profile.studentName!.trim().isNotEmpty) {
      await prefs.setString(_keyStudentName, profile.studentName!.trim());
    } else {
      await prefs.remove(_keyStudentName);
    }

    await prefs.setBool(_keyCarneVerified, false);

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

    if (profile.contactMessenger != null) {
      await prefs.setString(_keyMessenger, profile.contactMessenger!.trim());
    } else {
      await prefs.remove(_keyMessenger);
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
