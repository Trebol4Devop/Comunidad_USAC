import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:comunidad_universitaria/core/config/supabase_config.dart';
import 'package:comunidad_universitaria/core/models/marketplace_item.dart';
import 'package:comunidad_universitaria/core/services/cache_service.dart';
import 'package:comunidad_universitaria/core/services/marketplace_service.dart';
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
    SupabaseService.debugUserId = 'seller-user-id';
  });

  tearDown(() async {
    await resetTestState();
  });

  group('MarketplaceService — get_marketplace_feed & fallbacks', () {
    test('fetchListings llama a get_marketplace_feed con params correctos y sin user_id', () async {
      Map<String, dynamic>? receivedParams;

      fakeServer.onPost('/rest/v1/rpc/get_marketplace_feed', (req) {
        receivedParams = jsonDecode(req.body) as Map<String, dynamic>;
        return [
          {
            ...TestFixtures.marketplaceItemMap(id: 'item-feed-1'),
            'user_id': 'secret-author-user-id', // Simulamos fuga de backend
            'seller_public_id': 'seller-pub-1',
            'seller_business_name': 'Tienda T-3',
            'seller_plan_id': 'pro_student',
            'seller_plan_name': 'Emprendedor',
            'seller_badge_text': 'Emprendedor Verificado',
            'seller_is_verified': true,
            'seller_is_on_campus': true,
            'seller_building_code': 'T-3',
            'is_mine': false,
            'is_upvoted_by_me': true,
            'is_bookmarked_by_me': false,
            'score': 15.5,
            'is_hidden': false,
          },
        ];
      });

      final items = await MarketplaceService.fetchListings(
        category: 'comida_postres',
        facultad: '08',
        sede: 'central',
        buildingCode: 'T-3',
        onlyFree: true,
        searchQuery: 'brownies',
        offset: 10,
        limit: 20,
      );

      expect(items.length, 1);
      final item = items.first;
      expect(item.id, 'item-feed-1');
      // Privacidad estricta: user_id nunca debe exponerse
      expect(item.userId, isNull);
      expect(item.sellerPublicId, 'seller-pub-1');
      expect(item.sellerBusinessName, 'Tienda T-3');
      expect(item.sellerPlanId, 'pro_student');
      expect(item.sellerIsOnCampus, isTrue);
      expect(item.isUpvotedByMe, isTrue);
      expect(item.score, 15.5);

      // Verificación de parámetros RPC
      expect(receivedParams, isNotNull);
      expect(receivedParams!['p_category'], 'comida_postres');
      expect(receivedParams!['p_facultad'], '08');
      expect(receivedParams!['p_sede'], 'central');
      expect(receivedParams!['p_building_code'], 'T-3');
      expect(receivedParams!['p_only_free'], isTrue);
      expect(receivedParams!['p_sponsored_only'], isFalse);
      expect(receivedParams!['p_search'], 'brownies');
      expect(receivedParams!['p_offset'], 10);
      expect(receivedParams!['p_limit'], 20);
    });

    test('fetchListings convierte "todas" o "todos" a null en la RPC', () async {
      Map<String, dynamic>? receivedParams;

      fakeServer.onPost('/rest/v1/rpc/get_marketplace_feed', (req) {
        receivedParams = jsonDecode(req.body) as Map<String, dynamic>;
        return [];
      });

      await MarketplaceService.fetchListings(
        category: 'todos',
        facultad: 'todas',
        sede: 'todas',
        buildingCode: null,
      );

      expect(receivedParams!['p_category'], isNull);
      expect(receivedParams!['p_facultad'], isNull);
      expect(receivedParams!['p_sede'], isNull);
      expect(receivedParams!['p_building_code'], isNull);
      expect(receivedParams!['p_search'], isNull);
    });

    test('fetchListings ejecuta fallback a tabla marketplace_items si RPC falla', () async {
      fakeServer.onPost(
        '/rest/v1/rpc/get_marketplace_feed',
        (_) => http.Response('function not found', 404),
      );

      fakeServer.onGet('/rest/v1/marketplace_items', (req) {
        return [
          TestFixtures.marketplaceItemMap(
            id: 'item-fallback-10',
            title: 'Fallback Item',
          ),
        ];
      });

      fakeServer.onGet('/rest/v1/marketplace_upvotes', (_) => []);

      final items = await MarketplaceService.fetchListings(
        category: 'libros_materiales',
      );

      expect(items.length, 1);
      expect(items.first.id, 'item-fallback-10');
      expect(items.first.title, 'Fallback Item');
    });
  });

  group('MarketplaceService — Detalle, Catálogo y Relacionados', () {
    test('fetchItemDetail devuelve MarketplaceItem o null', () async {
      fakeServer.onPost('/rest/v1/rpc/get_marketplace_item_detail', (req) {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        if (body['p_item_id'] == 'item-1') {
          return [
            {
              ...TestFixtures.marketplaceItemMap(id: 'item-1'),
              'seller_public_id': 'seller-pub-1',
              'seller_badge_text': 'Estudiante Verificado',
              'is_mine': true,
              'is_upvoted_by_me': true,
              'is_bookmarked_by_me': true,
            },
          ];
        }
        return [];
      });

      final item = await MarketplaceService.fetchItemDetail('item-1');
      expect(item, isNotNull);
      expect(item!.id, 'item-1');
      expect(item.isMine, isTrue);
      expect(item.isBookmarked, isTrue);

      final notFound = await MarketplaceService.fetchItemDetail('item-999');
      expect(notFound, isNull);
    });

    test('fetchSellerCatalog llama a get_seller_catalog con excludeItemId', () async {
      Map<String, dynamic>? receivedParams;

      fakeServer.onPost('/rest/v1/rpc/get_seller_catalog', (req) {
        receivedParams = jsonDecode(req.body) as Map<String, dynamic>;
        return [
          TestFixtures.marketplaceItemMap(id: 'cat-item-1'),
          TestFixtures.marketplaceItemMap(id: 'cat-item-2'),
        ];
      });

      final items = await MarketplaceService.fetchSellerCatalog(
        sellerPublicId: 'seller-pub-uuid',
        excludeItemId: 'item-to-exclude',
        limit: 4,
        offset: 0,
      );

      expect(items.length, 2);
      expect(receivedParams!['p_seller_public_id'], 'seller-pub-uuid');
      expect(receivedParams!['p_exclude_item_id'], 'item-to-exclude');
      expect(receivedParams!['p_limit'], 4);
    });

    test('fetchRelatedListings llama a get_related_marketplace_items', () async {
      fakeServer.onPost('/rest/v1/rpc/get_related_marketplace_items', (req) {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(body['p_item_id'], 'orig-item-id');
        expect(body['p_limit'], 5);
        return [
          TestFixtures.marketplaceItemMap(id: 'related-1'),
        ];
      });

      final items = await MarketplaceService.fetchRelatedListings(
        itemId: 'orig-item-id',
        limit: 5,
      );

      expect(items.length, 1);
      expect(items.first.id, 'related-1');
    });

    test('fetchSellerProfile llama a get_seller_public_profile', () async {
      fakeServer.onPost('/rest/v1/rpc/get_seller_public_profile', (req) {
        return [
          {
            'public_id': 'seller-pub-xyz',
            'display_name': 'Comercio Universitario',
            'business_name': 'Comercio Universitario',
            'business_description': 'Cafetería y papelería',
            'business_logo_url': 'https://example.com/logo.jpg',
            'business_banner_url': null,
            'business_hours': {'mon': {'open': '07:00', 'close': '18:00'}},
            'seller_type': 'local_business',
            'plan_id': 'business_local',
            'plan_name': 'Comercio',
            'badge_text': 'Tienda Oficial',
            'is_verified': true,
            'is_on_campus': true,
            'current_building_code': 'T-3',
            'current_location_note': 'Nivel 1',
            'member_since': '2026-01-01T00:00:00.000Z',
            'active_items': 18,
            'is_my_store': false,
          },
        ];
      });

      final profile = await MarketplaceService.fetchSellerProfile('seller-pub-xyz');
      expect(profile, isNotNull);
      expect(profile!.publicId, 'seller-pub-xyz');
      expect(profile.businessName, 'Comercio Universitario');
      expect(profile.storeInitials, 'CU');
      expect(profile.planId, 'business_local');
    });
  });

  group('MarketplaceService — Planes, Estado y Marcadores', () {
    test('fetchPlans consulta marketplace_plans con columnas explícitas', () async {
      fakeServer.onGet('/rest/v1/marketplace_plans', (req) {
        expect(req.url.queryParameters['is_active'], 'eq.true');
        expect(req.url.queryParameters['order'], startsWith('sort_order.asc'));
        return [
          {
            'id': 'free',
            'name': 'Estudiante',
            'price_monthly': 0,
            'max_active_items': 3,
            'max_images_per_item': 2,
            'allow_video': false,
            'auto_sponsor_items': false,
            'hide_competitor_related': false,
            'default_badge_text': 'Estudiante Verificado',
            'features': ['3 publicaciones activas'],
            'sort_order': 0,
            'is_active': true,
          },
          {
            'id': 'pro_student',
            'name': 'Emprendedor',
            'price_monthly': 25.0,
            'max_active_items': 20,
            'max_images_per_item': 6,
            'allow_video': true,
            'auto_sponsor_items': true,
            'hide_competitor_related': false,
            'default_badge_text': 'Emprendedor Verificado',
            'features': ['20 publicaciones', 'video'],
            'sort_order': 1,
            'is_active': true,
          },
        ];
      });

      final plans = await MarketplaceService.fetchPlans();
      expect(plans.length, 2);
      expect(plans[0].id, 'free');
      expect(plans[0].formattedPrice, 'Q0');
      expect(plans[1].id, 'pro_student');
      expect(plans[1].formattedPrice, 'Q25.00');
    });

    test('fetchMyStatus obtiene estado y límites del vendedor', () async {
      fakeServer.onPost('/rest/v1/rpc/get_my_marketplace_status', (_) {
        return [
          {
            'can_publish': true,
            'reason': 'OK',
            'plan_id': 'free',
            'plan_name': 'Estudiante',
            'max_active_items': 3,
            'max_images_per_item': 2,
            'allow_video': false,
            'active_items': 1,
            'remaining_slots': 2,
            'expires_at': null,
            'seller_public_id': 'my-pub-uuid',
            'seller_type': 'student',
            'verification_status': 'approved',
            'is_verified': true,
            'is_on_campus': false,
            'current_building_code': null,
          },
        ];
      });

      final status = await MarketplaceService.fetchMyStatus();
      expect(status, isNotNull);
      expect(status!.canPublish, isTrue);
      expect(status.sellerPublicId, 'my-pub-uuid');
      expect(status.remainingSlots, 2);
      expect(status.isUnlimited, isFalse);
    });

    test('fetchMyListings llama a get_my_marketplace_items', () async {
      fakeServer.onPost('/rest/v1/rpc/get_my_marketplace_items', (req) {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(body['p_status'], 'available');
        return [
          TestFixtures.marketplaceItemMap(id: 'my-item-1', status: 'available'),
        ];
      });

      final items = await MarketplaceService.fetchMyListings(status: 'available');
      expect(items.length, 1);
      expect(items.first.id, 'my-item-1');
    });

    test('fetchBookmarkedListings llama a get_my_bookmarked_items', () async {
      fakeServer.onPost('/rest/v1/rpc/get_my_bookmarked_items', (_) {
        return [
          {
            ...TestFixtures.marketplaceItemMap(id: 'bookmarked-1'),
            'is_bookmarked_by_me': true,
            'bookmarked_at': '2026-11-13T12:00:00.000Z',
          },
        ];
      });

      final items = await MarketplaceService.fetchBookmarkedListings();
      expect(items.length, 1);
      expect(items.first.id, 'bookmarked-1');
      expect(items.first.isBookmarked, isTrue);
      expect(items.first.bookmarkedAt, isNotNull);
    });

    test('toggleBookmark alterna marcador e invalida caché', () async {
      CacheService.set('marketplace_items', 'dummy_key', <MarketplaceItem>[]);

      fakeServer.onPost('/rest/v1/rpc/toggle_marketplace_bookmark', (req) {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(body['p_item_id'], 'item-100');
        return true; // Marcado exitosamente
      });

      final bookmarked = await MarketplaceService.toggleBookmark('item-100');
      expect(bookmarked, isTrue);
      expect(CacheService.get('marketplace_items', 'dummy_key'), isNull);
    });

    test('toggleBookmark lanza MarketplaceException ante error PostgREST', () async {
      fakeServer.onPost(
        '/rest/v1/rpc/toggle_marketplace_bookmark',
        (_) => http.Response(
          jsonEncode({
            'message': 'Debes iniciar sesión para guardar productos en tus marcadores',
            'code': '42501',
          }),
          403,
          headers: {'content-type': 'application/json'},
        ),
      );

      expect(
        () => MarketplaceService.toggleBookmark('item-denied'),
        throwsA(isA<MarketplaceException>().having((e) => e.code, 'code', '42501')),
      );
    });
  });

  group('MarketplaceService — Telemetría, Métricas y Perfil', () {
    test('trackEvent llama a track_marketplace_event y nunca lanza error', () async {
      bool rpcCalled = false;
      fakeServer.onPost('/rest/v1/rpc/track_marketplace_event', (req) {
        rpcCalled = true;
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(body['p_item_id'], 'item-event-1');
        expect(body['p_event_type'], 'click_whatsapp');
        return true;
      });

      await MarketplaceService.trackEvent('item-event-1', 'click_whatsapp');
      expect(rpcCalled, isTrue);

      // Evento no permitido: no debe llamar a la red
      rpcCalled = false;
      await MarketplaceService.trackEvent('item-event-1', 'invalid_event');
      expect(rpcCalled, isFalse);

      // Si el servidor falla con 500, no lanza excepción
      fakeServer.onPost(
        '/rest/v1/rpc/track_marketplace_event',
        (_) => http.Response('error', 500),
      );
      await expectLater(
        MarketplaceService.trackEvent('item-event-1', 'view'),
        completes,
      );
    });

    test('fetchMyMetrics obtiene analíticas agregadas de vendedor', () async {
      fakeServer.onPost('/rest/v1/rpc/get_marketplace_metrics', (req) {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(body['p_days'], 14);
        return [
          {
            'item_id': 'item-m-1',
            'title': 'Calculadora',
            'views': 80,
            'click_whatsapp': 10,
            'click_telegram': 2,
            'click_instagram': 1,
            'click_messenger': 1,
            'shares': 3,
            'contact_rate': 0.175,
          },
        ];
      });

      final metrics = await MarketplaceService.fetchMyMetrics(days: 14);
      expect(metrics.length, 1);
      expect(metrics.first.itemId, 'item-m-1');
      expect(metrics.first.totalClicks, 14);
      expect(metrics.first.contactRate, 0.175);
    });

    test('updateSellerProfile actualiza filtrando por public_id (no por user_id)', () async {
      Map<String, dynamic>? patchedBody;

      fakeServer.onPatch('/rest/v1/seller_profiles', (req) {
        expect(req.url.queryParameters['public_id'], 'eq.seller-pub-target');
        expect(req.url.queryParameters.containsKey('user_id'), isFalse);
        patchedBody = jsonDecode(req.body) as Map<String, dynamic>;
        return [{'public_id': 'seller-pub-target'}];
      });

      final success = await MarketplaceService.updateSellerProfile(
        sellerPublicId: 'seller-pub-target',
        businessName: 'Nuevo Nombre Comercial',
        isCurrentlyOnCampus: true,
        currentBuildingCode: 'T-1',
        currentLocationNote: 'Pasillo 2',
      );

      expect(success, isTrue);
      expect(patchedBody!['business_name'], 'Nuevo Nombre Comercial');
      expect(patchedBody!['is_currently_on_campus'], isTrue);
      expect(patchedBody!['current_building_code'], 'T-1');
      expect(patchedBody!['current_location_note'], 'Pasillo 2');
      expect(patchedBody!.containsKey('user_id'), isFalse);
    });

    test('updatePresence actualiza usando public_id obtenido de fetchMyStatus', () async {
      fakeServer.onPost('/rest/v1/rpc/get_my_marketplace_status', (_) {
        return [
          {
            'seller_public_id': 'my-presence-pub-id',
            'can_publish': true,
          },
        ];
      });

      bool patchCalled = false;
      fakeServer.onPatch('/rest/v1/seller_profiles', (req) {
        patchCalled = true;
        expect(req.url.queryParameters['public_id'], 'eq.my-presence-pub-id');
        return [{'public_id': 'my-presence-pub-id'}];
      });

      final res = await MarketplaceService.updatePresence(
        onCampus: true,
        buildingCode: 'S-12',
        note: 'Frente a biblioteca',
      );

      expect(res, isTrue);
      expect(patchCalled, isTrue);
    });

    test('requestSponsorship incluye plan_id en la inserción', () async {
      Map<String, dynamic>? insertPayload;
      fakeServer.onPost('/rest/v1/sponsor_requests', (req) {
        insertPayload = jsonDecode(req.body) as Map<String, dynamic>;
        return [insertPayload!];
      });

      final ok = await MarketplaceService.requestSponsorship(
        brandName: 'Café San Carlos',
        contactName: 'Carlos López',
        contactPhone: '50212345678',
        email: 'cafe@usac.edu.gt',
        proposalDetails: 'Publicidad en carrusel',
        expectedPlacement: 'Carrusel superior',
        planId: 'business_local',
      );

      expect(ok, isTrue);
      expect(insertPayload!['plan_id'], 'business_local');
      expect(insertPayload!['brand_name'], 'Café San Carlos');
    });
  });

  group('MarketplaceService — Creación y Traducción de Excepciones', () {
    test('createListing no envía moderation_status, reported_count, upvotes, is_sponsored', () async {
      Map<String, dynamic>? insertedBody;

      fakeServer.onPost('/rest/v1/rpc/get_my_marketplace_status', (_) {
        return [{'can_publish': true}];
      });

      fakeServer.onPost('/rest/v1/marketplace_items', (req) {
        insertedBody = jsonDecode(req.body) as Map<String, dynamic>;
        return {
          ...insertedBody!,
          'id': 'new-item-uuid',
          'created_at': DateTime.now().toIso8601String(),
        };
      });

      final item = await MarketplaceService.createListing(
        title: 'Libro de Cálculo 1',
        description: 'Usado en buen estado',
        price: 120.0,
        isFree: false,
        category: 'libros_materiales',
        facultad: '08',
        sede: 'central',
        buildingCode: 'T-3',
        locationDetail: 'Nivel 2',
        authorAlias: 'Estudiante 123',
      );

      expect(item, isNotNull);
      expect(insertedBody, isNotNull);
      expect(insertedBody!['user_id'], 'seller-user-id');
      expect(insertedBody!.containsKey('moderation_status'), isFalse);
      expect(insertedBody!.containsKey('reported_count'), isFalse);
      expect(insertedBody!.containsKey('upvotes'), isFalse);
      expect(insertedBody!.containsKey('is_sponsored'), isFalse);
      expect(insertedBody!.containsKey('sponsor_badge_text'), isFalse);
    });

    test('createListing traduce PostgrestException 42501 a mensaje de verificación', () async {
      fakeServer.onPost('/rest/v1/rpc/get_my_marketplace_status', (_) {
        return [{'can_publish': true}];
      });

      fakeServer.onPost(
        '/rest/v1/marketplace_items',
        (_) => http.Response(
          jsonEncode({
            'message': 'permission denied for table marketplace_items',
            'code': '42501',
          }),
          403,
          headers: {'content-type': 'application/json'},
        ),
      );

      expect(
        () => MarketplaceService.createListing(
          title: 'Venta de algo',
          description: 'Descripción válida',
          price: 50.0,
          isFree: false,
          category: 'otros_articulos',
          facultad: '08',
          sede: 'central',
          buildingCode: 'T-3',
          locationDetail: 'Entrada',
          authorAlias: 'Anon',
        ),
        throwsA(
          isA<MarketplaceException>().having(
            (e) => e.message,
            'message',
            'Debes verificar tu identidad estudiantil con carné o contar con una cuenta comercial aprobada para publicar.',
          ),
        ),
      );
    });

    test('createListing traduce PostgrestException 23514 usando el mensaje del servidor', () async {
      fakeServer.onPost('/rest/v1/rpc/get_my_marketplace_status', (_) {
        return [{'can_publish': true}];
      });

      fakeServer.onPost(
        '/rest/v1/marketplace_items',
        (_) => http.Response(
          jsonEncode({
            'message': 'Has alcanzado el límite de publicaciones activas para tu plan (Estudiante).',
            'code': '23514',
          }),
          400,
          headers: {'content-type': 'application/json'},
        ),
      );

      expect(
        () => MarketplaceService.createListing(
          title: 'Venta de algo',
          description: 'Descripción válida',
          price: 50.0,
          isFree: false,
          category: 'otros_articulos',
          facultad: '08',
          sede: 'central',
          buildingCode: 'T-3',
          locationDetail: 'Entrada',
          authorAlias: 'Anon',
        ),
        throwsA(
          isA<MarketplaceException>().having(
            (e) => e.message,
            'message',
            'Has alcanzado el límite de publicaciones activas para tu plan (Estudiante).',
          ),
        ),
      );
    });
  });
}
