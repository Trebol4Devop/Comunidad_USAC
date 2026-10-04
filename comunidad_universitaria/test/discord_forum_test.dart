import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:comunidad_universitaria/features/forum/models/discord_forum_models.dart';
import 'package:comunidad_universitaria/features/forum/screens/forum_screen.dart';
import 'package:comunidad_universitaria/features/forum/widgets/discord/forum_channel_sidebar.dart';
import 'package:comunidad_universitaria/features/forum/widgets/discord/forum_server_rail.dart';
import 'package:comunidad_universitaria/features/navigation/app_shell.dart';
import 'package:comunidad_universitaria/features/rules/screens/rules_screen.dart';
import 'package:comunidad_universitaria/features/profile/screens/profile_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'usac_forum_alias': 'EstudianteTest'});
  });
  group('Discord Forum Models & Architecture', () {
    test('ForumServer.defaultServers define servidores oficiales por carrera y facultad', () {
      final servers = ForumServer.defaultServers;
      expect(servers.isNotEmpty, isTrue);

      final hasGeneral = servers.any((s) => s.id == 'todas');
      final hasSistemas = servers.any((s) => s.carreraId == 'sistemas');
      final hasMedicina = servers.any((s) => s.id == 'medicina' && s.carreraId == '05-00-01');
      final hasDerecho = servers.any((s) => s.id == 'derecho' && s.carreraId == '04-00-01');

      expect(hasGeneral, isTrue);
      expect(hasSistemas, isTrue);
      expect(hasMedicina, isTrue);
      expect(hasDerecho, isTrue);
    });

    test('ForumChannel.defaultChannels define canales temáticos estructurados estilo Discord alineados a categorias_foro', () {
      final channels = ForumChannel.defaultChannels;
      expect(channels.length, greaterThanOrEqualTo(5));

      final hasTodos = channels.any((c) => c.name == 'todos-los-temas' && c.categoryId == 'todos');
      final hasDudas = channels.any((c) => c.name == 'dudas-y-pensum' && c.categoryId == 'prerrequisitos');
      final hasCatedraticos = channels.any((c) => c.name == 'catedraticos-opiniones' && c.categoryId == 'catedraticos');
      final hasApuntes = channels.any((c) => c.name == 'apuntes-y-recursos' && c.categoryId == 'apuntes');
      final hasHorarios = channels.any((c) => c.name == 'horarios-y-secciones' && c.categoryId == 'horarios');
      final hasGeneral = channels.any((c) => c.name == 'charla-general' && c.categoryId == 'general');

      expect(hasTodos, isTrue);
      expect(hasDudas, isTrue);
      expect(hasCatedraticos, isTrue);
      expect(hasApuntes, isTrue);
      expect(hasHorarios, isTrue);
      expect(hasGeneral, isTrue);
    });

    test('ForumServer y ForumChannel no contienen datos simulados ni conteos mock', () {
      // 1. Servidores sin conteos de miembros inventados
      for (final s in ForumServer.defaultServers) {
        expect(s.memberCount, isNull, reason: 'El servidor ${s.id} no debe tener memberCount inventado/simulado');
      }

      // 2. Área común debe coincidir con la DB (facultadId = todas)
      final areaComun = ForumServer.defaultServers.firstWhere((s) => s.id == 'area_comun');
      expect(areaComun.facultadId, equals('todas'), reason: 'En public.carreras, area_comun pertenece a facultad_id = todas');

      // 3. fromDbCategory mapea correctamente registros de DB
      final cat = ForumChannel.fromDbCategory(id: 'prerrequisitos', nombre: 'Prerrequisitos & Pensum');
      expect(cat.id, 'prerrequisitos');
      expect(cat.name, 'dudas-y-pensum');
      expect(cat.label, 'Prerrequisitos & Pensum');
      expect(cat.categoryId, 'prerrequisitos');
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

      // Por defecto el servidor activo de hasta arriba es Todas las Facultades
      expect(find.text('Todas las Facultades'), findsOneWidget);

      // Tocamos la facultad de Agronomía (AGRO) en el riel
      final agroIcon = find.descendant(
        of: find.byType(ForumServerRail),
        matching: find.text('AGRO'),
      );
      expect(agroIcon, findsOneWidget);
      await tester.tap(agroIcon);
      await tester.pumpAndSettle();

      // Mientras está abierto el submenú, el área de mensajes y barra lateral mantienen lo actual
      expect(find.text('Todas las Facultades'), findsOneWidget);

      // Tocamos la carrera PROD
      await tester.tap(find.text('PROD'));
      await tester.pumpAndSettle();

      // El servidor activo en la barra lateral debe ser ahora Sistemas de Producción Agrícola
      expect(find.text('Sistemas de Producción Agrícola'), findsOneWidget);
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

    testWidgets('Permite abrir pantalla de Preferencias desde la barra inferior de perfil del foro', (tester) async {
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

      // Botón de preferencias en la barra inferior del sidebar
      final settingsBtn = find.descendant(
        of: find.byType(ForumChannelSidebar),
        matching: find.byIcon(Icons.settings_outlined),
      );
      expect(settingsBtn, findsOneWidget);
      await tester.tap(settingsBtn);
      await tester.pumpAndSettle();

      // Debe abrir la pantalla de Preferencias de Usuario con su AppBar y campo de seudónimo
      expect(find.text('Preferencias de Usuario'), findsOneWidget);
      expect(find.byTooltip('Regresar'), findsOneWidget);

      // Tocar regresar debe volver al foro
      await tester.tap(find.byTooltip('Regresar'));
      await tester.pumpAndSettle();
      expect(find.text('Preferencias de Usuario'), findsNothing);
    });

    testWidgets('Muestra solo las facultades en el riel de servidores y despliega submenú flotante de carreras', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: ForumScreen(
            activeAlias: 'EstudianteFacultad',
            onAliasChanged: (_) {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Debe mostrar el riel de servidores
      expect(find.byType(ForumServerRail), findsOneWidget);

      // Verificamos que se muestren las facultades en el riel principal
      expect(find.text('AGRO'), findsOneWidget);
      expect(find.text('ARQ'), findsOneWidget);
      expect(find.text('ECON'), findsOneWidget);
      expect(find.text('DER'), findsOneWidget);
      expect(find.text('MED'), findsOneWidget);
      expect(find.text('FARM'), findsOneWidget);
      expect(find.text('HUM'), findsOneWidget);
      expect(find.byIcon(Icons.engineering), findsOneWidget);

      // Tocamos la facultad de Agronomía (AGRO)
      final agroFinder = find.descendant(
        of: find.byType(ForumServerRail),
        matching: find.text('AGRO'),
      );
      expect(agroFinder, findsOneWidget);
      await tester.tap(agroFinder);
      await tester.pumpAndSettle();

      // Debe desplegarse el submenú flotante con las carreras de Agronomía (PROD, RNAT, FORE, AMBL)
      expect(find.text('PROD'), findsOneWidget);
      expect(find.text('RNAT'), findsOneWidget);
      expect(find.text('FORE'), findsOneWidget);
      expect(find.text('AMBL'), findsOneWidget);

      // Tocamos la carrera PROD (Sistemas de Producción Agrícola)
      await tester.tap(find.text('PROD'));
      await tester.pumpAndSettle();

      // El submenú flotante se cierra y el servidor activo pasa a ser la carrera seleccionada
      expect(find.text('PROD'), findsNothing);
      expect(find.text('Sistemas de Producción Agrícola'), findsOneWidget);
    });

    testWidgets('El servidor de hasta arriba es Todas las Facultades y el hero de bienvenida no duplica el nombre del servidor', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: ForumScreen(
            activeAlias: 'EstudianteTopServer',
            onAliasChanged: (_) {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      // El servidor de hasta arriba por defecto es Todas las Facultades
      expect(find.text('Todas las Facultades'), findsOneWidget);

      // El hero no debe duplicar "Todas las Facultades · "
      expect(find.textContaining('Todas las Facultades ·'), findsNothing);

      // No debe contener "(Toca para ver carreras)"
      expect(find.textContaining('(Toca para ver carreras)'), findsNothing);
    });

    testWidgets('Al abrir submenú mantiene visible el contenido actual y cambia solo al seleccionar subservidor', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: ForumScreen(
            activeAlias: 'TesterSubmenu',
            onAliasChanged: (_) {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Abrimos la facultad de Arquitectura (ARQ)
      final arqFinder = find.descendant(
        of: find.byType(ForumServerRail),
        matching: find.text('ARQ'),
      );
      expect(arqFinder, findsOneWidget);
      await tester.tap(arqFinder);
      await tester.pumpAndSettle();

      // El área central y sidebar mantienen lo que está actualmente sin cambiar
      expect(find.text('Todas las Facultades'), findsOneWidget);

      // Si tocamos afuera (en el scaffold) para cerrar el submenú sin elegir carrera
      await tester.tapAt(const Offset(500, 300));
      await tester.pumpAndSettle();

      // Sigue estando intacto en Todas las Facultades
      expect(find.text('Todas las Facultades'), findsOneWidget);
    });

    testWidgets('ForumServerRail posiciona siempre Todas las Facultades al inicio aunque la lista venga desordenada', (tester) async {
      final scrambledFaculties = [
        const ForumFaculty(
          id: '01',
          name: 'Facultad de Agronomía',
          shortCode: 'AGRO',
          icon: Icons.grass,
          color: Color(0xFF16A34A),
          careers: [],
        ),
        const ForumFaculty(
          id: '02',
          name: 'Facultad de Arquitectura',
          shortCode: 'ARQ',
          icon: Icons.architecture,
          color: Color(0xFF059669),
          careers: [],
        ),
        const ForumFaculty(
          id: 'todas',
          name: 'Todas las Facultades',
          shortCode: 'USAC',
          icon: Icons.school,
          color: Color(0xFF004B87),
          careers: [],
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ForumServerRail(
              servers: ForumServer.defaultServers,
              activeServer: ForumServer.defaultServers.first,
              faculties: scrambledFaculties,
              onSelectServer: (_) {},
              onAddServer: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tooltip del home server debe ser Todas las Facultades
      expect(find.byTooltip('Todas las Facultades'), findsOneWidget);

      // 'todas' no debe estar duplicado ni al final en la lista de otras facultades
      final agroFinder = find.text('AGRO');
      final arqFinder = find.text('ARQ');
      expect(agroFinder, findsOneWidget);
      expect(arqFinder, findsOneWidget);
    });

    testWidgets('Modo oscuro renderiza elementos del foro con contraste accesible', (tester) async {
      final foreignServer = ForumServer.defaultServers.firstWhere((s) => s.facultadId != 'todas');

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: ForumServerRail(
              servers: ForumServer.defaultServers,
              activeServer: foreignServer, // Servidor de otra facultad para que el home esté inactivo
              faculties: ForumFaculty.defaultFaculties,
              onSelectServer: (_) {},
              onAddServer: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // En modo oscuro cuando el home server está inactivo su icono debe tener color contrastante
      final homeIcon = tester.widget<Icon>(find.byIcon(ForumFaculty.defaultFaculties.first.icon).first);
      expect(homeIcon.color, const Color(0xFFDBDEE1));
    });

    testWidgets('Navbar no muestra el texto Red Estudiantil Autónoma', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: AppShell(
            activeAlias: 'EstudianteTest',
            onAliasChanged: (_) {},
            onToggleTheme: () {},
            isDarkMode: false,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Debe mostrar Comunidad y No Oficial
      expect(find.textContaining('Comunidad'), findsWidgets);
      expect(find.text('No Oficial'), findsOneWidget);

      // NO debe mostrar Red Estudiantil Autónoma
      expect(find.textContaining('Red Estudiantil Autónoma'), findsNothing);
    });

    testWidgets('Flujo de navegación para Normas Comunitarias y Preferencias permite ir y regresar correctamente', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: AppShell(
            activeAlias: 'EstudianteTest',
            onAliasChanged: (_) {},
            onToggleTheme: () {},
            isDarkMode: false,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Probar flujo de Normas
      final rulesBtn = find.byTooltip('Normas y Descargo');
      expect(rulesBtn, findsOneWidget);
      await tester.tap(rulesBtn);
      await tester.pumpAndSettle();

      // Debe mostrar RulesScreen con su AppBar y botón de regresar
      expect(find.byType(RulesScreen), findsOneWidget);
      expect(find.text('Normas Comunitarias y Descargo'), findsOneWidget);
      final backFromRules = find.byTooltip('Regresar');
      expect(backFromRules, findsOneWidget);
      await tester.tap(backFromRules);
      await tester.pumpAndSettle();

      // Regresa a AppShell
      expect(find.byType(RulesScreen), findsNothing);
      expect(find.byType(AppShell), findsOneWidget);

      // 2. Probar flujo de Preferencias de Usuario (desde la barra inferior de perfil)
      final settingsBtn = find.descendant(
        of: find.byType(ForumChannelSidebar),
        matching: find.byIcon(Icons.settings_outlined),
      );
      expect(settingsBtn, findsOneWidget);
      await tester.tap(settingsBtn);
      await tester.pumpAndSettle();

      // Debe mostrar ProfileScreen con su AppBar y botón de regresar
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.text('Preferencias de Usuario'), findsOneWidget);
      final backFromProfile = find.byTooltip('Regresar');
      expect(backFromProfile, findsOneWidget);
      await tester.tap(backFromProfile);
      await tester.pumpAndSettle();

      // Regresa a AppShell
      expect(find.byType(ProfileScreen), findsNothing);
      expect(find.byType(AppShell), findsOneWidget);
    });

    testWidgets('Todas las Carreras usa como símbolo el gorro de estudiante y el texto USAC', (tester) async {
      final defaultRoot = ForumFaculty.defaultFaculties.first;
      expect(defaultRoot.icon, Icons.school);
      expect(defaultRoot.shortCode, 'USAC');

      final carreraTodas = defaultRoot.careers.firstWhere((c) => c.id == 'todas');
      expect(carreraTodas.name, 'Todas las Carreras');
      expect(carreraTodas.shortCode, 'USAC');
      expect(carreraTodas.icon, Icons.school);

      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: ForumScreen(
            activeAlias: 'UsuarioUSAC',
            onAliasChanged: (_) {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      // En el riel, el botón de Todas las Facultades muestra el gorro escolar y USAC
      final usacRailButton = find.descendant(
        of: find.byType(ForumServerRail),
        matching: find.text('USAC'),
      );
      expect(usacRailButton, findsOneWidget);
    });
  });
}

