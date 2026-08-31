import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:comunidad_universitaria/core/models/post.dart';
import 'package:comunidad_universitaria/features/forum/screens/post_detail_screen.dart';
import 'package:comunidad_universitaria/features/forum/widgets/comment_item.dart';
import 'package:comunidad_universitaria/features/forum/widgets/post_card.dart';

void main() {
  testWidgets('Abrir PostDetailScreen desde ForumScreen o PostCard', (tester) async {
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
          body: PostCard(
            post: testPost,
            onTap: () {},
            onLike: () {},
          ),
        ),
      ),
    );

    expect(find.text('Duda sobre Matemática'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('Renderizar CommentItemWidget con respuestas anidadas', (tester) async {
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

  testWidgets('Renderizar PostDetailScreen con comentarios anidados', (tester) async {
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
        home: PostDetailScreen(
          initialPost: testPost,
          activeAlias: 'Tester',
        ),
      ),
    );

    // Initial pump
    await tester.pump();
    // Finish loading
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Duda sobre Matemática'), findsOneWidget);
  });
}

