import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:comunidad_universitaria/features/shared/widgets/anonymous_author_header.dart';

void main() {
  group('AnonymousAuthorHeader Widget Tests', () {
    test(
      'El mismo authorHash produce el mismo color en dos instancias (colorForHash)',
      () {
        const hash1 = 'a1b2c3d4e5f6';
        final colorA = AnonymousAuthorHeader.colorForHash(hash1);
        final colorB = AnonymousAuthorHeader.colorForHash(hash1);

        expect(colorA, equals(colorB));

        const hash2 = 'f6e5d4c3b2a1';
        final colorDifferent = AnonymousAuthorHeader.colorForHash(hash2);
        expect(colorA == colorDifferent, isFalse);
      },
    );

    testWidgets('Sin authorHash no se renderiza el chip', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnonymousAuthorHeader(
              authorAlias: 'Compilador Desvelado',
              authorHash: null,
            ),
          ),
        ),
      );

      expect(find.text('Compilador Desvelado'), findsOneWidget);
      // No debe contener ningún texto que empiece con #
      expect(find.textContaining('#'), findsNothing);
    });

    testWidgets('Con authorHash renderiza el chip compacto con prefijo #', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnonymousAuthorHeader(
              authorAlias: 'Compilador Desvelado',
              authorHash: 'abc123456789',
            ),
          ),
        ),
      );

      expect(find.text('#abc123'), findsOneWidget);
    });

    testWidgets('isOp == true renderiza "OP"', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnonymousAuthorHeader(
              authorAlias: 'Compilador Desvelado',
              isOp: true,
            ),
          ),
        ),
      );

      expect(find.text('OP'), findsOneWidget);
    });

    testWidgets('isOp == false no renderiza "OP"', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnonymousAuthorHeader(
              authorAlias: 'Compilador Desvelado',
              isOp: false,
            ),
          ),
        ),
      );

      expect(find.text('OP'), findsNothing);
    });

    testWidgets(
      'isMine == true renderiza "Tú" y el icono de eliminar cuando onDelete no es null',
      (tester) async {
        bool deleted = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnonymousAuthorHeader(
                authorAlias: 'Compilador Desvelado',
                isMine: true,
                onDelete: () {
                  deleted = true;
                },
              ),
            ),
          ),
        );

        expect(find.text('Tú'), findsOneWidget);
        final deleteIcon = find.byIcon(Icons.delete_outline);
        expect(deleteIcon, findsOneWidget);

        await tester.tap(deleteIcon);
        await tester.pumpAndSettle();

        expect(deleted, isTrue);
      },
    );

    testWidgets(
      'isMine == true con onDelete == null no renderiza icono de eliminar',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: AnonymousAuthorHeader(
                authorAlias: 'Compilador Desvelado',
                isMine: true,
                onDelete: null,
              ),
            ),
          ),
        );

        expect(find.text('Tú'), findsOneWidget);
        expect(find.byIcon(Icons.delete_outline), findsNothing);
      },
    );

    testWidgets('onReport != null && !isMine renderiza icono de bandera', (
      tester,
    ) async {
      bool reported = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnonymousAuthorHeader(
              authorAlias: 'Compilador Desvelado',
              isMine: false,
              onReport: () {
                reported = true;
              },
            ),
          ),
        ),
      );

      final flagIcon = find.byIcon(Icons.flag_outlined);
      expect(flagIcon, findsOneWidget);

      await tester.tap(flagIcon);
      await tester.pumpAndSettle();

      expect(reported, isTrue);
    });
  });
}
