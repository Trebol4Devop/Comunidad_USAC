import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:comunidad_universitaria/features/verification/models/verification_result.dart';
import 'package:comunidad_universitaria/features/verification/models/verification_status.dart';
import 'package:comunidad_universitaria/features/verification/services/verification_service.dart';
import 'package:comunidad_universitaria/features/verification/state/verification_controller.dart';

/// Fake de [VerificationService] sin llamadas de red ni dependencias externas.
class FakeVerificationService extends VerificationService {
  Map<String, dynamic>? statusToReturn;
  Map<String, dynamic> claimResultToReturn = {'ok': true};
  VerificationResult? submitResultToReturn;

  @override
  Future<Map<String, dynamic>?> fetchVerificationStatus() async {
    return statusToReturn;
  }

  @override
  Future<Map<String, dynamic>> claimCredentials({
    required String carne,
    String? cui,
  }) async {
    return claimResultToReturn;
  }

  @override
  Future<VerificationResult> submitDocument({
    required Uint8List fileBytes,
    required String fileName,
    required String carne,
    required VerificationDocumentType documentType,
    String? cui,
    String? clientOcrText,
    String? qrUrl,
  }) async {
    return submitResultToReturn ??
        VerificationResult.verified(requestId: 'test-req-123');
  }
}

void main() {
  group('VerificationController Unit Tests', () {
    late FakeVerificationService fakeService;
    late VerificationController controller;

    setUp(() {
      fakeService = FakeVerificationService();
      // Inicializar sin suscripción a auth real para aislar el test
      controller = VerificationController(
        service: fakeService,
        listenToAuthChanges: false,
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('Estado inicial es unverified y no tiene errores', () {
      expect(controller.status, StudentVerificationStatus.unverified);
      expect(controller.isUnverified, isTrue);
      expect(controller.isVerified, isFalse);
      expect(controller.isPendingReview, isFalse);
      expect(controller.isRejected, isFalse);
      expect(controller.isLoading, isFalse);
      expect(controller.errorMessage, isNull);
    });

    test('Transición: unverified → pending_review mediante submitDocument dudoso', () async {
      fakeService.submitResultToReturn = VerificationResult.manualReview(
        requestId: 'req-manual-1',
      );

      final result = await controller.submitDocument(
        fileBytes: Uint8List(10),
        fileName: 'constancia.jpg',
        carne: '201901234',
        documentType: VerificationDocumentType.constanciaInscripcion,
      );

      expect(result.isManualReview, isTrue);
      expect(controller.status, StudentVerificationStatus.pendingReview);
      expect(controller.isPendingReview, isTrue);
      expect(controller.maskedCarne, '2019****4');
    });

    test('Transición: pending_review → verified al recargar status aprobado', () async {
      // 1. Simular estado previo en revisión
      controller.setStatus(StudentVerificationStatus.pendingReview);
      expect(controller.isPendingReview, isTrue);

      // 2. Staff aprueba la solicitud en el backend
      fakeService.statusToReturn = {
        'is_verified': true,
        'verification_status': 'verified',
        'verification_method': 'manual_review',
      };

      await controller.loadStatus();

      expect(controller.status, StudentVerificationStatus.verified);
      expect(controller.isVerified, isTrue);
      expect(controller.verificationMethod, 'manual_review');
    });

    test('Transición: rejected y recarga con motivo de rechazo', () async {
      fakeService.statusToReturn = {
        'is_verified': false,
        'verification_status': 'rejected',
        'rejection_reason': 'Documento ilegible o foto con brillo',
      };

      await controller.loadStatus();

      expect(controller.status, StudentVerificationStatus.rejected);
      expect(controller.isRejected, isTrue);
      expect(controller.rejectionReason, 'Documento ilegible o foto con brillo');
    });

    test('Manejo de error y recarga tras fallo en claimCredentials', () async {
      // 1. Fallo por carné ya tomado (credential_unavailable)
      fakeService.claimResultToReturn = {
        'ok': false,
        'code': 'credential_unavailable',
        'message': 'No pudimos vincular este carné. Si crees que es un error, contacta soporte.',
      };

      final ok = await controller.claimCredentials(carne: '201900001');

      expect(ok, isFalse);
      expect(controller.errorMessage, contains('No pudimos vincular este carné'));
      expect(controller.status, StudentVerificationStatus.unverified);

      // 2. Limpiar error y reintentar con éxito
      controller.clearError();
      expect(controller.errorMessage, isNull);

      fakeService.claimResultToReturn = {
        'ok': true,
        'verification_status': 'verified',
        'is_verified': true,
      };
      fakeService.statusToReturn = {
        'is_verified': true,
        'verification_status': 'verified',
      };

      final retryOk = await controller.claimCredentials(carne: '201900002');

      expect(retryOk, isTrue);
      expect(controller.status, StudentVerificationStatus.verified);
      expect(controller.isVerified, isTrue);
    });

    test('Transición directa a verified mediante submitDocument auto-aprobado', () async {
      fakeService.submitResultToReturn = VerificationResult.verified(
        requestId: 'auto-approved-1',
      );

      final result = await controller.submitDocument(
        fileBytes: Uint8List(10),
        fileName: 'carne.png',
        carne: '202012345',
        documentType: VerificationDocumentType.carneFisico,
      );

      expect(result.isSuccess, isTrue);
      expect(controller.status, StudentVerificationStatus.verified);
      expect(controller.isVerified, isTrue);
    });
  });
}
