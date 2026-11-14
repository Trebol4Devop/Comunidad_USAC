import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../core/constants/zanate_colors.dart';
import '../../../core/constants/categories.dart';
import '../../../core/models/marketplace_item.dart';
import '../../../core/utils/time_utils.dart';
import '../../../core/utils/url_utils.dart';
import '../../shared/widgets/image_viewer_dialog.dart';
import '../../shared/widgets/report_dialog.dart';
import 'sponsored_content_controls.dart';

class MarketplaceCard extends StatefulWidget {
  final MarketplaceItem item;
  final VoidCallback onUpvote;
  final Function(String reason)? onReport;
  final Function(String newStatus)? onStatusChanged;
  final VoidCallback? onSponsoredHide;
  final VoidCallback? onShare;
  final bool isOwner;
  final VoidCallback? onTap;
  final VoidCallback? onOpenStore;
  final VoidCallback? onToggleBookmark;
  final VoidCallback? onShowPlans;
  final VoidCallback? onOpenMySales;

  const MarketplaceCard({
    super.key,
    required this.item,
    required this.onUpvote,
    this.onReport,
    this.onStatusChanged,
    this.onSponsoredHide,
    this.onShare,
    this.isOwner = false,
    this.onTap,
    this.onOpenStore,
    this.onToggleBookmark,
    this.onShowPlans,
    this.onOpenMySales,
  });

  @override
  State<MarketplaceCard> createState() => _MarketplaceCardState();
}

class _MarketplaceCardState extends State<MarketplaceCard> {
  int _currentImageIndex = 0;

  String _getCategoryLabel(String catId) {
    final match = USACConstants.marketplaceCategories.where(
      (c) => c.id == catId,
    );
    return match.isNotEmpty ? match.first.label : 'General';
  }

  String _getSedeName(String sedeId) {
    final match = USACConstants.sedes.where((s) => s['id'] == sedeId);
    return match.isNotEmpty ? match.first['nombre'] ?? 'Sede' : 'Sede Central';
  }

  IconData _getCategoryIcon(String catId) {
    switch (catId) {
      case 'comida_postres':
        return PhosphorIconsRegular.cookie;
      case 'tutorias_academica':
        return PhosphorIconsRegular.graduationCap;
      case 'libros_materiales':
        return PhosphorIconsRegular.bookOpen;
      case 'servicios_estudiantiles':
        return PhosphorIconsRegular.paintBrush;
      default:
        return PhosphorIconsRegular.package;
    }
  }

  String _getDomainLabel(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('instagram.com')) return 'Instagram';
    if (lower.contains('facebook.com') || lower.contains('fb.com')) {
      return 'Facebook';
    }
    if (lower.contains('tiktok.com')) return 'TikTok';
    if (lower.contains('drive.google.com')) return 'Drive / Menú';
    return 'Enlace';
  }

  IconData _getDomainIcon(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('instagram.com')) return PhosphorIconsFill.instagramLogo;
    if (lower.contains('facebook.com') || lower.contains('fb.com')) {
      return PhosphorIconsFill.facebookLogo;
    }
    if (lower.contains('tiktok.com')) return PhosphorIconsFill.tiktokLogo;
    return PhosphorIconsRegular.link;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final item = widget.item;

    final cardWidget = Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : ZanateColors.subtleBorder,
            width: 0.8,
          ),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Image Section
          Stack(
            children: [
              Container(
                height: 140,
                width: double.infinity,
                color: isDark
                    ? const Color(0xFF252525)
                    : const Color(0xFFF1F5F9),
                child: item.imageUrls.isNotEmpty
                    ? PageView.builder(
                        itemCount: item.imageUrls.length,
                        onPageChanged: (idx) =>
                            setState(() => _currentImageIndex = idx),
                        itemBuilder: (ctx, i) {
                          final imgUrl = item.imageUrls[i];
                          return InkWell(
                            onTap: () => ImageViewerDialog.show(
                              context,
                              imageUrl: imgUrl,
                              title:
                                  '${item.title} (${i + 1}/${item.imageUrls.length})',
                            ),
                            child: Image.network(
                              imgUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Center(
                                    child: Icon(
                                      _getCategoryIcon(item.category),
                                      size: 48,
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                            ),
                          );
                        },
                      )
                    : Center(
                        child: Icon(
                          _getCategoryIcon(item.category),
                          size: 48,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
              ),

              // Multi-image indicators
              if (item.imageUrls.length > 1)
                Positioned(
                  bottom: 6,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_currentImageIndex + 1}/${item.imageUrls.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              // Sold Watermark Overlay
              if (item.isSold)
                Positioned.fill(
                  child: Container(
                    color: Colors.white.withValues(alpha: 0.72),
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                      child: Text(
                        'VENDIDO',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ),

              // Reserved Overlay Banner
              if (item.isReserved)
                Positioned(
                  top: 40,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: theme.colorScheme.surface.withValues(alpha: 0.94),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    alignment: Alignment.center,
                    child: Text(
                      'ARTÍCULO RESERVADO',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),

              // Price badge & Bookmark (Top Right)
              Positioned(
                top: 10,
                right: 10,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.onToggleBookmark != null)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF0F172A).withValues(alpha: 0.85)
                              : Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          iconSize: 18,
                          padding: const EdgeInsets.all(5),
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          icon: Icon(
                            item.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                            color: item.isBookmarked
                                ? ZanateColors.zanateAccent
                                : (isDark ? Colors.white70 : Colors.black87),
                          ),
                          tooltip: item.isBookmarked ? 'Guardado' : 'Guardar',
                          onPressed: widget.onToggleBookmark,
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : ZanateColors.zanateDark,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Text(
                        item.isSold ? 'VENDIDO' : item.formattedPrice,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Category & Sede badges (Top Left)
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.92) : Colors.white.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : ZanateColors.subtleBorder,
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getCategoryIcon(item.category),
                        size: 13,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _getCategoryLabel(item.category),
                        style: TextStyle(
                          color: isDark ? const Color(0xFFE2E8F0) : ZanateColors.zanateDark,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (item.isSponsored)
                Positioned(
                  bottom: 0,
                  left: 8,
                  right: 8,
                  child: SponsoredContentControls(
                    item: item,
                    onHide: widget.onSponsoredHide ?? () {},
                    onReport: widget.onReport ?? (_) {},
                    overImage: true,
                  ),
                ),
            ],
          ),

          // Content body
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author and verification
                InkWell(
                  onTap: widget.onOpenStore,
                  borderRadius: BorderRadius.circular(6),
                  child: Row(
                    children: [
                      Icon(
                        PhosphorIconsRegular.userCircle,
                        size: 16,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                (item.sellerBusinessName != null && item.sellerBusinessName!.trim().isNotEmpty)
                                    ? item.sellerBusinessName!
                                    : item.authorAlias,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (item.isSellerVerified) ...[
                              const SizedBox(width: 4),
                              Tooltip(
                                message: 'Vendedor verificado',
                                child: Icon(
                                  Icons.verified_outlined,
                                  size: 14,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                            if (item.sellerBadgeText != null && item.sellerBadgeText!.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: ZanateColors.zanateAccent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  item.sellerBadgeText!,
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: ZanateColors.zanateAccent,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Text(
                        TimeUtils.timeAgo(item.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                      ),
                    ],
                  ),
                ),

                // Presence Chip & Expiration
                if (item.sellerIsOnCampus || (item.expiresAt != null && item.sellerPlanId == 'free')) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (item.sellerIsOnCampus)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_on, size: 12, color: Color(0xFF059669)),
                              const SizedBox(width: 3),
                              Text(
                                item.sellerBuildingCode != null && item.sellerBuildingCode!.isNotEmpty
                                    ? 'Entregando ahora · ${item.sellerBuildingCode}'
                                    : 'Entregando ahora en el campus',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF059669),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (item.expiresAt != null && item.sellerPlanId == 'free' && item.venceEnDias != null)
                        Text(
                          'Vence en ${item.venceEnDias} días',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: item.venceEnDias! <= 3 ? const Color(0xFFDC2626) : Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),

                // Title
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),

                // Description
                Text(
                  item.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: isDark
                        ? const Color(0xFFAAAAAA)
                        : const Color(0xFF64748B),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),

                // Delivery location
                Row(
                  children: [
                    Icon(
                      PhosphorIconsRegular.mapPin,
                      size: 14,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        item.buildingCode.isNotEmpty
                            ? '${item.buildingCode} · ${item.locationDetail.isNotEmpty ? item.locationDetail : _getSedeName(item.sede)}'
                            : (item.locationDetail.isNotEmpty
                                  ? item.locationDetail
                                  : _getSedeName(item.sede)),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? Colors.grey.shade300
                              : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),

                // Reference Social Links
                if (item.socialLinks.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: item.socialLinks.map((link) {
                      return InkWell(
                        onTap: () => UrlUtils.openUrl(context, link),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: theme.dividerColor),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getDomainIcon(link),
                                size: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _getDomainLabel(link),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                // Video button if available
                if (item.videoUrl != null && item.videoUrl!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => UrlUtils.openUrl(context, item.videoUrl!),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.play_circle_outline,
                            size: 13,
                            color: theme.colorScheme.onSurface,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Ver Video Promocional',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Discrete verification notice
                if (!item.isSellerVerified && !item.isSold) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        PhosphorIconsRegular.shieldWarning,
                        size: 13,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          'Vendedor independiente no verificado · Trato en campus',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],

                // Sleek Seller Status Selector
                if (widget.onStatusChanged != null &&
                    (widget.isOwner || item.isMine)) ...[
                  const SizedBox(height: 8),
                  PopupMenuButton<String>(
                    tooltip: 'Cambiar estado del anuncio',
                    onSelected: (newStatus) => widget.onStatusChanged!(newStatus),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : ZanateColors.surfaceBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : ZanateColors.subtleBorder,
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            PhosphorIconsRegular.tag,
                            size: 12,
                            color: ZanateColors.zanateAccent,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Estado: ${item.status.toUpperCase()}',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : ZanateColors.zanateDark,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            PhosphorIconsRegular.caretDown,
                            size: 11,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ],
                      ),
                    ),
                    itemBuilder: (ctx) => [
                      if (!item.isReserved && !item.isSold)
                        const PopupMenuItem(
                          value: 'reserved',
                          child: Text('Marcar como Reservado'),
                        ),
                      if (item.isReserved)
                        const PopupMenuItem(
                          value: 'available',
                          child: Text('Marcar como Disponible'),
                        ),
                      if (!item.isSold)
                        const PopupMenuItem(
                          value: 'sold',
                          child: Text('Marcar como Vendido'),
                        ),
                      if (item.status != 'paused' && !item.isSold)
                        const PopupMenuItem(
                          value: 'paused',
                          child: Text('Pausar anuncio'),
                        ),
                      if (item.status == 'paused')
                        const PopupMenuItem(
                          value: 'available',
                          child: Text('Reanudar anuncio'),
                        ),
                    ],
                  ),
                ],

                const SizedBox(height: 12),
                Container(
                  height: 0.8,
                  color: isDark ? const Color(0xFF334155) : ZanateColors.subtleBorder,
                ),
                const SizedBox(height: 10),

                // Contact channels & Upvote Row
                Row(
                  children: [
                    // Upvote pill button
                    InkWell(
                      onTap: widget.onUpvote,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: item.isUpvotedByMe
                              ? const Color(0xFFEF4444).withValues(alpha: 0.1)
                              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: item.isUpvotedByMe
                                ? const Color(0xFFEF4444)
                                : (isDark ? const Color(0xFF334155) : ZanateColors.subtleBorder),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              item.isUpvotedByMe
                                  ? PhosphorIconsFill.heart
                                  : PhosphorIconsRegular.heart,
                              size: 14,
                              color: item.isUpvotedByMe
                                  ? const Color(0xFFEF4444)
                                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${item.upvotes}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: item.isUpvotedByMe
                                    ? const Color(0xFFEF4444)
                                    : (isDark ? const Color(0xFFE2E8F0) : ZanateColors.zanateDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (widget.onShare != null) ...[
                      const SizedBox(width: 8),
                      // Share pill button with count
                      InkWell(
                        onTap: widget.onShare,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : ZanateColors.subtleBorder,
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                PhosphorIconsRegular.shareNetwork,
                                size: 14,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                              if (item.sharesCount > 0) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '${item.sharesCount}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? const Color(0xFFE2E8F0) : ZanateColors.zanateDark,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(width: 8),

                    // Contact icons / buttons
                    Expanded(
                      child: item.isSold
                          ? const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              child: Text(
                                'Este artículo ya fue vendido',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey,
                                ),
                              ),
                            )
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                          children: [
                            // WhatsApp
                            if (item.whatsappUrl != null)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: InkWell(
                                  onTap: () => UrlUtils.openUrl(
                                    context,
                                    item.whatsappUrl!,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF25D366).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          PhosphorIconsFill.whatsappLogo,
                                          size: 14,
                                          color: Color(0xFF25D366),
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'WhatsApp',
                                          style: TextStyle(
                                            color: Color(0xFF16A34A),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                            // Instagram
                            if (item.instagramUrl != null)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: InkWell(
                                  onTap: () => UrlUtils.openUrl(
                                    context,
                                    item.instagramUrl!,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE1306C).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          PhosphorIconsFill.instagramLogo,
                                          size: 14,
                                          color: Color(0xFFE1306C),
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Instagram',
                                          style: TextStyle(
                                            color: Color(0xFFE1306C),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                            // Messenger
                            if (item.messengerUrl != null)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: InkWell(
                                  onTap: () => UrlUtils.openUrl(
                                    context,
                                    item.messengerUrl!,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0084FF).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          PhosphorIconsFill.messengerLogo,
                                          size: 14,
                                          color: Color(0xFF0084FF),
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Messenger',
                                          style: TextStyle(
                                            color: Color(0xFF0084FF),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                            // Telegram
                            if (item.telegramUrl != null)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: InkWell(
                                  onTap: () => UrlUtils.openUrl(
                                    context,
                                    item.telegramUrl!,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0088CC).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          PhosphorIconsFill.telegramLogo,
                                          size: 14,
                                          color: Color(0xFF0088CC),
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Telegram',
                                          style: TextStyle(
                                            color: Color(0xFF0088CC),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 4),

                    if (!item.isSponsored && widget.onReport != null)
                      PopupMenuButton<String>(
                        tooltip: 'Más opciones',
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        surfaceTintColor: Colors.transparent,
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isDark ? const Color(0xFF334155) : ZanateColors.subtleBorder,
                            width: 0.8,
                          ),
                        ),
                        icon: Icon(
                          PhosphorIconsRegular.dotsThreeVertical,
                          size: 18,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                        onSelected: (val) {
                          if (val == 'report' && widget.onReport != null) {
                            ReportDialog.show(
                              context,
                              title: 'Reportar Publicación',
                              subtitle: 'Anuncio: ${item.title}',
                              onSubmitted: widget.onReport!,
                            );
                          }
                        },
                        itemBuilder: (ctx) => [
                          PopupMenuItem(
                            value: 'report',
                            height: 40,
                            child: Row(
                              children: const [
                                Icon(
                                  PhosphorIconsRegular.flag,
                                  size: 16,
                                  color: Color(0xFFEF4444),
                                ),
                                SizedBox(width: 10),
                                Text('Reportar', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (widget.onTap != null) {
      return InkWell(
        onTap: widget.onTap,
        child: cardWidget,
      );
    }
    return cardWidget;
  }
}
