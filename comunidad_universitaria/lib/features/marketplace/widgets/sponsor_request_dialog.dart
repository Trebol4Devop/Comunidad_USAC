import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../core/constants/zanate_colors.dart';
import '../../../core/services/marketplace_service.dart';
import '../../../core/utils/responsive.dart';

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
    if (Responsive.isMobile(context)) {
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => SponsorRequestDialog(
          planId: planId,
          planName: planName,
        ),
      );
    } else {
      return showDialog(
        context: context,
        builder: (ctx) => SponsorRequestDialog(
          planId: planId,
          planName: planName,
        ),
      );
    }
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
          backgroundColor: Color(0xFF004B87),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = Responsive.isMobile(context);
    final maxHeight =
        MediaQuery.of(context).size.height * (isMobile ? 0.90 : 0.85);

    Widget content = Form(
      key: _formKey,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
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
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      PhosphorIconsBold.sparkle,
                      color: Color(0xFFD97706),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Solicitar Espacio de Patrocinador',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.planName != null
                              ? 'Solicitud para Plan ${widget.planName}'
                              : 'Anúnciate en primera plana con video y mayor alcance',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFD97706),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const Divider(height: 24),

              TextFormField(
                controller: _brandController,
                decoration: const InputDecoration(
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
                      decoration: const InputDecoration(
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
                      decoration: const InputDecoration(
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
                decoration: const InputDecoration(
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
                  decoration: const InputDecoration(
                    labelText: 'Plan Deseado',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: 'none',
                      child: Text(
                        'Solo patrocinio (sin plan mensual)',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ..._plans.map(
                      (p) => DropdownMenuItem<String>(
                        value: p.id,
                        child: Text(
                          '${p.name} (${p.formattedPrice}${p.priceMonthly > 0 ? "/mes" : ""})',
                          overflow: TextOverflow.ellipsis,
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
                decoration: const InputDecoration(
                  labelText: 'Espacio Deseado',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Primera Plana - Marketplace',
                    child: Text(
                      'Primera Plana — Marketplace con Video y Fotos',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Banner en Foro Universitario',
                    child: Text(
                      'Banner Destacado en Foro Universitario',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Todos los Espacios',
                    child: Text(
                      'Presencia Integral (Marketplace + Foro)',
                      overflow: TextOverflow.ellipsis,
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
                decoration: const InputDecoration(
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

              const SizedBox(height: 12),

              // Nota obligatoria
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ZanateColors.zanateAccent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: ZanateColors.zanateAccent,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'La plataforma no procesa pagos ni cobra comisiones por venta. '
                        'La coordinación del plan se realiza con el equipo por WhatsApp.',
                        style: TextStyle(
                          fontSize: 11,
                          color: ZanateColors.zanateAccent,
                          height: 1.3,
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
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ZanateColors.zanateAccent,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Enviar Solicitud'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (isMobile) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: content,
      );
    } else {
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: content,
        ),
      );
    }
  }
}
