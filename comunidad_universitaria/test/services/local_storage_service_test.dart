import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:comunidad_universitaria/core/models/user_profile.dart';
import 'package:comunidad_universitaria/core/services/local_storage_service.dart';
import 'package:comunidad_universitaria/core/services/supabase_service.dart';
import '../helpers/test_setup.dart';

void main() {
  setUp(() async {
    await resetTestState();
  });

  tearDown(() async {
    await resetTestState();
  });

  group('LocalStorageService.getOrGenerateAlias & saveAlias', () {
    test('genera y persiste nuevo alias aleatorio si no existe previo', () async {
      SharedPreferences.setMockInitialValues({});

      final alias1 = await LocalStorageService.getOrGenerateAlias();
      expect(alias1, startsWith('Estudiante USAC #'));

      // Segunda llamada devuelve el mismo alias persistido
      final alias2 = await LocalStorageService.getOrGenerateAlias();
      expect(alias2, alias1);
    });

    test('respeta alias existente y no lo sobreescribe', () async {
      SharedPreferences.setMockInitialValues({
        'usac_forum_alias': 'Ingeniero 2026',
      });

      final alias = await LocalStorageService.getOrGenerateAlias();
      expect(alias, 'Ingeniero 2026');
    });

    test('saveAlias guarda el nuevo alias con trim', () async {
      await LocalStorageService.saveAlias('  Nuevo Alias USAC  ');
      final alias = await LocalStorageService.getOrGenerateAlias();
      expect(alias, 'Nuevo Alias USAC');
    });
  });

  group('LocalStorageService Profile Persistence', () {
    test('round-trip saveUserProfile y getUserProfile con todos los campos', () async {
      SupabaseService.debugUserId = 'auth-uid-100';

      const profile = UserProfile(
        userId: 'auth-uid-100',
        alias: 'Estudiante Destacado',
        role: 'student',
        facultadId: '08',
        carreraId: 'industrial',
        sedeId: 'cum',
        bio: 'Estudio y trabajo',
        avatarColorIndex: 3,
        avatarIconIndex: 2,
        contactWhatsapp: '50211112222',
        contactTelegram: 'tele_destacado',
        contactInstagram: 'insta_destacado',
        carne: '202112345',
        studentName: 'Ana Lucía Gómez',
        isCarneVerified: true,
      );

      await LocalStorageService.saveUserProfile(profile);

      final loaded = await LocalStorageService.getUserProfile();
      expect(loaded.userId, 'auth-uid-100');
      expect(loaded.alias, 'Estudiante Destacado');
      expect(loaded.facultadId, '08');
      expect(loaded.carreraId, 'industrial');
      expect(loaded.sedeId, 'cum');
      expect(loaded.bio, 'Estudio y trabajo');
      expect(loaded.avatarColorIndex, 3);
      expect(loaded.avatarIconIndex, 2);
      expect(loaded.contactWhatsapp, '50211112222');
      expect(loaded.contactTelegram, 'tele_destacado');
      expect(loaded.contactInstagram, 'insta_destacado');
      expect(loaded.carne, '202112345');
      expect(loaded.studentName, 'Ana Lucía Gómez');
      expect(loaded.isCarneVerified, isTrue);
    });

    test('getUserProfile aplica defaults limpios en ausencia de datos previos', () async {
      SharedPreferences.setMockInitialValues({});
      SupabaseService.debugUserId = null;

      final profile = await LocalStorageService.getUserProfile();
      expect(profile.userId, 'local_user');
      expect(profile.facultadId, '08');
      expect(profile.carreraId, 'sistemas');
      expect(profile.sedeId, 'central');
      expect(profile.bio, '');
      expect(profile.avatarColorIndex, 0);
      expect(profile.avatarIconIndex, 0);
      expect(profile.contactWhatsapp, isNull);
      expect(profile.carne, isNull);
      expect(profile.isCarneVerified, isFalse);
    });
  });

  group('LocalStorageService Settings & Flags', () {
    test('isDarkMode y saveThemeMode', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await LocalStorageService.isDarkMode(), isFalse);

      await LocalStorageService.saveThemeMode(true);
      expect(await LocalStorageService.isDarkMode(), isTrue);

      await LocalStorageService.saveThemeMode(false);
      expect(await LocalStorageService.isDarkMode(), isFalse);
    });

    test('dismissCleanupNotice y isCleanupNoticeDismissed', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await LocalStorageService.isCleanupNoticeDismissed(), isFalse);

      await LocalStorageService.dismissCleanupNotice();
      expect(await LocalStorageService.isCleanupNoticeDismissed(), isTrue);
    });
  });
}
