import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../core/constants/zanate_colors.dart';

enum IdentityMode { forumAnonymous, marketplaceVerified }

class IdentityBadgeChip extends StatelessWidget {
  final IdentityMode mode;
  final String displayName;
  final String? carne;
  final bool isVerified;
  final VoidCallback? onSwitchIdentity;

  const IdentityBadgeChip({
    super.key,
    required this.mode,
    required this.displayName,
    this.carne,
    this.isVerified = false,
    this.onSwitchIdentity,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = ZanateColors.textPrimary(isDark);
    final subtle = ZanateColors.textMuted(isDark);
    final chipBg = ZanateColors.surface(isDark);
    final borderColor = ZanateColors.border(isDark);

    if (mode == IdentityMode.forumAnonymous) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: chipBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: ZanateColors.bg(isDark),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: Icon(PhosphorIconsRegular.user, size: 16, color: fg),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        'Autor: ',
                        style: TextStyle(fontSize: 11.5, color: subtle),
                      ),
                      Flexible(
                        child: Text(
                          displayName,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: fg,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'Perfil Estudiantil',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: subtle,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (onSwitchIdentity != null)
              InkWell(
                onTap: onSwitchIdentity,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        PhosphorIconsRegular.arrowsClockwise,
                        size: 13,
                        color: fg,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Cambiar',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: fg,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: chipBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: ZanateColors.zanateEyeYellow.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isVerified
                    ? PhosphorIconsFill.sealCheck
                    : PhosphorIconsRegular.shieldCheck,
                size: 16,
                color: isDark
                    ? ZanateColors.zanateEyeYellow
                    : ZanateColors.zanateBlack,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    children: [
                      Text(
                        'Vendedor: ',
                        style: TextStyle(fontSize: 11.5, color: subtle),
                      ),
                      Text(
                        displayName,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: fg,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isVerified)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: ZanateColors.zanateEyeYellow,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text(
                            'Verificado',
                            style: TextStyle(
                              color: ZanateColors.zanateBlack,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isVerified
                              ? 'Identidad validada con carné institucional USAC'
                              : 'Perfil estudiantil de contacto directo',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: subtle,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (onSwitchIdentity != null)
              InkWell(
                onTap: onSwitchIdentity,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        PhosphorIconsRegular.shield,
                        size: 13,
                        color: fg,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Ajustes',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: fg,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    }
  }
}
