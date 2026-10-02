import 'package:flutter_test/flutter_test.dart';
import 'package:comunidad_universitaria/core/models/user_profile.dart';

void main() {
  group('UserProfile Model Unit Tests', () {
    test('Creación de perfil con valores por defecto', () {
      const profile = UserProfile(
        userId: 'test-user-123',
        alias: 'Estudiante USAC #500',
      );

      expect(profile.userId, 'test-user-123');
      expect(profile.alias, 'Estudiante USAC #500');
      expect(profile.role, 'student');
      expect(profile.facultadId, '08');
      expect(profile.carreraId, 'sistemas');
      expect(profile.sedeId, 'central');
      expect(profile.bio, '');
      expect(profile.avatarColorIndex, 0);
      expect(profile.avatarIconIndex, 0);
      expect(profile.isAdmin, isFalse);
      expect(profile.isModerator, isFalse);
      expect(profile.isCarneVerified, isFalse);
    });

    test('Roles de usuario: permisos de isAdmin y isModerator', () {
      const adminProfile = UserProfile(
        userId: 'admin-1',
        alias: 'Admin General',
        role: 'admin',
      );
      expect(adminProfile.isAdmin, isTrue);
      expect(adminProfile.isModerator, isTrue);

      const modProfile = UserProfile(
        userId: 'mod-1',
        alias: 'Moderador Foro',
        role: 'moderator',
      );
      expect(modProfile.isAdmin, isFalse);
      expect(modProfile.isModerator, isTrue);

      const studentProfile = UserProfile(
        userId: 'student-1',
        alias: 'Estudiante Normal',
        role: 'student',
      );
      expect(studentProfile.isAdmin, isFalse);
      expect(studentProfile.isModerator, isFalse);
    });

    test('isCarneVerified soporta clave estándar e_is_verified legacy', () {
      final standardMap = {
        'user_id': 'u-std',
        'alias': 'Estudiante Estándar',
        'is_carne_verified': true,
      };
      final pStandard = UserProfile.fromMap(standardMap);
      expect(pStandard.isCarneVerified, isTrue);

      final legacyMap = {
        'user_id': 'u-leg',
        'alias': 'Estudiante Legacy',
        'is_verified': true,
      };
      final pLegacy = UserProfile.fromMap(legacyMap);
      expect(pLegacy.isCarneVerified, isTrue);

      final unverifiedMap = {
        'user_id': 'u-unv',
        'alias': 'Estudiante No Verificado',
      };
      final pUnverified = UserProfile.fromMap(unverifiedMap);
      expect(pUnverified.isCarneVerified, isFalse);
    });

    test('Serialización y deserialización toMap y fromMap', () {
      const original = UserProfile(
        userId: 'uid-456',
        alias: 'Tricentenario #802',
        role: 'moderator',
        facultadId: '03',
        carreraId: '03-00-01',
        sedeId: 'cum',
        bio: 'Estudiante de Auditoría en el CUM',
        avatarColorIndex: 2,
        avatarIconIndex: 4,
        contactWhatsapp: '50212345678',
        contactTelegram: 'trice802',
        contactInstagram: 'trice_usac',
        email: 'estudiante@usac.edu.gt',
        carne: '202012345',
        studentName: 'Juan Pérez',
        isCarneVerified: true,
      );

      final map = original.toMap();
      expect(map['user_id'], 'uid-456');
      expect(map['alias'], 'Tricentenario #802');
      expect(map['role'], 'moderator');
      expect(map['carne'], '202012345');
      expect(map['student_name'], 'Juan Pérez');
      expect(map['is_carne_verified'], isTrue);

      final fromMap = UserProfile.fromMap(map);
      expect(fromMap.userId, original.userId);
      expect(fromMap.alias, original.alias);
      expect(fromMap.carne, original.carne);
      expect(fromMap.studentName, original.studentName);
      expect(fromMap.isCarneVerified, isTrue);
      expect(fromMap.isModerator, isTrue);
    });

    test('Método copyWith actualiza campos manteniendo inmutabilidad', () {
      const baseProfile = UserProfile(
        userId: 'uid-789',
        alias: 'Estudiante #1',
        role: 'student',
      );

      final updated = baseProfile.copyWith(
        alias: 'Estudiante Actualizado',
        role: 'admin',
        isCarneVerified: true,
      );

      expect(updated.userId, 'uid-789');
      expect(updated.alias, 'Estudiante Actualizado');
      expect(updated.role, 'admin');
      expect(updated.isAdmin, isTrue);
      expect(updated.isCarneVerified, isTrue);
      expect(baseProfile.alias, 'Estudiante #1');
      expect(baseProfile.role, 'student');
      expect(baseProfile.isAdmin, isFalse);
    });
  });
}
