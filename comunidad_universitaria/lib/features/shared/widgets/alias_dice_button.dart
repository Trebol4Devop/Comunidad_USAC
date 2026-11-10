import 'package:flutter/material.dart';
import '../../../core/constants/anonymous_aliases.dart';

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

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person_outline,
            size: compact ? 14 : 16,
            color: theme.colorScheme.primary,
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
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
          const SizedBox(width: 2),
          IconButton(
            icon: Icon(
              Icons.casino_outlined,
              size: compact ? 16 : 18,
              color: theme.colorScheme.primary,
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
