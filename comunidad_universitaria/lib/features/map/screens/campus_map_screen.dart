import 'dart:async';
import 'package:flutter/material.dart' hide NavigationMode;
import 'package:latlong2/latlong.dart' hide DistanceCalculator;
import 'package:usac_campus_map/usac_campus_map.dart';
import '../../../core/config/app_theme.dart';
import '../../../core/constants/categories.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/url_utils.dart';
import '../../shared/widgets/network_state_widgets.dart';
import '../services/map_sync_service.dart';
import '../services/supabase_campus_community_repository.dart';
import '../widgets/building_3d_viewer.dart';

class CampusMapScreen extends StatefulWidget {
  const CampusMapScreen({super.key});

  @override
  State<CampusMapScreen> createState() => _CampusMapScreenState();
}

class _CampusMapScreenState extends State<CampusMapScreen> {
  late final UsacCampusMapController _controller;
  late final SupabaseCampusCommunityRepository _communityRepo;

  String _selectedCampus = 'Todas';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  NavigationMode _navigationMode = NavigationMode.pedestrian;
  bool _showDirectoryOnly = false;
  bool _isSearching = false;
  StreamSubscription<bool>? _connectivitySub;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _communityRepo = SupabaseCampusCommunityRepository();
    _controller = UsacCampusMapController(
      communityRepository: _communityRepo,
    );
    _controller.addListener(_onControllerChanged);
    _initConnectivity();
    _initMapData();
  }

  void _initConnectivity() async {
    _isOnline = await ConnectivityService.instance.isConnected;
    if (mounted) setState(() {});
    _connectivitySub = ConnectivityService.instance.onConnectivityChanged.listen((isOnline) {
      if (mounted) {
        final wasOffline = !_isOnline;
        setState(() {
          _isOnline = isOnline;
        });
        if (wasOffline && isOnline) {
          MapSyncService.syncMapAssetsIfNeeded();
        }
      }
    });
  }

  Future<void> _initMapData() async {
    // 1. Carga inicial ultrarrápida (desde caché local R2 o assets empaquetados)
    await MapSyncService.loadRepositoryData(_controller.repository);
    await _controller.loadData();
    if (mounted) setState(() {});

    // 2. Sincronización en segundo plano con Cloudflare R2 sin bloquear la UI
    MapSyncService.syncMapAssetsIfNeeded();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  List<Map<String, dynamic>> get _locations {
    final seenCoordinates = <String>{};
    return USACConstants.campusBuildings.where((location) {
      final latitude = location['latitude'];
      final longitude = location['longitude'];
      if (latitude is! num || longitude is! num) return false;
      if (_selectedCampus != 'Todas' &&
          location['sede_id'] != _campusIdFor(_selectedCampus)) {
        return false;
      }
      final coordinates = '$latitude,$longitude';
      return seenCoordinates.add(coordinates);
    }).toList();
  }

  String? _campusIdFor(String campus) => switch (campus) {
    'Campus Central' => 'central',
    'CUM' => 'cum',
    _ => null,
  };

  void _onSearchChanged(String query) {
    setState(() {
      _isSearching = query.trim().isNotEmpty;
    });
    _controller.search(query.trim());
  }

  void _onSearchResultSelected(SearchResult result) {
    _searchFocusNode.unfocus();
    setState(() {
      _isSearching = false;
    });

    if (result.building != null) {
      _focusBuilding(result.building!);
    } else if (result.poi != null) {
      _focusPoi(result.poi!);
    }
  }

  void _focusBuilding(CampusBuilding building) {
    _controller.selectBuilding(building.id);
    _controller.mapController.move(building.center, 17.5);

    // Sincronizar reseñas de Supabase en segundo plano
    _communityRepo.syncFromSupabase(building.id, targetCategory: building.category);

    PoiDetailSheet.show(
      context: context,
      building: building,
      currentFloor: _controller.selectedFloor,
      userLocation: _controller.userLocation,
      theme: _getMapTheme(Theme.of(context).brightness == Brightness.dark),
      communityRepository: _communityRepo,
      onNavigate: (mode) {
        _navigationMode = mode;
        final origin = _controller.userLocation ?? const LatLng(14.5868, -90.5518);
        _controller.findRoute(
          origin: origin,
          destinationId: building.id,
          mode: mode,
        );
      },
    );
  }

  void _focusPoi(CampusPoi poi) {
    _controller.selectPoi(poi);
    final targetLoc = poi.location ??
        _controller.repository.buildingsById[poi.buildingId]?.center;
    if (targetLoc != null) {
      _controller.mapController.move(targetLoc, 18.0);
    }

    _communityRepo.syncFromSupabase(poi.id, targetCategory: poi.category);

    PoiDetailSheet.show(
      context: context,
      poi: poi,
      currentFloor: _controller.selectedFloor,
      userLocation: _controller.userLocation,
      theme: _getMapTheme(Theme.of(context).brightness == Brightness.dark),
      communityRepository: _communityRepo,
      onNavigate: (mode) {
        _navigationMode = mode;
        final origin = _controller.userLocation ?? const LatLng(14.5868, -90.5518);
        _controller.findRoute(
          origin: origin,
          destinationId: poi.id,
          mode: mode,
        );
      },
    );
  }

  Future<void> _handleDirections(Map<String, dynamic> location) async {
    final latitude = location['latitude'] as num;
    final longitude = location['longitude'] as num;
    final destLatLng = LatLng(latitude.toDouble(), longitude.toDouble());

    // Si es del Campus Central, intentamos enlazar con el motor cartográfico interactivo
    if (location['sede_id'] == 'central' && _controller.buildings.isNotEmpty) {
      // Buscar coincidencia por código o distancia
      CampusBuilding? match;
      final code = (location['building_code'] as String? ?? '').toLowerCase();
      try {
        match = _controller.buildings.firstWhere(
          (b) =>
              b.code.toLowerCase() == code ||
              b.id.toLowerCase() == code ||
              b.name.toLowerCase().contains(code),
        );
      } catch (_) {
        // Fallback por proximidad
        match = _controller.buildings.cast<CampusBuilding?>().firstWhere(
              (b) =>
                  b != null &&
                  DistanceCalculator.haversineDistance(b.center, destLatLng) <= 60.0,
              orElse: () => null,
            );
      }

      if (match != null) {
        if (_showDirectoryOnly) {
          setState(() => _showDirectoryOnly = false);
        }
        _focusBuilding(match);
        return;
      }
    }

    // Para CUM u otras ubicaciones externas al campus central, abrir navegación externa
    final url = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '$latitude,$longitude',
      'travelmode': 'walking',
    });
    await UrlUtils.openUrl(context, url.toString());
  }

  void _open3DViewerForSelected() {
    final building = _controller.selectedBuilding;
    if (building == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona un edificio en el mapa para ver su modelo 3D.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final model = UsacBuilding3DModel.fromBuilding(building);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: 500,
          height: 460,
          child: Column(
            children: [
              AppBar(
                title: Text(
                  'Modelo 3D · ${building.name}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
                elevation: 0,
                backgroundColor: Colors.transparent,
              ),
              Expanded(
                child: Building3DViewer(
                  model: model,
                  theme: _getMapTheme(Theme.of(context).brightness == Brightness.dark),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Arrastra para rotar · Pellizca para zoom · ${building.floorsCount} niveles',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  UsacMapTheme _getMapTheme(bool isDark) {
    if (isDark) {
      return UsacMapTheme(
        primaryColor: AppTheme.usacBlueLight,
        accentColor: AppTheme.usacGold,
        buildingDefaultColor: const Color(0x55004B87),
        buildingBorderColor: const Color(0xFF60A5FA),
        buildingSelectedColor: const Color(0x99EAB308),
        buildingSelectedBorderColor: const Color(0xFFF59E0B),
        routeStandardColor: const Color(0xFF38BDF8),
        routeCoveredColor: const Color(0xFF4ADE80),
        routeStairsColor: const Color(0xFFFB923C),
        userLocationColor: const Color(0xFF38BDF8),
        boundaryFillColor: const Color(0x100066CC),
        boundaryBorderColor: const Color(0x400066CC),
        tileUrlTemplate:
            'https://cartodb-basemaps-a.global.ssl.fastly.net/dark_all/{z}/{x}/{y}.png',
      );
    }
    return const UsacMapTheme(
      primaryColor: AppTheme.usacBlue,
      accentColor: AppTheme.usacGold,
      buildingDefaultColor: Color(0x35004B87),
      buildingBorderColor: Color(0xFF004B87),
      buildingSelectedColor: Color(0x80EAB308),
      buildingSelectedBorderColor: Color(0xFFD97706),
      routeStandardColor: Color(0xFF0284C7),
      routeCoveredColor: Color(0xFF16A34A),
      routeStairsColor: Color(0xFFEA580C),
      userLocationColor: Color(0xFF0284C7),
      boundaryFillColor: Color(0x12004B87),
      boundaryBorderColor: Color(0x35004B87),
      tileUrlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMobile = Responsive.isMobile(context);
    final mapTheme = _getMapTheme(isDark);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (!_isOnline)
              OfflineBanner(
                onRetry: () async {
                  final online = await ConnectivityService.instance.isConnected;
                  if (mounted) setState(() => _isOnline = online);
                  if (online) MapSyncService.syncMapAssetsIfNeeded();
                },
              ),
            Expanded(
              child: isMobile
                  ? _buildMobileLayout(context, theme, isDark, mapTheme)
                  : _buildDesktopLayout(context, theme, isDark, mapTheme),
            ),
          ],
        ),
      ),
    );
  }

  /// Vista de Escritorio y Tablets (>= 700px): Split View (Mapa + Directorio)
  Widget _buildDesktopLayout(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    UsacMapTheme mapTheme,
  ) {
    return Row(
      children: [
        // Mapa Interactivo Canvas Principal
        Expanded(
          flex: 6,
          child: Stack(
            children: [
              _buildMapCanvas(mapTheme),
              _buildTopControls(theme, isDark, mapTheme),
              if (_controller.selectedBuilding != null &&
                  _controller.selectedBuilding!.floorsCount > 1)
                Positioned(
                  right: 16,
                  bottom: 24,
                  child: FloorSelector(
                    floorsCount: _controller.selectedBuilding!.floorsCount,
                    selectedFloor: _controller.selectedFloor,
                    theme: mapTheme,
                    onFloorSelected: (f) => _controller.selectFloor(f),
                  ),
                ),
              if (_controller.currentRoute != null)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: TurnByTurnBanner(
                    route: _controller.currentRoute!,
                    trackingState: _controller.navigationTrackingState,
                    theme: mapTheme,
                    onClose: () => _controller.clearRoute(),
                  ),
                ),
            ],
          ),
        ),
        // Panel Lateral de Directorio y Puntos de Encuentro
        Container(
          width: 380,
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            border: Border(
              left: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: _buildDirectoryContent(theme, isDark),
        ),
      ],
    );
  }

  /// Vista Móvil (< 700px): Mapa interactivo completo + Draggable Sheet con Directorio
  Widget _buildMobileLayout(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    UsacMapTheme mapTheme,
  ) {
    if (_showDirectoryOnly) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => setState(() => _showDirectoryOnly = false),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Ver Mapa Interactivo'),
                ),
              ],
            ),
          ),
          Expanded(child: _buildDirectoryContent(theme, isDark)),
        ],
      );
    }

    return Stack(
      children: [
        // Canvas de Mapa
        Positioned.fill(child: _buildMapCanvas(mapTheme)),

        // Controles Superiores Flotantes (Buscador, Modos de Ruta, 3D)
        _buildTopControls(theme, isDark, mapTheme),

        // Floor Selector flotante si hay edificio con pisos seleccionado
        if (_controller.selectedBuilding != null &&
            _controller.selectedBuilding!.floorsCount > 1)
          Positioned(
            right: 16,
            bottom: 120,
            child: FloorSelector(
              floorsCount: _controller.selectedBuilding!.floorsCount,
              selectedFloor: _controller.selectedFloor,
              theme: mapTheme,
              onFloorSelected: (f) => _controller.selectFloor(f),
            ),
          ),

        // Banner Turn-by-Turn cuando hay ruta activa
        if (_controller.currentRoute != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: TurnByTurnBanner(
              route: _controller.currentRoute!,
              trackingState: _controller.navigationTrackingState,
              theme: mapTheme,
              onClose: () => _controller.clearRoute(),
            ),
          ),

        // Draggable Bottom Sheet con Directorio de Edificios y Puntos
        DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.15,
          maxChildSize: 0.95,
          snap: true,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: CustomScrollView(
                controller: scrollController,
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 8),
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.outlineVariant,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildDirectoryHeader(theme, isDark),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final location = _locations[index];
                          return _LocationRow(
                            location: location,
                            onDirections: () => _handleDirections(location),
                          );
                        },
                        childCount: _locations.length,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  /// Mapa Canvas con UsacCampusMap
  Widget _buildMapCanvas(UsacMapTheme mapTheme) {
    if (_controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return UsacCampusMap(
      controller: _controller,
      theme: mapTheme,
      buildings: _controller.buildings,
      onBuildingSelected: (b) {
        if (b != null) _focusBuilding(b);
      },
      onPoiTapped: (p) => _focusPoi(p),
      onUserLocationTap: (latlng) {
        _controller.mapController.move(latlng, 17.5);
      },
    );
  }

  /// Controles flotantes en la parte superior del mapa
  Widget _buildTopControls(
    ThemeData theme,
    bool isDark,
    UsacMapTheme mapTheme,
  ) {
    final searchResults = _controller.searchResults;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Barra de Búsqueda Flotante
            Material(
              elevation: 4,
              shadowColor: Colors.black26,
              borderRadius: BorderRadius.circular(14),
              color: isDark ? AppTheme.darkCard : Colors.white,
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Icon(
                    Icons.search,
                    color: isDark ? Colors.white70 : AppTheme.usacBlue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      onChanged: _onSearchChanged,
                      decoration: const InputDecoration(
                        hintText: 'Buscar edificio, aula o alias (ej. El Iglú, T-3, 5B)...',
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    ),
                  IconButton(
                    tooltip: 'Ver Modelo 3D',
                    icon: Icon(
                      Icons.view_in_ar_outlined,
                      color: isDark ? AppTheme.usacGold : AppTheme.usacBlue,
                    ),
                    onPressed: _open3DViewerForSelected,
                  ),
                ],
              ),
            ),

            // Chips de Modos de Navegación A* Multi-modal
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildNavChip(
                      label: 'Peatonal',
                      icon: Icons.directions_walk,
                      mode: NavigationMode.pedestrian,
                      theme: theme,
                    ),
                    const SizedBox(width: 8),
                    _buildNavChip(
                      label: 'Sin Gradas',
                      icon: Icons.accessible,
                      mode: NavigationMode.accessible,
                      theme: theme,
                    ),
                    const SizedBox(width: 8),
                    _buildNavChip(
                      label: 'Techada (Lluvia)',
                      icon: Icons.umbrella_outlined,
                      mode: NavigationMode.covered,
                      theme: theme,
                    ),
                  ],
                ),
              ),
            ),

            // Resultados de Búsqueda Desplegables
            if (_isSearching && searchResults.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 6),
                constraints: const BoxConstraints(maxHeight: 260),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: searchResults.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = searchResults[index];
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        item.building != null
                            ? Icons.business
                            : Icons.location_on_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      title: Text(
                        item.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        item.matchedAlias != null
                            ? '${item.subtitle} · Alias: ${item.matchedAlias}'
                            : item.subtitle,
                      ),
                      onTap: () => _onSearchResultSelected(item),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavChip({
    required String label,
    required IconData icon,
    required NavigationMode mode,
    required ThemeData theme,
  }) {
    final isSelected = _navigationMode == mode;
    return ChoiceChip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          setState(() => _navigationMode = mode);
          // Si hay una ruta activa, recalculamos con el nuevo modo
          if (_controller.currentRoute != null &&
              _controller.selectedBuilding != null) {
            final origin =
                _controller.userLocation ?? const LatLng(14.5868, -90.5518);
            _controller.findRoute(
              origin: origin,
              destinationId: _controller.selectedBuilding!.id,
              mode: mode,
            );
          }
        }
      },
    );
  }

  /// Encabezado del Directorio de Ubicaciones
  Widget _buildDirectoryHeader(ThemeData theme, bool isDark) {
    final locations = _locations;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Mapa', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(
          'Puntos de encuentro y edificios de la USAC',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: [
            for (final campus in const [
              'Todas',
              'Campus Central',
              'CUM',
            ])
              ChoiceChip(
                label: Text(campus),
                selected: _selectedCampus == campus,
                onSelected: (_) => setState(() => _selectedCampus = campus),
                showCheckmark: false,
                backgroundColor: theme.colorScheme.surface,
                selectedColor: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.07),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                ),
                labelStyle: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '${locations.length} ubicaciones',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  /// Contenido Completo del Directorio (para Desktop y vista dedicada)
  Widget _buildDirectoryContent(ThemeData theme, bool isDark) {
    final locations = _locations;

    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.isMobile(context) ? 20 : 24,
        vertical: 20,
      ),
      children: [
        _buildDirectoryHeader(theme, isDark),
        for (final location in locations)
          _LocationRow(
            location: location,
            onDirections: () => _handleDirections(location),
          ),
      ],
    );
  }
}

class _LocationRow extends StatelessWidget {
  final Map<String, dynamic> location;
  final VoidCallback onDirections;

  const _LocationRow({required this.location, required this.onDirections});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.location_on_outlined,
            size: 21,
            color: theme.colorScheme.onSurface,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  location['building_code'] as String? ?? 'Ubicación USAC',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  location['description'] as String? ?? '',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Cómo llegar',
            onPressed: onDirections,
            icon: const Icon(Icons.directions_outlined),
          ),
        ],
      ),
    );
  }
}
