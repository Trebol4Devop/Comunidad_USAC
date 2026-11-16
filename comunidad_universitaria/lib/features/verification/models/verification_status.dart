/// Estados y tipos del sistema de verificación estudiantil USAC.
/// Alineado con el contrato normativo (docs/verification/contract.md §2.2, §7).
library;

enum StudentVerificationStatus {
  unverified,
  pendingReview,
  verified,
  rejected;

  static StudentVerificationStatus fromDb(String? value) {
    switch (value?.toLowerCase().trim()) {
      case 'verified':
        return StudentVerificationStatus.verified;
      case 'pending_review':
        return StudentVerificationStatus.pendingReview;
      case 'rejected':
        return StudentVerificationStatus.rejected;
      case 'unverified':
      default:
        return StudentVerificationStatus.unverified;
    }
  }

  String toDb() {
    switch (this) {
      case StudentVerificationStatus.verified:
        return 'verified';
      case StudentVerificationStatus.pendingReview:
        return 'pending_review';
      case StudentVerificationStatus.rejected:
        return 'rejected';
      case StudentVerificationStatus.unverified:
        return 'unverified';
    }
  }

  bool get isVerified => this == StudentVerificationStatus.verified;
  bool get isPendingReview => this == StudentVerificationStatus.pendingReview;
  bool get isRejected => this == StudentVerificationStatus.rejected;
  bool get isUnverified => this == StudentVerificationStatus.unverified;
}

enum VerificationDocumentType {
  constanciaInscripcion,
  carneFisico,
  boletaAsignacion;

  static VerificationDocumentType fromDb(String? value) {
    switch (value?.toLowerCase().trim()) {
      case 'carne_fisico':
        return VerificationDocumentType.carneFisico;
      case 'boleta_asignacion':
        return VerificationDocumentType.boletaAsignacion;
      case 'constancia_inscripcion':
      default:
        return VerificationDocumentType.constanciaInscripcion;
    }
  }

  String toDb() {
    switch (this) {
      case VerificationDocumentType.constanciaInscripcion:
        return 'constancia_inscripcion';
      case VerificationDocumentType.carneFisico:
        return 'carne_fisico';
      case VerificationDocumentType.boletaAsignacion:
        return 'boleta_asignacion';
    }
  }

  String get displayName {
    switch (this) {
      case VerificationDocumentType.constanciaInscripcion:
        return 'Constancia de inscripción';
      case VerificationDocumentType.carneFisico:
        return 'Carné físico universitario';
      case VerificationDocumentType.boletaAsignacion:
        return 'Boleta de asignación de cursos';
    }
  }
}
