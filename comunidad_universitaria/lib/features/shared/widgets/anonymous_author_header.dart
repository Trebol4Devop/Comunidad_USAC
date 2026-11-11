import 'package:flutter/material.dart';
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
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
      decoration: BoxDecoration(
        color: const Color(0xFFD97706), // Ámbar/naranja de acento
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'OP',
        style: TextStyle(
          color: Colors.white,
          fontSize: compact ? 9 : 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    // Etiqueta Tú
    final mineBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
        ),
      ),
      child: Text(
        'Tú',
        style: TextStyle(
          color: isDark ? Colors.grey.shade200 : Colors.grey.shade800,
          fontSize: compact ? 9 : 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: compact ? 11 : 14,
          backgroundColor: isDark
              ? const Color(0xFF3B82F6).withValues(alpha: 0.2)
              : theme.colorScheme.primary.withValues(alpha: 0.12),
          child: Icon(
            Icons.person,
            size: compact ? 12 : 16,
            color: theme.colorScheme.primary,
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
                  fontWeight: FontWeight.bold,
                  fontSize: compact ? 12 : 13,
                ),
              ),
              ?hashChip,
              if (isOp) opBadge,
              if (isMine) mineBadge,
              if (createdAt != null)
                Text(
                  '• ${TimeUtils.timeAgo(createdAt!)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: compact ? 10 : 11,
                  ),
                ),
            ],
          ),
        ),
        if (isMine && onDelete != null)
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            color: Colors.red.shade400,
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
              Icons.flag_outlined,
              size: 16,
              color: Colors.grey.shade500,
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
