import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:comunidad_universitaria/features/groups/widgets/create_group_dialog.dart';
import 'package:comunidad_universitaria/features/marketplace/widgets/create_listing_dialog.dart';
import 'package:comunidad_universitaria/features/profile/screens/profile_screen.dart';
import 'package:comunidad_universitaria/features/rules/screens/rules_screen.dart';
import 'package:comunidad_universitaria/features/shared/widgets/alias_badge_button.dart';
import 'helpers/app_launcher.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('E2E: Flujo de Navegación de Invitado (Sin Backend)', () {
    testWidgets('Navegación fluida entre pestañas en vista móvil (400x800)', (tester) async {
      await launchApp(tester, surfaceSize: const Size(400, 800));

      // 1. Inicia en el Foro Estudiantil
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Foro'), findsOneWidget);

      // 2. Navegar a Grupos
      final gruposTab = find.text('Grupos');
      expect(gruposTab, findsOneWidget);
      await tester.tap(gruposTab);
      await tester.pumpAndSettle();

      // Debe aparecer el FAB de sugerir enlace
      expect(find.text('Sugerir Enlace'), findsOneWidget);

      // 3. Navegar a Marketplace
      final marketplaceTab = find.text('Marketplace');
      expect(marketplaceTab, findsOneWidget);
      await tester.tap(marketplaceTab);
      await tester.pumpAndSettle();

      // Debe aparecer el FAB de publicar artículo
      expect(find.text('Publicar Artículo'), findsOneWidget);

      // 4. Regresar a Foro
      final foroTab = find.text('Foro');
      await tester.tap(foroTab);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('Interacción con AppBar: aviso legal, normas, perfil y cambio de tema', (tester) async {
      await launchApp(tester, surfaceSize: const Size(400, 800));

      // 1. Abrir diálogo de Aviso Comunitario desde el título 'Comunidad USAC'
      final titleWidget = find.text('Comunidad USAC');
      expect(titleWidget, findsOneWidget);
      await tester.tap(titleWidget);
      await tester.pumpAndSettle();

      expect(find.text('Aviso Comunitario'), findsOneWidget);
      expect(find.text('Entendido'), findsOneWidget);
      await tester.tap(find.text('Entendido'));
      await tester.pumpAndSettle();

      // 2. Navegar a la pantalla de Normas (RulesScreen)
      final shieldIcon = find.byIcon(Icons.shield_outlined);
      expect(shieldIcon, findsOneWidget);
      await tester.tap(shieldIcon);
      await tester.pumpAndSettle();

      expect(find.byType(RulesScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(RulesScreen))).pop();
      await tester.pumpAndSettle();

      // 3. Navegar a la pantalla de Perfil (ProfileScreen) vía AliasBadgeButton
      final aliasBadge = find.byType(AliasBadgeButton);
      expect(aliasBadge, findsOneWidget);
      await tester.tap(aliasBadge);
      await tester.pumpAndSettle();

      expect(find.byType(ProfileScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(ProfileScreen))).pop();
      await tester.pumpAndSettle();

      // 4. Alternar tema claro/oscuro
      final themeToggle = find.byTooltip('Cambiar tema');
      expect(themeToggle, findsOneWidget);
      await tester.tap(themeToggle);
      await tester.pumpAndSettle();
    });

    testWidgets('Apertura y cierre de diálogos de creación (Grupos y Marketplace)', (tester) async {
      await launchApp(tester, surfaceSize: const Size(400, 800));

      // Ir a pestaña de grupos
      await tester.tap(find.text('Grupos'));
      await tester.pumpAndSettle();

      // Abrir diálogo de crear grupo
      final fabGrupos = find.text('Sugerir Enlace');
      expect(fabGrupos, findsOneWidget);
      await tester.tap(fabGrupos);
      await tester.pumpAndSettle();

      expect(find.byType(CreateGroupDialog), findsOneWidget);
      Navigator.of(tester.element(find.byType(CreateGroupDialog))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(CreateGroupDialog), findsNothing);

      // Ir a pestaña de marketplace
      await tester.tap(find.text('Marketplace'));
      await tester.pumpAndSettle();

      // Abrir diálogo de crear publicación de marketplace
      final fabMarket = find.text('Publicar Artículo');
      expect(fabMarket, findsOneWidget);
      await tester.tap(fabMarket);
      await tester.pumpAndSettle();

      expect(find.byType(CreateListingDialog), findsOneWidget);
      Navigator.of(tester.element(find.byType(CreateListingDialog))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(CreateListingDialog), findsNothing);
    });

    testWidgets('Modo escritorio (1200x800): renderiza barra superior horizontal y oculta NavigationBar', (tester) async {
      await launchApp(tester, surfaceSize: const Size(1200, 800));

      // No debe existir bottom NavigationBar en escritorio
      expect(find.byType(NavigationBar), findsNothing);

      // Deben estar las pestañas de navegación horizontal
      expect(find.text('Foro Estudiantil'), findsOneWidget);
      expect(find.text('Grupos de Estudio'), findsOneWidget);
      expect(find.text('Marketplace & Tutorías'), findsOneWidget);

      // Alternar hacia Grupos de Estudio
      await tester.tap(find.text('Grupos de Estudio'));
      await tester.pumpAndSettle();

      // Alternar hacia Marketplace
      await tester.tap(find.text('Marketplace & Tutorías'));
      await tester.pumpAndSettle();

      // Regresar al Foro
      await tester.tap(find.text('Foro Estudiantil'));
      await tester.pumpAndSettle();
    });
  });
}
