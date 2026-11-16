import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:comunidad_universitaria/features/onboarding/screens/merchant_verification_screen.dart';
import 'package:comunidad_universitaria/features/onboarding/state/session_controller.dart';
import 'package:comunidad_universitaria/features/verification/models/merchant_verification_result.dart';
import 'package:comunidad_universitaria/features/verification/services/merchant_verification_service.dart';
import 'package:comunidad_universitaria/features/verification/state/verification_controller.dart';
import '../../helpers/test_setup.dart';
import 'session_controller_test.dart';

class FakeMerchantVerificationService extends MerchantVerificationService {
  MerchantVerificationResult resultToReturn;
  bool submitCalled = false;
  String? lastBusinessName;
  String? lastDpiNumber;

  FakeMerchantVerificationService({
    this.resultToReturn =
        const MerchantVerificationResult.manualReview(requestId: 'req-fake-1'),
  });

  @override
  Future<MerchantVerificationResult> submitMerchantVerification({
    required Uint8List dpiFront,
    required Uint8List dpiBack,
    required Uint8List establishment,
    required String businessName,
    required String dpiNumber,
    String? establishmentNote,
  }) async {
    submitCalled = true;
    lastBusinessName = businessName;
    lastDpiNumber = dpiNumber;
    return resultToReturn;
  }
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setupTestLifecycle();

  Widget buildTestScreen({
    required SessionController sessionController,
    required VerificationController verificationController,
    required FakeMerchantVerificationService fakeService,
    Future<XFile?> Function(ImageSource source)? imagePickerFn,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => Navigator.of(ctx).push(
              MaterialPageRoute(
                builder: (_) => SessionScope(
                  controller: sessionController,
                  child: MerchantVerificationScreen(
                    sessionController: sessionController,
                    verificationController: verificationController,
                    service: fakeService,
                    imagePickerFn: imagePickerFn,
                  ),
                ),
              ),
            ),
            child: const Text('Abrir Pantalla'),
          ),
        ),
      ),
    );
  }

  group('MerchantVerificationScreen Widget Tests', () {
    late FakeAuthApi fakeApi;
    late SessionController sessionCtrl;
    late VerificationController verificationCtrl;
    late FakeMerchantVerificationService fakeService;

    setUp(() {
      fakeApi = FakeAuthApi(
        currentUser: createFakeUser(id: 'user-merchant-1', email: 'merchant@gmail.com'),
      );
      sessionCtrl = SessionController(api: fakeApi);
      sessionCtrl.setAuthenticated(fakeApi.currentUser!);

      verificationCtrl = VerificationController(listenToAuthChanges: false);
      fakeService = FakeMerchantVerificationService();
    });

    testWidgets('Muestra CTA de inicio de sesión si la sesión es de invitado o anónima', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final guestApi = FakeAuthApi();
      final guestSessionCtrl = SessionController(api: guestApi);
      await guestSessionCtrl.continueAsGuest();

      await tester.pumpWidget(
        buildTestScreen(
          sessionController: guestSessionCtrl,
          verificationController: verificationCtrl,
          fakeService: fakeService,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Abrir Pantalla'));
      await tester.pumpAndSettle();

      expect(find.text('Sesión requerida para verificación'), findsOneWidget);
      expect(find.text('Iniciar sesión con Google'), findsOneWidget);
      expect(find.text('Enviar Solicitud de Comerciante'), findsNothing);
    });

    testWidgets('Renderiza los 3 selectores de fotos y el aviso de privacidad', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestScreen(
          sessionController: sessionCtrl,
          verificationController: verificationCtrl,
          fakeService: fakeService,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Abrir Pantalla'));
      await tester.pumpAndSettle();

      // Campos de formulario
      expect(find.text('Nombre del negocio *'), findsOneWidget);
      expect(find.text('Número de DPI (13 dígitos) *'), findsOneWidget);
      expect(find.text('Nota de ubicación en el campus (opcional)'), findsOneWidget);

      // 3 selectores de fotografías obligatorias
      expect(find.text('1. DPI — Frente'), findsOneWidget);
      expect(find.text('2. DPI — Reverso'), findsOneWidget);
      expect(find.text('3. Establecimiento en el campus'), findsOneWidget);

      // Aviso de privacidad normativo
      expect(
        find.text(
          'Tus documentos se guardan de forma privada y se eliminan después de la revisión.',
        ),
        findsOneWidget,
      );

      // Botón de enviar está presente
      expect(find.text('Enviar Solicitud de Comerciante'), findsOneWidget);
    });

    testWidgets('El botón de enviar está deshabilitado sin las 3 fotos', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestScreen(
          sessionController: sessionCtrl,
          verificationController: verificationCtrl,
          fakeService: fakeService,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Abrir Pantalla'));
      await tester.pumpAndSettle();

      final submitBtnFinder = find.widgetWithText(
        ElevatedButton,
        'Enviar Solicitud de Comerciante',
      );
      expect(submitBtnFinder, findsOneWidget);

      final ElevatedButton btn = tester.widget(submitBtnFinder);
      expect(btn.onPressed, isNull); // Deshabilitado
    });

    testWidgets('Validaciones de errores en nombre de negocio y DPI', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      int pickerCallCount = 0;
      Future<XFile?> fakePicker(ImageSource source) async {
        pickerCallCount++;
        return XFile.fromData(
          Uint8List.fromList([1, 2, 3]),
          name: 'doc_$pickerCallCount.jpg',
        );
      }

      await tester.pumpWidget(
        buildTestScreen(
          sessionController: sessionCtrl,
          verificationController: verificationCtrl,
          fakeService: fakeService,
          imagePickerFn: fakePicker,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Abrir Pantalla'));
      await tester.pumpAndSettle();

      // Seleccionar las 3 fotos para habilitar el botón
      for (int i = 0; i < 3; i++) {
        final btnFinder = find.widgetWithText(OutlinedButton, 'Cámara').first;
        await tester.tap(btnFinder);
        await tester.pumpAndSettle();
      }

      // Ahora el botón debe estar habilitado
      final submitBtnFinder = find.widgetWithText(ElevatedButton, 'Enviar Solicitud de Comerciante');
      final submitBtn = tester.widget<ElevatedButton>(submitBtnFinder);
      expect(submitBtn.onPressed, isNotNull);

      // Intentar enviar sin llenar campos
      await tester.tap(submitBtnFinder);
      await tester.pumpAndSettle();

      expect(find.text('Ingresa el nombre del negocio.'), findsOneWidget);
      expect(find.text('Ingresa tu número de DPI.'), findsOneWidget);

      // Ingresar nombre inválido (< 2 chars) y DPI inválido (no 13 dígitos)
      await tester.enterText(find.byType(TextFormField).at(0), 'A');
      await tester.enterText(find.byType(TextFormField).at(1), '12345');
      await tester.tap(submitBtnFinder);
      await tester.pumpAndSettle();

      expect(
        find.text('El nombre del negocio debe tener entre 2 y 80 caracteres.'),
        findsOneWidget,
      );
      expect(
        find.text('El DPI debe tener 13 dígitos y un código departamental válido (01-22).'),
        findsOneWidget,
      );
    });

    testWidgets('Error 409 muestra el mensaje genérico normativo', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      fakeService.resultToReturn = const MerchantVerificationResult.error(
        code: 'credential_unavailable',
        message: 'No pudimos registrar este DPI. Si crees que es un error, contacta soporte.',
      );

      int pickerCallCount = 0;
      Future<XFile?> fakePicker(ImageSource source) async {
        pickerCallCount++;
        return XFile.fromData(
          Uint8List.fromList([1, 2, 3]),
          name: 'doc_$pickerCallCount.jpg',
        );
      }

      await tester.pumpWidget(
        buildTestScreen(
          sessionController: sessionCtrl,
          verificationController: verificationCtrl,
          fakeService: fakeService,
          imagePickerFn: fakePicker,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Abrir Pantalla'));
      await tester.pumpAndSettle();

      // Adjuntar las 3 fotos
      for (int i = 0; i < 3; i++) {
        final btnFinder = find.widgetWithText(OutlinedButton, 'Cámara').first;
        await tester.tap(btnFinder);
        await tester.pumpAndSettle();
      }

      // Llenar campos válidos (DPI con departamento 01 a 22, ej. 2501123450101)
      await tester.enterText(find.byType(TextFormField).at(0), 'Comedor El Ingeniero');
      await tester.enterText(find.byType(TextFormField).at(1), '2501123450101');
      await tester.pumpAndSettle();

      // Enviar
      final submitBtnFinder = find.widgetWithText(ElevatedButton, 'Enviar Solicitud de Comerciante');
      await tester.tap(submitBtnFinder);
      await tester.pumpAndSettle();

      expect(fakeService.submitCalled, isTrue);
      expect(
        find.text('No pudimos registrar este DPI. Si crees que es un error, contacta soporte.'),
        findsOneWidget,
      );
    });

    testWidgets('Envío exitoso actualiza el controller a pending y regresa', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      fakeService.resultToReturn = const MerchantVerificationResult.manualReview(
        requestId: 'req-success-123',
      );

      int pickerCallCount = 0;
      Future<XFile?> fakePicker(ImageSource source) async {
        pickerCallCount++;
        return XFile.fromData(
          Uint8List.fromList([1, 2, 3]),
          name: 'doc_$pickerCallCount.jpg',
        );
      }

      await tester.pumpWidget(
        buildTestScreen(
          sessionController: sessionCtrl,
          verificationController: verificationCtrl,
          fakeService: fakeService,
          imagePickerFn: fakePicker,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Abrir Pantalla'));
      await tester.pumpAndSettle();

      // Adjuntar fotos
      for (int i = 0; i < 3; i++) {
        final btnFinder = find.widgetWithText(OutlinedButton, 'Cámara').first;
        await tester.tap(btnFinder);
        await tester.pumpAndSettle();
      }

      // Llenar datos válidos
      await tester.enterText(find.byType(TextFormField).at(0), 'Librería Universitaria');
      await tester.enterText(find.byType(TextFormField).at(1), '2501123450101');
      await tester.enterText(find.byType(TextFormField).at(2), 'Edificio T-1');
      await tester.pumpAndSettle();

      expect(verificationCtrl.isMerchantPending, isFalse);

      final submitBtnFinder = find.widgetWithText(ElevatedButton, 'Enviar Solicitud de Comerciante');
      await tester.tap(submitBtnFinder);
      await tester.pumpAndSettle();

      expect(fakeService.submitCalled, isTrue);
      expect(verificationCtrl.isMerchantPending, isTrue);
      expect(
        find.text('Solicitud de comerciante enviada. Tu cuenta entrará en revisión manual.'),
        findsOneWidget,
      );
    });
  });
}
