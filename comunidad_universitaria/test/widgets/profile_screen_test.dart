import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:comunidad_universitaria/core/config/app_theme.dart';
import 'package:comunidad_universitaria/core/services/local_storage_service.dart';
import 'package:comunidad_universitaria/features/profile/screens/profile_screen.dart';
import 'package:comunidad_universitaria/features/shared/widgets/empty_state_widget.dart';
import '../helpers/test_setup.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setupTestLifecycle(initialPrefs: {
    'comunidad_user_alias': 'Estudiante Sancarlista #505',
  });

  setUp(() async {
    await LocalStorageService.saveAlias('Estudiante Sancarlista #505');
  });

  Widget buildTestProfile({
    String activeAlias = 'Estudiante Sancarlista #505',
    Function(String)? onAliasChanged,
    VoidCallback? onToggleTheme,
    bool isDarkMode = false,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: ProfileScreen(
        activeAlias: activeAlias,
        onAliasChanged: onAliasChanged ?? (_) {},
        onToggleTheme: onToggleTheme,
        isDarkMode: isDarkMode,
      ),
    );
  }

  group('ProfileScreen Widget Tests', () {
    testWidgets('permite volver a la pantalla principal desde el perfil', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ProfileScreen(
                      activeAlias: 'Estudiante Sancarlista #505',
                      onAliasChanged: (_) {},
                    ),
                  ),
                ),
                child: const Text('Abrir perfil'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir perfil'));
      await tester.pumpAndSettle();

      expect(find.text('Editar perfil'), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('Abrir perfil'), findsOneWidget);
    });

    testWidgets('Renderiza en móvil (400x800) con todas las secciones de perfil', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestProfile());
      await tester.pumpAndSettle();

      // Alias y modo anónimo protegido
      expect(find.text('Estudiante Sancarlista #505'), findsWidgets);
      expect(find.text('Modo Anónimo Protegido'), findsOneWidget);
      expect(find.text('Autenticación en dos pasos'), findsNothing);

      // Campos de edición principales
      expect(find.text('Seudónimo Visible en la Comunidad'), findsOneWidget);
      expect(find.text('Presentación o Bio Estudiantil'), findsOneWidget);

      // Tarjeta de validación de carné
      expect(find.text('Validación con Carné Universitario'), findsOneWidget);

      // Botón de guardar cambios
      expect(find.text('Guardar Cambios de Perfil'), findsOneWidget);

      // Pestañas de actividad
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.byType(Tab), findsNWidgets(3));
    });

    testWidgets('Renderiza en escritorio (1200x800) con distribución en columnas', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestProfile());
      await tester.pumpAndSettle();

      // Secciones académicas y de contacto
      expect(find.text('Información Académica'), findsWidgets);
      expect(find.text('Canales de Contacto'), findsWidgets);

      // Campos de contacto
      expect(find.widgetWithText(TextField, 'WhatsApp Predeterminado'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Telegram'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Instagram'), findsOneWidget);
    });

    testWidgets('Permite generar un nuevo seudónimo aleatorio y editar la bio', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestProfile());
      await tester.pumpAndSettle();

      // Botón de generar alias aleatorio (ícono shuffle)
      final shuffleButton = find.byTooltip('Generar seudónimo aleatorio');
      expect(shuffleButton, findsOneWidget);

      await tester.tap(shuffleButton);
      await tester.pumpAndSettle();

      // El campo debe haber sido actualizado con el prefijo 'Estudiante USAC #'
      expect(find.textContaining('Estudiante USAC #'), findsWidgets);

      // Editamos la bio estudiantil
      final bioField = find.widgetWithText(TextField, 'Presentación o Bio Estudiantil');
      expect(bioField, findsOneWidget);

      await tester.enterText(bioField, 'Estudiante entusiasta de Ingeniería de Software USAC.');
      await tester.pumpAndSettle();

      expect(find.text('Estudiante entusiasta de Ingeniería de Software USAC.'), findsOneWidget);
    });

    testWidgets('Guardar perfil dispara onAliasChanged y muestra SnackBar de confirmación', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      String? updatedAlias;

      await tester.pumpWidget(
        buildTestProfile(
          activeAlias: 'Usuario Inicial',
          onAliasChanged: (newVal) {
            updatedAlias = newVal;
          },
        ),
      );
      await tester.pumpAndSettle();

      final aliasField = find.widgetWithText(TextField, 'Seudónimo Visible en la Comunidad');
      await tester.enterText(aliasField, 'Ingeniero Actualizado #777');
      await tester.pumpAndSettle();

      final saveButton = find.text('Guardar Cambios de Perfil');
      expect(saveButton, findsOneWidget);

      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Debe haber llamado a onAliasChanged con el nuevo valor
      expect(updatedAlias, 'Ingeniero Actualizado #777');

      // Debe mostrar SnackBar de éxito
      expect(find.text('Perfil guardado exitosamente.'), findsOneWidget);
    });

    testWidgets('Navegación entre pestañas de actividad muestra sus respectivos estados vacíos', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestProfile());
      await tester.pumpAndSettle();

      // Tab inicial: Mis Posts vacío
      expect(find.byType(EmptyStateWidget), findsOneWidget);
      expect(find.text('Sin publicaciones en el foro'), findsOneWidget);

      // Scroll para que TabBar esté bien visible
      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -350));
      await tester.pumpAndSettle();

      // Cambiar a pestaña Mis Grupos (índice 1)
      await tester.tap(find.byType(Tab).at(1));
      await tester.pumpAndSettle();

      expect(find.text('Sin grupos de estudio compartidos'), findsOneWidget);

      // Cambiar a pestaña Mis Anuncios (índice 2)
      await tester.tap(find.byType(Tab).at(2));
      await tester.pumpAndSettle();

      expect(find.text('Sin anuncios en el Marketplace'), findsOneWidget);
    });
  });
}
