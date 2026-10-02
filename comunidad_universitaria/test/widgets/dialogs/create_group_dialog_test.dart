import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:comunidad_universitaria/core/config/app_theme.dart';
import 'package:comunidad_universitaria/core/models/whatsapp_group.dart';
import 'package:comunidad_universitaria/features/groups/widgets/create_group_dialog.dart';
import '../../helpers/test_setup.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setupTestLifecycle();

  Widget buildTestDialog({
    String activeAlias = 'Líder Estudiantil #88',
    Function(String)? onAliasChanged,
    Function(WhatsAppGroup)? onGroupCreated,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: CreateGroupDialog(
          activeAlias: activeAlias,
          onAliasChanged: onAliasChanged ?? (_) {},
          onGroupCreated: onGroupCreated ?? (_) {},
        ),
      ),
    );
  }

  group('CreateGroupDialog Widget Tests', () {
    testWidgets('Renderiza en vista móvil (400x800) con campos para tipo curso', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestDialog());
      await tester.pumpAndSettle();

      expect(find.text('Compartir Enlace de Grupo'), findsOneWidget);
      expect(find.text('Publicado por: Líder Estudiantil #88'), findsOneWidget);

      // Selector de tipo y dropdowns
      expect(find.text('Tipo de Grupo / Propósito'), findsOneWidget);
      expect(find.text('Curso Académico'), findsOneWidget);

      // Campos específicos de curso
      expect(find.widgetWithText(TextFormField, 'Nombre del Curso'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Sección'), findsOneWidget);

      // Campo de enlace
      expect(find.widgetWithText(TextFormField, 'Enlace de Invitación'), findsOneWidget);

      // Botones
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Compartir Grupo'), findsOneWidget);
    });

    testWidgets('Cambiar tipo de grupo a no-curso muestra campo de propósito general', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestDialog());
      await tester.pumpAndSettle();

      // Inicialmente se ve Nombre del Curso
      expect(find.widgetWithText(TextFormField, 'Nombre del Curso'), findsOneWidget);

      // Abrimos dropdown de tipo de grupo
      final typeDropdown = find.text('Curso Académico');
      await tester.tap(typeDropdown);
      await tester.pumpAndSettle();

      // Seleccionamos Objetos Perdidos
      final lostOption = find.text('Objetos Perdidos & Hallazgos').last;
      await tester.tap(lostOption);
      await tester.pumpAndSettle();

      // Ahora debe desaparecer Nombre del Curso y aparecer título de objetos perdidos
      expect(find.widgetWithText(TextFormField, 'Nombre del Curso'), findsNothing);
      expect(find.widgetWithText(TextFormField, 'Título del Grupo de Objetos Perdidos'), findsOneWidget);
    });

    testWidgets('Valida campos requeridos y formato de enlace https://', (tester) async {
      tester.view.physicalSize = const Size(600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestDialog());
      await tester.pumpAndSettle();

      final submitBtn = find.text('Compartir Grupo');
      await tester.ensureVisible(submitBtn);

      // Tap compartir con campos vacíos
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Validaciones esperadas
      expect(find.text('Ingresa el nombre del curso'), findsOneWidget);
      expect(find.text('Pega el enlace de invitación del grupo.'), findsOneWidget);

      // Llenamos el nombre del curso
      final courseField = find.widgetWithText(TextFormField, 'Nombre del Curso');
      await tester.ensureVisible(courseField);
      await tester.enterText(courseField, 'Química General 1');

      // Llenamos un enlace inválido sin https
      final linkField = find.widgetWithText(TextFormField, 'Enlace de Invitación');
      await tester.ensureVisible(linkField);
      await tester.enterText(linkField, 'chat.whatsapp.com/invitacion123');

      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Debe exigir https://
      expect(find.text('Ingresa el nombre del curso'), findsNothing);
      expect(find.text('El enlace debe comenzar con https://'), findsOneWidget);
    });
  });
}
