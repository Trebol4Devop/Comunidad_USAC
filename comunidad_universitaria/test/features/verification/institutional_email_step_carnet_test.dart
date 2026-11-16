import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:comunidad_universitaria/features/verification/screens/institutional_email_step.dart';
import 'package:comunidad_universitaria/features/verification/services/ocr_service.dart';
import 'package:comunidad_universitaria/features/verification/state/verification_controller.dart';

import '../../helpers/test_setup.dart';

final _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+ip1sAAAAASUVORK5CYII=',
);

class _FakeOcrService implements OcrService {
  _FakeOcrService(this.result);

  final OcrScanResult result;

  @override
  bool get isSupported => true;

  @override
  Future<OcrScanResult> scanDocument(String filePath) async => result;

  @override
  void dispose() {}
}

const _textoValido =
    'UNIVERSIDAD DE SAN CARLOS DE GUATEMALA\n'
    'FACULTAD DE INGENIERÍA\n'
    'CARRERA DE INGENIERÍA EN CIENCIAS Y SISTEMAS\n'
    'Carné 201901234\n'
    'DEPARTAMENTO DE REGISTRO Y ESTADÍSTICA';

Widget _buildStep({
  required OcrScanResult ocrResult,
  required VoidCallback onSuccess,
}) {
  return MaterialApp(
    home: Scaffold(
      body: InstitutionalEmailStep(
        controller: VerificationController(listenToAuthChanges: false),
        onSelectDocumentPath: () {},
        onSuccess: onSuccess,
        ocrService: _FakeOcrService(ocrResult),
        imagePickerFn: (_) async => XFile.fromData(
          _pngBytes,
          name: 'carne.png',
          mimeType: 'image/png',
        ),
      ),
    ),
  );
}

void main() {
  setupTestLifecycle();

  testWidgets(
    'La foto coherente habilita el correo institucional y el cambio de carné lo invalida',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        _buildStep(
          ocrResult: const OcrScanResult(
            text: _textoValido,
            qrUrl: 'https://registro.usac.edu.gt/verificar/201901234',
            isSupported: true,
          ),
          onSuccess: () {},
        ),
      );
      await tester.pumpAndSettle();

      final googleButton = find.widgetWithText(
        ElevatedButton,
        'Continuar con Google Institucional',
      );
      expect(tester.widget<ElevatedButton>(googleButton).onPressed, isNull);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Número de Carné USAC (9 dígitos)'),
        '201901234',
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Tomar foto'));
      await tester.tap(find.text('Tomar foto'));
      await tester.pumpAndSettle();

      expect(find.text('Verificación local aprobada'), findsOneWidget);
      expect(tester.widget<ElevatedButton>(googleButton).onPressed, isNotNull);

      // Cambiar el carné invalida la foto: debe volver a verificarse.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Número de Carné USAC (9 dígitos)'),
        '201999999',
      );
      await tester.pumpAndSettle();

      expect(find.text('Verificación local aprobada'), findsNothing);
      expect(tester.widget<ElevatedButton>(googleButton).onPressed, isNull);
    },
  );

  testWidgets('Un carné que no coincide bloquea el correo institucional', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      _buildStep(
        ocrResult: const OcrScanResult(
          text: _textoValido,
          isSupported: true,
        ),
        onSuccess: () {},
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Número de Carné USAC (9 dígitos)'),
      '201999999',
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Tomar foto'));
    await tester.tap(find.text('Tomar foto'));
    await tester.pumpAndSettle();

    expect(find.text('Revisa la foto de tu carné'), findsOneWidget);
    final googleButton = find.widgetWithText(
      ElevatedButton,
      'Continuar con Google Institucional',
    );
    expect(tester.widget<ElevatedButton>(googleButton).onPressed, isNull);
  });
}
