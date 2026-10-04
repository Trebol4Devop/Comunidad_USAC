import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:comunidad_universitaria/core/config/app_theme.dart';
import 'package:comunidad_universitaria/features/forum/screens/forum_screen.dart';
import 'package:comunidad_universitaria/features/groups/screens/groups_screen.dart';
import 'package:comunidad_universitaria/features/marketplace/screens/marketplace_screen.dart';
import 'package:comunidad_universitaria/features/navigation/app_shell.dart';
import 'package:comunidad_universitaria/features/profile/screens/profile_screen.dart';
import 'package:comunidad_universitaria/features/rules/screens/rules_screen.dart';
import 'package:comunidad_universitaria/features/shared/widgets/alias_badge_button.dart';
import '../helpers/test_setup.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setupTestLifecycle();

  Widget buildTestShell({
    required String activeAlias,
    Function(String)? onAliasChanged,
    VoidCallback? onToggleTheme,
    bool isDarkMode = false,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: AppShell(
        activeAlias: activeAlias,
        onAliasChanged: onAliasChanged ?? (_) {},
        onToggleTheme: onToggleTheme ?? () {},
        isDarkMode: isDarkMode,
      ),
    );
  }

  group('AppShell Widget Tests', () {
    testWidgets('Renderiza en vista móvil (400x800) con NavigationBar y alias activo', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestShell(activeAlias: 'Estudiante #101'),
      );
      await tester.pumpAndSettle();

      // En móvil muestra título 'Comunidad USAC' y 'No Oficial'
      expect(find.text('Comunidad USAC'), findsOneWidget);
      expect(find.text('No Oficial'), findsOneWidget);
      expect(find.text('Red Estudiantil Autónoma'), findsNothing);

      // Botón de perfil ya no se muestra en el navbar (se ubica en la barra inferior)
      expect(find.byType(AliasBadgeButton), findsNothing);

      // Bottom NavigationBar en móvil
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Foro'), findsOneWidget);
      expect(find.text('Grupos'), findsOneWidget);
      expect(find.text('Marketplace'), findsOneWidget);

      // En el tab inicial (Foro), no hay FloatingActionButton
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('Renderiza en escritorio (1200x800) con pestañas superiores y sin NavigationBar', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestShell(activeAlias: 'Ingeniero #404'),
      );
      await tester.pumpAndSettle();

      // En escritorio muestra título 'Comunidad Universitaria'
      expect(find.text('Comunidad Universitaria'), findsOneWidget);

      // No debe tener NavigationBar inferior
      expect(find.byType(NavigationBar), findsNothing);

      // Pestañas de escritorio
      expect(find.text('Foro Estudiantil'), findsOneWidget);
      expect(find.text('Grupos de Estudio'), findsOneWidget);
      expect(find.text('Marketplace & Tutorías'), findsOneWidget);
    });

    testWidgets('Navegación móvil entre tabs y verificación de FloatingActionButton contextual', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestShell(activeAlias: 'Tester USAC'),
      );
      await tester.pumpAndSettle();

      // Tab 0: ForumScreen activo por defecto
      expect(find.byType(ForumScreen), findsOneWidget);

      // Cambiar a Tab 1: Grupos
      final gruposTab = find.text('Grupos');
      await tester.tap(gruposTab);
      await tester.pumpAndSettle();

      // Debe mostrar el FAB contextual de grupos 'Sugerir Enlace'
      expect(find.widgetWithText(FloatingActionButton, 'Sugerir Enlace'), findsOneWidget);

      // Cambiar a Tab 2: Marketplace
      final marketTab = find.text('Marketplace');
      await tester.tap(marketTab);
      await tester.pumpAndSettle();

      // Debe mostrar el FAB contextual de marketplace 'Publicar Artículo'
      expect(find.widgetWithText(FloatingActionButton, 'Publicar Artículo'), findsOneWidget);
    });

    testWidgets('Navegación escritorio entre tabs superiores', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestShell(activeAlias: 'Desktop User'),
      );
      await tester.pumpAndSettle();

      // Seleccionar Grupos de Estudio
      final tabGrupos = find.text('Grupos de Estudio');
      await tester.tap(tabGrupos);
      await tester.pumpAndSettle();

      expect(find.byType(GroupsScreen), findsOneWidget);

      // Seleccionar Marketplace & Tutorías
      final tabMarket = find.text('Marketplace & Tutorías');
      await tester.tap(tabMarket);
      await tester.pumpAndSettle();

      expect(find.byType(MarketplaceScreen), findsOneWidget);
    });

    testWidgets('Botón de cambio de tema dispara callback onToggleTheme', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool themeToggled = false;

      await tester.pumpWidget(
        buildTestShell(
          activeAlias: 'Theme User',
          isDarkMode: false,
          onToggleTheme: () {
            themeToggled = true;
          },
        ),
      );
      await tester.pumpAndSettle();

      final themeButton = find.byTooltip('Cambiar tema');
      expect(themeButton, findsOneWidget);

      await tester.tap(themeButton);
      await tester.pumpAndSettle();

      expect(themeToggled, isTrue);
    });

    testWidgets('Navbar no muestra botón de perfil duplicado', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestShell(activeAlias: 'PerfilTester #99'),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AliasBadgeButton), findsNothing);
    });

    testWidgets('Click en botón de normas navega hacia RulesScreen', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestShell(activeAlias: 'Rules Tester'),
      );
      await tester.pumpAndSettle();

      final rulesButton = find.byTooltip('Normas y Descargo');
      expect(rulesButton, findsOneWidget);

      await tester.tap(rulesButton);
      await tester.pumpAndSettle();

      expect(find.byType(RulesScreen), findsOneWidget);
      expect(find.text('Normas Comunitarias & Descargo Legal'), findsOneWidget);
    });

    testWidgets('Click en el banner de título abre el modal de Aviso Comunitario', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestShell(activeAlias: 'Disclaimer Tester'),
      );
      await tester.pumpAndSettle();

      // Tocamos el encabezado Comunidad Universitaria
      final titleHeader = find.text('Comunidad Universitaria');
      await tester.tap(titleHeader);
      await tester.pumpAndSettle();

      // Diálogo de aviso comunitario
      expect(find.text('Aviso Comunitario'), findsOneWidget);
      expect(find.textContaining('Comunidad Universitaria es una plataforma estudiantil colaborativa'), findsOneWidget);
      expect(find.text('Ver Normas Completas'), findsOneWidget);
      expect(find.text('Entendido'), findsOneWidget);

      // Tocamos 'Ver Normas Completas' y navega a RulesScreen
      await tester.tap(find.text('Ver Normas Completas'));
      await tester.pumpAndSettle();

      expect(find.byType(RulesScreen), findsOneWidget);
    });
  });
}
