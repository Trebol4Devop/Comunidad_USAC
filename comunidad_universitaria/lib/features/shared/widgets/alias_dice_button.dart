import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../core/constants/anonymous_aliases.dart';
import '../../../core/constants/zanate_colors.dart';

/// Botón reutilizable con icono de dados para generar alias anónimos de manera aleatoria.
/// No permite entrada manual ni contiene TextField.
class AliasDiceButton extends StatelessWidget {
  final String alias;
  final ValueChanged<String> onAliasChanged;
  final bool compact;

  const AliasDiceButton({
    super.key,
    required this.alias,
    required this.onAliasChanged,
    this.compact = false,
  });

  void _generateNewAlias() {
    final newAlias = AnonymousAliasGenerator.generate();
    onAliasChanged(newAlias);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg = isDark ? Colors.white : ZanateColors.zanateBlack;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : ZanateColors.surfaceBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : ZanateColors.subtleBorder,
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            PhosphorIconsRegular.user,
            size: compact ? 14 : 16,
            color: fg,
          ),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: compact ? 120 : 160),
            child: Text(
              alias,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
          const SizedBox(width: 2),
          IconButton(
            icon: Icon(
              PhosphorIconsRegular.diceFive,
              size: compact ? 16 : 18,
              color: fg,
            ),
            tooltip: 'Generar alias anónimo',
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(
              minWidth: compact ? 26 : 30,
              minHeight: compact ? 26 : 30,
            ),
            onPressed: _generateNewAlias,
          ),
        ],
      ),
    );
  }
}
