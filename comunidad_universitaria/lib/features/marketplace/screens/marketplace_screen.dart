import 'package:flutter/material.dart';
import '../../../core/constants/categories.dart';
import '../../../core/models/marketplace_item.dart';
import '../../../core/services/marketplace_service.dart';
import '../../../core/utils/responsive.dart';
import '../widgets/create_listing_dialog.dart';
import '../widgets/marketplace_card.dart';
import '../widgets/sponsor_carousel.dart';
import '../widgets/sponsor_request_dialog.dart';
import '../../shared/widgets/empty_state_widget.dart';

class MarketplaceScreen extends StatefulWidget {
  final String activeAlias;
  final Function(String newAlias) onAliasChanged;

  const MarketplaceScreen({
    super.key,
    required this.activeAlias,
    required this.onAliasChanged,
  });

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  List<MarketplaceItem> _listings = [];
  List<MarketplaceItem> _sponsoredListings = [];
  bool _isLoading = true;

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

    if (mounted) {
      setState(() {
        _listings = results[0];
        _sponsoredListings = results[1];
        _isLoading = false;
      });
    }
  }

  Future<void> _handleToggleUpvote(MarketplaceItem item) async {
    final prevUpvoted = item.isUpvotedByMe;
    final prevUpvotes = item.upvotes;

    // Optimistic UI update
    setState(() {
      final idx = _listings.indexWhere((l) => l.id == item.id);
      if (idx != -1) {
        _listings[idx] = item.copyWith(
          isUpvotedByMe: !prevUpvoted,
          upvotes: prevUpvoted ? (prevUpvotes - 1).clamp(0, 999999) : prevUpvotes + 1,
        );
      }
    });

    final success = await MarketplaceService.toggleUpvote(item);
    if (mounted && success != !prevUpvoted) {
      setState(() {
        final idx = _listings.indexWhere((l) => l.id == item.id);
        if (idx != -1) {
          _listings[idx] = item.copyWith(isUpvotedByMe: prevUpvoted, upvotes: prevUpvotes);
        }
      });
    }
  }

  void _openCreateDialog() {
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

  void _openSponsorRequestDialog() {
    SponsorRequestDialog.show(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = Responsive.isDesktop(context);

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
                  padding: const EdgeInsets.all(20),
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
                            const Text(
                              'Marketplace & Tutorías Estudiantiles',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Espacio libre para emprendimientos sancarlistas: comidas, postres, tutorías de cursos y materiales universitarios.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 13,
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
                          ),
                          onPressed: _openCreateDialog,
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
                ),

                // Search & Sede Dropdown
                Row(
                  children: [
                    Expanded(
                      child: TextField(
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
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                      constraints: BoxConstraints(maxWidth: isDesktop ? 200 : 130),
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedSede,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        ),
                        items: USACConstants.sedes
                            .map((s) => DropdownMenuItem<String>(
                                  value: s['id']!,
                                  child: Text(
                                    s['nombre']!,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ))
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
                      constraints: BoxConstraints(maxWidth: isDesktop ? 200 : 130),
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedFacultad,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        ),
                        items: USACConstants.facultades
                            .map((f) => DropdownMenuItem<String>(
                                  value: f['id'].toString(),
                                  child: Text(
                                    f['nombre'].toString(),
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ))
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

                const SizedBox(height: 12),

                // Category Chips and Free filter
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Solo Gratis toggle chip
                      FilterChip(
                        avatar: Icon(
                          _onlyFree ? Icons.check_circle : Icons.volunteer_activism_outlined,
                          size: 16,
                          color: _onlyFree ? Colors.white : const Color(0xFF16A34A),
                        ),
                        label: const Text('Solo Gratuitos'),
                        selected: _onlyFree,
                        selectedColor: const Color(0xFF16A34A),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _onlyFree ? Colors.white : const Color(0xFF16A34A),
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
                            selectedColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? theme.colorScheme.primary : null,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Feed of listings
                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_listings.isEmpty)
                  EmptyStateWidget(
                    icon: Icons.storefront_outlined,
                    title: 'No hay publicaciones en esta categoría',
                    description: '¿Ofreces tutorías, almuerzos, postres o libros universitarios? ¡Publica tu anuncio libremente!',
                    buttonText: 'Crear Primera Publicación',
                    onButtonPressed: _openCreateDialog,
                  )
                else
                  Responsive(
                    mobile: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _listings.length,
                      itemBuilder: (ctx, i) {
                        final item = _listings[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: MarketplaceCard(
                            item: item,
                            onUpvote: () => _handleToggleUpvote(item),
                            onReport: (reason) {
                              MarketplaceService.reportListing(itemId: item.id, reason: reason);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Reporte recibido con éxito.')),
                              );
                            },
                          ),
                        );
                      },
                    ),
                    desktop: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                          onUpvote: () => _handleToggleUpvote(item),
                          onReport: (reason) {
                            MarketplaceService.reportListing(itemId: item.id, reason: reason);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Reporte recibido con éxito.')),
                            );
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateDialog,
        backgroundColor: const Color(0xFF004B87),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_business),
        label: const Text('Publicar Anuncio'),
      ),
    );
  }
}
