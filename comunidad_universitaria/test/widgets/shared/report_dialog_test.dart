import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:comunidad_universitaria/core/config/app_theme.dart';
import 'package:comunidad_universitaria/features/shared/widgets/report_dialog.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget buildTestDialog({
    String title = 'Reportar Contenido',
    String subtitle = 'Ayúdanos a mantener la comunidad segura.',
    Function(String)? onReportSubmitted,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: ReportDialog(
          title: title,
          subtitle: subtitle,
          onReportSubmitted: onReportSubmitted ?? (_) {},
        ),
      ),
    );
  }

  group('ReportDialog Widget Tests', () {
    testWidgets('Renderiza en vista móvil (400x800) con lista de motivos de reporte', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestDialog());
      await tester.pumpAndSettle();

      expect(find.text('Reportar Contenido'), findsOneWidget);
      expect(find.text('Ayúdanos a mantener la comunidad segura.'), findsOneWidget);
      expect(find.text('Selecciona el motivo del reporte:'), findsOneWidget);

      // Opciones por default
      expect(find.text('Acoso / Difamación'), findsOneWidget);
      expect(find.text('Spam / Publicidad engañosa'), findsOneWidget);
      expect(find.text('Otro motivo'), findsOneWidget);

      // Botones
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Enviar Reporte'), findsOneWidget);
    });

    testWidgets('Seleccionar motivo predeterminado envía ese motivo', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      String? reportedReason;

      await tester.pumpWidget(
        buildTestDialog(
          onReportSubmitted: (reason) {
            reportedReason = reason;
          },
        ),
      );
      await tester.pumpAndSettle();

      // Seleccionamos Spam
      await tester.tap(find.text('Spam / Publicidad engañosa'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Enviar Reporte'));
      await tester.pumpAndSettle();

      expect(reportedReason, 'Spam / Publicidad engañosa');
    });

    testWidgets('Seleccionar Otro motivo despliega campo de texto para razón personalizada', (tester) async {
      tester.view.physicalSize = const Size(600, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      String? reportedReason;

      await tester.pumpWidget(
        buildTestDialog(
          onReportSubmitted: (reason) {
            reportedReason = reason;
          },
        ),
      );
      await tester.pumpAndSettle();

      // Campo no debe existir aún
      expect(find.widgetWithText(TextField, 'Explica brevemente la razón...'), findsNothing);

      // Seleccionamos 'Otro motivo'
      await tester.tap(find.text('Otro motivo'));
      await tester.pumpAndSettle();

      // Ahora el campo debe ser visible
      final customField = find.widgetWithText(TextField, 'Explica brevemente la razón...');
      expect(customField, findsOneWidget);

      // Escribimos motivo personalizado
      await tester.enterText(customField, 'Enlace roto o fraudulento');
      await tester.tap(find.text('Enviar Reporte'));
      await tester.pumpAndSettle();

      expect(reportedReason, 'Enlace roto o fraudulento');
    });
  });
}
