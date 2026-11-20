import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../core/constants/zanate_colors.dart';
import '../../../core/services/marketplace_service.dart';
import '../../../core/utils/responsive.dart';
import '../marketplace_theme.dart';

class SponsorRequestDialog extends StatefulWidget {
  final String? planId;
  final String? planName;

  const SponsorRequestDialog({
    super.key,
    this.planId,
    this.planName,
  });

  static Future<void> show(
    BuildContext context, {
    String? planId,
    String? planName,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (ctx) => SponsorRequestDialog(
          planId: planId,
          planName: planName,
        ),
      ),
    );
  }

  @override
  State<SponsorRequestDialog> createState() => _SponsorRequestDialogState();
}

class _SponsorRequestDialogState extends State<SponsorRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  final _brandController = TextEditingController();
  final _contactController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _proposalController = TextEditingController();

  String _placement = 'Primera Plana - Marketplace';
  String? _selectedPlanId;
  List<MarketplacePlan> _plans = [];
  bool _isLoadingPlans = true;

  bool _isSubmitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _selectedPlanId = widget.planId;
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    try {
      final fetched = await MarketplaceService.fetchPlans();
      if (!mounted) return;
      setState(() {
        _plans = fetched;
        _isLoadingPlans = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingPlans = false);
    }
  }

  @override
  void dispose() {
    _brandController.dispose();
    _contactController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _proposalController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    var success = false;
    try {
      success = await MarketplaceService.requestSponsorship(
        brandName: _brandController.text.trim(),
        contactName: _contactController.text.trim(),
        contactPhone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        proposalDetails: _proposalController.text.trim(),
        expectedPlacement: _placement,
        planId: (_selectedPlanId == null || _selectedPlanId == 'none')
            ? null
            : _selectedPlanId,
      );
    } catch (_) {
      success = false;
    }

    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '¡Solicitud enviada con éxito! El equipo se comunicará contigo por WhatsApp.',
          ),
          backgroundColor: ZanateColors.zanateBlack,
        ),
      );
    } else {
      setState(() {
        _isSubmitting = false;
        _submitError =
            'No se pudo enviar la solicitud. Tus datos siguen en el formulario; inténtalo de nuevo.';
      });
    }
  }

  InputDecoration _zanateInput(
    bool isDark, {
    required String labelText,
    String? hintText,
  }) {
    final borderColor = ZanateColors.border(isDark);
    final focusColor = ZanateColors.focusBorder(isDark);
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      filled: true,
      fillColor: ZanateColors.surface(isDark),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
        borderSide: BorderSide(color: focusColor, width: 1.6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMobile = Responsive.isMobile(context);
    final scaffoldBg = ZanateColors.bg(isDark);
    final borderColor = ZanateColors.border(isDark);
    final primaryText = ZanateColors.textPrimary(isDark);
    final secondaryText = ZanateColors.textMuted(isDark);

    Widget content = Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 18 : 28,
          vertical: isMobile ? 16 : 24,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Subheader compacto
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: ZanateColors.zanateEyeYellow.withValues(alpha: 0.24),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: PhosphorIcon(
                          PhosphorIconsBold.sparkle,
                          color: isDark
                              ? ZanateColors.zanateEyeYellow
                              : ZanateColors.zanateBlack,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.planName != null
                                ? 'Solicitud para Plan ${widget.planName}'
                                : 'Anúnciate en primera plana con video y mayor alcance',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: secondaryText,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 44,
                            height: 4,
                            decoration: BoxDecoration(
                              color: ZanateColors.zanateEyeYellow,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                TextFormField(
                  controller: _brandController,
                  decoration: _zanateInput(
                    isDark,
                    labelText: 'Nombre del Emprendimiento, Marca o Negocio',
                    hintText: 'Ej. Librería Central / Pastelería Universitaria',
                  ),
                  validator: (val) => (val == null || val.trim().isEmpty)
                      ? 'Ingresa el nombre del negocio'
                      : null,
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _contactController,
                        decoration: _zanateInput(
                          isDark,
                          labelText: 'Nombre del Encargado',
                          hintText: 'Tu nombre',
                        ),
                        validator: (val) => (val == null || val.trim().isEmpty)
                            ? 'Ingresa tu nombre'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: _zanateInput(
                          isDark,
                          labelText: 'WhatsApp',
                          hintText: '55551234',
                        ),
                        validator: (val) =>
                            val == null ||
                                !RegExp(r'^\d{8}$').hasMatch(val.trim())
                            ? 'Ingresa un número de WhatsApp de 8 dígitos.'
                            : null,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _zanateInput(
                    isDark,
                    labelText: 'Correo Electrónico de Contacto',
                    hintText: 'contacto@ejemplo.com',
                  ),
                ),

                const SizedBox(height: 12),

                // Plan Deseado Selector (leído de la BD)
                if (!_isLoadingPlans && _plans.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    key: ValueKey(_selectedPlanId),
                    initialValue: _selectedPlanId,
                    isExpanded: true,
                    itemHeight: null,
                    dropdownColor: ZanateColors.card(isDark),
                    style: TextStyle(color: primaryText, fontSize: 14),
                    decoration: _zanateInput(
                      isDark,
                      labelText: 'Plan Deseado',
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: 'none',
                        child: Text(
                          'Solo patrocinio (sin plan mensual)',
                        ),
                      ),
                      ..._plans.map(
                        (p) => DropdownMenuItem<String>(
                          value: p.id,
                          child: Text(
                            '${p.name} (${p.formattedPrice}${p.priceMonthly > 0 ? "/mes" : ""})',
                          ),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() => _selectedPlanId = val);
                    },
                  ),
                  const SizedBox(height: 12),
                ],

                DropdownButtonFormField<String>(
                  initialValue: _placement,
                  isExpanded: true,
                  itemHeight: null,
                  dropdownColor: ZanateColors.card(isDark),
                  style: TextStyle(color: primaryText, fontSize: 14),
                  decoration: _zanateInput(
                    isDark,
                    labelText: 'Espacio Deseado',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Primera Plana - Marketplace',
                      child: Text(
                        'Primera Plana — Marketplace con Video y Fotos',
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'Banner en Foro Universitario',
                      child: Text(
                        'Banner Destacado en Foro Universitario',
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'Todos los Espacios',
                      child: Text(
                        'Presencia Integral (Marketplace + Foro)',
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _placement = val);
                  },
                ),

                const SizedBox(height: 12),

                TextFormField(
                  controller: _proposalController,
                  maxLines: 3,
                  decoration: _zanateInput(
                    isDark,
                    labelText:
                        'Detalle de la propuesta o productos a promocionar',
                    hintText:
                        'Describe brevemente tus productos y el horario o ubicación de entrega...',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().length < 10) {
                      return 'Describe tu propuesta con al menos 10 caracteres.';
                    }
                    if (val.trim().length > 500) {
                      return 'El detalle no debe exceder 500 caracteres.';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 14),

                // Nota obligatoria
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ZanateColors.zanateEyeYellow.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: ZanateColors.zanateEyeYellow.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PhosphorIcon(
                        PhosphorIconsRegular.info,
                        size: 17,
                        color: isDark
                            ? ZanateColors.zanateEyeYellow
                            : ZanateColors.zanateBlack,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'La plataforma no procesa pagos ni cobra comisiones por venta. '
                          'La coordinación del plan se realiza con el equipo por WhatsApp.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark
                                ? const Color(0xFFFDE68A)
                                : ZanateColors.zanateBlack,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (_submitError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _submitError!,
                    style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
                  ),
                ],

                const SizedBox(height: 20),

                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: secondaryText,
                        ),
                        onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
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
                            horizontal: 20,
                            vertical: 13,
                          ),
                        ),
                        onPressed: _isSubmitting ? null : _submit,
                        child: _isSubmitting
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: isDark
                                      ? ZanateColors.zanateBlack
                                      : Colors.white,
                                ),
                              )
                            : const Text(
                                'Enviar Solicitud',
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

    return MarketplaceTheme.wrap(
      context,
      Scaffold(
        backgroundColor: scaffoldBg,
        appBar: AppBar(
          backgroundColor: scaffoldBg,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            tooltip: 'Volver',
            icon: PhosphorIcon(
              PhosphorIconsBold.caretLeft,
              color: primaryText,
              size: 22,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'Solicitar Espacio de Patrocinador',
            style: GoogleFonts.outfit(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: primaryText,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(height: 1, color: borderColor),
          ),
        ),
        body: SafeArea(child: content),
      ),
    );
  }
}
