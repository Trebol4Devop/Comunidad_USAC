import 'package:flutter_test/flutter_test.dart';
import 'package:comunidad_universitaria/core/models/marketplace_item.dart';
import '../helpers/fixtures.dart';

void main() {
  group('MarketplaceCategoryExtension', () {
    test('id y label devuelven los identificadores y textos esperados', () {
      expect(MarketplaceCategory.comidaPostres.id, 'comida_postres');
      expect(MarketplaceCategory.comidaPostres.label, 'Comida & Postres');

      expect(MarketplaceCategory.tutoriasAcademica.id, 'tutorias_academica');
      expect(
        MarketplaceCategory.tutoriasAcademica.label,
        'Tutorías & Asesoría',
      );

      expect(MarketplaceCategory.librosMateriales.id, 'libros_materiales');
      expect(MarketplaceCategory.librosMateriales.label, 'Libros & Materiales');

      expect(
        MarketplaceCategory.serviciosEstudiantiles.id,
        'servicios_estudiantiles',
      );
      expect(
        MarketplaceCategory.serviciosEstudiantiles.label,
        'Servicios Estudiantiles',
      );

      expect(MarketplaceCategory.otrosArticulos.id, 'otros_articulos');
      expect(MarketplaceCategory.otrosArticulos.label, 'Otros Artículos');
    });

    test(
      'fromString convierte strings a enum con fallback a otrosArticulos',
      () {
        expect(
          MarketplaceCategoryExtension.fromString('comida_postres'),
          MarketplaceCategory.comidaPostres,
        );
        expect(
          MarketplaceCategoryExtension.fromString('tutorias_academica'),
          MarketplaceCategory.tutoriasAcademica,
        );
        expect(
          MarketplaceCategoryExtension.fromString('libros_materiales'),
          MarketplaceCategory.librosMateriales,
        );
        expect(
          MarketplaceCategoryExtension.fromString('servicios_estudiantiles'),
          MarketplaceCategory.serviciosEstudiantiles,
        );
        expect(
          MarketplaceCategoryExtension.fromString('otros_articulos'),
          MarketplaceCategory.otrosArticulos,
        );
        expect(
          MarketplaceCategoryExtension.fromString('categoria_inexistente'),
          MarketplaceCategory.otrosArticulos,
        );
      },
    );
  });

  group('MarketplaceItem Model Helpers & Getters', () {
    test(
      'formattedPrice formatea correctamente GRATIS y valores con moneda',
      () {
        final freeItem1 = TestFixtures.marketplaceItem(
          isFree: true,
          price: 50.0,
        );
        expect(freeItem1.formattedPrice, 'GRATIS');

        final freeItem2 = TestFixtures.marketplaceItem(
          isFree: false,
          price: 0.0,
        );
        expect(freeItem2.formattedPrice, 'GRATIS');

        final paidItem = TestFixtures.marketplaceItem(
          isFree: false,
          price: 175.5,
        );
        expect(paidItem.formattedPrice, 'Q175.50');
      },
    );

    test(
      'whatsappUrl formatea teléfonos de 8 dígitos con prefijo 502 y limpia caracteres',
      () {
        // 8 dígitos sin prefijo
        final item1 = TestFixtures.marketplaceItem(
          title: 'Bata de Laboratorio',
          contactWhatsapp: '1234-5678',
        );
        expect(item1.whatsappUrl, contains('https://wa.me/50212345678?text='));
        expect(
          item1.whatsappUrl,
          contains(Uri.encodeComponent('Bata de Laboratorio')),
        );

        // Con prefijo internacional y signo +
        final item2 = TestFixtures.marketplaceItem(
          title: 'Libro',
          contactWhatsapp: '+502 9876-5432',
        );
        expect(item2.whatsappUrl, contains('https://wa.me/50298765432?text='));

        // Teléfono nulo o en blanco
        final item3 = TestFixtures.marketplaceItem(contactWhatsapp: '   ');
        expect(item3.whatsappUrl, isNull);
      },
    );

    test(
      'instagramUrl, messengerUrl y telegramUrl manejan @, URL completa y null',
      () {
        final itemWithHandles = TestFixtures.marketplaceItem(
          contactInstagram: '@tienda_estudiantil',
          contactMessenger: '@tienda.messenger',
          contactTelegram: '@tienda_tele',
        );
        expect(
          itemWithHandles.instagramUrl,
          'https://instagram.com/tienda_estudiantil',
        );
        expect(itemWithHandles.messengerUrl, 'https://m.me/tienda.messenger');
        expect(itemWithHandles.telegramUrl, 'https://t.me/tienda_tele');

        final itemWithUrls = TestFixtures.marketplaceItem(
          contactInstagram: 'https://instagram.com/perfil_completo',
          contactMessenger: 'https://m.me/perfil_completo',
          contactTelegram: 'https://t.me/perfil_completo',
        );
        expect(
          itemWithUrls.instagramUrl,
          'https://instagram.com/perfil_completo',
        );
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
      },
    );

    test('hasAnyContact valida presencia de al menos una vía de contacto', () {
      expect(
        TestFixtures.marketplaceItem(
          contactWhatsapp: '50212345678',
        ).hasAnyContact,
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

    test(
      'round-trip fromMap y toInsertMap con soporte de clave legacy is_verified',
      () {
        final map = {
          'id': 'item-abc',
          'title': 'Engrapadora industrial',
          'description': 'Poco uso',
          'price': '85.50',
          'is_free': false,
          'category': 'otros_articulos',
          'image_url': 'https://example.com/single.jpg',
          'is_verified': true,
          'sponsor_brand_name': 'Marca XYZ',
          'upvotes': '10',
          'reported_count': '0',
          'moderation_status': '0',
          'user_id': 'user-leak-test',
          'is_mine': true,
        };

        final item = MarketplaceItem.fromMap(map, isUpvotedByMe: true);
        expect(item.id, 'item-abc');
        expect(item.price, 85.50);
        expect(item.imageUrls, ['https://example.com/single.jpg']);
        expect(item.isSellerVerified, isTrue);
        expect(item.isUpvotedByMe, isTrue);
        expect(item.userId, isNull);
        expect(item.isMine, isTrue);
        expect(item.normalizedSponsorBrandName, 'Marca XYZ');

        final insertMap = item.toInsertMap();
        expect(insertMap['title'], 'Engrapadora industrial');
        expect(insertMap['price'], 85.50);
        expect(insertMap.containsKey('is_seller_verified'), isFalse);
        expect(insertMap['upvotes'], 10);

        final defaultItem = MarketplaceItem.fromMap({'id': 'item-def'});
        expect(defaultItem.isMine, isFalse);
        expect(defaultItem.userId, isNull);

        final updated = item.copyWith(isMine: false);
        expect(updated.isMine, isFalse);
      },
    );

    test('get_marketplace_feed RPC payload parsing y nuevos campos UX', () {
      final now = DateTime.now();
      final expires = now.add(const Duration(days: 10));

      final rpcPayload = {
        'id': '777e4567-e89b-12d3-a456-426614174000',
        'title': 'Calculadora Casio fx-991',
        'description': 'Ideal para Ingeniería',
        'price': '350.00',
        'is_free': false,
        'category': 'otros_articulos',
        'facultad': '08',
        'sede': 'central',
        'building_code': 'T-3',
        'location_detail': 'Frente a biblioteca',
        'contact_whatsapp': '50255551234',
        'contact_telegram': '@ingeniero_usac',
        'contact_instagram': 'casio_usac',
        'contact_messenger': null,
        'social_links': ['https://instagram.com/p/123'],
        'image_urls': [
          'https://example.com/img1.jpg',
          'https://example.com/img2.jpg',
        ],
        'video_url': 'https://example.com/video.mp4',
        'is_sponsored': true,
        'sponsor_badge_text': 'Destacado',
        'author_alias': 'Carlos Ingeniero',
        'upvotes': 15,
        'reported_count': 0,
        'shares_count': 7,
        'moderation_status': 0,
        'status': 'available',
        'created_at': now.subtract(const Duration(hours: 3)).toIso8601String(),
        'updated_at': now.toIso8601String(),
        'expires_at': expires.toIso8601String(),
        'is_legal_hold': false,
        'seller_public_id': 'seller-pub-123',
        'seller_business_name': 'Tienda de Ingeniería',
        'seller_plan_id': 'pro_student',
        'seller_plan_name': 'Emprendedor',
        'seller_badge_text': 'Emprendedor Verificado',
        'seller_is_verified': true,
        'seller_is_on_campus': true,
        'seller_building_code': 'T-3',
        'is_mine': false,
        'is_upvoted_by_me': true,
        'is_bookmarked_by_me': true,
        'score': 12.456,
        'is_hidden': false,
        'user_id': 'leaked-user-id-that-must-be-ignored',
      };

      final item = MarketplaceItem.fromJson(rpcPayload);

      expect(item.id, '777e4567-e89b-12d3-a456-426614174000');
      expect(item.userId, isNull);
      expect(item.sellerPublicId, 'seller-pub-123');
      expect(item.sellerBusinessName, 'Tienda de Ingeniería');
      expect(item.sellerPlanId, 'pro_student');
      expect(item.sellerPlanName, 'Emprendedor');
      expect(item.sellerBadgeText, 'Emprendedor Verificado');
      expect(item.isSellerVerified, isTrue);
      expect(item.sellerIsOnCampus, isTrue);
      expect(item.sellerBuildingCode, 'T-3');
      expect(item.isMine, isFalse);
      expect(item.isUpvotedByMe, isTrue);
      expect(item.isBookmarked, isTrue);
      expect(item.score, 12.456);
      expect(item.isHidden, isFalse);
      expect(item.isHiddenFromFeed, isFalse);
      expect(item.planBadge, 'Emprendedor Verificado');
      expect(item.storeUrlId, 'seller-pub-123');
      expect(item.venceEnDias, greaterThanOrEqualTo(9));
      expect(item.formattedPrice, 'Q350.00');
      expect(
        item.whatsappUrl,
        'https://wa.me/50255551234?text=${Uri.encodeComponent("Hola Carlos Ingeniero, vi tu publicación 'Calculadora Casio fx-991' en el Marketplace universitario. ¿Sigue disponible?")}',
      );
    });

    test(
      'Contrato de privacidad de modelos: fromJson con get_marketplace_feed produce userId == null y toInsertMap protege identidad y campos sensibles',
      () {
        final feedPayload = {
          'id': '777e4567-e89b-12d3-a456-426614174000',
          'title': 'Cuaderno Universitario USAC',
          'description': '100 hojas cuadrícula',
          'price': 25.0,
          'is_free': false,
          'category': 'libros_materiales',
          'facultad': '08',
          'sede': 'central',
          'building_code': 'T-3',
          'location_detail': 'Planta baja',
          'author_alias': 'Estudiante Ingeniero',
          'created_at': DateTime.now().toIso8601String(),
          'seller_public_id': 'seller-pub-uuid-1',
          'seller_plan_id': 'free',
          'seller_plan_name': 'Estudiante',
          'seller_is_verified': true,
          'status': 'available',
        };

        // 1. Confirma que el payload del feed no expone user_id
        expect(feedPayload.containsKey('user_id'), isFalse);

        // 2. Confirma que fromJson produce userId == null
        final item = MarketplaceItem.fromJson(feedPayload);
        expect(item.userId, isNull, reason: 'MarketplaceItem.fromJson debe producir userId == null');

        // 3. Confirma que aun si se inyecta un user_id malicioso o filtrado en el json, fromJson lo anula
        final leakPayload = Map<String, dynamic>.from(feedPayload)
          ..['user_id'] = 'malicious-leaked-user-uuid';
        final sanitizedItem = MarketplaceItem.fromJson(leakPayload);
        expect(
          sanitizedItem.userId,
          isNull,
          reason: 'MarketplaceItem.fromJson debe ignorar siempre user_id para evitar doxxing',
        );

        // 4. Confirma que toInsertMap() no contiene user_id
        final insertMap = item.toInsertMap();
        expect(insertMap.containsKey('user_id'), isFalse, reason: 'toInsertMap no debe contener user_id');
        expect(insertMap['user_id'], isNull);

        // 5. Confirma que toInsertMap() no contiene campos internos de moderación de staff o legales
        expect(insertMap.containsKey('moderated_by'), isFalse);
        expect(insertMap.containsKey('moderated_at'), isFalse);
        expect(insertMap.containsKey('moderation_reason'), isFalse);
        expect(insertMap.containsKey('moderation_label'), isFalse);
        expect(insertMap.containsKey('moderation_confidence'), isFalse);
        expect(insertMap.containsKey('is_legal_hold'), isFalse);
      },
    );
  });
}
