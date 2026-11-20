import 'dart:async';
import 'package:flutter/material.dart' hide NavigationMode;
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart' hide DistanceCalculator;
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:usac_campus_map/usac_campus_map.dart';
import '../../../core/constants/categories.dart';
import '../../../core/constants/zanate_colors.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/url_utils.dart';
import '../../shared/screens/settings_screen.dart';
import '../../shared/widgets/network_state_widgets.dart';
import '../../shared/widgets/zanate_ui.dart';
import '../services/map_sync_service.dart';
import '../services/supabase_campus_community_repository.dart';
import '../widgets/building_3d_viewer.dart';

class CampusMapScreen extends StatefulWidget {
  final String? activeAlias;
  final Function(String newAlias)? onAliasChanged;
  final VoidCallback? onToggleTheme;

  const CampusMapScreen({
    super.key,
    this.activeAlias,
    this.onAliasChanged,
    this.onToggleTheme,
  });

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: ZanateColors.bg(isDark),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: ZanateColors.border(isDark),
          ),
        ),
        child: SizedBox(
          width: 500,
          height: 460,
          child: Column(
            children: [
              AppBar(
                title: Text(
                  'Modelo 3D · ${building.name}',
                  style: GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: ZanateColors.textPrimary(isDark),
                  ),
                ),
                leading: IconButton(
                  icon: PhosphorIcon(
                    PhosphorIconsRegular.x,
                    size: 20,
                    color: ZanateColors.textPrimary(isDark),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
                elevation: 0,
                backgroundColor: Colors.transparent,
              ),
              Expanded(
                child: UsacBuilding3DViewer(
                  model: model,
                  theme: _getMapTheme(isDark),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Text(
                  'Arrastra para rotar · Pellizca para zoom · ${building.floorsCount} niveles',
                  style: TextStyle(
                    fontSize: 12,
                    color: ZanateColors.textMuted(isDark),
                  ),
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
        primaryColor: ZanateColors.zanateEyeYellow,
        accentColor: ZanateColors.zanateEyeYellow,
        buildingDefaultColor: const Color(0x5514181F),
        buildingBorderColor: const Color(0xFF64748B),
        buildingSelectedColor: const Color(0x99F5C518),
        buildingSelectedBorderColor: ZanateColors.zanateEyeYellow,
        routeStandardColor: const Color(0xFF38BDF8),
        routeCoveredColor: const Color(0xFF4ADE80),
        routeStairsColor: const Color(0xFFFB923C),
        userLocationColor: const Color(0xFF38BDF8),
        boundaryFillColor: const Color(0x10F5C518),
        boundaryBorderColor: const Color(0x40F5C518),
        tileUrlTemplate:
            'https://cartodb-basemaps-a.global.ssl.fastly.net/dark_all/{z}/{x}/{y}.png',
      );
    }
    return const UsacMapTheme(
      primaryColor: ZanateColors.zanateBlack,
      accentColor: ZanateColors.zanateEyeYellow,
      buildingDefaultColor: Color(0x280B0D10),
      buildingBorderColor: ZanateColors.zanateBlack,
      buildingSelectedColor: Color(0x99F5C518),
      buildingSelectedBorderColor: ZanateColors.zanateBlack,
      routeStandardColor: Color(0xFF0284C7),
      routeCoveredColor: Color(0xFF16A34A),
      routeStairsColor: Color(0xFFEA580C),
      userLocationColor: Color(0xFF0284C7),
      boundaryFillColor: Color(0x100B0D10),
      boundaryBorderColor: Color(0x350B0D10),
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
            color: ZanateColors.bg(isDark),
            border: Border(
              left: BorderSide(
                color: ZanateColors.border(isDark),
              ),
            ),
          ),
          child: _buildDirectoryContent(theme, isDark),
        ),
      ],
    );
  }

  void _openSettings() {
    SettingsScreen.show(
      context,
      activeAlias: widget.activeAlias ?? 'Estudiante USAC',
      onAliasChanged: widget.onAliasChanged ?? (_) {},
      onToggleTheme: widget.onToggleTheme,
    );
  }

  Widget _buildMobileMapHeader(bool isDark) {
    final textPrimary = ZanateColors.textPrimary(isDark);
    return ZanatePageHeader(
      kicker: 'CAMPUS USAC',
      title: 'Mapa',
      leading: IconButton(
        tooltip: 'Configuración y Perfil',
        onPressed: _openSettings,
        icon: PhosphorIcon(
          PhosphorIconsRegular.gear,
          size: 21,
          color: textPrimary,
        ),
        style: IconButton.styleFrom(
          backgroundColor: ZanateColors.pill(isDark),
          fixedSize: const Size(38, 38),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
            side: BorderSide(color: ZanateColors.border(isDark), width: 0.8),
          ),
        ),
      ),
      trailing: [
        IconButton(
          tooltip: 'Ver Modelo 3D',
          onPressed: _open3DViewerForSelected,
          icon: PhosphorIcon(
            PhosphorIconsRegular.cube,
            size: 20,
            color: textPrimary,
          ),
          style: IconButton.styleFrom(
            backgroundColor: ZanateColors.pill(isDark),
            fixedSize: const Size(38, 38),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(11),
              side: BorderSide(color: ZanateColors.border(isDark), width: 0.8),
            ),
          ),
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
          _buildMobileMapHeader(isDark),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed: () => setState(() => _showDirectoryOnly = false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ZanateColors.ctaBg(isDark),
                    foregroundColor: ZanateColors.ctaFg(isDark),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const PhosphorIcon(
                    PhosphorIconsRegular.mapTrifold,
                    size: 18,
                  ),
                  label: const Text(
                    'Ver Mapa Interactivo',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildDirectoryContent(theme, isDark)),
        ],
      );
    }

    return Column(
      children: [
        _buildMobileMapHeader(isDark),
        Expanded(
          child: Stack(
            children: [
              // Canvas de Mapa
              Positioned.fill(child: _buildMapCanvas(mapTheme)),

              // Controles Superiores Flotantes (Buscador, Modos de Ruta)
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
                initialChildSize: 0.34,
                minChildSize: 0.14,
                maxChildSize: 0.92,
                snap: true,
                builder: (context, scrollController) {
                  return Container(
                    decoration: BoxDecoration(
                      color: ZanateColors.bg(isDark),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      border: Border(
                        top: BorderSide(
                          color: ZanateColors.border(isDark),
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
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
                                  color: ZanateColors.border(isDark),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(height: 6),
                            ],
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: _buildDirectoryHeader(
                              theme,
                              isDark,
                              compact: true,
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
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
          ),
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
              elevation: 2,
              shadowColor: Colors.black.withValues(alpha: 0.12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: ZanateColors.border(isDark),
                  width: 1.2,
                ),
              ),
              color: ZanateColors.card(isDark),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  PhosphorIcon(
                    PhosphorIconsRegular.magnifyingGlass,
                    size: 19,
                    color: isDark
                        ? ZanateColors.zanateEyeYellow
                        : ZanateColors.zanateBlack,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      onChanged: _onSearchChanged,
                      style: TextStyle(
                        color: ZanateColors.textPrimary(isDark),
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        filled: false,
                        hintText:
                            'Buscar edificio, aula o alias (ej. El Iglú, T-3, 5B)...',
                        hintStyle: TextStyle(
                          color: ZanateColors.textMuted(isDark),
                        ),
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: const PhosphorIcon(
                        PhosphorIconsRegular.x,
                        size: 18,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    ),
                  if (!Responsive.isMobile(context))
                    IconButton(
                      tooltip: 'Ver Modelo 3D',
                      icon: PhosphorIcon(
                        PhosphorIconsRegular.cube,
                        size: 20,
                        color: isDark
                            ? ZanateColors.zanateEyeYellow
                            : ZanateColors.zanateBlack,
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
                      icon: PhosphorIconsRegular.footprints,
                      mode: NavigationMode.pedestrian,
                      theme: theme,
                    ),
                    const SizedBox(width: 8),
                    _buildNavChip(
                      label: 'Sin Gradas',
                      icon: PhosphorIconsRegular.wheelchair,
                      mode: NavigationMode.accessible,
                      theme: theme,
                    ),
                    const SizedBox(width: 8),
                    _buildNavChip(
                      label: 'Techada (Lluvia)',
                      icon: PhosphorIconsRegular.umbrella,
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
                  color: ZanateColors.card(isDark),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: ZanateColors.border(isDark),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: searchResults.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    color: ZanateColors.border(isDark),
                  ),
                  itemBuilder: (context, index) {
                    final item = searchResults[index];
                    return ListTile(
                      dense: true,
                      leading: PhosphorIcon(
                        item.building != null
                            ? PhosphorIconsRegular.buildings
                            : PhosphorIconsRegular.mapPin,
                        size: 20,
                        color: isDark
                            ? ZanateColors.zanateEyeYellow
                            : ZanateColors.zanateBlack,
                      ),
                      title: Text(
                        item.title,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w700,
                          color: ZanateColors.textPrimary(isDark),
                        ),
                      ),
                      subtitle: Text(
                        item.matchedAlias != null
                            ? '${item.subtitle} · Alias: ${item.matchedAlias}'
                            : item.subtitle,
                        style: TextStyle(
                          color: ZanateColors.textMuted(isDark),
                          fontSize: 12,
                        ),
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
    final isDark = theme.brightness == Brightness.dark;
    final isSelected = _navigationMode == mode;
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected
            ? ZanateColors.zanateBlack
            : ZanateColors.textMuted(isDark),
      ),
      label: Text(label),
      selected: isSelected,
      showCheckmark: false,
      backgroundColor: ZanateColors.card(isDark),
      selectedColor: ZanateColors.zanateEyeYellow,
      side: BorderSide(
        color: isSelected
            ? ZanateColors.focusBorder(isDark)
            : ZanateColors.border(isDark),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      labelStyle: GoogleFonts.outfit(
        fontSize: 12.5,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
        color: isSelected
            ? ZanateColors.zanateBlack
            : ZanateColors.textSecondary(isDark),
      ),
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
  Widget _buildDirectoryHeader(
    ThemeData theme,
    bool isDark, {
    bool compact = false,
  }) {
    final locations = _locations;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!compact) ...[
          Text(
            'Mapa',
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: ZanateColors.textPrimary(isDark),
            ),
          ),
          const SizedBox(height: 6),
        ],
        const ZanateAccentBar(),
        SizedBox(height: compact ? 6 : 8),
        Text(
          'Puntos de encuentro y edificios de la USAC',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: compact ? 13 : null,
            color: ZanateColors.textSecondary(isDark),
          ),
        ),
        SizedBox(height: compact ? 8 : 16),
        Wrap(
          spacing: 8,
          runSpacing: compact ? 6 : 8,
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
                visualDensity: compact ? VisualDensity.compact : null,
                padding: compact
                    ? const EdgeInsets.symmetric(horizontal: 6)
                    : null,
                backgroundColor: ZanateColors.pill(isDark),
                selectedColor: ZanateColors.zanateEyeYellow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(
                  color: _selectedCampus == campus
                      ? ZanateColors.focusBorder(isDark)
                      : ZanateColors.border(isDark),
                ),
                labelStyle: GoogleFonts.outfit(
                  fontSize: compact ? 12.5 : 13,
                  color: _selectedCampus == campus
                      ? ZanateColors.zanateBlack
                      : ZanateColors.textSecondary(isDark),
                  fontWeight: _selectedCampus == campus
                      ? FontWeight.w700
                      : FontWeight.w600,
                ),
              ),
          ],
        ),
        SizedBox(height: compact ? 6 : 12),
        Text(
          '${locations.length} ubicaciones',
          style: TextStyle(
            fontSize: compact ? 12 : 12.5,
            fontWeight: FontWeight.w600,
            color: ZanateColors.textMuted(isDark),
          ),
        ),
        SizedBox(height: compact ? 2 : 4),
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
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: ZanateColors.border(isDark),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: ZanateColors.surface(isDark),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: ZanateColors.border(isDark),
              ),
            ),
            child: Center(
              child: PhosphorIcon(
                PhosphorIconsRegular.mapPin,
                size: 18,
                color: isDark
                    ? ZanateColors.zanateEyeYellow
                    : ZanateColors.zanateBlack,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  location['building_code'] as String? ?? 'Ubicación USAC',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    color: ZanateColors.textPrimary(isDark),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  location['description'] as String? ?? '',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: ZanateColors.textMuted(isDark),
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
            style: IconButton.styleFrom(
              backgroundColor: ZanateColors.surface(isDark),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: PhosphorIcon(
              PhosphorIconsRegular.navigationArrow,
              size: 18,
              color: isDark
                  ? ZanateColors.zanateEyeYellow
                  : ZanateColors.zanateBlack,
            ),
          ),
        ],
      ),
    );
  }
}
