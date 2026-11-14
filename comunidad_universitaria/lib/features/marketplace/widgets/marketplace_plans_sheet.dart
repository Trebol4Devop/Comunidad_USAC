import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../core/constants/zanate_colors.dart';
import '../../../core/services/marketplace_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../shared/widgets/auth_modal.dart';
import 'sponsor_request_dialog.dart';

class MarketplacePlansSheet extends StatefulWidget {
  final List<MarketplacePlan>? initialPlans;
  final MarketplaceSellerStatus? initialStatus;

  const MarketplacePlansSheet({
    super.key,
    this.initialPlans,
    this.initialStatus,
  });

  static Future<void> show(BuildContext context) {
    if (Responsive.isMobile(context)) {
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => const MarketplacePlansSheet(),
      );
    } else {
      return showDialog(
        context: context,
        builder: (ctx) => Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: const MarketplacePlansSheet(),
          ),
        ),
      );
    }
  }

  @override
  State<MarketplacePlansSheet> createState() => _MarketplacePlansSheetState();
}

class _MarketplacePlansSheetState extends State<MarketplacePlansSheet> {
  List<MarketplacePlan> _plans = [];
  MarketplaceSellerStatus? _myStatus;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialPlans != null) {
      _plans = widget.initialPlans!;
      _myStatus = widget.initialStatus;
      _isLoading = false;
    } else {
      _loadPlansAndStatus();
    }
  }

  Future<void> _loadPlansAndStatus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        MarketplaceService.fetchPlans(),
        MarketplaceService.fetchMyStatus(),
      ]);

      if (!mounted) return;
      final fetchedPlans = results[0] as List<MarketplacePlan>;
      final fetchedStatus = results[1] as MarketplaceSellerStatus?;

      setState(() {
        _plans = fetchedPlans;
        _myStatus = fetchedStatus;
        _isLoading = false;
        if (fetchedPlans.isEmpty) {
          _errorMessage =
              'No pudimos cargar los planes. Revisa tu conexión e inténtalo de nuevo.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _plans = const [];
        _isLoading = false;
        _errorMessage =
            'No pudimos cargar los planes desde el servidor. Revisa tu conexión e inténtalo de nuevo.';
      });
    }
  }

  void _handlePlanAction(MarketplacePlan plan) {
    if (!SupabaseService.isAuthenticated) {
      AuthModal.show(
        context,
        title: 'Inicia sesión para solicitar un plan',
        subtitle:
            'Para asociar un plan a tu cuenta estudiantil o comercial debes iniciar sesión.',
        onAuthenticated: () {
          _loadPlansAndStatus();
        },
      );
      return;
    }

    SponsorRequestDialog.show(
      context,
      planId: plan.id,
      planName: plan.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDesktop = Responsive.isDesktop(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 32 : 18,
        vertical: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ZanateColors.zanateAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  PhosphorIconsBold.sparkle,
                  color: ZanateColors.zanateAccent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Planes del Marketplace',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : ZanateColors.zanateDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Más visibilidad, más catálogo, más herramientas. Sin comisiones por venta.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Cerrar',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Content body
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_errorMessage!),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _loadPlansAndStatus,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            )
          else
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    if (isDesktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _plans
                            .map(
                              (plan) => Expanded(
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 6),
                                  child: _buildPlanCard(plan, isDark),
                                ),
                              ),
                            )
                            .toList(),
                      )
                    else
                      Column(
                        children: _plans
                            .map(
                              (plan) => Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: _buildPlanCard(plan, isDark),
                              ),
                            )
                            .toList(),
                      ),
                    const SizedBox(height: 18),

                    // Mandatory Note (UX-MKT-018)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF334155)
                              : ZanateColors.subtleBorder,
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            PhosphorIconsRegular.info,
                            size: 18,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'La coordinación y el pago del plan se realizan fuera de la app con el equipo. La plataforma no cobra comisiones por tus ventas.',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? const Color(0xFFCBD5E1)
                                    : const Color(0xFF475569),
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
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

  Widget _buildPlanCard(MarketplacePlan plan, bool isDark) {
    final currentPlanId = _myStatus?.planId ?? 'free';
    final isCurrentPlan = plan.id == currentPlanId;
    final isRecommended = plan.id == 'pro_student';

    final borderColor = isCurrentPlan
        ? const Color(0xFF10B981)
        : (isRecommended
            ? const Color(0xFFF59E0B)
            : (isDark
                ? const Color(0xFF334155)
                : ZanateColors.subtleBorder));

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor,
          width: isCurrentPlan || isRecommended ? 1.5 : 0.8,
        ),
        boxShadow: [
          if (isRecommended || isCurrentPlan)
            BoxShadow(
              color: (isCurrentPlan
                      ? const Color(0xFF10B981)
                      : const Color(0xFFF59E0B))
                  .withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Plan Name & Badges
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                plan.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (isCurrentPlan)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Plan actual',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF059669),
                    ),
                  ),
                )
              else if (isRecommended)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Recomendado',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFD97706),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Price
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                plan.formattedPrice,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: ZanateColors.zanateAccent,
                ),
              ),
              if (plan.priceMonthly > 0)
                Text(
                  ' /mes',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Limits Summary
          Text(
            plan.isUnlimited
                ? 'Publicaciones activas: Ilimitadas'
                : 'Hasta ${plan.maxActiveItems} publicaciones activas',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${plan.maxImagesPerItem} imágenes por publicación${plan.allowVideo ? ' + video' : ''}',
            style: TextStyle(
              fontSize: 11.5,
              color: isDark
                  ? const Color(0xFF94A3B8)
                  : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 12),

          // Features List
          ...plan.features.map(
            (feat) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      PhosphorIconsBold.check,
                      size: 13,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      feat,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? const Color(0xFFE2E8F0)
                            : ZanateColors.zanateDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Action Button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isCurrentPlan
                  ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9))
                  : ZanateColors.zanateAccent,
              foregroundColor:
                  isCurrentPlan ? (isDark ? Colors.white70 : Colors.black87) : Colors.white,
              elevation: isCurrentPlan ? 0 : 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: isCurrentPlan
                ? null
                : () => _handlePlanAction(plan),
            child: Text(
              isCurrentPlan
                  ? 'Plan actual'
                  : (!SupabaseService.isAuthenticated
                      ? 'Inicia sesión para solicitar'
                      : (plan.priceMonthly == 0
                          ? 'Solicitar plan'
                          : 'Mejorar plan')),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isCurrentPlan ? Colors.grey : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
