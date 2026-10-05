import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:comunidad_universitaria/features/forum/models/discord_forum_models.dart';
import 'package:comunidad_universitaria/features/forum/screens/forum_screen.dart';
import 'package:comunidad_universitaria/features/forum/widgets/discord/forum_channel_sidebar.dart';
import 'package:comunidad_universitaria/features/forum/widgets/discord/forum_server_rail.dart';
import 'package:comunidad_universitaria/features/forum/widgets/discord/popular_servers_sidebar.dart';
import 'package:comunidad_universitaria/features/navigation/app_shell.dart';
import 'package:comunidad_universitaria/features/rules/screens/rules_screen.dart';
import 'package:comunidad_universitaria/features/profile/screens/profile_screen.dart';
import 'package:comunidad_universitaria/features/groups/screens/groups_screen.dart';

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

    test('ForumChannel.defaultChannels define canales temáticos estructurados estilo Discord alineados a categorias_foro sin charla-general', () {
      final channels = ForumChannel.defaultChannels;
      expect(channels.length, equals(5));

      final hasTodos = channels.any((c) => c.name == 'todos-los-temas' && c.categoryId == 'todos');
      final hasDudas = channels.any((c) => c.name == 'dudas-y-pensum' && c.categoryId == 'prerrequisitos');
      final hasCatedraticos = channels.any((c) => c.name == 'catedraticos-opiniones' && c.categoryId == 'catedraticos');
      final hasApuntes = channels.any((c) => c.name == 'apuntes-y-recursos' && c.categoryId == 'apuntes');
      final hasHorarios = channels.any((c) => c.name == 'horarios-y-secciones' && c.categoryId == 'horarios');
      final hasGeneral = channels.any((c) => c.name == 'charla-general' || c.categoryId == 'general');

      expect(hasTodos, isTrue);
      expect(hasDudas, isTrue);
      expect(hasCatedraticos, isTrue);
      expect(hasApuntes, isTrue);
      expect(hasHorarios, isTrue);
      expect(hasGeneral, isFalse);
    });

    test('ForumServer y ForumChannel no contienen datos simulados ni conteos mock', () {
      // 1. Servidores sin conteos de miembros inventados
      for (final s in ForumServer.defaultServers) {
        expect(s.memberCount, isNull, reason: 'El servidor ${s.id} no debe tener memberCount inventado/simulado');
      }

      // 2. Área común debe pertenecer a Facultad de Ingeniería (facultadId = 08)
      final areaComun = ForumServer.defaultServers.firstWhere((s) => s.id == 'area_comun');
      expect(areaComun.facultadId, equals('08'), reason: 'En USAC, area_comun pertenece como sub-servidor a facultad_id = 08 (Ingeniería)');

      // 3. fromDbCategory mapea correctamente registros de DB
      final cat = ForumChannel.fromDbCategory(id: 'prerrequisitos', nombre: 'Prerrequisitos & Pensum');
      expect(cat.id, 'prerrequisitos');
      expect(cat.name, 'dudas-y-pensum');
      expect(cat.label, 'Prerrequisitos & Pensum');
      expect(cat.categoryId, 'prerrequisitos');
    });

    test('ForumChannel.groupsChannels define los canales de servidor correspondientes a las facultades de la base de datos', () {
      final channels = ForumChannel.groupsChannels;
      expect(channels.length, equals(12));

      // Primer canal es Todos los Grupos
      expect(channels.first.id, equals('todas'));
      expect(channels.first.name, equals('todos-los-grupos'));
      expect(channels.first.categoryId, equals('todas'));

      // Verificar facultades oficiales de la BD
      final hasIngenieria = channels.any((c) => c.id == '08' && c.name == 'ingenieria');
      final hasMedicina = channels.any((c) => c.id == '05' && c.name == 'ciencias-medicas');
      final hasEconomicas = channels.any((c) => c.id == '03' && c.name == 'ciencias-economicas');
      final hasDerecho = channels.any((c) => c.id == '04' && c.name == 'ciencias-juridicas');
      final hasArquitectura = channels.any((c) => c.id == '02' && c.name == 'arquitectura');
      final hasAgronomia = channels.any((c) => c.id == '01' && c.name == 'agronomia');
      final hasFarmacia = channels.any((c) => c.id == '06' && c.name == 'quimica-y-farmacia');
      final hasHumanidades = channels.any((c) => c.id == '77' && c.name == 'humanidades');
      final hasOdontologia = channels.any((c) => c.id == '09' && c.name == 'odontologia');
      final hasVeterinaria = channels.any((c) => c.id == '10' && c.name == 'veterinaria');
      final hasAreaComun = channels.any((c) => c.id == 'area_comun' && c.name == 'area-comun');

      expect(hasIngenieria, isTrue);
      expect(hasMedicina, isTrue);
      expect(hasEconomicas, isTrue);
      expect(hasDerecho, isTrue);
      expect(hasArquitectura, isTrue);
      expect(hasAgronomia, isTrue);
      expect(hasFarmacia, isTrue);
      expect(hasHumanidades, isTrue);
      expect(hasOdontologia, isTrue);
      expect(hasVeterinaria, isTrue);
      expect(hasAreaComun, isTrue);
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

      // Al tocar la facultad en el riel, se abre el servidor de la facultad en general
      expect(find.text('Facultad de Agronomía'), findsOneWidget);

      // Tocamos la carrera PROD en el submenú
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
      // mis-guardados no debe permitir crear publicaciones
      expect(find.text('Publicar'), findsNothing);
      expect(find.text('Crear Primera Publicación'), findsNothing);
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
      expect(find.descendant(of: find.byType(ForumServerRail), matching: find.text('AGRO')), findsOneWidget);
      expect(find.descendant(of: find.byType(ForumServerRail), matching: find.text('ARQ')), findsOneWidget);
      expect(find.descendant(of: find.byType(ForumServerRail), matching: find.text('ECON')), findsOneWidget);
      expect(find.descendant(of: find.byType(ForumServerRail), matching: find.text('DER')), findsOneWidget);
      expect(find.descendant(of: find.byType(ForumServerRail), matching: find.text('MED')), findsOneWidget);
      expect(find.descendant(of: find.byType(ForumServerRail), matching: find.text('FARM')), findsOneWidget);
      expect(find.descendant(of: find.byType(ForumServerRail), matching: find.text('HUM')), findsOneWidget);
      expect(find.descendant(of: find.byType(ForumServerRail), matching: find.byIcon(Icons.engineering)), findsOneWidget);

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

    testWidgets('Al tocar una facultad en el riel se abre el servidor completo por facultad y despliega el submenú de subservidores', (tester) async {
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

      // Al tocar la facultad en el riel, se abre el servidor general de la facultad
      expect(find.text('Facultad de Arquitectura'), findsOneWidget);

      // Si tocamos afuera (en el scaffold) para cerrar el submenú sin elegir carrera
      await tester.tapAt(const Offset(500, 300));
      await tester.pumpAndSettle();

      // Sigue manteniéndose en Facultad de Arquitectura
      expect(find.text('Facultad de Arquitectura'), findsOneWidget);
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

    testWidgets('Grupos de Estudio se ubica en el riel de servidores directamente abajo de USAC con el símbolo de WhatsApp y texto GRUPOS', (tester) async {
      expect(ForumServer.groupsServer.id, 'grupos_estudio');
      expect(ForumServer.groupsServer.color, const Color(0xFF25D366));
      expect(ForumServer.groupsServer.shortCode, 'GRUPOS');

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

      // En el riel, verificar el botón de Grupos de Estudio
      final gruposTooltip = find.byTooltip('Grupos de Estudio (WhatsApp)');
      expect(gruposTooltip, findsOneWidget);

      final gruposText = find.descendant(
        of: gruposTooltip,
        matching: find.text('GRUPOS'),
      );
      expect(gruposText, findsOneWidget);

      // Verificar que contiene el símbolo de WhatsApp (chat bubble y phone)
      final chatBubbleIcon = find.descendant(
        of: gruposTooltip,
        matching: find.byIcon(Icons.chat_bubble),
      );
      expect(chatBubbleIcon, findsOneWidget);

      final phoneIcon = find.descendant(
        of: gruposTooltip,
        matching: find.byIcon(Icons.phone),
      );
      expect(phoneIcon, findsOneWidget);
    });

    testWidgets('Al tocar Grupos de Estudio en el riel se despliega submenú de facultades/áreas y al seleccionar una se muestra GroupsScreen con sus carreras como canales', (tester) async {
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

      // Inicialmente se muestra ForumChannelSidebar con los canales de discusión del foro
      expect(find.byType(ForumChannelSidebar), findsOneWidget);
      expect(find.text('CANALES DE DISCUSIÓN'), findsOneWidget);
      expect(find.byType(GroupsScreen), findsNothing);

      // Tocar el botón de Grupos de Estudio en el riel
      final gruposTooltip = find.byTooltip('Grupos de Estudio (WhatsApp)');
      await tester.tap(gruposTooltip);
      await tester.pumpAndSettle();

      // Se despliega el submenú flotante de subservidores de Grupos con todas las facultades
      expect(find.text('TODAS'), findsOneWidget);
      expect(find.text('CMED'), findsOneWidget);
      expect(find.text('ING'), findsNWidgets(2));
      expect(find.byTooltip('Facultad de Ingeniería'), findsNWidgets(2));
      expect(find.byTooltip('Facultad de Humanidades'), findsWidgets);
      expect(find.byTooltip('Facultad de Odontología'), findsWidgets);

      // Seleccionar el subservidor de Ingeniería en el submenú flotante
      await tester.tap(find.text('ING').last);
      await tester.pumpAndSettle();

      // Se muestra GroupsScreen
      expect(find.byType(GroupsScreen), findsOneWidget);
      expect(find.textContaining('¡Te damos la bienvenida a #todos-los-grupos!'), findsOneWidget);

      // Único botón de compartir grupo en la parte inferior
      expect(find.text('Compartir Grupo'), findsOneWidget);

      // El riel de servidores y la barra de canales permanecen visibles
      expect(find.byType(ForumServerRail), findsOneWidget);
      expect(find.byType(ForumChannelSidebar), findsOneWidget);

      // En el riel, la facultad regular NO se resalta (mantiene su texto de inactiva),
      // solo el servidor GRUPOS permanece resaltado.
      final ingRailItem = find.descendant(
        of: find.byType(ForumServerRail),
        matching: find.text('ING'),
      );
      expect(ingRailItem, findsOneWidget);

      // La barra lateral muestra las categorías/carreras de la facultad como canales
      expect(find.text('CANALES Y CATEGORÍAS'), findsOneWidget);
      expect(find.text('todos-los-grupos'), findsWidgets);
      expect(find.text('sistemas'), findsWidgets);

      // Al tocar un canal de carrera específico (ej. sistemas), se actualiza el canal
      final sistemasChannel = find.text('sistemas').first;
      await tester.tap(sistemasChannel);
      await tester.pumpAndSettle();

      // El hero en GroupsScreen ahora da la bienvenida al canal de la carrera
      expect(find.textContaining('¡Te damos la bienvenida a #sistemas!'), findsOneWidget);

      // Al tocar USAC en el riel se abre el submenú y al seleccionar Todas las Carreras regresa al foro
      final usacRailButton = find.byTooltip('Todas las Facultades');
      await tester.tap(usacRailButton);
      await tester.pumpAndSettle();

      // Seleccionar Todas las Carreras desde el submenú flotante
      final todasCarreras = find.byTooltip('Todas las Carreras');
      if (todasCarreras.evaluate().isNotEmpty) {
        await tester.tap(todasCarreras.first);
        await tester.pumpAndSettle();
      }

      expect(find.byType(ForumChannelSidebar), findsOneWidget);
      expect(find.text('CANALES DE DISCUSIÓN'), findsOneWidget);
    });

    testWidgets('En vista móvil, ForumScreen con Grupos de Estudio activo renderiza encabezado móvil con nombre de canal y abre drawer con servidores y canales', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: ForumScreen(
            activeAlias: 'UsuarioUSAC',
            onAliasChanged: (_) {},
            activeServer: ForumServer.groupsServer,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Renderiza GroupsScreen
      expect(find.byType(GroupsScreen), findsOneWidget);

      // Renderiza el encabezado móvil con icono de WhatsApp y canal activo
      expect(find.text('#todos-los-grupos'), findsOneWidget);
      expect(find.text('WAPP'), findsOneWidget);

      // El botón de menú abre el drawer que contiene ForumServerRail y ForumChannelSidebar
      final menuBtn = find.byTooltip('Canales y Servidores');
      expect(menuBtn, findsOneWidget);
      await tester.tap(menuBtn);
      await tester.pumpAndSettle();

      expect(find.byType(ForumServerRail), findsOneWidget);
      expect(find.byType(ForumChannelSidebar), findsOneWidget);
    });

    testWidgets('Al cambiar de servidor siempre por predeterminado se abre el canal de todos los temas', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: ForumScreen(
            activeAlias: 'EstudianteTestCanal',
            onAliasChanged: (_) {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Por defecto el canal inicial es todos-los-temas
      expect(find.text('todos-los-temas'), findsOneWidget);
      expect(find.text('¡Te damos la bienvenida a #todos-los-temas!'), findsOneWidget);

      // Cambiamos al canal de dudas-y-pensum
      final dudasTile = find.text('dudas-y-pensum');
      expect(dudasTile, findsOneWidget);
      await tester.tap(dudasTile);
      await tester.pumpAndSettle();
      expect(find.text('¡Te damos la bienvenida a #dudas-y-pensum!'), findsOneWidget);

      // Ahora tocamos en el riel el servidor principal de Ingeniería (ING)
      final ingIcon = find.descendant(
        of: find.byType(ForumServerRail),
        matching: find.text('ING'),
      );
      expect(ingIcon, findsOneWidget);
      await tester.tap(ingIcon);
      await tester.pumpAndSettle();

      // Debe abrir Facultad de Ingeniería en general
      expect(
        find.descendant(
          of: find.byType(ForumChannelSidebar),
          matching: find.text('Facultad de Ingeniería'),
        ),
        findsOneWidget,
      );

      // Y el canal activo debe haberse restablecido por defecto a todos-los-temas
      expect(find.text('¡Te damos la bienvenida a #todos-los-temas!'), findsOneWidget);
    });

    test('PopularServerItem.defaultPopularServers define exactamente 5 servidores populares con métricas y shortcode', () {
      final popular = PopularServerItem.defaultPopularServers();
      expect(popular.length, equals(5));
      for (final item in popular) {
        expect(item.server.name.isNotEmpty, isTrue);
        expect(item.postCount, greaterThan(0));
        expect(item.likesCount, greaterThan(0));
        expect(item.score, greaterThan(0));
      }
    });

    testWidgets('En vista escritorio (1200x800) renderiza la barra lateral derecha fija con diseño minimalista', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final popularSample = PopularServerItem.defaultPopularServers();

      await tester.pumpWidget(
        MaterialApp(
          home: ForumScreen(
            activeAlias: 'EstudianteTester',
            onAliasChanged: (_) {},
            initialPopularServers: popularSample,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Debe renderizar la barra lateral derecha fija
      expect(find.byType(PopularServersSidebar), findsOneWidget);
      expect(find.text('MÁS POPULARES'), findsOneWidget);
      expect(find.text('${popularSample.length}'), findsOneWidget);
      expect(find.text('Comunidades con mayor actividad y aportes'), findsOneWidget);

      // Debe mostrar las comunidades populares con ranking minimalista #1, #2, etc.
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('#2'), findsOneWidget);
      expect(find.text('Ingeniería en Ciencias y Sistemas'), findsWidgets);
      expect(find.text('Médico y Cirujano'), findsWidgets);
      expect(find.text('Ciencias Jurídicas y Sociales'), findsWidgets);
    });

    testWidgets('Al tocar un servidor en la barra lateral derecha de populares se navega a ese servidor', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final popularSample = PopularServerItem.defaultPopularServers();

      await tester.pumpWidget(
        MaterialApp(
          home: ForumScreen(
            activeAlias: 'EstudianteTester',
            onAliasChanged: (_) {},
            initialPopularServers: popularSample,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tocamos Médico y Cirujano dentro de la barra lateral derecha de populares
      final medCard = find.descendant(
        of: find.byType(PopularServersSidebar),
        matching: find.text('Médico y Cirujano'),
      );
      expect(medCard, findsOneWidget);
      await tester.tap(medCard);
      await tester.pumpAndSettle();

      // Debe cambiar el servidor activo a Médico y Cirujano
      expect(find.text('Médico y Cirujano'), findsWidgets);
      expect(find.text('MED'), findsWidgets);

      // Y debe tener abierto por defecto todos-los-temas
      expect(find.text('¡Te damos la bienvenida a #todos-los-temas!'), findsOneWidget);
    });

    testWidgets('En vista móvil (400x800) el botón de fuego en la cabecera abre el modal con las comunidades populares', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final popularSample = PopularServerItem.defaultPopularServers();

      await tester.pumpWidget(
        MaterialApp(
          home: ForumScreen(
            activeAlias: 'EstudianteTester',
            onAliasChanged: (_) {},
            initialPopularServers: popularSample,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // En móvil no se muestra la barra fija a la derecha
      expect(find.byType(PopularServersSidebar), findsNothing);

      // Tocamos el botón de fuego en la cabecera móvil
      final fireBtn = find.byIcon(Icons.local_fire_department_rounded);
      expect(fireBtn, findsOneWidget);
      await tester.tap(fireBtn);
      await tester.pumpAndSettle();

      // Debe desplegarse el modal con la barra de populares
      expect(find.byType(PopularServersSidebar), findsOneWidget);
      expect(find.text('MÁS POPULARES'), findsOneWidget);
      expect(find.text('${popularSample.length}'), findsOneWidget);
    });

    testWidgets('PopularServersSidebar muestra únicamente servidores reales disponibles (sin datos falsos ni relleno)', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Solo 2 servidores reales
      final twoServers = PopularServerItem.defaultPopularServers().take(2).toList();

      await tester.pumpWidget(
        MaterialApp(
          home: ForumScreen(
            activeAlias: 'EstudianteTester',
            onAliasChanged: (_) {},
            initialPopularServers: twoServers,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Debe mostrar el conteo real '2' sin inventar 5
      expect(find.text('2'), findsOneWidget);
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('#2'), findsOneWidget);
      expect(find.text('#3'), findsNothing);
      expect(find.text('#4'), findsNothing);
      expect(find.text('#5'), findsNothing);
    });

    testWidgets('PopularServersSidebar muestra estado vacío limpio cuando no hay comunidades populares registradas', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: ForumScreen(
            activeAlias: 'EstudianteTester',
            onAliasChanged: (_) {},
            initialPopularServers: const [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sin actividad registrada aún'), findsOneWidget);
      expect(find.text('#1'), findsNothing);
    });

    testWidgets('Facultad con una sola carrera (como Derecho o Odontología) no despliega submenú y selecciona directamente el servidor', (tester) async {
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

      // Buscamos el botón de Derecho (DER) en el riel
      final derIcon = find.descendant(
        of: find.byType(ForumServerRail),
        matching: find.text('DER'),
      );
      expect(derIcon, findsOneWidget);

      // Al tocar DER, como solo tiene 1 carrera, no debe abrir submenú flotante sino seleccionar directamente
      await tester.tap(derIcon);
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(ForumChannelSidebar),
          matching: find.text('Ciencias Jurídicas y Sociales'),
        ),
        findsOneWidget,
      );
    });
  });
}

