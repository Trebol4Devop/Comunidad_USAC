import 'package:flutter_test/flutter_test.dart';
import 'package:comunidad_universitaria/core/constants/categories.dart';
import 'package:comunidad_universitaria/core/models/facultad.dart';
import 'package:comunidad_universitaria/core/models/marketplace_item.dart';
import 'package:comunidad_universitaria/core/services/marketplace_service.dart';

void main() {
  group('Catálogo Académico y Sedes', () {
    test('Contiene todas las 10 facultades y Humanidades con sus códigos oficiales', () {
      final facultades = USACConstants.facultades;
      expect(facultades.length, greaterThanOrEqualTo(11));

      final agronomia = facultades.firstWhere((f) => f['id'] == '01');
      expect(agronomia['nombre'], contains('Agronomía'));
      expect(agronomia['sitio'], 'http://fausac.gt/');

      final carrerasAgro = (agronomia['carreras'] as List);
      expect(carrerasAgro.any((c) => c['codigo'] == '01-00-02'), isTrue);

      final humanidades = facultades.firstWhere((f) => f['id'] == '07');
      expect(humanidades['codigo'], '77');
      expect(humanidades['nombre'], contains('Humanidades'));
      final carrerasHum = (humanidades['carreras'] as List);
      expect(carrerasHum.any((c) => c['codigo'] == '77-00-55'), isTrue);

      final ingenieria = facultades.firstWhere((f) => f['id'] == '08');
      final carrerasIng = (ingenieria['carreras'] as List);
      expect(carrerasIng.any((c) => c['codigo'] == '08-00-09'), isTrue); // Sistemas
    });

    test('Catálogo de Sedes y Campus Buildings estructurados para mapa interactivo', () {
      expect(USACConstants.sedes.length, greaterThanOrEqualTo(20));
      expect(USACConstants.sedes.any((s) => s['id'] == 'central'), isTrue);
      expect(USACConstants.sedes.any((s) => s['id'] == 'cum'), isTrue);
      expect(USACConstants.sedes.any((s) => s['id'] == 'cunoc'), isTrue);

      final buildings = USACConstants.campusBuildings;
      expect(buildings.length, greaterThanOrEqualTo(10));
      final t3 = buildings.firstWhere((b) => b['id'] == 't3');
      expect(t3['building_code'], 'T-3');
      expect(t3['latitude'], isNotNull);
      expect(t3['longitude'], isNotNull);

      final locModel = CampusLocation.fromMap(t3);
      expect(locModel.buildingCode, 'T-3');
      expect(locModel.latitude, closeTo(14.588, 0.01));
    });
  });

  group('Marketplace Estudiantil y Modelos', () {
    test('Formateo de precio correcto (Qxx.xx vs GRATIS)', () {
      final freeItem = MarketplaceItem(
        id: '1',
        title: 'Tutoría de Mate 1',
        description: 'Tutoría gratuita de repaso',
        price: 0.0,
        isFree: true,
        category: 'tutorias_academica',
        contactWhatsapp: '55551122',
        authorAlias: 'Tutor #1',
        createdAt: DateTime.now(),
      );
      expect(freeItem.formattedPrice, 'GRATIS');

      final paidItem = MarketplaceItem(
        id: '2',
        title: 'Pastel de Zanahoria',
        description: 'Deliciosa porción',
        price: 15.50,
        isFree: false,
        category: 'comida_postres',
        contactWhatsapp: '44443322',
        authorAlias: 'Repostero #2',
        createdAt: DateTime.now(),
      );
      expect(paidItem.formattedPrice, 'Q15.50');
    });

    test('Generación de enlace directo de WhatsApp con mensaje personalizado', () {
      final item = MarketplaceItem(
        id: '3',
        title: 'Calculadora TI-84',
        description: 'Calculadora científica',
        price: 300.0,
        category: 'libros_materiales',
        contactWhatsapp: '50255554433',
        authorAlias: 'Vendedor #3',
        createdAt: DateTime.now(),
      );

      final waUrl = item.whatsappUrl;
      expect(waUrl, startsWith('https://wa.me/50255554433?text='));
      expect(waUrl, contains('Calculadora%20TI-84'));
    });

    test('Serialización y Deserialización de MarketplaceItem', () {
      final original = MarketplaceItem(
        id: 'test-100',
        title: 'Libro de Física 1',
        description: 'En buen estado',
        price: 75.0,
        isFree: false,
        category: 'libros_materiales',
        facultad: '08',
        sede: 'central',
        buildingCode: 'T-3',
        locationDetail: '2do nivel',
        contactWhatsapp: '50212345678',
        imageUrls: ['https://ejemplo.com/foto.jpg'],
        videoUrl: 'https://youtube.com/video',
        isSponsored: true,
        sponsorBadgeText: 'Patrocinador VIP',
        authorAlias: 'Estudiante #99',
        createdAt: DateTime.now(),
        upvotes: 5,
        isUpvotedByMe: true,
      );

      final insertMap = original.toInsertMap();
      expect(insertMap['title'], 'Libro de Física 1');
      expect(insertMap['price'], 75.0);
      expect(insertMap['is_sponsored'], isTrue);
      expect(insertMap['building_code'], 'T-3');

      final fromMap = MarketplaceItem.fromMap(insertMap, isUpvotedByMe: true);
      expect(fromMap.title, original.title);
      expect(fromMap.price, original.price);
      expect(fromMap.isSponsored, isTrue);
      expect(fromMap.isUpvotedByMe, isTrue);
    });

    test('Filtrado en MarketplaceService (Mock Fallback)', () async {
      final all = await MarketplaceService.fetchListings();
      expect(all.isNotEmpty, isTrue);

      final freeOnly = await MarketplaceService.fetchListings(onlyFree: true);
      for (var item in freeOnly) {
        expect(item.isFree || item.price <= 0.0, isTrue);
      }

      final sponsored = await MarketplaceService.fetchSponsoredListings();
      expect(sponsored.every((s) => s.isSponsored), isTrue);
    });
  });
}
