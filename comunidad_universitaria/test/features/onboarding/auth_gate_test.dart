import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:comunidad_universitaria/features/onboarding/screens/welcome_screen.dart';
import 'package:comunidad_universitaria/features/onboarding/state/session_controller.dart';
import 'package:comunidad_universitaria/features/onboarding/widgets/auth_gate.dart';
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
      expect(find.text('Comunidad USAC'), findsOneWidget);
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

    testWidgets('muestra child en guest', (tester) async {
      final fakeApi = FakeAuthApi();
      final controller = SessionController(api: fakeApi);
      await controller.bootstrap();
      await controller.continueAsGuest();

      await tester.pumpWidget(buildGateApp(controller));
      await tester.pumpAndSettle();

      expect(find.text('MainAppChild'), findsOneWidget);
      expect(find.byType(WelcomeScreen), findsNothing);
    });
  });
}
