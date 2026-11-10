import 'dart:ui' show SemanticsRole, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:comunidad_universitaria/core/config/app_theme.dart';
import 'package:comunidad_universitaria/features/forum/screens/forum_screen.dart';
import 'package:comunidad_universitaria/features/groups/screens/groups_screen.dart';
import 'package:comunidad_universitaria/features/groups/widgets/create_group_dialog.dart';
import 'package:comunidad_universitaria/features/marketplace/screens/marketplace_screen.dart';
import 'package:comunidad_universitaria/features/map/screens/campus_map_screen.dart';
import 'package:comunidad_universitaria/features/navigation/app_shell.dart';
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
    testWidgets(
      'Renderiza en vista móvil (400x800) con NavigationBar y alias activo',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestShell(activeAlias: 'Estudiante #101'));
        await tester.pumpAndSettle();

        // En móvil sigue la cabecera compacta de la referencia.
        expect(find.text('Zanate'), findsOneWidget);
        final logo = find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName ==
                  'assets/images/zanate_logo.png',
        );
        expect(logo, findsOneWidget);
        expect(tester.getSize(logo), const Size(48, 48));
        // El icono de configuración se removió de la barra superior donde está Zanate
        expect(find.byTooltip('Ajustes'), findsNothing);
        expect(find.text('Comunidad Universitaria'), findsNothing);
        expect(find.text('No Oficial'), findsNothing);
        expect(find.text('Red Estudiantil Autónoma'), findsNothing);

        // Botón de perfil ya no se muestra en el navbar (se ubica en la barra inferior)
        expect(find.byType(AliasBadgeButton), findsNothing);

        // Navegación móvil con iconos sin etiquetas visibles, en orden de referencia.
        expect(find.byType(NavigationBar), findsOneWidget);
        final navigationBar = tester.widget<NavigationBar>(
          find.byType(NavigationBar),
        );
        expect(
          navigationBar.labelBehavior,
          NavigationDestinationLabelBehavior.alwaysHide,
        );
        expect(
          navigationBar.destinations.map(
            (destination) => (destination as NavigationDestination).label,
          ),
          ['Foro', 'Grupos', 'Mapa', 'Marketplace'],
        );
        for (final icon in const [
          Icons.chat_bubble_outline,
          Icons.groups_outlined,
          Icons.map_outlined,
          Icons.local_mall_outlined,
        ]) {
          expect(
            find.descendant(
              of: find.byType(NavigationBar),
              matching: find.byIcon(icon),
            ),
            findsOneWidget,
          );
        }

        // En el tab inicial (Foro), no hay FloatingActionButton
        expect(find.byType(FloatingActionButton), findsNothing);
      },
    );

    testWidgets('El destino Mapa abre el directorio de ubicaciones USAC', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestShell(activeAlias: 'Map Tester'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.byIcon(Icons.map_outlined),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CampusMapScreen), findsOneWidget);
      expect(
        find.text('Puntos de encuentro y edificios de la USAC'),
        findsOneWidget,
      );
      expect(find.text('Campus Central'), findsOneWidget);
      expect(find.byTooltip('Cómo llegar'), findsWidgets);
    });

    testWidgets(
      'Renderiza en escritorio (1200x800) con pestañas superiores y sin NavigationBar',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestShell(activeAlias: 'Ingeniero #404'));
        await tester.pumpAndSettle();

        // En escritorio muestra título 'Comunidad Universitaria'
        expect(find.text('Comunidad Universitaria'), findsOneWidget);

        // No debe tener NavigationBar inferior
        expect(find.byType(NavigationBar), findsNothing);

        // Las cuatro secciones están disponibles desde la navegación superior.
        expect(find.text('Foro Estudiantil'), findsOneWidget);
        expect(find.text('Marketplace & Tutorías'), findsOneWidget);
        expect(find.text('Grupos de Estudio'), findsOneWidget);
        expect(find.text('Mapa'), findsOneWidget);
      },
    );

    testWidgets('Pestañas de escritorio tienen semántica tablist/tab', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(buildTestShell(activeAlias: 'Semantics Tester'));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.role == SemanticsRole.tabBar,
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.role == SemanticsRole.tab,
        ),
        findsNWidgets(4),
      );
      expect(
        tester
                .getSemantics(find.bySemanticsLabel('Foro Estudiantil'))
                .getSemanticsData()
                .flagsCollection
                .isSelected ==
            Tristate.isTrue,
        isTrue,
      );
      semantics.dispose();
    });

    testWidgets('Teclado mueve y activa las pestañas de escritorio', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(buildTestShell(activeAlias: 'Keyboard Tester'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Foro Estudiantil'));
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'Desktop tab 0');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'Desktop tab 1');
      expect(
        tester
                .getSemantics(find.bySemanticsLabel('Marketplace & Tutorías'))
                .getSemanticsData()
                .flagsCollection
                .isSelected ==
            Tristate.isTrue,
        isTrue,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      expect(
        tester
                .getSemantics(find.bySemanticsLabel('Mapa'))
                .getSemanticsData()
                .flagsCollection
                .isSelected ==
            Tristate.isTrue,
        isTrue,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pumpAndSettle();
      expect(
        tester
                .getSemantics(find.bySemanticsLabel('Foro Estudiantil'))
                .getSemanticsData()
                .flagsCollection
                .isSelected ==
            Tristate.isTrue,
        isTrue,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(
        tester
                .getSemantics(find.bySemanticsLabel('Mapa'))
                .getSemanticsData()
                .flagsCollection
                .isSelected ==
            Tristate.isTrue,
        isTrue,
      );
      semantics.dispose();
    });

    testWidgets(
      'Navegación móvil entre tabs y verificación de FloatingActionButton contextual',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestShell(activeAlias: 'Tester USAC'));
        await tester.pumpAndSettle();

        // Tab 0: ForumScreen activo por defecto
        expect(find.byType(ForumScreen), findsOneWidget);

        // El cuarto icono visual abre Marketplace (pantalla interna 1).
        final marketTab = find.descendant(
          of: find.byType(NavigationBar),
          matching: find.byIcon(Icons.local_mall_outlined),
        );
        await tester.tap(marketTab);
        await tester.pumpAndSettle();

        // Debe mostrar el FAB contextual de marketplace 'Publicar Artículo'
        expect(
          find.widgetWithText(FloatingActionButton, 'Publicar Artículo'),
          findsOneWidget,
        );
      },
    );

    testWidgets('Breakpoint canónico conmuta a pestañas superiores en 700px', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(699, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestShell(activeAlias: 'Breakpoint Tester'));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Zanate'), findsOneWidget);
      expect(find.byTooltip('Ajustes'), findsNothing);

      tester.view.physicalSize = const Size(700, 800);
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('Foro Estudiantil'), findsOneWidget);
      expect(find.text('Marketplace & Tutorías'), findsOneWidget);
      expect(find.text('Grupos de Estudio'), findsOneWidget);
      expect(find.text('Mapa'), findsOneWidget);
      expect(find.text('Comunidad Universitaria'), findsOneWidget);
    });

    testWidgets(
      'Acceso móvil a Grupos comparte con un solo FAB y conserva estado',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestShell(activeAlias: 'Group Tester'));
        await tester.pumpAndSettle();

        expect(find.byType(GroupsScreen, skipOffstage: false), findsNothing);

        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.byIcon(Icons.groups_outlined),
          ),
        );
        await tester.pumpAndSettle();

        final groupsScreen = find.byType(GroupsScreen, skipOffstage: false);
        expect(groupsScreen, findsOneWidget);
        final groupsState = tester.state<GroupsScreenState>(groupsScreen);
        expect(
          find.widgetWithText(FloatingActionButton, 'Compartir Grupo'),
          findsOneWidget,
        );
        expect(find.byType(FloatingActionButton), findsOneWidget);

        await tester.tap(
          find.widgetWithText(FloatingActionButton, 'Compartir Grupo'),
        );
        await tester.pumpAndSettle();
        expect(find.byType(CreateGroupDialog), findsOneWidget);

        Navigator.of(tester.element(find.byType(CreateGroupDialog))).pop();
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.byIcon(Icons.local_mall_outlined),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.byIcon(Icons.groups_outlined),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          tester.state<GroupsScreenState>(groupsScreen),
          same(groupsState),
        );
      },
    );

    testWidgets('Navegación escritorio entre tabs superiores', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestShell(activeAlias: 'Desktop User'));
      await tester.pumpAndSettle();

      // Seleccionar Marketplace & Tutorías
      final tabMarket = find.text('Marketplace & Tutorías');
      await tester.tap(tabMarket);
      await tester.pumpAndSettle();

      expect(find.byType(MarketplaceScreen), findsOneWidget);

      // Entrar a Grupos y volver al Foro desde las pestañas superiores.
      await tester.tap(find.text('Grupos de Estudio'));
      await tester.pumpAndSettle();
      expect(find.byType(GroupsScreen), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
      final shareGroupAction = find.byTooltip('Compartir Grupo');
      expect(shareGroupAction, findsOneWidget);
      await tester.tap(shareGroupAction);
      await tester.pumpAndSettle();
      expect(find.byType(CreateGroupDialog), findsOneWidget);
      Navigator.of(tester.element(find.byType(CreateGroupDialog))).pop();
      await tester.pumpAndSettle();

      final tabForo = find.text('Foro Estudiantil');
      await tester.tap(tabForo);
      await tester.pumpAndSettle();

      expect(find.byType(ForumScreen), findsOneWidget);
    });

    testWidgets('Botón de cambio de tema dispara callback onToggleTheme', (
      tester,
    ) async {
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

      await tester.pumpWidget(buildTestShell(activeAlias: 'PerfilTester #99'));
      await tester.pumpAndSettle();

      expect(find.byType(AliasBadgeButton), findsNothing);
    });

    testWidgets('Click en botón de normas navega hacia RulesScreen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestShell(activeAlias: 'Rules Tester'));
      await tester.pumpAndSettle();

      final rulesButton = find.byTooltip('Normas y Descargo');
      expect(rulesButton, findsOneWidget);

      await tester.tap(rulesButton);
      await tester.pumpAndSettle();

      expect(find.byType(RulesScreen), findsOneWidget);
      expect(find.text('Normas Comunitarias & Descargo Legal'), findsOneWidget);
    });

    testWidgets(
      'Click en el banner de título abre el modal de Aviso Comunitario',
      (tester) async {
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
        expect(
          find.textContaining(
            'Comunidad Universitaria es una plataforma estudiantil colaborativa',
          ),
          findsOneWidget,
        );
        expect(find.text('Ver Normas Completas'), findsOneWidget);
        expect(find.text('Entendido'), findsOneWidget);
        expect(
          Focus.of(tester.element(find.text('Entendido'))).hasFocus,
          isTrue,
        );

        // Tocamos 'Ver Normas Completas' y navega a RulesScreen
        await tester.tap(find.text('Ver Normas Completas'));
        await tester.pumpAndSettle();

        expect(find.byType(RulesScreen), findsOneWidget);
      },
    );
  });
}
