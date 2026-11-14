import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:comunidad_universitaria/core/config/app_theme.dart';
import 'package:comunidad_universitaria/core/models/marketplace_item.dart';
import 'package:comunidad_universitaria/features/marketplace/screens/product_detail_screen.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget buildTestScreen(MarketplaceItem item) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: ProductDetailScreen(
        itemId: item.id,
        initialItem: item,
      ),
    );
  }

  group('ProductDetailScreen Tests', () {
    testWidgets('Verifica bloques 1-4 con un artículo disponible', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final availableItem = MarketplaceItem(
        id: 'item-101',
        title: 'Calculadora HP Prime G2',
        description: 'Calculadora graficadora táctil en perfecto estado.',
        price: 950.0,
        status: 'available',
        category: 'electronica',
        sede: 'central',
        facultad: 'Ingeniería',
        buildingCode: 'T-3',
        locationDetail: 'Laboratorio de Física',
        authorAlias: 'Estudiante Emprendedor',
        sellerPublicId: 'sp-101',
        sellerBadgeText: 'Emprendedor Verificado',
        sellerIsOnCampus: true,
        sellerBuildingCode: 'T-3',
        contactWhatsapp: '50212345678',
        contactTelegram: 'usuario_test',
        imageUrls: ['https://example.com/img1.jpg', 'https://example.com/img2.jpg'],
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      );

      await tester.pumpWidget(buildTestScreen(availableItem));
      await tester.pumpAndSettle();

      // Bloque 1: Galería / PageView
      expect(find.byType(PageView), findsOneWidget);
      expect(find.text('1/2'), findsOneWidget);

      // Bloque 2: Información principal
      expect(find.text('Calculadora HP Prime G2'), findsWidgets);
      expect(find.text('Q950.00'), findsOneWidget);
      expect(find.text('Disponible'), findsOneWidget);
      expect(find.text('Campus Central · Zona 12'), findsOneWidget);
      expect(find.text('INGENIERÍA'), findsOneWidget);
      expect(find.textContaining('T-3'), findsWidgets);

      // Bloque 3: Vendedor y presencia
      expect(find.text('Estudiante Emprendedor'), findsOneWidget);
      expect(find.text('Emprendedor Verificado'), findsOneWidget);
      expect(find.textContaining('Entregando ahora en edificio T-3'), findsOneWidget);
      expect(find.text('Ver tienda'), findsOneWidget);

      // Bloque 4: Acciones de contacto habilitadas
      expect(find.text('Contactar por WhatsApp'), findsOneWidget);
      expect(find.text('Telegram'), findsOneWidget);
      expect(
        find.textContaining('El contacto directo está deshabilitado'),
        findsNothing,
      );
    });

    testWidgets('Oculta y deshabilita botones de contacto cuando el artículo está vendido (isSold)', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final soldItem = MarketplaceItem(
        id: 'item-sold-99',
        title: 'Libro Física Universitaria Sears Zemansky',
        description: 'Volumen 1 en buen estado.',
        price: 180.0,
        status: 'sold',
        category: 'libros',
        sede: 'Campus Central',
        authorAlias: 'Vendedor Egresado',
        contactWhatsapp: '50212345678',
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
      );

      await tester.pumpWidget(buildTestScreen(soldItem));
      await tester.pumpAndSettle();

      // Bloque 2: Estado Vendido
      expect(find.text('Vendido'), findsOneWidget);
      expect(find.text('Este artículo ya fue vendido.'), findsOneWidget);

      // Bloque 4: Deshabilitado / Oculto
      expect(find.text('Contactar por WhatsApp'), findsNothing);
      expect(
        find.text('El contacto directo está deshabilitado porque este artículo ya fue vendido.'),
        findsOneWidget,
      );
    });
  });
}
