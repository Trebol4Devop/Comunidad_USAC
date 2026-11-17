import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/services/supabase_service.dart';
import '../models/verification_result.dart';
import '../models/verification_status.dart';
import '../services/merchant_verification_service.dart';
import '../services/verification_service.dart';
import '../utils/verification_validators.dart';

/// Controlador central del estado de verificación estudiantil y de comerciantes.
/// Extiende [ChangeNotifier] para integrarse reactivamente mediante [ListenableBuilder].
class VerificationController extends ChangeNotifier {
  final VerificationService _service;
  final MerchantVerificationService _merchantService;
  StreamSubscription? _authSubscription;

  StudentVerificationStatus _status = StudentVerificationStatus.unverified;
  String? sellerVerificationStatus; // unverified|pending|verified|rejected
  String? merchantRejectionReason;

  bool _isLoading = false;
  String? _errorMessage;
  String? _rejectionReason;
  String? _verificationMethod;
  String? _currentCarne;

  VerificationController({
    VerificationService? service,
    MerchantVerificationService? merchantService,
    bool listenToAuthChanges = true,
  })  : _service = service ?? VerificationService(),
        _merchantService = merchantService ?? MerchantVerificationService() {
    if (listenToAuthChanges && SupabaseConfig.isConfigured) {
      try {
        _authSubscription = SupabaseService.client.auth.onAuthStateChange.listen((_) {
          loadStatus();
        });
      } catch (_) {
        // Ignorar si en entorno de testing o sin inicializar
      }
    }
  }

  // Getters de estado estudiantil
  StudentVerificationStatus get status => _status;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get rejectionReason => _rejectionReason;
  String? get verificationMethod => _verificationMethod;
  String? get currentCarne => _currentCarne;
  String? get maskedCarne =>
      _currentCarne != null ? VerificationValidators.maskCarne(_currentCarne) : null;

  bool get isVerified => _status == StudentVerificationStatus.verified;
  bool get isPendingReview => _status == StudentVerificationStatus.pendingReview;
  bool get isRejected => _status == StudentVerificationStatus.rejected;
  bool get isUnverified => _status == StudentVerificationStatus.unverified;

  // Getters y acciones de comerciante
  bool get isMerchantPending => sellerVerificationStatus == 'pending';
  bool get isMerchantVerified => sellerVerificationStatus == 'verified';
  bool get isMerchantRejected => sellerVerificationStatus == 'rejected';

  void markMerchantPending() {
    sellerVerificationStatus = 'pending';
    merchantRejectionReason = null;
    notifyListeners();
  }

  /// Permite establecer directamente el estado de comerciante (útil para pruebas unitarias).
  void setMerchantStatus(String newStatus, {String? reason}) {
    sellerVerificationStatus = newStatus;
    if (reason != null) {
      merchantRejectionReason = reason;
    }
    _errorMessage = null;
    notifyListeners();
  }

  /// Permite establecer directamente el estado (útil para pruebas unitarias).
  void setStatus(StudentVerificationStatus newStatus, {String? reason}) {
    _status = newStatus;
    if (reason != null) {
      _rejectionReason = reason;
    }
    _errorMessage = null;
    notifyListeners();
  }

  /// Limpia cualquier mensaje de error activo.
  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  /// Consulta a la base de datos Supabase el estado real del usuario actual.
  Future<void> loadStatus({bool force = false}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await _service.fetchVerificationStatus();
      if (data != null) {
        final isVerifiedDb = data['is_verified'] == true;
        final rawStatus = data['verification_status']?.toString();

        if (isVerifiedDb || rawStatus == 'verified') {
          _status = StudentVerificationStatus.verified;
        } else if (rawStatus != null) {
          _status = StudentVerificationStatus.fromDb(rawStatus);
        } else {
          _status = StudentVerificationStatus.unverified;
        }

        _verificationMethod = data['verification_method']?.toString();
        _rejectionReason = data['rejection_reason']?.toString();

        final rawSellerStatus = data['seller_verification_status']?.toString();
        sellerVerificationStatus = rawSellerStatus ?? 'unverified';

        if (sellerVerificationStatus == 'rejected') {
          try {
            final latestMerchantReq =
                await _merchantService.fetchLatestMerchantRequest();
            if (latestMerchantReq != null) {
              merchantRejectionReason =
                  latestMerchantReq['rejection_reason']?.toString();
            }
          } catch (e) {
            debugPrint(
                '[VerificationController] Error consultando motivo rechazo comerciante: $e');
          }
        } else {
          merchantRejectionReason = null;
        }
      } else {
        // En offline o sesión sin perfil persistido, mantener estado seguro
        if (_status != StudentVerificationStatus.verified) {
          _status = StudentVerificationStatus.unverified;
        }
        if (sellerVerificationStatus != 'verified') {
          sellerVerificationStatus ??= 'unverified';
        }
      }
    } catch (e) {
      debugPrint('[VerificationController] Error cargando status: $e');
      _errorMessage = 'No se pudo actualizar el estado de verificación.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Reclama carné usando la RPC `claim_student_credentials` (Zero-PII: solo carné).
  Future<bool> claimCredentials({
    required String carne,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _service.claimCredentials(carne: carne);
      if (res['ok'] == true) {
        _currentCarne = carne.trim();
        // Recargar perfil para reflejar cambios
        await loadStatus();
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = res['message']?.toString() ??
            VerificationValidators.mapErrorCode(res['code']?.toString());
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('[VerificationController] Error en claimCredentials');
      _errorMessage = VerificationValidators.mapErrorCode('network_error');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Envía el documento estudiantil al Worker para verificación.
  Future<VerificationResult> submitDocument({
    required Uint8List fileBytes,
    required String fileName,
    required String carne,
    required VerificationDocumentType documentType,
    String? clientOcrText,
    String? qrUrl,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _service.submitDocument(
        fileBytes: fileBytes,
        fileName: fileName,
        carne: carne,
        documentType: documentType,
        clientOcrText: clientOcrText,
        qrUrl: qrUrl,
      );

      _currentCarne = carne.trim();

      if (result.isSuccess) {
        _status = StudentVerificationStatus.verified;
      } else if (result.isManualReview) {
        _status = StudentVerificationStatus.pendingReview;
      } else if (result.isError) {
        _errorMessage = result.message;
      }

      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      debugPrint('[VerificationController] Error enviando documento: $e');
      final err = VerificationResult.error(
        code: 'network_error',
        message: VerificationValidators.mapErrorCode('network_error'),
      );
      _errorMessage = err.message;
      _isLoading = false;
      notifyListeners();
      return err;
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
