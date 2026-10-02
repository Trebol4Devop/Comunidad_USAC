import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:comunidad_universitaria/features/forum/models/discord_forum_models.dart';
import 'package:comunidad_universitaria/features/forum/screens/forum_screen.dart';
import 'package:comunidad_universitaria/features/forum/widgets/discord/forum_channel_sidebar.dart';
import 'package:comunidad_universitaria/features/forum/widgets/discord/forum_server_rail.dart';

void main() {
  group('Discord Forum Models & Architecture', () {
    test('ForumServer.defaultServers define servidores oficiales por carrera y facultad', () {
      final servers = ForumServer.defaultServers;
      expect(servers.isNotEmpty, isTrue);

      final hasGeneral = servers.any((s) => s.id == 'todas');
      final hasSistemas = servers.any((s) => s.carreraId == 'sistemas');
      final hasMedicina = servers.any((s) => s.carreraId == 'medicina');
      final hasDerecho = servers.any((s) => s.carreraId == 'derecho');

      expect(hasGeneral, isTrue);
      expect(hasSistemas, isTrue);
      expect(hasMedicina, isTrue);
      expect(hasDerecho, isTrue);
    });

    test('ForumChannel.defaultChannels define canales temáticos estructurados estilo Discord', () {
      final channels = ForumChannel.defaultChannels;
      expect(channels.length, greaterThanOrEqualTo(5));

      final hasTodos = channels.any((c) => c.name == 'todos-los-temas');
      final hasDudas = channels.any((c) => c.name == 'dudas-y-pensum');
      final hasCatedraticos = channels.any((c) => c.name == 'catedraticos-opiniones');
      final hasApuntes = channels.any((c) => c.name == 'apuntes-y-recursos');

      expect(hasTodos, isTrue);
      expect(hasDudas, isTrue);
      expect(hasCatedraticos, isTrue);
      expect(hasApuntes, isTrue);
    });
  });

  group('Discord Forum UI Widgets', () {
    testWidgets('Renderiza ForumServerRail y ForumChannelSidebar en pantalla de escritorio', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: ForumScreen(
            activeAlias: 'Estudiante #42',
            onAliasChanged: (_) {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Debe encontrar los rieles de servidor y barra lateral de canales
      expect(find.byType(ForumServerRail), findsOneWidget);
      expect(find.byType(ForumChannelSidebar), findsOneWidget);

      // Verificación de canales tipo Discord
      expect(find.text('todos-los-temas'), findsWidgets);
      expect(find.text('dudas-y-pensum'), findsWidgets);
      expect(find.text('CANALES DE DISCUSIÓN'), findsOneWidget);
      expect(find.text('Estudiante #42'), findsOneWidget);
    });

    testWidgets('Permite cambiar de canal y actualizar el encabezado del feed', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: ForumScreen(
            activeAlias: 'SistemasDev',
            onAliasChanged: (_) {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tocamos el canal catedraticos-opiniones
      final channelFinder = find.text('catedraticos-opiniones');
      expect(channelFinder, findsOneWidget);
      await tester.tap(channelFinder);
      await tester.pumpAndSettle();

      // El encabezado de bienvenida debe reflejar el canal seleccionado
      expect(find.text('¡Te damos la bienvenida a #catedraticos-opiniones!'), findsOneWidget);
    });

    testWidgets('En vista móvil renderiza drawer deslizable con servidores y canales', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: ForumScreen(
            activeAlias: 'EstudianteMovil',
            onAliasChanged: (_) {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      // En móvil se muestra el icono de menú de navegación para abrir el drawer
      final menuButton = find.byIcon(Icons.menu);
      expect(menuButton, findsOneWidget);

      await tester.tap(menuButton);
      await tester.pumpAndSettle();

      // El drawer abierto contiene los servidores y canales
      expect(find.byType(ForumServerRail), findsOneWidget);
      expect(find.byType(ForumChannelSidebar), findsOneWidget);
    });

    testWidgets('Permite cambiar de servidor desde el riel y actualiza el servidor activo en la barra lateral', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: ForumScreen(
            activeAlias: 'EstudianteIngenieria',
            onAliasChanged: (_) {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Por defecto el servidor activo es Sistemas
      expect(find.text('Ingeniería en Sistemas'), findsOneWidget);

      // Tocamos el ícono del primer servidor en el riel (Campus Central / USAC General)
      final campusCentralIcon = find.descendant(
        of: find.byType(ForumServerRail),
        matching: find.byIcon(Icons.school),
      );
      expect(campusCentralIcon, findsOneWidget);
      await tester.tap(campusCentralIcon);
      await tester.pumpAndSettle();

      // El servidor activo en la barra lateral debe ser ahora Campus Central
      expect(find.text('Campus Central'), findsOneWidget);
      expect(find.textContaining('Campus Central ·'), findsOneWidget);
    });

    testWidgets('Abre el diálogo de exploración de carreras y permite filtrar por texto', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: ForumScreen(
            activeAlias: 'EstudianteTester',
            onAliasChanged: (_) {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tocamos el botón de explorar carreras en el riel
      final exploreButton = find.descendant(
        of: find.byType(ForumServerRail),
        matching: find.byIcon(Icons.explore_outlined),
      );
      expect(exploreButton, findsOneWidget);
      await tester.tap(exploreButton);
      await tester.pumpAndSettle();

      // Debe abrirse el diálogo de exploración
      expect(find.text('Explorar Carreras'), findsOneWidget);

      // Filtramos por texto
      final searchInput = find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(TextField),
      );
      expect(searchInput, findsOneWidget);
      await tester.enterText(searchInput, 'Médico');
      await tester.pumpAndSettle();

      // Debe aparecer la carrera de Médico y Cirujano
      expect(find.text('Médico y Cirujano'), findsWidgets);

      // Tocamos la carrera filtrada para seleccionarla
      await tester.tap(find.text('Médico y Cirujano').first);
      await tester.pumpAndSettle();

      // El diálogo debe cerrarse y el nuevo servidor activo debe ser Médico y Cirujano
      expect(find.text('Explorar Carreras'), findsNothing);
      expect(find.text('Médico y Cirujano'), findsOneWidget);
    });

    testWidgets('Muestra mensaje empty cuando el filtro de carreras no arroja resultados y permite limpiar', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: ForumScreen(
            activeAlias: 'EstudianteTester',
            onAliasChanged: (_) {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Abrimos el diálogo de exploración
      await tester.tap(find.descendant(
        of: find.byType(ForumServerRail),
        matching: find.byIcon(Icons.explore_outlined),
      ));
      await tester.pumpAndSettle();

      // Ingresamos término sin coincidencias
      final searchInput = find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(searchInput, 'carrera_inexistente_xyz');
      await tester.pumpAndSettle();

      expect(
        find.text('No se encontraron carreras que coincidan con "carrera_inexistente_xyz".'),
        findsOneWidget,
      );

      // Limpiamos con el botón de borrar
      final clearBtn = find.byIcon(Icons.clear);
      expect(clearBtn, findsOneWidget);
      await tester.tap(clearBtn);
      await tester.pumpAndSettle();

      expect(
        find.text('No se encontraron carreras que coincidan con "carrera_inexistente_xyz".'),
        findsNothing,
      );
    });

    testWidgets('Permite navegar al canal de marcadores personales mis-guardados y muestra estado activo', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: ForumScreen(
            activeAlias: 'EstudianteGuardados',
            onAliasChanged: (_) {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tocamos el canal personal mis-guardados
      final bookmarksChannelFinder = find.text('mis-guardados');
      expect(bookmarksChannelFinder, findsOneWidget);
      await tester.tap(bookmarksChannelFinder);
      await tester.pumpAndSettle();

      // El encabezado de bienvenida debe reflejar mis-guardados
      expect(find.text('¡Te damos la bienvenida a #mis-guardados!'), findsOneWidget);
      expect(find.text('No tienes publicaciones guardadas'), findsOneWidget);
    });

    testWidgets('Permite abrir modal de cambio de alias desde la barra inferior de perfil', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: ForumScreen(
            activeAlias: 'UsuarioOriginal',
            onAliasChanged: (_) {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Botón de editar seudónimo en la barra inferior del sidebar
      final editAliasBtn = find.descendant(
        of: find.byType(ForumChannelSidebar),
        matching: find.byIcon(Icons.edit_outlined),
      );
      expect(editAliasBtn, findsOneWidget);
      await tester.tap(editAliasBtn);
      await tester.pumpAndSettle();

      // Debe abrir el AliasModal
      expect(find.text('Tu Seudónimo Estudiantil'), findsOneWidget);
      expect(find.text('Guardar Alias'), findsOneWidget);
    });
  });
}
