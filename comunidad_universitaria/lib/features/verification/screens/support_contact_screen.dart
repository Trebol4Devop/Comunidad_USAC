import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/support_config.dart';
import '../../../core/constants/zanate_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../utils/verification_validators.dart';

/// Canal alternativo cuando la verificación automática no está disponible:
/// abre el cliente de correo del usuario con un mensaje prellenado a soporte.
///
/// No persiste datos: el carné opcional solo viaja en el correo que el usuario
/// decide enviar desde su propia cuenta.
class SupportContactScreen extends StatefulWidget {
  final String? accountEmail;
  final Future<bool> Function(Uri uri)? launchEmail;
  final VoidCallback? onSelectAutomaticPath;

  const SupportContactScreen({
    super.key,
    this.accountEmail,
    this.launchEmail,
    this.onSelectAutomaticPath,
  });

  @override
  State<SupportContactScreen> createState() => _SupportContactScreenState();
}

class _SupportContactScreenState extends State<SupportContactScreen> {
  static const _reasons = <String>[
    'No puedo acceder con mi correo institucional',
    'Mi carné no fue reconocido',
    'Mi cuenta sigue sin verificar',
    'Otro problema',
  ];

  final _formKey = GlobalKey<FormState>();
  final _carneController = TextEditingController();
  final _detailController = TextEditingController();

  String _selectedReason = _reasons.first;
  bool _isSending = false;

  String? get _accountEmail {
    if (widget.accountEmail != null && widget.accountEmail!.trim().isNotEmpty) {
      return widget.accountEmail!.trim();
    }
    return SupabaseService.currentUser?.email?.trim();
  }

  @override
  void dispose() {
    _carneController.dispose();
    _detailController.dispose();
    super.dispose();
  }

  Uri _buildEmailUri() {
    final account = _accountEmail;
    final carne = _carneController.text.trim();
    final detail = _detailController.text.trim();

    final body = StringBuffer()
      ..writeln('Hola equipo de soporte:')
      ..writeln()
      ..writeln(
        'No pude completar la verificación automática en Comunidad USAC.',
      )
      ..writeln();

    if (account != null && account.isNotEmpty) {
      body.writeln('Correo de la cuenta: $account');
    }
    if (carne.isNotEmpty) {
      body.writeln('Carné USAC (opcional): $carne');
    }

    body
      ..writeln('Motivo: $_selectedReason')
      ..writeln();

    if (detail.isNotEmpty) {
      body
        ..writeln('Detalle:')
        ..writeln(detail)
        ..writeln();
    }

    body.writeln('Gracias.');

    final subject = '${SupportConfig.subjectPrefix}: $_selectedReason';
    return Uri.parse(
      'mailto:${SupportConfig.email}'
      '?subject=${Uri.encodeComponent(subject)}'
      '&body=${Uri.encodeComponent(body.toString())}',
    );
  }

  Future<bool> _launchEmail(Uri uri) async {
    final launcher = widget.launchEmail;
    if (launcher != null) return launcher(uri);

    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (opened) return true;
      return await launchUrl(uri, mode: LaunchMode.platformDefault);
    } catch (_) {
      return false;
    }
  }

  Future<void> _handleSend() async {
    if (_isSending) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSending = true);
    final opened = await _launchEmail(_buildEmailUri());

    if (!mounted) return;
    setState(() => _isSending = false);

    if (!opened) {
      await Clipboard.setData(const ClipboardData(text: SupportConfig.email));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo abrir tu app de correo. Copiamos la dirección: '
            '${SupportConfig.email}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Revisa y envía el correo desde tu app. El equipo de soporte te responderá.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = ZanateColors.textPrimary(isDark);
    final textSecondary = ZanateColors.textSecondary(isDark);
    final textMuted = ZanateColors.textMuted(isDark);
    final borderColor = ZanateColors.border(isDark);
    final focusColor = ZanateColors.focusBorder(isDark);
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: borderColor, width: 1.2),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: focusColor, width: 1.6),
    );
    final errorBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: isDark ? const Color(0xFFF87171) : const Color(0xFFEF4444),
        width: 1.2,
      ),
    );
    InputDecoration zanateInput({
      required String labelText,
      String? hintText,
      Widget? prefixIcon,
      bool alignLabelWithHint = false,
      String? counterText,
    }) {
      return InputDecoration(
        labelText: labelText,
        hintText: hintText,
        alignLabelWithHint: alignLabelWithHint,
        counterText: counterText,
        prefixIcon: prefixIcon,
        filled: true,
        fillColor: ZanateColors.surface(isDark),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        labelStyle: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
          color: textMuted,
        ),
        floatingLabelStyle: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: focusColor,
        ),
        hintStyle: TextStyle(
          fontSize: 13.5,
          color: textMuted,
        ),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: focusedBorder,
        errorBorder: errorBorder,
        focusedErrorBorder: errorBorder,
      );
    }

    return ColoredBox(
      color: ZanateColors.bg(isDark),
      child: AbsorbPointer(
        absorbing: _isSending,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Solicitud de soporte',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: ZanateColors.zanateEyeYellow,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Escríbenos si no tienes correo institucional o falló la verificación.',
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 18),

                if (_accountEmail != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: ZanateColors.surface(isDark),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          PhosphorIconsRegular.at,
                          size: 17,
                          color: textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Correo de la cuenta: ${_accountEmail!}',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                DropdownButtonFormField<String>(
                  initialValue: _selectedReason,
                  isExpanded: true,
                  itemHeight: null,
                  dropdownColor: ZanateColors.card(isDark),
                  borderRadius: BorderRadius.circular(14),
                  style: TextStyle(color: textPrimary, fontSize: 14),
                  decoration: zanateInput(
                    labelText: 'Motivo de contacto',
                    prefixIcon: Icon(
                      PhosphorIconsRegular.question,
                      color: textSecondary,
                    ),
                  ),
                  items: [
                    for (final reason in _reasons)
                      DropdownMenuItem(
                        value: reason,
                        child: Text(
                          reason,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedReason = value);
                  },
                ),
                const SizedBox(height: 14),

                TextFormField(
                  key: const Key('support_detail'),
                  controller: _detailController,
                  maxLength: 500,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(color: textPrimary),
                  decoration: zanateInput(
                    labelText: 'Detalle (opcional)',
                    hintText: 'Cuéntanos qué pasó o qué error viste.',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 6),

                TextFormField(
                  key: const Key('support_carne'),
                  controller: _carneController,
                  keyboardType: TextInputType.number,
                  maxLength: 9,
                  style: TextStyle(color: textPrimary),
                  decoration: zanateInput(
                    labelText: 'Carné USAC (opcional)',
                    hintText: 'Ej. 202012345',
                    prefixIcon: Icon(
                      PhosphorIconsRegular.identificationCard,
                      color: textSecondary,
                    ),
                    counterText: '',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    return VerificationValidators.validateCarne(value);
                  },
                ),
                const SizedBox(height: 18),

                ElevatedButton.icon(
                  key: const Key('support_send'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ZanateColors.ctaBg(isDark),
                    foregroundColor: ZanateColors.ctaFg(isDark),
                    elevation: 0,
                    minimumSize: const Size.fromHeight(52),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _isSending ? null : _handleSend,
                  icon: _isSending
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: ZanateColors.ctaFg(isDark),
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(PhosphorIconsBold.envelopeSimple, size: 19),
                  label: const Text(
                    'Enviar correo a soporte',
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
