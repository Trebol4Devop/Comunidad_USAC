import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/support_config.dart';
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
    const zanateBlack = Color(0xFF0B0D10);
    const zanateEyeYellow = Color(0xFFF5C518);
    const subtleText = Color(0xFF475569);
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: zanateBlack, width: 1.6),
    );
    final errorBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
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
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        labelStyle: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
          color: Color(0xFF64748B),
        ),
        floatingLabelStyle: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: zanateBlack,
        ),
        hintStyle: const TextStyle(
          fontSize: 13.5,
          color: Color(0xFF94A3B8),
        ),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: focusedBorder,
        errorBorder: errorBorder,
        focusedErrorBorder: errorBorder,
      );
    }

    return ColoredBox(
      color: Colors.white,
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
                    color: zanateBlack,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: zanateEyeYellow,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Escríbenos si no tienes correo institucional o falló la verificación.',
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    color: subtleText,
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
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          PhosphorIconsRegular.at,
                          size: 17,
                          color: subtleText,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Correo de la cuenta: ${_accountEmail!}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: zanateBlack,
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
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  decoration: zanateInput(
                    labelText: 'Motivo de contacto',
                    prefixIcon: const Icon(
                      PhosphorIconsRegular.question,
                      color: subtleText,
                    ),
                  ),
                  items: [
                    for (final reason in _reasons)
                      DropdownMenuItem(
                        value: reason,
                        child: Text(
                          reason,
                          overflow: TextOverflow.ellipsis,
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
                  decoration: zanateInput(
                    labelText: 'Carné USAC (opcional)',
                    hintText: 'Ej. 202012345',
                    prefixIcon: const Icon(
                      PhosphorIconsRegular.identificationCard,
                      color: subtleText,
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
                    backgroundColor: zanateBlack,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size.fromHeight(52),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _isSending ? null : _handleSend,
                  icon: _isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
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
