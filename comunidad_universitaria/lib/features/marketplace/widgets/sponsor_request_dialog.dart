import 'package:flutter/material.dart';
import '../../../core/services/marketplace_service.dart';
import '../../../core/utils/responsive.dart';

class SponsorRequestDialog extends StatefulWidget {
  const SponsorRequestDialog({super.key});

  static Future<void> show(BuildContext context) {
    if (Responsive.isMobile(context)) {
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => const SponsorRequestDialog(),
      );
    } else {
      return showDialog(
        context: context,
        builder: (ctx) => const SponsorRequestDialog(),
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
  bool _isSubmitting = false;

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

    setState(() => _isSubmitting = true);

    final success = await MarketplaceService.requestSponsorship(
      brandName: _brandController.text.trim(),
      contactName: _contactController.text.trim(),
      contactPhone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      proposalDetails: _proposalController.text.trim(),
      expectedPlacement: _placement,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Solicitud enviada con éxito! El equipo se comunicará contigo por WhatsApp.'),
            backgroundColor: Color(0xFF004B87),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = Responsive.isMobile(context);
    final maxHeight = MediaQuery.of(context).size.height * (isMobile ? 0.90 : 0.85);

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
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.star_outline, color: Color(0xFFD97706), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Solicitar Espacio de Patrocinador',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        'Anúnciate en primera plana con video y mayor alcance',
                        style: TextStyle(fontSize: 12, color: Color(0xFFD97706)),
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
              validator: (val) => (val == null || val.trim().isEmpty) ? 'Ingresa el nombre del negocio' : null,
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
                    validator: (val) => (val == null || val.trim().isEmpty) ? 'Ingresa tu nombre' : null,
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
                    validator: (val) => (val == null || val.trim().isEmpty) ? 'Ingresa tu WhatsApp' : null,
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

            DropdownButtonFormField<String>(
              initialValue: _placement,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Espacio Deseado',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: const [
                DropdownMenuItem(value: 'Primera Plana - Marketplace', child: Text('Primera Plana — Marketplace (Video + Fotos)', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: 'Banner en Foro Universitario', child: Text('Banner Destacado en Foro Universitario', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: 'Todos los Espacios', child: Text('Patrocinio Integral (Marketplace + Foro + Grupos)', overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (val) => setState(() => _placement = val ?? _placement),
            ),

            const SizedBox(height: 12),

            TextFormField(
              controller: _proposalController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Detalle de la propuesta o productos a promocionar',
                hintText: 'Describe qué productos o servicios ofreces a los estudiantes...',
              ),
              validator: (val) => (val == null || val.trim().isEmpty) ? 'Describe tu propuesta' : null,
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Nota: Los patrocinios ayudan al sostenimiento autónomo de la plataforma estudiantil. No se admiten productos no autorizados por las normas comunitarias.',
                style: TextStyle(fontSize: 11, color: Color(0xFF475569)),
              ),
            ),

            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _isSubmitting ? null : _submit,
                  child: Text(_isSubmitting ? 'Enviando...' : 'Enviar Solicitud'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

    if (isMobile) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: content,
      );
    } else {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: content,
        ),
      );
    }
  }
}
