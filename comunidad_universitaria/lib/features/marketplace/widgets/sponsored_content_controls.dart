import 'package:flutter/material.dart';

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

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Por qué veo esto?'),
        content: Text(explanation),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cerrar'),
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
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                Icons.info_outline,
                color: theme.colorScheme.onSurface,
              ),
              title: const Text('¿Por qué veo esto?'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _showWhy(context);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.visibility_off_outlined,
                color: theme.colorScheme.onSurface,
              ),
              title: const Text('Ocultar este anuncio'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onHide();
              },
            ),
            ListTile(
              leading: Icon(
                Icons.flag_outlined,
                color: theme.colorScheme.onSurface,
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
    final menuForeground = overImage
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
    final menuBackground = overImage
        ? Colors.black.withValues(alpha: 0.72)
        : null;

    return Row(
      children: [
        Semantics(
          container: true,
          label: _accessibleSponsorLabel,
          child: ExcludeSemantics(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF08A),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF854D0E)),
                  ),
                  child: const Text(
                    'Patrocinado',
                    style: TextStyle(
                      color: Color(0xFF422006),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (brand != null) ...[
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: Text(
                      'por $brand',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
        const Spacer(),
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
                  icon: const Icon(Icons.more_vert),
                )
              : PopupMenuButton<String>(
                  tooltip: 'Opciones del contenido patrocinado',
                  color: Theme.of(context).colorScheme.surface,
                  surfaceTintColor: Colors.transparent,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  padding: EdgeInsets.zero,
                  icon: Icon(Icons.more_vert, color: menuForeground),
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
