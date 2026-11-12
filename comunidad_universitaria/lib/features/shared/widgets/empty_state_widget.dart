import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../core/constants/zanate_colors.dart';

class EmptyStateWidget extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String description;
  final String? buttonText;
  final VoidCallback? onButtonPressed;

  const EmptyStateWidget({
    super.key,
    this.icon,
    required this.title,
    required this.description,
    this.buttonText,
    this.onButtonPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final titleColor = isDark ? Colors.white : ZanateColors.zanateDark;
    final subtitleColor =
        isDark ? const Color(0xFF94A3B8) : Colors.blueGrey.shade500;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    ZanateColors.zanateAccent.withValues(alpha: isDark ? 0.25 : 0.14),
                    const Color(0xFF38BDF8).withValues(alpha: isDark ? 0.16 : 0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: ZanateColors.zanateAccent.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Center(
                child: icon != null
                    ? Icon(
                        icon,
                        size: 38,
                        color: ZanateColors.zanateAccent,
                      )
                    : const Text(
                        '#',
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          color: ZanateColors.zanateAccent,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: subtitleColor,
                ),
              ),
            ),
            if (onButtonPressed != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onButtonPressed,
                style: FilledButton.styleFrom(
                  backgroundColor:
                      isDark ? ZanateColors.zanateAccent : ZanateColors.zanateDark,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  elevation: 0,
                ),
                icon: const PhosphorIcon(PhosphorIconsRegular.plus, size: 18),
                label: Text(
                  buttonText ?? 'Iniciar conversación',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
