import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:comunidad_universitaria/core/models/seccion_review.dart';
import 'package:comunidad_universitaria/features/reviews/screens/seccion_reviews_screen.dart';

void main() {
  testWidgets(
    'SeccionReviewsScreen renderiza estado vacío cuando no hay reseñas',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: SeccionReviewsScreen(
            loader: ({cursoCodigo, seccion, semestre}) async => [],
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Comprobar estado vacío
      expect(
        find.text('Aún no hay reseñas para este curso. ¡Sé el primero!'),
        findsOneWidget,
      );

      // Comprobar botón de "Nueva reseña"
      expect(find.text('Nueva reseña'), findsOneWidget);
    },
  );

  testWidgets(
    'SeccionReviewsScreen muestra curso, catedrático, Recomienda y contador de upvotes',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final testReview = SeccionReview(
        id: 'rev-101',
        cursoCodigo: '0770',
        seccion: 'A',
        recomienda: true,
        catedraticoNombre: 'Ing. Moisés Velásquez',
        dificultad: 4,
        cargaTareas: 3,
        comentario: 'Curso exigente pero se aprende bastante.',
        semestre: '1S-2026',
        upvotes: 12,
        createdAt: DateTime(2026, 3, 15),
        isMine: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SeccionReviewsScreen(
            loader: ({cursoCodigo, seccion, semestre}) async => [testReview],
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verifica que se muestra curso + sección
      expect(find.text('0770 · Sección A'), findsOneWidget);

      // Verifica catedrático
      expect(find.text('Ing. Moisés Velásquez'), findsOneWidget);

      // Verifica badge 'Recomienda'
      expect(find.text('Recomienda'), findsOneWidget);

      // Verifica 'Tú' por ser isMine
      expect(find.text('Tú'), findsOneWidget);

      // Verifica contador de upvotes
      expect(find.text('12'), findsOneWidget);

      // Verifica comentario
      expect(
        find.text('Curso exigente pero se aprende bastante.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'SeccionReviewsScreen botón Nueva reseña abre el diálogo de creación',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: SeccionReviewsScreen(
            loader: ({cursoCodigo, seccion, semestre}) async => [],
            consentGate: (ctx) async => true,
          ),
        ),
      );

      await tester.pumpAndSettle();

      final fab = find.byKey(const Key('nueva_reseña_fab'));
      expect(fab, findsOneWidget);

      await tester.tap(fab);
      await tester.pumpAndSettle();

      // Debe abrirse el formulario de creación
      expect(find.text('Nueva Reseña de Sección'), findsOneWidget);
      expect(find.byKey(const Key('curso_codigo_input')), findsOneWidget);
      expect(find.byKey(const Key('seccion_input')), findsOneWidget);
    },
  );

  testWidgets(
    'SeccionReviewsScreen botón de upvote invoca callback y actualiza',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      int upvotes = 5;
      bool upvoteCalled = false;

      final review = SeccionReview(
        id: 'rev-202',
        cursoCodigo: '0771',
        seccion: 'B',
        recomienda: false,
        catedraticoNombre: 'Ing. Perez',
        dificultad: 5,
        cargaTareas: 5,
        comentario: 'Mucha carga.',
        semestre: '2S-2025',
        upvotes: upvotes,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SeccionReviewsScreen(
            loader: ({cursoCodigo, seccion, semestre}) async => [
              review.copyWith(upvotes: upvotes),
            ],
            upvoteHandler: (id) async {
              upvoteCalled = true;
              upvotes++;
              return true;
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Upvote inicial
      expect(find.text('5'), findsOneWidget);
      expect(find.text('No recomienda'), findsOneWidget);

      final upvoteBtn = find.byKey(const Key('upvote_button_rev-202'));
      expect(upvoteBtn, findsOneWidget);

      await tester.tap(upvoteBtn);
      await tester.pumpAndSettle();

      expect(upvoteCalled, isTrue);
      expect(find.text('6'), findsOneWidget);
    },
  );

  testWidgets('SeccionReviewsScreen aplica filtros de curso y sección', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    String? passedCurso;
    String? passedSeccion;
    String? passedSemestre;

    await tester.pumpWidget(
      MaterialApp(
        home: SeccionReviewsScreen(
          loader: ({cursoCodigo, seccion, semestre}) async {
            passedCurso = cursoCodigo;
            passedSeccion = seccion;
            passedSemestre = semestre;
            return [];
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Escribir en filtros
    await tester.enterText(
      find.byKey(const Key('filtro_curso_codigo')),
      '0772',
    );
    await tester.enterText(find.byKey(const Key('filtro_seccion')), 'C');

    // Seleccionar chip de semestre '1S-2026'
    await tester.tap(find.text('1S-2026'));
    await tester.pumpAndSettle();

    expect(passedCurso, '0772');
    expect(passedSeccion, 'C');
    expect(passedSemestre, '1S-2026');
  });
}
