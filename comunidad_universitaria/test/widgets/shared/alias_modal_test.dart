import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:comunidad_universitaria/core/config/app_theme.dart';
import 'package:comunidad_universitaria/core/constants/anonymous_aliases.dart';
import 'package:comunidad_universitaria/features/profile/widgets/alias_modal.dart';
import '../../helpers/test_setup.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setupTestLifecycle();

  Widget buildTestModal({
    String currentAlias = 'Compilador Desvelado',
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
    testWidgets('Renderiza en vista móvil (400x800) sin TextField editable', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestModal());
      await tester.pumpAndSettle();

      expect(find.text('Tu Seudónimo Estudiantil'), findsOneWidget);
      expect(
        find.text('Aparece al publicar en el foro y compartir grupos'),
        findsOneWidget,
      );
      // Ya NO debe existir un TextField editable de alias
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Compilador Desvelado'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Guardar Alias'), findsOneWidget);
      expect(find.textContaining('Art. 12'), findsOneWidget);
    });

    testWidgets(
      'Al pulsar el botón de dados, el alias cambia y sigue el patrón del catálogo',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          buildTestModal(currentAlias: 'Compilador Desvelado'),
        );
        await tester.pumpAndSettle();

        final diceBtn = find.byTooltip('Generar alias anónimo');
        expect(diceBtn, findsOneWidget);

        await tester.tap(diceBtn);
        await tester.pumpAndSettle();

        // El alias anterior no debe estar visible si se generó uno nuevo
        // Buscamos cualquier Text widget que sea un alias válido del catálogo
        final textWidgets = tester.widgetList<Text>(find.byType(Text));
        final generatedAliases = textWidgets
            .map((w) => w.data ?? '')
            .where((txt) => AnonymousAliasGenerator.isValid(txt))
            .toList();

        expect(generatedAliases.isNotEmpty, isTrue);
        final newAlias = generatedAliases.first;
        expect(AnonymousAliasGenerator.isValid(newAlias), isTrue);
      },
    );

    testWidgets('Guardar dispara callback con un alias válido generado', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(600, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      String? savedAlias;

      await tester.pumpWidget(
        buildTestModal(
          currentAlias: 'Compilador Desvelado',
          onAliasSaved: (val) {
            savedAlias = val;
          },
        ),
      );
      await tester.pumpAndSettle();

      final diceBtn = find.byTooltip('Generar alias anónimo');
      await tester.tap(diceBtn);
      await tester.pumpAndSettle();

      final saveBtn = find.text('Guardar Alias');
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(savedAlias, isNotNull);
      expect(AnonymousAliasGenerator.isValid(savedAlias!), isTrue);
    });
  });
}
