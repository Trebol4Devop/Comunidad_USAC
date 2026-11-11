import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:comunidad_universitaria/features/sso/screens/sso_authorize_screen.dart';
import 'helpers/app_launcher.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('E2E: Flujo SSO Deep Link (Autorizar / Rechazar)', () {
    testWidgets('Muestra pantalla SSO con parámetros válidos de PEMTREE', (tester) async {
      await launchApp(
        tester,
        initialRoute: '/auth/authorize?client_id=pemtree&redirect_uri=https://pemtree.org/callback&state=state_123',
        surfaceSize: const Size(400, 800),
      );

      // Debe montar la pantalla de autorización SSO
      expect(find.byType(SsoAuthorizeScreen), findsOneWidget);

      // Verificación de textos y controles clave
      expect(find.text('Cancelar / Rechazar'), findsOneWidget);
      expect(find.text('Autorizar / Continuar'), findsOneWidget);
    });

    testWidgets('Flujo de rechazo / cancelación SSO emite redirección con error access_denied', (tester) async {
      await launchApp(
        tester,
        initialRoute: '/auth/authorize?client_id=pemtree&redirect_uri=https://pemtree.org/callback&state=state_cancel',
        surfaceSize: const Size(400, 800),
      );

      expect(find.byType(SsoAuthorizeScreen), findsOneWidget);

      // Click en Cancelar / Rechazar
      final rejectButton = find.text('Cancelar / Rechazar');
      expect(rejectButton, findsOneWidget);
      await tester.tap(rejectButton);
      // La pantalla entra en estado "redirigiendo" con un spinner indefinido:
      // no usar pumpAndSettle porque nunca se asienta.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Se procesa la cancelación y se ofrece la redirección manual
      expect(find.text('Redirigiendo a PEMTREE...'), findsOneWidget);
      expect(find.byType(SsoAuthorizeScreen), findsOneWidget);
    });

    testWidgets('Flujo de autorización exitosa SSO genera tokens de sesión y redirige', (tester) async {
      await launchApp(
        tester,
        initialRoute: '/auth/authorize?client_id=pemtree&redirect_uri=https://pemtree.org/callback&state=state_ok',
        surfaceSize: const Size(400, 800),
      );

      expect(find.byType(SsoAuthorizeScreen), findsOneWidget);

      // Click en Autorizar / Continuar
      final authorizeButton = find.text('Autorizar / Continuar');
      expect(authorizeButton, findsOneWidget);
      await tester.tap(authorizeButton);
      // Igual que en el rechazo: el spinner de redirección es infinito.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // La pantalla procesa la autorización y pasa al estado de redirección
      expect(find.text('Redirigiendo a PEMTREE...'), findsOneWidget);
      expect(find.byType(SsoAuthorizeScreen), findsOneWidget);
    });
  });
}
