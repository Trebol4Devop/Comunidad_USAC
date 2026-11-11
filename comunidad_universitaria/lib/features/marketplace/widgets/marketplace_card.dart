import 'package:flutter/material.dart';
import '../../../core/constants/categories.dart';
import '../../../core/models/marketplace_item.dart';
import '../../../core/utils/responsive.dart';
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
  final bool isOwner;

  const MarketplaceCard({
    super.key,
    required this.item,
    required this.onUpvote,
    this.onReport,
    this.onStatusChanged,
    this.onSponsoredHide,
    this.isOwner = false,
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
        return Icons.cake_outlined;
      case 'tutorias_academica':
        return Icons.school_outlined;
      case 'libros_materiales':
        return Icons.menu_book_outlined;
      case 'servicios_estudiantiles':
        return Icons.design_services_outlined;
      default:
        return Icons.inventory_2_outlined;
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
    if (lower.contains('instagram.com')) return Icons.camera_alt_outlined;
    if (lower.contains('facebook.com') || lower.contains('fb.com')) {
      return Icons.facebook;
    }
    if (lower.contains('tiktok.com')) return Icons.music_note_outlined;
    return Icons.link;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMobile = Responsive.isMobile(context);
    final item = widget.item;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: isMobile
          ? const RoundedRectangleBorder()
          : RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isDark
                    ? const Color(0xFF383A40)
                    : const Color(0xFFD9D9D9),
              ),
            ),
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
                    ? const Color(0xFF1E293B)
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

              // Price badge (Top Right)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                  child: Text(
                    item.isSold ? 'VENDIDO' : item.formattedPrice,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),

              // Category & Sede badges (Top Left)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getCategoryIcon(item.category),
                        size: 12,
                        color: theme.colorScheme.onSurface,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _getCategoryLabel(item.category),
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 10,
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
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.authorAlias,
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
                        ],
                      ),
                    ),
                    Text(
                      TimeUtils.timeAgo(item.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                    ),
                  ],
                ),
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
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),

                // Delivery location
                Row(
                  children: [
                    Icon(
                      Icons.place_outlined,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
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

                // Preventive Banner if Seller is NOT verified
                if (!item.isSellerVerified && !item.isSold) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Vendedor no validado con carné. Se sugiere realizar la transacción en persona dentro del campus.',
                            style: TextStyle(
                              fontSize: 10,
                              height: 1.25,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // 1-Touch Product Lifecycle Buttons (For Seller or Owner)
                if (widget.onStatusChanged != null &&
                    (widget.isOwner || item.isMine)) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (!item.isReserved && !item.isSold)
                        ActionChip(
                          avatar: Icon(
                            Icons.bookmark_outline,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          label: const Text(
                            'Marcar Reservado',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () => widget.onStatusChanged!('reserved'),
                          backgroundColor: theme.colorScheme.surface,
                          side: BorderSide(color: theme.dividerColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                      if (item.isReserved)
                        ActionChip(
                          avatar: Icon(
                            Icons.check_circle_outline,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          label: const Text(
                            'Disponible',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () => widget.onStatusChanged!('available'),
                          backgroundColor: theme.colorScheme.surface,
                          side: BorderSide(color: theme.dividerColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                      if (!item.isSold)
                        ActionChip(
                          avatar: Icon(
                            Icons.done_all,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          label: const Text(
                            'Marcar Vendido',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () => widget.onStatusChanged!('sold'),
                          backgroundColor: theme.colorScheme.surface,
                          side: BorderSide(color: theme.dividerColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                      if (item.status != 'paused' && !item.isSold)
                        ActionChip(
                          avatar: Icon(
                            Icons.pause_circle_outline,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          label: const Text(
                            'Pausar',
                            style: TextStyle(fontSize: 11),
                          ),
                          onPressed: () => widget.onStatusChanged!('paused'),
                          backgroundColor: theme.colorScheme.surface,
                          side: BorderSide(color: theme.dividerColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                      if (item.status == 'paused')
                        ActionChip(
                          avatar: Icon(
                            Icons.play_circle_outline,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          label: const Text(
                            'Reanudar',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () => widget.onStatusChanged!('available'),
                          backgroundColor: theme.colorScheme.surface,
                          side: BorderSide(color: theme.dividerColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                    ],
                  ),
                ],

                const Divider(height: 16),

                // Contact channels & Upvote Row
                Row(
                  children: [
                    // Upvote button
                    InkWell(
                      onTap: widget.onUpvote,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: const BoxDecoration(),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              item.isUpvotedByMe
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 14,
                              color: item.isUpvotedByMe
                                  ? theme.colorScheme.onSurface
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${item.upvotes}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Contact icons / buttons
                    Expanded(
                      child: SingleChildScrollView(
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
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surface,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: theme.dividerColor,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.chat_outlined,
                                          size: 13,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'WhatsApp',
                                          style: TextStyle(
                                            color: theme.colorScheme.onSurface,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
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
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surface,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: theme.dividerColor,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.camera_alt_outlined,
                                          size: 13,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Instagram',
                                          style: TextStyle(
                                            color: theme.colorScheme.onSurface,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
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
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surface,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: theme.dividerColor,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.message_outlined,
                                          size: 13,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Messenger',
                                          style: TextStyle(
                                            color: theme.colorScheme.onSurface,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
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
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surface,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: theme.dividerColor,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.send_outlined,
                                          size: 13,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Telegram',
                                          style: TextStyle(
                                            color: theme.colorScheme.onSurface,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
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
                        color: theme.colorScheme.surface,
                        surfaceTintColor: Colors.transparent,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        icon: Icon(
                          Icons.more_vert,
                          size: 18,
                          color: theme.colorScheme.onSurface,
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
                            height: 44,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.flag_outlined,
                                  size: 17,
                                  color: theme.colorScheme.onSurface,
                                ),
                                const SizedBox(width: 10),
                                const Text('Reportar'),
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
  }
}
