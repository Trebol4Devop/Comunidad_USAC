import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:comunidad_universitaria/core/config/supabase_config.dart';
import 'package:comunidad_universitaria/core/services/forum_service.dart';
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
    SupabaseService.debugUserId = 'test-user-id';
  });

  tearDown(() async {
    await resetTestState();
  });

  group('ForumService.createPost', () {
    test('crea post con trim, nulls en imágenes vacías y sin encuesta', () async {
      Map<String, dynamic>? insertedPost;

      fakeServer.onPost('/rest/v1/posts', (req) {
        insertedPost = jsonDecode(req.body) as Map<String, dynamic>;
        return {
          ...insertedPost!,
          'id': 'created-post-1',
          'created_at': DateTime.now().toIso8601String(),
        };
      });

      final result = await ForumService.createPost(
        title: '  Título con espacios  ',
        content: '  Contenido con espacios  ',
        category: 'general',
        carrera: 'sistemas',
        authorAlias: '  Estudiante Usac  ',
        imageUrl: '   ',
        gifUrl: '',
      );

      expect(result, isNotNull);
      expect(result!.id, 'created-post-1');
      expect(result.title, 'Título con espacios');
      expect(result.content, 'Contenido con espacios');
      expect(result.authorAlias, 'Estudiante Usac');
      expect(result.imageUrl, isNull);
      expect(result.gifUrl, isNull);

      expect(insertedPost, isNotNull);
      expect(insertedPost!['title'], 'Título con espacios');
      expect(insertedPost!['content'], 'Contenido con espacios');
      expect(insertedPost!['author_alias'], 'Estudiante Usac');
      expect(insertedPost!['image_url'], isNull);
      expect(insertedPost!['gif_url'], isNull);
      expect(insertedPost!['user_id'], 'test-user-id');
    });

    test('crea encuesta adjunta cuando hay pregunta y >= 2 opciones no vacías', () async {
      Map<String, dynamic>? insertedPoll;
      List<dynamic>? insertedOptions;

      fakeServer.onPost('/rest/v1/posts', (req) {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        return {
          ...body,
          'id': 'post-with-poll',
          'created_at': DateTime.now().toIso8601String(),
        };
      });

      fakeServer.onPost('/rest/v1/post_polls', (req) {
        insertedPoll = jsonDecode(req.body) as Map<String, dynamic>;
        return {
          ...insertedPoll!,
          'id': 'poll-created-1',
        };
      });

      fakeServer.onPost('/rest/v1/post_poll_options', (req) {
        insertedOptions = jsonDecode(req.body) as List<dynamic>;
        return insertedOptions!;
      });

      final result = await ForumService.createPost(
        title: '¿Cuál catedrático prefieren?',
        content: 'Para la clase de Estructuras',
        category: 'catedraticos',
        carrera: 'sistemas',
        authorAlias: 'Encuestador',
        pollQuestion: '  ¿Catedrático favorito?  ',
        pollOptions: ['  Ing. López  ', '   ', 'Ing. Pérez  '],
      );

      expect(result, isNotNull);
      expect(result!.id, 'post-with-poll');

      expect(insertedPoll, isNotNull);
      expect(insertedPoll!['post_id'], 'post-with-poll');
      expect(insertedPoll!['question'], '¿Catedrático favorito?');

      expect(insertedOptions, isNotNull);
      expect(insertedOptions!.length, 2);
      expect(insertedOptions![0]['option_text'], 'Ing. López');
      expect(insertedOptions![1]['option_text'], 'Ing. Pérez');
    });
  });

  group('ForumService.addComment', () {
    test('agrega comentario con trim, parent_id y gif procesados', () async {
      Map<String, dynamic>? insertedComment;

      fakeServer.onPost('/rest/v1/comments', (req) {
        insertedComment = jsonDecode(req.body) as Map<String, dynamic>;
        return {
          ...insertedComment!,
          'id': 'new-comment-99',
          'created_at': DateTime.now().toIso8601String(),
        };
      });

      final result = await ForumService.addComment(
        postId: 'post-1',
        content: '  Respuesta detallada  ',
        authorAlias: '  Compañero  ',
        parentId: 'parent-123',
        gifUrl: '  https://giphy.com/sample.gif  ',
      );

      expect(result, isNotNull);
      expect(result!.id, 'new-comment-99');
      expect(result.content, 'Respuesta detallada');
      expect(result.authorAlias, 'Compañero');
      expect(result.parentId, 'parent-123');
      expect(result.gifUrl, 'https://giphy.com/sample.gif');

      expect(insertedComment!['parent_id'], 'parent-123');
      expect(insertedComment!['gif_url'], 'https://giphy.com/sample.gif');
    });
  });

  group('ForumService.toggleLike & toggleBookmark', () {
    test('toggleLike sin sesión devuelve el estado original del post', () async {
      SupabaseService.debugUserId = null;
      final post = TestFixtures.post(id: 'p-1', isLikedByMe: true);
      final res = await ForumService.toggleLike(post);
      expect(res, isTrue);
    });

    test('toggleLike inserta si no estaba likeado y devuelve true', () async {
      bool inserted = false;
      fakeServer.onPost('/rest/v1/post_likes', (req) {
        inserted = true;
        return [];
      });

      final post = TestFixtures.post(id: 'p-1', isLikedByMe: false);
      final res = await ForumService.toggleLike(post);

      expect(res, isTrue);
      expect(inserted, isTrue);
    });

    test('toggleLike elimina si ya estaba likeado y devuelve false', () async {
      bool deleted = false;
      fakeServer.onDelete('/rest/v1/post_likes', (req) {
        deleted = true;
        return [];
      });

      final post = TestFixtures.post(id: 'p-1', isLikedByMe: true);
      final res = await ForumService.toggleLike(post);

      expect(res, isFalse);
      expect(deleted, isTrue);
    });

    test('toggleBookmark inserta y elimina según estado previo', () async {
      bool inserted = false;
      bool deleted = false;

      fakeServer.onPost('/rest/v1/post_bookmarks', (req) {
        inserted = true;
        return [];
      });
      fakeServer.onDelete('/rest/v1/post_bookmarks', (req) {
        deleted = true;
        return [];
      });

      // 1. Guardar bookmark
      final notBookmarked = TestFixtures.post(id: 'p-2', isBookmarkedByMe: false);
      final res1 = await ForumService.toggleBookmark(notBookmarked);
      expect(res1, isTrue);
      expect(inserted, isTrue);

      // 2. Quitar bookmark
      final bookmarked = TestFixtures.post(id: 'p-2', isBookmarkedByMe: true);
      final res2 = await ForumService.toggleBookmark(bookmarked);
      expect(res2, isFalse);
      expect(deleted, isTrue);
    });
  });

  group('ForumService.votePoll', () {
    test('votePoll elimina voto previo e inserta nuevo voto', () async {
      bool deletedOld = false;
      bool insertedNew = false;

      fakeServer.onDelete('/rest/v1/post_poll_votes', (req) {
        deletedOld = true;
        return [];
      });
      fakeServer.onPost('/rest/v1/post_poll_votes', (req) {
        insertedNew = true;
        return [];
      });

      final res = await ForumService.votePoll(
        pollId: 'poll-1',
        optionId: 'opt-2',
      );

      expect(res, isTrue);
      expect(deletedOld, isTrue);
      expect(insertedNew, isTrue);
    });
  });

  group('ForumService.reportPost, reportComment, reportUser', () {
    test('reportPost llama a RPC report_forum_post', () async {
      fakeServer.onPost('/rest/v1/rpc/report_forum_post', (req) => true);

      final res = await ForumService.reportPost(
        postId: 'post-1',
        reason: 'spam',
        details: 'Venta no autorizada',
      );
      expect(res, isTrue);
    });

    test('reportComment llama a RPC report_forum_comment', () async {
      fakeServer.onPost('/rest/v1/rpc/report_forum_comment', (req) => true);

      final res = await ForumService.reportComment(
        commentId: 'comment-1',
        reason: 'ofensivo',
      );
      expect(res, isTrue);
    });

    test('reportUser inserta reporte en entity_reports', () async {
      Map<String, dynamic>? reportInserted;
      fakeServer.onPost('/rest/v1/entity_reports', (req) {
        reportInserted = jsonDecode(req.body) as Map<String, dynamic>;
        return [];
      });

      final res = await ForumService.reportUser(
        reportedUserId: 'target-u',
        reportedAlias: 'Usuario Tóxico',
        reason: 'acoso',
      );

      expect(res, isTrue);
      expect(reportInserted, isNotNull);
      expect(reportInserted!['entity_type'], 'user');
      expect(reportInserted!['reported_user_id'], 'target-u');
      expect(reportInserted!['reason'], 'acoso');
    });
  });

  group('ForumService.fetchCommentsTree', () {
    test('construye árbol anidado, maneja huérfanos a raíz y previene ciclos', () async {
      // Comentarios de prueba:
      // c1: raíz
      // c2: hijo de c1
      // c3: hijo de c2
      // c4: huérfano (parentId 'c-inexistente') -> debe ir a raíz
      // c5 y c6: ciclo mutuo (c5.parentId = c6, c6.parentId = c5) -> detecta ciclo y envía c6 a raíz
      fakeServer.onGet('/rest/v1/v_public_comments', (req) {
        return [
          {
            'id': 'c1',
            'post_id': 'post-1',
            'content': 'Comentario raíz',
            'parent_id': null,
            'created_at': '2026-03-01T10:00:00.000Z',
          },
          {
            'id': 'c2',
            'post_id': 'post-1',
            'content': 'Respuesta a c1',
            'parent_id': 'c1',
            'created_at': '2026-03-01T10:05:00.000Z',
          },
          {
            'id': 'c3',
            'post_id': 'post-1',
            'content': 'Respuesta a c2',
            'parent_id': 'c2',
            'created_at': '2026-03-01T10:10:00.000Z',
          },
          {
            'id': 'c4',
            'post_id': 'post-1',
            'content': 'Comentario huérfano',
            'parent_id': 'c-no-existe',
            'created_at': '2026-03-01T10:15:00.000Z',
          },
          {
            'id': 'c5',
            'post_id': 'post-1',
            'content': 'Ciclo 1',
            'parent_id': 'c6',
            'created_at': '2026-03-01T10:20:00.000Z',
          },
          {
            'id': 'c6',
            'post_id': 'post-1',
            'content': 'Ciclo 2',
            'parent_id': 'c5',
            'created_at': '2026-03-01T10:25:00.000Z',
          },
        ];
      });

      final tree = await ForumService.fetchCommentsTree('post-1');

      // Las raíces deben incluir c1, c4 (huérfano) y al menos uno de c5/c6 por ruptura de ciclo
      final rootIds = tree.map((c) => c.id).toList();
      expect(rootIds, contains('c1'));
      expect(rootIds, contains('c4'));

      // c1 tiene hijo c2
      final c1 = tree.firstWhere((c) => c.id == 'c1');
      expect(c1.children.length, 1);
      expect(c1.children.first.id, 'c2');

      // c2 tiene hijo c3
      final c2 = c1.children.first;
      expect(c2.children.length, 1);
      expect(c2.children.first.id, 'c3');

      // No hay loops infinitos y la función finalizó con éxito
      expect(tree, isNotEmpty);
    });
  });
}
