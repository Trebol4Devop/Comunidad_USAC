import 'package:flutter/material.dart';
import '../../../core/models/whatsapp_group.dart';
import '../../../core/utils/time_utils.dart';
import '../../../core/utils/url_utils.dart';
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

  Color _getPlatformColor(GroupPlatform platform) {
    switch (platform) {
      case GroupPlatform.whatsApp:
        return const Color(0xFF25D366);
      case GroupPlatform.telegram:
        return const Color(0xFF0088CC);
      case GroupPlatform.discord:
        return const Color(0xFF5865F2);
      case GroupPlatform.drive:
        return const Color(0xFFFBBC05);
      case GroupPlatform.other:
        return const Color(0xFF004B87);
    }
  }

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
        return Icons.chat;
      case GroupPlatform.telegram:
        return Icons.send_rounded;
      case GroupPlatform.discord:
        return Icons.headset_mic_rounded;
      case GroupPlatform.drive:
        return Icons.folder_shared_outlined;
      case GroupPlatform.other:
        return Icons.link;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final platform = group.platform;
    final platformColor = _getPlatformColor(platform);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Course badge, Section badge, Platform badge, More options
            Row(
              children: [
                // Platform tag
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: platformColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: platformColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_getPlatformIcon(platform), size: 12, color: platformColor),
                      const SizedBox(width: 4),
                      Text(
                        _getPlatformLabel(platform),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: platformColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Section tag
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    group.section,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                    ),
                  ),
                ),

                const Spacer(),

                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, size: 18, color: Colors.grey.shade600),
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
                    const PopupMenuItem(
                      value: 'report',
                      child: Row(
                        children: [
                          Icon(Icons.flag_outlined, size: 16, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Reportar enlace caído/spam'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

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
                  color: theme.colorScheme.primary,
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

            const SizedBox(height: 12),

            // Creator & Time
            Row(
              children: [
                Icon(Icons.person_outline, size: 13, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  group.authorAlias,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, fontWeight: FontWeight.w500),
                ),
                Text(
                  ' • ${TimeUtils.timeAgo(group.createdAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Actions Row: Upvote, Copy link, Join Button
            Row(
              children: [
                // Upvote button
                InkWell(
                  onTap: onUpvote,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: group.isUpvotedByMe
                          ? theme.colorScheme.primary.withValues(alpha: 0.12)
                          : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          group.isUpvotedByMe ? Icons.thumb_up : Icons.thumb_up_alt_outlined,
                          size: 15,
                          color: group.isUpvotedByMe
                              ? theme.colorScheme.primary
                              : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${group.upvotes}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: group.isUpvotedByMe
                                ? theme.colorScheme.primary
                                : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Copy Link Button
                IconButton.outlined(
                  icon: const Icon(Icons.copy, size: 16),
                  tooltip: 'Copiar enlace',
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => UrlUtils.copyToClipboard(
                    context,
                    group.link,
                    message: 'Enlace del grupo copiado al portapapeles',
                  ),
                ),

                const Spacer(),

                // Join Button
                ElevatedButton.icon(
                  onPressed: () => UrlUtils.openUrl(context, group.link),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: platformColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  icon: Icon(_getPlatformIcon(platform), size: 16),
                  label: const Text('Unirse al Grupo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
