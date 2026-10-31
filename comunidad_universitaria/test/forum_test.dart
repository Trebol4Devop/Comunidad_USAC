import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:comunidad_universitaria/core/models/post.dart';
import 'package:comunidad_universitaria/features/forum/screens/forum_screen.dart';
import 'package:comunidad_universitaria/features/forum/screens/post_detail_screen.dart';
import 'package:comunidad_universitaria/features/forum/widgets/comment_item.dart';
import 'package:comunidad_universitaria/features/forum/widgets/create_post_dialog.dart';
import 'package:comunidad_universitaria/features/forum/widgets/post_card.dart';

void main() {
  testWidgets('Forum feed muestra error de carga y permite reintentar', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        home: ForumScreen(
          activeAlias: 'Tester',
          onAliasChanged: (_) {},
          initialPopularServers: const [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('No se pudo actualizar el feed. Comprueba tu conexión.'),
      findsOneWidget,
    );
    expect(find.text('Reintentar'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(
      find.text('No se pudo actualizar el feed. Comprueba tu conexión.'),
      findsOneWidget,
    );
  });
  testWidgets('Abrir PostDetailScreen desde ForumScreen o PostCard', (
    tester,
  ) async {
    final testPost = Post(
      id: 'test-1',
      title: 'Duda sobre Matemática',
      category: 'catedraticos',
      content: 'Pregunta de prueba en foro',
      authorAlias: 'Estudiante #10',
      likes: 5,
      createdAt: DateTime.now(),
      commentCount: 2,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PostCard(post: testPost, onTap: () {}, onLike: () {}),
        ),
      ),
    );

    expect(find.text('Duda sobre Matemática'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('Renderizar CommentItemWidget con respuestas anidadas', (
    tester,
  ) async {
    final parent = PostComment(
      id: 'c-1',
      postId: 'post-1',
      authorAlias: 'Ing. Carlos',
      content: 'Respuesta principal al post',
      createdAt: DateTime.now(),
    );
    parent.children.add(
      PostComment(
        id: 'c-2',
        postId: 'post-1',
        parentId: 'c-1',
        authorAlias: 'Estudiante #5',
        content: 'Muchas gracias por la explicación',
        createdAt: DateTime.now(),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CommentItemWidget(
              comment: parent,
              postAuthorUserId: 'author-1',
              onReply: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Ing. Carlos'), findsOneWidget);
    expect(find.text('Respuesta principal al post'), findsOneWidget);
    expect(find.text('Estudiante #5'), findsOneWidget);
    expect(find.text('Muchas gracias por la explicación'), findsOneWidget);
    expect(find.text('Responder'), findsNWidgets(2));
  });

  testWidgets(
    'PostDetail distingue error de comentarios y permite reintentar',
    (tester) async {
      final post = Post(
        id: 'comments-error',
        title: 'Consulta',
        category: 'catedraticos',
        content: 'Contenido de prueba',
        authorAlias: 'Estudiante',
        likes: 0,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PostDetailScreen(initialPost: post, activeAlias: 'Tester'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('No se pudieron cargar los comentarios.'),
        findsOneWidget,
      );
      expect(find.text('Aún no hay respuestas'), findsNothing);
      expect(find.text('Reintentar'), findsOneWidget);

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(
        find.text('No se pudieron cargar los comentarios.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'PostDetail deshabilita enviar comentario vacío y avisa si falla un like',
    (tester) async {
      final post = Post(
        id: 'like-failure',
        title: 'Consulta',
        category: 'catedraticos',
        content: 'Contenido de prueba',
        authorAlias: 'Estudiante',
        likes: 5,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PostDetailScreen(initialPost: post, activeAlias: 'Tester'),
        ),
      );
      await tester.pumpAndSettle();

      final sendButton = find.ancestor(
        of: find.byIcon(Icons.send),
        matching: find.byType(IconButton),
      );
      expect(tester.widget<IconButton>(sendButton).onPressed, isNull);

      final commentField = find.byType(TextField).first;
      await tester.enterText(commentField, '   ');
      await tester.pump();
      expect(tester.widget<IconButton>(sendButton).onPressed, isNull);
      await tester.enterText(commentField, 'Respuesta válida');
      await tester.pump();
      expect(tester.widget<IconButton>(sendButton).onPressed, isNotNull);
      await tester.enterText(commentField, '');
      await tester.pump();
      expect(tester.widget<IconButton>(sendButton).onPressed, isNull);

      final likeCount = find.text('5 votos útiles');
      await tester.ensureVisible(likeCount);
      await tester.tap(likeCount);
      await tester.pumpAndSettle();

      expect(
        find.text('No se pudo registrar el me gusta. Inténtalo de nuevo.'),
        findsOneWidget,
      );
      expect(find.text('5 votos útiles'), findsOneWidget);
    },
  );

  testWidgets(
    'El título de publicación acepta el mínimo documentado de 3 caracteres',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreatePostDialog(
              activeAlias: 'Tester',
              onAliasChanged: (_) {},
              onPostCreated: (_) {},
            ),
          ),
        ),
      );

      final titleField = find.byType(TextFormField).first;
      await tester.enterText(titleField, 'ab');
      await tester.ensureVisible(find.text('Publicar'));
      await tester.tap(find.text('Publicar'));
      await tester.pumpAndSettle();
      expect(
        find.text('El título debe tener al menos 3 caracteres.'),
        findsOneWidget,
      );

      await tester.enterText(titleField, 'abc');
      await tester.tap(find.text('Publicar'));
      await tester.pumpAndSettle();
      expect(
        find.text('El título debe tener al menos 3 caracteres.'),
        findsNothing,
      );
    },
  );

  testWidgets('Renderizar PostDetailScreen con comentarios anidados', (
    tester,
  ) async {
    final testPost = Post(
      id: 'test-1',
      title: 'Duda sobre Matemática',
      category: 'catedraticos',
      content: 'Pregunta de prueba en foro',
      authorAlias: 'Estudiante #10',
      likes: 5,
      createdAt: DateTime.now(),
      commentCount: 2,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PostDetailScreen(initialPost: testPost, activeAlias: 'Tester'),
      ),
    );

    // Initial pump
    await tester.pump();
    // Finish loading
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Duda sobre Matemática'), findsOneWidget);
  });
}
