import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
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
import '../../shared/screens/settings_screen.dart';
import '../../onboarding/screens/merchant_support_screen.dart';
import '../../verification/screens/verification_flow_screen.dart';
import '../../verification/widgets/verification_gate.dart';
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
          backgroundColor: ZanateColors.zanateBlack,
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
        backgroundColor: ZanateColors.zanateBlack,
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
      final vCtrl = VerificationGate.maybeOf(context);

      // Comerciante en revisión
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final dialogBg = ZanateColors.card(isDark);
      final dialogShape = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: ZanateColors.border(isDark)),
      );
      final bodyStyle = TextStyle(
        fontSize: 13.5,
        height: 1.45,
        color: ZanateColors.textSecondary(isDark),
      );
      final primaryBtnStyle = ElevatedButton.styleFrom(
        backgroundColor: ZanateColors.ctaBg(isDark),
        foregroundColor: ZanateColors.ctaFg(isDark),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      );

      Widget zanateDialogTitle(String title) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: ZanateColors.textPrimary(isDark),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: ZanateColors.zanateEyeYellow,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      );

      if (vCtrl != null && vCtrl.isMerchantPending) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: dialogBg,
            shape: dialogShape,
            title: zanateDialogTitle('Solicitud en revisión'),
            content: Text(
              'Tu solicitud de comerciante está en revisión. Podrás publicar cuando sea aprobada.',
              style: bodyStyle,
            ),
            actions: [
              ElevatedButton(
                style: primaryBtnStyle,
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text(
                  'Entendido',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        );
        return;
      }

      // Comerciante rechazado
      if (vCtrl != null && vCtrl.isMerchantRejected) {
        final reason = vCtrl.merchantRejectionReason;
        final contentText = (reason != null && reason.trim().isNotEmpty)
            ? 'Tu solicitud de comerciante fue rechazada: $reason'
            : 'Tu solicitud de comerciante fue rechazada.';

        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: dialogBg,
            shape: dialogShape,
            title: zanateDialogTitle('Verificación rechazada'),
            content: Text(contentText, style: bodyStyle),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(
                  'Cerrar',
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : ZanateColors.mutedText,
                  ),
                ),
              ),
              ElevatedButton(
                style: primaryBtnStyle,
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MerchantSupportScreen(),
                    ),
                  );
                },
                child: const Text(
                  'Contactar con soporte',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        );
        return;
      }

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
            backgroundColor: dialogBg,
            shape: dialogShape,
            title: zanateDialogTitle('Límite de publicaciones alcanzado'),
            content: Text(
              'Has alcanzado el límite de ${currentStatus.maxActiveItems} publicaciones activas de tu plan ${currentStatus.planName}. Puedes mejorar tu plan para publicar más.',
              style: bodyStyle,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(
                  'Cerrar',
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : ZanateColors.mutedText,
                  ),
                ),
              ),
              ElevatedButton(
                style: primaryBtnStyle,
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  MarketplacePlansSheet.show(context);
                },
                child: const Text(
                  'Conocer planes',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        );
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: dialogBg,
          shape: dialogShape,
          title: zanateDialogTitle('Verifica tu cuenta para publicar'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (status != null && status.reason.isNotEmpty)
                      ? '${status.reason}\n\nElige cómo quieres verificar tu cuenta:'
                      : 'Para publicar en el Marketplace necesitas verificar que perteneces a la comunidad USAC. Elige una opción:',
                  style: bodyStyle,
                ),
                const SizedBox(height: 16),
                _VerificationPathOption(
                  icon: PhosphorIconsRegular.sealCheck,
                  title: 'Verificación automática',
                  subtitle:
                      'Con tu correo @usac.edu.gt y tu carné USAC. Validación inmediata.',
                  onTap: () {
                    Navigator.of(dialogContext).pop();
                    VerificationFlowScreen.show(
                      context,
                      controller: vCtrl,
                      initialTab: 0,
                    );
                  },
                ),
                const SizedBox(height: 10),
                _VerificationPathOption(
                  icon: PhosphorIconsRegular.headset,
                  title: 'Contactar con soporte',
                  subtitle:
                      'Si no tienes correo institucional o la verificación automática falló.',
                  onTap: () {
                    Navigator.of(dialogContext).pop();
                    VerificationFlowScreen.show(
                      context,
                      controller: vCtrl,
                      initialTab: 1,
                    );
                  },
                ),
                const SizedBox(height: 10),
                _VerificationPathOption(
                  icon: PhosphorIconsRegular.storefront,
                  title: 'Comerciante del campus',
                  subtitle:
                      'Contacta con soporte para registrar tu negocio.',
                  onTap: () {
                    Navigator.of(dialogContext).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MerchantSupportScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),
                Text(
                  'La verificación automática requiere correo @usac.edu.gt. Si usas una cuenta personal, contacta con soporte.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    color: ZanateColors.mutedText,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Ahora no',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : ZanateColors.mutedText,
                ),
              ),
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
  InputDecoration _zanateFilterDecoration(String hintText, bool isDark) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: ZanateColors.border(isDark), width: 1.2),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: ZanateColors.focusBorder(isDark),
        width: 1.6,
      ),
    );
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(fontSize: 12, color: ZanateColors.textMuted(isDark)),
      filled: true,
      fillColor: ZanateColors.surface(isDark),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      border: border,
      enabledBorder: border,
      focusedBorder: focusedBorder,
    );
  }

  Widget _buildSquaredHeader(bool isDark) {
    final textPrimary = ZanateColors.textPrimary(isDark);
    return Container(
      height: 58,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: ZanateColors.card(isDark),
        border: Border(
          bottom: BorderSide(color: ZanateColors.border(isDark)),
        ),
      ),
      child: Row(
        children: [
          // Settings button
          IconButton(
            tooltip: 'Configuración y Perfil',
            onPressed: () => SettingsScreen.show(
              context,
              activeAlias: widget.activeAlias,
              onAliasChanged: widget.onAliasChanged,
              onToggleTheme: widget.onToggleTheme,
            ),
            icon: Icon(
              PhosphorIconsRegular.gear,
              size: 22,
              color: textPrimary,
            ),
            splashRadius: 22,
          ),

          // Saved Listings shortcut (mismo lado que ajustes)
          IconButton(
            tooltip: 'Productos guardados',
            onPressed: _openSavedListings,
            icon: Icon(
              PhosphorIconsRegular.bookmarkSimple,
              size: 20,
              color: textPrimary,
            ),
            splashRadius: 22,
          ),

          // Title (centrado)
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
                    color: ZanateColors.textMuted(isDark),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  'Marketplace',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // My Sales shortcut
          IconButton(
            tooltip: 'Mis ventas',
            onPressed: _openMySales,
            icon: Icon(
              PhosphorIconsRegular.storefront,
              size: 20,
              color: textPrimary,
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
              color: textPrimary,
            ),
            splashRadius: 22,
          ),
        ],
      ),
    );
  }

  Widget _buildTopBanner(bool isDark, bool isDesktop) {
    final textPrimary = ZanateColors.textPrimary(isDark);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: ZanateColors.card(isDark),
        border: Border(
          bottom: BorderSide(color: ZanateColors.border(isDark)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: ZanateColors.zanateEyeYellow,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'Marketplace Estudiantil',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Espacio libre para emprendimientos sancarlistas: comidas, postres, tutorías de cursos y materiales universitarios. Trato directo, sin comisiones.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ZanateColors.textSecondary(isDark),
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          if (isDesktop) ...[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: textPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              onPressed: () => MarketplacePlansSheet.show(context),
              child: const Text(
                'Conocer planes',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: ZanateColors.ctaBg(isDark),
                foregroundColor: ZanateColors.ctaFg(isDark),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
              ),
              onPressed: _handleCreateListingClick,
              icon: const Icon(PhosphorIconsBold.plus, size: 15),
              label: const Text(
                'Publicar Anuncio',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
              ),
            ),
          ] else
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => MarketplacePlansSheet.show(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Text(
                  'Ver planes',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: ZanateColors.focusBorder(isDark),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(bool isDark, bool isDesktop) {
    final borderColor = ZanateColors.border(isDark);
    final textPrimary = ZanateColors.textPrimary(isDark);
    final textSecondary = ZanateColors.textSecondary(isDark);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: borderColor, width: 1.2),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: ZanateColors.focusBorder(isDark),
        width: 1.6,
      ),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: ZanateColors.card(isDark),
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Campo de búsqueda
          TextField(
            controller: _searchController,
            style: TextStyle(fontSize: 13.5, color: textPrimary),
            decoration: InputDecoration(
              hintText: 'Buscar postres, almuerzos, tutorías o libros...',
              hintStyle: TextStyle(
                fontSize: 13,
                color: ZanateColors.textMuted(isDark),
              ),
              prefixIcon: Icon(
                PhosphorIconsRegular.magnifyingGlass,
                size: 18,
                color: textSecondary,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        PhosphorIconsRegular.x,
                        size: 16,
                        color: textSecondary,
                      ),
                      splashRadius: 16,
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                        _loadData();
                      },
                    )
                  : null,
              filled: true,
              fillColor: ZanateColors.surface(isDark),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: border,
              enabledBorder: border,
              focusedBorder: focusedBorder,
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
                Expanded(child: _buildSedeDropdown(isDark)),
                const SizedBox(width: 8),
                Expanded(child: _buildFacultadDropdown(isDark)),
                const SizedBox(width: 8),
                Expanded(child: _buildBuildingDropdown(isDark)),
              ],
            )
          else
            Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildSedeDropdown(isDark)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildFacultadDropdown(isDark)),
                  ],
                ),
                const SizedBox(height: 8),
                _buildBuildingDropdown(isDark),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSedeDropdown(bool isDark) {
    final textPrimary = ZanateColors.textPrimary(isDark);
    return DropdownButtonFormField<String>(
      key: ValueKey('sede_$_selectedSede'),
      initialValue: _selectedSede,
      isExpanded: true,
      dropdownColor: ZanateColors.card(isDark),
      borderRadius: BorderRadius.circular(14),
      decoration: _zanateFilterDecoration('Sede / Campus', isDark),
      style: TextStyle(fontSize: 12, color: textPrimary),
      items: USACConstants.sedes
          .map(
            (s) => DropdownMenuItem<String>(
              value: s['id']!,
              child: Text(
                s['nombre']!,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: textPrimary),
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

  Widget _buildFacultadDropdown(bool isDark) {
    final textPrimary = ZanateColors.textPrimary(isDark);
    return DropdownButtonFormField<String>(
      key: ValueKey('facultad_$_selectedFacultad'),
      initialValue: _selectedFacultad,
      isExpanded: true,
      dropdownColor: ZanateColors.card(isDark),
      borderRadius: BorderRadius.circular(14),
      decoration: _zanateFilterDecoration('Facultad / Unidad', isDark),
      style: TextStyle(fontSize: 12, color: textPrimary),
      items: USACConstants.facultades
          .map(
            (f) => DropdownMenuItem<String>(
              value: f['id'].toString(),
              child: Text(
                f['nombre'].toString(),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: textPrimary),
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

  Widget _buildBuildingDropdown(bool isDark) {
    final textPrimary = ZanateColors.textPrimary(isDark);
    final buildings = USACConstants.campusBuildings
        .where((b) => _selectedSede == 'todas' || b['sede_id'] == _selectedSede)
        .toList();

    return DropdownButtonFormField<String>(
      key: ValueKey('building_${_selectedSede}_$_selectedBuilding'),
      initialValue: _selectedBuilding,
      isExpanded: true,
      dropdownColor: ZanateColors.card(isDark),
      borderRadius: BorderRadius.circular(14),
      decoration: _zanateFilterDecoration('Edificio / Inmueble', isDark),
      style: TextStyle(fontSize: 12, color: textPrimary),
      items: [
        DropdownMenuItem<String>(
          value: 'todos',
          child: Text(
            'Todos los edificios',
            style: TextStyle(fontSize: 12, color: textPrimary),
          ),
        ),
        ...buildings.map(
          (b) => DropdownMenuItem<String>(
            value: b['building_code']?.toString() ?? '',
            child: Text(
              '${b['building_code']} · ${b['nombre']}',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: textPrimary),
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

  // Sección "Compra por Categorías".
  Widget _buildEbayCategoriesSection(bool isDark) {
    final categories = USACConstants.marketplaceCategories
        .map((c) => (id: c.id, label: c.label))
        .toList();
    final textPrimary = ZanateColors.textPrimary(isDark);
    final textSecondary = ZanateColors.textSecondary(isDark);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: ZanateColors.card(isDark),
        border: Border(
          bottom: BorderSide(color: ZanateColors.border(isDark)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Compra por Categorías',
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
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
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 132,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? ZanateColors.zanateEyeYellow
                            : ZanateColors.pill(isDark),
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? null
                            : Border.all(color: ZanateColors.border(isDark)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            visuals.icon,
                            size: 20,
                            color: isSelected
                                ? ZanateColors.zanateBlack
                                : textPrimary,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            cat.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? ZanateColors.zanateBlack
                                  : textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            visuals.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isSelected
                                  ? ZanateColors.zanateBlack
                                      .withValues(alpha: 0.78)
                                  : textSecondary,
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
    final textPrimary = ZanateColors.textPrimary(isDark);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: ZanateColors.card(isDark),
        border: Border(
          bottom: BorderSide(
            color: ZanateColors.border(isDark),
            width: 0.8,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const PhosphorIcon(
                PhosphorIconsBold.lightning,
                size: 16,
                color: ZanateColors.zanateEyeYellow,
              ),
              const SizedBox(width: 6),
              Text(
                'Ofertas y Aportes del Día',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: ZanateColors.zanateEyeYellow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'GRATIS & DESTACADOS',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: ZanateColors.zanateBlack,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: deals.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, idx) {
                final item = deals[idx];
                final visuals = _getCategoryVisuals(item.category);

                return Container(
                  width: 245,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ZanateColors.surface(isDark),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: ZanateColors.border(isDark),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 76,
                          height: 108,
                          color: ZanateColors.card(isDark),
                          child: item.imageUrls.isNotEmpty
                              ? Image.network(
                                  item.imageUrls.first,
                                  fit: BoxFit.cover,
                                  errorBuilder: (ctx, err, stack) => Center(
                                    child: Icon(
                                      visuals.icon,
                                      size: 24,
                                      color: ZanateColors.textMuted(isDark),
                                    ),
                                  ),
                                )
                              : Center(
                                  child: Icon(
                                    visuals.icon,
                                    size: 24,
                                    color: ZanateColors.textMuted(isDark),
                                  ),
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
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: item.isFree
                                    ? ZanateColors.zanateEyeYellow
                                    : (isDark
                                        ? Colors.white
                                        : ZanateColors.zanateBlack),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                item.isFree ? 'GRATIS' : item.formattedPrice,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: item.isFree
                                      ? ZanateColors.zanateBlack
                                      : (isDark
                                          ? ZanateColors.zanateBlack
                                          : Colors.white),
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
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
    final textPrimary = ZanateColors.textPrimary(isDark);
    final borderColor = ZanateColors.border(isDark);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: ZanateColors.card(isDark),
        border: Border(
          bottom: BorderSide(color: borderColor),
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
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: ZanateColors.textSecondary(isDark),
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () {
              setState(() => _onlyFree = !_onlyFree);
              _loadData();
            },
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _onlyFree
                    ? ZanateColors.zanateEyeYellow
                    : ZanateColors.pill(isDark),
                borderRadius: BorderRadius.circular(10),
                border: _onlyFree ? null : Border.all(color: borderColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _onlyFree
                        ? PhosphorIconsFill.checkCircle
                        : PhosphorIconsRegular.gift,
                    size: 14,
                    color: _onlyFree ? ZanateColors.zanateBlack : textPrimary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Solo Gratuitos',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: _onlyFree ? FontWeight.w700 : FontWeight.w600,
                      color: _onlyFree ? ZanateColors.zanateBlack : textPrimary,
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: CircularProgressIndicator(
            color: ZanateColors.focusBorder(isDark),
          ),
        ),
      );
    }

    if (_listings.isEmpty) {
      return EmptyStateWidget(
        icon: PhosphorIconsRegular.storefront,
        title: 'No hay publicaciones en esta categoría aún',
        description:
            'Prueba ajustando tus preferencias de búsqueda o usa el botón para publicar un anuncio.',
        buttonText: 'Crear Primera Publicación',
        onButtonPressed: _handleCreateListingClick,
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
        backgroundColor: ZanateColors.bg(isDark),
        body: Column(
          children: [
            // 1. Cabecera Zanate
            _buildSquaredHeader(isDark),

            // 2. Búsqueda y filtros
            _buildSearchAndFilters(isDark, isDesktop),

            // 3. Contenido desplazable: franja promocional, categorías,
            // ofertas, patrocinios y feed a ancho completo.
            Expanded(
              child: RefreshIndicator(
                color: ZanateColors.focusBorder(isDark),
                backgroundColor: ZanateColors.card(isDark),
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Franja promocional (UX-MKT-001)
                      _buildTopBanner(isDark, isDesktop),

                      // Compra por categorías
                      _buildEbayCategoriesSection(isDark),

                      // Ofertas y aportes del día
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
                backgroundColor: ZanateColors.ctaBg(isDark),
                foregroundColor: ZanateColors.ctaFg(isDark),
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
      ),
    );
  }
}

/// Opción de verificación dentro de la ventana de Marketplace.
/// Mantiene la misma terminología y estructura que el onboarding
/// (estudiante vs. comerciante) sin abrir directamente un solo camino.
class _VerificationPathOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _VerificationPathOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ZanateColors.surface(isDark),
          border: Border.all(
            color: ZanateColors.border(isDark),
            width: 1.0,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: ZanateColors.zanateEyeYellow.withValues(alpha: 0.24),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: PhosphorIcon(
                  icon,
                  size: 20,
                  color: ZanateColors.focusBorder(isDark),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: ZanateColors.textPrimary(isDark),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: ZanateColors.textMuted(isDark),
                    ),
                  ),
                ],
              ),
            ),
            PhosphorIcon(
              PhosphorIconsRegular.caretRight,
              size: 16,
              color: ZanateColors.textMuted(isDark),
            ),
          ],
        ),
      ),
    );
  }
}
