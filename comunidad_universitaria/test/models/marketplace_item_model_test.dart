import 'package:flutter_test/flutter_test.dart';
import 'package:comunidad_universitaria/core/models/marketplace_item.dart';
import '../helpers/fixtures.dart';

void main() {
  group('MarketplaceCategoryExtension', () {
    test('id y label devuelven los identificadores y textos esperados', () {
      expect(MarketplaceCategory.comidaPostres.id, 'comida_postres');
      expect(MarketplaceCategory.comidaPostres.label, 'Comida & Postres');

      expect(MarketplaceCategory.tutoriasAcademica.id, 'tutorias_academica');
      expect(MarketplaceCategory.tutoriasAcademica.label, 'Tutorías & Asesoría');

      expect(MarketplaceCategory.librosMateriales.id, 'libros_materiales');
      expect(MarketplaceCategory.librosMateriales.label, 'Libros & Materiales');

      expect(MarketplaceCategory.serviciosEstudiantiles.id, 'servicios_estudiantiles');
      expect(MarketplaceCategory.serviciosEstudiantiles.label, 'Servicios Estudiantiles');

      expect(MarketplaceCategory.otrosArticulos.id, 'otros_articulos');
      expect(MarketplaceCategory.otrosArticulos.label, 'Otros Artículos');
    });

    test('fromString convierte strings a enum con fallback a otrosArticulos', () {
      expect(MarketplaceCategoryExtension.fromString('comida_postres'), MarketplaceCategory.comidaPostres);
      expect(MarketplaceCategoryExtension.fromString('tutorias_academica'), MarketplaceCategory.tutoriasAcademica);
      expect(MarketplaceCategoryExtension.fromString('libros_materiales'), MarketplaceCategory.librosMateriales);
      expect(MarketplaceCategoryExtension.fromString('servicios_estudiantiles'), MarketplaceCategory.serviciosEstudiantiles);
      expect(MarketplaceCategoryExtension.fromString('otros_articulos'), MarketplaceCategory.otrosArticulos);
      expect(MarketplaceCategoryExtension.fromString('categoria_inexistente'), MarketplaceCategory.otrosArticulos);
    });
  });

  group('MarketplaceItem Model Helpers & Getters', () {
    test('formattedPrice formatea correctamente GRATIS y valores con moneda', () {
      final freeItem1 = TestFixtures.marketplaceItem(isFree: true, price: 50.0);
      expect(freeItem1.formattedPrice, 'GRATIS');

      final freeItem2 = TestFixtures.marketplaceItem(isFree: false, price: 0.0);
      expect(freeItem2.formattedPrice, 'GRATIS');

      final paidItem = TestFixtures.marketplaceItem(isFree: false, price: 175.5);
      expect(paidItem.formattedPrice, 'Q175.50');
    });

    test('whatsappUrl formatea teléfonos de 8 dígitos con prefijo 502 y limpia caracteres', () {
      // 8 dígitos sin prefijo
      final item1 = TestFixtures.marketplaceItem(
        title: 'Bata de Laboratorio',
        contactWhatsapp: '1234-5678',
      );
      expect(
        item1.whatsappUrl,
        contains('https://wa.me/50212345678?text='),
      );
      expect(item1.whatsappUrl, contains(Uri.encodeComponent('Bata de Laboratorio')));

      // Con prefijo internacional y signo +
      final item2 = TestFixtures.marketplaceItem(
        title: 'Libro',
        contactWhatsapp: '+502 9876-5432',
      );
      expect(item2.whatsappUrl, contains('https://wa.me/50298765432?text='));

      // Teléfono nulo o en blanco
      final item3 = TestFixtures.marketplaceItem(contactWhatsapp: '   ');
      expect(item3.whatsappUrl, isNull);
    });

    test('instagramUrl, messengerUrl y telegramUrl manejan @, URL completa y null', () {
      final itemWithHandles = TestFixtures.marketplaceItem(
        contactInstagram: '@tienda_estudiantil',
        contactMessenger: '@tienda.messenger',
        contactTelegram: '@tienda_tele',
      );
      expect(itemWithHandles.instagramUrl, 'https://instagram.com/tienda_estudiantil');
      expect(itemWithHandles.messengerUrl, 'https://m.me/tienda.messenger');
      expect(itemWithHandles.telegramUrl, 'https://t.me/tienda_tele');

      final itemWithUrls = TestFixtures.marketplaceItem(
        contactInstagram: 'https://instagram.com/perfil_completo',
        contactMessenger: 'https://m.me/perfil_completo',
        contactTelegram: 'https://t.me/perfil_completo',
      );
      expect(itemWithUrls.instagramUrl, 'https://instagram.com/perfil_completo');
      expect(itemWithUrls.messengerUrl, 'https://m.me/perfil_completo');
      expect(itemWithUrls.telegramUrl, 'https://t.me/perfil_completo');

      final emptyItem = TestFixtures.marketplaceItem(
        contactInstagram: '',
        contactMessenger: '   ',
        contactTelegram: null,
      );
      expect(emptyItem.instagramUrl, isNull);
      expect(emptyItem.messengerUrl, isNull);
      expect(emptyItem.telegramUrl, isNull);
    });

    test('hasAnyContact valida presencia de al menos una vía de contacto', () {
      expect(
        TestFixtures.marketplaceItem(contactWhatsapp: '50212345678').hasAnyContact,
        isTrue,
      );
      expect(
        TestFixtures.marketplaceItem(contactInstagram: 'tienda').hasAnyContact,
        isTrue,
      );
      expect(
        TestFixtures.marketplaceItem(contactMessenger: 'm_user').hasAnyContact,
        isTrue,
      );
      expect(
        TestFixtures.marketplaceItem(contactTelegram: 'tg_user').hasAnyContact,
        isTrue,
      );
      expect(
        TestFixtures.marketplaceItem(
          contactWhatsapp: null,
          contactInstagram: '',
          contactMessenger: '  ',
          contactTelegram: null,
        ).hasAnyContact,
        isFalse,
      );
    });

    test('Flags de estado e moderación responden correctamente', () {
      final available = TestFixtures.marketplaceItem(status: 'available');
      expect(available.isAvailable, isTrue);
      expect(available.isSold, isFalse);
      expect(available.isReserved, isFalse);

      final sold = TestFixtures.marketplaceItem(status: 'sold');
      expect(sold.isSold, isTrue);

      final reserved = TestFixtures.marketplaceItem(status: 'reserved');
      expect(reserved.isReserved, isTrue);

      final underReview = TestFixtures.marketplaceItem(moderationStatus: 1);
      expect(underReview.isUnderReview, isTrue);
      expect(underReview.isHidden, isFalse);

      final hidden = TestFixtures.marketplaceItem(moderationStatus: 2);
      expect(hidden.isHidden, isTrue);
    });

    test('round-trip fromMap y toInsertMap con soporte de clave legacy is_verified', () {
      final map = {
        'id': 'item-abc',
        'title': 'Engrapadora industrial',
        'description': 'Poco uso',
        'price': '85.50',
        'is_free': false,
        'category': 'otros_articulos',
        'image_url': 'https://example.com/single.jpg',
        'is_verified': true,
        'upvotes': '10',
        'reported_count': '0',
        'moderation_status': '0',
      };

      final item = MarketplaceItem.fromMap(map, isUpvotedByMe: true);
      expect(item.id, 'item-abc');
      expect(item.price, 85.50);
      expect(item.imageUrls, ['https://example.com/single.jpg']);
      expect(item.isSellerVerified, isTrue);
      expect(item.isUpvotedByMe, isTrue);

      final insertMap = item.toInsertMap();
      expect(insertMap['title'], 'Engrapadora industrial');
      expect(insertMap['price'], 85.50);
      expect(insertMap['is_seller_verified'], isTrue);
      expect(insertMap['upvotes'], 10);
    });
  });
}
