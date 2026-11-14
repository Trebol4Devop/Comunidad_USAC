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
        subtitle: 'Para guardar este producto en tus marcadores debes iniciar sesión.',
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
        subtitle: 'Para acceder a tus productos guardados debes iniciar sesión.',
        onAuthenticated: _openSavedListings,
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SavedListingsScreen()),
    );
  }

  void _openMySales() {
    if (SupabaseConfig.isConfigured && !SupabaseService.isAuthenticated) {
      AuthModal.show(
        context,
        title: 'Inicia sesión para ver tus ventas',
        subtitle: 'Para gestionar tus publicaciones y presencia debes iniciar sesión.',
        onAuthenticated: _openMySales,
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MySalesScreen()),
    );
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

  // Top Banner (UX-MKT-001)
  Widget _buildTopBanner(bool isDark, bool isDesktop) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF004B87), Color(0xFF1E3A8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: const Text(
                    'Marketplace & Tutorías Estudiantiles',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Espacio libre para emprendimientos sancarlistas: comidas, postres, tutorías de cursos y materiales universitarios. Trato directo, sin comisiones.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => MarketplacePlansSheet.show(context),
                  child: const Text(
                    'Conocer planes',
                    style: TextStyle(
                      color: Color(0xFFFDE68A),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                      decorationColor: Color(0xFFFDE68A),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isDesktop) ...[
            const SizedBox(width: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEAB308),
                foregroundColor: Colors.black87,
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onPressed: _handleCreateListingClick,
              icon: const Icon(Icons.add_shopping_cart, size: 18),
              label: const Text(
                'Publicar Anuncio',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Search and Faceted Filters (UX-MKT-004)
  Widget _buildSearchAndFilters(bool isDark, bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search Input
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Buscar postres, almuerzos, tutorías o libros...',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                      _loadData();
                    },
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF334155) : ZanateColors.subtleBorder,
              ),
            ),
          ),
          onSubmitted: (val) {
            setState(() => _searchQuery = val.trim());
            _loadData();
          },
        ),
        const SizedBox(height: 10),

        // Dropdowns: Sede, Facultad, Edificio
        if (isDesktop)
          Row(
            children: [
              Expanded(child: _buildSedeDropdown()),
              const SizedBox(width: 10),
              Expanded(child: _buildFacultadDropdown()),
              const SizedBox(width: 10),
              Expanded(child: _buildBuildingDropdown()),
              const SizedBox(width: 10),
              _buildFreeChip(isDark),
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
              Row(
                children: [
                  Expanded(child: _buildBuildingDropdown()),
                  const SizedBox(width: 8),
                  _buildFreeChip(isDark),
                ],
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildSedeDropdown() {
    return DropdownButtonFormField<String>(
      key: ValueKey('sede_$_selectedSede'),
      initialValue: _selectedSede,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Sede / Campus',
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
      decoration: const InputDecoration(
        labelText: 'Facultad / Unidad',
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
      decoration: const InputDecoration(
        labelText: 'Edificio / Inmueble',
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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

  Widget _buildFreeChip(bool isDark) {
    return FilterChip(
      selected: _onlyFree,
      avatar: Icon(
        _onlyFree ? Icons.check_circle : Icons.volunteer_activism_outlined,
        size: 16,
        color: _onlyFree ? Colors.white : const Color(0xFF16A34A),
      ),
      label: const Text('Solo Gratuitos'),
      labelStyle: TextStyle(
        color: _onlyFree ? Colors.white : (isDark ? Colors.white : ZanateColors.zanateDark),
        fontWeight: _onlyFree ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      selectedColor: const Color(0xFF16A34A),
      onSelected: (val) {
        setState(() => _onlyFree = val);
        _loadData();
      },
    );
  }

  // Category Filter Chips
  Widget _buildCategoryChips(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: USACConstants.marketplaceCategories.map((cat) {
          final isSelected = _selectedCategory == cat.id;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              label: Text(cat.label),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
              selectedColor: ZanateColors.zanateAccent,
              onSelected: (_) {
                setState(() => _selectedCategory = cat.id);
                _loadData();
              },
            ),
          );
        }).toList(),
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
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final item = _listings[i];
        return MarketplaceCard(
          key: ValueKey(item.id),
          item: item,
          isOwner: item.isMine ||
              (item.userId != null &&
                  item.userId == SupabaseService.currentUserId),
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProductDetailScreen(
                  itemId: item.id,
                  initialItem: item,
                ),
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

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : ZanateColors.surfaceBg,
      body: Column(
        children: [
          // Squared Header
          _buildSquaredHeader(isDark),

          // Main Scrollable Area
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: MaxWidthContainer(
                  maxWidth: 1100,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Top Banner (UX-MKT-001)
                      _buildTopBanner(isDark, isDesktop),
                      const SizedBox(height: 16),

                      // Sponsor Carousel (UX-MKT-002)
                      SponsorCarousel(
                        sponsoredItems: _sponsoredListings,
                        onRequestSponsor: _openSponsorRequestDialog,
                        onHideSponsored: _hideSponsoredItem,
                        onReportSponsored: _handleReportItem,
                      ),
                      const SizedBox(height: 12),

                      // Search and Faceted Filters (UX-MKT-004)
                      _buildSearchAndFilters(isDark, isDesktop),
                      const SizedBox(height: 12),

                      // Category Filters
                      _buildCategoryChips(isDark),
                      const SizedBox(height: 14),

                      // Offline notice if applicable
                      if (_isOffline) ...[
                        OfflineBanner(onRetry: _loadData),
                        const SizedBox(height: 12),
                      ],

                      // Feed
                      _buildPostsFeed(isDark),
                    ],
                  ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              icon: const Icon(PhosphorIconsBold.plus, size: 18),
              label: const Text(
                'Publicar Anuncio',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            )
          : null,
    );
  }
}
