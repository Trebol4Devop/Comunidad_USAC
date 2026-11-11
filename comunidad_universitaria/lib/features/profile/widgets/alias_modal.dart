import 'package:flutter/material.dart';
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.badge_outlined,
                      color: theme.colorScheme.primary,
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
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Aparece al publicar en el foro y compartir grupos',
                          style: theme.textTheme.bodySmall,
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
                  prefixIcon: const Icon(Icons.person_outline, size: 20),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.casino_outlined, size: 20),
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
                      onPressed: _save,
                      child: const Text('Guardar Alias'),
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
