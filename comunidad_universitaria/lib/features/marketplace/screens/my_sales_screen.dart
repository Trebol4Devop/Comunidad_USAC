import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../core/constants/categories.dart';
import '../../../core/constants/zanate_colors.dart';
import '../../../core/models/marketplace_item.dart';
import '../../../core/services/marketplace_service.dart';
import '../../../core/utils/responsive.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../marketplace_theme.dart';
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

    return MarketplaceTheme.wrap(
      context,
      Scaffold(
      backgroundColor: ZanateColors.bg(isDark),
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Volver',
          icon: PhosphorIcon(
            PhosphorIconsBold.caretLeft,
            size: 22,
            color: ZanateColors.textPrimary(isDark),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Mis Ventas e Inventario',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: ZanateColors.textPrimary(isDark),
          ),
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
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: EmptyStateWidget(
                              icon: PhosphorIconsRegular.shoppingBag,
                              title: 'Aún no tienes publicaciones',
                              description: 'Publica tu primer producto o servicio para empezar a vender.',
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
        color: ZanateColors.card(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ZanateColors.border(isDark),
          width: 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ZanateColors.zanateEyeYellow.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: PhosphorIcon(
              PhosphorIconsBold.sparkle,
              color: isDark
                  ? ZanateColors.zanateEyeYellow
                  : ZanateColors.zanateBlack,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plan $planName',
                  style: GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : ZanateColors.zanateBlack,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isUnlimited
                      ? '$activeCount activas · Cupo ilimitado'
                      : '$activeCount de $maxActive publicaciones activas',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFFCBD5E1)
                        : ZanateColors.subtleText,
                  ),
                ),
                if (status?.expiresAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Vence el: ${status!.expiresAt!.day}/${status.expiresAt!.month}/${status.expiresAt!.year}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : ZanateColors.mutedText,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark
                  ? ZanateColors.zanateEyeYellow
                  : ZanateColors.zanateBlack,
              foregroundColor: isDark
                  ? ZanateColors.zanateBlack
                  : Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => MarketplacePlansSheet.show(context),
            child: const Text(
              'Mejorar plan',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresenceCard(bool isDark, ThemeData theme) {
    final textPrimary = ZanateColors.textPrimary(isDark);
    final borderColor = ZanateColors.border(isDark);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ZanateColors.card(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
          width: 1.0,
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
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
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
                Text(
                  'Edificio: ',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ZanateColors.textSecondary(isDark),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: ZanateColors.surface(isDark),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedBuilding,
                        isDense: true,
                        isExpanded: true,
                        itemHeight: null,
                        dropdownColor: ZanateColors.card(isDark),
                        borderRadius: BorderRadius.circular(12),
                        style: TextStyle(fontSize: 12, color: textPrimary),
                        items: USACConstants.campusBuildings
                            .where((b) => b['sede_id'] == 'central')
                            .map(
                              (b) => DropdownMenuItem<String>(
                                value: b['building_code']?.toString(),
                                child: Text(
                                  '${b['building_code']} · ${b['nombre']}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: textPrimary,
                                  ),
                                ),
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
                    ),
                  ),
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

    final overallContactRate = totalViews > 0
        ? (totalClicks / totalViews * 100).toStringAsFixed(1)
        : '0.0';

    final textPrimary = ZanateColors.textPrimary(isDark);
    final textMuted = ZanateColors.textMuted(isDark);
    final borderColor = ZanateColors.border(isDark);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ZanateColors.card(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ZanateColors.zanateEyeYellow.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: PhosphorIcon(
                  PhosphorIconsBold.chartLineUp,
                  size: 18,
                  color: isDark
                      ? ZanateColors.zanateEyeYellow
                      : ZanateColors.zanateBlack,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    'Rendimiento y Conversión',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: ZanateColors.pill(isDark),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedMetricsDays,
                    isDense: true,
                    dropdownColor: ZanateColors.card(isDark),
                    borderRadius: BorderRadius.circular(12),
                    style: TextStyle(fontSize: 12, color: textPrimary),
                    items: [
                      DropdownMenuItem(
                        value: 7,
                        child: Text(
                          'Últimos 7 días',
                          style: TextStyle(fontSize: 12, color: textPrimary),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 30,
                        child: Text(
                          'Últimos 30 días',
                          style: TextStyle(fontSize: 12, color: textPrimary),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null && val != _selectedMetricsDays) {
                        setState(() => _selectedMetricsDays = val);
                        _loadMetrics();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

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
                const Expanded(
                  child: Text(
                    'No se pudieron cargar las analíticas.',
                    style: TextStyle(fontSize: 12, color: Colors.red),
                  ),
                ),
                TextButton(
                  onPressed: _loadMetrics,
                  child: const Text('Reintentar'),
                ),
              ],
            )
          else ...[
            // Métricas principales en diseño de 2 niveles para evitar recortes en móvil
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
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricTile(
                    'Clics a contacto',
                    '$totalClicks',
                    PhosphorIconsRegular.cursorClick,
                    isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: ZanateColors.surface(isDark),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor, width: 1.0),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ZanateColors.zanateEyeYellow.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      PhosphorIconsBold.trendUp,
                      size: 16,
                      color: isDark
                          ? ZanateColors.zanateEyeYellow
                          : ZanateColors.zanateBlack,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tasa conversión',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Porcentaje de vistas que generaron contacto',
                          style: TextStyle(
                            fontSize: 11,
                            color: textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$overallContactRate%',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? ZanateColors.zanateEyeYellow
                          : ZanateColors.zanateBlack,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Interacciones por canal',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: textMuted,
              ),
            ),
            const SizedBox(height: 8),

            // Breakdown by channel en cuadrícula limpia 2x2
            Row(
              children: [
                Expanded(
                  child: _buildChannelChip(
                    'WhatsApp',
                    totalWhatsapp,
                    PhosphorIconsFill.whatsappLogo,
                    const Color(0xFF25D366),
                    isDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildChannelChip(
                    'Telegram',
                    totalTelegram,
                    PhosphorIconsFill.telegramLogo,
                    const Color(0xFF0088CC),
                    isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildChannelChip(
                    'Instagram',
                    totalInstagram,
                    PhosphorIconsFill.instagramLogo,
                    const Color(0xFFE1306C),
                    isDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildChannelChip(
                    'Messenger',
                    totalMessenger,
                    PhosphorIconsFill.messengerLogo,
                    const Color(0xFF0084FF),
                    isDark,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, IconData icon, bool isDark) {
    final textPrimary = ZanateColors.textPrimary(isDark);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ZanateColors.surface(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ZanateColors.border(isDark),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: ZanateColors.focusBorder(isDark),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: ZanateColors.textMuted(isDark),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelChip(
    String channel,
    int clicks,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    final textPrimary = ZanateColors.textPrimary(isDark);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: ZanateColors.surface(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ZanateColors.border(isDark),
          width: 0.9,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                channel,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$clicks',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryRow(MarketplaceItem item, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ZanateColors.card(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ZanateColors.border(isDark),
          width: 1.0,
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
                borderRadius: BorderRadius.circular(10),
                color: ZanateColors.surface(isDark),
              ),
              clipBehavior: Clip.antiAlias,
              child: item.imageUrls.isNotEmpty
                  ? Image.network(
                      item.imageUrls.first,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const PhosphorIcon(
                        PhosphorIconsRegular.image,
                        size: 24,
                        color: ZanateColors.hintText,
                      ),
                    )
                  : const PhosphorIcon(
                      PhosphorIconsRegular.storefront,
                      size: 24,
                      color: ZanateColors.hintText,
                    ),
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
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : ZanateColors.zanateBlack,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.formattedPrice,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? ZanateColors.zanateEyeYellow
                        : ZanateColors.zanateBlack,
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
