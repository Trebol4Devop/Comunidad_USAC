import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
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

        final pendingBg =
            isDark ? const Color(0xFF2B2108) : const Color(0xFFFFFBEB);
        final pendingBorder =
            isDark ? const Color(0xFF78350F) : const Color(0xFFFDE68A);
        final pendingFg =
            isDark ? ZanateColors.zanateEyeYellow : ZanateColors.zanateBlack;
        final errorBg =
            isDark ? const Color(0xFF3F1616) : const Color(0xFFFEF2F2);
        final errorBorder =
            isDark ? const Color(0xFF991B1B) : const Color(0xFFFECACA);
        final errorIconColor =
            isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
        final errorTextColor =
            isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C);

        // 1. Prioridad: Estudiante pendiente
        if (controller.isPendingReview) {
          return Semantics(
            container: true,
            label: 'Aviso de verificación en revisión',
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: pendingBg,
                border: Border(
                  bottom: BorderSide(
                    color: pendingBorder,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    PhosphorIconsRegular.hourglassMedium,
                    color: pendingFg,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tu verificación está en revisión. Podrás publicar en el Marketplace en breve.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: pendingFg,
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
                color: pendingBg,
                border: Border(
                  bottom: BorderSide(
                    color: pendingBorder,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    PhosphorIconsRegular.hourglassMedium,
                    color: pendingFg,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tu solicitud de comerciante está en revisión. Podrás publicar cuando sea aprobada.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: pendingFg,
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
                color: errorBg,
                border: Border(
                  bottom: BorderSide(
                    color: errorBorder,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    PhosphorIconsRegular.warningCircle,
                    color: errorIconColor,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: errorTextColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: errorTextColor,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: onRetryMerchant ?? onRetry,
                    icon: const Icon(PhosphorIconsRegular.arrowsClockwise, size: 16),
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
                color: errorBg,
                border: Border(
                  bottom: BorderSide(
                    color: errorBorder,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    PhosphorIconsRegular.warningCircle,
                    color: errorIconColor,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: errorTextColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: errorTextColor,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: onRetry,
                    icon: const Icon(PhosphorIconsRegular.arrowsClockwise, size: 16),
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
