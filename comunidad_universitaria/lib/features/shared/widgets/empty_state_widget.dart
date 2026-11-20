import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

    final titleColor = ZanateColors.textPrimary(isDark);
    final subtitleColor = ZanateColors.textSecondary(isDark);
    final circleBg = ZanateColors.surface(isDark);
    final circleBorder = ZanateColors.border(isDark);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: circleBg,
                border: Border.all(color: circleBorder, width: 1.2),
              ),
              child: Center(
                child: icon != null
                    ? Icon(icon, size: 34, color: titleColor)
                    : Text(
                        '#',
                        style: GoogleFonts.outfit(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: titleColor,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: subtitleColor,
                ),
              ),
            ),
            if (onButtonPressed != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onButtonPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark
                      ? ZanateColors.zanateEyeYellow
                      : ZanateColors.zanateBlack,
                  foregroundColor: isDark
                      ? ZanateColors.zanateBlack
                      : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  elevation: 0,
                ),
                icon: const PhosphorIcon(PhosphorIconsBold.plus, size: 17),
                label: Text(
                  buttonText ?? 'Iniciar conversación',
                  style: const TextStyle(
                    fontSize: 13.5,
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
