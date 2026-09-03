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
  });
}
