import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../core/constants/zanate_colors.dart';

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
    final isDark = theme.brightness == Brightness.dark;

    final titleColor = ZanateColors.textPrimary(isDark);
    final subtleText = ZanateColors.textSecondary(isDark);
    final borderColor = ZanateColors.border(isDark);

    return Dialog(
      backgroundColor: ZanateColors.card(isDark),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: borderColor, width: 1.0),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      PhosphorIconsBold.flag,
                      color: Color(0xFFEF4444),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            letterSpacing: -0.2,
                            color: titleColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle,
                          style: TextStyle(fontSize: 12.5, color: subtleText),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: ZanateColors.zanateEyeYellow,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Selecciona el motivo del reporte:',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: titleColor,
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
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 7,
                          horizontal: 4,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected
                                  ? PhosphorIconsFill.radioButton
                                  : PhosphorIconsRegular.circle,
                              size: 18,
                              color: isSelected
                                  ? titleColor
                                  : ZanateColors.textMuted(isDark),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                opt,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: titleColor,
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
                const SizedBox(height: 10),
                TextField(
                  controller: _customReasonController,
                  maxLength: 120,
                  style: TextStyle(fontSize: 13.5, color: titleColor),
                  decoration: InputDecoration(
                    hintText: 'Explica brevemente la razón...',
                    hintStyle: const TextStyle(
                      color: ZanateColors.hintText,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: ZanateColors.surface(isDark),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: borderColor, width: 1.2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: borderColor, width: 1.2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: titleColor, width: 1.6),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: subtleText,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                      ),
                      onPressed: _submit,
                      child: const Text(
                        'Enviar Reporte',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
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
