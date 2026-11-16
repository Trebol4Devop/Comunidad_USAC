import 'package:flutter_test/flutter_test.dart';
import 'package:comunidad_universitaria/features/verification/utils/verification_validators.dart';

void main() {
  group('VerificationValidators Tests', () {
    final currentYear = DateTime.now().year;

    group('Validación de Carné USAC', () {
      test('Carné válido con año dentro de rango (1980 - año actual) y 9 dígitos', () {
        expect(VerificationValidators.isValidCarne('201901234'), isTrue);
        expect(VerificationValidators.isValidCarne('198012345'), isTrue);
        expect(VerificationValidators.isValidCarne('${currentYear}12345'), isTrue);
        expect(VerificationValidators.isValidCarne('202399999'), isTrue);
      });

      test('Carné inválido por año anterior a 1980', () {
        expect(VerificationValidators.isValidCarne('197912345'), isFalse);
        expect(VerificationValidators.isValidCarne('195012345'), isFalse);
      });

      test('Carné inválido por año futuro posterior al actual', () {
        final futureYear = currentYear + 1;
        expect(VerificationValidators.isValidCarne('${futureYear}12345'), isFalse);
        expect(VerificationValidators.isValidCarne('209912345'), isFalse);
      });

      test('Carné inválido por longitud incorrecta o caracteres alfabéticos', () {
        expect(VerificationValidators.isValidCarne('20191234'), isFalse); // 8 dígitos
        expect(VerificationValidators.isValidCarne('2019123456'), isFalse); // 10 dígitos
        expect(VerificationValidators.isValidCarne('2019ABCD5'), isFalse);
        expect(VerificationValidators.isValidCarne(''), isFalse);
        expect(VerificationValidators.isValidCarne(null), isFalse);
      });

      test('validateCarne validador de formulario para UI', () {
        expect(VerificationValidators.validateCarne(''), isNotNull);
        expect(VerificationValidators.validateCarne('123'), isNotNull);
        expect(VerificationValidators.validateCarne('197012345'), isNotNull);
        expect(VerificationValidators.validateCarne('202012345'), isNull);
      });
    });

    group('Validación de CUI (DPI de Guatemala)', () {
      test('CUI válido con 13 dígitos y código de departamento entre 01 y 22', () {
        expect(VerificationValidators.isValidCui('2501123450101'), isTrue); // Depto 01 Guatemala
        expect(VerificationValidators.isValidCui('1234567892201'), isTrue); // Depto 22 Jutiapa
        expect(VerificationValidators.isValidCui('1111222230901'), isTrue); // Depto 09 Quetzaltenango
      });

      test('CUI opcional: null o cadena vacía es válido', () {
        expect(VerificationValidators.isValidCui(null), isFalse); // null directo
        expect(VerificationValidators.isValidCui(''), isTrue); // opcional
        expect(VerificationValidators.isValidCui('   '), isTrue);
        expect(VerificationValidators.validateCui(null), isNull);
        expect(VerificationValidators.validateCui(''), isNull);
      });

      test('CUI inválido por código departamental fuera de rango (00 o > 22)', () {
        expect(VerificationValidators.isValidCui('2501123450001'), isFalse); // Depto 00
        expect(VerificationValidators.isValidCui('2501123452301'), isFalse); // Depto 23 no existe
        expect(VerificationValidators.isValidCui('2501123459901'), isFalse); // Depto 99 no existe
      });

      test('CUI inválido por longitud o formato', () {
        expect(VerificationValidators.isValidCui('250112345010'), isFalse); // 12 dígitos
        expect(VerificationValidators.isValidCui('25011234501019'), isFalse); // 14 dígitos
        expect(VerificationValidators.isValidCui('250112345010A'), isFalse);
      });
    });

    group('Dominios Institucionales USAC', () {
      test('Acepta correos institucionales oficiales (.usac.edu.gt y facultades)', () {
        expect(VerificationValidators.isInstitutionalEmail('estudiante@usac.edu.gt'), isTrue);
        expect(
          VerificationValidators.isInstitutionalEmail('alumno@ingenieria.usac.edu.gt'),
          isTrue,
        );
        expect(
          VerificationValidators.isInstitutionalEmail('medico@medicina.usac.edu.gt'),
          isTrue,
        );
        expect(
          VerificationValidators.isInstitutionalEmail('abogado@derecho.usac.edu.gt'),
          isTrue,
        );
        expect(
          VerificationValidators.isInstitutionalEmail('economista@economicas.usac.edu.gt'),
          isTrue,
        );
        expect(
          VerificationValidators.isInstitutionalEmail('farmaceutico@farusac.edu.gt'),
          isTrue,
        );
        expect(VerificationValidators.isInstitutionalEmail('agronomo@fausac.gt'), isTrue);
        expect(VerificationValidators.isInstitutionalEmail('sistemas@ecys.org'), isTrue);
      });

      test('Rechaza correos comerciales y no institucionales', () {
        expect(VerificationValidators.isInstitutionalEmail('usuario@gmail.com'), isFalse);
        expect(VerificationValidators.isInstitutionalEmail('usuario@hotmail.com'), isFalse);
        expect(VerificationValidators.isInstitutionalEmail('usuario@yahoo.es'), isFalse);
        expect(VerificationValidators.isInstitutionalEmail('usuario@outlook.com'), isFalse);
        expect(VerificationValidators.isInstitutionalEmail(''), isFalse);
        expect(VerificationValidators.isInstitutionalEmail(null), isFalse);
        expect(VerificationValidators.isInstitutionalEmail('invalido'), isFalse);
      });
    });

    group('Mapeo de Errores y Seguridad (Anti-Enumeración)', () {
      test('credential_unavailable devuelve mensaje genérico sin confirmar existencia', () {
        final message = VerificationValidators.mapErrorCode('credential_unavailable');
        expect(
          message,
          'No pudimos vincular este carné. Si crees que es un error, contacta soporte.',
        );
        expect(message.contains('existe'), isFalse);
        expect(message.contains('ya registrado'), isFalse);
      });

      test('Mapeo de rate_limited y otros códigos conocidos', () {
        expect(
          VerificationValidators.mapErrorCode('rate_limited'),
          contains('24 horas'),
        );
        expect(
          VerificationValidators.mapErrorCode('invalid_carne'),
          contains('carné debe tener 9 dígitos'),
        );
        expect(
          VerificationValidators.mapErrorCode('unauthorized'),
          contains('cuenta real'),
        );
        expect(
          VerificationValidators.mapErrorCode('file_too_large'),
          contains('10 MB'),
        );
        expect(
          VerificationValidators.mapErrorCode('unsupported_media_type'),
          contains('JPEG, PNG'),
        );
        expect(
          VerificationValidators.mapErrorCode('invalid_qr_host'),
          contains('usac.edu.gt'),
        );
      });
    });

    group('Enmascaramiento de Carné', () {
      test('Enmascara carné dejando primeros 4 y último dígito', () {
        expect(VerificationValidators.maskCarne('201912345'), '2019****5');
        expect(VerificationValidators.maskCarne('202400001'), '2024****1');
        expect(VerificationValidators.maskCarne(''), '');
        expect(VerificationValidators.maskCarne(null), '');
      });
    });
  });
}
