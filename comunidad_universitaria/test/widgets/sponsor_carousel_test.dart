import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:comunidad_universitaria/core/config/app_theme.dart';
import 'package:comunidad_universitaria/core/models/marketplace_item.dart';
import 'package:comunidad_universitaria/features/marketplace/widgets/sponsor_carousel.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget buildTestCarousel({
    List<MarketplaceItem> sponsoredItems = const [],
    VoidCallback? onRequestSponsor,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: SingleChildScrollView(
          child: SponsorCarousel(
            sponsoredItems: sponsoredItems,
            onRequestSponsor: onRequestSponsor ?? () {},
          ),
        ),
      ),
    );
  }

  group('SponsorCarousel Tests', () {
    testWidgets('Muestra banner de invitación y botón Anunciarme cuando la lista está vacía', (tester) async {
      bool requested = false;

      await tester.pumpWidget(
        buildTestCarousel(
          sponsoredItems: [],
          onRequestSponsor: () {
            requested = true;
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Espacio para Patrocinadores y Emprendimientos'), findsOneWidget);
      expect(find.text('Anunciarme'), findsOneWidget);

      await tester.tap(find.text('Anunciarme'));
      await tester.pumpAndSettle();

      expect(requested, isTrue);
    });

    testWidgets('Muestra detalles del patrocinador destacado y botón de WhatsApp', (tester) async {
      final sponsor = MarketplaceItem(
        id: 'spon-1',
        title: 'Librería & Fotocopiadora Central',
        description: 'Impresiones y útiles frente a Biblioteca Central.',
        price: 0,
        isFree: true,
        category: 'libros',
        facultad: '08',
        sede: 'central',
        buildingCode: 'T-3',
        locationDetail: 'Nivel 1',
        contactWhatsapp: '55551234',
        createdAt: DateTime.now(),
        authorAlias: 'Librería Central',
        isSponsored: true,
        sponsorBadgeText: 'PATROCINADOR OFICIAL',
      );

      await tester.pumpWidget(buildTestCarousel(sponsoredItems: [sponsor]));
      await tester.pumpAndSettle();

      expect(find.text('PATROCINADOR OFICIAL'), findsOneWidget);
      expect(find.text('Anunciarme aquí'), findsOneWidget);
      expect(find.text('Librería & Fotocopiadora Central'), findsOneWidget);
      expect(find.text('Impresiones y útiles frente a Biblioteca Central.'), findsOneWidget);
      expect(find.text('Contactar por WhatsApp'), findsOneWidget);
    });
  });
}
