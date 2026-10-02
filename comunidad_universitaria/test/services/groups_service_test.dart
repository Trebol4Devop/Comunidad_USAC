import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:comunidad_universitaria/core/config/supabase_config.dart';
import 'package:comunidad_universitaria/core/models/whatsapp_group.dart';
import 'package:comunidad_universitaria/core/services/groups_service.dart';
import 'package:comunidad_universitaria/core/services/supabase_service.dart';
import '../helpers/fake_postgrest.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_setup.dart';

void main() {
  late FakePostgrestServer fakeServer;

  setUp(() async {
    await resetTestState();
    fakeServer = FakePostgrestServer();
    SupabaseConfig.debugOverrideConfigured = true;
    SupabaseService.debugClient = fakeServer.buildClient();
    SupabaseService.debugUserId = 'group-creator-id';
  });

  tearDown(() async {
    await resetTestState();
  });

  group('GroupsService.createGroup', () {
    test('crea grupo con sección default "Sección Única", plataforma por link, upvotes=1 y auto-upvote', () async {
      Map<String, dynamic>? insertedGroup;
      Map<String, dynamic>? insertedUpvote;

      fakeServer.onPost('/rest/v1/student_groups', (req) {
        insertedGroup = jsonDecode(req.body) as Map<String, dynamic>;
        return {
          ...insertedGroup!,
          'id': 'new-group-10',
          'created_at': DateTime.now().toIso8601String(),
        };
      });

      fakeServer.onPost('/rest/v1/student_group_upvotes', (req) {
        insertedUpvote = jsonDecode(req.body) as Map<String, dynamic>;
        return [];
      });

      final created = await GroupsService.createGroup(
        title: '  Matemática Intermedia 1  ',
        carrera: 'sistemas',
        curso: '  Matemática Intermedia 1  ',
        section: '   ', // Vacía -> debe asignar 'Sección Única'
        link: 'https://t.me/mate_intermedia1',
        description: 'Grupo de estudio',
        authorAlias: 'Auxiliar',
      );

      expect(created, isNotNull);
      expect(created!.id, 'new-group-10');
      expect(created.section, 'Sección Única');
      expect(created.platform, GroupPlatform.telegram);
      expect(created.upvotes, 1);
      expect(created.isUpvotedByMe, isTrue);

      expect(insertedGroup, isNotNull);
      expect(insertedGroup!['section'], 'Sección Única');
      expect(insertedGroup!['platform'], 'telegram');
      expect(insertedGroup!['upvotes'], 1);

      expect(insertedUpvote, isNotNull);
      expect(insertedUpvote!['group_id'], 'new-group-10');
      expect(insertedUpvote!['user_id'], 'group-creator-id');
    });
  });

  group('GroupsService.toggleUpvote', () {
    test('sin sesión devuelve el estado previo sin llamar a la red', () async {
      SupabaseService.debugUserId = null;
      final group = TestFixtures.whatsAppGroup(id: 'g-1', isUpvotedByMe: true);
      final res = await GroupsService.toggleUpvote(group);
      expect(res, isTrue);
    });

    test('agrega upvote si no estaba upvoteado', () async {
      bool inserted = false;
      fakeServer.onPost('/rest/v1/student_group_upvotes', (req) {
        inserted = true;
        return [];
      });

      final group = TestFixtures.whatsAppGroup(id: 'g-1', isUpvotedByMe: false);
      final res = await GroupsService.toggleUpvote(group);

      expect(res, isTrue);
      expect(inserted, isTrue);
    });

    test('remueve upvote si ya estaba upvoteado', () async {
      bool deleted = false;
      fakeServer.onDelete('/rest/v1/student_group_upvotes', (req) {
        deleted = true;
        return [];
      });

      final group = TestFixtures.whatsAppGroup(id: 'g-1', isUpvotedByMe: true);
      final res = await GroupsService.toggleUpvote(group);

      expect(res, isFalse);
      expect(deleted, isTrue);
    });
  });

  group('GroupsService.reportGroup', () {
    test('inserta reporte en entity_reports con entity_type "group"', () async {
      Map<String, dynamic>? reportData;
      fakeServer.onPost('/rest/v1/entity_reports', (req) {
        reportData = jsonDecode(req.body) as Map<String, dynamic>;
        return [];
      });

      final res = await GroupsService.reportGroup(
        groupId: 'g-bad',
        reason: 'Enlace roto o fraudulento',
      );

      expect(res, isTrue);
      expect(reportData, isNotNull);
      expect(reportData!['entity_type'], 'group');
      expect(reportData!['entity_id'], 'g-bad');
      expect(reportData!['reason'], 'Enlace roto o fraudulento');
      expect(reportData!['reporter_id'], 'group-creator-id');
    });
  });
}
