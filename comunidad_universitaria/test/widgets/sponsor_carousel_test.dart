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
    ValueChanged<MarketplaceItem>? onHideSponsored,
    Function(MarketplaceItem item, String reason)? onReportSponsored,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: SingleChildScrollView(
          child: SponsorCarousel(
            sponsoredItems: sponsoredItems,
            onRequestSponsor: onRequestSponsor ?? () {},
            onHideSponsored: onHideSponsored ?? (_) {},
            onReportSponsored: onReportSponsored ?? (_, _) {},
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

    testWidgets('Conecta ocultamiento y reporte del anuncio patrocinado', (tester) async {
      final sponsor = MarketplaceItem(
        id: 'spon-actions',
        title: 'Anuncio de prueba',
        description: 'Contenido promocionado.',
        category: 'libros',
        authorAlias: 'Marca de prueba',
        createdAt: DateTime.now(),
        isSponsored: true,
      );
      MarketplaceItem? hiddenItem;
      MarketplaceItem? reportedItem;
      String? reportReason;

      await tester.pumpWidget(
        buildTestCarousel(
          sponsoredItems: [sponsor],
          onHideSponsored: (item) => hiddenItem = item,
          onReportSponsored: (item, reason) {
            reportedItem = item;
            reportReason = reason;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Opciones del contenido patrocinado'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ocultar este anuncio'));
      await tester.pumpAndSettle();
      expect(hiddenItem?.id, 'spon-actions');

      await tester.tap(find.byTooltip('Opciones del contenido patrocinado'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reportar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enviar Reporte'));
      await tester.pumpAndSettle();
      expect(reportedItem?.id, 'spon-actions');
      expect(reportReason, isNotNull);
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
        sponsorBrandName: 'Librería Central',
      );

      await tester.pumpWidget(buildTestCarousel(sponsoredItems: [sponsor]));
      await tester.pumpAndSettle();

      expect(find.text('Patrocinado'), findsOneWidget);
      expect(find.text('por Librería Central'), findsOneWidget);
      expect(find.text('Anunciarme aquí'), findsOneWidget);
      expect(find.text('Librería & Fotocopiadora Central'), findsOneWidget);
      expect(find.text('Impresiones y útiles frente a Biblioteca Central.'), findsOneWidget);
      expect(find.text('Contactar por WhatsApp'), findsOneWidget);
    });
  });
}
