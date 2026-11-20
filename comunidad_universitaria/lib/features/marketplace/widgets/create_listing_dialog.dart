import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../core/constants/zanate_colors.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/categories.dart';
import '../../../core/models/marketplace_item.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/services/marketplace_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/utils/responsive.dart';
import '../../profile/screens/profile_screen.dart';
import '../../profile/widgets/carne_validation_modal.dart';
import '../../shared/widgets/identity_badge_chip.dart';
import '../../../core/models/user_profile.dart';
import '../marketplace_theme.dart';
import 'marketplace_plans_sheet.dart';

class CreateListingDialog extends StatefulWidget {
  final String activeAlias;
  final Function(String newAlias) onAliasChanged;
  final Function(MarketplaceItem newItem) onListingCreated;
  final bool isSponsored;

  const CreateListingDialog({
    super.key,
    required this.activeAlias,
    required this.onAliasChanged,
    required this.onListingCreated,
    this.isSponsored = false,
  });

  static Future<void> show(
    BuildContext context, {
    required String activeAlias,
    required Function(String) onAliasChanged,
    required Function(MarketplaceItem) onListingCreated,
    bool isSponsored = false,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (ctx) => CreateListingDialog(
          activeAlias: activeAlias,
          onAliasChanged: onAliasChanged,
          onListingCreated: onListingCreated,
          isSponsored: isSponsored,
        ),
      ),
    );
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
  bool _isLoadingProfile = true;
  UserProfile? _userProfile;
  MarketplaceSellerStatus? _sellerStatus;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadSellerStatus();
  }

  Future<void> _loadSellerStatus() async {
    try {
      final status = await MarketplaceService.fetchMyStatus();
      if (mounted && status != null) {
        setState(() => _sellerStatus = status);
      }
    } catch (_) {}
  }

  Future<void> _loadUserProfile() async {
    final prof = await LocalStorageService.getUserProfile();
    if (mounted) {
      setState(() {
        _userProfile = prof;
        _isLoadingProfile = false;
      });
    }
  }

  bool get _hasConfiguredContactChannel =>
      _userProfile?.hasContactChannel ?? false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _locationDetailController.dispose();
    _socialLinkInputController.dispose();
    _videoUrlController.dispose();
    super.dispose();
  }

  int get _maxImages =>
      _sellerStatus?.maxImagesPerItem ?? (widget.isSponsored ? 3 : 2);

  bool get _isQuotaExceeded =>
      _sellerStatus != null &&
      !_sellerStatus!.isUnlimited &&
      _sellerStatus!.activeItems >= _sellerStatus!.maxActiveItems;

  Future<void> _pickAndUploadImage() async {
    if (_imageUrls.length >= _maxImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isSponsored
                ? 'Límite de 3 imágenes alcanzado para patrocinadores.'
                : 'Límite de 1 imagen alcanzado para publicaciones regulares.',
          ),
        ),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al subir imagen: $e')));
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

    // Verify at least one contact channel configured in profile
    final whatsapp = _userProfile?.contactWhatsapp?.trim();
    final instagram = _userProfile?.contactInstagram?.trim();
    final messenger = _userProfile?.contactMessenger?.trim();
    final telegram = _userProfile?.contactTelegram?.trim();

    final hasWhatsapp = whatsapp != null && whatsapp.isNotEmpty;
    final hasInstagram = instagram != null && instagram.isNotEmpty;
    final hasMessenger = messenger != null && messenger.isNotEmpty;
    final hasTelegram = telegram != null && telegram.isNotEmpty;

    if (!hasWhatsapp && !hasInstagram && !hasMessenger && !hasTelegram) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Debes configurar al menos un canal de contacto en tu perfil.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final priceVal = _isFree
        ? 0.0
        : (double.tryParse(_priceController.text.trim()) ?? 0.0);

    try {
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
        contactWhatsapp: hasWhatsapp ? whatsapp : null,
        contactInstagram: hasInstagram ? instagram : null,
        contactMessenger: hasMessenger ? messenger : null,
        contactTelegram: hasTelegram ? telegram : null,
        socialLinks: _socialLinks,
        imageUrls: _imageUrls,
        videoUrl: _videoUrlController.text.trim().isNotEmpty
            ? _videoUrlController.text.trim()
            : null,
        authorAlias: widget.activeAlias,
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        if (created != null) {
          widget.onListingCreated(created);
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '¡Publicación creada exitosamente en el Marketplace!',
              ),
              backgroundColor: ZanateColors.zanateBlack,
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
    } on MarketplaceException catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        final msg = e is StateError
            ? e.toString().replaceFirst('Bad state: ', '')
            : (e.toString().startsWith('Exception: ')
                ? e.toString().replaceFirst('Exception: ', '')
                : 'No se pudo publicar el anuncio. Revisa tu conexión e inténtalo de nuevo.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  InputDecoration _zanateInput(
    bool isDark, {
    required String labelText,
    String? hintText,
    String? prefixText,
    Widget? prefixIcon,
  }) {
    final borderColor = ZanateColors.border(isDark);
    final focusColor = ZanateColors.focusBorder(isDark);
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixText: prefixText,
      prefixIcon: prefixIcon,
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
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // Selector visual drásticamente diferenciado (Identidad en Marketplace)
              IdentityBadgeChip(
                mode: IdentityMode.marketplaceVerified,
                displayName: widget.activeAlias,
                carne: null,
                isVerified: _userProfile?.isCarneVerified ?? false,
                onSwitchIdentity: () {
                  if (_userProfile != null) {
                    CarneValidationModal.show(
                      context,
                      currentProfile: _userProfile!,
                      onProfileUpdated: (updated) {
                        setState(() {
                          _userProfile = updated;
                        });
                      },
                    );
                  }
                },
              ),

              // Tarjeta de límites del plan (UX-MKT-012)
              if (_sellerStatus != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _isQuotaExceeded
                        ? const Color(0xFFEF4444).withValues(alpha: 0.1)
                        : ZanateColors.pill(isDark),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isQuotaExceeded
                          ? const Color(0xFFEF4444)
                          : borderColor,
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isQuotaExceeded
                            ? PhosphorIconsBold.warning
                            : PhosphorIconsRegular.sparkle,
                        size: 16,
                        color: _isQuotaExceeded
                            ? const Color(0xFFEF4444)
                            : ZanateColors.focusBorder(isDark),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _isQuotaExceeded
                              ? 'Alcanzaste el máximo de ${_sellerStatus!.maxActiveItems} publicaciones activas de tu plan.'
                              : 'Plan ${_sellerStatus!.planName} · ${_sellerStatus!.isUnlimited ? "Publicaciones ilimitadas" : "${_sellerStatus!.activeItems}/${_sellerStatus!.maxActiveItems} publicaciones"} · hasta $_maxImages imágenes',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: _isQuotaExceeded
                                ? const Color(0xFFDC2626)
                                : primaryText,
                          ),
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 32),
                        ),
                        onPressed: () => MarketplacePlansSheet.show(context),
                        child: Text(
                          _isQuotaExceeded ? 'Mejorar plan' : 'Planes',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: ZanateColors.focusBorder(isDark),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Aviso de vigencia de 14 días en plan free
              if (_sellerStatus == null || _sellerStatus!.planId == 'free') ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      PhosphorIconsRegular.clockCountdown,
                      size: 13,
                      color: primaryText,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Esta publicación se pausará automáticamente a los 14 días.',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: primaryText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 16),
              Container(height: 0.8, color: borderColor),
              const SizedBox(height: 18),

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
                      isExpanded: true,
                      itemHeight: null,
                      dropdownColor: ZanateColors.card(isDark),
                      decoration: _zanateInput(
                        isDark,
                        labelText: 'Categoría',
                      ),
                      items: USACConstants.marketplaceCategories
                          .where((c) => c.id != 'todos')
                          .map(
                            (c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(
                                c.label,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) => setState(
                        () => _selectedCategory = val ?? 'comida_postres',
                      ),
                    ),
                  ),

                  // Free toggle
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: _isFree,
                        activeColor: ZanateColors.zanateBlack,
                        onChanged: (val) {
                          setState(() {
                            _isFree = val ?? false;
                            if (_isFree) _priceController.text = '0.00';
                          });
                        },
                      ),
                      const Text(
                        'Aporte o tutoría GRATUITA',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Title
              TextFormField(
                controller: _titleController,
                decoration: _zanateInput(
                  isDark,
                  labelText: 'Título del producto o servicio',
                  hintText: 'Ej. Pastel de Zanahoria / Tutoría de Física 1',
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
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _zanateInput(
                    isDark,
                    labelText: 'Precio en Quetzales',
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
                const SizedBox(height: 12),
              ],

              // Botón para configurar canales de contacto solo si no hay ninguno configurado
              if (!_isLoadingProfile && !_hasConfiguredContactChannel) ...[
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryText,
                    backgroundColor: ZanateColors.surface(isDark),
                    side: BorderSide(color: borderColor, width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProfileScreen(
                          activeAlias: widget.activeAlias,
                          onAliasChanged: widget.onAliasChanged,
                          isDarkMode: isDark,
                        ),
                      ),
                    );
                    await _loadUserProfile();
                  },
                  icon: Icon(
                    PhosphorIconsRegular.addressBook,
                    size: 18,
                    color: primaryText,
                  ),
                  label: const Text(
                    'Configurar canales de contacto',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Sede & Building / Location
              Text(
                'Ubicación de Entrega en el Campus',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: primaryText,
                ),
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
                      isExpanded: true,
                      itemHeight: null,
                      dropdownColor: ZanateColors.card(isDark),
                      decoration: _zanateInput(
                        isDark,
                        labelText: 'Sede / Campus',
                      ),
                      items: USACConstants.sedes
                          .map(
                            (s) => DropdownMenuItem<String>(
                              value: s['id']!,
                              child: Text(
                                s['nombre']!,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedSede = val ?? 'central'),
                    ),
                  ),
                  SizedBox(
                    width: isMobile ? double.infinity : 240,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedFacultad,
                      isExpanded: true,
                      itemHeight: null,
                      dropdownColor: ZanateColors.card(isDark),
                      decoration: _zanateInput(
                        isDark,
                        labelText: 'Facultad / Unidad',
                      ),
                      items: USACConstants.facultades
                          .map(
                            (f) => DropdownMenuItem<String>(
                              value: f['id'].toString(),
                              child: Text(
                                f['nombre'].toString(),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedFacultad = val ?? 'todas'),
                    ),
                  ),
                  SizedBox(
                    width: isMobile ? double.infinity : 240,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedBuilding,
                      isExpanded: true,
                      itemHeight: null,
                      dropdownColor: ZanateColors.card(isDark),
                      decoration: _zanateInput(
                        isDark,
                        labelText: 'Edificio o Punto',
                      ),
                      items: USACConstants.campusBuildings
                          .map(
                            (b) => DropdownMenuItem<String>(
                              value: b['building_code'].toString(),
                              child: Text(
                                '${b['building_code']} — ${b['nombre']}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedBuilding = val ?? 'T-3'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              TextFormField(
                controller: _locationDetailController,
                decoration: _zanateInput(
                  isDark,
                  labelText: 'Punto específico / Horario de entrega',
                  hintText: 'Ej. Frente a cafetería entre 11:00 y 13:00 hrs.',
                  prefixIcon: const Padding(
                    padding: EdgeInsets.all(12),
                    child: PhosphorIcon(PhosphorIconsRegular.mapPin, size: 18),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Description
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: _zanateInput(
                  isDark,
                  labelText: 'Descripción detallada',
                  hintText:
                      'Indica sabores, temas de la tutoría, estado del libro o especificaciones...',
                ),
                validator: (val) {
                  if (val == null || val.trim().length < 10) {
                    return 'Agrega una descripción de al menos 10 caracteres.';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 14),

              // Image Upload to Bucket
              Text(
                widget.isSponsored
                    ? 'Fotos de Patrocinador · Hasta 3 imágenes'
                    : 'Foto del Producto o Servicio',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: primaryText,
                ),
              ),
              const SizedBox(height: 6),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ..._imageUrls.map(
                    (url) => Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            url,
                            width: 70,
                            height: 70,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) => Container(
                              width: 70,
                              height: 70,
                              color: ZanateColors.surface(isDark),
                              child: PhosphorIcon(
                                PhosphorIconsRegular.imageBroken,
                                size: 24,
                                color: secondaryText,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: InkWell(
                            onTap: () => setState(() => _imageUrls.remove(url)),
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const PhosphorIcon(
                                PhosphorIconsRegular.x,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_imageUrls.length < _maxImages)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryText,
                        backgroundColor: ZanateColors.surface(isDark),
                        side: BorderSide(color: borderColor, width: 1.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                      ),
                      onPressed: _isUploadingImage ? null : _pickAndUploadImage,
                      icon: _isUploadingImage
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : PhosphorIcon(
                              PhosphorIconsRegular.image,
                              size: 18,
                              color: primaryText,
                            ),
                      label: Text(
                        _isUploadingImage ? 'Subiendo...' : 'Subir Foto',
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 14),

              // Reference Social Links
              Text(
                'Publicaciones de Referencia en Redes Sociales',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: primaryText,
                ),
              ),
              const SizedBox(height: 6),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _socialLinkInputController,
                      decoration: _zanateInput(
                        isDark,
                        labelText: 'Enlace de publicación',
                        hintText: 'https://instagram.com/p/...',
                        prefixIcon: const Padding(
                          padding: EdgeInsets.all(12),
                          child: PhosphorIcon(PhosphorIconsRegular.link, size: 18),
                        ),
                      ),
                      onSubmitted: (_) => _addSocialLink(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    style: IconButton.styleFrom(
                      backgroundColor: ZanateColors.pill(isDark),
                      foregroundColor: primaryText,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const PhosphorIcon(PhosphorIconsBold.plus, size: 18),
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
                      .map(
                        (link) => Chip(
                          label: Text(
                            link,
                            style: const TextStyle(fontSize: 11),
                          ),
                          deleteIcon: const PhosphorIcon(
                            PhosphorIconsRegular.x,
                            size: 13,
                          ),
                          onDeleted: () =>
                              setState(() => _socialLinks.remove(link)),
                        ),
                      )
                      .toList(),
                ),
              ],

              // Video URL (if allowVideo or sponsored)
              if (_sellerStatus?.allowVideo == true || widget.isSponsored) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _videoUrlController,
                  decoration: _zanateInput(
                    isDark,
                    labelText: 'Enlace de Video Promocional',
                    hintText: 'https://youtube.com/watch?v=...',
                    prefixIcon: const Padding(
                      padding: EdgeInsets.all(12),
                      child: PhosphorIcon(
                        PhosphorIconsRegular.playCircle,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Disclaimer
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ZanateColors.zanateEyeYellow.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: ZanateColors.zanateEyeYellow.withValues(alpha: 0.45),
                  ),
                ),
                child: Text(
                  'Nota: Toda compra, venta o asesoría se coordina directamente entre estudiantes de forma voluntaria. La plataforma no maneja dinero.',
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFFFDE68A)
                        : ZanateColors.zanateBlack,
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Action Buttons
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: secondaryText,
                      ),
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isQuotaExceeded
                            ? ZanateColors.zanateEyeYellow
                            : (isDark
                                ? ZanateColors.zanateEyeYellow
                                : ZanateColors.zanateBlack),
                        foregroundColor: _isQuotaExceeded
                            ? ZanateColors.zanateBlack
                            : (isDark
                                ? ZanateColors.zanateBlack
                                : Colors.white),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 13,
                        ),
                      ),
                      onPressed: _isSubmitting
                          ? null
                          : (_isQuotaExceeded
                              ? () => MarketplacePlansSheet.show(context)
                              : _submit),
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              _isQuotaExceeded
                                  ? PhosphorIconsBold.sparkle
                                  : PhosphorIconsBold.paperPlaneTilt,
                              size: 16,
                            ),
                      label: Text(
                        _isSubmitting
                            ? 'Publicando...'
                            : (_isQuotaExceeded
                                ? 'Mejorar plan'
                                : 'Publicar Anuncio'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
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
            'Publicar Producto o Servicio',
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
