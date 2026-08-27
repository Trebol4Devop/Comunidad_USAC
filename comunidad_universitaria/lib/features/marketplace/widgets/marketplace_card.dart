import 'package:flutter/material.dart';
import '../../../core/constants/categories.dart';
import '../../../core/models/marketplace_item.dart';
import '../../../core/utils/time_utils.dart';
import '../../../core/utils/url_utils.dart';
import '../../shared/widgets/report_dialog.dart';

class MarketplaceCard extends StatelessWidget {
  final MarketplaceItem item;
  final VoidCallback onUpvote;
  final Function(String reason)? onReport;

  const MarketplaceCard({
    super.key,
    required this.item,
    required this.onUpvote,
    this.onReport,
  });

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
          // Top Image or Category placeholder
          Stack(
            children: [
              Container(
                height: 140,
                width: double.infinity,
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                child: item.imageUrls.isNotEmpty
                    ? Image.network(
                        item.imageUrls.first,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Center(
                          child: Icon(_getCategoryIcon(item.category), size: 48, color: Colors.grey.shade400),
                        ),
                      )
                    : Center(
                        child: Icon(_getCategoryIcon(item.category), size: 48, color: theme.colorScheme.primary.withValues(alpha: 0.4)),
                      ),
              ),

              // Price badge (Top Right)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: item.isFree
                        ? const Color(0xFF16A34A)
                        : (item.isSponsored ? const Color(0xFFD97706) : const Color(0xFF004B87)),
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
                    item.formattedPrice,
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
                child: Row(
                  children: [
                    Container(
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
                  ],
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

                // Delivery location / Building tag
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
                const SizedBox(height: 12),

                // Author & Time
                Row(
                  children: [
                    CircleAvatar(
                      radius: 10,
                      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                      child: Icon(Icons.person, size: 12, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.authorAlias,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ),
                    Text(
                      TimeUtils.timeAgo(item.createdAt),
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                    ),
                  ],
                ),

                const Divider(height: 18),

                // Footer: Upvote + WhatsApp Contact Button + Report
                Row(
                  children: [
                    // Upvote button
                    InkWell(
                      onTap: onUpvote,
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

                    // WhatsApp Direct Contact Button
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          minimumSize: const Size(0, 32),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.chat, size: 14),
                        label: const Text(
                          'Contactar',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          UrlUtils.openUrl(context, item.whatsappUrl);
                        },
                      ),
                    ),

                    const SizedBox(width: 4),

                    // More / Report menu
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, size: 16, color: Colors.grey.shade600),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onSelected: (val) {
                        if (val == 'report' && onReport != null) {
                          ReportDialog.show(
                            context,
                            title: 'Reportar Publicación',
                            subtitle: 'Anuncio: ${item.title}',
                            onSubmitted: onReport!,
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
