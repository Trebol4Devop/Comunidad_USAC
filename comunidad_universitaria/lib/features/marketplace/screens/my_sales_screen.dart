import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../core/constants/categories.dart';
import '../../../core/constants/zanate_colors.dart';
import '../../../core/models/marketplace_item.dart';
import '../../../core/services/marketplace_service.dart';
import '../../../core/utils/responsive.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../widgets/marketplace_plans_sheet.dart';
import 'product_detail_screen.dart';

class MySalesScreen extends StatefulWidget {
  final MarketplaceSellerStatus? initialStatus;
  final List<MarketplaceItem>? initialListings;
  final List<MarketplaceMetrics>? initialMetrics;
  final Future<bool> Function(String itemId, String newStatus)? onItemStatusChanged;

  const MySalesScreen({
    super.key,
    this.initialStatus,
    this.initialListings,
    this.initialMetrics,
    this.onItemStatusChanged,
  });

  @override
  State<MySalesScreen> createState() => _MySalesScreenState();
}

class _MySalesScreenState extends State<MySalesScreen> {
  MarketplaceSellerStatus? _status;
  List<MarketplaceItem> _listings = [];
  List<MarketplaceMetrics> _metrics = [];

  bool _isLoadingAll = true;
  bool _isLoadingMetrics = false;
  int _selectedMetricsDays = 7;
  bool _metricsError = false;

  bool _isOnCampus = false;
  String _selectedBuilding = 'T-3';
  bool _isUpdatingPresence = false;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
    if (widget.initialListings != null) _listings = widget.initialListings!;
    if (widget.initialMetrics != null) _metrics = widget.initialMetrics!;

    if (_status != null && widget.initialListings != null) {
      _isLoadingAll = false;
      _isOnCampus = _status!.isOnCampus;
      _selectedBuilding = _status!.currentBuildingCode ?? 'T-3';
      _loadMetrics();
    } else {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoadingAll = true);
    try {
      final results = await Future.wait([
        MarketplaceService.fetchMyStatus(),
        MarketplaceService.fetchMyListings(),
        MarketplaceService.fetchMyMetrics(days: _selectedMetricsDays),
      ]);

      if (!mounted) return;
      final st = results[0] as MarketplaceSellerStatus?;
      final list = results[1] as List<MarketplaceItem>;
      final met = results[2] as List<MarketplaceMetrics>;

      setState(() {
        _status = st;
        _listings = list;
        _metrics = met;
        _isLoadingAll = false;
        _metricsError = false;
        if (st != null) {
          _isOnCampus = st.isOnCampus;
          if (st.currentBuildingCode != null && st.currentBuildingCode!.isNotEmpty) {
            _selectedBuilding = st.currentBuildingCode!;
          }
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingAll = false);
    }
  }

  Future<void> _loadMetrics() async {
    setState(() {
      _isLoadingMetrics = true;
      _metricsError = false;
    });

    try {
      final met = await MarketplaceService.fetchMyMetrics(days: _selectedMetricsDays);
      if (!mounted) return;
      setState(() {
        _metrics = met;
        _isLoadingMetrics = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingMetrics = false;
        _metricsError = true;
      });
    }
  }

  Future<void> _handleUpdateStatus(MarketplaceItem item, String newStatus) async {
    final oldStatus = item.status;
    setState(() {
      final idx = _listings.indexWhere((l) => l.id == item.id);
      if (idx != -1) {
        _listings[idx] = item.copyWith(status: newStatus);
      }
    });

    bool ok = false;
    try {
      if (widget.onItemStatusChanged != null) {
        ok = await widget.onItemStatusChanged!(item.id, newStatus);
      } else {
        ok = await MarketplaceService.updateItemStatus(
          itemId: item.id,
          newStatus: newStatus,
        );
      }
    } catch (_) {
      ok = false;
    }

    if (!mounted) return;
    if (!ok) {
      setState(() {
        final idx = _listings.indexWhere((l) => l.id == item.id);
        if (idx != -1) {
          _listings[idx] = item.copyWith(status: oldStatus);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo actualizar el estado del anuncio.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Estado actualizado a: ${newStatus.toUpperCase()}'),
          backgroundColor: const Color(0xFF059669),
          duration: const Duration(seconds: 2),
        ),
      );
      // Refresh status quota
      try {
        final updatedStatus = await MarketplaceService.fetchMyStatus();
        if (mounted && updatedStatus != null) {
          setState(() => _status = updatedStatus);
        }
      } catch (_) {}
    }
  }

  Future<void> _handleTogglePresence(bool active) async {
    setState(() {
      _isUpdatingPresence = true;
      _isOnCampus = active;
    });

    try {
      final ok = await MarketplaceService.updatePresence(
        onCampus: active,
        buildingCode: active ? _selectedBuilding : null,
      );

      if (!mounted) return;
      setState(() => _isUpdatingPresence = false);

      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              active
                  ? 'Presencia activada en edificio $_selectedBuilding'
                  : 'Presencia desactivada.',
            ),
            backgroundColor: const Color(0xFF059669),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUpdatingPresence = false;
        _isOnCampus = !active;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar presencia: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : ZanateColors.surfaceBg,
      appBar: AppBar(
        title: const Text(
          'Mis Ventas e Inventario',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: _isLoadingAll
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isDesktop ? 1000 : double.infinity),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. Quota & Plan Header Card
                        _buildQuotaCard(isDark, theme),
                        const SizedBox(height: 16),

                        // 2. Presence Switch (Paid / pro_student plan only)
                        if (_status != null &&
                            (_status!.sellerType == 'pro_student' ||
                                _status!.planId != 'free')) ...[
                          _buildPresenceCard(isDark, theme),
                          const SizedBox(height: 16),
                        ],

                        // 3. Performance / Metrics Card
                        _buildMetricsCard(isDark, theme),
                        const SizedBox(height: 20),

                        // 4. Inventory Section
                        Semantics(
                          header: true,
                          child: Text(
                            'Mis Publicaciones (${_listings.length})',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        if (_listings.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: EmptyStateWidget(
                              icon: PhosphorIconsRegular.shoppingBag,
                              title: 'Aún no tienes publicaciones',
                              description: 'Publica tu primer producto o servicio para empezar a vender.',
                              buttonText: 'Crear Publicación',
                              onButtonPressed: () => Navigator.of(context).pop(),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _listings.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (ctx, i) => _buildInventoryRow(_listings[i], isDark),
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

  Widget _buildQuotaCard(bool isDark, ThemeData theme) {
    final status = _status;
    final planName = status?.planName ?? 'Estudiante';
    final activeCount = status?.activeItems ?? _listings.where((l) => l.isAvailable || l.isReserved).length;
    final maxActive = status?.maxActiveItems ?? 3;
    final isUnlimited = status?.isUnlimited ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : ZanateColors.subtleBorder,
          width: 0.8,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ZanateColors.zanateAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(PhosphorIconsBold.sparkle, color: ZanateColors.zanateAccent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plan $planName',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  isUnlimited
                      ? '$activeCount activas · Cupo ilimitado'
                      : '$activeCount de $maxActive publicaciones activas',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                  ),
                ),
                if (status?.expiresAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Vence el: ${status!.expiresAt!.day}/${status.expiresAt!.month}/${status.expiresAt!.year}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ZanateColors.zanateAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => MarketplacePlansSheet.show(context),
            child: const Text('Mejorar plan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildPresenceCard(bool isDark, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : ZanateColors.subtleBorder,
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(PhosphorIconsFill.mapPin, color: Color(0xFF059669), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Entregando ahora en el campus',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Switch(
                value: _isOnCampus,
                activeThumbColor: const Color(0xFF10B981),
                onChanged: _isUpdatingPresence ? null : _handleTogglePresence,
              ),
            ],
          ),
          if (_isOnCampus) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Edificio: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(width: 6),
                DropdownButton<String>(
                  value: _selectedBuilding,
                  isDense: true,
                  items: USACConstants.campusBuildings
                      .where((b) => b['sede_id'] == 'central')
                      .map(
                        (b) => DropdownMenuItem<String>(
                          value: b['building_code']?.toString(),
                          child: Text('${b['building_code']} · ${b['nombre']}', style: const TextStyle(fontSize: 12)),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedBuilding = val);
                      _handleTogglePresence(true);
                    }
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricsCard(bool isDark, ThemeData theme) {
    int totalViews = 0;
    int totalClicks = 0;
    int totalWhatsapp = 0;
    int totalTelegram = 0;
    int totalInstagram = 0;
    int totalMessenger = 0;

    for (var m in _metrics) {
      totalViews += m.views;
      totalClicks += m.totalClicks;
      totalWhatsapp += m.clickWhatsapp;
      totalTelegram += m.clickTelegram;
      totalInstagram += m.clickInstagram;
      totalMessenger += m.clickMessenger;
    }

    final overallContactRate = totalViews > 0 ? (totalClicks / totalViews * 100).toStringAsFixed(1) : '0.0';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : ZanateColors.subtleBorder,
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Rendimiento y Conversión',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
              DropdownButton<int>(
                value: _selectedMetricsDays,
                isDense: true,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 7, child: Text('Últimos 7 días', style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 30, child: Text('Últimos 30 días', style: TextStyle(fontSize: 12))),
                ],
                onChanged: (val) {
                  if (val != null && val != _selectedMetricsDays) {
                    setState(() => _selectedMetricsDays = val);
                    _loadMetrics();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (_isLoadingMetrics)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_metricsError)
            Row(
              children: [
                const Text('No se pudieron cargar las analíticas.', style: TextStyle(fontSize: 12, color: Colors.red)),
                const Spacer(),
                TextButton(onPressed: _loadMetrics, child: const Text('Reintentar')),
              ],
            )
          else ...[
            // Aggregated Stat Badges
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    'Vistas totales',
                    '$totalViews',
                    PhosphorIconsRegular.eye,
                    isDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    'Clics a contacto',
                    '$totalClicks',
                    PhosphorIconsRegular.cursorClick,
                    isDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    'Tasa conversión',
                    '$overallContactRate%',
                    PhosphorIconsRegular.trendUp,
                    isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Breakdown by channel
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildChannelChip('WhatsApp', totalWhatsapp, const Color(0xFF25D366)),
                _buildChannelChip('Telegram', totalTelegram, const Color(0xFF0088CC)),
                _buildChannelChip('Instagram', totalInstagram, const Color(0xFFE1306C)),
                _buildChannelChip('Messenger', totalMessenger, const Color(0xFF0084FF)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: ZanateColors.zanateAccent),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelChip(String channel, int clicks, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$channel: ',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
          Text(
            '$clicks',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryRow(MarketplaceItem item, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : ZanateColors.subtleBorder,
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          // Thumbnail
          InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProductDetailScreen(itemId: item.id, initialItem: item),
                ),
              );
            },
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade200,
              ),
              clipBehavior: Clip.antiAlias,
              child: item.imageUrls.isNotEmpty
                  ? Image.network(
                      item.imageUrls.first,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(Icons.image, size: 24),
                    )
                  : const Icon(Icons.storefront, size: 24),
            ),
          ),
          const SizedBox(width: 12),

          // Title & Price
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 3),
                Text(
                  item.formattedPrice,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: ZanateColors.zanateAccent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Status Selector
          PopupMenuButton<String>(
            tooltip: 'Cambiar estado del artículo',
            onSelected: (newStatus) => _handleUpdateStatus(item, newStatus),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _getStatusColor(item.status).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getStatusLabel(item.status),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(item.status),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    PhosphorIconsRegular.caretDown,
                    size: 12,
                    color: _getStatusColor(item.status),
                  ),
                ],
              ),
            ),
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'available', child: Text('Disponible')),
              PopupMenuItem(value: 'reserved', child: Text('Reservado')),
              PopupMenuItem(value: 'sold', child: Text('Vendido')),
              PopupMenuItem(value: 'paused', child: Text('Pausado')),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'available':
        return const Color(0xFF059669);
      case 'reserved':
        return const Color(0xFFD97706);
      case 'sold':
        return const Color(0xFFDC2626);
      case 'paused':
      default:
        return Colors.grey.shade700;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'available':
        return 'Disponible';
      case 'reserved':
        return 'Reservado';
      case 'sold':
        return 'Vendido';
      case 'paused':
        return 'Pausado';
      default:
        return status.toUpperCase();
    }
  }
}
