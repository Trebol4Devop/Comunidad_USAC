import 'package:flutter_test/flutter_test.dart';
import 'package:comunidad_universitaria/core/models/marketplace_exception.dart';
import 'package:comunidad_universitaria/core/models/marketplace_metrics.dart';
import 'package:comunidad_universitaria/core/models/marketplace_plan.dart';
import 'package:comunidad_universitaria/core/models/marketplace_seller_status.dart';
import 'package:comunidad_universitaria/core/models/seller_profile.dart';

void main() {
  group('MarketplacePlan Model', () {
    test('fromMap parsea tipos y formatea precios correctamente', () {
      final freeMap = {
        'id': 'free',
        'name': 'Estudiante',
        'price_monthly': '0.00',
        'max_active_items': 3,
        'max_images_per_item': 2,
        'allow_video': false,
        'auto_sponsor_items': false,
        'hide_competitor_related': false,
        'default_badge_text': 'Estudiante Verificado',
        'features': ['3 publicaciones', '2 fotos'],
        'sort_order': 1,
        'is_active': true,
      };

      final freePlan = MarketplacePlan.fromMap(freeMap);
      expect(freePlan.id, 'free');
      expect(freePlan.name, 'Estudiante');
      expect(freePlan.priceMonthly, 0.0);
      expect(freePlan.formattedPrice, 'Q0');
      expect(freePlan.isUnlimited, isFalse);
      expect(freePlan.maxActiveItems, 3);
      expect(freePlan.maxImagesPerItem, 2);
      expect(freePlan.allowVideo, isFalse);
      expect(freePlan.autoSponsorItems, isFalse);
      expect(freePlan.hideCompetitorRelated, isFalse);
      expect(freePlan.defaultBadgeText, 'Estudiante Verificado');
      expect(freePlan.features.length, 2);
      expect(freePlan.sortOrder, 1);
      expect(freePlan.isActive, isTrue);

      final businessMap = {
        'id': 'business_local',
        'name': 'Comercio',
        'price_monthly': 150.50,
        'max_active_items': 0, // Ilimitado
        'max_images_per_item': 10,
        'allow_video': true,
        'auto_sponsor_items': true,
        'hide_competitor_related': true,
        'default_badge_text': 'Tienda Oficial',
        'features': ['Ilimitadas', 'Video HD'],
        'sort_order': 3,
        'is_active': true,
      };

      final businessPlan = MarketplacePlan.fromJson(businessMap);
      expect(businessPlan.id, 'business_local');
      expect(businessPlan.formattedPrice, 'Q150.50');
      expect(businessPlan.isUnlimited, isTrue);
      expect(businessPlan.allowVideo, isTrue);
      expect(businessPlan.autoSponsorItems, isTrue);
      expect(businessPlan.hideCompetitorRelated, isTrue);

      final toMap = businessPlan.toMap();
      expect(toMap['id'], 'business_local');
      expect(toMap['price_monthly'], 150.50);
      expect(toMap['max_active_items'], 0);
    });
  });

  group('SellerProfile Model', () {
    test('fromMap parsea perfil y storeInitials genera siglas correctas', () {
      final map = {
        'public_id': 'seller-pub-uuid',
        'display_name': 'Carlos Estudiante',
        'business_name': 'Café San Carlos',
        'business_description': 'El mejor café del CUM',
        'business_logo_url': 'https://example.com/logo.png',
        'business_banner_url': 'https://example.com/banner.png',
        'business_hours': {
          'mon': {'open': '08:00', 'close': '17:00', 'closed': false},
        },
        'seller_type': 'local_business',
        'plan_id': 'business_local',
        'plan_name': 'Comercio',
        'badge_text': 'Tienda / Local Oficial',
        'is_verified': true,
        'is_on_campus': true,
        'is_my_store': true,
        'current_building_code': 'CUM-2',
        'current_location_note': 'Frente a librería',
        'member_since': '2026-01-15T10:00:00.000Z',
        'active_items': 12,
      };

      final profile = SellerProfile.fromJson(map);
      expect(profile.publicId, 'seller-pub-uuid');
      expect(profile.displayName, 'Carlos Estudiante');
      expect(profile.businessName, 'Café San Carlos');
      expect(profile.storeInitials, 'CS');
      expect(profile.businessDescription, 'El mejor café del CUM');
      expect(profile.businessLogoUrl, 'https://example.com/logo.png');
      expect(profile.businessBannerUrl, 'https://example.com/banner.png');
      expect(profile.businessHours?['mon']?['open'], '08:00');
      expect(profile.sellerType, 'local_business');
      expect(profile.planId, 'business_local');
      expect(profile.planName, 'Comercio');
      expect(profile.badgeText, 'Tienda / Local Oficial');
      expect(profile.isVerified, isTrue);
      expect(profile.isOnCampus, isTrue);
      expect(profile.isMyStore, isTrue);
      expect(profile.currentBuildingCode, 'CUM-2');
      expect(profile.currentLocationNote, 'Frente a librería');
      expect(profile.activeItems, 12);
      expect(profile.memberSince?.year, 2026);

      // Siglas con palabra única o sin nombre comercial
      final singleWord = SellerProfile.fromMap({
        'public_id': 'single-id',
        'display_name': 'Libreria',
      });
      expect(singleWord.storeInitials, 'LI');

      final emptyName = SellerProfile.fromMap({
        'public_id': 'empty-id',
        'display_name': '',
        'business_name': '',
      });
      expect(emptyName.storeInitials, 'US');
    });
  });

  group('MarketplaceSellerStatus Model', () {
    test('fromMap parsea límites, cupos y estado canPublish', () {
      final statusMap = {
        'can_publish': true,
        'reason': 'OK',
        'plan_id': 'free',
        'plan_name': 'Estudiante',
        'max_active_items': 3,
        'max_images_per_item': 2,
        'allow_video': false,
        'active_items': 1,
        'remaining_slots': 2,
        'expires_at': '2026-12-31T23:59:59.000Z',
        'seller_public_id': 'pub-1234',
        'seller_type': 'student',
        'verification_status': 'approved',
        'is_verified': true,
        'is_on_campus': false,
        'current_building_code': null,
      };

      final status = MarketplaceSellerStatus.fromJson(statusMap);
      expect(status.canPublish, isTrue);
      expect(status.reason, 'OK');
      expect(status.planId, 'free');
      expect(status.maxActiveItems, 3);
      expect(status.maxImagesPerItem, 2);
      expect(status.allowVideo, isFalse);
      expect(status.activeItems, 1);
      expect(status.remainingSlots, 2);
      expect(status.isUnlimited, isFalse);
      expect(status.sellerPublicId, 'pub-1234');
      expect(status.isVerified, isTrue);
      expect(status.isOnCampus, isFalse);

      final unlimitedMap = {
        'can_publish': true,
        'reason': 'OK',
        'plan_id': 'business_local',
        'plan_name': 'Comercio',
        'max_active_items': 0,
        'max_images_per_item': 10,
        'allow_video': true,
        'active_items': 35,
        'remaining_slots': null,
      };

      final unlimitedStatus = MarketplaceSellerStatus.fromMap(unlimitedMap);
      expect(unlimitedStatus.isUnlimited, isTrue);
      expect(unlimitedStatus.remainingSlots, -1);
      expect(unlimitedStatus.allowVideo, isTrue);
    });
  });

  group('MarketplaceMetrics Model', () {
    test('fromMap parsea métricas y calcula totalClicks correctamente', () {
      final map = {
        'item_id': 'item-metrics-123',
        'title': 'Libro Álgebra Lineal',
        'views': 120,
        'click_whatsapp': 15,
        'click_telegram': 5,
        'click_instagram': 3,
        'click_messenger': 2,
        'shares': 8,
        'contact_rate': 0.2083,
      };

      final metrics = MarketplaceMetrics.fromJson(map);
      expect(metrics.itemId, 'item-metrics-123');
      expect(metrics.title, 'Libro Álgebra Lineal');
      expect(metrics.views, 120);
      expect(metrics.clickWhatsapp, 15);
      expect(metrics.clickTelegram, 5);
      expect(metrics.clickInstagram, 3);
      expect(metrics.clickMessenger, 2);
      expect(metrics.shares, 8);
      expect(metrics.totalClicks, 25);
      expect(metrics.contactRate, 0.2083);

      final toMap = metrics.toMap();
      expect(toMap['item_id'], 'item-metrics-123');
      expect(toMap['views'], 120);
      expect(toMap['contact_rate'], 0.2083);
    });
  });

  group('MarketplaceException Model', () {
    test('formatea mensaje y código de error legible', () {
      const ex1 = MarketplaceException('Acceso no autorizado', code: '42501');
      expect(ex1.message, 'Acceso no autorizado');
      expect(ex1.code, '42501');
      expect(ex1.toString(), 'MarketplaceException: Acceso no autorizado (42501)');

      const ex2 = MarketplaceException('Error genérico');
      expect(ex2.code, isNull);
      expect(ex2.toString(), 'MarketplaceException: Error genérico');
    });
  });
}
