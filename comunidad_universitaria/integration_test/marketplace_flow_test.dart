import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:comunidad_universitaria/core/services/marketplace_service.dart';
import 'package:comunidad_universitaria/core/services/supabase_service.dart';
import 'helpers/app_launcher.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('E2E: Flujo Real de Marketplace (Crear / Leer / Borrar)', () {
    testWidgets(
      'Crea una publicación en Marketplace, cambia su estado y la elimina',
      skip: !isLocalSupabaseConfigured,
      (tester) async {
        final uniqueTitle = 'Artículo E2E Marketplace ${DateTime.now().millisecondsSinceEpoch}';

        await launchApp(tester, surfaceSize: const Size(400, 800));

        // Navegar a pestaña de Marketplace
        await tester.tap(find.text('Marketplace'));
        await tester.pumpAndSettle();

        // 1. Crear producto en el marketplace
        final listing = await MarketplaceService.createListing(
          title: uniqueTitle,
          description: 'Artículo de prueba creado durante el flujo E2E automatizado.',
          price: 95.0,
          isFree: false,
          category: 'otros_articulos',
          facultad: '08',
          sede: 'central',
          buildingCode: 'T-3',
          locationDetail: 'Laboratorio de cómputo',
          authorAlias: 'E2E Market Tester',
        );

        expect(listing, isNotNull);
        expect(listing!.status, equals('available'));

        // 2. Consultar listings activos
        final listings = await MarketplaceService.fetchListings(category: 'otros_articulos');
        expect(listings.any((item) => item.id == listing.id), isTrue);

        // 3. Actualizar estado a pausado
        final updated = await MarketplaceService.updateItemStatus(itemId: listing.id, newStatus: 'paused');
        expect(updated, isTrue);

        // 4. Limpieza en base de datos
        await SupabaseService.client
            .from('marketplace_upvotes')
            .delete()
            .eq('item_id', listing.id);

        await SupabaseService.client
            .from('marketplace_items')
            .delete()
            .eq('id', listing.id);

        final check = await SupabaseService.client
            .from('marketplace_items')
            .select('id')
            .eq('id', listing.id);

        expect((check as List).isEmpty, isTrue);
      },
    );
  });
}
