import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/categories.dart';
import '../../../core/models/marketplace_item.dart';
import '../../../core/services/marketplace_service.dart';
import '../../../core/services/storage_service.dart';
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
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
  final _locationDetailController = TextEditingController();

  // Contact channels
  final _whatsappController = TextEditingController();
  final _instagramController = TextEditingController();
  final _messengerController = TextEditingController();
  final _telegramController = TextEditingController();

  // Reference Social Links
  final _socialLinkInputController = TextEditingController();
  final List<String> _socialLinks = [];

  // Uploaded images & video
  final List<String> _imageUrls = [];
  final _videoUrlController = TextEditingController();

  String _selectedCategory = 'comida_postres';
  String _selectedSede = 'central';
  String _selectedBuilding = 'T-3';
  String _selectedFacultad = 'todas';

  bool _isFree = false;
  bool _isSubmitting = false;
  bool _isUploadingImage = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _locationDetailController.dispose();
    _whatsappController.dispose();
    _instagramController.dispose();
    _messengerController.dispose();
    _telegramController.dispose();
    _socialLinkInputController.dispose();
    _videoUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    if (_imageUrls.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Límite de 3 imágenes alcanzado.')),
      );
      return;
    }

    setState(() => _isUploadingImage = true);

    try {
      final XFile? file = await StorageService.pickSingleImage();
      if (file != null) {
        final url = await StorageService.uploadImageFile(file);
        if (url != null && mounted) {
          setState(() {
            _imageUrls.add(url);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir imagen: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  void _addSocialLink() {
    final text = _socialLinkInputController.text.trim();
    if (text.isEmpty) return;
    if (!text.startsWith('http://') && !text.startsWith('https://')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El enlace debe iniciar con https://')),
      );
      return;
    }
    setState(() {
      _socialLinks.add(text);
      _socialLinkInputController.clear();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Verify at least one contact channel
    final hasWhatsapp = _whatsappController.text.trim().isNotEmpty;
    final hasInstagram = _instagramController.text.trim().isNotEmpty;
    final hasMessenger = _messengerController.text.trim().isNotEmpty;
    final hasTelegram = _telegramController.text.trim().isNotEmpty;

    if (!hasWhatsapp && !hasInstagram && !hasMessenger && !hasTelegram) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes proporcionar al menos un medio de contacto (WhatsApp, Instagram, Messenger o Telegram).'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final priceVal = _isFree ? 0.0 : (double.tryParse(_priceController.text.trim()) ?? 0.0);

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
      contactWhatsapp: hasWhatsapp ? _whatsappController.text.trim() : null,
      contactInstagram: hasInstagram ? _instagramController.text.trim() : null,
      contactMessenger: hasMessenger ? _messengerController.text.trim() : null,
      contactTelegram: hasTelegram ? _telegramController.text.trim() : null,
      socialLinks: _socialLinks,
      imageUrls: _imageUrls,
      videoUrl: _videoUrlController.text.trim().isNotEmpty ? _videoUrlController.text.trim() : null,
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
            content: Text('Error al crear la publicación. Revisa los datos.'),
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

              const Divider(height: 20),

              // Category & Free Toggle
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: isMobile ? double.infinity : 260,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Categoría',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

                  // Free toggle
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
                      const Text('Aporte o tutoría GRATUITA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
                  hintText: 'Ej. Pastel de Zanahoria / Tutoría de Física 1',
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                validator: (val) {
                  if (val == null || val.trim().length < 4) {
                    return 'Ingresa un título de al menos 4 caracteres.';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 12),

              // Price
              if (!_isFree) ...[
                TextFormField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Precio en Quetzales (Q)',
                    hintText: '15.00',
                    prefixText: 'Q ',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  validator: (val) {
                    if (!_isFree) {
                      final num = double.tryParse(val ?? '');
                      if (num == null || num < 0) return 'Precio inválido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
              ],

              // Contact Channels Section Header
              Text(
                'Canales de Contacto (Elige los que desees brindar)',
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),

              // WhatsApp
              TextFormField(
                controller: _whatsappController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'WhatsApp (opcional)',
                  hintText: 'Ej. 55551234',
                  prefixIcon: Icon(Icons.chat, size: 18, color: Color(0xFF25D366)),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(height: 8),

              // Instagram
              TextFormField(
                controller: _instagramController,
                decoration: const InputDecoration(
                  labelText: 'Instagram (opcional)',
                  hintText: 'Ej. @mi_emprendimiento o enlace a tu perfil',
                  prefixIcon: Icon(Icons.camera_alt_outlined, size: 18, color: Color(0xFFE1306C)),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(height: 8),

              // Messenger
              TextFormField(
                controller: _messengerController,
                decoration: const InputDecoration(
                  labelText: 'Facebook Messenger (opcional)',
                  hintText: 'Ej. @usuario o enlace m.me/tu_perfil',
                  prefixIcon: Icon(Icons.message_outlined, size: 18, color: Color(0xFF0084FF)),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(height: 8),

              // Telegram
              TextFormField(
                controller: _telegramController,
                decoration: const InputDecoration(
                  labelText: 'Telegram (opcional)',
                  hintText: 'Ej. @usuario_telegram',
                  prefixIcon: Icon(Icons.send_outlined, size: 18, color: Color(0xFF229ED9)),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),

              const SizedBox(height: 14),

              // Sede & Building / Location
              Text(
                'Ubicación de Entrega en el Campus',
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),

              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: isMobile ? double.infinity : 240,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedSede,
                      decoration: const InputDecoration(
                        labelText: 'Sede / Campus',
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                        labelText: 'Edificio o Punto',
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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

              const SizedBox(height: 8),

              TextFormField(
                controller: _locationDetailController,
                decoration: const InputDecoration(
                  labelText: 'Punto específico / Horario de entrega',
                  hintText: 'Ej. Frente a cafetería entre 11:00 y 13:00 hrs.',
                  prefixIcon: Icon(Icons.place_outlined, size: 18),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),

              const SizedBox(height: 14),

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

              const SizedBox(height: 14),

              // Image Upload to Bucket (Up to 3 images)
              Text(
                'Fotos del Producto / Servicio (Hasta 3 imágenes)',
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ..._imageUrls.map((url) => Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              url,
                              width: 70,
                              height: 70,
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, err, stack) => Container(
                                width: 70,
                                height: 70,
                                color: Colors.grey.shade300,
                                child: const Icon(Icons.broken_image, size: 24),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: InkWell(
                              onTap: () => setState(() => _imageUrls.remove(url)),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      )),
                  if (_imageUrls.length < 3)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onPressed: _isUploadingImage ? null : _pickAndUploadImage,
                      icon: _isUploadingImage
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_photo_alternate_outlined, size: 18),
                      label: Text(_isUploadingImage ? 'Subiendo...' : 'Subir Foto'),
                    ),
                ],
              ),

              const SizedBox(height: 14),

              // Reference Social Links (Facebook, Instagram, TikTok, etc.)
              Text(
                'Publicaciones de Referencia en Redes Sociales (Opcional)',
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _socialLinkInputController,
                      decoration: const InputDecoration(
                        labelText: 'Enlace de publicación (FB, IG, TikTok...)',
                        hintText: 'https://instagram.com/p/...',
                        prefixIcon: Icon(Icons.link, size: 18),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      onSubmitted: (_) => _addSocialLink(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.add, size: 20),
                    tooltip: 'Fijar enlace',
                    onPressed: _addSocialLink,
                  ),
                ],
              ),

              if (_socialLinks.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _socialLinks
                      .map((link) => Chip(
                            label: Text(
                              link.length > 30 ? '${link.substring(0, 27)}...' : link,
                              style: const TextStyle(fontSize: 11),
                            ),
                            deleteIcon: const Icon(Icons.close, size: 14),
                            onDeleted: () => setState(() => _socialLinks.remove(link)),
                          ))
                      .toList(),
                ),
              ],

              const SizedBox(height: 14),

              // Video URL (Optional for sponsors/demos)
              TextFormField(
                controller: _videoUrlController,
                decoration: const InputDecoration(
                  labelText: 'Enlace de Video Promocional (YouTube, Vimeo, etc. - opcional)',
                  hintText: 'https://youtube.com/watch?v=...',
                  prefixIcon: Icon(Icons.play_circle_outline, size: 18),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),

              const SizedBox(height: 16),

              // Disclaimer
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: const Text(
                  'Nota: Toda compra, venta o asesoría se coordina directamente entre estudiantes de forma voluntaria. La plataforma no maneja dinero.',
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
          constraints: const BoxConstraints(maxWidth: 640),
          child: content,
        ),
      );
    }
  }
}
