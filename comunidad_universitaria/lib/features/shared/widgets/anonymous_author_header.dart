import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../core/constants/zanate_colors.dart';
import '../../../core/utils/time_utils.dart';

/// Encabezado reutilizable de autor anónimo para el foro.
/// Garantiza una identidad visual 100% determinista basada en authorHash.
class AnonymousAuthorHeader extends StatelessWidget {
  final String authorAlias;
  final String? authorHash;
  final bool isOp;
  final bool isMine;
  final DateTime? createdAt;
  final VoidCallback? onDelete;
  final VoidCallback? onReport;
  final Widget? trailing;
  final bool compact;

  const AnonymousAuthorHeader({
    super.key,
    required this.authorAlias,
    this.authorHash,
    this.isOp = false,
    this.isMine = false,
    this.createdAt,
    this.onDelete,
    this.onReport,
    this.trailing,
    this.compact = false,
  });

  /// Genera un color 100% determinista a partir del hash del autor.
  /// PROHIBIDO el uso de Random, DateTime.now() o hashCode de objetos.
  static Color colorForHash(String hash) {
    if (hash.isEmpty) {
      return const Color(0xFF64748B);
    }
    int acc = 0;
    for (int i = 0; i < hash.length; i++) {
      acc = (acc * 31 + hash.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    final double hue = (acc % 360).toDouble();
    return HSLColor.fromAHSL(1.0, hue, 0.55, 0.45).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Chip determinista de authorHash (si existe y no está vacío)
    Widget? hashChip;
    if (authorHash != null && authorHash!.trim().isNotEmpty) {
      final cleanHash = authorHash!.trim();
      final shortHash = cleanHash.length > 6
          ? cleanHash.substring(0, 6)
          : cleanHash;
      final chipBg = colorForHash(cleanHash);
      final textColor = chipBg.computeLuminance() > 0.5
          ? Colors.black87
          : Colors.white;

      hashChip = Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
        decoration: BoxDecoration(
          color: chipBg,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '#$shortHash',
          style: TextStyle(
            color: textColor,
            fontSize: compact ? 9 : 10,
            fontWeight: FontWeight.w700,
            fontFamily: 'monospace',
          ),
        ),
      );
    }

    // Insignia OP (Autor original)
    final opBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: ZanateColors.zanateEyeYellow,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        'OP',
        style: TextStyle(
          color: ZanateColors.zanateBlack,
          fontSize: compact ? 9 : 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    // Etiqueta Tú
    final mineBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: ZanateColors.surface(isDark),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: ZanateColors.border(isDark)),
      ),
      child: Text(
        'Tú',
        style: TextStyle(
          color: ZanateColors.textPrimary(isDark),
          fontSize: compact ? 9 : 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: compact ? 24 : 30,
          height: compact ? 24 : 30,
          decoration: BoxDecoration(
            color: ZanateColors.surface(isDark),
            shape: BoxShape.circle,
            border: Border.all(
              color: ZanateColors.border(isDark),
              width: 1.0,
            ),
          ),
          child: Center(
            child: Icon(
              PhosphorIconsRegular.user,
              size: compact ? 13 : 16,
              color: ZanateColors.textPrimary(isDark),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              Text(
                authorAlias,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: compact ? 12.5 : 13.5,
                  color: ZanateColors.textPrimary(isDark),
                ),
              ),
              ?hashChip,
              if (isOp) opBadge,
              if (isMine) mineBadge,
              if (createdAt != null)
                Text(
                  '• ${TimeUtils.timeAgo(createdAt!)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: compact ? 10.5 : 11,
                    color: ZanateColors.textMuted(isDark),
                  ),
                ),
            ],
          ),
        ),
        if (isMine && onDelete != null)
          IconButton(
            icon: const Icon(PhosphorIconsRegular.trash, size: 17),
            color: const Color(0xFFEF4444),
            tooltip: 'Eliminar (soft delete)',
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(
              minWidth: compact ? 32 : 36,
              minHeight: compact ? 32 : 36,
            ),
            onPressed: onDelete,
          ),
        if (!isMine && onReport != null)
          IconButton(
            icon: Icon(
              PhosphorIconsRegular.flag,
              size: 16,
              color: ZanateColors.textMuted(isDark),
            ),
            tooltip: 'Reportar',
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(
              minWidth: compact ? 32 : 36,
              minHeight: compact ? 32 : 36,
            ),
            onPressed: onReport,
          ),
        ?trailing,
      ],
    );
  }
}
