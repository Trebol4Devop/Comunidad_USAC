import 'package:flutter/material.dart';
import '../../../core/constants/zanate_colors.dart';
import '../state/verification_controller.dart';

/// Banner superior para estados pendientes y rechazados de verificación estudiantil
/// o de comerciante del campus USAC.
/// Cumple con las especificaciones del contrato normativo (docs/verification/merchant-contract.md §5).
class VerificationBanner extends StatelessWidget {
  final VerificationController controller;
  final VoidCallback? onRetry;
  final VoidCallback? onRetryMerchant;

  const VerificationBanner({
    super.key,
    required this.controller,
    this.onRetry,
    this.onRetryMerchant,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        // 1. Prioridad: Estudiante pendiente
        if (controller.isPendingReview) {
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

        // 2. Comerciante pendiente
        if (controller.isMerchantPending) {
          return Semantics(
            container: true,
            label: 'Aviso de solicitud de comerciante en revisión',
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
                      'Tu solicitud de comerciante está en revisión. Podrás publicar cuando sea aprobada.',
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

        // 3. Comerciante rechazado
        if (controller.isMerchantRejected) {
          final reason = controller.merchantRejectionReason;
          final message = (reason != null && reason.trim().isNotEmpty)
              ? 'Solicitud de comerciante rechazada: $reason'
              : 'Tu solicitud de comerciante fue rechazada.';

          return Semantics(
            container: true,
            label: 'Aviso de solicitud de comerciante rechazada',
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
                    onPressed: onRetryMerchant ?? onRetry,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text(
                      'Reintentar',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // 4. Estudiante rechazado
        if (controller.isRejected) {
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

        // 5. Verificado o unverified sin estados pendientes/rechazados
        return const SizedBox.shrink();
      },
    );
  }
}
