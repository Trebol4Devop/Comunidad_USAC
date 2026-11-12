import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../core/constants/zanate_colors.dart';
import '../../../core/constants/anonymous_aliases.dart';
import '../../../core/services/local_storage_service.dart';

class AliasModal extends StatefulWidget {
  final String currentAlias;
  final Function(String newAlias) onAliasSaved;

  const AliasModal({
    super.key,
    required this.currentAlias,
    required this.onAliasSaved,
  });

  static Future<void> show(
    BuildContext context, {
    required String currentAlias,
    required Function(String) onSaved,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) =>
          AliasModal(currentAlias: currentAlias, onAliasSaved: onSaved),
    );
  }

  @override
  State<AliasModal> createState() => _AliasModalState();
}

class _AliasModalState extends State<AliasModal> {
  late String _alias;

  @override
  void initState() {
    super.initState();
    _alias = widget.currentAlias;
  }

  void _generateRandomAlias() {
    setState(() {
      _alias = AnonymousAliasGenerator.generate();
    });
  }

  Future<void> _save() async {
    final text = _alias.trim();
    if (text.isEmpty) return;

    await LocalStorageService.saveAlias(text);
    widget.onAliasSaved(text);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? const Color(0xFF334155) : ZanateColors.subtleBorder,
          width: 0.8,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ZanateColors.zanateAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      PhosphorIconsBold.userCircle,
                      color: ZanateColors.zanateAccent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tu Seudónimo Estudiantil',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            letterSpacing: -0.2,
                            color: isDark ? Colors.white : ZanateColors.zanateDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Identidad comunitaria en foros y grupos',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Alias visible',
                  prefixIcon: const Icon(PhosphorIconsRegular.user, size: 20),
                  suffixIcon: IconButton(
                    icon: const Icon(PhosphorIconsRegular.diceFive, size: 20),
                    tooltip: 'Generar alias anónimo',
                    onPressed: _generateRandomAlias,
                  ),
                ),
                child: Text(
                  _alias,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Nota: Tu seudónimo protege tu privacidad frente a otros estudiantes. Los alias son generados y verificados para evitar suplantación (Art. 12).',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ZanateColors.zanateAccent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      onPressed: _save,
                      child: const Text('Guardar Alias', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
