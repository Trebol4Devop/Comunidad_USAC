import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:comunidad_universitaria/core/config/app_theme.dart';
import 'package:comunidad_universitaria/features/legal/widgets/terms_consent_modal.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget buildTestApp({
    Future<void> Function()? onAcceptTerms,
    void Function(bool result)? onResult,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                final result = await TermsConsentModal.show(
                  context,
                  onAcceptTerms: onAcceptTerms,
                );
                onResult?.call(result);
              },
              child: const Text('Abrir Términos'),
            ),
          ),
        ),
      ),
    );
  }

  group('TermsConsentModal Widget Tests', () {
    testWidgets('Renderiza contenido obligatorio, versión y reglas clave', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(500, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp());
      await tester.tap(find.text('Abrir Términos'));
      await tester.pumpAndSettle();

      expect(
        find.text('Términos de Uso y Reglas de la Comunidad'),
        findsOneWidget,
      );
      expect(find.textContaining('v1.0-2026'), findsOneWidget);
      expect(find.textContaining('Art. 3'), findsOneWidget);
      expect(find.textContaining('Art. 12, 13, 14, 16'), findsOneWidget);
      expect(find.textContaining('Art. 20, 21'), findsOneWidget);
      expect(find.textContaining('HMAC'), findsWidgets);

      expect(
        find.text(
          'He leído y acepto los Términos y las Reglas de la Comunidad',
        ),
        findsOneWidget,
      );
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Aceptar y continuar'), findsOneWidget);
    });

    testWidgets(
      'Botón aceptar está deshabilitado sin checkbox y se habilita al marcarlo',
      (tester) async {
        tester.view.physicalSize = const Size(500, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestApp());
        await tester.tap(find.text('Abrir Términos'));
        await tester.pumpAndSettle();

        final acceptBtnFinder = find.widgetWithText(
          ElevatedButton,
          'Aceptar y continuar',
        );
        expect(acceptBtnFinder, findsOneWidget);

        ElevatedButton btn = tester.widget<ElevatedButton>(acceptBtnFinder);
        expect(btn.onPressed, isNull);

        // Marcamos el checkbox
        final checkboxFinder = find.byType(Checkbox);
        expect(checkboxFinder, findsOneWidget);
        await tester.tap(checkboxFinder);
        await tester.pumpAndSettle();

        btn = tester.widget<ElevatedButton>(acceptBtnFinder);
        expect(btn.onPressed, isNotNull);

        // Desmarcamos y vuelve a deshabilitarse
        await tester.tap(checkboxFinder);
        await tester.pumpAndSettle();

        btn = tester.widget<ElevatedButton>(acceptBtnFinder);
        expect(btn.onPressed, isNull);
      },
    );

    testWidgets('Cancelar devuelve false y cierra el modal', (tester) async {
      tester.view.physicalSize = const Size(500, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool? returnedResult;
      await tester.pumpWidget(
        buildTestApp(onResult: (res) => returnedResult = res),
      );
      await tester.tap(find.text('Abrir Términos'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.byType(TermsConsentModal), findsNothing);
      expect(returnedResult, isFalse);
    });

    testWidgets('Al marcar y aceptar ejecuta callback y devuelve true', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(500, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool calledAcceptCallback = false;
      bool? returnedResult;

      await tester.pumpWidget(
        buildTestApp(
          onAcceptTerms: () async {
            calledAcceptCallback = true;
          },
          onResult: (res) => returnedResult = res,
        ),
      );
      await tester.tap(find.text('Abrir Términos'));
      await tester.pumpAndSettle();

      // Marcamos checkbox
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      // Tap en aceptar
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Aceptar y continuar'),
      );
      await tester.pumpAndSettle();

      expect(calledAcceptCallback, isTrue);
      expect(returnedResult, isTrue);
      expect(find.byType(TermsConsentModal), findsNothing);
    });

    testWidgets(
      'Si el guardado falla, muestra SnackBar de error y devuelve false',
      (tester) async {
        tester.view.physicalSize = const Size(500, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        bool? returnedResult;

        await tester.pumpWidget(
          buildTestApp(
            onAcceptTerms: () async {
              throw Exception('Conexión rechazada por el servidor');
            },
            onResult: (res) => returnedResult = res,
          ),
        );
        await tester.tap(find.text('Abrir Términos'));
        await tester.pumpAndSettle();

        // Marcamos checkbox
        await tester.tap(find.byType(Checkbox));
        await tester.pumpAndSettle();

        // Tap aceptar
        await tester.tap(
          find.widgetWithText(ElevatedButton, 'Aceptar y continuar'),
        );
        await tester.pumpAndSettle();

        expect(returnedResult, isFalse);
        expect(find.textContaining('Conexión rechazada'), findsOneWidget);
      },
    );
  });
}
