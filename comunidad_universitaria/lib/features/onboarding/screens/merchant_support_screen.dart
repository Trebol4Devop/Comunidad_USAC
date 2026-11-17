import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/support_config.dart';
import '../../../core/constants/categories.dart';
import '../../../core/constants/zanate_colors.dart';
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
      ..writeln('Quiero registrar mi comercio en Comunidad USAC.')
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Contactar con soporte',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Regresar',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: _isSending,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.storefront_outlined,
                              color: ZanateColors.zanateAccent,
                              size: 26,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Registra tu comercio en Comunidad USAC. Enviaremos tus datos a soporte para que revisen tu caso y te den de alta.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  height: 1.35,
                                  color: isDark
                                      ? Colors.grey.shade300
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

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
                                  'Cuenta: ${_accountEmail!}',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      TextFormField(
                        key: const Key('merchant_business_name'),
                        controller: _businessNameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Nombre del negocio *',
                          hintText: 'Ej. Cafetería El Sancarlista',
                          prefixIcon: Icon(Icons.store_outlined),
                          border: OutlineInputBorder(),
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
                        decoration: const InputDecoration(
                          labelText: 'Teléfono / WhatsApp *',
                          hintText: 'Ej. +502 2345 6789 o 23456789',
                          prefixIcon: Icon(Icons.phone_outlined),
                          border: OutlineInputBorder(),
                          helperText:
                              'Se usa para que soporte pueda contactarte; no se publica.',
                        ),
                        validator: VerificationValidators.validatePhone,
                      ),
                      const SizedBox(height: 14),

                      TextFormField(
                        key: const Key('merchant_location'),
                        controller: _locationController,
                        maxLength: 160,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Ubicación en el campus *',
                          hintText: 'Ej. Frente al edificio T-3, pasillo principal',
                          prefixIcon: Icon(Icons.place_outlined),
                          border: OutlineInputBorder(),
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
                      const SizedBox(height: 6),

                      DropdownButtonFormField<String>(
                        key: const Key('merchant_category'),
                        initialValue: _selectedCategoryId.isEmpty
                            ? null
                            : _selectedCategoryId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Categoría *',
                          prefixIcon: Icon(Icons.category_outlined),
                          border: OutlineInputBorder(),
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
                        decoration: const InputDecoration(
                          labelText: 'Descripción (opcional)',
                          hintText:
                              'Qué vendes, horario aproximado o cualquier detalle útil.',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),

                      ElevatedButton.icon(
                        key: const Key('merchant_send'),
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
                          'Enviar solicitud a soporte',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      Text(
                        'Se abrirá tu aplicación de correo con los datos preparados. '
                        'La app no almacena esta información; solo se envía desde tu cuenta.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
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
    );
  }
}
