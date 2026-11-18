import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../core/constants/zanate_colors.dart';
import '../../../core/models/marketplace_item.dart';
import '../../../core/utils/url_utils.dart';
import 'sponsored_content_controls.dart';

class SponsorCarousel extends StatelessWidget {
  final List<MarketplaceItem> sponsoredItems;
  final VoidCallback onRequestSponsor;
  final ValueChanged<MarketplaceItem> onHideSponsored;
  final Function(MarketplaceItem item, String reason) onReportSponsored;

  const SponsorCarousel({
    super.key,
    required this.sponsoredItems,
    required this.onRequestSponsor,
    required this.onHideSponsored,
    required this.onReportSponsored,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (sponsoredItems.isEmpty) {
      // Prompt banner to invite sponsors
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isDark ? const Color(0xFF334155) : ZanateColors.subtleBorder,
            width: 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ZanateColors.zanateEyeYellow.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: PhosphorIcon(
                PhosphorIconsBold.megaphoneSimple,
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
                    'Espacio para Patrocinadores y Emprendimientos',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: isDark ? Colors.white : ZanateColors.zanateBlack,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Llega a miles de estudiantes en primera plana con fotos y video.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : ZanateColors.subtleText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark
                    ? ZanateColors.zanateEyeYellow
                    : ZanateColors.zanateBlack,
                foregroundColor:
                    isDark ? ZanateColors.zanateBlack : Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
              onPressed: onRequestSponsor,
              child: const Text(
                'Anunciarme',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
    }

    final item = sponsoredItems.first;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ZanateColors.zanateEyeYellow,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SponsoredContentControls(
                  item: item,
                  onHide: () => onHideSponsored(item),
                  onReport: (reason) => onReportSponsored(item, reason),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onRequestSponsor,
                    icon: PhosphorIcon(
                      PhosphorIconsRegular.plusCircle,
                      size: 16,
                      color: isDark
                          ? ZanateColors.zanateEyeYellow
                          : ZanateColors.zanateBlack,
                    ),
                    label: Text(
                      'Anunciarme aquí',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? ZanateColors.zanateEyeYellow
                            : ZanateColors.zanateBlack,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Sponsor details & multimedia
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail or gallery preview
                if (item.imageUrls.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 100,
                      height: 100,
                      color: isDark
                          ? const Color(0xFF0F172A)
                          : ZanateColors.surfaceBg,
                      child: Image.network(
                        item.imageUrls.first,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const PhosphorIcon(
                              PhosphorIconsRegular.storefront,
                              size: 36,
                              color: ZanateColors.hintText,
                            ),
                      ),
                    ),
                  ),
                const SizedBox(width: 14),

                // Text info & actions
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              (item.sellerBusinessName != null && item.sellerBusinessName!.trim().isNotEmpty)
                                  ? item.sellerBusinessName!
                                  : (item.normalizedSponsorBrandName ?? item.authorAlias),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? ZanateColors.zanateEyeYellow
                                    : ZanateColors.zanateBlack,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (item.sellerBadgeText != null && item.sellerBadgeText!.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: ZanateColors.zanateEyeYellow
                                    .withValues(alpha: 0.28),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.sellerBadgeText!,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? ZanateColors.zanateEyeYellow
                                      : ZanateColors.zanateBlack,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.title,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w700,
                          fontSize: 15.5,
                          color: isDark
                              ? Colors.white
                              : ZanateColors.zanateBlack,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Location & Video button & WhatsApp Button
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (item.buildingCode.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF0F172A)
                                    : ZanateColors.surfaceBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF334155)
                                      : ZanateColors.subtleBorder,
                                ),
                              ),
                              child: Text(
                                'Ubicación: ${item.buildingCode}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? Colors.white
                                      : ZanateColors.zanateBlack,
                                ),
                              ),
                            ),

                          if (item.videoUrl != null &&
                              item.videoUrl!.isNotEmpty)
                            ActionChip(
                              avatar: const PhosphorIcon(
                                PhosphorIconsFill.playCircle,
                                size: 15,
                                color: Colors.red,
                              ),
                              label: const Text(
                                'Ver Video',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: () =>
                                  UrlUtils.openUrl(context, item.videoUrl!),
                              padding: EdgeInsets.zero,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),

                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              minimumSize: const Size(0, 34),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            icon: const Icon(PhosphorIconsFill.whatsappLogo, size: 14),
                            label: const Text(
                              'Contactar por WhatsApp',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: () {
                              final contact =
                                  item.whatsappUrl ??
                                  item.instagramUrl ??
                                  item.messengerUrl ??
                                  item.telegramUrl ??
                                  item.videoUrl ??
                                  '';
                              UrlUtils.openUrl(context, contact);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
