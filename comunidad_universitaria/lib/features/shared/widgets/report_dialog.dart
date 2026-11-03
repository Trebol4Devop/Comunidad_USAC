import 'package:flutter/material.dart';

class ReportDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<String> reasonOptions;
  final Function(String reason) onReportSubmitted;

  static const List<String> defaultReasonOptions = [
    'Acoso / Difamación',
    'Spam / Publicidad engañosa',
    'Venta ilegal / Servicios prohibidos',
    'Información personal expuesta',
    'Contenido inapropiado / Ofensivo',
    'Otro motivo',
  ];

  const ReportDialog({
    super.key,
    required this.title,
    required this.subtitle,
    this.reasonOptions = defaultReasonOptions,
    required this.onReportSubmitted,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String subtitle,
    List<String>? reasonOptions,
    required Function(String) onSubmitted,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => ReportDialog(
        title: title,
        subtitle: subtitle,
        reasonOptions: reasonOptions ?? defaultReasonOptions,
        onReportSubmitted: onSubmitted,
      ),
    );
  }

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  String? _selectedReason;
  final TextEditingController _customReasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedReason = widget.reasonOptions.first;
  }

  @override
  void dispose() {
    _customReasonController.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _selectedReason == 'Otro motivo'
        ? _customReasonController.text.trim()
        : _selectedReason ?? 'Reporte comunitario';

    if (reason.isEmpty) return;

    widget.onReportSubmitted(reason);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.flag_outlined,
                    color: theme.colorScheme.onSurface,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Selecciona el motivo del reporte:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.reasonOptions.length,
                  itemBuilder: (ctx, i) {
                    final opt = widget.reasonOptions[i];
                    final isSelected = _selectedReason == opt;
                    return InkWell(
                      onTap: () => setState(() => _selectedReason = opt),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              size: 18,
                              color: isSelected
                                  ? theme.colorScheme.onSurface
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                opt,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (_selectedReason == 'Otro motivo') ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _customReasonController,
                  maxLength: 120,
                  decoration: InputDecoration(
                    hintText: 'Explica brevemente la razón...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide: BorderSide(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide: BorderSide(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
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
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.onSurface,
                        foregroundColor: theme.colorScheme.surface,
                        elevation: 0,
                        shape: const RoundedRectangleBorder(),
                      ),
                      onPressed: _submit,
                      child: const Text('Enviar Reporte'),
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
