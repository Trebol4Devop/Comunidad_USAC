import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../core/constants/zanate_colors.dart';
import '../../../core/models/whatsapp_group.dart';
import '../../../core/utils/time_utils.dart';
import '../../../core/utils/url_utils.dart';
import '../../shared/widgets/image_viewer_dialog.dart';
import '../../shared/widgets/report_dialog.dart';

class GroupCard extends StatelessWidget {
  final WhatsAppGroup group;
  final VoidCallback onUpvote;
  final Function(String reason)? onReport;

  const GroupCard({
    super.key,
    required this.group,
    required this.onUpvote,
    this.onReport,
  });

  String _getPlatformLabel(GroupPlatform platform) {
    switch (platform) {
      case GroupPlatform.whatsApp:
        return 'WhatsApp';
      case GroupPlatform.telegram:
        return 'Telegram';
      case GroupPlatform.discord:
        return 'Discord';
      case GroupPlatform.drive:
        return 'Drive';
      case GroupPlatform.other:
        return 'Enlace Web';
    }
  }

  IconData _getPlatformIcon(GroupPlatform platform) {
    switch (platform) {
      case GroupPlatform.whatsApp:
        return PhosphorIconsFill.whatsappLogo;
      case GroupPlatform.telegram:
        return PhosphorIconsFill.telegramLogo;
      case GroupPlatform.discord:
        return PhosphorIconsFill.discordLogo;
      case GroupPlatform.drive:
        return PhosphorIconsRegular.folder;
      case GroupPlatform.other:
        return PhosphorIconsRegular.link;
    }
  }

  Color _getPlatformColor(GroupPlatform platform) {
    switch (platform) {
      case GroupPlatform.whatsApp:
        return const Color(0xFF25D366);
      case GroupPlatform.telegram:
        return const Color(0xFF0088CC);
      case GroupPlatform.discord:
        return const Color(0xFF5865F2);
      case GroupPlatform.drive:
        return const Color(0xFF0F9D58);
      case GroupPlatform.other:
        return ZanateColors.zanateAccent;
    }
  }

  String? _validatedExternalUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;

    final hasScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:').hasMatch(trimmed);
    final uri = Uri.tryParse(hasScheme ? trimmed : 'https://$trimmed');
    if (uri == null ||
        !const {'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    return uri.toString();
  }

  Future<void> _openGroupLink(BuildContext context) async {
    final safeUrl = _validatedExternalUrl(group.link);
    if (safeUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El enlace del grupo no es válido.')),
      );
      return;
    }
    await UrlUtils.openUrl(context, safeUrl);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final platform = group.platform;
    final platformColor = _getPlatformColor(platform);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : ZanateColors.subtleBorder,
            width: 0.8,
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Course badge, Section badge, Platform badge, More options
            Row(
              children: [
                // Platform and section details
                Icon(
                  _getPlatformIcon(platform),
                  size: 14,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
                const SizedBox(width: 5),
                Text(
                  _getPlatformLabel(platform),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),

                // Section tag
                Text(
                  '· ${group.section}',
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),

                const Spacer(),

                if (onReport != null)
                  PopupMenuButton<String>(
                    tooltip: 'Más opciones',
                    color: theme.colorScheme.surface,
                    surfaceTintColor: Colors.transparent,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: theme.colorScheme.outlineVariant),
                    ),
                    icon: Icon(
                      Icons.more_vert,
                      size: 18,
                      color: theme.colorScheme.onSurface,
                    ),
                    onSelected: (val) {
                      if (val == 'report' && onReport != null) {
                        ReportDialog.show(
                          context,
                          title: 'Reportar Grupo',
                          subtitle: group.title,
                          reasonOptions: const [
                            'El enlace de invitación está expirado o revocado',
                            'El grupo es de otra sección o curso',
                            'Grupo lleno / límite de participantes',
                            'Spam, publicidad o cobros de dinero',
                            'Otro motivo',
                          ],
                          onSubmitted: onReport!,
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

            const SizedBox(height: 8),

            // Creator and time
            Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 15,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    group.authorAlias,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  ' · ${TimeUtils.timeAgo(group.createdAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Course Name (Big)
            Text(
              group.curso.isNotEmpty ? group.curso : group.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),

            // Group Subtitle / Description
            if (group.title != group.curso && group.title.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                group.title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
            ],

            if (group.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                group.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
              ),
            ],

            // Optional Image / Banner Preview
            if (group.imageUrl != null && group.imageUrl!.isNotEmpty) ...[
              const SizedBox(height: 10),
              InkWell(
                onTap: () => ImageViewerDialog.show(
                  context,
                  imageUrl: group.imageUrl!,
                  title: group.title,
                ),
                borderRadius: BorderRadius.circular(8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    children: [
                      Image.network(
                        group.imageUrl!,
                        width: double.infinity,
                        height: 140,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) =>
                            const SizedBox.shrink(),
                      ),
                      Positioned(
                        bottom: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.zoom_in,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),
            Container(
              height: 0.8,
              color: isDark ? const Color(0xFF334155) : ZanateColors.subtleBorder,
            ),
            const SizedBox(height: 12),

            // Actions Row: Upvote, Copy link, Join Button
            LayoutBuilder(
              builder: (context, constraints) {
                final compactJoinAction = constraints.maxWidth < 360;
                return Row(
                  children: [
                    // Upvote pill button
                    InkWell(
                      onTap: onUpvote,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: group.isUpvotedByMe
                              ? ZanateColors.zanateAccent.withValues(alpha: 0.12)
                              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: group.isUpvotedByMe
                                ? ZanateColors.zanateAccent
                                : (isDark ? const Color(0xFF334155) : ZanateColors.subtleBorder),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              group.isUpvotedByMe
                                  ? PhosphorIconsFill.arrowFatUp
                                  : PhosphorIconsRegular.arrowFatUp,
                              size: 15,
                              color: group.isUpvotedByMe
                                  ? ZanateColors.zanateAccent
                                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '${group.upvotes}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: group.isUpvotedByMe
                                    ? ZanateColors.zanateAccent
                                    : (isDark ? const Color(0xFFE2E8F0) : ZanateColors.zanateDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Minimalist copy button
                    IconButton(
                      icon: Icon(
                        PhosphorIconsRegular.copy,
                        size: 17,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      tooltip: 'Copiar enlace',
                      onPressed: () => UrlUtils.copyToClipboard(
                        context,
                        group.link,
                        message: 'Enlace del grupo copiado al portapapeles',
                      ),
                    ),
                    const Spacer(),
                    // Join action button
                    ElevatedButton.icon(
                      onPressed: () => _openGroupLink(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: platformColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                      ),
                      icon: Icon(_getPlatformIcon(platform), size: 15),
                      label: Text(
                        compactJoinAction ? 'Unirse' : 'Unirse al Grupo',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
  }
}
