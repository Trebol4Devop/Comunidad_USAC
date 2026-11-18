import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:comunidad_universitaria/core/services/local_storage_service.dart';
import 'package:comunidad_universitaria/features/onboarding/screens/merchant_support_screen.dart';
import 'package:comunidad_universitaria/features/onboarding/screens/no_institutional_email_screen.dart';
import 'package:comunidad_universitaria/features/onboarding/state/session_controller.dart';
import 'package:comunidad_universitaria/features/verification/screens/verification_flow_screen.dart';
import 'package:comunidad_universitaria/features/verification/state/verification_controller.dart';
import '../../helpers/test_setup.dart';
import 'session_controller_test.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setupTestLifecycle();

  Widget buildTestScreen({
    required SessionController sessionController,
    VerificationController? verificationController,
    FakeAuthApi? authApi,
  }) {
    return MaterialApp(
      home: SessionScope(
        controller: sessionController,
        child: NoInstitutionalEmailScreen(
          sessionController: sessionController,
          verificationController: verificationController,
          authApi: authApi,
        ),
      ),
    );
  }

  group('NoInstitutionalEmailScreen Tests', () {
    late FakeAuthApi fakeApi;
    late SessionController sessionCtrl;
    late VerificationController verificationCtrl;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      fakeApi = FakeAuthApi();
      sessionCtrl = SessionController(api: fakeApi);
      verificationCtrl = VerificationController(listenToAuthChanges: false);
    });

    testWidgets('Usuario autenticado: la tarjeta de comerciante navega a MerchantSupportScreen', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final user = createFakeUser(id: 'u-auth-1', email: 'personal@gmail.com');
      fakeApi.currentUser = user;
      sessionCtrl.setAuthenticated(user);

      await tester.pumpWidget(
        buildTestScreen(
          sessionController: sessionCtrl,
          verificationController: verificationCtrl,
          authApi: fakeApi,
        ),
      );
      await tester.pumpAndSettle();

      final merchantBtn = find.byKey(const Key('merchant_support_button'));
      expect(merchantBtn, findsOneWidget);

      await tester.ensureVisible(merchantBtn);
      await tester.tap(merchantBtn);
      await tester.pumpAndSettle();

      expect(find.byType(MerchantSupportScreen), findsOneWidget);
    });

    testWidgets('Usuario no autenticado: tarjeta de comerciante persiste intención merchant y lanza Google', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestScreen(
          sessionController: sessionCtrl,
          verificationController: verificationCtrl,
          authApi: fakeApi,
        ),
      );
      await tester.pumpAndSettle();

      final merchantBtn = find.byKey(const Key('merchant_support_button'));
      expect(merchantBtn, findsOneWidget);

      await tester.ensureVisible(merchantBtn);
      await tester.tap(merchantBtn);
      await tester.pump();

      expect(fakeApi.signInWithGoogleCalled, isTrue);
      final savedIntent = await LocalStorageService.getPendingAuthIntent();
      expect(savedIntent, 'merchant');
    });

    testWidgets('Usuario autenticado: tarjeta de estudiante navega a VerificationFlowScreen tab 1', (tester) async {
      final user = createFakeUser(id: 'u-auth-2', email: 'estudiante@gmail.com');
      fakeApi.currentUser = user;
      sessionCtrl.setAuthenticated(user);

      await tester.pumpWidget(
        buildTestScreen(
          sessionController: sessionCtrl,
          verificationController: verificationCtrl,
          authApi: fakeApi,
        ),
      );
      await tester.pumpAndSettle();

      final studentBtn = find.byKey(const Key('student_support_button'));
      expect(studentBtn, findsOneWidget);

      await tester.ensureVisible(studentBtn);
      await tester.tap(studentBtn);
      await tester.pumpAndSettle();

      expect(find.byType(VerificationFlowScreen), findsOneWidget);
    });

    testWidgets(
      'Usuario no autenticado: al regresar de Google sin iniciar sesión libera los botones tras el periodo de gracia',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          buildTestScreen(
            sessionController: sessionCtrl,
            verificationController: verificationCtrl,
            authApi: fakeApi,
          ),
        );
        await tester.pumpAndSettle();

        final merchantBtn = find.byKey(const Key('merchant_support_button'));
        await tester.ensureVisible(merchantBtn);
        await tester.tap(merchantBtn);
        await tester.pump();

        expect(
          find.text(
            'Completa el acceso en Google y regresa a la app para continuar.',
          ),
          findsOneWidget,
        );

        // Simula que el usuario cierra la ventana de Google y regresa a la app
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pump(const Duration(milliseconds: 1600));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Completa el acceso en Google y regresa a la app para continuar.',
          ),
          findsNothing,
        );
        final buttonWidget = tester.widget<ElevatedButton>(merchantBtn);
        expect(buttonWidget.onPressed, isNotNull);
        expect(await LocalStorageService.getPendingAuthIntent(), isNull);
      },
    );
  });
}
