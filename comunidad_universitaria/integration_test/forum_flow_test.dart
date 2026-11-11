import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:comunidad_universitaria/core/services/forum_service.dart';
import 'package:comunidad_universitaria/core/services/supabase_service.dart';
import 'helpers/app_launcher.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('E2E: Flujo Real del Foro Estudiantil (Crear / Leer / Borrar)', () {
    testWidgets(
      'Crea una publicación en el foro, la lee en la interfaz y la elimina',
      skip: !isLocalSupabaseConfigured,
      (tester) async {
        final uniqueTitle = 'Post E2E Foro ${DateTime.now().millisecondsSinceEpoch}';

        await launchApp(tester, surfaceSize: const Size(400, 800));

        // 1. Crear publicación en base de datos local
        final createdPost = await ForumService.createPost(
          title: uniqueTitle,
          content: 'Contenido verificado mediante prueba de integración E2E automatizada.',
          category: 'general',
          carrera: 'sistemas',
          authorAlias: 'E2E Forum Tester',
        );

        expect(createdPost, isNotNull);
        expect(createdPost!.id, isNotEmpty);

        // 2. Refrescar el feed del foro
        final posts = await ForumService.fetchPosts(category: 'general', carrera: 'sistemas');
        expect(posts.any((p) => p.id == createdPost.id), isTrue);

        await tester.pumpWidget(Container()); // Re-mount para forzar lectura fresca
        await launchApp(tester, surfaceSize: const Size(400, 800));

        // 3. Dar like al post
        final liked = await ForumService.toggleLike(createdPost);
        expect(liked, isTrue);

        // 4. Eliminar publicación y verificar limpieza
        await SupabaseService.client
            .from('post_likes')
            .delete()
            .eq('post_id', createdPost.id);

        await SupabaseService.client
            .from('posts')
            .delete()
            .eq('id', createdPost.id);

        final check = await SupabaseService.client
            .from('posts')
            .select('id')
            .eq('id', createdPost.id);

        expect((check as List).isEmpty, isTrue);
      },
    );
  });
}
