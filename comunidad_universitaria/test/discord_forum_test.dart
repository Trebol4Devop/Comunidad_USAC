import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:comunidad_universitaria/core/services/forum_server_preferences_service.dart';
import 'package:comunidad_universitaria/features/forum/models/discord_forum_models.dart';
import 'package:comunidad_universitaria/features/forum/screens/forum_screen.dart';
import 'package:comunidad_universitaria/features/forum/widgets/discord/forum_channel_sidebar.dart';
import 'package:comunidad_universitaria/features/forum/widgets/discord/forum_server_rail.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'usac_forum_alias': 'EstudianteTest',
    });
  });

  group('Discord Forum Models & Architecture', () {
    test(
      'Los servidores predeterminados incluyen comunidades generales y por carrera',
      () {
        final servers = ForumServer.defaultServers;
        expect(servers.any((server) => server.id == 'todas'), isTrue);
        expect(servers.any((server) => server.carreraId == 'sistemas'), isTrue);
        expect(
          servers.any(
            (server) =>
                server.id == 'medicina' && server.carreraId == '05-00-01',
          ),
          isTrue,
        );
        expect(
          servers.any(
            (server) =>
                server.id == 'derecho' && server.carreraId == '04-00-01',
          ),
          isTrue,
        );
      },
    );

    test(
      'Los canales del foro están alineados con las categorías disponibles',
      () {
        final channels = ForumChannel.defaultChannels;
        expect(channels.length, 5);
        expect(
          channels.any((channel) => channel.name == 'todos-los-temas'),
          isTrue,
        );
        expect(
          channels.any((channel) => channel.name == 'dudas-y-pensum'),
          isTrue,
        );
        expect(
          channels.any((channel) => channel.name == 'catedraticos-opiniones'),
          isTrue,
        );
        expect(
          channels.any((channel) => channel.name == 'apuntes-y-recursos'),
          isTrue,
        );
        expect(
          channels.any((channel) => channel.name == 'horarios-y-secciones'),
          isTrue,
        );
      },
    );

    test('Los servidores y canales no dependen de conteos simulados', () {
      for (final server in ForumServer.defaultServers) {
        expect(server.memberCount, isNull);
      }
      final areaComun = ForumServer.defaultServers.firstWhere(
        (server) => server.id == 'area_comun',
      );
      expect(areaComun.facultadId, '08');

      final channel = ForumChannel.fromDbCategory(
        id: 'prerrequisitos',
        nombre: 'Prerrequisitos & Pensum',
      );
      expect(channel.name, 'dudas-y-pensum');
      expect(channel.label, 'Prerrequisitos & Pensum');
    });

    test(
      'Los servidores de grupos conservan su catálogo fuera del rail del foro',
      () {
        final channels = ForumChannel.groupsChannels;
        expect(channels.length, 11);
        expect(channels.first.name, 'todos-los-grupos');
        expect(
          channels.any(
            (channel) => channel.id == '08' && channel.name == 'ingenieria',
          ),
          isTrue,
        );
        expect(channels.any((channel) => channel.id == 'area_comun'), isFalse);
        final engineering = ForumFaculty.defaultFaculties.firstWhere(
          (faculty) => faculty.id == '08',
        );
        expect(
          engineering.careers.any((career) => career.id == 'area_comun'),
          isTrue,
        );
      },
    );
  });

  group('Discord Forum UI', () {
    testWidgets(
      'Inicia con el servidor general y no muestra grupos, perfil ni engranaje en el menú lateral',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          const MaterialApp(
            home: ForumScreen(
              activeAlias: 'Alias oculto',
              onAliasChanged: _ignoreAlias,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ForumServerRail), findsOneWidget);
        expect(find.byType(ForumChannelSidebar), findsOneWidget);
        expect(find.byTooltip('Todas las Facultades'), findsOneWidget);
        expect(find.byTooltip('Grupos de Estudio'), findsNothing);
        expect(find.byTooltip('Agregar servidor'), findsOneWidget);
        expect(find.byTooltip('Normas y descargo legal'), findsOneWidget);
        expect(find.byIcon(Icons.settings_outlined), findsNothing);
        expect(find.text('Alias oculto'), findsOneWidget);
        expect(find.text('En línea'), findsNothing);
        expect(find.text('CANALES'), findsOneWidget);
      },
    );

    testWidgets('El botón más agrega un servidor y persiste la preferencia', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: ForumScreen(
            activeAlias: 'Estudiante',
            onAliasChanged: _ignoreAlias,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Agregar servidor'));
      await tester.pumpAndSettle();
      expect(find.text('Agregar servidor'), findsOneWidget);

      final search = find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(search, 'Médico y Cirujano');
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .descendant(
              of: find.byType(Dialog),
              matching: find.byType(ListTile),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);

      final savedServers = await ForumServerPreferencesService.load();
      expect(savedServers.any((server) => server.id != 'todas'), isTrue);
      expect(
        find.descendant(
          of: find.byType(ForumChannelSidebar),
          matching: find.text('Médico y Cirujano'),
        ),
        findsOneWidget,
      );
      expect(
        savedServers.any((server) => server.carreraId == '05-00-01'),
        isTrue,
      );
      expect(savedServers.any((server) => server.isGroups), isFalse);
    });

    testWidgets(
      'Los títulos de canales muestran el canal con hashtag sin bienvenida ni CTA duplicado',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          const MaterialApp(
            home: ForumScreen(
              activeAlias: 'Estudiante',
              onAliasChanged: _ignoreAlias,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('#todos-los-temas'),
          findsOneWidget,
        );
        expect(find.text('Crear Primera Publicación'), findsNothing);

        await tester.tap(find.text('catedraticos-opiniones'));
        await tester.pumpAndSettle();
        expect(
          find.text('#catedraticos-opiniones'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'En móvil se conservan rail de servidores y canales dentro del drawer',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          const MaterialApp(
            home: ForumScreen(
              activeAlias: 'Estudiante',
              onAliasChanged: _ignoreAlias,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Cabecera móvil con Zanate centrado y canal con hashtag a la derecha
        expect(find.text('Zanate'), findsOneWidget);
        expect(find.text('#todos-los-temas'), findsOneWidget);
        expect(find.byType(FloatingActionButton), findsOneWidget);

        await tester.tap(find.byIcon(Icons.menu));
        await tester.pumpAndSettle();
        expect(find.byType(ForumServerRail), findsOneWidget);
        expect(find.byType(ForumChannelSidebar), findsOneWidget);
        expect(find.byTooltip('Agregar servidor'), findsOneWidget);
        expect(find.byTooltip('Grupos de Estudio'), findsNothing);
        // El botón flotante desaparece al abrir la barra lateral
        expect(find.byType(FloatingActionButton), findsNothing);

        // Seleccionar canal dudas-y-pensum en móvil
        await tester.tap(find.text('dudas-y-pensum'));
        await tester.pumpAndSettle();

        // Al cerrarse el menú lateral, el botón flotante reaparece
        expect(find.byType(FloatingActionButton), findsOneWidget);

        // La cabecera móvil se actualiza dinámicamente con el canal activo a la derecha
        expect(
          find.text('#dudas-y-pensum'),
          findsOneWidget,
        );

        await tester.tap(find.byIcon(Icons.menu));
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Agregar servidor'));
        await tester.pumpAndSettle();
        final search = find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(TextField),
        );
        await tester.enterText(search, 'Médico y Cirujano');
        await tester.pumpAndSettle();
        await tester.tap(
          find
              .descendant(
                of: find.byType(Dialog),
                matching: find.byType(ListTile),
              )
              .first,
        );
        await tester.pumpAndSettle();
        // Al cambiar / agregar un servidor, la barra lateral NO se cierra
        expect(find.byType(ForumServerRail), findsOneWidget);

        // Al presionar el botón de cerrar menú, se cierra la barra lateral
        await tester.tap(find.byTooltip('Cerrar menú'));
        await tester.pumpAndSettle();
        expect(find.byType(ForumServerRail), findsNothing);
        expect(find.byType(FloatingActionButton), findsOneWidget);
      },
    );

    testWidgets('El rail ignora servidores de grupos recibidos en la lista', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ForumServerRail(
              servers: ForumServer.defaultServers,
              activeServer: ForumServer.defaultServers.first,
              onSelectServer: (_) {},
              onAddServer: (_) {},
            ),
          ),
        ),
      );

      expect(find.byTooltip('Todas las Facultades'), findsOneWidget);
      expect(find.byTooltip('Grupos de Estudio'), findsNothing);
      expect(find.byTooltip('Agregar servidor'), findsOneWidget);
    });
  });
}

void _ignoreAlias(String _) {}
