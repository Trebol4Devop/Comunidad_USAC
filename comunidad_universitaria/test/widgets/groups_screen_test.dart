import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
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

  void seedGroupsCache(
    List<WhatsAppGroup> groups, {
    String carrera = 'todas',
    String facultad = 'todas',
  }) {
    final cacheKey = CacheService.buildKey({
      'user': SupabaseService.currentUserId ?? 'anon',
      if (facultad != 'todas') 'facultad': facultad,
      'carrera': carrera,
      'search': '',
    });
    CacheService.set('student_groups', cacheKey, groups);
  }

  group('GroupsScreen Widget Tests', () {
    testWidgets('Renderiza en móvil y distingue error de carga de lista vacía', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      // Encabezado Zanate del directorio estudiantil
      expect(find.text('DIRECTORIO ESTUDIANTIL'), findsOneWidget);
      expect(find.text('Grupos de Estudio'), findsOneWidget);
      final prefsButton = find.byWidgetPredicate(
        (w) =>
            w is Icon &&
            (w.icon == PhosphorIconsRegular.slidersHorizontal ||
                w.icon == PhosphorIconsFill.slidersHorizontal),
      );
      expect(prefsButton, findsOneWidget);
      expect(find.byTooltip('Compartir Grupo'), findsOneWidget);

      // La búsqueda permanece visible y accesible aunque falle la carga.
      expect(find.byType(TextField), findsOneWidget);
      expect(
        find.text('Buscar cursos, secciones o palabras clave...'),
        findsOneWidget,
      );

      // Sin Supabase configurado, la carga falla: no debe mostrarse como lista vacía.
      expect(find.byType(EmptyStateWidget), findsNothing);
      expect(
        find.text('No se pudieron cargar los grupos. Revisa tu conexión.'),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsOneWidget);
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(
        find.text('No se pudieron cargar los grupos. Revisa tu conexión.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'Renderiza en escritorio (1200x800) con cabecera Zanate y único botón de compartir',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestScreen());
        await tester.pumpAndSettle();

        expect(find.text('DIRECTORIO ESTUDIANTIL'), findsOneWidget);
        expect(find.text('Grupos de Estudio'), findsOneWidget);

        // Botón único '+' para compartir grupo en cabecera
        expect(find.byTooltip('Compartir Grupo'), findsOneWidget);

        // Las facultades se manejan en el bottom sheet Zanate de preferencias, no como dropdown inline.
        expect(find.byType(DropdownButtonFormField<String>), findsNothing);
        expect(find.byType(TextField), findsOneWidget);
      },
    );

    testWidgets('Permite abrir la hoja de preferencias de facultad', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      final prefsButton = find.byWidgetPredicate(
        (w) =>
            w is Icon &&
            (w.icon == PhosphorIconsRegular.slidersHorizontal ||
                w.icon == PhosphorIconsFill.slidersHorizontal),
      );
      expect(prefsButton, findsOneWidget);
      await tester.tap(prefsButton);
      await tester.pumpAndSettle();

      expect(find.text('Filtrar por Facultad'), findsOneWidget);
    });

    testWidgets(
      'Renderiza la lista de Grupos en tableta con datos en caché',
      (tester) async {
        tester.view.physicalSize = const Size(800, 800);
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

        expect(find.byType(ListView), findsWidgets);
        expect(find.byType(GroupCard), findsOneWidget);
        expect(find.text('Física 1 - Sección B'), findsOneWidget);
        expect(find.text('15'), findsOneWidget);
        final voteButton = find.ancestor(
          of: find.text('15'),
          matching: find.byType(InkWell),
        );
        expect(voteButton, findsOneWidget);
        expect(tester.getSize(voteButton).height, greaterThanOrEqualTo(48));
      },
    );

    testWidgets('Rechaza esquemas inseguros al abrir enlaces de grupos', (
      tester,
    ) async {
      final unsafeGroup = TestFixtures.whatsAppGroup(
        id: 'unsafe-group',
        title: 'Enlace inseguro',
        link: 'javascript:alert(1)',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GroupCard(group: unsafeGroup, onUpvote: () {}),
          ),
        ),
      );

      await tester.tap(find.text('Unirse al Grupo'));
      await tester.pumpAndSettle();

      expect(find.text('El enlace del grupo no es válido.'), findsOneWidget);
    });

    testWidgets('Abre CreateGroupDialog al hacer click en compartir grupo', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestScreen(activeAlias: 'Auxiliar #42'));
      await tester.pumpAndSettle();

      final shareBtn = find.byTooltip('Compartir Grupo');
      expect(shareBtn, findsOneWidget);

      await tester.tap(shareBtn);
      await tester.pumpAndSettle();

      // Debe haberse abierto CreateGroupDialog
      expect(find.byType(CreateGroupDialog), findsOneWidget);
      expect(find.text('Compartir Enlace de Grupo'), findsOneWidget);
    });
  });
}
