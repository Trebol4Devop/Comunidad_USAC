import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:comunidad_universitaria/features/onboarding/screens/merchant_support_screen.dart';
import 'package:comunidad_universitaria/features/onboarding/screens/no_institutional_email_screen.dart';
import 'package:comunidad_universitaria/features/onboarding/screens/welcome_screen.dart';
import 'package:comunidad_universitaria/features/onboarding/state/session_controller.dart';
import 'package:comunidad_universitaria/features/onboarding/widgets/auth_gate.dart';
import 'package:comunidad_universitaria/features/verification/screens/verification_flow_screen.dart';
import '../../helpers/test_setup.dart';
import 'session_controller_test.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setupTestLifecycle();

  Widget buildGateApp(SessionController controller) {
    return MaterialApp(
      home: AuthGate(
        sessionController: controller,
        child: const Scaffold(
          body: Text('MainAppChild'),
        ),
      ),
    );
  }

  group('AuthGate Widget Tests', () {
    testWidgets('muestra CircularProgressIndicator y no revienta en loading', (tester) async {
      final fakeApi = FakeAuthApi();
      final controller = SessionController(api: fakeApi);
      // controller.phase defaults to SessionPhase.loading
      expect(controller.phase, SessionPhase.loading);

      await tester.pumpWidget(buildGateApp(controller));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('MainAppChild'), findsNothing);
      expect(find.byType(WelcomeScreen), findsNothing);
    });

    testWidgets('muestra WelcomeScreen en unauthenticated', (tester) async {
      final fakeApi = FakeAuthApi();
      final controller = SessionController(api: fakeApi);
      await controller.bootstrap(); // No user, no guest -> unauthenticated

      await tester.pumpWidget(buildGateApp(controller));
      await tester.pumpAndSettle();

      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.text('MainAppChild'), findsNothing);
      expect(find.text('Zanate'), findsOneWidget);
    });

    testWidgets('muestra child en authenticated', (tester) async {
      final fakeApi = FakeAuthApi(
        currentUser: createFakeUser(id: 'user-auth', email: 'test@usac.edu.gt'),
      );
      final controller = SessionController(api: fakeApi);
      await controller.bootstrap();

      await tester.pumpWidget(buildGateApp(controller));
      await tester.pumpAndSettle();

      expect(find.text('MainAppChild'), findsOneWidget);
      expect(find.byType(WelcomeScreen), findsNothing);
    });

    group('Post-login Dispatcher Tests', () {
      testWidgets('Intención student navega a VerificationFlowScreen tab 1 y limpia intención', (tester) async {
        String? currentIntent = 'student';
        bool clearCalled = false;

        final fakeApi = FakeAuthApi(
          currentUser: createFakeUser(id: 'u-student', email: 'test@usac.edu.gt'),
        );
        final controller = SessionController(api: fakeApi);
        await controller.bootstrap();

        await tester.pumpWidget(
          MaterialApp(
            home: AuthGate(
              sessionController: controller,
              getPendingIntent: () async => currentIntent,
              clearPendingIntent: () async {
                clearCalled = true;
                currentIntent = null;
              },
              child: const Scaffold(body: Text('MainAppChild')),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(clearCalled, isTrue);
        expect(find.byType(VerificationFlowScreen), findsOneWidget);
      });

      testWidgets('Intención merchant navega a MerchantSupportScreen y limpia intención', (tester) async {
        String? currentIntent = 'merchant';
        bool clearCalled = false;

        final fakeApi = FakeAuthApi(
          currentUser: createFakeUser(id: 'u-merchant', email: 'merchant@gmail.com'),
        );
        final controller = SessionController(api: fakeApi);
        await controller.bootstrap();

        await tester.pumpWidget(
          MaterialApp(
            home: AuthGate(
              sessionController: controller,
              getPendingIntent: () async => currentIntent,
              clearPendingIntent: () async {
                clearCalled = true;
                currentIntent = null;
              },
              child: const Scaffold(body: Text('MainAppChild')),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(clearCalled, isTrue);
        expect(find.byType(MerchantSupportScreen), findsOneWidget);
      });

      testWidgets('Intención auto con correo institucional no verificado abre verificación automática (tab 0)', (tester) async {
        String? currentIntent = 'auto';
        bool clearCalled = false;

        final fakeApi = FakeAuthApi(
          currentUser: createFakeUser(id: 'u-inst-unverified', email: 'alumno@usac.edu.gt'),
        );
        final controller = SessionController(api: fakeApi);
        await controller.bootstrap();

        await tester.pumpWidget(
          MaterialApp(
            home: AuthGate(
              sessionController: controller,
              getPendingIntent: () async => currentIntent,
              clearPendingIntent: () async {
                clearCalled = true;
                currentIntent = null;
              },
              checkIsVerified: (_) async => false,
              child: const Scaffold(body: Text('MainAppChild')),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(clearCalled, isTrue);
        expect(find.byType(VerificationFlowScreen), findsOneWidget);
      });

      testWidgets('Intención auto con correo personal abre NoInstitutionalEmailScreen', (tester) async {
        String? currentIntent = 'auto';
        bool clearCalled = false;

        final fakeApi = FakeAuthApi(
          currentUser: createFakeUser(id: 'u-personal', email: 'persona@gmail.com'),
        );
        final controller = SessionController(api: fakeApi);
        await controller.bootstrap();

        await tester.pumpWidget(
          MaterialApp(
            home: AuthGate(
              sessionController: controller,
              getPendingIntent: () async => currentIntent,
              clearPendingIntent: () async {
                clearCalled = true;
                currentIntent = null;
              },
              checkIsVerified: (_) async => false,
              child: const Scaffold(body: Text('MainAppChild')),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(clearCalled, isTrue);
        expect(find.byType(NoInstitutionalEmailScreen), findsOneWidget);
      });

      testWidgets('Intención auto con perfil ya verificado no hace nada', (tester) async {
        String? currentIntent = 'auto';
        bool clearCalled = false;

        final fakeApi = FakeAuthApi(
          currentUser: createFakeUser(id: 'u-verified', email: 'verified@usac.edu.gt'),
        );
        final controller = SessionController(api: fakeApi);
        await controller.bootstrap();

        await tester.pumpWidget(
          MaterialApp(
            home: AuthGate(
              sessionController: controller,
              getPendingIntent: () async => currentIntent,
              clearPendingIntent: () async {
                clearCalled = true;
                currentIntent = null;
              },
              checkIsVerified: (_) async => true,
              child: const Scaffold(body: Text('MainAppChild')),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(clearCalled, isTrue);
        expect(find.text('MainAppChild'), findsOneWidget);
        expect(find.byType(VerificationFlowScreen), findsNothing);
        expect(find.byType(NoInstitutionalEmailScreen), findsNothing);
      });

      testWidgets('No dispara el despachador para invitados ni usuarios anónimos', (tester) async {
        String? currentIntent = 'student';
        bool clearCalled = false;

        // Usuario anónimo
        final fakeApi = FakeAuthApi(
          currentUser: createFakeUser(id: 'u-anon', isAnonymous: true),
        );
        final controller = SessionController(api: fakeApi);
        await controller.bootstrap();

        await tester.pumpWidget(
          MaterialApp(
            home: AuthGate(
              sessionController: controller,
              getPendingIntent: () async => currentIntent,
              clearPendingIntent: () async {
                clearCalled = true;
              },
              child: const Scaffold(body: Text('MainAppChild')),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(clearCalled, isFalse);
        expect(find.text('MainAppChild'), findsOneWidget);
        expect(find.byType(VerificationFlowScreen), findsNothing);
      });

      testWidgets('Limpia rutas previas de onboarding al despachar post-login para salir en un solo atrás', (tester) async {
        String? currentIntent = 'student';
        final fakeApi = FakeAuthApi();
        final controller = SessionController(api: fakeApi);
        await controller.bootstrap();

        await tester.pumpWidget(
          MaterialApp(
            home: AuthGate(
              sessionController: controller,
              getPendingIntent: () async => currentIntent,
              clearPendingIntent: () async {
                currentIntent = null;
              },
              child: const Scaffold(body: Text('MainAppChild')),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Simular que el usuario navegó: WelcomeScreen -> Crear cuenta -> No cuentas con correo institucional
        await tester.tap(find.text('Crear cuenta'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('¿No cuentas con correo institucional?'));
        await tester.pumpAndSettle();
        expect(find.byType(NoInstitutionalEmailScreen), findsOneWidget);

        // Simular inicio de sesión con Google completado
        final user = createFakeUser(id: 'u-personal', email: 'persona@gmail.com');
        fakeApi.currentUser = user;
        fakeApi.emitAuthState(AuthState(
          AuthChangeEvent.signedIn,
          Session(
            accessToken: 'token-123',
            tokenType: 'bearer',
            user: user,
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.byType(VerificationFlowScreen), findsOneWidget);
        expect(find.byType(NoInstitutionalEmailScreen), findsNothing);

        // Un solo "regresar" debe llevar directo a MainAppChild
        final nav = tester.state<NavigatorState>(find.byType(Navigator));
        nav.pop();
        await tester.pumpAndSettle();

        expect(find.byType(VerificationFlowScreen), findsNothing);
        expect(find.text('MainAppChild'), findsOneWidget);
      });
    });
  });
}
