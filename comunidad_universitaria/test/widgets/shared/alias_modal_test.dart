import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:comunidad_universitaria/core/config/app_theme.dart';
import 'package:comunidad_universitaria/features/profile/widgets/alias_modal.dart';
import '../../helpers/test_setup.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setupTestLifecycle();

  Widget buildTestModal({
    String currentAlias = 'Usuario Original #100',
    Function(String)? onAliasSaved,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: AliasModal(
          currentAlias: currentAlias,
          onAliasSaved: onAliasSaved ?? (_) {},
        ),
      ),
    );
  }

  group('AliasModal Widget Tests', () {
    testWidgets('Renderiza en vista móvil (400x800) con alias actual', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestModal());
      await tester.pumpAndSettle();

      expect(find.text('Tu Seudónimo Estudiantil'), findsOneWidget);
      expect(find.text('Aparece al publicar en el foro y compartir grupos'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Alias visible'), findsOneWidget);
      expect(find.text('Usuario Original #100'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Guardar Alias'), findsOneWidget);
    });

    testWidgets('Genera un seudónimo aleatorio al presionar el botón shuffle', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestModal());
      await tester.pumpAndSettle();

      final shuffleBtn = find.byTooltip('Generar aleatorio');
      expect(shuffleBtn, findsOneWidget);

      await tester.tap(shuffleBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('Estudiante USAC #'), findsOneWidget);
    });

    testWidgets('Guardar alias dispara callback con el nuevo valor ingresado', (tester) async {
      tester.view.physicalSize = const Size(600, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      String? savedAlias;

      await tester.pumpWidget(
        buildTestModal(
          onAliasSaved: (val) {
            savedAlias = val;
          },
        ),
      );
      await tester.pumpAndSettle();

      final field = find.widgetWithText(TextField, 'Alias visible');
      await tester.enterText(field, 'Arquitecto Sancarlista #999');
      await tester.pumpAndSettle();

      final saveBtn = find.text('Guardar Alias');
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(savedAlias, 'Arquitecto Sancarlista #999');
    });
  });
}
