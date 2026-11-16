import 'package:flutter/material.dart';
import '../../../core/constants/zanate_colors.dart';
import '../models/verification_status.dart';
import '../state/verification_controller.dart';

/// Banner superior para estados pendientes y rechazados de verificación.
/// No se muestra en estado verificado o sin verificar (contrato §7).
class VerificationBanner extends StatelessWidget {
  final VerificationController controller;
  final VoidCallback? onRetry;

  const VerificationBanner({
    super.key,
    required this.controller,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final status = controller.status;

        if (status == StudentVerificationStatus.verified ||
            status == StudentVerificationStatus.unverified) {
          return const SizedBox.shrink();
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;

        if (status == StudentVerificationStatus.pendingReview) {
          return Semantics(
            container: true,
            label: 'Aviso de verificación en revisión',
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFBFDBFE),
                    width: 1,
                  ),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.hourglass_top_rounded,
                    color: ZanateColors.zanateAccent,
                    size: 20,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tu verificación está en revisión. Podrás publicar en el Marketplace en breve.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: ZanateColors.zanateAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (status == StudentVerificationStatus.rejected) {
          final reason = controller.rejectionReason;
          final message = (reason != null && reason.trim().isNotEmpty)
              ? 'Verificación rechazada: $reason'
              : 'Tu solicitud de verificación fue rechazada.';

          return Semantics(
            container: true,
            label: 'Aviso de verificación rechazada',
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF451A1A) : const Color(0xFFFEF2F2),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFDC2626),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFB91C1C),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFB91C1C),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text(
                      'Reintentar verificación',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}
