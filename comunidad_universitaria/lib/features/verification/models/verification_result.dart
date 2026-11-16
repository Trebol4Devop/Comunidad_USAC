import 'verification_status.dart';

/// Resultado devuelto por las operaciones de verificación (RPC o Worker).
class VerificationResult {
  final StudentVerificationStatus status;
  final String? requestId;
  final String? code;
  final String? message;

  const VerificationResult({
    required this.status,
    this.requestId,
    this.code,
    this.message,
  });

  factory VerificationResult.verified({
    String? requestId,
    String? message,
  }) {
    return VerificationResult(
      status: StudentVerificationStatus.verified,
      requestId: requestId,
      message: message ?? 'Tu cuenta ha sido verificada exitosamente como estudiante USAC.',
    );
  }

  factory VerificationResult.manualReview({
    String? requestId,
    String? message,
  }) {
    return VerificationResult(
      status: StudentVerificationStatus.pendingReview,
      requestId: requestId,
      message: message ??
          'Tu documento ha sido enviado a revisión manual. Te notificaremos una vez sea validado.',
    );
  }

  factory VerificationResult.error({
    required String code,
    required String message,
  }) {
    return VerificationResult(
      status: StudentVerificationStatus.unverified,
      code: code,
      message: message,
    );
  }

  bool get isSuccess => status == StudentVerificationStatus.verified;
  bool get isManualReview => status == StudentVerificationStatus.pendingReview;
  bool get isError => code != null;
}
