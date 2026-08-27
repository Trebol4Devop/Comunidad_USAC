import 'package:flutter/material.dart';
import '../../../core/constants/categories.dart';
import '../../../core/models/marketplace_item.dart';
import '../../../core/services/marketplace_service.dart';
import '../../../core/utils/responsive.dart';
import '../../profile/widgets/alias_modal.dart';

class CreateListingDialog extends StatefulWidget {
  final String activeAlias;
  final Function(String newAlias) onAliasChanged;
  final Function(MarketplaceItem newItem) onListingCreated;

  const CreateListingDialog({
    super.key,
    required this.activeAlias,
    required this.onAliasChanged,
    required this.onListingCreated,
  });

  static Future<void> show(
    BuildContext context, {
    required String activeAlias,
    required Function(String) onAliasChanged,
    required Function(MarketplaceItem) onListingCreated,
  }) {
    if (Responsive.isMobile(context)) {
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => CreateListingDialog(
          activeAlias: activeAlias,
          onAliasChanged: onAliasChanged,
          onListingCreated: onListingCreated,
        ),
      );
    } else {
      return showDialog(
        context: context,
        builder: (ctx) => CreateListingDialog(
          activeAlias: activeAlias,
          onAliasChanged: onAliasChanged,
          onListingCreated: onListingCreated,
        ),
      );
    }
  }

  @override
  State<CreateListingDialog> createState() => _CreateListingDialogState();
}

class _CreateListingDialogState extends State<CreateListingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController(text: '0.00');
  final _whatsappController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _locationDetailController = TextEditingController();

  String _selectedCategory = 'comida_postres';
  String _selectedSede = 'central';
  String _selectedBuilding = 'T-3';
  String _selectedFacultad = 'todas';
  bool _isFree = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _whatsappController.dispose();
    _imageUrlController.dispose();
    _locationDetailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final priceVal = _isFree ? 0.0 : (double.tryParse(_priceController.text.trim()) ?? 0.0);
    final imageUrls = _imageUrlController.text.trim().isNotEmpty
        ? [_imageUrlController.text.trim()]
        : <String>[];

    final created = await MarketplaceService.createListing(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      price: priceVal,
      isFree: _isFree || priceVal <= 0.0,
      category: _selectedCategory,
      facultad: _selectedFacultad,
      sede: _selectedSede,
      buildingCode: _selectedBuilding,
      locationDetail: _locationDetailController.text.trim(),
      contactWhatsapp: _whatsappController.text.trim(),
      imageUrls: imageUrls,
      authorAlias: widget.activeAlias,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (created != null) {
        widget.onListingCreated(created);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Publicación creada exitosamente en el Marketplace!'),
            backgroundColor: Color(0xFF004B87),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al crear la publicación. Revisa los datos ingresados.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = Responsive.isMobile(context);

    Widget content = Form(
      key: _formKey,
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
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF004B87).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.storefront_outlined, color: Color(0xFF004B87), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Publicar Producto o Tutoría',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Publicando como: ${widget.activeAlias}',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.edit, size: 14),
                  label: const Text('Alias', style: TextStyle(fontSize: 12)),
                  onPressed: () {
                    AliasModal.show(
                      context,
                      currentAlias: widget.activeAlias,
                      onSaved: widget.onAliasChanged,
                    );
                  },
                ),
              ],
            ),

            const Divider(height: 24),

            // Category & Free Toggle
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: isMobile ? double.infinity : 260,
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Categoría',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: USACConstants.marketplaceCategories
                        .where((c) => c.id != 'todos')
                        .map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.label, style: const TextStyle(fontSize: 13)),
                            ))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedCategory = val ?? 'comida_postres'),
                  ),
                ),

                // Free toggle switch
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: _isFree,
                      onChanged: (val) {
                        setState(() {
                          _isFree = val ?? false;
                          if (_isFree) _priceController.text = '0.00';
                        });
                      },
                    ),
                    const Text('Es un aporte o tutoría GRATUITA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Título del producto o servicio',
                hintText: 'Ej. Porciones de Pastel de Zanahoria / Tutoría de Física 1',
              ),
              validator: (val) {
                if (val == null || val.trim().length < 4) {
                  return 'Ingresa un título de al menos 4 caracteres.';
                }
                return null;
              },
            ),

            const SizedBox(height: 12),

            // Price (if not free) & WhatsApp Phone
            Row(
              children: [
                if (!_isFree) ...[
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Precio (Q)',
                        hintText: '15.00',
                        prefixText: 'Q ',
                      ),
                      validator: (val) {
                        if (!_isFree) {
                          final num = double.tryParse(val ?? '');
                          if (num == null || num < 0) return 'Precio inválido';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _whatsappController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Número de WhatsApp de contacto',
                      hintText: 'Ej. 55551234',
                      prefixIcon: Icon(Icons.chat, size: 18, color: Color(0xFF25D366)),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().replaceAll(RegExp(r'[^0-9]'), '').length < 8) {
                        return 'Ingresa tu WhatsApp (al menos 8 dígitos).';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Sede, Faculty & Building / Point of Delivery (Prepared for map)
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: isMobile ? double.infinity : 240,
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedSede,
                    decoration: const InputDecoration(
                      labelText: 'Sede / Campus',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: USACConstants.sedes
                        .map((s) => DropdownMenuItem<String>(
                              value: s['id']!,
                              child: Text(s['nombre']!, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                            ))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedSede = val ?? 'central'),
                  ),
                ),
                SizedBox(
                  width: isMobile ? double.infinity : 240,
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedFacultad,
                    decoration: const InputDecoration(
                      labelText: 'Facultad / Unidad',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: USACConstants.facultades
                        .map((f) => DropdownMenuItem<String>(
                              value: f['id'].toString(),
                              child: Text(f['nombre'].toString(), overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                            ))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedFacultad = val ?? 'todas'),
                  ),
                ),
                SizedBox(
                  width: isMobile ? double.infinity : 240,
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedBuilding,
                    decoration: const InputDecoration(
                      labelText: 'Edificio o Punto en Campus',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: USACConstants.campusBuildings
                        .map((b) => DropdownMenuItem<String>(
                              value: b['building_code'].toString(),
                              child: Text(
                                '${b['building_code']} — ${b['nombre']}',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedBuilding = val ?? 'T-3'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Specific location detail
            TextFormField(
              controller: _locationDetailController,
              decoration: const InputDecoration(
                labelText: 'Punto exacto o horario de entrega (opcional)',
                hintText: 'Ej. Pasillo frente al cafetín entre 11:00 y 13:00 hrs.',
                prefixIcon: Icon(Icons.place_outlined, size: 18),
              ),
            ),

            const SizedBox(height: 12),

            // Description
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Descripción detallada',
                hintText: 'Indica sabores, temas de la tutoría, estado del libro o especificaciones...',
              ),
              validator: (val) {
                if (val == null || val.trim().length < 10) {
                  return 'Agrega una descripción de al menos 10 caracteres.';
                }
                return null;
              },
            ),

            const SizedBox(height: 12),

            // Image URL (optional)
            TextFormField(
              controller: _imageUrlController,
              decoration: const InputDecoration(
                labelText: 'Enlace de foto del producto (opcional)',
                hintText: 'https://ejemplo.com/foto_pastel.jpg',
                prefixIcon: Icon(Icons.image_outlined, size: 18),
              ),
            ),

            const SizedBox(height: 14),

            // Disclaimer Banner
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Text(
                'Nota: La entrega y pago se coordinan de forma directa y presencial entre estudiantes. La plataforma no cobra comisiones.',
                style: TextStyle(color: Color(0xFF92400E), fontSize: 11),
              ),
            ),

            const SizedBox(height: 20),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF004B87),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check, size: 16),
                  label: Text(_isSubmitting ? 'Publicando...' : 'Publicar Anuncio'),
                ),
              ],
            ),
          ],
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
          constraints: const BoxConstraints(maxWidth: 620),
          child: content,
        ),
      );
    }
  }
}
