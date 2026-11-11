import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:comunidad_universitaria/core/constants/anonymous_aliases.dart';
import 'package:comunidad_universitaria/features/shared/widgets/alias_dice_button.dart';

void main() {
  group('AliasDiceButton Widget Tests', () {
    testWidgets(
      'Muestra alias actual y botón con icono casino_outlined y tooltip',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AliasDiceButton(
                alias: 'Compilador Desvelado',
                onAliasChanged: (_) {},
              ),
            ),
          ),
        );

        expect(find.text('Compilador Desvelado'), findsOneWidget);
        expect(find.byType(TextField), findsNothing);

        final diceBtn = find.byTooltip('Generar alias anónimo');
        expect(diceBtn, findsOneWidget);
        expect(find.byIcon(Icons.casino_outlined), findsOneWidget);
      },
    );

    testWidgets(
      'Al pulsar genera un alias válido del catálogo y llama onAliasChanged',
      (tester) async {
        String? updatedAlias;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AliasDiceButton(
                alias: 'Compilador Desvelado',
                onAliasChanged: (newVal) {
                  updatedAlias = newVal;
                },
              ),
            ),
          ),
        );

        final diceBtn = find.byTooltip('Generar alias anónimo');
        await tester.tap(diceBtn);
        await tester.pumpAndSettle();

        expect(updatedAlias, isNotNull);
        expect(updatedAlias!.isNotEmpty, isTrue);
        expect(AnonymousAliasGenerator.isValid(updatedAlias!), isTrue);
      },
    );
  });
}
