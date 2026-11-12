import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:comunidad_universitaria/core/config/app_theme.dart';
import 'package:comunidad_universitaria/core/models/marketplace_item.dart';
import 'package:comunidad_universitaria/features/marketplace/widgets/marketplace_card.dart';
import 'package:comunidad_universitaria/features/shared/widgets/report_dialog.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  MarketplaceItem sponsoredItem() => MarketplaceItem(
    id: 'sponsored-1',
    title: 'Librería Universitaria',
    description: 'Libros y materiales para tus cursos.',
    category: 'libros_materiales',
    authorAlias: 'Vendedor #12',
    createdAt: DateTime(2026, 10, 1),
    isSponsored: true,
    sponsorBrandName: 'Librería USAC',
  );

  Widget buildCard({
    required VoidCallback onHide,
    required ValueChanged<String> onReport,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: SingleChildScrollView(
          child: MarketplaceCard(
            item: sponsoredItem(),
            onUpvote: () {},
            onSponsoredHide: onHide,
            onReport: onReport,
          ),
        ),
      ),
    );
  }

  group('Transparencia de contenido patrocinado', () {
    testWidgets('muestra etiqueta textual y nombre de marca en la card', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildCard(onHide: () {}, onReport: (_) {}));

      expect(find.text('Patrocinado'), findsOneWidget);
      expect(find.text('por Librería USAC'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Contenido patrocinado por Librería USAC'),
        findsOneWidget,
      );
      expect(
        tester
            .getSize(find.byTooltip('Opciones del contenido patrocinado'))
            .width,
        greaterThanOrEqualTo(48),
      );
    });

    testWidgets(
      'ofrece explicación, ocultamiento y reporte desde acciones móviles',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(() => tester.view.resetPhysicalSize());
        var hidden = false;
        String? reportedReason;

        await tester.pumpWidget(
          buildCard(
            onHide: () => hidden = true,
            onReport: (reason) => reportedReason = reason,
          ),
        );
        await tester.tap(find.byTooltip('Opciones del contenido patrocinado'));
        await tester.pumpAndSettle();

        expect(find.text('¿Por qué veo esto?'), findsOneWidget);
        expect(find.text('Ocultar este anuncio'), findsOneWidget);
        expect(find.text('Reportar'), findsOneWidget);

        await tester.tap(find.text('¿Por qué veo esto?'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('promocionado por Librería USAC'),
          findsOneWidget,
        );
        expect(
          find.textContaining('no se informa una razón de segmentación'),
          findsOneWidget,
        );
        await tester.tap(find.text('Cerrar'));
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Opciones del contenido patrocinado'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ocultar este anuncio'));
        await tester.pumpAndSettle();
        expect(hidden, isTrue);

        await tester.tap(find.byTooltip('Opciones del contenido patrocinado'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Reportar'));
        await tester.pumpAndSettle();
        expect(find.byType(ReportDialog), findsOneWidget);
        await tester.tap(find.text('Enviar Reporte'));
        await tester.pumpAndSettle();
        expect(reportedReason, isNotNull);
      },
    );
  });
}
