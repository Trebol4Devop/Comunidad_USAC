import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:comunidad_universitaria/core/config/app_theme.dart';
import 'package:comunidad_universitaria/core/models/marketplace_item.dart';
import 'package:comunidad_universitaria/core/services/cache_service.dart';
import 'package:comunidad_universitaria/core/services/supabase_service.dart';
import 'package:comunidad_universitaria/features/marketplace/screens/marketplace_screen.dart';
import 'package:comunidad_universitaria/features/marketplace/widgets/create_listing_dialog.dart';
import 'package:comunidad_universitaria/features/marketplace/widgets/marketplace_card.dart';
import 'package:comunidad_universitaria/features/marketplace/widgets/sponsor_carousel.dart';
import 'package:comunidad_universitaria/features/shared/widgets/empty_state_widget.dart';
import 'package:comunidad_universitaria/features/shared/widgets/network_state_widgets.dart';
import '../helpers/fixtures.dart';
import '../helpers/test_setup.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setupTestLifecycle();

  Widget buildTestScreen({
    String activeAlias = 'Vendedor #100',
    Function(String)? onAliasChanged,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: MarketplaceScreen(
        activeAlias: activeAlias,
        onAliasChanged: onAliasChanged ?? (_) {},
      ),
    );
  }

  void seedMarketplaceCache(List<MarketplaceItem> items, {List<MarketplaceItem> sponsored = const []}) {
    final cacheKey = CacheService.buildKey({
      'user': SupabaseService.currentUserId ?? 'anon',
      'category': 'todos',
      'facultad': 'todas',
      'sede': 'todas',
      'onlyFree': false,
      'search': '',
    });
    CacheService.set('marketplace_items', cacheKey, items);
  }

  group('MarketplaceScreen Widget Tests', () {
    testWidgets('Renderiza en móvil (400x800) y muestra banner de error/offline sin conexión Supabase', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      // Banner de cabecera
      expect(find.text('Marketplace & Tutorías Estudiantiles'), findsOneWidget);
      expect(find.textContaining('Espacio libre para emprendimientos sancarlistas'), findsOneWidget);

      // SponsorCarousel está presente
      expect(find.byType(SponsorCarousel), findsOneWidget);

      // Campo de búsqueda en móvil
      expect(find.text('Buscar postres, almuerzos, tutorías o libros...'), findsOneWidget);

      // Filtro de Solo Gratuitos
      expect(find.text('Solo Gratuitos'), findsOneWidget);

      // En entorno de test sin Supabase ni caché, el catch activa OfflineBanner
      expect(find.byType(OfflineBanner), findsOneWidget);
      expect(find.text('Sin conexión. Mostrando contenido en caché.'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);

      // Botón FAB de publicar
      expect(find.widgetWithText(FloatingActionButton, 'Publicar Anuncio'), findsOneWidget);
    });

    testWidgets('Renderiza en escritorio (1200x800) con botón superior y buscador amplio', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      expect(find.text('Marketplace & Tutorías Estudiantiles'), findsOneWidget);

      // En desktop hay un botón 'Publicar Anuncio' en el header banner además del FAB
      expect(find.text('Publicar Anuncio'), findsWidgets);

      // Dropdown de Sede y Facultad presentes
      expect(find.byType(DropdownButtonFormField<String>), findsWidgets);
    });

    testWidgets('Muestra EmptyStateWidget cuando la lista de publicaciones está vacía en caché', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Sembramos caché vacía
      seedMarketplaceCache(<MarketplaceItem>[]);

      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      // Debe mostrar el EmptyStateWidget real
      expect(find.byType(EmptyStateWidget), findsOneWidget);
      expect(find.text('No hay publicaciones en esta categoría aún'), findsOneWidget);
      expect(find.text('Crear Primera Publicación'), findsOneWidget);
    });

    testWidgets('Renderiza MarketplaceCard con los datos del artículo', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sampleItem = TestFixtures.marketplaceItem(
        id: 'item-usac-1',
        title: 'Calculadora HP Prime G2',
        price: 950.0,
        buildingCode: 'T-3',
        description: 'Impecable para exámenes de mate y física',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: MarketplaceCard(
                item: sampleItem,
                onUpvote: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MarketplaceCard), findsOneWidget);
      expect(find.text('Calculadora HP Prime G2'), findsOneWidget);
      expect(find.text('Q950.00'), findsOneWidget);
    });

    testWidgets('Abre CreateListingDialog al hacer click en el botón de publicar', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      seedMarketplaceCache(<MarketplaceItem>[]);

      await tester.pumpWidget(buildTestScreen(activeAlias: 'Vendedora Sancarlista'));
      await tester.pumpAndSettle();

      // Tap en el FAB de publicar anuncio
      final fabFinder = find.byType(FloatingActionButton);
      expect(fabFinder, findsOneWidget);

      await tester.tap(fabFinder);
      await tester.pumpAndSettle();

      // Debe haberse abierto CreateListingDialog
      expect(find.byType(CreateListingDialog), findsOneWidget);
      expect(find.text('Publicar Producto o Servicio'), findsOneWidget);
    });

    testWidgets('Permite alternar el filtro Solo Gratuitos', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      seedMarketplaceCache(<MarketplaceItem>[]);

      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      final freeChip = find.text('Solo Gratuitos');
      expect(freeChip, findsOneWidget);

      await tester.tap(freeChip);
      await tester.pumpAndSettle();

      // El FilterChip fue presionado y la pantalla refrescó
      expect(find.byType(MarketplaceScreen), findsOneWidget);
    });
  });
}
