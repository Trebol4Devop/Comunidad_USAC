import 'package:flutter/material.dart';
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

    return PopScope(
      canPop: !_isSubmitting,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.gavel_rounded,
                        color: Color(0xFF2563EB),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Términos de Uso y Reglas de la Comunidad',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Versión ${ProfileService.termsVersion}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Scrollable Terms Content
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0),
                      ),
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
                              'Tu CUI y número de carné estudiantil se almacenan exclusivamente como una huella HMAC irreversible (cui_hash / carne_hash), garantizando que nunca se guarden en texto plano ni puedan ser leídos por terceros o administradores.',
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
                  value: _accepted,
                  onChanged: _isSubmitting
                      ? null
                      : (val) {
                          setState(() => _accepted = val ?? false);
                        },
                  title: const Text(
                    'He leído y acepto los Términos y las Reglas de la Comunidad',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
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
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.of(context).pop(false),
                        child: const Text('Cancelar'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
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
                            : const Text('Aceptar y continuar'),
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
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 12.5,
        color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8),
      ),
    );
  }

  Widget _buildSectionBody(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11.5,
        height: 1.4,
        color: isDark ? Colors.grey.shade300 : const Color(0xFF334155),
      ),
    );
  }
}
