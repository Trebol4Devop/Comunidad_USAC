import 'package:flutter_test/flutter_test.dart';
import 'package:comunidad_universitaria/core/models/post.dart';
import '../helpers/fixtures.dart';

void main() {
  group('PollOption Model', () {
    test('PollOption.fromMap parsea int y string para votes_count', () {
      final opt1 = PollOption.fromMap({
        'id': 'opt-1',
        'poll_id': 'poll-1',
        'option_text': 'Primera opción',
        'votes_count': 15,
      });
      expect(opt1.id, 'opt-1');
      expect(opt1.pollId, 'poll-1');
      expect(opt1.optionText, 'Primera opción');
      expect(opt1.votesCount, 15);

      final opt2 = PollOption.fromMap({
        'id': 'opt-2',
        'poll_id': 'poll-1',
        'option_text': 'Segunda opción',
        'votes_count': '25',
      });
      expect(opt2.votesCount, 25);

      final optDefault = PollOption.fromMap({});
      expect(optDefault.id, '');
      expect(optDefault.pollId, '');
      expect(optDefault.optionText, '');
      expect(optDefault.votesCount, 0);
    });

    test('PollOption.toMap serializa correctamente', () {
      final opt = PollOption(
        id: 'opt-x',
        pollId: 'poll-x',
        optionText: 'Texto',
        votesCount: 7,
      );
      final map = opt.toMap();
      expect(map['id'], 'opt-x');
      expect(map['poll_id'], 'poll-x');
      expect(map['option_text'], 'Texto');
      expect(map['votes_count'], 7);
    });
  });

  group('PostPoll Model', () {
    test('PostPoll.totalVotes suma votos de todas las opciones', () {
      final poll = TestFixtures.postPoll(
        options: [
          TestFixtures.pollOption(id: '1', votesCount: 10),
          TestFixtures.pollOption(id: '2', votesCount: 25),
          TestFixtures.pollOption(id: '3', votesCount: 5),
        ],
      );
      expect(poll.totalVotes, 40);
    });

    test('PostPoll.fromMap y copyWith funcionan correctamente', () {
      final raw = {
        'id': 'poll-10',
        'post_id': 'post-10',
        'question': '¿Qué opinás?',
        'options': [
          {'id': 'o1', 'poll_id': 'poll-10', 'option_text': 'Bien', 'votes_count': 3},
          {'id': 'o2', 'poll_id': 'poll-10', 'option_text': 'Mal', 'votes_count': 1},
        ],
      };

      final poll = PostPoll.fromMap(raw, myVotedOptionId: 'o1');
      expect(poll.id, 'poll-10');
      expect(poll.postId, 'post-10');
      expect(poll.question, '¿Qué opinás?');
      expect(poll.options.length, 2);
      expect(poll.myVotedOptionId, 'o1');

      final copy = poll.copyWith(myVotedOptionId: 'o2', question: 'Nueva pregunta');
      expect(copy.myVotedOptionId, 'o2');
      expect(copy.question, 'Nueva pregunta');
      expect(copy.id, poll.id);
    });
  });

  group('PostComment Model', () {
    test('PostComment.fromMap limpia parent_id y user_id ("null", vacío o ausente -> null)', () {
      final mapNullStr = {
        'id': 'c-1',
        'post_id': 'p-1',
        'content': 'Comentario de prueba',
        'parent_id': 'null',
        'user_id': 'null',
      };
      final comment1 = PostComment.fromMap(mapNullStr);
      expect(comment1.parentId, isNull);
      expect(comment1.userId, isNull);

      final mapEmptyStr = {
        'id': 'c-2',
        'post_id': 'p-1',
        'content': 'Comentario de prueba 2',
        'parent_id': '   ',
        'user_id': '',
      };
      final comment2 = PostComment.fromMap(mapEmptyStr);
      expect(comment2.parentId, isNull);
      expect(comment2.userId, isNull);

      final mapMissing = {
        'id': 'c-3',
        'post_id': 'p-1',
        'content': 'Comentario con ids válidos',
        'parent_id': 'c-parent',
        'user_id': 'user-123',
      };
      final comment3 = PostComment.fromMap(mapMissing);
      expect(comment3.parentId, 'c-parent');
      expect(comment3.userId, 'user-123');
    });

    test('PostComment.fromMap parsea flags is_post_author y is_my_comment', () {
      final comment = PostComment.fromMap({
        'id': 'c-10',
        'post_id': 'p-1',
        'content': 'Hola',
        'is_post_author': true,
        'is_my_comment': true,
        'moderation_status': '1',
      });
      expect(comment.isPostAuthor, isTrue);
      expect(comment.isMyComment, isTrue);
      expect(comment.moderationStatus, 1);
    });

    test('PostComment.toInsertMap genera mapa correcto', () {
      final comment = PostComment(
        id: 'c-1',
        postId: 'p-1',
        authorAlias: 'Carlos',
        content: 'Excelente aporte',
        userId: 'u-1',
        parentId: 'p-root',
        gifUrl: 'https://example.com/dance.gif',
        createdAt: DateTime.now(),
        moderationStatus: 0,
      );

      final map = comment.toInsertMap();
      expect(map['post_id'], 'p-1');
      expect(map['author_alias'], 'Carlos');
      expect(map['content'], 'Excelente aporte');
      expect(map['user_id'], 'u-1');
      expect(map['parent_id'], 'p-root');
      expect(map['gif_url'], 'https://example.com/dance.gif');
      expect(map['moderation_status'], 0);
    });
  });

  group('Post Model', () {
    test('Post.fromMap valores por defecto y parseo de tipos flexibles', () {
      final minimalMap = {
        'id': 'post-1',
        'title': 'Título mínimo',
        'content': 'Contenido mínimo',
        'likes': '12',
        'moderation_status': '0',
        'reposts_count': '3',
      };

      final post = Post.fromMap(minimalMap);
      expect(post.id, 'post-1');
      expect(post.title, 'Título mínimo');
      expect(post.content, 'Contenido mínimo');
      expect(post.category, 'general');
      expect(post.authorAlias, 'Estudiante USAC');
      expect(post.carrera, 'todas');
      expect(post.likes, 12);
      expect(post.moderationStatus, 0);
      expect(post.repostsCount, 3);
      expect(post.isPinned, isFalse);
      expect(post.isLikedByMe, isFalse);
      expect(post.isBookmarkedByMe, isFalse);
      expect(post.isMyPost, isFalse);
      expect(post.commentCount, 0);
    });

    test('Post.fromMap parsea comment_count como int y como string', () {
      final p1 = Post.fromMap({'id': '1', 'title': 'T', 'content': 'C', 'comment_count': 5});
      expect(p1.commentCount, 5);

      final p2 = Post.fromMap({'id': '2', 'title': 'T', 'content': 'C', 'comment_count': '8'});
      expect(p2.commentCount, 8);
    });

    test('Post.toInsertMap incluye campos esperados', () {
      final post = TestFixtures.post(
        id: 'post-99',
        title: 'Guía de estudio',
        category: 'apuntes',
        content: 'Comparto resumen del primer parcial',
        authorAlias: 'Tutor Mate',
        userId: 'user-77',
        carrera: 'civil',
        imageUrl: 'https://example.com/mate.png',
        gifUrl: null,
        quotedPostId: 'post-1',
        isPinned: true,
        likes: 10,
        moderationStatus: 0,
      );

      final map = post.toInsertMap();
      expect(map['title'], 'Guía de estudio');
      expect(map['category'], 'apuntes');
      expect(map['content'], 'Comparto resumen del primer parcial');
      expect(map['author_alias'], 'Tutor Mate');
      expect(map['user_id'], 'user-77');
      expect(map['carrera'], 'civil');
      expect(map['image_url'], 'https://example.com/mate.png');
      expect(map['gif_url'], isNull);
      expect(map['quoted_post_id'], 'post-1');
      expect(map['is_pinned'], isTrue);
      expect(map['likes'], 10);
      expect(map['moderation_status'], 0);
    });

    test('Post.copyWith actualiza campos preservando inmutabilidad', () {
      final original = TestFixtures.post(id: 'orig-1', likes: 2);
      final updated = original.copyWith(
        title: 'Nuevo título',
        likes: 3,
        isLikedByMe: true,
        isBookmarkedByMe: true,
      );

      expect(updated.id, original.id);
      expect(updated.title, 'Nuevo título');
      expect(updated.likes, 3);
      expect(updated.isLikedByMe, isTrue);
      expect(updated.isBookmarkedByMe, isTrue);
      expect(original.title, isNot('Nuevo título'));
      expect(original.likes, 2);
    });
  });
}
