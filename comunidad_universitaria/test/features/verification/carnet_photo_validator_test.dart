import 'package:flutter_test/flutter_test.dart';
import 'package:comunidad_universitaria/features/verification/utils/carnet_photo_validator.dart';

void main() {
  group('CarnetPhotoValidator.normalize', () {
    test('quita tildes, pasa a mayúsculas y colapsa espacios', () {
      expect(
        CarnetPhotoValidator.normalize('  Facultad de Ingeniería   en Ciencias '),
        'FACULTAD DE INGENIERIA EN CIENCIAS',
      );
    });

    test('mantiene números y dominios', () {
      expect(
        CarnetPhotoValidator.normalize('201901234 https://registro.usac.edu.gt/x'),
        '201901234 HTTPS://REGISTRO.USAC.EDU.GT/X',
      );
    });
  });

  group('CarnetPhotoValidator.isValidUsacQr', () {
    test('acepta usac.edu.gt y subdominios', () {
      expect(CarnetPhotoValidator.isValidUsacQr('https://usac.edu.gt/x'), isTrue);
      expect(
        CarnetPhotoValidator.isValidUsacQr('https://registro.usac.edu.gt/x'),
        isTrue,
      );
    });

    test('rechaza hosts ajenos y esquemas inválidos', () {
      expect(CarnetPhotoValidator.isValidUsacQr('https://evil.com'), isFalse);
      expect(
        CarnetPhotoValidator.isValidUsacQr('https://usac.edu.gt.evil.com'),
        isFalse,
      );
      expect(CarnetPhotoValidator.isValidUsacQr('ftp://usac.edu.gt'), isFalse);
    });
  });

  group('CarnetPhotoValidator.validate', () {
    const textoValido =
        'UNIVERSIDAD DE SAN CARLOS DE GUATEMALA\n'
        'FACULTAD DE INGENIERÍA\n'
        'CARRERA DE INGENIERÍA EN CIENCIAS Y SISTEMAS\n'
        'Carné 201901234\n'
        'CUI 1234567890101\n'
        'DEPARTAMENTO DE REGISTRO Y ESTADÍSTICA';

    test('aprueba un carné coherente con carné, facultad y carrera', () {
      final result = CarnetPhotoValidator.validate(
        ocrText: textoValido,
        carne: '201901234',
        facultadNombre: 'Facultad de Ingeniería',
        carreraNombre: 'Ingeniería en Ciencias y Sistemas',
        qrUrl: 'https://registro.usac.edu.gt/verificar/201901234',
      );

      expect(result.passed, isTrue);
      expect(result.items.any((i) => i.isError), isFalse);
      expect(
        result.items.where((i) => i.level == CarnetCheckLevel.ok).length,
        greaterThanOrEqualTo(4),
      );
    });

    test('falla si el carné escrito no aparece en la foto', () {
      final result = CarnetPhotoValidator.validate(
        ocrText: textoValido,
        carne: '201999999',
        facultadNombre: 'Facultad de Ingeniería',
      );

      expect(result.passed, isFalse);
      expect(
        result.items.any(
          (i) => i.label == 'Número de carné' && i.isError,
        ),
        isTrue,
      );
    });

    test('falla si no se detecta la institución', () {
      final result = CarnetPhotoValidator.validate(
        ocrText: 'FACULTAD DE INGENIERIA\nCARRERA DE SISTEMAS\n201901234',
        carne: '201901234',
      );

      expect(result.passed, isFalse);
      expect(
        result.items.any(
          (i) => i.label == 'Institución USAC' && i.isError,
        ),
        isTrue,
      );
    });

    test('falla si el QR apunta a un dominio ajeno', () {
      final result = CarnetPhotoValidator.validate(
        ocrText: textoValido,
        carne: '201901234',
        qrUrl: 'https://evil.com/phishing',
      );

      expect(result.passed, isFalse);
      expect(
        result.items.any((i) => i.label == 'Código QR' && i.isError),
        isTrue,
      );
    });

    test('acepta un código de barras que no es URL', () {
      final result = CarnetPhotoValidator.validate(
        ocrText: textoValido,
        carne: '201901234',
        qrUrl: '2019012340001',
      );

      expect(result.passed, isTrue);
      expect(
        result.items.any((i) => i.label == 'Código de barras'),
        isTrue,
      );
    });

    test('una carrera no confirmada es advertencia, no bloqueo', () {
      final result = CarnetPhotoValidator.validate(
        ocrText: textoValido,
        carne: '201901234',
        facultadNombre: 'Facultad de Ingeniería',
        carreraNombre: 'Medicina',
      );

      expect(result.passed, isTrue);
      expect(
        result.items.any(
          (i) => i.label == 'Carrera' && i.isWarning,
        ),
        isTrue,
      );
    });

    test('falla si el texto es demasiado corto', () {
      final result = CarnetPhotoValidator.validate(
        ocrText: '201901234',
        carne: '201901234',
      );

      expect(result.passed, isFalse);
      expect(
        result.items.any(
          (i) => i.label == 'Lectura del carné' && i.isError,
        ),
        isTrue,
      );
    });

    test('valida el CUI si se proporciona', () {
      final ok = CarnetPhotoValidator.validate(
        ocrText: textoValido,
        carne: '201901234',
        cui: '1234567890101',
      );
      expect(ok.passed, isTrue);

      final bad = CarnetPhotoValidator.validate(
        ocrText: textoValido,
        carne: '201901234',
        cui: '9999999990101',
      );
      expect(bad.passed, isFalse);
      expect(bad.items.any((i) => i.label == 'CUI' && i.isError), isTrue);
    });
  });
}
