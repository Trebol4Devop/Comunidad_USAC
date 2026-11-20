import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:comunidad_universitaria/core/config/app_theme.dart';
import 'package:comunidad_universitaria/core/models/marketplace_item.dart';
import 'package:comunidad_universitaria/features/marketplace/widgets/create_listing_dialog.dart';
import 'package:comunidad_universitaria/features/profile/screens/profile_screen.dart';
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
      expect(find.text('Marketplace Universitario · Comunidad USAC'), findsNothing);
      expect(find.text('Perfil estudiantil de contacto directo'), findsNothing);
      expect(find.byType(IdentityBadgeChip), findsOneWidget);
      expect(find.byIcon(PhosphorIconsRegular.gear), findsOneWidget);

      // Categoría y checkbox de gratuidad
      expect(find.text('Categoría'), findsOneWidget);
      expect(find.text('Aporte o tutoría GRATUITA'), findsOneWidget);

      // Campos de formulario
      expect(find.widgetWithText(TextFormField, 'Título del producto o servicio'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Precio en Quetzales'), findsOneWidget);

      // Sin campos embebidos de canales; muestra botón para configurar si no hay canales guardados
      expect(find.widgetWithText(TextFormField, 'WhatsApp'), findsNothing);
      expect(find.widgetWithText(TextFormField, 'Instagram'), findsNothing);
      expect(find.widgetWithText(TextFormField, 'Facebook Messenger'), findsNothing);
      expect(find.widgetWithText(TextFormField, 'Telegram'), findsNothing);
      expect(find.text('Configurar canales de contacto'), findsOneWidget);

      // Botones de acción
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Publicar Anuncio'), findsOneWidget);
    });

    testWidgets(
      'Oculta el botón Configurar canales de contacto cuando ya hay al menos un canal configurado',
      (tester) async {
        await resetTestState(
          initialPrefs: {'usac_contact_messenger': 'm.me/mi_tienda'},
        );
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestDialog());
        await tester.pumpAndSettle();

        expect(find.text('Configurar canales de contacto'), findsNothing);
      },
    );

    testWidgets(
      'El botón Configurar canales de contacto navega a ProfileScreen',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestDialog());
        await tester.pumpAndSettle();

        final configBtn = find.text('Configurar canales de contacto');
        expect(configBtn, findsOneWidget);
        await tester.ensureVisible(configBtn);
        await tester.tap(configBtn);
        await tester.pumpAndSettle();

        expect(find.byType(ProfileScreen), findsOneWidget);
        expect(
          find.widgetWithText(TextField, 'Facebook Messenger'),
          findsOneWidget,
        );
      },
    );

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

      // Intentamos publicar sin canales configurados en perfil
      final publishBtn = find.text('Publicar Anuncio');
      await tester.ensureVisible(publishBtn);
      await tester.tap(publishBtn);
      await tester.pumpAndSettle();

      // Debe advertir por falta de canales de contacto en el perfil
      expect(
        find.text('Debes configurar al menos un canal de contacto en tu perfil.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'CreateListingDialog.show abre una vista separada con AppBar y caretLeft en móvil',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => CreateListingDialog.show(
                    ctx,
                    activeAlias: 'Vendedora USAC #22',
                    onAliasChanged: (_) {},
                    onListingCreated: (_) {},
                  ),
                  child: const Text('Abrir crear anuncio'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Abrir crear anuncio'));
        await tester.pumpAndSettle();

        expect(find.byType(CreateListingDialog), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(CreateListingDialog),
            matching: find.byType(Scaffold),
          ),
          findsOneWidget,
        );
        expect(find.byType(AppBar), findsOneWidget);
        expect(find.text('Publicar Producto o Servicio'), findsOneWidget);
        expect(find.byIcon(PhosphorIconsBold.caretLeft), findsOneWidget);
        expect(find.byType(BottomSheet), findsNothing);
        expect(find.byType(Dialog), findsNothing);
      },
    );
  });
}
