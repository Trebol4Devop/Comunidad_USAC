import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/constants/categories.dart';
import '../../../core/constants/zanate_colors.dart';
import '../../../core/models/marketplace_item.dart';
import '../../../core/services/marketplace_service.dart';
import '../../../core/services/share_count_service.dart';
import '../../../core/services/sponsored_preferences_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../widgets/create_listing_dialog.dart';
import '../widgets/marketplace_card.dart';
import '../widgets/sponsor_carousel.dart';
import '../widgets/sponsor_request_dialog.dart';
import '../../shared/widgets/auth_modal.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../../shared/widgets/network_state_widgets.dart';
import '../../shared/widgets/settings_bottom_sheet.dart';

class MarketplaceScreen extends StatefulWidget {
  final String activeAlias;
  final Function(String newAlias) onAliasChanged;
  final VoidCallback? onToggleTheme;
  final bool showFloatingActionButton;

  const MarketplaceScreen({
    super.key,
    required this.activeAlias,
    required this.onAliasChanged,
    this.onToggleTheme,
    this.showFloatingActionButton = true,
  });

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  List<MarketplaceItem> _listings = [];
  List<MarketplaceItem> _sponsoredListings = [];
  bool _isLoading = true;
  bool _isOffline = false;

  String _selectedCategory = 'todos';
  String _selectedSede = 'todas';
  String _selectedFacultad = 'todas';
  bool _onlyFree = false;
  String _searchQuery = '';

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        MarketplaceService.fetchListings(
          category: _selectedCategory,
          facultad: _selectedFacultad,
          sede: _selectedSede,
          onlyFree: _onlyFree,
          searchQuery: _searchQuery,
        ),
        MarketplaceService.fetchSponsoredListings(),
      ]);
      final hiddenSponsoredIds =
          await SponsoredPreferencesService.hiddenItemIds();

      final allItems = results[0]
          .where(
            (item) =>
                !item.isSponsored || !hiddenSponsoredIds.contains(item.id),
          )
          .toList();

      await ShareCountService.preload(allItems.map((i) => i.id).toList());
      final enrichedItems = allItems.map((i) {
        final count = ShareCountService.getCachedCount(i.id);
        return count > i.sharesCount ? i.copyWith(sharesCount: count) : i;
      }).toList();

      if (mounted) {
        setState(() {
          _listings = enrichedItems;
          _sponsoredListings = results[1]
              .where((item) => !hiddenSponsoredIds.contains(item.id))
              .toList();
          _isLoading = false;
          _isOffline = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isOffline = true;
        });
      }
    }
  }

  Future<void> _handleShareListing(MarketplaceItem item) async {
    final newCount = item.sharesCount + 1;
    setState(() {
      final idx = _listings.indexWhere((l) => l.id == item.id);
      if (idx != -1) {
        _listings[idx] = _listings[idx].copyWith(sharesCount: newCount);
      }
    });

    await ShareCountService.incrementShare(item.id, table: 'marketplace_items');

    final shareText =
        '${item.title} - ${item.isFree ? "GRATIS" : item.formattedPrice}\n\n${item.description}\n\nUbicación: ${item.locationDetail.isNotEmpty ? item.locationDetail : item.sede}\n— Publicado por ${item.authorAlias} en Comunidad USAC';
    try {
      await SharePlus.instance.share(
        ShareParams(text: shareText, subject: item.title),
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: shareText));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Publicación compartida ($newCount veces). El enlace se copió al portapapeles.'),
          backgroundColor: ZanateColors.zanateAccent,
        ),
      );
      return;
    }
  }

  Future<void> _handleUpdateItemStatus(
    MarketplaceItem item,
    String newStatus,
  ) async {
    final previousStatus = item.status;
    setState(() {
      final idx = _listings.indexWhere((l) => l.id == item.id);
      if (idx != -1) {
        _listings[idx] = item.copyWith(status: newStatus);
      }
    });

    final ok = await MarketplaceService.updateItemStatus(
      itemId: item.id,
      newStatus: newStatus,
    );
    if (!mounted) return;

    if (!ok) {
      setState(() {
        final idx = _listings.indexWhere((listing) => listing.id == item.id);
        if (idx != -1) {
          _listings[idx] = _listings[idx].copyWith(status: previousStatus);
        }
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Estado actualizado a: ${newStatus.toUpperCase()}'
              : 'No se pudo actualizar el anuncio. Inténtalo de nuevo.',
        ),
        backgroundColor: ok
            ? const Color(0xFF059669)
            : Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleToggleUpvote(MarketplaceItem item) async {
    if (SupabaseConfig.isConfigured && !SupabaseService.isAuthenticated) {
      AuthModal.show(
        context,
        title: 'Inicia sesión para votar',
        subtitle: 'Para apoyar una publicación necesitas iniciar sesión.',
        onAuthenticated: () => _handleToggleUpvote(item),
      );
      return;
    }

    final prevUpvoted = item.isUpvotedByMe;
    final prevUpvotes = item.upvotes;

    setState(() {
      final idx = _listings.indexWhere((l) => l.id == item.id);
      if (idx != -1) {
        _listings[idx] = item.copyWith(
          isUpvotedByMe: !prevUpvoted,
          upvotes: prevUpvoted
              ? (prevUpvotes - 1).clamp(0, 999999)
              : prevUpvotes + 1,
        );
      }
    });

    final success = await MarketplaceService.toggleUpvote(item);
    if (mounted && success != !prevUpvoted) {
      setState(() {
        final idx = _listings.indexWhere((l) => l.id == item.id);
        if (idx != -1) {
          _listings[idx] = item.copyWith(
            isUpvotedByMe: prevUpvoted,
            upvotes: prevUpvotes,
          );
        }
      });
    }
  }

  Future<void> _hideSponsoredItem(MarketplaceItem item) async {
    await SponsoredPreferencesService.hideItem(item.id);
    if (!mounted) return;

    setState(() {
      _listings.removeWhere(
        (listing) => listing.isSponsored && listing.id == item.id,
      );
      _sponsoredListings.removeWhere((listing) => listing.id == item.id);
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Anuncio ocultado para ti.')));
  }

  Future<void> _handleReportItem(MarketplaceItem item, String reason) async {
    if (SupabaseConfig.isConfigured && !SupabaseService.isAuthenticated) {
      AuthModal.show(
        context,
        title: 'Inicia sesión para reportar',
        subtitle: 'Para enviar un reporte necesitas iniciar sesión.',
        onAuthenticated: () => _handleReportItem(item, reason),
      );
      return;
    }

    final submitted = await MarketplaceService.reportListing(
      itemId: item.id,
      reason: reason,
      sellerUserId: item.userId,
      sellerAlias: item.authorAlias,
    );
    if (!mounted) return;
    if (!submitted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo enviar el reporte. Inténtalo de nuevo.'),
        ),
      );
      return;
    }

    if (item.isSponsored) {
      await _hideSponsoredItem(item);
      return;
    }

    setState(() {
      _listings.removeWhere((listing) => listing.id == item.id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reporte enviado. La publicación se ocultó para ti.'),
        backgroundColor: ZanateColors.zanateAccent,
      ),
    );
  }

  void _openSponsorRequestDialog() {
    if (SupabaseConfig.isConfigured && !SupabaseService.isAuthenticated) {
      AuthModal.show(
        context,
        title: 'Inicia sesión para solicitar patrocinio',
        subtitle: 'La solicitud debe enviarse desde una cuenta autenticada.',
        onAuthenticated: _openSponsorRequestDialog,
      );
      return;
    }
    SponsorRequestDialog.show(context);
  }

  void _handleCreateListingClick() {
    if (SupabaseConfig.isConfigured && !SupabaseService.isAuthenticated) {
      AuthModal.show(
        context,
        title: 'Inicia Sesión para Publicar',
        subtitle:
            'Para mantener la seguridad del Marketplace y prevenir anuncios fraudulentos, inicia sesión antes de publicar.',
        onAuthenticated: () {
          _openCreateDialog();
        },
      );
    } else {
      _openCreateDialog();
    }
  }

  Future<void> _openCreateDialog() async {
    final canCreate = await MarketplaceService.canCreateListing();
    if (!mounted) return;
    if (!canCreate) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Verificación necesaria'),
          content: const Text(
            'Para publicar anuncios se requiere una verificación estudiantil real. '
            'Esa conexión todavía no está disponible; no se guardará ningún anuncio '
            'ni se marcará tu cuenta como verificada.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }

    CreateListingDialog.show(
      context,
      activeAlias: widget.activeAlias,
      onAliasChanged: widget.onAliasChanged,
      onListingCreated: (newItem) {
        setState(() {
          _listings.insert(0, newItem);
        });
      },
    );
  }

  // Uniform Category Visuals - Disciplined Monochromatic Palette (No Rainbow)
  ({IconData icon, String subtitle}) _getCategoryVisuals(String catId) {
    switch (catId) {
      case 'comida_postres':
        return (
          icon: PhosphorIconsBold.bowlFood,
          subtitle: 'Almuerzos & postres',
        );
      case 'tutorias_academica':
        return (
          icon: PhosphorIconsBold.graduationCap,
          subtitle: 'Clases & asesorías',
        );
      case 'libros_materiales':
        return (
          icon: PhosphorIconsBold.books,
          subtitle: 'Libros, batas y útiles',
        );
      case 'servicios_estudiantiles':
        return (
          icon: PhosphorIconsBold.briefcase,
          subtitle: 'Impresiones y software',
        );
      case 'otros_articulos':
        return (
          icon: PhosphorIconsBold.tag,
          subtitle: 'Tecnología y varios',
        );
      case 'todos':
      default:
        return (
          icon: PhosphorIconsBold.squaresFour,
          subtitle: 'Ver todo el catálogo',
        );
    }
  }

  // 1. Squared Top Header: Clean, Simple, Centered Title without Symbol, Gear for Settings on Left
  Widget _buildSquaredHeader(bool isDark) {
    return Container(
      height: 56,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : ZanateColors.subtleBorder,
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        children: [
          // Left: Settings Button (Configuración y Perfil)
          IconButton(
            tooltip: 'Configuración y Perfil',
            onPressed: () => SettingsBottomSheet.show(
              context,
              activeAlias: widget.activeAlias,
              onAliasChanged: widget.onAliasChanged,
              onToggleTheme: widget.onToggleTheme,
            ),
            icon: Icon(
              PhosphorIconsRegular.gear,
              size: 21,
              color: isDark ? Colors.white : ZanateColors.zanateDark,
            ),
            splashRadius: 22,
          ),

          // Center: Clean, simple, centered title (Matching Forum layout, no symbol box)
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'ZANATE STORE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : Colors.blueGrey.shade400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Marketplace & Tutorías',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: isDark ? Colors.white : ZanateColors.zanateDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Right: Minimalist + button to publish listing
          IconButton(
            tooltip: 'Publicar Anuncio',
            onPressed: _handleCreateListingClick,
            icon: Icon(
              PhosphorIconsBold.plus,
              size: 22,
              color: isDark ? Colors.white : ZanateColors.zanateDark,
            ),
            splashRadius: 22,
          ),
        ],
      ),
    );
  }

  // 2. Search & Filters Bar (Search Query + Ubicación por Sede + Facultad)
  Widget _buildSearchAndFilters(bool isDark, bool isDesktop) {
    final containerBg = isDark ? const Color(0xFF0F172A) : ZanateColors.surfaceBg;
    final borderColor = isDark ? const Color(0xFF334155) : ZanateColors.subtleBorder;
    final textColor = isDark ? Colors.white : ZanateColors.zanateDark;

    if (isDesktop) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          border: Border(
            bottom: BorderSide(color: borderColor, width: 0.8),
          ),
        ),
        child: Column(
          children: [
            // Row 1: Search Field
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: containerBg,
                border: Border.all(color: borderColor, width: 0.8),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const Icon(
                    PhosphorIconsRegular.magnifyingGlass,
                    size: 16,
                    color: ZanateColors.zanateAccent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Buscar en Marketplace (postres, tutorías, libros, cálculo...)',
                        hintStyle: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                      style: TextStyle(fontSize: 13, color: textColor),
                      onSubmitted: (val) {
                        setState(() => _searchQuery = val.trim());
                        _loadData();
                      },
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: const Icon(PhosphorIconsRegular.x, size: 14),
                      splashRadius: 14,
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                        _loadData();
                      },
                    ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      backgroundColor: ZanateColors.zanateAccent,
                      foregroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      minimumSize: const Size(0, 40),
                    ),
                    icon: const Icon(PhosphorIconsBold.magnifyingGlass, size: 15),
                    label: const Text(
                      'Buscar',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    onPressed: () {
                      setState(() => _searchQuery = _searchController.text.trim());
                      _loadData();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Row 2: Filters (Sede / Ubicación, Facultad)
            Row(
              children: [
                // Sede / Ubicación
                Expanded(
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: containerBg,
                      border: Border.all(color: borderColor, width: 0.8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedSede,
                        isExpanded: true,
                        icon: const Icon(PhosphorIconsRegular.caretDown, size: 13),
                        items: USACConstants.sedes
                            .map(
                              (s) => DropdownMenuItem<String>(
                                value: s['id']!,
                                child: Text(
                                  s['nombre']!,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 11.5, color: textColor),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          setState(() => _selectedSede = val ?? 'todas');
                          _loadData();
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Facultad
                Expanded(
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: containerBg,
                      border: Border.all(color: borderColor, width: 0.8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedFacultad,
                        isExpanded: true,
                        icon: const Icon(PhosphorIconsRegular.caretDown, size: 13),
                        items: USACConstants.facultades
                            .map(
                              (f) => DropdownMenuItem<String>(
                                value: f['id'].toString(),
                                child: Text(
                                  f['nombre'].toString(),
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 11.5, color: textColor),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          setState(() => _selectedFacultad = val ?? 'todas');
                          _loadData();
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Mobile layout
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          bottom: BorderSide(color: borderColor, width: 0.8),
        ),
      ),
      child: Column(
        children: [
          // Search Field
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: containerBg,
              border: Border.all(color: borderColor, width: 0.8),
            ),
            child: Row(
              children: [
                const SizedBox(width: 10),
                const Icon(
                  PhosphorIconsRegular.magnifyingGlass,
                  size: 15,
                  color: ZanateColors.zanateAccent,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Buscar en Marketplace...',
                      hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 9),
                    ),
                    style: TextStyle(fontSize: 12, color: textColor),
                    onSubmitted: (val) {
                      setState(() => _searchQuery = val.trim());
                      _loadData();
                    },
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: const Icon(PhosphorIconsRegular.x, size: 14),
                    splashRadius: 14,
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                      _loadData();
                    },
                  ),
                IconButton(
                  tooltip: 'Buscar',
                  icon: const Icon(PhosphorIconsBold.magnifyingGlass, size: 16, color: ZanateColors.zanateAccent),
                  onPressed: () {
                    setState(() => _searchQuery = _searchController.text.trim());
                    _loadData();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Sede / Ubicación & Facultad Row
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: containerBg,
                    border: Border.all(color: borderColor, width: 0.8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedSede,
                      isExpanded: true,
                      icon: const Icon(PhosphorIconsRegular.caretDown, size: 12),
                      items: USACConstants.sedes
                          .map(
                            (s) => DropdownMenuItem<String>(
                              value: s['id']!,
                              child: Text(
                                s['nombre']!,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 10.5, color: textColor),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        setState(() => _selectedSede = val ?? 'todas');
                        _loadData();
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: containerBg,
                    border: Border.all(color: borderColor, width: 0.8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedFacultad,
                      isExpanded: true,
                      icon: const Icon(PhosphorIconsRegular.caretDown, size: 12),
                      items: USACConstants.facultades
                          .map(
                            (f) => DropdownMenuItem<String>(
                              value: f['id'].toString(),
                              child: Text(
                                f['nombre'].toString(),
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 10.5, color: textColor),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        setState(() => _selectedFacultad = val ?? 'todas');
                        _loadData();
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 3. eBay-Style "Compra por Categorías" Visual Section
  Widget _buildEbayCategoriesSection(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : ZanateColors.subtleBorder,
            width: 0.8,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Compra por Categorías',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  color: isDark ? Colors.white : ZanateColors.zanateDark,
                ),
              ),
              if (_selectedCategory != 'todos')
                InkWell(
                  onTap: () {
                    setState(() => _selectedCategory = 'todos');
                    _loadData();
                  },
                  child: const Text(
                    'Ver todas',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: ZanateColors.zanateAccent,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: USACConstants.marketplaceCategories.map((cat) {
                final isSelected = _selectedCategory == cat.id;
                final visuals = _getCategoryVisuals(cat.id);

                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: InkWell(
                    onTap: () {
                      setState(() => _selectedCategory = cat.id);
                      _loadData();
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 130,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? ZanateColors.zanateAccent.withValues(alpha: isDark ? 0.25 : 0.08)
                            : (isDark ? const Color(0xFF0F172A) : ZanateColors.surfaceBg),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? ZanateColors.zanateAccent
                              : (isDark ? const Color(0xFF334155) : ZanateColors.subtleBorder),
                          width: isSelected ? 1.5 : 0.8,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            visuals.icon,
                            size: 20,
                            color: isSelected
                                ? ZanateColors.zanateAccent
                                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            cat.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                              color: isSelected
                                  ? ZanateColors.zanateAccent
                                  : (isDark ? Colors.white : ZanateColors.zanateDark),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            visuals.subtitle,
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
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // 4. eBay-Style "Ofertas y Aportes del Día" Spotlight Carousel
  Widget _buildEbayDealsSection(bool isDark) {
    final deals = _listings.where((item) => item.isFree || item.upvotes > 0).take(8).toList();

    if (deals.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : ZanateColors.subtleBorder,
            width: 0.8,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                PhosphorIconsBold.lightning,
                size: 16,
                color: Color(0xFFF59E0B),
              ),
              const SizedBox(width: 6),
              Text(
                'Ofertas y Aportes del Día',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  color: isDark ? Colors.white : ZanateColors.zanateDark,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'GRATIS & DESTACADOS',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF059669),
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 130,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: deals.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, idx) {
                final item = deals[idx];
                final visuals = _getCategoryVisuals(item.category);

                return Container(
                  width: 240,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : ZanateColors.surfaceBg,
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : ZanateColors.subtleBorder,
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 76,
                        height: 106,
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        child: item.imageUrls.isNotEmpty
                            ? Image.network(
                                item.imageUrls.first,
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stack) => Center(
                                  child: Icon(visuals.icon, size: 24, color: const Color(0xFF94A3B8)),
                                ),
                              )
                            : Center(
                                child: Icon(visuals.icon, size: 24, color: const Color(0xFF94A3B8)),
                              ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: item.isFree ? const Color(0xFF059669) : ZanateColors.zanateAccent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.isFree ? 'GRATIS' : item.formattedPrice,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : ZanateColors.zanateDark,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                const Icon(
                                  PhosphorIconsRegular.mapPin,
                                  size: 11,
                                  color: Color(0xFF94A3B8),
                                ),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    item.locationDetail.isNotEmpty ? item.locationDetail : item.sede,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 5. Feed Header Row
  Widget _buildFeedFilterHeader(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : ZanateColors.subtleBorder,
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${_listings.length} publicaciones disponibles',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          InkWell(
            onTap: () {
              setState(() => _onlyFree = !_onlyFree);
              _loadData();
            },
            borderRadius: BorderRadius.circular(6),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _onlyFree
                    ? ZanateColors.zanateAccent
                    : (isDark ? const Color(0xFF0F172A) : ZanateColors.surfaceBg),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _onlyFree
                      ? ZanateColors.zanateAccent
                      : (isDark ? const Color(0xFF334155) : ZanateColors.subtleBorder),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _onlyFree ? PhosphorIconsFill.checkCircle : PhosphorIconsRegular.gift,
                    size: 13,
                    color: _onlyFree ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Solo Gratis',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: _onlyFree ? FontWeight.w700 : FontWeight.w500,
                      color: _onlyFree ? Colors.white : (isDark ? const Color(0xFFE2E8F0) : ZanateColors.zanateDark),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsFeed(bool isDark) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_listings.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        children: const [
          EmptyStateWidget(
            icon: PhosphorIconsRegular.storefront,
            title: 'No hay publicaciones para estas preferencias',
            description:
                'Prueba ajustando tus preferencias de búsqueda o usa el botón + superior para publicar un anuncio.',
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: _listings.length,
      itemBuilder: (ctx, i) {
        final item = _listings[i];
        return MarketplaceCard(
          key: ValueKey(item.id),
          item: item,
          isOwner: item.isMine ||
              (item.userId != null &&
                  item.userId == SupabaseService.currentUserId),
          onUpvote: () => _handleToggleUpvote(item),
          onStatusChanged: (newStatus) =>
              _handleUpdateItemStatus(item, newStatus),
          onSponsoredHide: () => _hideSponsoredItem(item),
          onReport: (reason) => _handleReportItem(item, reason),
          onShare: () => _handleShareListing(item),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      body: Column(
        children: [
          // 1. Squared Top Header: Clean, Simple, Centered Title without symbol box, Gear for Settings on Left
          _buildSquaredHeader(isDark),

          // 2. Search & Filters Bar (Ubicación por Sede + Facultad + Carrera)
          _buildSearchAndFilters(isDark, isDesktop),

          // 3. eBay "Compra por categorías"
          _buildEbayCategoriesSection(isDark),

          // 4. eBay "Ofertas y Aportes del Día"
          _buildEbayDealsSection(isDark),

          // Sponsor VIP Showcase (if any)
          if (_sponsoredListings.isNotEmpty) ...[
            SponsorCarousel(
              sponsoredItems: _sponsoredListings,
              onRequestSponsor: _openSponsorRequestDialog,
              onHideSponsored: _hideSponsoredItem,
              onReportSponsored: _handleReportItem,
            ),
          ],

          // 5. Feed Filter Header
          _buildFeedFilterHeader(isDark),

          // Offline Banner if degraded network
          if (_isOffline) ...[
            OfflineBanner(onRetry: _loadData),
          ],

          // 6. Squared Full-Width Feed (ListView with 1px border dividers)
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: _buildPostsFeed(isDark),
            ),
          ),
        ],
      ),
      floatingActionButton: null,
    );
  }
}
