import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/categories.dart';
import '../../../core/constants/zanate_colors.dart';
import '../../../core/models/marketplace_item.dart';
import '../../../core/services/marketplace_service.dart';
import '../../../core/utils/business_hours_helper.dart';
import '../../../core/utils/responsive.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../../shared/widgets/report_dialog.dart';
import 'product_detail_screen.dart';

class StoreProfileScreen extends StatefulWidget {
  final String sellerPublicId;
  final SellerProfile? initialProfile;

  const StoreProfileScreen({
    super.key,
    required this.sellerPublicId,
    this.initialProfile,
  });

  @override
  State<StoreProfileScreen> createState() => _StoreProfileScreenState();
}

class _StoreProfileScreenState extends State<StoreProfileScreen> {
  SellerProfile? _profile;
  List<MarketplaceItem> _catalog = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _profile = widget.initialProfile;
    _loadStoreData();
  }

  Future<void> _loadStoreData() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        MarketplaceService.fetchSellerProfile(widget.sellerPublicId),
        MarketplaceService.fetchSellerCatalog(
          sellerPublicId: widget.sellerPublicId,
          limit: 30,
        ),
      ]);

      if (!mounted) return;
      final fetchedProfile = results[0] as SellerProfile?;
      final fetchedCatalog = results[1] as List<MarketplaceItem>;

      if (fetchedProfile != null) {
        setState(() {
          _profile = fetchedProfile;
          _catalog = fetchedCatalog;
          _isLoading = false;
          _hasError = false;
        });
      } else if (_profile == null) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      } else {
        setState(() {
          _catalog = fetchedCatalog;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      if (_profile == null) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleShareStore() {
    final prof = _profile;
    if (prof == null) return;

    final storeName = prof.businessName ?? prof.displayName;
    final shareText =
        'Visita la tienda "$storeName" en el Marketplace de Comunidad USAC.\n'
        'Catálogo de productos y contacto directo.';

    try {
      SharePlus.instance.share(
        ShareParams(text: shareText, subject: 'Tienda $storeName'),
      );
    } catch (_) {
      Clipboard.setData(ClipboardData(text: shareText));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El enlace de la tienda se copió al portapapeles.'),
          backgroundColor: ZanateColors.zanateAccent,
        ),
      );
    }
  }

  void _handleReportStore() {
    final prof = _profile;
    if (prof == null) return;

    final firstItemId = _catalog.isNotEmpty ? _catalog.first.id : prof.publicId;

    ReportDialog.show(
      context,
      title: 'Reportar Tienda',
      subtitle: 'Comercio: ${prof.businessName ?? prof.displayName}',
      onSubmitted: (reason) async {
        final ok = await MarketplaceService.reportListing(
          itemId: firstItemId,
          reason: 'Reporte a tienda [${prof.publicId}]: $reason',
          sellerUserId: null,
          sellerAlias: prof.displayName,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok
                  ? 'Tienda reportada. Gracias por cuidar la comunidad.'
                  : 'No se pudo enviar el reporte.',
            ),
            backgroundColor: ZanateColors.zanateAccent,
          ),
        );
      },
    );
  }

  void _openEditStoreSheet() {
    final prof = _profile;
    if (prof == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _EditStoreSheet(
        profile: prof,
        onProfileUpdated: (updated) {
          setState(() => _profile = updated);
          _loadStoreData();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDesktop = Responsive.isDesktop(context);

    if (_isLoading && _profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cargando tienda...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_hasError || _profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tienda')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  PhosphorIconsRegular.storefront,
                  size: 48,
                  color: Color(0xFFEF4444),
                ),
                const SizedBox(height: 14),
                Text(
                  'No pudimos cargar la información de esta tienda.',
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Volver'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final prof = _profile!;
    final storeName = (prof.businessName != null && prof.businessName!.trim().isNotEmpty)
        ? prof.businessName!
        : prof.displayName;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : ZanateColors.surfaceBg,
      appBar: AppBar(
        title: Text(
          storeName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Compartir tienda',
            icon: const Icon(PhosphorIconsRegular.shareNetwork),
            onPressed: _handleShareStore,
          ),
          if (prof.isMyStore)
            IconButton(
              tooltip: 'Editar tienda',
              icon: const Icon(PhosphorIconsRegular.pencilSimple),
              onPressed: _openEditStoreSheet,
            )
          else
            PopupMenuButton<String>(
              tooltip: 'Más opciones',
              onSelected: (val) {
                if (val == 'report') _handleReportStore();
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'report',
                  child: Row(
                    children: [
                      Icon(PhosphorIconsRegular.flag, size: 16, color: Color(0xFFEF4444)),
                      SizedBox(width: 8),
                      Text('Reportar tienda'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStoreData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isDesktop ? 1000 : double.infinity),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Store Header (Banner + Avatar + Info)
                  _buildHeader(prof, isDark, theme),
                  const SizedBox(height: 16),

                  // 2. Catalog Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            'Catálogo de publicaciones',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Text(
                          '${_catalog.length} disponibles',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_catalog.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: EmptyStateWidget(
                        icon: PhosphorIconsRegular.storefront,
                        title: 'Esta tienda aún no tiene publicaciones activas',
                        description: 'Vuelve más tarde para descubrir nuevos productos o tutorías.',
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: isDesktop
                          ? GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _catalog.length,
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 14,
                                childAspectRatio: 0.76,
                              ),
                              itemBuilder: (ctx, i) => _buildCatalogItem(_catalog[i]),
                            )
                          : GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _catalog.length,
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 0.74,
                              ),
                              itemBuilder: (ctx, i) => _buildCatalogItem(_catalog[i]),
                            ),
                    ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(SellerProfile prof, bool isDark, ThemeData theme) {
    final bannerUrl = prof.businessBannerUrl;
    final logoUrl = prof.businessLogoUrl;
    final storeName = prof.businessName ?? prof.displayName;
    final hoursStatus = BusinessHoursHelper.formatStatus(prof.businessHours);
    final isOpen = BusinessHoursHelper.isOpenNow(prof.businessHours);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Banner
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: 130,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: bannerUrl == null
                    ? const LinearGradient(
                        colors: [Color(0xFF004B87), Color(0xFF1E3A8A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                image: bannerUrl != null
                    ? DecorationImage(image: NetworkImage(bannerUrl), fit: BoxFit.cover)
                    : null,
              ),
            ),

            // Floating Logo / Avatar
            Positioned(
              left: 20,
              bottom: -32,
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : Colors.white,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: logoUrl != null && logoUrl.isNotEmpty
                      ? Image.network(
                          logoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _buildAvatarFallback(prof),
                        )
                      : _buildAvatarFallback(prof),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 36),

        // Info Block
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Store Name & Verified Badge
              Row(
                children: [
                  Flexible(
                    child: Text(
                      storeName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  if (prof.isVerified) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.verified, size: 18, color: Color(0xFF0284C7)),
                  ],
                ],
              ),
              const SizedBox(height: 4),

              // Plan Badge & Status Chips
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: ZanateColors.zanateAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      prof.badgeText ?? prof.planName,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: ZanateColors.zanateAccent,
                      ),
                    ),
                  ),

                  // Open / Closed Status for local businesses
                  if (prof.businessHours != null && prof.businessHours!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isOpen == true
                            ? const Color(0xFF10B981).withValues(alpha: 0.15)
                            : Colors.grey.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.circle,
                            size: 8,
                            color: isOpen == true ? const Color(0xFF059669) : Colors.grey,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            hoursStatus,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isOpen == true ? const Color(0xFF059669) : Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Presence on campus
                  if (prof.isOnCampus)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(PhosphorIconsFill.mapPin, size: 12, color: Color(0xFF059669)),
                          const SizedBox(width: 4),
                          Text(
                            prof.currentBuildingCode != null && prof.currentBuildingCode!.isNotEmpty
                                ? 'Entregando ahora · ${prof.currentBuildingCode}'
                                : 'Entregando ahora en el campus',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Description
              if (prof.businessDescription != null && prof.businessDescription!.isNotEmpty) ...[
                Text(
                  prof.businessDescription!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    height: 1.35,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Presence note if available
              if (prof.isOnCampus &&
                  prof.currentLocationNote != null &&
                  prof.currentLocationNote!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Punto de entrega: ${prof.currentLocationNote}',
                    style: const TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarFallback(SellerProfile prof) {
    return Container(
      color: ZanateColors.zanateAccent,
      child: Center(
        child: Text(
          prof.storeInitials,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 22,
          ),
        ),
      ),
    );
  }

  Widget _buildCatalogItem(MarketplaceItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(
              itemId: item.id,
              initialItem: item,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : ZanateColors.subtleBorder,
            width: 0.8,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade200,
                child: item.imageUrls.isNotEmpty
                    ? Image.network(
                        item.imageUrls.first,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(Icons.image, size: 28),
                      )
                    : const Icon(Icons.storefront, size: 28),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.formattedPrice,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: ZanateColors.zanateAccent,
                    ),
                  ),
                  if (item.buildingCode.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Edificio ${item.buildingCode}',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditStoreSheet extends StatefulWidget {
  final SellerProfile profile;
  final ValueChanged<SellerProfile> onProfileUpdated;

  const _EditStoreSheet({
    required this.profile,
    required this.onProfileUpdated,
  });

  @override
  State<_EditStoreSheet> createState() => _EditStoreSheetState();
}

class _EditStoreSheetState extends State<_EditStoreSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late final TextEditingController _noteController;
  late bool _isOnCampus;
  String? _selectedBuilding;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.businessName ?? '');
    _descController = TextEditingController(text: widget.profile.businessDescription ?? '');
    _noteController = TextEditingController(text: widget.profile.currentLocationNote ?? '');
    _isOnCampus = widget.profile.isOnCampus;
    _selectedBuilding = widget.profile.currentBuildingCode ?? 'T-3';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    try {
      final success = await MarketplaceService.updateSellerProfile(
        sellerPublicId: widget.profile.publicId,
        businessName: _nameController.text.trim(),
        businessDescription: _descController.text.trim(),
        isCurrentlyOnCampus: _isOnCampus,
        currentBuildingCode: _selectedBuilding,
        currentLocationNote: _noteController.text.trim(),
      );

      if (!mounted) return;
      if (success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil de tienda actualizado con éxito.'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      } else {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar la tienda.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Editar Perfil Comercial',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre comercial de la tienda',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              maxLines: 3,
              maxLength: 300,
              decoration: const InputDecoration(
                labelText: 'Descripción de la tienda o productos',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Entregando ahora en el campus'),
              subtitle: const Text('Muestra un distintivo verde en tu perfil y publicaciones.'),
              value: _isOnCampus,
              onChanged: (val) => setState(() => _isOnCampus = val),
            ),
            if (_isOnCampus) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: ValueKey(_selectedBuilding),
                initialValue: _selectedBuilding,
                decoration: const InputDecoration(
                  labelText: 'Edificio de entrega',
                  border: OutlineInputBorder(),
                ),
                items: USACConstants.campusBuildings
                    .where((b) => b['sede_id'] == 'central')
                    .map(
                      (b) => DropdownMenuItem<String>(
                        value: b['building_code']?.toString(),
                        child: Text('${b['building_code']} · ${b['nombre']}'),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _selectedBuilding = val),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Nota de ubicación (ej. Frente a fotocopiadora)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: ZanateColors.zanateAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Guardar Cambios'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
