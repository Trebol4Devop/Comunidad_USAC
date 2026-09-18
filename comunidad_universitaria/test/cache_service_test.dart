import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:comunidad_universitaria/core/models/marketplace_item.dart';
import 'package:comunidad_universitaria/core/models/post.dart';
import 'package:comunidad_universitaria/core/models/whatsapp_group.dart';
import 'package:comunidad_universitaria/core/services/cache_service.dart';
import 'package:comunidad_universitaria/core/services/forum_service.dart';
import 'package:comunidad_universitaria/core/services/groups_service.dart';
import 'package:comunidad_universitaria/core/services/marketplace_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    CacheService.invalidate('test_cache');
    CacheService.invalidate('otro_namespace');
    CacheService.invalidate('forum_posts');
    CacheService.invalidate('student_groups');
    CacheService.invalidate('marketplace_items');
  });

  group('CacheService', () {
    test('buildKey es estable aunque cambie el orden de los filtros', () {
      final a = CacheService.buildKey({'category': 'todos', 'sede': 'central', 'onlyFree': false});
      final b = CacheService.buildKey({'sede': 'central', 'onlyFree': false, 'category': 'todos'});
      expect(a, b);
    });

    test('get/set en memoria respeta el TTL', () async {
      CacheService.set('test_cache', 'feed', [1, 2, 3], ttl: const Duration(milliseconds: 50));
      expect(CacheService.get<List<int>>('test_cache', 'feed'), [1, 2, 3]);

      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(CacheService.get<List<int>>('test_cache', 'feed'), isNull);
    });

    test('invalidate limpia solo el namespace indicado', () {
      CacheService.set('test_cache', 'a', 'valor-a');
      CacheService.set('otro_namespace', 'b', 'valor-b');

      CacheService.invalidate('test_cache');

      expect(CacheService.get<String>('test_cache', 'a'), isNull);
      expect(CacheService.get<String>('otro_namespace', 'b'), 'valor-b');
    });

    test('persistencia: roundtrip JSON, TTL e invalidación', () async {
      await CacheService.setPersisted(
        'test_cache',
        'feed',
        [
          {'id': 'p1', 'title': 'Hola'},
        ],
        ttl: const Duration(milliseconds: 50),
      );

      final loaded = await CacheService.getPersisted<List<dynamic>>(
        'test_cache',
        'feed',
        (data) => data as List<dynamic>,
      );
      expect(loaded, isNotNull);
      expect(loaded!.first['title'], 'Hola');

      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(
        await CacheService.getPersisted<List<dynamic>>(
          'test_cache',
          'feed',
          (data) => data as List<dynamic>,
        ),
        isNull,
      );

      await CacheService.setPersisted(
        'test_cache',
        'feed',
        [1],
        ttl: const Duration(minutes: 1),
      );
      await CacheService.invalidateAll('test_cache');
      expect(CacheService.get('test_cache', 'feed'), isNull);
      expect(
        await CacheService.getPersisted<List<dynamic>>(
          'test_cache',
          'feed',
          (data) => data as List<dynamic>,
        ),
        isNull,
      );
    });
  });

  group('Feeds consultan la caché antes de la red', () {
    test('fetchPosts devuelve la copia en memoria y protege la caché', () async {
      final post = Post(
        id: 'cache-post',
        title: 'Post en caché',
        category: 'general',
        content: 'Contenido de prueba',
        authorAlias: 'Estudiante #1',
        likes: 3,
        createdAt: DateTime.now(),
      );
      final key = CacheService.buildKey({
        'user': 'anon',
        'category': 'todos',
        'facultad': 'todas',
        'carrera': 'todas',
        'search': '',
        'bookmarks': false,
      });
      CacheService.set('forum_posts', key, [post]);

      final result = await ForumService.fetchPosts();
      expect(result.length, 1);
      expect(result.first.id, 'cache-post');

      // El llamador puede ordenar/mutar la lista sin dañar la caché.
      result.clear();
      final again = await ForumService.fetchPosts();
      expect(again.length, 1);
      expect(again.first.id, 'cache-post');
    });

    test('fetchGroups devuelve la copia en memoria', () async {
      final group = WhatsAppGroup(
        id: 'cache-group',
        title: 'Grupo en caché',
        carrera: 'sistemas',
        curso: 'Estructuras de Datos',
        section: 'Sección Única',
        link: 'https://chat.whatsapp.com/cache',
        description: 'Descripción de prueba',
        authorAlias: 'Estudiante #2',
        upvotes: 5,
        reportedCount: 0,
        createdAt: DateTime.now(),
      );
      final key = CacheService.buildKey({
        'user': 'anon',
        'carrera': 'todas',
        'search': '',
      });
      CacheService.set('student_groups', key, [group]);

      final result = await GroupsService.fetchGroups();
      expect(result.length, 1);
      expect(result.first.id, 'cache-group');
    });

    test('fetchListings devuelve la copia en memoria', () async {
      final item = MarketplaceItem(
        id: 'cache-item',
        title: 'Artículo en caché',
        description: 'Descripción de prueba',
        category: 'otros_articulos',
        authorAlias: 'Estudiante #3',
        createdAt: DateTime.now(),
      );
      final key = CacheService.buildKey({
        'user': 'anon',
        'category': 'todos',
        'facultad': 'todas',
        'sede': 'todas',
        'onlyFree': false,
        'search': '',
      });
      CacheService.set('marketplace_items', key, [item]);

      final result = await MarketplaceService.fetchListings();
      expect(result.length, 1);
      expect(result.first.id, 'cache-item');
    });
  });
}
