import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:comunidad_universitaria/core/config/app_theme.dart';
import 'package:comunidad_universitaria/core/models/whatsapp_group.dart';
import 'package:comunidad_universitaria/core/services/cache_service.dart';
import 'package:comunidad_universitaria/core/services/supabase_service.dart';
import 'package:comunidad_universitaria/features/groups/screens/groups_screen.dart';
import 'package:comunidad_universitaria/features/groups/widgets/create_group_dialog.dart';
import 'package:comunidad_universitaria/features/groups/widgets/group_card.dart';
import 'package:comunidad_universitaria/features/shared/widgets/empty_state_widget.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_setup.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setupTestLifecycle();

  Widget buildTestScreen({
    String activeAlias = 'Estudiante #200',
    Function(String)? onAliasChanged,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: GroupsScreen(
        activeAlias: activeAlias,
        onAliasChanged: onAliasChanged ?? (_) {},
      ),
    );
  }

  void seedGroupsCache(List<WhatsAppGroup> groups, {String carrera = 'todas', String facultad = 'todas'}) {
    final cacheKey = CacheService.buildKey({
      'user': SupabaseService.currentUserId ?? 'anon',
      if (facultad != 'todas') 'facultad': facultad,
      'carrera': carrera,
      'search': '',
    });
    CacheService.set('student_groups', cacheKey, groups);
  }

  group('GroupsScreen Widget Tests', () {
    testWidgets('Renderiza en móvil (400x800) con banner superior, aviso semestral y empty state', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      // Banner superior
      expect(find.text('Directorio de Grupos de Estudio'), findsOneWidget);
      expect(find.textContaining('Comunidad libre para encontrar y compartir enlaces de grupos'), findsOneWidget);

      // Aviso de depuración semestral
      expect(find.textContaining('Para evitar enlaces caídos, los grupos se depuran automáticamente'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);

      // Buscador móvil
      expect(find.text('Buscar por curso, catedrático o sección...'), findsOneWidget);

      // Sin conexión/datos reales, GroupsScreen maneja el fallback y muestra EmptyStateWidget
      expect(find.byType(EmptyStateWidget), findsOneWidget);
      expect(find.text('No se encontraron grupos para este filtro'), findsOneWidget);
      expect(find.text('Compartir Enlace'), findsOneWidget);

      // FAB para compartir grupo
      expect(find.widgetWithText(FloatingActionButton, 'Compartir Grupo'), findsOneWidget);
    });

    testWidgets('Renderiza en escritorio (1200x800) con único botón inferior de compartir y buscador', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      expect(find.text('Directorio de Grupos de Estudio'), findsOneWidget);

      // Único botón de compartir grupo en la parte inferior (se eliminó la redundancia del banner superior)
      expect(find.text('Compartir Grupo'), findsOneWidget);

      // Las facultades se manejan como canales de servidor en la barra lateral, no como dropdown en la página
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    });

    testWidgets('Permite descartar el aviso semestral con el botón cerrar', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      final bannerFinder = find.textContaining('Para evitar enlaces caídos, los grupos se depuran automáticamente');
      expect(bannerFinder, findsOneWidget);

      // Tap en el botón de cerrar aviso
      final closeButton = find.byIcon(Icons.close);
      expect(closeButton, findsOneWidget);
      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      // El aviso ya no debe estar visible
      expect(bannerFinder, findsNothing);
    });

    testWidgets('Renderiza GroupCard cuando hay grupos en caché', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sampleGroup = TestFixtures.whatsAppGroup(
        id: 'group-101',
        title: 'Física 1 - Sección B',
        curso: 'Física 1',
        section: 'Sección B',
        carrera: 'sistemas',
        upvotes: 15,
        link: 'https://chat.whatsapp.com/TestGroup123',
      );

      // Sembramos la caché para la carrera default y contexto del usuario (08 - sistemas)
      seedGroupsCache([sampleGroup], carrera: 'sistemas', facultad: '08');
      seedGroupsCache([sampleGroup], carrera: 'sistemas');
      seedGroupsCache([sampleGroup], carrera: 'todas');

      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      expect(find.byType(GroupCard), findsOneWidget);
      expect(find.text('Física 1 - Sección B'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
    });

    testWidgets('Abre CreateGroupDialog al hacer click en compartir grupo', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestScreen(activeAlias: 'Auxiliar #42'));
      await tester.pumpAndSettle();

      final fab = find.byType(FloatingActionButton);
      expect(fab, findsOneWidget);

      await tester.tap(fab);
      await tester.pumpAndSettle();

      // Debe haberse abierto CreateGroupDialog
      expect(find.byType(CreateGroupDialog), findsOneWidget);
      expect(find.text('Compartir Enlace de Grupo'), findsOneWidget);
    });
  });
}
