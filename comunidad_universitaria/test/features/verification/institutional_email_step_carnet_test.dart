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
  _FakeOcrService(this.results);

  final List<OcrScanResult> results;
  int _calls = 0;

  @override
  bool get isSupported => true;

  @override
  Future<OcrScanResult> scanDocument(String filePath) async {
    final index = _calls < results.length ? _calls : results.length - 1;
    _calls++;
    return results[index];
  }

  @override
  void dispose() {}
}

const _frenteValido =
    'UNIVERSIDAD DE SAN CARLOS DE GUATEMALA\n'
    'FACULTAD DE INGENIERÍA\n'
    'CARRERA DE INGENIERÍA EN CIENCIAS Y SISTEMAS\n'
    'Carné 201901234\n'
    'CUI 1234567890101\n'
    'EN CASO DE EMERGENCIA MARQUE AL 1592\n'
    'DEPARTAMENTO DE REGISTRO Y ESTADÍSTICA';

const _reversoValido =
    'JUAN PÉREZ GÓMEZ\n'
    'USAC TRICENTENARIA\n'
    'ESTUDIANTE UNIVERSITARIO\n'
    'Departamento de Registro y Estadística';

const _frenteResult = OcrScanResult(
  text: _frenteValido,
  qrUrl: '2019012340001',
  isSupported: true,
);

const _reversoResult = OcrScanResult(
  text: _reversoValido,
  qrUrl: 'https://registro.usac.edu.gt/estudiante/201901234',
  isSupported: true,
);

Widget _buildStep({
  required List<OcrScanResult> ocrResults,
  required VoidCallback onSuccess,
}) {
  return MaterialApp(
    home: Scaffold(
      body: InstitutionalEmailStep(
        controller: VerificationController(listenToAuthChanges: false),
        onSelectDocumentPath: () {},
        onSuccess: onSuccess,
        ocrService: _FakeOcrService(ocrResults),
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
    'Frente y reverso coherentes habilitan el correo, y cambiar datos lo invalida',
    (tester) async {
      tester.view.physicalSize = const Size(900, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        _buildStep(
          ocrResults: const [_frenteResult, _reversoResult],
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

      await tester.ensureVisible(
        find.byKey(const Key('carnet_front_camera')),
      );
      await tester.tap(find.byKey(const Key('carnet_front_camera')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('carnet_back_camera')));
      await tester.tap(find.byKey(const Key('carnet_back_camera')));
      await tester.pumpAndSettle();

      expect(find.text('Verificación local aprobada'), findsNWidgets(2));
      expect(tester.widget<ElevatedButton>(googleButton).onPressed, isNotNull);

      // Cambiar el carné invalida ambas caras.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Número de Carné USAC (9 dígitos)'),
        '201999999',
      );
      await tester.pumpAndSettle();

      expect(find.text('Verificación local aprobada'), findsNothing);
      expect(tester.widget<ElevatedButton>(googleButton).onPressed, isNull);
    },
  );

  testWidgets('Un frente con carné distinto bloquea el correo institucional', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      _buildStep(
        ocrResults: const [_frenteResult, _reversoResult],
        onSuccess: () {},
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Número de Carné USAC (9 dígitos)'),
      '201999999',
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('carnet_front_camera')));
    await tester.tap(find.byKey(const Key('carnet_front_camera')));
    await tester.pumpAndSettle();

    expect(find.text('Revisa la foto de tu carné'), findsOneWidget);
    final googleButton = find.widgetWithText(
      ElevatedButton,
      'Continuar con Google Institucional',
    );
    expect(tester.widget<ElevatedButton>(googleButton).onPressed, isNull);
  });
}
