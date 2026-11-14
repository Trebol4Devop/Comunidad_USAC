import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/categories.dart';
import '../../../core/constants/zanate_colors.dart';
import '../../../core/models/marketplace_item.dart';
import '../../../core/services/marketplace_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/time_utils.dart';
import '../../../core/utils/url_utils.dart';
import '../marketplace_theme.dart';
import '../../shared/widgets/auth_modal.dart';
import '../../shared/widgets/image_viewer_dialog.dart';
import '../../shared/widgets/report_dialog.dart';
import 'store_profile_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final String itemId;
  final MarketplaceItem? initialItem;

  const ProductDetailScreen({
    super.key,
    required this.itemId,
    this.initialItem,
  });

  /// Tracks viewed item IDs in the current session to ensure debounce/once-per-session tracking.
  static final Set<String> _sessionViewedItemIds = {};

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  MarketplaceItem? _item;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  int _currentImageIndex = 0;
  List<MarketplaceItem> _sellerOtherItems = [];
  bool _isLoadingSellerItems = false;
  List<MarketplaceItem> _relatedItems = [];
  bool _isLoadingRelated = false;

  @override
  void initState() {
    super.initState();
    _item = widget.initialItem;
    if (_item != null) {
      _isLoading = false;
      _trackViewOnce(_item!);
      _loadSecondaryData(_item!);
    }
    _loadDetail();
  }

  void _trackViewOnce(MarketplaceItem item) {
    final currentUserId = SupabaseService.currentUserId;
    final isMyItem = item.isMine || (item.userId != null && item.userId == currentUserId);

    if (!isMyItem && !ProductDetailScreen._sessionViewedItemIds.contains(item.id)) {
      ProductDetailScreen._sessionViewedItemIds.add(item.id);
      MarketplaceService.trackEvent(item.id, 'view');
    }
  }

  Future<void> _loadDetail() async {
    try {
      final detailed = await MarketplaceService.fetchItemDetail(widget.itemId);
      if (!mounted) return;

      if (detailed != null) {
        setState(() {
          _item = detailed;
          _isLoading = false;
          _hasError = false;
        });
        _trackViewOnce(detailed);
        _loadSecondaryData(detailed);
      } else if (_item == null) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'No pudimos cargar esta publicación.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      if (_item == null) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'No pudimos cargar esta publicación.';
        });
      }
    }
  }

  Future<void> _loadSecondaryData(MarketplaceItem item) async {
    // 1. Same seller catalog
    final publicId = item.sellerPublicId;
    if (publicId != null && publicId.isNotEmpty) {
      setState(() => _isLoadingSellerItems = true);
      try {
        final catalog = await MarketplaceService.fetchSellerCatalog(
          sellerPublicId: publicId,
          excludeItemId: item.id,
          limit: 6,
        );
        if (mounted) {
          setState(() {
            _sellerOtherItems = catalog;
            _isLoadingSellerItems = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isLoadingSellerItems = false);
      }
    }

    // 2. Related listings (unless competitor protection is active for business_local)
    final hideCompetitors = item.sellerPlanId == 'business_local';
    if (!hideCompetitors) {
      setState(() => _isLoadingRelated = true);
      try {
        final related = await MarketplaceService.fetchRelatedListings(
          itemId: item.id,
          limit: 8,
        );
        if (mounted) {
          setState(() {
            _relatedItems = related;
            _isLoadingRelated = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isLoadingRelated = false);
      }
    }
  }

  Future<void> _handleToggleBookmark() async {
    final item = _item;
    if (item == null) return;

    if (!SupabaseService.isAuthenticated) {
      AuthModal.show(
        context,
        title: 'Inicia sesión para guardar',
        subtitle: 'Para guardar este producto en tus marcadores debes iniciar sesión.',
        onAuthenticated: _handleToggleBookmark,
      );
      return;
    }

    final previousBookmarked = item.isBookmarked;
    setState(() {
      _item = item.copyWith(isBookmarked: !previousBookmarked);
    });

    try {
      final result = await MarketplaceService.toggleBookmark(item.id);
      if (!mounted) return;
      if (result != !previousBookmarked) {
        setState(() {
          _item = item.copyWith(isBookmarked: result);
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result
                ? 'Guardado en tus productos'
                : 'Eliminado de tus guardados',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _item = item.copyWith(isBookmarked: previousBookmarked);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo actualizar el marcador. Inténtalo de nuevo.'),
        ),
      );
    }
  }

  Future<void> _handleToggleUpvote() async {
    final item = _item;
    if (item == null) return;

    if (!SupabaseService.isAuthenticated) {
      AuthModal.show(
        context,
        title: 'Inicia sesión para apoyar',
        subtitle: 'Para dar un voto de utilidad a esta publicación debes iniciar sesión.',
        onAuthenticated: _handleToggleUpvote,
      );
      return;
    }

    final prevUpvoted = item.isUpvotedByMe;
    final prevCount = item.upvotes;
    final newCount = prevUpvoted ? (prevCount - 1).clamp(0, 999999) : prevCount + 1;

    setState(() {
      _item = item.copyWith(isUpvotedByMe: !prevUpvoted, upvotes: newCount);
    });

    final success = await MarketplaceService.toggleUpvote(item);
    if (!mounted) return;
    if (success != !prevUpvoted) {
      setState(() {
        _item = item.copyWith(isUpvotedByMe: prevUpvoted, upvotes: prevCount);
      });
    }
  }

  Future<void> _handleContactChannel(String channel, String url) async {
    final item = _item;
    if (item == null) return;

    // Track intent asynchronously without blocking
    MarketplaceService.trackEvent(item.id, 'click_$channel');

    await UrlUtils.openUrl(context, url);
  }

  Future<void> _handleShare() async {
    final item = _item;
    if (item == null) return;

    MarketplaceService.trackEvent(item.id, 'share');

    final shareText =
        '${item.title} - ${item.formattedPrice}\n\n${item.description}\n\nUbicación: ${item.locationDetail.isNotEmpty ? item.locationDetail : item.sede}\n— Vendedor: ${item.sellerBusinessName ?? item.authorAlias} en Comunidad USAC';

    try {
      await SharePlus.instance.share(
        ShareParams(text: shareText, subject: item.title),
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: shareText));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El enlace de la publicación se copió al portapapeles.'),
          backgroundColor: ZanateColors.zanateAccent,
        ),
      );
    }
  }

  void _handleReport() {
    final item = _item;
    if (item == null) return;

    ReportDialog.show(
      context,
      title: 'Reportar Publicación',
      subtitle: 'Anuncio: ${item.title}',
      onSubmitted: (reason) async {
        final ok = await MarketplaceService.reportListing(
          itemId: item.id,
          reason: reason,
          sellerUserId: item.userId,
          sellerAlias: item.authorAlias,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok
                  ? 'Publicación reportada. Gracias por cuidar la comunidad.'
                  : 'No se pudo enviar el reporte.',
            ),
            backgroundColor: ZanateColors.zanateAccent,
          ),
        );
        if (ok) Navigator.of(context).pop();
      },
    );
  }

  String _getCategoryLabel(String catId) {
    final match = USACConstants.marketplaceCategories.where((c) => c.id == catId);
    return match.isNotEmpty ? match.first.label : 'General';
  }

  String _getSedeName(String sedeId) {
    final match = USACConstants.sedes.where((s) => s['id'] == sedeId);
    return match.isNotEmpty ? match.first['nombre'] ?? 'Sede' : 'Sede Central';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDesktop = Responsive.isDesktop(context);

    if (_isLoading && _item == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cargando anuncio...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_hasError || _item == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Publicación')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  PhosphorIconsRegular.warningCircle,
                  size: 48,
                  color: Color(0xFFEF4444),
                ),
                const SizedBox(height: 14),
                Text(
                  _errorMessage ?? 'No pudimos cargar esta publicación.',
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

    final item = _item!;

    return MarketplaceTheme.wrap(
      context,
      Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      appBar: AppBar(
        title: Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: item.isBookmarked ? 'Quitar de guardados' : 'Guardar publicación',
            icon: Icon(
              item.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              color: item.isBookmarked ? ZanateColors.zanateAccent : null,
            ),
            onPressed: _handleToggleBookmark,
          ),
          IconButton(
            tooltip: 'Compartir publicación',
            icon: const Icon(PhosphorIconsRegular.shareNetwork),
            onPressed: _handleShare,
          ),
          PopupMenuButton<String>(
            tooltip: 'Más opciones',
            onSelected: (val) {
              if (val == 'report') _handleReport();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'report',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(PhosphorIconsRegular.flag, size: 16, color: Color(0xFFEF4444)),
                    SizedBox(width: 8),
                    Text('Reportar publicación'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isDesktop ? 760 : double.infinity),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Notice if item is under review
                if (item.isUnderReview)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF59E0B)),
                    ),
                    child: const Row(
                      children: [
                        Icon(PhosphorIconsBold.shieldWarning, color: Color(0xFFD97706), size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Esta publicación está en revisión por moderación comunitaria. Solo tú puedes verla por ahora.',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFB45309)),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Notice if item is sold
                if (item.isSold)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFEF4444), width: 1),
                    ),
                    child: const Row(
                      children: [
                        Icon(PhosphorIconsBold.tag, color: Color(0xFFDC2626), size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Este artículo ya fue vendido.',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                          ),
                        ),
                      ],
                    ),
                  ),

                // -------------------------------------------------------------
                // BLOQUE 1: Multimedia (Galería PageView con contador 1/N y video)
                // -------------------------------------------------------------
                _buildBlock1Gallery(item, isDark),
                const SizedBox(height: 18),

                // -------------------------------------------------------------
                // BLOQUE 2: Información principal (Título, precio, chips, tiempo)
                // -------------------------------------------------------------
                _buildBlock2MainInfo(item, isDark, theme),
                const SizedBox(height: 20),

                // -------------------------------------------------------------
                // BLOQUE 3: Vendedor, confianza, presencia y botón Ver Tienda
                // -------------------------------------------------------------
                _buildBlock3Seller(item, isDark, theme),
                const SizedBox(height: 20),

                // -------------------------------------------------------------
                // BLOQUE 4: Acciones de contacto (WhatsApp primario, secundarios, upvote)
                // -------------------------------------------------------------
                _buildBlock4Actions(item, isDark, theme),
                const SizedBox(height: 24),

                // -------------------------------------------------------------
                // BLOQUE 5: Más productos de este vendedor
                // -------------------------------------------------------------
                if (_sellerOtherItems.isNotEmpty || _isLoadingSellerItems) ...[
                  _buildBlock5SellerOtherItems(item, isDark, theme),
                  const SizedBox(height: 24),
                ],

                // -------------------------------------------------------------
                // BLOQUE 6: Productos similares de otros vendedores
                // -------------------------------------------------------------
                if (item.sellerPlanId != 'business_local' &&
                    (_relatedItems.isNotEmpty || _isLoadingRelated)) ...[
                  _buildBlock6RelatedItems(item, isDark, theme),
                  const SizedBox(height: 32),
                ],
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  // BLOQUE 1
  Widget _buildBlock1Gallery(MarketplaceItem item, bool isDark) {
    if (item.imageUrls.isEmpty && (item.videoUrl == null || item.videoUrl!.isEmpty)) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Center(
          child: Icon(PhosphorIconsRegular.image, size: 56, color: Color(0xFF94A3B8)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (item.imageUrls.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Container(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    child: PageView.builder(
                      itemCount: item.imageUrls.length,
                      onPageChanged: (idx) => setState(() => _currentImageIndex = idx),
                      itemBuilder: (ctx, i) {
                        final img = item.imageUrls[i];
                        return InkWell(
                          onTap: () => ImageViewerDialog.show(
                            context,
                            imageUrl: img,
                            title: '${item.title} (${i + 1}/${item.imageUrls.length})',
                          ),
                          child: Image.network(
                            img,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Center(
                              child: Icon(PhosphorIconsRegular.imageBroken, size: 48, color: Colors.grey),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                if (item.imageUrls.length > 1)
                  Positioned(
                    bottom: 10,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${_currentImageIndex + 1}/${item.imageUrls.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

        // Video button if exists (no autoplay)
        if (item.videoUrl != null && item.videoUrl!.isNotEmpty) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              side: const BorderSide(color: ZanateColors.zanateAccent, width: 1),
            ),
            icon: const Icon(PhosphorIconsFill.playCircle, color: ZanateColors.zanateAccent, size: 20),
            label: const Text(
              'Ver video promocional',
              style: TextStyle(fontWeight: FontWeight.w700, color: ZanateColors.zanateAccent),
            ),
            onPressed: () => UrlUtils.openUrl(context, item.videoUrl!),
          ),
        ],
      ],
    );
  }

  // BLOQUE 2
  Widget _buildBlock2MainInfo(MarketplaceItem item, bool isDark, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Semantics(
          header: true,
          child: Text(
            item.title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              height: 1.25,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Price Row
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: item.isFree ? const Color(0xFF059669) : ZanateColors.zanateAccent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                item.formattedPrice,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Status Chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: item.isSold
                    ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                    : (item.isReserved
                        ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                        : const Color(0xFF10B981).withValues(alpha: 0.15)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                item.isSold
                    ? 'Vendido'
                    : (item.isReserved ? 'Reservado' : 'Disponible'),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: item.isSold
                      ? const Color(0xFFDC2626)
                      : (item.isReserved
                          ? const Color(0xFFD97706)
                          : const Color(0xFF059669)),
                ),
              ),
            ),
            const Spacer(),
            Text(
              TimeUtils.timeAgo(item.createdAt),
              style: TextStyle(
                fontSize: 11,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Price reference note
        Text(
          'Precio referencial. Coordina el pago y la entrega directamente con el vendedor.',
          style: TextStyle(
            fontSize: 10.5,
            fontStyle: FontStyle.italic,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 12),

        // Location & Category Chips
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            Chip(
              avatar: const Icon(PhosphorIconsRegular.tag, size: 14),
              label: Text(_getCategoryLabel(item.category)),
              visualDensity: VisualDensity.compact,
            ),
            Chip(
              avatar: const Icon(PhosphorIconsRegular.mapPin, size: 14),
              label: Text(_getSedeName(item.sede)),
              visualDensity: VisualDensity.compact,
            ),
            if (item.facultad != 'todas')
              Chip(
                avatar: const Icon(PhosphorIconsRegular.buildings, size: 14),
                label: Text(item.facultad.toUpperCase()),
                visualDensity: VisualDensity.compact,
              ),
            if (item.buildingCode.isNotEmpty)
              Chip(
                avatar: const Icon(PhosphorIconsRegular.door, size: 14),
                label: Text('Edificio ${item.buildingCode}'),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),

        if (item.locationDetail.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(PhosphorIconsRegular.navigationArrow, size: 14, color: ZanateColors.zanateAccent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Punto de entrega: ${item.locationDetail}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 14),
        // Description
        Text(
          item.description,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 13.5,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  // BLOQUE 3
  Widget _buildBlock3Seller(MarketplaceItem item, bool isDark, ThemeData theme) {
    final sellerName = (item.sellerBusinessName != null && item.sellerBusinessName!.trim().isNotEmpty)
        ? item.sellerBusinessName!
        : item.authorAlias;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : ZanateColors.subtleBorder,
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: ZanateColors.zanateAccent.withValues(alpha: 0.15),
                child: Text(
                  sellerName.isNotEmpty ? sellerName[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    color: ZanateColors.zanateAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            sellerName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (item.isSellerVerified) ...[
                          const SizedBox(width: 4),
                          const Tooltip(
                            message: 'Identidad verificada',
                            child: Icon(
                              Icons.verified,
                              size: 16,
                              color: Color(0xFF0284C7),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.sellerBadgeText ??
                          (item.sellerPlanName.isNotEmpty
                              ? item.sellerPlanName
                              : 'Vendedor'),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (item.sellerPublicId != null && item.sellerPublicId!.isNotEmpty)
                TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialURLRoute(
                        builder: (_) => StoreProfileScreen(
                          sellerPublicId: item.sellerPublicId!,
                        ),
                      ),
                    );
                  },
                  child: const Text(
                    'Ver tienda',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: ZanateColors.zanateAccent,
                    ),
                  ),
                ),
            ],
          ),

          // Presence in campus indicator if isOnCampus
          if (item.sellerIsOnCampus) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    PhosphorIconsFill.mapPin,
                    size: 14,
                    color: Color(0xFF059669),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    item.sellerBuildingCode != null && item.sellerBuildingCode!.isNotEmpty
                        ? 'Entregando ahora en edificio ${item.sellerBuildingCode}'
                        : 'Entregando ahora en el campus',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF059669),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // BLOQUE 4
  Widget _buildBlock4Actions(MarketplaceItem item, bool isDark, ThemeData theme) {
    if (item.isSold) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Center(
          child: Text(
            'El contacto directo está deshabilitado porque este artículo ya fue vendido.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final hasWhatsapp = item.whatsappUrl != null;
    final hasSecondary = item.telegramUrl != null ||
        item.instagramUrl != null ||
        item.messengerUrl != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Primary WhatsApp Button
        if (hasWhatsapp)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
              elevation: 1,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            icon: const Icon(PhosphorIconsFill.whatsappLogo, size: 22),
            label: const Text(
              'Contactar por WhatsApp',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            onPressed: () => _handleContactChannel('whatsapp', item.whatsappUrl!),
          ),

        if (hasSecondary) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              if (item.telegramUrl != null)
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(PhosphorIconsFill.telegramLogo, size: 16, color: Color(0xFF0088CC)),
                    label: const Text('Telegram', style: TextStyle(fontSize: 12)),
                    onPressed: () => _handleContactChannel('telegram', item.telegramUrl!),
                  ),
                ),
              if (item.telegramUrl != null && (item.instagramUrl != null || item.messengerUrl != null))
                const SizedBox(width: 8),
              if (item.instagramUrl != null)
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(PhosphorIconsFill.instagramLogo, size: 16, color: Color(0xFFE1306C)),
                    label: const Text('Instagram', style: TextStyle(fontSize: 12)),
                    onPressed: () => _handleContactChannel('instagram', item.instagramUrl!),
                  ),
                ),
              if (item.instagramUrl != null && item.messengerUrl != null)
                const SizedBox(width: 8),
              if (item.messengerUrl != null)
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(PhosphorIconsFill.messengerLogo, size: 16, color: Color(0xFF0084FF)),
                    label: const Text('Messenger', style: TextStyle(fontSize: 12)),
                    onPressed: () => _handleContactChannel('messenger', item.messengerUrl!),
                  ),
                ),
            ],
          ),
        ],

        const SizedBox(height: 12),
        // Row with Upvote & Bookmark & Report
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Upvote button
            InkWell(
              onTap: _handleToggleUpvote,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: item.isUpvotedByMe
                      ? const Color(0xFFEF4444).withValues(alpha: 0.1)
                      : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: item.isUpvotedByMe
                        ? const Color(0xFFEF4444)
                        : (isDark ? const Color(0xFF334155) : ZanateColors.subtleBorder),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.isUpvotedByMe
                          ? PhosphorIconsFill.heart
                          : PhosphorIconsRegular.heart,
                      size: 16,
                      color: item.isUpvotedByMe ? const Color(0xFFEF4444) : Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${item.upvotes} votos de utilidad',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: item.isUpvotedByMe ? const Color(0xFFEF4444) : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bookmark button
            IconButton(
              tooltip: item.isBookmarked ? 'Guardado' : 'Guardar',
              icon: Icon(
                item.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                color: item.isBookmarked ? ZanateColors.zanateAccent : null,
              ),
              onPressed: _handleToggleBookmark,
            ),

            // Report button
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
                minimumSize: const Size(48, 48),
              ),
              icon: const Icon(PhosphorIconsRegular.flag, size: 14),
              label: const Text('Reportar', style: TextStyle(fontSize: 11.5)),
              onPressed: _handleReport,
            ),
          ],
        ),
      ],
    );
  }

  // BLOQUE 5
  Widget _buildBlock5SellerOtherItems(MarketplaceItem item, bool isDark, ThemeData theme) {
    final sellerName = item.sellerBusinessName ?? item.authorAlias;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  'Más productos de $sellerName',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (item.sellerPublicId != null && item.sellerPublicId!.isNotEmpty)
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialURLRoute(
                      builder: (_) => StoreProfileScreen(
                        sellerPublicId: item.sellerPublicId!,
                      ),
                    ),
                  );
                },
                child: const Text('Ver tienda completa', style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 160,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _sellerOtherItems.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (ctx, i) {
              final other = _sellerOtherItems[i];
              return InkWell(
                onTap: () {
                  Navigator.of(context).pushReplacement(
                    MaterialURLRoute(
                      builder: (_) => ProductDetailScreen(
                        itemId: other.id,
                        initialItem: other,
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 130,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : ZanateColors.subtleBorder,
                      width: 0.8,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 90,
                        width: double.infinity,
                        color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade200,
                        child: other.imageUrls.isNotEmpty
                            ? Image.network(
                                other.imageUrls.first,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const Icon(Icons.image, size: 24),
                              )
                            : const Icon(Icons.storefront, size: 24),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              other.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              other.formattedPrice,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: ZanateColors.zanateAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // BLOQUE 6
  Widget _buildBlock6RelatedItems(MarketplaceItem item, bool isDark, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            'También te puede interesar',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _relatedItems.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.85,
          ),
          itemBuilder: (ctx, i) {
            final rel = _relatedItems[i];
            return InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialURLRoute(
                    builder: (_) => ProductDetailScreen(
                      itemId: rel.id,
                      initialItem: rel,
                    ),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(4),
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
                        child: rel.imageUrls.isNotEmpty
                            ? Image.network(
                                rel.imageUrls.first,
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
                            rel.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            rel.formattedPrice,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: ZanateColors.zanateAccent,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            rel.authorAlias,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class MaterialURLRoute<T> extends MaterialPageRoute<T> {
  MaterialURLRoute({required super.builder});
}
