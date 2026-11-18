import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
    final titleColor = isDark ? Colors.white : ZanateColors.zanateBlack;
    final subtleColor =
        isDark ? const Color(0xFF94A3B8) : ZanateColors.subtleText;
    final borderColor =
        isDark ? const Color(0xFF334155) : ZanateColors.subtleBorder;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: borderColor, width: 1.0),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
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
                      color: ZanateColors.zanateEyeYellow.withValues(
                        alpha: 0.22,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      PhosphorIconsBold.userCircle,
                      color: isDark
                          ? ZanateColors.zanateEyeYellow
                          : ZanateColors.zanateBlack,
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
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            letterSpacing: -0.2,
                            color: titleColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Aparece al publicar en el foro y compartir grupos',
                          style: TextStyle(fontSize: 12, color: subtleColor),
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
              const SizedBox(height: 18),
              InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Alias visible',
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: ZanateColors.mutedText,
                  ),
                  floatingLabelStyle: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF0F172A)
                      : ZanateColors.surfaceBg,
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
                  prefixIcon: Icon(
                    PhosphorIconsRegular.user,
                    size: 20,
                    color: subtleColor,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      PhosphorIconsRegular.diceFive,
                      size: 20,
                      color: titleColor,
                    ),
                    tooltip: 'Generar alias anónimo',
                    onPressed: _generateRandomAlias,
                  ),
                ),
                child: Text(
                  _alias,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: titleColor,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Nota: Tu seudónimo protege tu privacidad frente a otros estudiantes. Los alias son generados y verificados para evitar suplantación (Art. 12).',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11.5,
                  height: 1.35,
                  color: subtleColor,
                ),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: subtleColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark
                            ? ZanateColors.zanateEyeYellow
                            : ZanateColors.zanateBlack,
                        foregroundColor: isDark
                            ? ZanateColors.zanateBlack
                            : Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                      ),
                      onPressed: _save,
                      child: const Text(
                        'Guardar Alias',
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
