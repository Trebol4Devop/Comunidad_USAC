import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:comunidad_universitaria/core/config/app_theme.dart';
import 'package:comunidad_universitaria/core/models/post.dart';
import 'package:comunidad_universitaria/features/forum/widgets/create_post_dialog.dart';
import '../../helpers/test_setup.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setupTestLifecycle();

  Widget buildTestDialog({
    String activeAlias = 'Estudiante Ingenioso #101',
    Post? quotedPost,
    Function(String)? onAliasChanged,
    Function(Post)? onPostCreated,
    String? initialCategory,
    String? initialCarrera,
    String? initialFacultad,
    String? serverName,
    String? channelName,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: CreatePostDialog(
          activeAlias: activeAlias,
          quotedPost: quotedPost,
          onAliasChanged: onAliasChanged ?? (_) {},
          onPostCreated: onPostCreated ?? (_) {},
          initialCategory: initialCategory,
          initialCarrera: initialCarrera,
          initialFacultad: initialFacultad,
          serverName: serverName,
          channelName: channelName,
        ),
      ),
    );
  }

  group('CreatePostDialog Widget Tests', () {
    testWidgets('Renderiza en vista móvil (400x800) con campos y badge de identidad anónima', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestDialog());
      await tester.pumpAndSettle();

      expect(find.text('Nueva Consulta en el Foro'), findsOneWidget);
      expect(find.text('Foro Estudiantil USAC · Espacio Libre'), findsOneWidget);

      // Campos de texto
      expect(find.widgetWithText(TextFormField, 'Título de la consulta o aporte'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Detalle o descripción'), findsOneWidget);

      // Botones de medios y encuesta
      expect(find.text('Foto'), findsOneWidget);
      expect(find.text('GIF'), findsOneWidget);
      expect(find.text('Encuesta'), findsOneWidget);

      // Botones de acción
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Publicar'), findsOneWidget);
    });

    testWidgets('Renderiza en vista escritorio (1200x800) en modo cita con post previo', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final quote = Post(
        id: 'post-1',
        title: 'Recomendaciones Física 1',
        content: '¿Quién es mejor catedrático para el curso?',
        authorAlias: 'Sancarlista #99',
        category: 'general',
        carrera: 'sistemas',
        createdAt: DateTime.now(),
        likes: 3,
        commentCount: 2,
      );

      await tester.pumpWidget(
        buildTestDialog(
          quotedPost: quote,
          serverName: 'Facultad de Ingeniería',
          channelName: 'primer-ingreso',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Citar Publicación'), findsOneWidget);
      expect(find.text('Citando a Sancarlista #99'), findsOneWidget);
      expect(find.text('Recomendaciones Física 1'), findsWidgets);
      expect(find.text('#primer-ingreso'), findsOneWidget);
      expect(find.text('Servidor: Facultad de Ingeniería'), findsOneWidget);
    });

    testWidgets('Valida campos requeridos y longitudes mínimas al intentar publicar', (tester) async {
      tester.view.physicalSize = const Size(600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestDialog());
      await tester.pumpAndSettle();

      // Tap publicar sin llenar campos
      await tester.tap(find.text('Publicar'));
      await tester.pumpAndSettle();

      // Debe mostrar mensajes de validación
      expect(find.text('El título debe tener al menos 5 caracteres.'), findsOneWidget);
      expect(find.text('El contenido debe tener al menos 10 caracteres.'), findsOneWidget);

      // Llenamos el título con < 5 caracteres
      final titleField = find.widgetWithText(TextFormField, 'Título de la consulta o aporte');
      await tester.enterText(titleField, 'Hola');
      await tester.tap(find.text('Publicar'));
      await tester.pumpAndSettle();

      expect(find.text('El título debe tener al menos 5 caracteres.'), findsOneWidget);

      // Llenamos con título válido
      await tester.enterText(titleField, '¿Horarios de Cálculo 1?');
      await tester.tap(find.text('Publicar'));
      await tester.pumpAndSettle();

      expect(find.text('El título debe tener al menos 5 caracteres.'), findsNothing);
      expect(find.text('El contenido debe tener al menos 10 caracteres.'), findsOneWidget);
    });

    testWidgets('Muestra y gestiona el formulario de encuestas (agregar y remover opciones)', (tester) async {
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestDialog());
      await tester.pumpAndSettle();

      // Inicialmente la encuesta no es visible
      expect(find.text('Crear Encuesta Estudiantil'), findsNothing);

      // Hacemos tap en el botón Encuesta
      await tester.tap(find.text('Encuesta'));
      await tester.pumpAndSettle();

      expect(find.text('Crear Encuesta Estudiantil'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Pregunta de la encuesta'), findsOneWidget);
      expect(find.text('Opción 1'), findsWidgets);
      expect(find.text('Opción 2'), findsWidgets);

      // Con 2 opciones no debe haber botón de borrar (el mínimo es 2)
      expect(find.byIcon(Icons.delete_outline), findsNothing);

      // Añadimos una opción más
      final addOptionBtn = find.text('Añadir opción');
      expect(addOptionBtn, findsOneWidget);
      await tester.tap(addOptionBtn);
      await tester.pumpAndSettle();

      // Ahora hay 3 opciones y deben aparecer botones de eliminar
      expect(find.byIcon(Icons.delete_outline), findsNWidgets(3));

      // Eliminamos la última opción
      await tester.tap(find.byIcon(Icons.delete_outline).last);
      await tester.pumpAndSettle();

      // Volvemos a tener 2 opciones
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });
  });
}
