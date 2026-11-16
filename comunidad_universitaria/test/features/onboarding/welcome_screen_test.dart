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

    testWidgets('muestra branding, texto de modo lectura y sin campos de texto ni OTP', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWelcome());
      await tester.pumpAndSettle();

      expect(find.text('Comunidad USAC'), findsOneWidget);
      expect(
        find.textContaining(
          'Modo lectura: podrás explorar el foro y el marketplace, pero necesitas una cuenta para publicar.',
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
  });
}
