import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:comunidad_universitaria/core/config/supabase_config.dart';
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

  group('MarketplaceService.createListing', () {
    test('bloquea publicación prohibida por validateContent ANTES de tocar la red', () async {
      bool networkTouched = false;
      fakeServer.onPost('/rest/v1/marketplace_items', (req) {
        networkTouched = true;
        return {};
      });

      expect(
        () => MarketplaceService.createListing(
          title: 'Vendo drogas y armas',
          description: 'Contacto por telegram',
          price: 100,
          isFree: false,
          category: 'otros_articulos',
          facultad: '08',
          sede: 'central',
          buildingCode: 'T-3',
          locationDetail: 'Entrada',
          authorAlias: 'Anon',
        ),
        throwsA(isA<Exception>()),
      );

      expect(networkTouched, isFalse);
    });

    test('isFree fuerza precio en 0.0 y nullifica contactos en blanco', () async {
      Map<String, dynamic>? insertedItem;
      fakeServer.onPost('/rest/v1/marketplace_items', (req) {
        insertedItem = jsonDecode(req.body) as Map<String, dynamic>;
        return {
          ...insertedItem!,
          'id': 'listing-free-1',
          'created_at': DateTime.now().toIso8601String(),
        };
      });

      final created = await MarketplaceService.createListing(
        title: 'Regalo apuntes de Química',
        description: 'Fotocopias limpias del semestre pasado',
        price: 999.0, // Debe forzarse a 0.0 porque isFree es true
        isFree: true,
        category: 'libros_materiales',
        facultad: '08',
        sede: 'central',
        buildingCode: 'T-3',
        locationDetail: 'Cafetería',
        contactWhatsapp: '   ',
        contactInstagram: '',
        contactMessenger: null,
        contactTelegram: '  @quimica_gratis  ',
        authorAlias: 'Estudiante Solidario',
      );

      expect(created, isNotNull);
      expect(created!.price, 0.0);
      expect(created.isFree, isTrue);
      expect(created.contactWhatsapp, isNull);
      expect(created.contactInstagram, isNull);
      expect(created.contactMessenger, isNull);
      expect(created.contactTelegram, '@quimica_gratis');

      expect(insertedItem, isNotNull);
      expect(insertedItem!['price'], 0.0);
      expect(insertedItem!['is_free'], isTrue);
      expect(insertedItem!['contact_whatsapp'], isNull);
      expect(insertedItem!['contact_instagram'], isNull);
      expect(insertedItem!['contact_telegram'], '@quimica_gratis');
      expect(insertedItem!['upvotes'], 1);
    });
  });

  group('MarketplaceService.moderateListing & updateItemStatus', () {
    test('moderateListing ejecuta RPC o fallback a update', () async {
      fakeServer.onPost('/rest/v1/rpc/moderate_marketplace_item', (req) => true);

      final res = await MarketplaceService.moderateListing(
        itemId: 'item-10',
        newStatus: 2, // Ocultar
      );
      expect(res, isTrue);
    });

    test('updateItemStatus actualiza el estado comercial', () async {
      bool updateCalled = false;
      fakeServer.onPatch('/rest/v1/marketplace_items', (req) {
        updateCalled = true;
        return [];
      });

      final res = await MarketplaceService.updateItemStatus(
        itemId: 'item-10',
        newStatus: 'sold',
      );
      expect(res, isTrue);
      expect(updateCalled, isTrue);
    });
  });

  group('MarketplaceService.fetchSponsoredListings', () {
    test('obtiene anuncios patrocinados activos', () async {
      fakeServer.onGet('/rest/v1/marketplace_items', (req) {
        return [
          TestFixtures.marketplaceItemMap(
            id: 'sponsor-1',
            title: 'Café San Carlos Sponsor',
            isSponsored: true,
          ),
        ];
      });

      final sponsors = await MarketplaceService.fetchSponsoredListings();
      expect(sponsors.length, 1);
      expect(sponsors.first.id, 'sponsor-1');
      expect(sponsors.first.isSponsored, isTrue);
    });
  });

  group('MarketplaceService.reportListing', () {
    test('reportListing ejecuta RPC de reporte', () async {
      fakeServer.onPost('/rest/v1/rpc/report_marketplace_item', (req) => true);

      final res = await MarketplaceService.reportListing(
        itemId: 'item-spam',
        reason: 'Precio falso',
        sellerUserId: 'seller-x',
        sellerAlias: 'Vendedor Sospechoso',
      );
      expect(res, isTrue);
    });
  });
}
