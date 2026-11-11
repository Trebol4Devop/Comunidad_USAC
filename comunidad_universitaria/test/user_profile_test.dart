import 'package:flutter_test/flutter_test.dart';
import 'package:comunidad_universitaria/core/models/user_profile.dart';

void main() {
  group('UserProfile Model & Operations', () {
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
    });

    test('Serialización y deserialización toMap y fromMap', () {
      final original = const UserProfile(
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
      );

      final map = original.toMap();
      expect(map['user_id'], 'uid-456');
      expect(map['alias'], 'Tricentenario #802');
      expect(map['role'], 'moderator');
      expect(map['facultad_id'], '03');
      expect(map['carrera_id'], '03-00-01');
      expect(map['contact_whatsapp'], '50212345678');

      final fromMap = UserProfile.fromMap(map);
      expect(fromMap.userId, original.userId);
      expect(fromMap.alias, original.alias);
      expect(fromMap.role, original.role);
      expect(fromMap.facultadId, original.facultadId);
      expect(fromMap.carreraId, original.carreraId);
      expect(fromMap.sedeId, original.sedeId);
      expect(fromMap.bio, original.bio);
      expect(fromMap.avatarColorIndex, original.avatarColorIndex);
      expect(fromMap.avatarIconIndex, original.avatarIconIndex);
      expect(fromMap.contactWhatsapp, original.contactWhatsapp);
      expect(fromMap.contactTelegram, original.contactTelegram);
      expect(fromMap.contactInstagram, original.contactInstagram);
      expect(fromMap.email, original.email);
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
        bio: 'Nueva bio',
        contactWhatsapp: '50299998888',
      );

      expect(updated.userId, 'uid-789');
      expect(updated.alias, 'Estudiante Actualizado');
      expect(updated.bio, 'Nueva bio');
      expect(updated.contactWhatsapp, '50299998888');
      expect(baseProfile.alias, 'Estudiante #1');
    });

    test('Validación de roles isAdmin e isModerator', () {
      const admin = UserProfile(
        userId: 'admin-id',
        alias: 'Super Admin',
        role: 'admin',
      );
      expect(admin.isAdmin, isTrue);
      expect(admin.isModerator, isTrue);

      const mod = UserProfile(
        userId: 'mod-id',
        alias: 'Mod General',
        role: 'moderator',
      );
      expect(mod.isAdmin, isFalse);
      expect(mod.isModerator, isTrue);

      const student = UserProfile(
        userId: 'student-id',
        alias: 'Estudiante',
        role: 'student',
      );
      expect(student.isAdmin, isFalse);
      expect(student.isModerator, isFalse);
    });

    test('isCarneVerified soporta tanto is_carne_verified como la clave legacy is_verified', () {
      final p1 = UserProfile.fromMap({
        'user_id': 'u1',
        'is_carne_verified': true,
      });
      expect(p1.isCarneVerified, isTrue);

      final p2 = UserProfile.fromMap({
        'user_id': 'u2',
        'is_verified': true,
      });
      expect(p2.isCarneVerified, isTrue);

      final p3 = UserProfile.fromMap({
        'user_id': 'u3',
      });
      expect(p3.isCarneVerified, isFalse);
    });
  });
}
