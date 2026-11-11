// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:comunidad_universitaria/core/config/supabase_config.dart';
import 'package:comunidad_universitaria/core/services/forum_service.dart';
import 'package:comunidad_universitaria/core/services/groups_service.dart';
import 'package:comunidad_universitaria/core/services/marketplace_service.dart';
import 'package:comunidad_universitaria/core/services/supabase_service.dart';

/// Determina si se proporcionaron credenciales que apunten a una instancia local de Supabase
/// mediante dart-define o variables de entorno del proceso.
bool get isLocalSupabaseConfigured {
  const dartDefineUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  const dartDefineKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
  final envUrl = Platform.environment['SUPABASE_URL'] ?? '';
  final envKey = Platform.environment['SUPABASE_ANON_KEY'] ?? '';

  final activeUrl = dartDefineUrl.isNotEmpty ? dartDefineUrl : envUrl;
  final activeKey = dartDefineKey.isNotEmpty ? dartDefineKey : envKey;

  if (activeUrl.isEmpty || activeKey.isEmpty) return false;

  final uri = Uri.tryParse(activeUrl);
  if (uri == null) return false;

  final host = uri.host.toLowerCase();
  final isLocalHost = host == '127.0.0.1' ||
      host == 'localhost' ||
      host == '10.0.2.2' ||
      host == '0.0.0.0' ||
      host == 'supabase' ||
      host.endsWith('.internal');

  return isLocalHost;
}

String get localSupabaseUrl {
  const dartDefineUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  return dartDefineUrl.isNotEmpty ? dartDefineUrl : (Platform.environment['SUPABASE_URL'] ?? '');
}

String get localSupabaseAnonKey {
  const dartDefineKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
  return dartDefineKey.isNotEmpty ? dartDefineKey : (Platform.environment['SUPABASE_ANON_KEY'] ?? '');
}

void main() {
  const skipReason =
      'Omitido: Requiere SUPABASE_URL y SUPABASE_ANON_KEY apuntando a una base local (ej. 127.0.0.1:54321).';

  group('DB Service Integration Tests (Local Supabase)', () {
    const testUserId = '00000000-0000-0000-0000-000000000001';

    setUpAll(() async {
      if (!isLocalSupabaseConfigured) return;

      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});

      final client = SupabaseClient(
        localSupabaseUrl,
        localSupabaseAnonKey,
      );

      SupabaseService.debugClient = client;
      SupabaseService.debugUserId = testUserId;
      SupabaseConfig.debugOverrideConfigured = true;
    });

    tearDownAll(() async {
      SupabaseService.resetForTests();
    });

    test(
      'ForumService: createPost -> fetchPosts -> borrar',
      skip: !isLocalSupabaseConfigured ? skipReason : false,
      () async {
        final uniqueTitle = 'Integration Test Post ${DateTime.now().millisecondsSinceEpoch}';

        // 1. Crear publicación en el foro
        final createdPost = await ForumService.createPost(
          title: uniqueTitle,
          content: 'Publicación de prueba generada por la suite de integración Dart.',
          category: 'general',
          carrera: 'sistemas',
          authorAlias: 'Dart Integration Runner',
        );

        expect(createdPost, isNotNull, reason: 'El post debe haberse creado');
        expect(createdPost!.id, isNotEmpty);
        expect(createdPost.title, equals(uniqueTitle));

        // 2. Consultar publicaciones activas del foro
        final posts = await ForumService.fetchPosts(
          category: 'general',
          carrera: 'sistemas',
        );

        final found = posts.any((p) => p.id == createdPost.id);
        expect(found, isTrue, reason: 'El post recién creado debe ser visible en fetchPosts');

        // 3. Borrar la publicación directamente en base de datos
        await SupabaseService.client
            .from('posts')
            .delete()
            .eq('id', createdPost.id);

        final verification = await SupabaseService.client
            .from('posts')
            .select('id')
            .eq('id', createdPost.id);

        expect((verification as List).isEmpty, isTrue, reason: 'El post debe haber sido eliminado');
      },
    );

    test(
      'GroupsService: createGroup -> toggleUpvote',
      skip: !isLocalSupabaseConfigured ? skipReason : false,
      () async {
        final uniqueTitle = 'Grupo de Repaso ${DateTime.now().millisecondsSinceEpoch}';

        // 1. Crear grupo estudiantil
        final createdGroup = await GroupsService.createGroup(
          title: uniqueTitle,
          carrera: 'sistemas',
          curso: 'Estructuras de Datos',
          section: 'A',
          link: 'https://chat.whatsapp.com/testintegrationgroup',
          description: 'Grupo creado por el test de integración de base de datos.',
          authorAlias: 'Dart Group Runner',
        );

        expect(createdGroup, isNotNull);
        expect(createdGroup!.id, isNotEmpty);
        expect(createdGroup.title, equals(uniqueTitle));

        // Por diseño de createGroup, el creador inicia con auto-upvote (isUpvotedByMe: true)
        // 2. Alternar upvote (remover upvote)
        final toggledOff = await GroupsService.toggleUpvote(createdGroup);
        expect(toggledOff, isFalse, reason: 'El primer toggle debe remover el upvote del creador');

        // 3. Alternar upvote de nuevo (volver a dar upvote)
        final toggledOn = await GroupsService.toggleUpvote(createdGroup);
        expect(toggledOn, isTrue, reason: 'El segundo toggle debe restaurar el upvote');

        // Limpieza de datos creados en el test
        await SupabaseService.client
            .from('student_group_upvotes')
            .delete()
            .eq('group_id', createdGroup.id);

        await SupabaseService.client
            .from('student_groups')
            .delete()
            .eq('id', createdGroup.id);
      },
    );

    test(
      'MarketplaceService: createListing -> updateItemStatus',
      skip: !isLocalSupabaseConfigured ? skipReason : false,
      () async {
        final uniqueTitle = 'Calculadora Científica ${DateTime.now().millisecondsSinceEpoch}';

        // 1. Crear publicación en el marketplace
        final listing = await MarketplaceService.createListing(
          title: uniqueTitle,
          description: 'Calculadora en perfecto estado para exámenes de física y cálculo.',
          price: 135.0,
          isFree: false,
          category: 'otros_articulos',
          facultad: '08',
          sede: 'central',
          buildingCode: 'T-3',
          locationDetail: '2do nivel cubículos',
          authorAlias: 'Dart Market Runner',
        );

        expect(listing, isNotNull);
        expect(listing!.id, isNotEmpty);
        expect(listing.status, equals('available'));

        // 2. Actualizar estado del artículo a 'reserved'
        final updated = await MarketplaceService.updateItemStatus(
          itemId: listing.id,
          newStatus: 'reserved',
        );
        expect(updated, isTrue, reason: 'updateItemStatus debe retornar true al actualizar');

        // 3. Verificar en base de datos que el estado cambió a 'reserved'
        final check = await SupabaseService.client
            .from('marketplace_items')
            .select('status')
            .eq('id', listing.id)
            .single();

        expect(check['status'], equals('reserved'), reason: 'El status en BD debe ser reserved');

        // Limpieza de datos creados
        await SupabaseService.client
            .from('marketplace_upvotes')
            .delete()
            .eq('item_id', listing.id);

        await SupabaseService.client
            .from('marketplace_items')
            .delete()
            .eq('id', listing.id);
      },
    );
  });
}
