import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:comunidad_universitaria/features/verification/services/merchant_verification_service.dart';

class MockMultipartClient extends http.BaseClient {
  FutureOr<http.StreamedResponse> Function(http.BaseRequest request)? handler;
  http.BaseRequest? lastRequest;
  int callCount = 0;

  MockMultipartClient([this.handler]);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    callCount++;
    lastRequest = request;
    if (handler != null) {
      return await handler!(request);
    }
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode({'status': 'manual_review', 'request_id': 'req-default'}))),
      200,
    );
  }
}

void main() {
  group('MerchantVerificationService Tests', () {
    late MockMultipartClient mockClient;
    late MerchantVerificationService service;

    final dummyFront = Uint8List.fromList([1, 2, 3]);
    final dummyBack = Uint8List.fromList([4, 5, 6]);
    final dummyEstablishment = Uint8List.fromList([7, 8, 9]);

    setUp(() {
      mockClient = MockMultipartClient();
      service = MerchantVerificationService(
        httpClient: mockClient,
        baseUrl: 'https://test-worker.dev',
        tokenProvider: () => 'valid-bearer-token',
        isAnonymousProvider: () => false,
      );
    });

    test('Envía multipart con los 3 archivos y campos requeridos', () async {
      mockClient.handler = (req) {
        expect(req, isA<http.MultipartRequest>());
        final multiReq = req as http.MultipartRequest;

        expect(multiReq.method, 'POST');
        expect(multiReq.url.path, '/api/v1/verify-merchant');
        expect(multiReq.headers['Authorization'], 'Bearer valid-bearer-token');

        expect(multiReq.fields['business_name'], 'Librería Central');
        expect(multiReq.fields['dpi_number'], '2501123450101');
        expect(multiReq.fields['establishment_note'], 'Frente al T-3');

        final fileNames = multiReq.files.map((f) => f.field).toList();
        expect(fileNames, containsAll(['dpi_front', 'dpi_back', 'establishment']));

        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({
            'status': 'manual_review',
            'request_id': 'uuid-merchant-123',
          }))),
          200,
          headers: {'content-type': 'application/json'},
        );
      };

      final result = await service.submitMerchantVerification(
        dpiFront: dummyFront,
        dpiBack: dummyBack,
        establishment: dummyEstablishment,
        businessName: 'Librería Central',
        dpiNumber: '2501123450101',
        establishmentNote: 'Frente al T-3',
      );

      expect(mockClient.callCount, 1);
      expect(result.isSuccess, isTrue);
      expect(result.isManualReview, isTrue);
      expect(result.requestId, 'uuid-merchant-123');
    });

    test('Sesión anónima no llama a la red y devuelve unauthorized', () async {
      final anonService = MerchantVerificationService(
        httpClient: mockClient,
        baseUrl: 'https://test-worker.dev',
        tokenProvider: () => 'some-token',
        isAnonymousProvider: () => true, // Usuario anónimo
      );

      final result = await anonService.submitMerchantVerification(
        dpiFront: dummyFront,
        dpiBack: dummyBack,
        establishment: dummyEstablishment,
        businessName: 'Librería',
        dpiNumber: '2501123450101',
      );

      expect(mockClient.callCount, 0); // No toca la red
      expect(result.isError, isTrue);
      expect(result.code, 'unauthorized');
    });

    test('Sin token de sesión no llama a la red y devuelve unauthorized', () async {
      final noTokenService = MerchantVerificationService(
        httpClient: mockClient,
        baseUrl: 'https://test-worker.dev',
        tokenProvider: () => null,
        isAnonymousProvider: () => false,
      );

      final result = await noTokenService.submitMerchantVerification(
        dpiFront: dummyFront,
        dpiBack: dummyBack,
        establishment: dummyEstablishment,
        businessName: 'Librería',
        dpiNumber: '2501123450101',
      );

      expect(mockClient.callCount, 0);
      expect(result.isError, isTrue);
      expect(result.code, 'unauthorized');
    });

    test('Mapeo de error 409 credential_unavailable con mensaje genérico', () async {
      mockClient.handler = (_) => http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({
          'status': 'error',
          'code': 'credential_unavailable',
          'message': 'DPI claimed',
        }))),
        409,
        headers: {'content-type': 'application/json'},
      );

      final result = await service.submitMerchantVerification(
        dpiFront: dummyFront,
        dpiBack: dummyBack,
        establishment: dummyEstablishment,
        businessName: 'Café',
        dpiNumber: '2501123450101',
      );

      expect(result.isError, isTrue);
      expect(result.code, 'credential_unavailable');
      expect(
        result.message,
        'No pudimos registrar este DPI. Si crees que es un error, contacta soporte.',
      );
    });

    test('Mapeo de error 429 rate_limited', () async {
      mockClient.handler = (_) => http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({
          'status': 'error',
          'code': 'rate_limited',
        }))),
        429,
        headers: {'content-type': 'application/json'},
      );

      final result = await service.submitMerchantVerification(
        dpiFront: dummyFront,
        dpiBack: dummyBack,
        establishment: dummyEstablishment,
        businessName: 'Café',
        dpiNumber: '2501123450101',
      );

      expect(result.isError, isTrue);
      expect(result.code, 'rate_limited');
      expect(result.message, 'Demasiados intentos. Espera 24 horas.');
    });

    test('Mapeo de error 413 file_too_large', () async {
      mockClient.handler = (_) => http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({
          'status': 'error',
          'code': 'file_too_large',
        }))),
        413,
        headers: {'content-type': 'application/json'},
      );

      final result = await service.submitMerchantVerification(
        dpiFront: dummyFront,
        dpiBack: dummyBack,
        establishment: dummyEstablishment,
        businessName: 'Café',
        dpiNumber: '2501123450101',
      );

      expect(result.isError, isTrue);
      expect(result.code, 'file_too_large');
      expect(result.message, 'El archivo supera el tamaño máximo permitido de 10 MB.');
    });

    test('Mapeo de error 415 unsupported_media_type', () async {
      mockClient.handler = (_) => http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({
          'status': 'error',
          'code': 'unsupported_media_type',
        }))),
        415,
        headers: {'content-type': 'application/json'},
      );

      final result = await service.submitMerchantVerification(
        dpiFront: dummyFront,
        dpiBack: dummyBack,
        establishment: dummyEstablishment,
        businessName: 'Café',
        dpiNumber: '2501123450101',
      );

      expect(result.isError, isTrue);
      expect(result.code, 'unsupported_media_type');
      expect(
        result.message,
        'Formato de imagen inválido. Solo se admiten archivos JPEG, PNG y WebP.',
      );
    });

    test('Mapeo de error 422 con validaciones específicas', () async {
      mockClient.handler = (_) => http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({
          'status': 'error',
          'code': 'invalid_dpi',
        }))),
        422,
        headers: {'content-type': 'application/json'},
      );

      final result = await service.submitMerchantVerification(
        dpiFront: dummyFront,
        dpiBack: dummyBack,
        establishment: dummyEstablishment,
        businessName: 'Café',
        dpiNumber: '123',
      );

      expect(result.isError, isTrue);
      expect(result.code, 'invalid_dpi');
      expect(
        result.message,
        'El número de DPI debe tener 13 dígitos y un código departamental válido (01-22).',
      );
    });

    test('Mapeo de error 403 / 401', () async {
      mockClient.handler = (_) => http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({
          'status': 'error',
          'code': 'anonymous_not_allowed',
        }))),
        403,
        headers: {'content-type': 'application/json'},
      );

      final result = await service.submitMerchantVerification(
        dpiFront: dummyFront,
        dpiBack: dummyBack,
        establishment: dummyEstablishment,
        businessName: 'Café',
        dpiNumber: '2501123450101',
      );

      expect(result.isError, isTrue);
      expect(result.code, 'unauthorized');
    });

    test('Mapeo de error 500 interno del servidor', () async {
      mockClient.handler = (_) => http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({
          'status': 'error',
          'code': 'upload_failed',
          'message': 'Storage unreachable',
        }))),
        500,
        headers: {'content-type': 'application/json'},
      );

      final result = await service.submitMerchantVerification(
        dpiFront: dummyFront,
        dpiBack: dummyBack,
        establishment: dummyEstablishment,
        businessName: 'Café',
        dpiNumber: '2501123450101',
      );

      expect(result.isError, isTrue);
      expect(result.code, 'upload_failed');
    });

    test('Manejo de timeout de red', () async {
      mockClient.handler = (_) async {
        throw TimeoutException('Connection timed out');
      };

      final result = await service.submitMerchantVerification(
        dpiFront: dummyFront,
        dpiBack: dummyBack,
        establishment: dummyEstablishment,
        businessName: 'Café',
        dpiNumber: '2501123450101',
      );

      expect(result.isError, isTrue);
      expect(result.code, 'network_timeout');
      expect(
        result.message,
        'Tiempo de espera agotado al conectar con el servidor de verificación. Por favor intenta de nuevo.',
      );
    });
  });
}
