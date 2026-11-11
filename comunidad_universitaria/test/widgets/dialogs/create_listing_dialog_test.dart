import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:comunidad_universitaria/core/config/app_theme.dart';
import 'package:comunidad_universitaria/core/models/marketplace_item.dart';
import 'package:comunidad_universitaria/features/marketplace/widgets/create_listing_dialog.dart';
import 'package:comunidad_universitaria/features/shared/widgets/identity_badge_chip.dart';
import '../../helpers/test_setup.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setupTestLifecycle();

  Widget buildTestDialog({
    String activeAlias = 'Vendedora USAC #22',
    Function(String)? onAliasChanged,
    Function(MarketplaceItem)? onListingCreated,
    bool isSponsored = false,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: CreateListingDialog(
          activeAlias: activeAlias,
          onAliasChanged: onAliasChanged ?? (_) {},
          onListingCreated: onListingCreated ?? (_) {},
          isSponsored: isSponsored,
        ),
      ),
    );
  }

  group('CreateListingDialog Widget Tests', () {
    testWidgets('Renderiza en vista móvil (400x800) con todos los campos clave', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestDialog());
      await tester.pumpAndSettle();

      expect(find.text('Publicar Producto o Servicio'), findsOneWidget);
      expect(find.byType(IdentityBadgeChip), findsOneWidget);

      // Categoría y checkbox de gratuidad
      expect(find.text('Categoría'), findsOneWidget);
      expect(find.text('Aporte o tutoría GRATUITA'), findsOneWidget);

      // Campos de formulario
      expect(find.widgetWithText(TextFormField, 'Título del producto o servicio'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Precio en Quetzales'), findsOneWidget);

      // Canales de contacto
      expect(find.text('Canales de Contacto'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'WhatsApp'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Instagram'), findsOneWidget);

      // Botones de acción
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Publicar Anuncio'), findsOneWidget);
    });

    testWidgets('Toggle de Aporte GRATUITO oculta el campo de Precio', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestDialog());
      await tester.pumpAndSettle();

      // Inicialmente el campo de precio está visible
      expect(find.widgetWithText(TextFormField, 'Precio en Quetzales'), findsOneWidget);

      // Activamos checkbox gratuito
      final freeCheckbox = find.byType(Checkbox);
      expect(freeCheckbox, findsOneWidget);
      await tester.tap(freeCheckbox);
      await tester.pumpAndSettle();

      // Campo de precio desaparece
      expect(find.widgetWithText(TextFormField, 'Precio en Quetzales'), findsNothing);

      // Desactivamos checkbox
      await tester.tap(freeCheckbox);
      await tester.pumpAndSettle();

      // Vuelve a aparecer
      expect(find.widgetWithText(TextFormField, 'Precio en Quetzales'), findsOneWidget);
    });

    testWidgets('Valida longitud mínima del título al intentar publicar', (tester) async {
      tester.view.physicalSize = const Size(600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestDialog());
      await tester.pumpAndSettle();

      final publishBtn = find.text('Publicar Anuncio');
      await tester.ensureVisible(publishBtn);
      await tester.pumpAndSettle();

      // Tap publicar sin llenar título
      await tester.tap(publishBtn);
      await tester.pumpAndSettle();

      expect(find.text('Ingresa un título de al menos 4 caracteres.'), findsOneWidget);

      // Llenamos con título de 2 letras
      final titleField = find.widgetWithText(TextFormField, 'Título del producto o servicio');
      await tester.ensureVisible(titleField);
      await tester.enterText(titleField, 'AB');
      await tester.ensureVisible(publishBtn);
      await tester.tap(publishBtn);
      await tester.pumpAndSettle();

      expect(find.text('Ingresa un título de al menos 4 caracteres.'), findsOneWidget);
    });

    testWidgets('Exige al menos un canal de contacto si el título es válido', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestDialog());
      await tester.pumpAndSettle();

      // Ingresamos un título y descripción válidos
      final titleField = find.widgetWithText(TextFormField, 'Título del producto o servicio');
      await tester.ensureVisible(titleField);
      await tester.enterText(titleField, 'Calculadora Texas TI-84 Plus');

      final descField = find.widgetWithText(TextFormField, 'Descripción detallada');
      await tester.ensureVisible(descField);
      await tester.enterText(descField, 'Calculadora gráfica en perfecto estado con manuales incluidos.');
      await tester.pumpAndSettle();

      // Limpiamos los canales de contacto por si tenían borrador
      final waField = find.widgetWithText(TextFormField, 'WhatsApp');
      await tester.ensureVisible(waField);
      await tester.enterText(waField, '');

      final igField = find.widgetWithText(TextFormField, 'Instagram');
      await tester.ensureVisible(igField);
      await tester.enterText(igField, '');

      final fbField = find.widgetWithText(TextFormField, 'Facebook Messenger');
      await tester.ensureVisible(fbField);
      await tester.enterText(fbField, '');

      final tgField = find.widgetWithText(TextFormField, 'Telegram');
      await tester.ensureVisible(tgField);
      await tester.enterText(tgField, '');
      await tester.pumpAndSettle();

      // Intentamos publicar
      final publishBtn = find.text('Publicar Anuncio');
      await tester.ensureVisible(publishBtn);
      await tester.tap(publishBtn);
      await tester.pumpAndSettle();

      // Debe advertir por falta de canales de contacto
      expect(find.text('Debes proporcionar al menos un canal de contacto.'), findsOneWidget);
    });
  });
}
