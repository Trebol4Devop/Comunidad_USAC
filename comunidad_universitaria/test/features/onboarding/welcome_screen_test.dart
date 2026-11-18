import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:comunidad_universitaria/core/config/app_theme.dart';
import 'package:comunidad_universitaria/features/onboarding/screens/welcome_screen.dart';
import '../../helpers/test_setup.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setupTestLifecycle();

  Widget buildTestWelcome({
    VoidCallback? onSignIn,
    VoidCallback? onContinueAsGuest,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: WelcomeScreen(
        onSignIn: onSignIn,
        onContinueAsGuest: onContinueAsGuest,
      ),
    );
  }

  group('WelcomeScreen Widget Tests', () {
    testWidgets('los dos botones disparan sus callbacks correctamente', (
      tester,
    ) async {
      bool signInCalled = false;
      bool guestCalled = false;

      await tester.pumpWidget(
        buildTestWelcome(
          onSignIn: () => signInCalled = true,
          onContinueAsGuest: () => guestCalled = true,
        ),
      );
      await tester.pumpAndSettle();

      // Botón principal: Iniciar sesión
      final signInButton = find.widgetWithText(ElevatedButton, 'Iniciar sesión');
      expect(signInButton, findsOneWidget);
      await tester.tap(signInButton);
      await tester.pumpAndSettle();
      expect(signInCalled, isTrue);

      // Botón secundario: Continuar como anónimo
      final guestButton = find.widgetWithText(
        OutlinedButton,
        'Continuar como anónimo',
      );
      expect(guestButton, findsOneWidget);
      await tester.tap(guestButton);
      await tester.pumpAndSettle();
      expect(guestCalled, isTrue);
    });

    testWidgets('muestra branding, texto de modo anónimo y sin campos de texto ni OTP', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWelcome());
      await tester.pumpAndSettle();

      expect(find.text('Zanate'), findsOneWidget);
      expect(
        find.textContaining(
          'Modo anónimo: podrás explorar el foro y el marketplace, pero necesitas una cuenta para publicar.',
        ),
        findsOneWidget,
      );

      // Sin campos de correo, contraseña ni OTP
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('Contraseña'), findsNothing);
      expect(find.text('OTP'), findsNothing);
      expect(find.text('Código de verificación'), findsNothing);

      // Enlace a normas
      expect(find.text('Normas Comunitarias & Descargo Legal'), findsOneWidget);
    });

    testWidgets(
      'fondo completamente blanco y Trebol4Devop al límite inferior visible en móvil',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.view.resetPadding();
        });

        await tester.pumpWidget(buildTestWelcome());
        await tester.pumpAndSettle();

        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        expect(scaffold.backgroundColor, Colors.white);

        // No debe haber contenedores con el fondo negro anterior
        final blackContainers = tester.widgetList<Container>(
          find.byType(Container),
        ).where((c) {
          final decoration = c.decoration;
          if (decoration is BoxDecoration &&
              decoration.color == const Color(0xFF0B0D10)) {
            return true;
          }
          return c.color == const Color(0xFF0B0D10);
        });
        expect(blackContainers, isEmpty);

        // Trebol4Devop visible y posicionado al límite inferior sobre el SafeArea (844 - 34 = 810)
        final trebolFinder = find.text('Trebol4Devop');
        expect(trebolFinder, findsOneWidget);
        final trebolRect = tester.getRect(trebolFinder);
        expect(trebolRect.bottom, lessThanOrEqualTo(810));
        expect(trebolRect.bottom, greaterThan(770));
      },
    );

    testWidgets('renderiza sin desbordamiento en móvil compacto y escritorio', (
      tester,
    ) async {
      // Móvil compacto (360x640)
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWelcome());
      await tester.pumpAndSettle();
      expect(find.text('Trebol4Devop'), findsOneWidget);
      expect(find.text('Iniciar sesión'), findsOneWidget);

      // Escritorio (1200x800)
      tester.view.physicalSize = const Size(1200, 800);
      await tester.pumpWidget(buildTestWelcome());
      await tester.pumpAndSettle();
      expect(find.text('Trebol4Devop'), findsOneWidget);
      expect(find.text('Ingresa a la comunidad'), findsOneWidget);
    });
  });
}
