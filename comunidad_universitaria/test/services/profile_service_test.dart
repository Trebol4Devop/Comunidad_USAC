import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:comunidad_universitaria/core/config/supabase_config.dart';
import 'package:comunidad_universitaria/core/services/profile_service.dart';
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
    SupabaseService.debugUserId = 'profile-user-id';
  });

  tearDown(() async {
    await resetTestState();
  });

  group('ProfileService Deletions', () {
    test('deletePost maneja éxito y error', () async {
      fakeServer.onGet('/rest/v1/posts', (req) => {'is_legal_hold': false});
      fakeServer.onPatch('/rest/v1/posts', (req) => []);
      final success = await ProfileService.deletePost('post-10');
      expect(success, isTrue);

      // Simular error HTTP 500
      fakeServer.onPatch('/rest/v1/posts', (req) {
        return http.Response(
          '{"message":"Error interno"}',
          500,
          headers: {'content-type': 'application/json'},
        );
      });
      final failure = await ProfileService.deletePost('post-error');
      expect(failure, isFalse);
    });

    test('deletePost rechaza borrado si is_legal_hold es true', () async {
      var patchCalled = false;
      fakeServer.onGet('/rest/v1/posts', (req) => {'is_legal_hold': true});
      fakeServer.onPatch('/rest/v1/posts', (req) {
        patchCalled = true;
        return [];
      });
      final result = await ProfileService.deletePost('post-held');
      expect(result, isFalse);
      expect(patchCalled, isFalse);
    });

    test('deleteGroup maneja éxito y error', () async {
      fakeServer.onGet('/rest/v1/student_groups', (req) => {'is_legal_hold': false});
      fakeServer.onPatch('/rest/v1/student_groups', (req) => []);
      final success = await ProfileService.deleteGroup('group-10');
      expect(success, isTrue);

      fakeServer.onPatch('/rest/v1/student_groups', (req) {
        return http.Response(
          '{"message":"Permiso denegado"}',
          403,
          headers: {'content-type': 'application/json'},
        );
      });
      final failure = await ProfileService.deleteGroup('group-error');
      expect(failure, isFalse);
    });

    test('deleteGroup rechaza borrado si is_legal_hold es true', () async {
      var patchCalled = false;
      fakeServer.onGet('/rest/v1/student_groups', (req) => {'is_legal_hold': true});
      fakeServer.onPatch('/rest/v1/student_groups', (req) {
        patchCalled = true;
        return [];
      });
      final result = await ProfileService.deleteGroup('group-held');
      expect(result, isFalse);
      expect(patchCalled, isFalse);
    });

    test('deleteMarketplaceItem maneja éxito y error', () async {
      fakeServer.onGet('/rest/v1/marketplace_items', (req) => {'is_legal_hold': false});
      fakeServer.onPatch('/rest/v1/marketplace_items', (req) => []);
      final success = await ProfileService.deleteMarketplaceItem('item-10');
      expect(success, isTrue);

      fakeServer.onPatch('/rest/v1/marketplace_items', (req) {
        return http.Response(
          '{"message":"No encontrado"}',
          404,
          headers: {'content-type': 'application/json'},
        );
      });
      final failure = await ProfileService.deleteMarketplaceItem('item-error');
      expect(failure, isFalse);
    });

    test('deleteMarketplaceItem rechaza borrado si is_legal_hold es true', () async {
      var patchCalled = false;
      fakeServer.onGet('/rest/v1/marketplace_items', (req) => {'is_legal_hold': true});
      fakeServer.onPatch('/rest/v1/marketplace_items', (req) {
        patchCalled = true;
        return [];
      });
      final result = await ProfileService.deleteMarketplaceItem('item-held');
      expect(result, isFalse);
      expect(patchCalled, isFalse);
    });
  });

  group('ProfileService.fetchUserPosts', () {
    test('obtiene publicaciones del usuario filtradas por alias', () async {
      fakeServer.onGet('/rest/v1/posts', (req) {
        expect(req.url.queryParameters['author_alias'], 'eq.Estudiante Destacado');
        return [
          TestFixtures.postMap(
            id: 'post-destacado-1',
            title: 'Mi publicación',
            authorAlias: 'Estudiante Destacado',
          ),
        ];
      });

      final posts = await ProfileService.fetchUserPosts(alias: 'Estudiante Destacado');
      expect(posts.length, 1);
      expect(posts.first.id, 'post-destacado-1');
      expect(posts.first.authorAlias, 'Estudiante Destacado');
    });
  });
}
