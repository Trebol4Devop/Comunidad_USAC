import 'package:flutter/material.dart';
import '../../../core/constants/categories.dart';
import '../../../core/models/marketplace_item.dart';
import '../../../core/utils/time_utils.dart';
import '../../../core/utils/url_utils.dart';
import '../../shared/widgets/image_viewer_dialog.dart';
import '../../shared/widgets/report_dialog.dart';

class MarketplaceCard extends StatefulWidget {
  final MarketplaceItem item;
  final VoidCallback onUpvote;
  final Function(String reason)? onReport;
  final Function(String newStatus)? onStatusChanged;
  final bool isOwner;

  const MarketplaceCard({
    super.key,
    required this.item,
    required this.onUpvote,
    this.onReport,
    this.onStatusChanged,
    this.isOwner = false,
  });

  @override
  State<MarketplaceCard> createState() => _MarketplaceCardState();
}

class _MarketplaceCardState extends State<MarketplaceCard> {
  int _currentImageIndex = 0;

  String _getCategoryLabel(String catId) {
    final match = USACConstants.marketplaceCategories.where((c) => c.id == catId);
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
    if (lower.contains('facebook.com') || lower.contains('fb.com')) return 'Facebook';
    if (lower.contains('tiktok.com')) return 'TikTok';
    if (lower.contains('drive.google.com')) return 'Drive / Menú';
    return 'Enlace';
  }

  IconData _getDomainIcon(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('instagram.com')) return Icons.camera_alt_outlined;
    if (lower.contains('facebook.com') || lower.contains('fb.com')) return Icons.facebook;
    if (lower.contains('tiktok.com')) return Icons.music_note_outlined;
    return Icons.link;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final item = widget.item;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: item.isSponsored ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: item.isSponsored
            ? const BorderSide(color: Color(0xFFEAB308), width: 1.5)
            : (isDark
                ? const BorderSide(color: Color(0xFF334155))
                : BorderSide(color: Colors.grey.shade200)),
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
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                child: item.imageUrls.isNotEmpty
                    ? PageView.builder(
                        itemCount: item.imageUrls.length,
                        onPageChanged: (idx) => setState(() => _currentImageIndex = idx),
                        itemBuilder: (ctx, i) {
                          final imgUrl = item.imageUrls[i];
                          return InkWell(
                            onTap: () => ImageViewerDialog.show(
                              context,
                              imageUrl: imgUrl,
                              title: '${item.title} (${i + 1}/${item.imageUrls.length})',
                            ),
                            child: Image.network(
                              imgUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Center(
                                child: Icon(_getCategoryIcon(item.category), size: 48, color: Colors.grey.shade400),
                              ),
                            ),
                          );
                        },
                      )
                    : Center(
                        child: Icon(_getCategoryIcon(item.category), size: 48, color: theme.colorScheme.primary.withValues(alpha: 0.4)),
                      ),
              ),

              // Multi-image indicators
              if (item.imageUrls.length > 1)
                Positioned(
                  bottom: 6,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_currentImageIndex + 1}/${item.imageUrls.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

              // Sold Watermark Overlay
              if (item.isSold)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.6),
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.shade700,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Text(
                        'VENDIDO',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 2,
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
                    color: Colors.amber.shade700.withValues(alpha: 0.9),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    alignment: Alignment.center,
                    child: const Text(
                      'ARTÍCULO RESERVADO',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),

              // Price badge (Top Right)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: item.isSold
                        ? Colors.grey.shade700
                        : (item.isFree
                            ? const Color(0xFF16A34A)
                            : (item.isSponsored ? const Color(0xFFD97706) : const Color(0xFF004B87))),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: Text(
                    item.isSold ? 'VENDIDO' : item.formattedPrice,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_getCategoryIcon(item.category), size: 12, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        _getCategoryLabel(item.category),
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),

              // Sponsored Tag
              if (item.isSponsored)
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF08A),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFCA8A04)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, size: 11, color: Color(0xFF854D0E)),
                        const SizedBox(width: 3),
                        Text(
                          item.sponsorBadgeText ?? 'Patrocinador',
                          style: const TextStyle(
                            color: Color(0xFF854D0E),
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
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
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),

                // Delivery location
                Row(
                  children: [
                    Icon(Icons.place_outlined, size: 14, color: theme.colorScheme.primary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        item.buildingCode.isNotEmpty
                            ? '${item.buildingCode} · ${item.locationDetail.isNotEmpty ? item.locationDetail : _getSedeName(item.sede)}'
                            : (item.locationDetail.isNotEmpty ? item.locationDetail : _getSedeName(item.sede)),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_getDomainIcon(link), size: 12, color: theme.colorScheme.primary),
                              const SizedBox(width: 4),
                              Text(
                                _getDomainLabel(link),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.play_circle_fill, size: 13, color: Color(0xFFEF4444)),
                          SizedBox(width: 4),
                          Text(
                            'Ver Video Promocional',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 10),

                // Author & Verification Badge
                Row(
                  children: [
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: item.isSellerVerified
                          ? const Color(0xFF10B981).withValues(alpha: 0.15)
                          : theme.colorScheme.primary.withValues(alpha: 0.1),
                      child: Icon(
                        item.isSellerVerified ? Icons.verified_user : Icons.person,
                        size: 13,
                        color: item.isSellerVerified ? const Color(0xFF059669) : theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.authorAlias,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 4),
                          if (item.isSellerVerified)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFF059669),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.verified, size: 10, color: Colors.white),
                                  SizedBox(width: 2),
                                  Text(
                                    'Vendedor Verificado',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      TimeUtils.timeAgo(item.createdAt),
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                    ),
                  ],
                ),

                // Preventive Banner if Seller is NOT verified
                if (!item.isSellerVerified && !item.isSold) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isDark ? const Color(0xFFD97706) : const Color(0xFFF59E0B),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 14,
                          color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Vendedor no validado con carné. Se sugiere realizar la transacción en persona dentro del campus.',
                            style: TextStyle(
                              fontSize: 10,
                              height: 1.25,
                              fontWeight: FontWeight.w500,
                              color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // 1-Touch Product Lifecycle Buttons (For Seller or Owner)
                if (widget.onStatusChanged != null && (widget.isOwner || item.userId != null)) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (!item.isReserved && !item.isSold)
                        ActionChip(
                          avatar: const Icon(Icons.bookmark_outline, size: 14, color: Colors.amber),
                          label: const Text('Marcar Reservado', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          onPressed: () => widget.onStatusChanged!('reserved'),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                      if (item.isReserved)
                        ActionChip(
                          avatar: const Icon(Icons.check_circle_outline, size: 14, color: Colors.blue),
                          label: const Text('Disponible', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          onPressed: () => widget.onStatusChanged!('available'),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                      if (!item.isSold)
                        ActionChip(
                          avatar: const Icon(Icons.done_all, size: 14, color: Colors.green),
                          label: const Text('Marcar Vendido', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          onPressed: () => widget.onStatusChanged!('sold'),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                      if (item.status != 'paused' && !item.isSold)
                        ActionChip(
                          avatar: const Icon(Icons.pause_circle_outline, size: 14, color: Colors.grey),
                          label: const Text('Pausar', style: TextStyle(fontSize: 11)),
                          onPressed: () => widget.onStatusChanged!('paused'),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                      if (item.status == 'paused')
                        ActionChip(
                          avatar: const Icon(Icons.play_circle_outline, size: 14, color: Colors.green),
                          label: const Text('Reanudar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          onPressed: () => widget.onStatusChanged!('available'),
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: item.isUpvotedByMe
                              ? theme.colorScheme.primary.withValues(alpha: 0.12)
                              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              item.isUpvotedByMe ? Icons.favorite : Icons.favorite_border,
                              size: 14,
                              color: item.isUpvotedByMe ? Colors.red : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${item.upvotes}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: item.isUpvotedByMe ? theme.colorScheme.primary : Colors.grey.shade700,
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
                                  onTap: () => UrlUtils.openUrl(context, item.whatsappUrl!),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF25D366),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(Icons.chat, size: 13, color: Colors.white),
                                        SizedBox(width: 4),
                                        Text('WhatsApp', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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
                                  onTap: () => UrlUtils.openUrl(context, item.instagramUrl!),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE1306C),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(Icons.camera_alt_outlined, size: 13, color: Colors.white),
                                        SizedBox(width: 4),
                                        Text('Instagram', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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
                                  onTap: () => UrlUtils.openUrl(context, item.messengerUrl!),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0084FF),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(Icons.message_outlined, size: 13, color: Colors.white),
                                        SizedBox(width: 4),
                                        Text('Messenger', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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
                                  onTap: () => UrlUtils.openUrl(context, item.telegramUrl!),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF229ED9),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(Icons.send_outlined, size: 13, color: Colors.white),
                                        SizedBox(width: 4),
                                        Text('Telegram', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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

                    // Report menu
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, size: 16, color: Colors.grey.shade600),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
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
                        const PopupMenuItem(
                          value: 'report',
                          child: Row(
                            children: [
                              Icon(Icons.flag_outlined, size: 16, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Reportar contenido'),
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
