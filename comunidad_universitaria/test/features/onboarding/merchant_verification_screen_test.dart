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
  String? lastContactPhone;

  FakeMerchantVerificationService({
    this.resultToReturn =
        const MerchantVerificationResult.manualReview(requestId: 'req-fake-1'),
  });

  @override
  Future<MerchantVerificationResult> submitMerchantVerification({
    required Uint8List establishmentPhoto,
    required String businessName,
    required String contactPhone,
    String? establishmentNote,
  }) async {
    submitCalled = true;
    lastBusinessName = businessName;
    lastContactPhone = contactPhone;
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

  group('MerchantVerificationScreen Widget Tests (Zero-PII)', () {
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

    testWidgets('Renderiza el selector de foto de establecimiento y aviso de privacidad', (tester) async {
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
      expect(find.text('Teléfono comercial / WhatsApp *'), findsOneWidget);
      expect(find.text('Nota de ubicación en el campus (opcional)'), findsOneWidget);

      // No debe existir selector ni campo de DPI
      expect(find.textContaining('DPI'), findsNothing);

      // Selector de fotografía del puesto/local
      expect(find.text('Fotografía del puesto o local *'), findsOneWidget);

      // Aviso de privacidad Zero-PII
      expect(
        find.text(
          'Tus datos se guardan de forma privada y la fotografía se elimina después de la revisión.',
        ),
        findsOneWidget,
      );

      // Botón de enviar está presente
      expect(find.text('Enviar Solicitud de Comerciante'), findsOneWidget);
    });

    testWidgets('El botón de enviar está deshabilitado sin la foto del establecimiento', (tester) async {
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

    testWidgets('Validaciones de errores en nombre de negocio y teléfono', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Future<XFile?> fakePicker(ImageSource source) async {
        return XFile.fromData(
          Uint8List.fromList([1, 2, 3]),
          name: 'local.jpg',
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

      // Seleccionar la foto para habilitar el botón
      final btnFinder = find.widgetWithText(OutlinedButton, 'Cámara').first;
      await tester.tap(btnFinder);
      await tester.pumpAndSettle();

      // Ahora el botón debe estar habilitado
      final submitBtnFinder = find.widgetWithText(ElevatedButton, 'Enviar Solicitud de Comerciante');
      final submitBtn = tester.widget<ElevatedButton>(submitBtnFinder);
      expect(submitBtn.onPressed, isNotNull);

      // Intentar enviar sin llenar campos
      await tester.tap(submitBtnFinder);
      await tester.pumpAndSettle();

      expect(find.text('Ingresa el nombre del negocio.'), findsOneWidget);
      expect(find.text('Ingresa tu teléfono comercial.'), findsOneWidget);

      // Ingresar nombre inválido (< 2 chars) y teléfono inválido (no 8 dígitos)
      await tester.enterText(find.byType(TextFormField).at(0), 'A');
      await tester.enterText(find.byType(TextFormField).at(1), '12345');
      await tester.tap(submitBtnFinder);
      await tester.pumpAndSettle();

      expect(
        find.text('El nombre del negocio debe tener entre 2 y 80 caracteres.'),
        findsOneWidget,
      );
      expect(
        find.text('El teléfono debe tener 8 dígitos (Guatemala).'),
        findsOneWidget,
      );
    });

    testWidgets('Error 409 muestra el mensaje genérico normativo de teléfono', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      fakeService.resultToReturn = const MerchantVerificationResult.error(
        code: 'credential_unavailable',
        message: 'No pudimos registrar este teléfono de contacto. Si crees que es un error, contacta soporte.',
      );

      Future<XFile?> fakePicker(ImageSource source) async {
        return XFile.fromData(
          Uint8List.fromList([1, 2, 3]),
          name: 'local.jpg',
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

      // Adjuntar foto
      final btnFinder = find.widgetWithText(OutlinedButton, 'Cámara').first;
      await tester.tap(btnFinder);
      await tester.pumpAndSettle();

      // Llenar campos válidos (acepta +502 y espacios)
      await tester.enterText(find.byType(TextFormField).at(0), 'Comedor El Ingeniero');
      await tester.enterText(find.byType(TextFormField).at(1), '+502 2345 6789');
      await tester.pumpAndSettle();

      // Enviar
      final submitBtnFinder = find.widgetWithText(ElevatedButton, 'Enviar Solicitud de Comerciante');
      await tester.tap(submitBtnFinder);
      await tester.pumpAndSettle();

      expect(fakeService.submitCalled, isTrue);
      expect(fakeService.lastContactPhone, '23456789'); // Normalizado a 8 dígitos
      expect(
        find.text('No pudimos registrar este teléfono de contacto. Si crees que es un error, contacta soporte.'),
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

      Future<XFile?> fakePicker(ImageSource source) async {
        return XFile.fromData(
          Uint8List.fromList([1, 2, 3]),
          name: 'local.jpg',
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

      // Adjuntar foto
      final btnFinder = find.widgetWithText(OutlinedButton, 'Cámara').first;
      await tester.tap(btnFinder);
      await tester.pumpAndSettle();

      // Llenar datos válidos
      await tester.enterText(find.byType(TextFormField).at(0), 'Librería Universitaria');
      await tester.enterText(find.byType(TextFormField).at(1), '23456789');
      await tester.enterText(find.byType(TextFormField).at(2), 'Edificio T-1');
      await tester.pumpAndSettle();

      expect(verificationCtrl.isMerchantPending, isFalse);

      final submitBtnFinder = find.widgetWithText(ElevatedButton, 'Enviar Solicitud de Comerciante');
      await tester.tap(submitBtnFinder);
      await tester.pumpAndSettle();

      expect(fakeService.submitCalled, isTrue);
      expect(fakeService.lastContactPhone, '23456789');
      expect(verificationCtrl.isMerchantPending, isTrue);
      expect(
        find.text('Solicitud de comerciante enviada. Tu cuenta entrará en revisión manual.'),
        findsOneWidget,
      );
    });
  });
}
