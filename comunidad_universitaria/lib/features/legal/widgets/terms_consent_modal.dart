import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../core/constants/zanate_colors.dart';
import '../../../core/services/profile_service.dart';

class TermsConsentModal extends StatefulWidget {
  final Future<void> Function()? onAcceptTerms;

  const TermsConsentModal({super.key, this.onAcceptTerms});

  /// Muestra el modal de consentimiento obligatorio de términos.
  /// No es descartable haciendo tap fuera de la barrera (barrierDismissible: false).
  static Future<bool> show(
    BuildContext context, {
    Future<void> Function()? onAcceptTerms,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => TermsConsentModal(onAcceptTerms: onAcceptTerms),
    );
    return result ?? false;
  }

  @override
  State<TermsConsentModal> createState() => _TermsConsentModalState();
}

class _TermsConsentModalState extends State<TermsConsentModal> {
  bool _accepted = false;
  bool _isSubmitting = false;

  Future<void> _handleAccept() async {
    if (!_accepted || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      if (widget.onAcceptTerms != null) {
        await widget.onAcceptTerms!();
      } else {
        await ProfileService.acceptTerms();
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al aceptar los términos: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
        Navigator.of(context).pop(false);
      }
    }
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

    return PopScope(
      canPop: !_isSubmitting,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: borderColor, width: 1.0),
        ),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
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
                        PhosphorIconsRegular.scales,
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
                            'Términos de Uso y Reglas de la Comunidad',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                              color: titleColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Versión ${ProfileService.termsVersion}',
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
                const SizedBox(height: 14),

                // Scrollable Terms Content
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A)
                          : ZanateColors.surfaceBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor, width: 1.2),
                    ),
                    child: Scrollbar(
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionTitle(
                              '1. Transmisiones y Moderación (Art. 3)',
                              isDark,
                            ),
                            const SizedBox(height: 4),
                            _buildSectionBody(
                              'El proveedor no edita el contenido de las transmisiones ajenas; únicamente actúa conforme a directrices de moderación pudiendo aprobar u ocultar publicaciones que vulneren los reglamentos comunitarios o la legislación aplicable.',
                              isDark,
                            ),
                            const SizedBox(height: 12),

                            _buildSectionTitle(
                              '2. Conductas Prohibidas (Art. 12, 13, 14, 16)',
                              isDark,
                            ),
                            const SizedBox(height: 4),
                            _buildSectionBody(
                              'Queda terminantemente prohibida la suplantación de identidad (Art. 12), el acceso ilícito o piratería digital (Art. 13/16), así como cualquier forma de fraude, amenazas, hostigamiento y doxxing o revelación no autorizada de datos privados (Art. 14).',
                              isDark,
                            ),
                            const SizedBox(height: 12),

                            _buildSectionTitle(
                              '3. Retención de Evidencia y Legal Hold (Art. 20, 21)',
                              isDark,
                            ),
                            const SizedBox(height: 4),
                            _buildSectionBody(
                              'Se contempla la retención de evidencia digital hasta por 90 días ante incidentes de seguridad y la activación de congelamiento preventivo (is_legal_hold) en caso de requerimientos judiciales o administrativos debidamente fundados.',
                              isDark,
                            ),
                            const SizedBox(height: 12),

                            _buildSectionTitle(
                              '4. Privacidad Criptográfica de Identidad',
                              isDark,
                            ),
                            const SizedBox(height: 4),
                            _buildSectionBody(
                              'Tu número de carné estudiantil se almacena exclusivamente como una huella HMAC irreversible (carne_hash), garantizando que nunca se guarde en texto plano ni pueda ser leído por terceros o administradores.',
                              isDark,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Checkbox
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: ZanateColors.zanateBlack,
                  value: _accepted,
                  onChanged: _isSubmitting
                      ? null
                      : (val) {
                          setState(() => _accepted = val ?? false);
                        },
                  title: Text(
                    'He leído y acepto los Términos y las Reglas de la Comunidad',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                    ),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                ),

                const SizedBox(height: 10),

                // Buttons
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
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
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.of(context).pop(false),
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
                        onPressed: (_accepted && !_isSubmitting)
                            ? _handleAccept
                            : null,
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Aceptar y continuar',
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
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontWeight: FontWeight.w700,
        fontSize: 13,
        color: isDark ? Colors.white : ZanateColors.zanateBlack,
      ),
    );
  }

  Widget _buildSectionBody(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        height: 1.45,
        color: isDark ? Colors.grey.shade300 : ZanateColors.subtleText,
      ),
    );
  }
}
