import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:comunidad_universitaria/core/models/seccion_review.dart';
import 'package:comunidad_universitaria/features/reviews/widgets/create_seccion_review_dialog.dart';

void main() {
  testWidgets('CreateSeccionReviewDialog valida campos obligatorios', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CreateSeccionReviewDialog())),
    );

    // Intentar guardar con campos vacíos
    final submitButton = find.byKey(const Key('guardar_review_button'));
    expect(submitButton, findsOneWidget);

    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    // Deben mostrarse mensajes de error de validación
    expect(find.text('Obligatorio'), findsWidgets);
  });

  testWidgets(
    'CreateSeccionReviewDialog permite editar campos, cambiar sliders y recomienda',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool? capturedRecomienda;
      int? capturedDificultad;
      int? capturedCargaTareas;
      String? capturedCurso;
      String? capturedSeccion;
      String? capturedCatedratico;

      Future<SeccionReview?> mockHandler({
        required String cursoCodigo,
        required String seccion,
        required bool recomienda,
        String? catedraticoNombre,
        int? dificultad,
        int? cargaTareas,
        String? comentario,
        String semestre = '1S-2026',
      }) async {
        capturedCurso = cursoCodigo;
        capturedSeccion = seccion;
        capturedRecomienda = recomienda;
        capturedCatedratico = catedraticoNombre;
        capturedDificultad = dificultad;
        capturedCargaTareas = cargaTareas;

        return SeccionReview(
          id: 'review-1',
          cursoCodigo: cursoCodigo,
          seccion: seccion,
          recomienda: recomienda,
          catedraticoNombre: catedraticoNombre,
          dificultad: dificultad,
          cargaTareas: cargaTareas,
          comentario: comentario,
          semestre: semestre,
          upvotes: 0,
          createdAt: DateTime.now(),
          isMine: true,
        );
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreateSeccionReviewDialog(createReviewHandler: mockHandler),
          ),
        ),
      );

      // Llenar campos de texto
      await tester.enterText(
        find.byKey(const Key('curso_codigo_input')),
        '0770',
      );
      await tester.enterText(find.byKey(const Key('seccion_input')), 'A');
      await tester.enterText(
        find.byKey(const Key('catedratico_input')),
        'Ing. Perez',
      );

      // Cambiar switch de recomienda
      final switchFinder = find.byKey(const Key('recomienda_switch'));
      expect(switchFinder, findsOneWidget);
      await tester.ensureVisible(switchFinder);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // Sliders de dificultad y carga
      final dificultadSlider = find.byKey(const Key('dificultad_slider'));
      expect(dificultadSlider, findsOneWidget);

      final cargaSlider = find.byKey(const Key('carga_tareas_slider'));
      expect(cargaSlider, findsOneWidget);

      // Escribir comentario
      final comentarioInput = find.byKey(const Key('comentario_input'));
      await tester.ensureVisible(comentarioInput);
      await tester.enterText(
        comentarioInput,
        'Excelente curso, muy recomendado estudiar constantes.',
      );
      await tester.pumpAndSettle();

      // Guardar
      final submitButton = find.byKey(const Key('guardar_review_button'));
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // Verificar que los datos capturados corresponden a los ingresados
      expect(capturedCurso, '0770');
      expect(capturedSeccion, 'A');
      expect(capturedRecomienda, false);
      expect(capturedCatedratico, 'Ing. Perez');
      expect(capturedDificultad, isNotNull);
      expect(capturedCargaTareas, isNotNull);
    },
  );

  testWidgets(
    'CreateSeccionReviewDialog se abre y cierra desde método show() en modal',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => CreateSeccionReviewDialog.show(context),
                  child: const Text('Abrir Modal'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Nueva Reseña de Sección'), findsOneWidget);

      // Cancelar/cerrar modal con el botón de cerrar superior o cancelar
      final cancelButton = find.text('Cancelar');
      await tester.ensureVisible(cancelButton);
      await tester.tap(cancelButton);
      await tester.pumpAndSettle();

      expect(find.text('Nueva Reseña de Sección'), findsNothing);
    },
  );
}
