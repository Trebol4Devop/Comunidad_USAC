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
