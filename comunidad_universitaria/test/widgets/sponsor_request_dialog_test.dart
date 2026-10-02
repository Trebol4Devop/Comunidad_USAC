import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:comunidad_universitaria/core/config/app_theme.dart';
import 'package:comunidad_universitaria/features/marketplace/widgets/sponsor_request_dialog.dart';
import '../helpers/test_setup.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setupTestLifecycle();

  Widget buildTestDialog() {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: const Scaffold(
        body: SponsorRequestDialog(),
      ),
    );
  }

  group('SponsorRequestDialog Tests', () {
    testWidgets('Renderiza en vista móvil (400x800) con todos los campos del formulario', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestDialog());
      await tester.pumpAndSettle();

      expect(find.text('Solicitar Espacio de Patrocinador'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Nombre del Emprendimiento, Marca o Negocio'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Nombre del Encargado'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'WhatsApp'), findsOneWidget);
      expect(find.widgetWithText(DropdownButtonFormField<String>, 'Espacio Deseado'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Detalle de la propuesta o productos a promocionar'), findsOneWidget);

      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Enviar Solicitud'), findsOneWidget);
    });

    testWidgets('Valida campos requeridos al enviar formulario vacío', (tester) async {
      tester.view.physicalSize = const Size(600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestDialog());
      await tester.pumpAndSettle();

      final submitBtn = find.text('Enviar Solicitud');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Ingresa el nombre del negocio'), findsOneWidget);
      expect(find.text('Ingresa tu nombre'), findsOneWidget);
      expect(find.text('Ingresa tu WhatsApp'), findsOneWidget);
      expect(find.text('Describe tu propuesta'), findsOneWidget);
    });
  });
}
