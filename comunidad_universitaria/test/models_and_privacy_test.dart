import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:comunidad_universitaria/core/constants/anonymous_aliases.dart';
import 'package:comunidad_universitaria/core/models/post.dart';
import 'package:comunidad_universitaria/core/models/seccion_review.dart';
import 'package:comunidad_universitaria/features/shared/widgets/anonymous_author_header.dart';

void main() {
  group('1. Modelos con payloads de vistas seguras (SIN user_id)', () {
    test('Post.fromMap deserializa campos seguros e ignora user_id', () {
      final payload = {
        'id': 'post-safe-001',
        'title': 'Consejos para el examen final',
        'category': 'academico',
        'content': 'Estudien con tiempo los árboles AVL.',
        'author_alias': 'Compilador Desvelado',
        'author_hash': 'a4f9b2c1',
        'user_id': '00000000-0000-0000-0000-000000000001', // No debe persistir en el modelo
        'comments_count': 14,
        'hot_score': 92.75,
        'expires_at': '2026-12-31T23:59:59.000Z',
        'is_mine': true,
        'is_legal_hold': true,
        'deleted_at': '2026-11-10T12:00:00.000Z',
        'likes': 25,
        'created_at': '2026-11-01T08:00:00.000Z',
      };

      final post = Post.fromMap(payload);

      expect(post.userId, isNull);
      expect(post.id, 'post-safe-001');
      expect(post.title, 'Consejos para el examen final');
      expect(post.category, 'academico');
      expect(post.content, 'Estudien con tiempo los árboles AVL.');
      expect(post.authorAlias, 'Compilador Desvelado');
      expect(post.authorHash, 'a4f9b2c1');
      expect(post.commentsCount, 14);
      expect(post.commentCount, 14); // Compatibility getter
      expect(post.hotScore, 92.75);
      expect(post.expiresAt, DateTime.parse('2026-12-31T23:59:59.000Z'));
      expect(post.isMine, isTrue);
      expect(post.isMyPost, isTrue); // Compatibility getter
      expect(post.isLegalHold, isTrue);
      expect(post.deletedAt, DateTime.parse('2026-11-10T12:00:00.000Z'));
      expect(post.likes, 25);
    });

    test('PostComment.fromMap deserializa campos seguros e ignora user_id', () {
      final payload = {
        'id': 'comment-safe-002',
        'post_id': 'post-safe-001',
        'author_alias': 'Recursivo Del Lab',
        'content': 'Totalmente de acuerdo, gracias.',
        'author_hash': 'b5e8c3d2',
        'user_id': '00000000-0000-0000-0000-000000000002', // No debe exponerse
        'is_op': true,
        'likes_count': 8,
        'is_mine': true,
        'deleted_at': '2026-11-10T14:30:00.000Z',
        'created_at': '2026-11-01T09:15:00.000Z',
      };

      final comment = PostComment.fromMap(payload);

      expect(comment.userId, isNull);
      expect(comment.id, 'comment-safe-002');
      expect(comment.postId, 'post-safe-001');
      expect(comment.authorAlias, 'Recursivo Del Lab');
      expect(comment.content, 'Totalmente de acuerdo, gracias.');
      expect(comment.authorHash, 'b5e8c3d2');
      expect(comment.isOp, isTrue);
      expect(comment.isPostAuthor, isTrue); // Compatibility getter
      expect(comment.likesCount, 8);
      expect(comment.isMine, isTrue);
      expect(comment.isMyComment, isTrue); // Compatibility getter
      expect(comment.deletedAt, DateTime.parse('2026-11-10T14:30:00.000Z'));
    });

    test('SeccionReview.fromMap deserializa campos de reseña e ignora user_id', () {
      final payload = {
        'id': 'review-safe-003',
        'curso_codigo': '0772',
        'seccion': 'A',
        'recomienda': true,
        'catedratico_nombre': 'Ing. Morales',
        'dificultad': 4,
        'carga_tareas': 3,
        'comentario': 'Catedrático exigente pero con contenido de alto valor.',
        'semestre': '1S-2026',
        'upvotes': 19,
        'is_mine': true,
        'user_id': '00000000-0000-0000-0000-000000000003', // No debe persistir
        'created_at': '2026-11-05T16:00:00.000Z',
      };

      final review = SeccionReview.fromMap(payload);

      expect(review.userId, isNull);
      expect(review.id, 'review-safe-003');
      expect(review.cursoCodigo, '0772');
      expect(review.seccion, 'A');
      expect(review.recomienda, isTrue);
      expect(review.catedraticoNombre, 'Ing. Morales');
      expect(review.dificultad, 4);
      expect(review.cargaTareas, 3);
      expect(review.comentario, 'Catedrático exigente pero con contenido de alto valor.');
      expect(review.semestre, '1S-2026');
      expect(review.upvotes, 19);
      expect(review.isMine, isTrue);
    });
  });

  group('2. Color determinista del author_hash', () {
    test('AnonymousAuthorHeader.colorForHash es idéntico en múltiples llamadas y difiere para otro hash', () {
      final colorA1 = AnonymousAuthorHeader.colorForHash('a4f9b2c1');
      final colorA2 = AnonymousAuthorHeader.colorForHash('a4f9b2c1');
      final colorB = AnonymousAuthorHeader.colorForHash('b5e8c3d2');
      final colorC = AnonymousAuthorHeader.colorForHash('f9b2c1a4');

      // Determinismo puro: dos llamadas con el mismo hash producen exactamente el mismo Color
      expect(colorA1, equals(colorA2));
      expect(colorA1.toARGB32(), equals(colorA2.toARGB32()));

      // Hashes distintos producen colores distintos
      expect(colorA1, isNot(equals(colorB)));
      expect(colorA1, isNot(equals(colorC)));

      // Hash vacío produce color de fallback seguro
      final fallbackColor = AnonymousAuthorHeader.colorForHash('');
      expect(fallbackColor, const Color(0xFF64748B));
    });
  });

  group('3. Badges OP, Tú y renderizado de authorHash', () {
    testWidgets('Renderizar AnonymousAuthorHeader con isOp: true muestra badge OP', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnonymousAuthorHeader(
              authorAlias: 'Compilador Desvelado',
              isOp: true,
            ),
          ),
        ),
      );

      expect(find.text('OP'), findsOneWidget);
    });

    testWidgets('Renderizar con isMine: true y onDelete muestra badge Tú e ícono de eliminación', (tester) async {
      var deleteCalled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnonymousAuthorHeader(
              authorAlias: 'Compilador Desvelado',
              isMine: true,
              onDelete: () {
                deleteCalled = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Tú'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline));
      expect(deleteCalled, isTrue);
    });

    testWidgets('Sin authorHash no se muestra ningún chip o texto que empiece con #', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnonymousAuthorHeader(
              authorAlias: 'Compilador Desvelado',
              authorHash: null,
            ),
          ),
        ),
      );

      final hashTexts = find.byWidgetPredicate(
        (widget) => widget is Text && (widget.data?.startsWith('#') ?? false),
      );
      expect(hashTexts, findsNothing);
    });

    testWidgets('Con authorHash sí se muestra el chip que empieza con #', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnonymousAuthorHeader(
              authorAlias: 'Compilador Desvelado',
              authorHash: 'a4f9b2c1',
            ),
          ),
        ),
      );

      expect(find.text('#a4f9b2'), findsOneWidget);
    });
  });

  group('4. Generador de alias cerrado', () {
    test('generate() nunca es vacío y siempre es válido según el catálogo cerrado', () {
      for (var i = 0; i < 50; i++) {
        final alias = AnonymousAliasGenerator.generate();
        expect(alias.trim(), isNotEmpty);
        expect(
          AnonymousAliasGenerator.isValid(alias),
          isTrue,
          reason: 'El alias generado "$alias" debe cumplir las reglas de catálogo cerrado',
        );
      }
    });

    test('isValid valida estrictamente contra nombres reales, correos y títulos', () {
      expect(AnonymousAliasGenerator.isValid('Juan Pérez'), isFalse);
      expect(AnonymousAliasGenerator.isValid('Ing. Juan'), isFalse);
      expect(AnonymousAliasGenerator.isValid('correo@x.com'), isFalse);
      expect(AnonymousAliasGenerator.isValid(''), isFalse);
      expect(AnonymousAliasGenerator.isValid('   '), isFalse);
      expect(AnonymousAliasGenerator.isValid('Compilador Desvelado'), isTrue);
    });

    test('El generador de alias no acepta entrada manual de texto (catálogo cerrado determinista)', () {
      // Verificamos que generate() es una función autocontenida que toma un generador pseudoaleatorio opcional
      // y no permite que un atacante inyecte nombres arbitrarios como parámetros de entrada.
      final seededRng = Random(42);
      final alias1 = AnonymousAliasGenerator.generate(seededRng);
      expect(alias1, isNotEmpty);
      expect(AnonymousAliasGenerator.isValid(alias1), isTrue);

      // No existe firma generate(String customName); sólo genera combinaciones válidas del catálogo.
      final aliasDefault = AnonymousAliasGenerator.generate();
      expect(AnonymousAliasGenerator.isValid(aliasDefault), isTrue);
    });
  });

  group('5. Separación entre escritura (toInsertMap) y lectura pública (fromMap)', () {
    test('Post.toInsertMap incluye user_id pero fromMap nunca lo lee', () {
      final post = Post(
        id: 'post-write-001',
        title: 'Post para crear',
        category: 'general',
        content: 'Contenido original',
        authorAlias: 'Compilador Desvelado',
        userId: 'auth-user-id-12345',
        likes: 0,
        createdAt: DateTime.now(),
      );

      final insertMap = post.toInsertMap();
      expect(insertMap['user_id'], 'auth-user-id-12345');

      // Al reconstruir desde fromMap (como al consumir un feed o vista pública),
      // el user_id DEBE ser ignorado y quedar nulo por privacidad.
      final reconstructed = Post.fromMap(insertMap);
      expect(reconstructed.userId, isNull);
    });

    test('PostComment.toInsertMap incluye user_id pero fromMap nunca lo lee', () {
      final comment = PostComment(
        id: 'comm-write-001',
        postId: 'post-write-001',
        authorAlias: 'Compilador Desvelado',
        content: 'Comentario original',
        userId: 'auth-commenter-id-67890',
        createdAt: DateTime.now(),
      );

      final insertMap = comment.toInsertMap();
      expect(insertMap['user_id'], 'auth-commenter-id-67890');

      // fromMap no lee user_id
      final reconstructed = PostComment.fromMap(insertMap);
      expect(reconstructed.userId, isNull);
    });
  });
}
