import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../core/constants/zanate_colors.dart';
import '../../../core/models/marketplace_item.dart';
import '../../../core/utils/responsive.dart';
import '../../shared/widgets/report_dialog.dart';

class SponsoredContentControls extends StatelessWidget {
  final MarketplaceItem item;
  final VoidCallback onHide;
  final ValueChanged<String> onReport;
  final bool overImage;

  const SponsoredContentControls({
    super.key,
    required this.item,
    required this.onHide,
    required this.onReport,
    this.overImage = false,
  });

  String get _accessibleSponsorLabel {
    final brand = item.normalizedSponsorBrandName;
    return brand == null
        ? 'Contenido patrocinado'
        : 'Contenido patrocinado por $brand';
  }

  void _showWhy(BuildContext context) {
    final brand = item.normalizedSponsorBrandName;
    final explanation = brand == null
        ? 'Este contenido fue incluido como promoción en Marketplace. Actualmente no se informa una razón de segmentación más específica.'
        : 'Este contenido fue promocionado por $brand en Marketplace. Actualmente no se informa una razón de segmentación más específica.';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: ZanateColors.card(isDark),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: ZanateColors.border(isDark)),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '¿Por qué veo esto?',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w700,
                fontSize: 19,
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
        ),
        content: Text(
          explanation,
          style: TextStyle(
            fontSize: 13.5,
            height: 1.45,
            color: ZanateColors.textSecondary(isDark),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ZanateColors.ctaBg(isDark),
              foregroundColor: ZanateColors.ctaFg(isDark),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(
              'Cerrar',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _report(BuildContext context) {
    ReportDialog.show(
      context,
      title: 'Reportar anuncio patrocinado',
      subtitle: 'Anuncio: ${item.title}',
      onSubmitted: onReport,
    );
  }

  void _selectAction(BuildContext context, String action) {
    switch (action) {
      case 'why':
        _showWhy(context);
        break;
      case 'hide':
        onHide();
        break;
      case 'report':
        _report(context);
        break;
    }
  }

  void _openMobileActions(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ZanateColors.bg(isDark),
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(
          color: ZanateColors.border(isDark),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: PhosphorIcon(
                PhosphorIconsRegular.info,
                color: isDark ? Colors.white : ZanateColors.zanateBlack,
              ),
              title: const Text('¿Por qué veo esto?'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _showWhy(context);
              },
            ),
            ListTile(
              leading: PhosphorIcon(
                PhosphorIconsRegular.eyeSlash,
                color: isDark ? Colors.white : ZanateColors.zanateBlack,
              ),
              title: const Text('Ocultar este anuncio'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onHide();
              },
            ),
            ListTile(
              leading: PhosphorIcon(
                PhosphorIconsRegular.flag,
                color: const Color(0xFFEF4444),
              ),
              title: const Text('Reportar'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _report(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brand = item.normalizedSponsorBrandName;
    final isMobile = Responsive.isMobile(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final menuForeground = overImage
        ? Colors.white
        : (isDark ? Colors.white : ZanateColors.zanateBlack);
    final menuBackground = overImage
        ? Colors.black.withValues(alpha: 0.72)
        : null;

    return Row(
      children: [
        Expanded(
          child: Semantics(
            container: true,
            label: _accessibleSponsorLabel,
            child: ExcludeSemantics(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: ZanateColors.zanateEyeYellow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Patrocinado',
                      style: GoogleFonts.outfit(
                        color: ZanateColors.zanateBlack,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (brand != null) ...[
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'por $brand',
                        style: TextStyle(
                          color: overImage
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurface,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          shadows: overImage
                              ? const [
                                  Shadow(color: Colors.black87, blurRadius: 4),
                                ]
                              : null,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 48,
          height: 48,
          child: isMobile
              ? IconButton(
                  tooltip: 'Opciones del contenido patrocinado',
                  onPressed: () => _openMobileActions(context),
                  style: IconButton.styleFrom(
                    foregroundColor: menuForeground,
                    backgroundColor: menuBackground,
                    minimumSize: const Size(48, 48),
                  ),
                  icon: const PhosphorIcon(PhosphorIconsBold.dotsThreeVertical),
                )
              : PopupMenuButton<String>(
                  tooltip: 'Opciones del contenido patrocinado',
                  color: ZanateColors.card(isDark),
                  surfaceTintColor: Colors.transparent,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: ZanateColors.border(isDark),
                    ),
                  ),
                  padding: EdgeInsets.zero,
                  icon: PhosphorIcon(
                    PhosphorIconsBold.dotsThreeVertical,
                    color: menuForeground,
                  ),
                  onSelected: (action) => _selectAction(context, action),
                  itemBuilder: (menuContext) => const [
                    PopupMenuItem(
                      value: 'why',
                      height: 48,
                      child: Text('¿Por qué veo esto?'),
                    ),
                    PopupMenuItem(
                      value: 'hide',
                      height: 48,
                      child: Text('Ocultar este anuncio'),
                    ),
                    PopupMenuItem(
                      value: 'report',
                      height: 48,
                      child: Text('Reportar'),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
