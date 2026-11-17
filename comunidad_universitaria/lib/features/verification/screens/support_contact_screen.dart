import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return AbsorbPointer(
      absorbing: _isSending,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.support_agent,
                      color: ZanateColors.zanateAccent,
                      size: 26,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Contactar con soporte',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Si la verificación automática no funcionó o no tienes correo institucional, escríbenos y revisaremos tu caso.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? Colors.grey.shade300
                                  : Colors.grey.shade700,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (_accountEmail != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.alternate_email, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Correo de la cuenta: ${_accountEmail!}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              DropdownButtonFormField<String>(
                initialValue: _selectedReason,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Motivo de contacto',
                  prefixIcon: Icon(Icons.help_outline),
                  border: OutlineInputBorder(),
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
                decoration: const InputDecoration(
                  labelText: 'Detalle (opcional)',
                  hintText: 'Cuéntanos qué pasó o qué mensaje de error viste.',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 6),

              TextFormField(
                key: const Key('support_carne'),
                controller: _carneController,
                keyboardType: TextInputType.number,
                maxLength: 9,
                decoration: const InputDecoration(
                  labelText: 'Carné USAC (opcional)',
                  hintText: 'Ej. 202012345',
                  prefixIcon: Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(),
                  counterText: '',
                  helperText:
                      'Solo se incluye en el correo que tú envíes. La app no lo guarda.',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return null;
                  return VerificationValidators.validateCarne(value);
                },
              ),
              const SizedBox(height: 16),

              ElevatedButton.icon(
                key: const Key('support_send'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ZanateColors.zanateAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
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
                    : const Icon(Icons.mail_outline, size: 20),
                label: const Text(
                  'Enviar correo a soporte',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 10),

              Text(
                'Se abrirá tu aplicación de correo con el mensaje preparado. '
                'La app no almacena el contenido ni el carné.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),

              if (widget.onSelectAutomaticPath != null) ...[
                const SizedBox(height: 10),
                Center(
                  child: TextButton.icon(
                    onPressed: widget.onSelectAutomaticPath,
                    icon: const Icon(Icons.verified_user_outlined, size: 18),
                    label: const Text(
                      'Volver a la verificación automática',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
