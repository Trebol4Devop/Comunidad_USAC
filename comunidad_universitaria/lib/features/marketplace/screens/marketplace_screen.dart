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
import '../marketplace_theme.dart';
import '../widgets/create_listing_dialog.dart';
import '../widgets/marketplace_card.dart';
import '../widgets/marketplace_plans_sheet.dart';
import '../widgets/sponsor_carousel.dart';
import '../widgets/sponsor_request_dialog.dart';
import '../../shared/widgets/auth_modal.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../../shared/widgets/network_state_widgets.dart';
import '../../shared/widgets/settings_bottom_sheet.dart';
import 'my_sales_screen.dart';
import 'product_detail_screen.dart';
import 'saved_listings_screen.dart';
import 'store_profile_screen.dart';

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
  String _selectedBuilding = 'todos';
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
          buildingCode: _selectedBuilding != 'todos' ? _selectedBuilding : null,
          onlyFree: _onlyFree,
          searchQuery: _searchQuery,
        ),
        MarketplaceService.fetchSponsoredListings(
          sede: _selectedSede != 'todas' ? _selectedSede : null,
        ),
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

    await ShareCountService.incrementShare(item.id);

    final shareText =
        '${item.title} - ${item.formattedPrice}\n\n${item.description}\n\nUbicación: ${item.locationDetail.isNotEmpty ? item.locationDetail : item.sede}\n— Publicado por ${item.authorAlias} en Comunidad USAC';
    try {
      await SharePlus.instance.share(
        ShareParams(text: shareText, subject: item.title),
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: shareText));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Publicación compartida ($newCount veces). El enlace se copió al portapapeles.',
          ),
          backgroundColor: ZanateColors.zanateAccent,
        ),
      );
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

  Future<void> _handleToggleBookmark(MarketplaceItem item) async {
    if (SupabaseConfig.isConfigured && !SupabaseService.isAuthenticated) {
      AuthModal.show(
        context,
        title: 'Inicia sesión para guardar',
        subtitle:
            'Para guardar este producto en tus marcadores debes iniciar sesión.',
        onAuthenticated: () => _handleToggleBookmark(item),
      );
      return;
    }

    final prev = item.isBookmarked;
    setState(() {
      final idx = _listings.indexWhere((l) => l.id == item.id);
      if (idx != -1) {
        _listings[idx] = item.copyWith(isBookmarked: !prev);
      }
    });

    try {
      final res = await MarketplaceService.toggleBookmark(item.id);
      if (mounted && res != !prev) {
        setState(() {
          final idx = _listings.indexWhere((l) => l.id == item.id);
          if (idx != -1) {
            _listings[idx] = item.copyWith(isBookmarked: res);
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          final idx = _listings.indexWhere((l) => l.id == item.id);
          if (idx != -1) {
            _listings[idx] = item.copyWith(isBookmarked: prev);
          }
        });
      }
    }
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
      MarketplaceSellerStatus? status;
      try {
        status = await MarketplaceService.fetchMyStatus();
      } catch (_) {
        // En offline o sin conexión a Supabase, status será nulo.
      }
      if (!mounted) return;

      final currentStatus = status;
      if (currentStatus != null &&
          !currentStatus.isUnlimited &&
          currentStatus.activeItems >= currentStatus.maxActiveItems) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Límite de publicaciones alcanzado'),
            content: Text(
              'Has alcanzado el límite de ${currentStatus.maxActiveItems} publicaciones activas de tu plan ${currentStatus.planName}. Puedes mejorar tu plan para publicar más.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cerrar'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  MarketplacePlansSheet.show(context);
                },
                child: const Text('Conocer planes'),
              ),
            ],
          ),
        );
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Verificación necesaria'),
          content: Text(
            (status != null && status.reason.isNotEmpty)
                ? status.reason
                : 'Para publicar anuncios se requiere una verificación institucional real. '
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

  void _openSavedListings() {
    if (SupabaseConfig.isConfigured && !SupabaseService.isAuthenticated) {
      AuthModal.show(
        context,
        title: 'Inicia sesión para ver tus guardados',
        subtitle:
            'Para acceder a tus productos guardados debes iniciar sesión.',
        onAuthenticated: _openSavedListings,
      );
      return;
    }
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SavedListingsScreen()));
  }

  void _openMySales() {
    if (SupabaseConfig.isConfigured && !SupabaseService.isAuthenticated) {
      AuthModal.show(
        context,
        title: 'Inicia sesión para ver tus ventas',
        subtitle:
            'Para gestionar tus publicaciones y presencia debes iniciar sesión.',
        onAuthenticated: _openMySales,
      );
      return;
    }
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const MySalesScreen()));
  }

  // Top Squared Header with Settings, Navigation Actions & Publish
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
          // Settings button
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

          // Title
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

          // Saved Listings shortcut
          IconButton(
            tooltip: 'Productos guardados',
            onPressed: _openSavedListings,
            icon: Icon(
              PhosphorIconsRegular.bookmarkSimple,
              size: 20,
              color: isDark ? Colors.white : ZanateColors.zanateDark,
            ),
            splashRadius: 22,
          ),

          // My Sales shortcut
          IconButton(
            tooltip: 'Mis ventas',
            onPressed: _openMySales,
            icon: Icon(
              PhosphorIconsRegular.storefront,
              size: 20,
              color: isDark ? Colors.white : ZanateColors.zanateDark,
            ),
            splashRadius: 22,
          ),

          // Publish button
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

  // Franja promocional superior (UX-MKT-001) con la estética cuadrada del
  // catálogo: superficie plana, borde inferior de 0.8px y sin degradados.
  Widget _buildTopBanner(bool isDark, bool isDesktop) {
    final textColor = isDark ? Colors.white : ZanateColors.zanateDark;
    final mutedColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
          Container(width: 4, height: 34, color: ZanateColors.zanateAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'Marketplace & Tutorías Estudiantiles',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      color: textColor,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Espacio libre para emprendimientos sancarlistas: comidas, postres, tutorías de cursos y materiales universitarios. Trato directo, sin comisiones.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: mutedColor,
                    fontSize: 11.5,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          if (isDesktop) ...[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: ZanateColors.zanateAccent,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              onPressed: () => MarketplacePlansSheet.show(context),
              child: const Text(
                'Conocer planes',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              style: TextButton.styleFrom(
                backgroundColor: ZanateColors.zanateAccent,
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
              ),
              onPressed: _handleCreateListingClick,
              icon: const Icon(Icons.add_shopping_cart, size: 16),
              label: const Text(
                'Publicar Anuncio',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
          ] else
            InkWell(
              onTap: () => MarketplacePlansSheet.show(context),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Text(
                  'Ver planes',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: ZanateColors.zanateAccent,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Barra de búsqueda y filtros facetados (UX-MKT-004) con la estética
  // cuadrada y plana del catálogo.
  Widget _buildSearchAndFilters(bool isDark, bool isDesktop) {
    final containerBg = isDark
        ? const Color(0xFF0F172A)
        : ZanateColors.surfaceBg;
    final borderColor = isDark
        ? const Color(0xFF334155)
        : ZanateColors.subtleBorder;
    final textColor = isDark ? Colors.white : ZanateColors.zanateDark;

    OutlineInputBorder squareBorder(Color color, [double width = 0.8]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(bottom: BorderSide(color: borderColor, width: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Campo de búsqueda
          TextField(
            controller: _searchController,
            style: TextStyle(fontSize: 13, color: textColor),
            decoration: InputDecoration(
              hintText: 'Buscar postres, almuerzos, tutorías o libros...',
              hintStyle: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF94A3B8),
              ),
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      splashRadius: 16,
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                        _loadData();
                      },
                    )
                  : null,
              filled: true,
              fillColor: containerBg,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: squareBorder(borderColor),
              enabledBorder: squareBorder(borderColor),
              focusedBorder: squareBorder(ZanateColors.zanateAccent, 1.2),
            ),
            onSubmitted: (val) {
              setState(() => _searchQuery = val.trim());
              _loadData();
            },
          ),
          const SizedBox(height: 8),

          // Filtros: Sede, Facultad y Edificio
          if (isDesktop)
            Row(
              children: [
                Expanded(child: _buildSedeDropdown()),
                const SizedBox(width: 8),
                Expanded(child: _buildFacultadDropdown()),
                const SizedBox(width: 8),
                Expanded(child: _buildBuildingDropdown()),
              ],
            )
          else
            Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildSedeDropdown()),
                    const SizedBox(width: 8),
                    Expanded(child: _buildFacultadDropdown()),
                  ],
                ),
                const SizedBox(height: 8),
                _buildBuildingDropdown(),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSedeDropdown() {
    return DropdownButtonFormField<String>(
      key: ValueKey('sede_$_selectedSede'),
      initialValue: _selectedSede,
      isExpanded: true,
      decoration: InputDecoration(
        hintText: 'Sede / Campus',
        hintStyle: const TextStyle(fontSize: 11),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.8,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.8,
          ),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: ZanateColors.zanateAccent, width: 1.2),
        ),
      ),
      style: TextStyle(
        fontSize: 11,
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : ZanateColors.zanateDark,
      ),
      items: USACConstants.sedes
          .map(
            (s) => DropdownMenuItem<String>(
              value: s['id']!,
              child: Text(
                s['nombre']!,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11),
              ),
            ),
          )
          .toList(),
      onChanged: (val) {
        setState(() {
          _selectedSede = val ?? 'todas';
          if (_selectedBuilding != 'todos' && _selectedSede != 'todas') {
            final validBuildings = USACConstants.campusBuildings
                .where((b) => b['sede_id'] == _selectedSede)
                .map((b) => b['building_code']?.toString());
            if (!validBuildings.contains(_selectedBuilding)) {
              _selectedBuilding = 'todos';
            }
          }
        });
        _loadData();
      },
    );
  }

  Widget _buildFacultadDropdown() {
    return DropdownButtonFormField<String>(
      key: ValueKey('facultad_$_selectedFacultad'),
      initialValue: _selectedFacultad,
      isExpanded: true,
      decoration: InputDecoration(
        hintText: 'Facultad / Unidad',
        hintStyle: const TextStyle(fontSize: 11),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.8,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.8,
          ),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: ZanateColors.zanateAccent, width: 1.2),
        ),
      ),
      style: TextStyle(
        fontSize: 11,
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : ZanateColors.zanateDark,
      ),
      items: USACConstants.facultades
          .map(
            (f) => DropdownMenuItem<String>(
              value: f['id'].toString(),
              child: Text(
                f['nombre'].toString(),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11),
              ),
            ),
          )
          .toList(),
      onChanged: (val) {
        setState(() => _selectedFacultad = val ?? 'todas');
        _loadData();
      },
    );
  }

  Widget _buildBuildingDropdown() {
    final buildings = USACConstants.campusBuildings
        .where((b) => _selectedSede == 'todas' || b['sede_id'] == _selectedSede)
        .toList();

    return DropdownButtonFormField<String>(
      key: ValueKey('building_${_selectedSede}_$_selectedBuilding'),
      initialValue: _selectedBuilding,
      isExpanded: true,
      decoration: InputDecoration(
        hintText: 'Edificio / Inmueble',
        hintStyle: const TextStyle(fontSize: 11),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.8,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.8,
          ),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: ZanateColors.zanateAccent, width: 1.2),
        ),
      ),
      style: TextStyle(
        fontSize: 11,
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : ZanateColors.zanateDark,
      ),
      items: [
        const DropdownMenuItem<String>(
          value: 'todos',
          child: Text('Todos los edificios', style: TextStyle(fontSize: 11)),
        ),
        ...buildings.map(
          (b) => DropdownMenuItem<String>(
            value: b['building_code']?.toString() ?? '',
            child: Text(
              '${b['building_code']} · ${b['nombre']}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ),
      ],
      onChanged: (val) {
        setState(() => _selectedBuilding = val ?? 'todos');
        _loadData();
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
        return (icon: PhosphorIconsBold.tag, subtitle: 'Tecnología y varios');
      case 'todos':
      default:
        return (
          icon: PhosphorIconsBold.squaresFour,
          subtitle: 'Ver todo el catálogo',
        );
    }
  }

  // Sección "Compra por Categorías" con tiles cuadrados.
  Widget _buildEbayCategoriesSection(bool isDark) {
    final categories = <({String id, String label})>[
      (id: 'todos', label: 'Todos'),
      ...USACConstants.marketplaceCategories.map(
        (c) => (id: c.id, label: c.label),
      ),
    ];

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
              children: categories.map((cat) {
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? ZanateColors.zanateAccent.withValues(
                                alpha: isDark ? 0.25 : 0.08,
                              )
                            : (isDark
                                  ? const Color(0xFF0F172A)
                                  : ZanateColors.surfaceBg),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? ZanateColors.zanateAccent
                              : (isDark
                                    ? const Color(0xFF334155)
                                    : ZanateColors.subtleBorder),
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
                                : (isDark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            cat.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w700,
                              color: isSelected
                                  ? ZanateColors.zanateAccent
                                  : (isDark
                                        ? Colors.white
                                        : ZanateColors.zanateDark),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            visuals.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
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

  // Sección "Ofertas y Aportes del Día" con carrusel horizontal.
  Widget _buildEbayDealsSection(bool isDark) {
    final deals = _listings
        .where((item) => item.isFree || item.upvotes > 0)
        .take(8)
        .toList();

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
                    color: isDark
                        ? const Color(0xFF0F172A)
                        : ZanateColors.surfaceBg,
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF334155)
                          : ZanateColors.subtleBorder,
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
                                  child: Icon(
                                    visuals.icon,
                                    size: 24,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                ),
                              )
                            : Center(
                                child: Icon(
                                  visuals.icon,
                                  size: 24,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: item.isFree
                                    ? const Color(0xFF059669)
                                    : ZanateColors.zanateAccent,
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
                                color: isDark
                                    ? Colors.white
                                    : ZanateColors.zanateDark,
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
                                    item.locationDetail.isNotEmpty
                                        ? item.locationDetail
                                        : item.sede,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF94A3B8),
                                    ),
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

  // Encabezado del feed: conteo de publicaciones y filtro de gratuitos.
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
        children: [
          Expanded(
            child: Text(
              '${_listings.length} publicaciones disponibles',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(width: 8),
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
                    : (isDark
                          ? const Color(0xFF0F172A)
                          : ZanateColors.surfaceBg),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _onlyFree
                      ? ZanateColors.zanateAccent
                      : (isDark
                            ? const Color(0xFF334155)
                            : ZanateColors.subtleBorder),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _onlyFree
                        ? PhosphorIconsFill.checkCircle
                        : PhosphorIconsRegular.gift,
                    size: 13,
                    color: _onlyFree
                        ? Colors.white
                        : (isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B)),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Solo Gratuitos',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: _onlyFree ? FontWeight.w700 : FontWeight.w500,
                      color: _onlyFree
                          ? Colors.white
                          : (isDark
                                ? const Color(0xFFE2E8F0)
                                : ZanateColors.zanateDark),
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
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        children: [
          EmptyStateWidget(
            icon: PhosphorIconsRegular.storefront,
            title: 'No hay publicaciones en esta categoría aún',
            description:
                'Prueba ajustando tus preferencias de búsqueda o usa el botón para publicar un anuncio.',
            buttonText: 'Crear Primera Publicación',
            onButtonPressed: _handleCreateListingClick,
          ),
        ],
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _listings.length,
      separatorBuilder: (_, _) => const SizedBox.shrink(),
      itemBuilder: (ctx, i) {
        final item = _listings[i];
        return MarketplaceCard(
          key: ValueKey(item.id),
          item: item,
          isOwner:
              item.isMine ||
              (item.userId != null &&
                  item.userId == SupabaseService.currentUserId),
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    ProductDetailScreen(itemId: item.id, initialItem: item),
              ),
            );
            _loadData();
          },
          onOpenStore: item.sellerPublicId != null
              ? () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => StoreProfileScreen(
                        sellerPublicId: item.sellerPublicId!,
                      ),
                    ),
                  );
                }
              : null,
          onToggleBookmark: () => _handleToggleBookmark(item),
          onShowPlans: () => MarketplacePlansSheet.show(context),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDesktop = Responsive.isDesktop(context);

    return MarketplaceTheme.wrap(
      context,
      Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        body: Column(
          children: [
            // 1. Cabecera cuadrada
            _buildSquaredHeader(isDark),

            // 2. Búsqueda y filtros (fijos, como en el catálogo eBay)
            _buildSearchAndFilters(isDark, isDesktop),

            // 3. Contenido desplazable: franja promocional, categorías,
            // ofertas, patrocinios y feed a ancho completo.
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Franja promocional (UX-MKT-001)
                      _buildTopBanner(isDark, isDesktop),

                      // Compra por categorías (estilo eBay)
                      _buildEbayCategoriesSection(isDark),

                      // Ofertas y aportes del día (estilo eBay)
                      _buildEbayDealsSection(isDark),

                      // Carrusel de patrocinadores (UX-MKT-002)
                      SponsorCarousel(
                        sponsoredItems: _sponsoredListings,
                        onRequestSponsor: _openSponsorRequestDialog,
                        onHideSponsored: _hideSponsoredItem,
                        onReportSponsored: _handleReportItem,
                      ),

                      // Aviso de modo offline
                      if (_isOffline) OfflineBanner(onRetry: _loadData),

                      // Encabezado del feed con conteo y filtro de gratuitos
                      _buildFeedFilterHeader(isDark),

                      // Feed de publicaciones
                      _buildPostsFeed(isDark),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: widget.showFloatingActionButton
            ? FloatingActionButton.extended(
                heroTag: 'marketplace_fab',
                onPressed: _handleCreateListingClick,
                backgroundColor: ZanateColors.zanateAccent,
                foregroundColor: Colors.white,
                elevation: 2,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
                icon: const Icon(PhosphorIconsBold.plus, size: 18),
                label: const Text(
                  'Publicar Anuncio',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              )
            : null,
      ),
    );
  }
}
