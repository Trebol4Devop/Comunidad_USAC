import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../core/constants/zanate_colors.dart';

/// Barra de acento amarilla característica del lenguaje visual Zanate.
class ZanateAccentBar extends StatelessWidget {
  final double width;
  final double height;
  final Color color;

  const ZanateAccentBar({
    super.key,
    this.width = 44,
    this.height = 4,
    this.color = ZanateColors.zanateEyeYellow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
  }
}

/// Encabezado móvil estandarizado de 58px con soporte para kicker, título y acciones.
class ZanatePageHeader extends StatelessWidget {
  final String title;
  final String? kicker;
  final String? subtitle;
  final Widget? leading;
  final VoidCallback? onBack;
  final String backTooltip;
  final List<Widget>? trailing;
  final bool centerTitle;
  final double height;
  final bool safeAreaTop;

  const ZanatePageHeader({
    super.key,
    required this.title,
    this.kicker,
    this.subtitle,
    this.leading,
    this.onBack,
    this.backTooltip = 'Volver',
    this.trailing,
    this.centerTitle = true,
    this.height = 58,
    this.safeAreaTop = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = ZanateColors.border(isDark);
    final textPrimary = ZanateColors.textPrimary(isDark);
    final textMuted = ZanateColors.textMuted(isDark);

    final Widget? resolvedLeading =
        leading ??
        (onBack != null
            ? IconButton(
                onPressed: onBack,
                tooltip: backTooltip,
                icon: Icon(
                  PhosphorIconsBold.caretLeft,
                  size: 22,
                  color: textPrimary,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: ZanateColors.pill(isDark),
                  fixedSize: const Size(38, 38),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                    side: BorderSide(color: borderColor, width: 0.8),
                  ),
                ),
              )
            : null);

    final bool hasTrailing = trailing != null && trailing!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: ZanateColors.card(isDark),
        border: Border(
          bottom: BorderSide(color: borderColor, width: 1),
        ),
      ),
      child: SafeArea(
        top: safeAreaTop,
        bottom: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: height),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                if (resolvedLeading != null)
                  resolvedLeading
                else if (centerTitle && hasTrailing)
                  const SizedBox(width: 40),
                if (resolvedLeading != null) const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: centerTitle
                        ? CrossAxisAlignment.center
                        : CrossAxisAlignment.start,
                    children: [
                      if (kicker != null && kicker!.isNotEmpty)
                        Text(
                          kicker!.toUpperCase(),
                          textAlign: centerTitle
                              ? TextAlign.center
                              : TextAlign.start,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: textMuted,
                          ),
                        ),
                      Text(
                        title,
                        textAlign: centerTitle
                            ? TextAlign.center
                            : TextAlign.start,
                        style: GoogleFonts.outfit(
                          fontSize: 17.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          height: 1.15,
                          color: textPrimary,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty)
                        Text(
                          subtitle!,
                          textAlign: centerTitle
                              ? TextAlign.center
                              : TextAlign.start,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: ZanateColors.textSecondary(isDark),
                          ),
                        ),
                    ],
                  ),
                ),
                if (hasTrailing) ...[
                  const SizedBox(width: 8),
                  Row(mainAxisSize: MainAxisSize.min, children: trailing!),
                ] else if (centerTitle && resolvedLeading != null)
                  const SizedBox(width: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Construye un [InputDecoration] consistente con el lenguaje Zanate en claro y oscuro.
InputDecoration zanateInputDecoration({
  required bool isDark,
  String? labelText,
  String? hintText,
  String? helperText,
  String? errorText,
  Widget? prefixIcon,
  Widget? suffixIcon,
  EdgeInsetsGeometry? contentPadding,
  Color? fillColor,
  double borderRadius = 14,
}) {
  final borderColor = ZanateColors.border(isDark);
  final focusColor = ZanateColors.focusBorder(isDark);
  final errorColor = isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
  final muted = ZanateColors.textMuted(isDark);

  OutlineInputBorder outline(Color color, [double width = 1.0]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    helperText: helperText,
    errorText: errorText,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: fillColor ?? ZanateColors.surface(isDark),
    labelStyle: TextStyle(
      color: ZanateColors.textSecondary(isDark),
      fontSize: 13.5,
    ),
    hintStyle: TextStyle(color: muted, fontSize: 14),
    helperStyle: TextStyle(color: muted, fontSize: 12),
    errorStyle: TextStyle(color: errorColor, fontSize: 12),
    contentPadding:
        contentPadding ??
        const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: outline(borderColor),
    enabledBorder: outline(borderColor),
    focusedBorder: outline(focusColor, 1.6),
    errorBorder: outline(errorColor, 1.2),
    focusedErrorBorder: outline(errorColor, 1.6),
  );
}

/// Ícono oficial "G" de Google en 4 colores vectoriales.
class ZanateGoogleIcon extends StatelessWidget {
  final double size;

  const ZanateGoogleIcon({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _ZanateGooglePainter()),
    );
  }
}

class _ZanateGooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final strokeWidth = size.width * 0.21;
    final radius = size.width * 0.37;
    final arcRect = Rect.fromCircle(center: center, radius: radius);

    Paint arcPaint(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    const deg = math.pi / 180;

    canvas.drawArc(
      arcRect,
      -150 * deg,
      110 * deg,
      false,
      arcPaint(const Color(0xFFEA4335)),
    );
    canvas.drawArc(
      arcRect,
      147 * deg,
      65 * deg,
      false,
      arcPaint(const Color(0xFFFBBC05)),
    );
    canvas.drawArc(
      arcRect,
      44 * deg,
      105 * deg,
      false,
      arcPaint(const Color(0xFF34A853)),
    );

    const blueColor = Color(0xFF4285F4);
    canvas.drawArc(arcRect, -6 * deg, 52 * deg, false, arcPaint(blueColor));

    canvas.save();
    final outerClip = Path()
      ..addOval(
        Rect.fromCircle(center: center, radius: radius + strokeWidth / 2),
      );
    canvas.clipPath(outerClip);
    canvas.drawRect(
      Rect.fromLTRB(
        center.dx,
        center.dy - strokeWidth * 0.46,
        size.width,
        center.dy + strokeWidth * 0.46,
      ),
      Paint()..color = blueColor,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
