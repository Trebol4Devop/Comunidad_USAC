import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:comunidad_universitaria/core/config/app_theme.dart';
import 'package:comunidad_universitaria/features/onboarding/screens/auth_gateway_screen.dart';
import 'package:comunidad_universitaria/features/onboarding/screens/no_institutional_email_screen.dart';
import 'package:comunidad_universitaria/features/onboarding/state/session_controller.dart';
import 'package:comunidad_universitaria/features/verification/screens/verification_flow_screen.dart';
import 'package:comunidad_universitaria/features/verification/state/verification_controller.dart';
import '../../helpers/test_setup.dart';
import 'session_controller_test.dart';

class FakeVerificationController extends VerificationController {
  bool _mockIsUnverified = true;
  bool _mockIsVerified = false;

  void setMockStatus({required bool isUnverified, required bool isVerified}) {
    _mockIsUnverified = isUnverified;
    _mockIsVerified = isVerified;
  }

  @override
  bool get isUnverified => _mockIsUnverified;

  @override
  bool get isVerified => _mockIsVerified;
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setupTestLifecycle();

  Widget buildTestGateway({
    required FakeAuthApi authApi,
    VerificationController? verificationController,
    SessionController? sessionController,
    bool isModal = false,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: AuthGatewayScreen(
        authApi: authApi,
        verificationController: verificationController,
        sessionController: sessionController,
        isModal: isModal,
      ),
    );
  }

  group('AuthGatewayScreen Unit & Decision Function Tests', () {
    test('determinePostLoginDestination: correo institucional y no verificado enruta a Camino A', () {
      final dest1 = AuthGatewayScreen.determinePostLoginDestination(
        email: 'estudiante@usac.edu.gt',
        isUnverified: true,
      );
      expect(dest1, AuthPostLoginDestination.caminoA);

      final dest2 = AuthGatewayScreen.determinePostLoginDestination(
        email: 'alumno@ingenieria.usac.edu.gt',
        isUnverified: true,
      );
      expect(dest2, AuthPostLoginDestination.caminoA);

      final dest3 = AuthGatewayScreen.determinePostLoginDestination(
        email: 'medicina@medicina.usac.edu.gt',
        isUnverified: true,
      );
      expect(dest3, AuthPostLoginDestination.caminoA);
    });

    test('determinePostLoginDestination: correo institucional ya verificado devuelve alreadyVerified', () {
      final dest = AuthGatewayScreen.determinePostLoginDestination(
        email: 'estudiante@usac.edu.gt',
        isUnverified: false,
      );
      expect(dest, AuthPostLoginDestination.alreadyVerified);
    });

    test('determinePostLoginDestination: correo personal siempre enruta a noInstitutional', () {
      final dest1 = AuthGatewayScreen.determinePostLoginDestination(
        email: 'usuario@gmail.com',
        isUnverified: true,
      );
      expect(dest1, AuthPostLoginDestination.noInstitutional);

      final dest2 = AuthGatewayScreen.determinePostLoginDestination(
        email: 'comerciante@yahoo.com',
        isUnverified: false,
      );
      expect(dest2, AuthPostLoginDestination.noInstitutional);

      final dest3 = AuthGatewayScreen.determinePostLoginDestination(
        email: null,
        isUnverified: true,
      );
      expect(dest3, AuthPostLoginDestination.noInstitutional);
    });
  });

  group('AuthGatewayScreen Widget Tests', () {
    late FakeAuthApi fakeApi;

    setUp(() {
      fakeApi = FakeAuthApi();
    });

    tearDown(() {
      fakeApi.dispose();
    });

    testWidgets('botón de Google llama a la API e informa espera de redirect', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestGateway(authApi: fakeApi));
      await tester.pumpAndSettle();

      final googleButton = find.widgetWithText(
        OutlinedButton,
        'Continuar con Google',
      );
      expect(googleButton, findsOneWidget);

      await tester.tap(googleButton);
      await tester.pump();

      expect(fakeApi.signInWithGoogleCalled, isTrue);
      expect(
        find.text('Completa el acceso en Google y regresa a la app'),
        findsOneWidget,
      );
    });

    testWidgets('enlace "¿No cuentas con correo institucional?" abre pantalla con dos tarjetas', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestGateway(authApi: fakeApi));
      await tester.pumpAndSettle();

      final link = find.text('¿No cuentas con correo institucional?');
      expect(link, findsOneWidget);

      await tester.tap(link);
      await tester.pumpAndSettle();

      // Navegó a NoInstitutionalEmailScreen
      expect(find.byType(NoInstitutionalEmailScreen), findsOneWidget);

      // Tarjeta Estudiante
      expect(find.text('Estudiante USAC'), findsOneWidget);
      expect(
        find.text('Tengo constancia de inscripción o carné físico'),
        findsOneWidget,
      );

      // Tarjeta Comerciante
      expect(find.text('Comerciante del Campus'), findsOneWidget);
      expect(
        find.text('Tengo un negocio dentro del campus (DPI + local)'),
        findsOneWidget,
      );
    });

    testWidgets('muestra mensaje de error y botón de reintento si Google falla', (
      tester,
    ) async {
      fakeApi.signInWithGoogleResult = false;

      await tester.pumpWidget(buildTestGateway(authApi: fakeApi));
      await tester.pumpAndSettle();

      final googleButton = find.widgetWithText(
        OutlinedButton,
        'Continuar con Google',
      );
      await tester.tap(googleButton);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(
        find.text('No se pudo iniciar sesión con Google. Inténtalo de nuevo.'),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsOneWidget);

      // Reintentar cuando se soluciona
      fakeApi.signInWithGoogleResult = true;
      await tester.tap(find.text('Reintentar'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(
        find.text('Completa el acceso en Google y regresa a la app'),
        findsOneWidget,
      );
    });

    testWidgets('al completar sesión con correo institucional no verificado abre Camino A (tab 0)', (
      tester,
    ) async {
      final fakeVerificationCtrl = FakeVerificationController();
      fakeVerificationCtrl.setMockStatus(isUnverified: true, isVerified: false);

      await tester.pumpWidget(buildTestGateway(
        authApi: fakeApi,
        verificationController: fakeVerificationCtrl,
      ));
      await tester.pumpAndSettle();

      // Simular click en Google
      await tester.tap(find.widgetWithText(OutlinedButton, 'Continuar con Google'));
      await tester.pump();

      // Emitir sesión autenticada institucional
      final instUser = createFakeUser(
        id: 'user-inst-1',
        email: 'estudiante@usac.edu.gt',
      );
      fakeApi.emitAuthState(AuthState(
        AuthChangeEvent.signedIn,
        Session(
          accessToken: 'token-abc',
          tokenType: 'bearer',
          user: instUser,
        ),
      ));

      await tester.pumpAndSettle();

      // Se abrió VerificationFlowScreen en Camino A
      expect(find.byType(VerificationFlowScreen), findsOneWidget);
      expect(find.text('Camino A: Correo'), findsOneWidget);
    });
  });
}
