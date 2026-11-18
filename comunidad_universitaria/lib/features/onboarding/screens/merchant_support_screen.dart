import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/support_config.dart';
import '../../../core/constants/categories.dart';
import '../../../core/services/supabase_service.dart';
import '../../verification/utils/verification_validators.dart';

/// Flujo de alta de comerciante: envía los datos del negocio a soporte por correo.
///
/// No sube fotos, no crea solicitudes en Supabase y no modifica el estado de la
/// cuenta. Soporte revisa el correo y da de alta el comercio manualmente.
class MerchantSupportScreen extends StatefulWidget {
  final String? accountEmail;
  final String? accountId;
  final Future<bool> Function(Uri uri)? launchEmail;

  const MerchantSupportScreen({
    super.key,
    this.accountEmail,
    this.accountId,
    this.launchEmail,
  });

  @override
  State<MerchantSupportScreen> createState() => _MerchantSupportScreenState();
}

class _MerchantSupportScreenState extends State<MerchantSupportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();

  late final List<MarketplaceCategoryOption> _categories;
  late String _selectedCategoryId;

  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _categories = USACConstants.marketplaceCategories
        .where((category) => category.id != 'todos')
        .toList(growable: false);
    _selectedCategoryId = _categories.isNotEmpty ? _categories.first.id : '';
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String? get _accountEmail {
    if (widget.accountEmail != null && widget.accountEmail!.trim().isNotEmpty) {
      return widget.accountEmail!.trim();
    }
    return SupabaseService.currentUser?.email?.trim();
  }

  String? get _accountId {
    if (widget.accountId != null && widget.accountId!.trim().isNotEmpty) {
      return widget.accountId!.trim();
    }
    return SupabaseService.currentUserId;
  }

  MarketplaceCategoryOption? get _selectedCategory {
    for (final category in _categories) {
      if (category.id == _selectedCategoryId) return category;
    }
    return null;
  }

  Uri _buildEmailUri() {
    final businessName = _businessNameController.text.trim();
    final phone =
        VerificationValidators.normalizePhone(_phoneController.text);
    final location = _locationController.text.trim();
    final description = _descriptionController.text.trim();
    final accountEmail = _accountEmail;
    final accountId = _accountId;
    final category = _selectedCategory?.label ?? _selectedCategoryId;

    final body = StringBuffer()
      ..writeln('Hola equipo de soporte:')
      ..writeln()
      ..writeln('Quiero registrar mi comercio en Zanate.')
      ..writeln();

    if (accountEmail != null && accountEmail.isNotEmpty) {
      body.writeln('Correo de la cuenta: $accountEmail');
    }
    if (accountId != null && accountId.isNotEmpty) {
      body.writeln('ID de cuenta: $accountId');
    }

    body
      ..writeln('Nombre del negocio: $businessName')
      ..writeln('Teléfono / WhatsApp: $phone')
      ..writeln('Ubicación en el campus: $location')
      ..writeln('Categoría: $category');

    if (description.isNotEmpty) {
      body
        ..writeln('Descripción:')
        ..writeln(description);
    }

    body.writeln();
    body.writeln('Gracias.');

    final subject = '${SupportConfig.merchantSubjectPrefix}: $businessName';
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
          'Revisa y envía el correo desde tu app. Soporte te contactará para completar el alta.',
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
      String? helperText,
      Widget? prefixIcon,
      bool alignLabelWithHint = false,
      String? counterText,
    }) {
      return InputDecoration(
        labelText: labelText,
        hintText: hintText,
        helperText: helperText,
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
        helperStyle: const TextStyle(
          fontSize: 12,
          color: Color(0xFF64748B),
        ),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: focusedBorder,
        errorBorder: errorBorder,
        focusedErrorBorder: errorBorder,
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      PhosphorIconsBold.caretLeft,
                      size: 22,
                      color: zanateBlack,
                    ),
                    tooltip: 'Regresar',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      'Contactar con soporte',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: zanateBlack,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: AbsorbPointer(
                absorbing: _isSending,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 580),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Registro de comercio',
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
                              'Registra tu comercio en Zanate. Enviaremos tus datos a soporte para que revisen tu caso y te den de alta.',
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
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                  ),
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

                            TextFormField(
                              key: const Key('merchant_business_name'),
                              controller: _businessNameController,
                              textCapitalization: TextCapitalization.words,
                              decoration: zanateInput(
                                labelText: 'Nombre del negocio *',
                                hintText: 'Ej. Cafetería El Sancarlista',
                                prefixIcon: const Icon(
                                  PhosphorIconsRegular.storefront,
                                  color: subtleText,
                                ),
                              ),
                              validator: (value) {
                                final clean = value?.trim() ?? '';
                                if (clean.length < 2 || clean.length > 80) {
                                  return 'El nombre debe tener entre 2 y 80 caracteres.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            TextFormField(
                              key: const Key('merchant_phone'),
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: zanateInput(
                                labelText: 'Teléfono / WhatsApp *',
                                hintText: 'Ej. +502 2345 6789 o 23456789',
                                prefixIcon: const Icon(
                                  PhosphorIconsRegular.phone,
                                  color: subtleText,
                                ),
                              ),
                              validator: VerificationValidators.validatePhone,
                            ),
                            const SizedBox(height: 14),

                            TextFormField(
                              key: const Key('merchant_location'),
                              controller: _locationController,
                              maxLength: 160,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: zanateInput(
                                labelText: 'Ubicación en el campus *',
                                hintText:
                                    'Ej. Frente al edificio T-3, pasillo principal',
                                prefixIcon: const Icon(
                                  PhosphorIconsRegular.mapPin,
                                  color: subtleText,
                                ),
                                counterText: '',
                              ),
                              validator: (value) {
                                final clean = value?.trim() ?? '';
                                if (clean.isEmpty) {
                                  return 'Indica dónde está tu puesto o local.';
                                }
                                if (clean.length > 160) {
                                  return 'La ubicación no debe superar 160 caracteres.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            DropdownButtonFormField<String>(
                              key: const Key('merchant_category'),
                              initialValue: _selectedCategoryId.isEmpty
                                  ? null
                                  : _selectedCategoryId,
                              isExpanded: true,
                              dropdownColor: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              decoration: zanateInput(
                                labelText: 'Categoría *',
                                prefixIcon: const Icon(
                                  PhosphorIconsRegular.tag,
                                  color: subtleText,
                                ),
                              ),
                              items: [
                                for (final category in _categories)
                                  DropdownMenuItem(
                                    value: category.id,
                                    child: Text(
                                      category.label,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _selectedCategoryId = value);
                              },
                              validator: (value) =>
                                  (value == null || value.isEmpty)
                                      ? 'Selecciona una categoría.'
                                      : null,
                            ),
                            const SizedBox(height: 14),

                            TextFormField(
                              key: const Key('merchant_description'),
                              controller: _descriptionController,
                              maxLength: 300,
                              maxLines: 4,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: zanateInput(
                                labelText: 'Descripción (opcional)',
                                hintText:
                                    'Qué vendes, horario aproximado o cualquier detalle útil.',
                                alignLabelWithHint: true,
                              ),
                            ),
                            const SizedBox(height: 18),

                            ElevatedButton.icon(
                              key: const Key('merchant_send'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: zanateBlack,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                minimumSize: const Size.fromHeight(52),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
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
                                  : const Icon(
                                      PhosphorIconsBold.envelopeSimple,
                                      size: 19,
                                    ),
                              label: const Text(
                                'Enviar solicitud a soporte',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
