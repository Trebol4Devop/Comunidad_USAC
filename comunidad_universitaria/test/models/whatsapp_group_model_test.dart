import 'package:flutter_test/flutter_test.dart';
import 'package:comunidad_universitaria/core/models/whatsapp_group.dart';
import '../helpers/fixtures.dart';

void main() {
  group('GroupPlatform & WhatsAppGroup Model', () {
    test('stringToPlatform resuelve plataforma según el campo explícito', () {
      expect(WhatsAppGroup.stringToPlatform('whatsapp', ''), GroupPlatform.whatsApp);
      expect(WhatsAppGroup.stringToPlatform('TELEGRAM', ''), GroupPlatform.telegram);
      expect(WhatsAppGroup.stringToPlatform('discord', ''), GroupPlatform.discord);
      expect(WhatsAppGroup.stringToPlatform('drive', ''), GroupPlatform.drive);
      expect(WhatsAppGroup.stringToPlatform('otro', ''), GroupPlatform.other);
    });

    test('stringToPlatform resuelve plataforma según la URL del enlace', () {
      expect(
        WhatsAppGroup.stringToPlatform(null, 'https://chat.whatsapp.com/invitacion123'),
        GroupPlatform.whatsApp,
      );
      expect(
        WhatsAppGroup.stringToPlatform('', 'https://wa.me/50212345678'),
        GroupPlatform.whatsApp,
      );
      expect(
        WhatsAppGroup.stringToPlatform(null, 'https://t.me/estudiantes_usac'),
        GroupPlatform.telegram,
      );
      expect(
        WhatsAppGroup.stringToPlatform(null, 'https://telegram.me/grupo_usac'),
        GroupPlatform.telegram,
      );
      expect(
        WhatsAppGroup.stringToPlatform(null, 'https://discord.gg/invitacion'),
        GroupPlatform.discord,
      );
      expect(
        WhatsAppGroup.stringToPlatform(null, 'https://discord.com/invite/servidor'),
        GroupPlatform.discord,
      );
      expect(
        WhatsAppGroup.stringToPlatform(null, 'https://drive.google.com/drive/folders/xyz'),
        GroupPlatform.drive,
      );
      expect(
        WhatsAppGroup.stringToPlatform(null, 'https://docs.google.com/document/d/xyz'),
        GroupPlatform.drive,
      );
      expect(
        WhatsAppGroup.stringToPlatform(null, 'https://facebook.com/groups/usac'),
        GroupPlatform.other,
      );
    });

    test('platformToString convierte GroupPlatform al string esperado en la base de datos', () {
      expect(WhatsAppGroup.platformToString(GroupPlatform.whatsApp), 'whatsapp');
      expect(WhatsAppGroup.platformToString(GroupPlatform.telegram), 'telegram');
      expect(WhatsAppGroup.platformToString(GroupPlatform.discord), 'discord');
      expect(WhatsAppGroup.platformToString(GroupPlatform.drive), 'drive');
      expect(WhatsAppGroup.platformToString(GroupPlatform.other), 'otro');
    });

    test('WhatsAppGroup.fromMap valores por defecto y parseo de tipos flexibles', () {
      final map = {
        'id': 'g-1',
        'title': 'Física 1',
        'curso': 'Física 1',
        'link': 'https://chat.whatsapp.com/demo',
        'description': 'Grupo para laboratorio',
        'upvotes': '8',
        'reported_count': '1',
        'moderation_status': '0',
      };

      final group = WhatsAppGroup.fromMap(map, isUpvotedByMe: true);
      expect(group.id, 'g-1');
      expect(group.carrera, 'todas');
      expect(group.section, 'Sección Única');
      expect(group.authorAlias, 'Estudiante USAC');
      expect(group.upvotes, 8);
      expect(group.reportedCount, 1);
      expect(group.moderationStatus, 0);
      expect(group.isUpvotedByMe, isTrue);
      expect(group.platform, GroupPlatform.whatsApp);
    });

    test('WhatsAppGroup toInsertMap y copyWith funcionan correctamente', () {
      final group = TestFixtures.whatsAppGroup(
        id: 'g-99',
        title: 'Álgebra Lineal Grupo',
        link: 'https://discord.gg/algebra',
        section: 'Sección B',
        upvotes: 4,
        moderationStatus: 0,
      );

      final insertMap = group.toInsertMap();
      expect(insertMap['title'], 'Álgebra Lineal Grupo');
      expect(insertMap['section'], 'Sección B');
      expect(insertMap['link'], 'https://discord.gg/algebra');
      expect(insertMap['platform'], 'discord');
      expect(insertMap['upvotes'], 4);

      final updated = group.copyWith(
        title: 'Álgebra Lineal - Secc B',
        upvotes: 5,
        isUpvotedByMe: true,
      );
      expect(updated.title, 'Álgebra Lineal - Secc B');
      expect(updated.upvotes, 5);
      expect(updated.isUpvotedByMe, isTrue);
      expect(group.title, 'Álgebra Lineal Grupo');
    });
  });
}
