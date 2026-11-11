import 'package:flutter/material.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/constants/categories.dart';
import '../../../core/models/marketplace_item.dart';
import '../../../core/services/marketplace_service.dart';
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

class MarketplaceScreen extends StatefulWidget {
  final String activeAlias;
  final Function(String newAlias) onAliasChanged;
  final bool showFloatingActionButton;

  const MarketplaceScreen({
    super.key,
    required this.activeAlias,
    required this.onAliasChanged,
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

      if (mounted) {
        setState(() {
          _listings = results[0]
              .where(
                (item) =>
                    !item.isSponsored || !hiddenSponsoredIds.contains(item.id),
              )
              .toList();
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

    // Optimistic UI update
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
        backgroundColor: Color(0xFF004B87),
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
            'Para publicar anuncios se requiere una verificación institucional real. '
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = Responsive.isDesktop(context);
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: MaxWidthContainer(
            maxWidth: 1100,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.brightness == Brightness.dark
                          ? const Color(0xFF303030)
                          : const Color(0xFFD9D9D9),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Marketplace & Tutorías Estudiantiles',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Espacio libre para emprendimientos sancarlistas: comidas, postres, tutorías de cursos y materiales universitarios.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isDesktop) ...[
                        const SizedBox(width: 16),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.colorScheme.onSurface,
                            side: BorderSide(
                              color: theme.brightness == Brightness.dark
                                  ? Colors.white38
                                  : Colors.black54,
                            ),
                          ),
                          onPressed: _handleCreateListingClick,
                          icon: const Icon(Icons.add_shopping_cart, size: 18),
                          label: const Text('Publicar Anuncio'),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Sponsor VIP / First plane Showcase
                SponsorCarousel(
                  sponsoredItems: _sponsoredListings,
                  onRequestSponsor: _openSponsorRequestDialog,
                  onHideSponsored: _hideSponsoredItem,
                  onReportSponsored: _handleReportItem,
                ),

                // Search & Filter Dropdowns
                if (isMobile) ...[
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText:
                          'Buscar postres, almuerzos, tutorías o libros...',
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
                    ),
                    onSubmitted: (val) {
                      setState(() => _searchQuery = val);
                      _loadData();
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Sede Selector
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedSede,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Sede / Campus',
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
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
                            });
                            _loadData();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Faculty Selector
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedFacultad,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Facultad / Unidad',
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
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
                            setState(() {
                              _selectedFacultad = val ?? 'todas';
                            });
                            _loadData();
                          },
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText:
                                'Buscar postres, almuerzos, tutorías o libros...',
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
                          ),
                          onSubmitted: (val) {
                            setState(() => _searchQuery = val);
                            _loadData();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Sede Selector
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 180),
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedSede,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 10,
                            ),
                          ),
                          items: USACConstants.sedes
                              .map(
                                (s) => DropdownMenuItem<String>(
                                  value: s['id']!,
                                  child: Text(
                                    s['nombre']!,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedSede = val ?? 'todas';
                            });
                            _loadData();
                          },
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Faculty Selector
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 180),
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedFacultad,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 10,
                            ),
                          ),
                          items: USACConstants.facultades
                              .map(
                                (f) => DropdownMenuItem<String>(
                                  value: f['id'].toString(),
                                  child: Text(
                                    f['nombre'].toString(),
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedFacultad = val ?? 'todas';
                            });
                            _loadData();
                          },
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 12),

                // Category Chips and Free filter
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Solo Gratis toggle chip
                      FilterChip(
                        avatar: Icon(
                          _onlyFree
                              ? Icons.check_circle
                              : Icons.volunteer_activism_outlined,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        label: const Text('Solo Gratuitos'),
                        selected: _onlyFree,
                        selectedColor: theme.colorScheme.surface,
                        showCheckmark: false,
                        side: BorderSide(
                          color: _onlyFree
                              ? theme.colorScheme.onSurface
                              : theme.dividerColor,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                        onSelected: (selected) {
                          setState(() => _onlyFree = selected);
                          _loadData();
                        },
                      ),
                      const SizedBox(width: 8),

                      // Category Chips
                      ...USACConstants.marketplaceCategories.map((cat) {
                        final isSelected = _selectedCategory == cat.id;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(cat.label),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                _selectedCategory = cat.id;
                              });
                              _loadData();
                            },
                            selectedColor: theme.colorScheme.surface,
                            showCheckmark: false,
                            side: BorderSide(
                              color: isSelected
                                  ? theme.colorScheme.onSurface
                                  : theme.dividerColor,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Offline Banner if degraded network
                if (_isOffline) ...[
                  OfflineBanner(onRetry: _loadData),
                  const SizedBox(height: 12),
                ],

                // Feed of listings
                if (_isLoading)
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 4,
                    itemBuilder: (ctx, i) => const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: SkeletonCard(height: 220),
                    ),
                  )
                else if (_listings.isEmpty)
                  EmptyStateWidget(
                    icon: Icons.storefront_outlined,
                    title: 'No hay publicaciones en esta categoría aún',
                    description:
                        '¿Ofreces tutorías, almuerzos, postres o libros universitarios? ¡Sé el primero en publicar!',
                    buttonText: 'Crear Primera Publicación',
                    onButtonPressed: _handleCreateListingClick,
                  )
                else
                  Responsive(
                    mobile: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _listings.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        thickness: 1,
                        color: Theme.of(
                          context,
                        ).dividerColor.withValues(alpha: 0.6),
                      ),
                      itemBuilder: (ctx, i) {
                        final item = _listings[i];
                        return MarketplaceCard(
                          item: item,
                          isOwner:
                              item.isMine ||
                              (item.userId != null &&
                                  item.userId == SupabaseService.currentUserId),
                          onUpvote: () => _handleToggleUpvote(item),
                          onStatusChanged: (newStatus) =>
                              _handleUpdateItemStatus(item, newStatus),
                          onSponsoredHide: () => _hideSponsoredItem(item),
                          onReport: (reason) => _handleReportItem(item, reason),
                        );
                      },
                    ),
                    desktop: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 0.78,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                      itemCount: _listings.length,
                      itemBuilder: (ctx, i) {
                        final item = _listings[i];
                        return MarketplaceCard(
                          item: item,
                          isOwner:
                              item.isMine ||
                              (item.userId != null &&
                                  item.userId == SupabaseService.currentUserId),
                          onUpvote: () => _handleToggleUpvote(item),
                          onStatusChanged: (newStatus) =>
                              _handleUpdateItemStatus(item, newStatus),
                          onSponsoredHide: () => _hideSponsoredItem(item),
                          onReport: (reason) => _handleReportItem(item, reason),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: widget.showFloatingActionButton
          ? FloatingActionButton.extended(
              heroTag: 'marketplace_fab',
              onPressed: _handleCreateListingClick,
              backgroundColor: theme.colorScheme.onSurface,
              foregroundColor: theme.colorScheme.surface,
              icon: const Icon(Icons.add_business),
              label: const Text('Publicar Anuncio'),
            )
          : null,
    );
  }
}
