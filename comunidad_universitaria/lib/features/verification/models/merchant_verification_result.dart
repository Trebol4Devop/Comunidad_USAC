/// Resultado del envío de solicitud de verificación de comerciante USAC.
/// Cumple con las especificaciones normativas de docs/verification/merchant-contract.md §3.1.
class MerchantVerificationResult {
  final String status;
  final String? requestId;
  final String? code;
  final String? message;

  const MerchantVerificationResult({
    required this.status,
    this.requestId,
    this.code,
    this.message,
  });

  const MerchantVerificationResult.manualReview({this.requestId})
      : status = 'manual_review',
        code = null,
        message = null;

  const MerchantVerificationResult.error({
    required this.code,
    required this.message,
  })  : status = 'error',
        requestId = null;

  bool get isManualReview => status == 'manual_review';
  bool get isSuccess => isManualReview;
  bool get isError => status == 'error';

  @override
  String toString() =>
      'MerchantVerificationResult(status: $status, requestId: $requestId, code: $code, message: $message)';
}
