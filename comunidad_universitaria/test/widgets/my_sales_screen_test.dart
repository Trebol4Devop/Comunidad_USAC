import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:comunidad_universitaria/core/config/app_theme.dart';
import 'package:comunidad_universitaria/core/models/marketplace_item.dart';
import 'package:comunidad_universitaria/core/models/marketplace_metrics.dart';
import 'package:comunidad_universitaria/core/models/marketplace_seller_status.dart';
import 'package:comunidad_universitaria/features/marketplace/screens/my_sales_screen.dart';
import 'package:comunidad_universitaria/features/shared/widgets/empty_state_widget.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget buildTestScreen({
    MarketplaceSellerStatus? status,
    List<MarketplaceItem>? listings,
    List<MarketplaceMetrics>? metrics,
    Future<bool> Function(String itemId, String newStatus)? onItemStatusChanged,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: MySalesScreen(
        initialStatus: status,
        initialListings: listings,
        initialMetrics: metrics ?? const [],
        onItemStatusChanged: onItemStatusChanged,
      ),
    );
  }

  group('MySalesScreen Tests', () {
    testWidgets('Renderiza lista de inventario y cambio de estado invoca callback', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final testStatus = const MarketplaceSellerStatus(
        sellerType: 'student',
        planId: 'free',
        planName: 'Estudiante',
        canPublish: true,
        activeItems: 1,
        maxActiveItems: 3,
        remainingSlots: 2,
      );

      final item = MarketplaceItem(
        id: 'sale-item-1',
        title: 'Bata de Laboratorio Talla M',
        description: 'Bata blanca reglamentaria para química.',
        price: 85.0,
        status: 'available',
        category: 'otros_articulos',
        authorAlias: 'Mi Usuario',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      );

      String? updatedItemId;
      String? updatedStatus;

      await tester.pumpWidget(
        buildTestScreen(
          status: testStatus,
          listings: [item],
          onItemStatusChanged: (id, newStatus) async {
            updatedItemId = id;
            updatedStatus = newStatus;
            return true;
          },
        ),
      );
      await tester.pumpAndSettle();

      // Verifica encabezado de cupo
      expect(find.text('Plan Estudiante'), findsOneWidget);
      expect(find.text('1 de 3 publicaciones activas'), findsOneWidget);

      // Verifica ítem en inventario
      expect(find.text('Bata de Laboratorio Talla M'), findsOneWidget);
      expect(find.text('Q85.00'), findsOneWidget);
      expect(find.text('Disponible'), findsOneWidget);

      // Toca el selector de estado (PopupMenuButton)
      await tester.tap(find.text('Disponible'));
      await tester.pumpAndSettle();

      // Selecciona "Vendido" del menú
      expect(find.text('Vendido'), findsOneWidget);
      await tester.tap(find.text('Vendido'));
      await tester.pumpAndSettle();

      // Verifica que el callback fue invocado con el ID y el nuevo estado
      expect(updatedItemId, equals('sale-item-1'));
      expect(updatedStatus, equals('sold'));

      // Y que la interfaz se actualizó optimísticamente
      expect(find.text('Vendido'), findsOneWidget);
    });

    testWidgets('Muestra EmptyStateWidget cuando no hay publicaciones en el inventario', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final testStatus = const MarketplaceSellerStatus(
        sellerType: 'student',
        planId: 'free',
        planName: 'Estudiante',
        canPublish: true,
        activeItems: 0,
        maxActiveItems: 3,
        remainingSlots: 3,
      );

      await tester.pumpWidget(
        buildTestScreen(
          status: testStatus,
          listings: <MarketplaceItem>[],
        ),
      );
      await tester.pumpAndSettle();

      // Verifica el estado vacío
      expect(find.byType(EmptyStateWidget), findsOneWidget);
      expect(find.text('Aún no tienes publicaciones'), findsOneWidget);
      expect(find.text('Crear Publicación'), findsOneWidget);
    });
  });
}
