import 'package:flutter/material.dart';
import '../../../core/constants/categories.dart';
import '../../../core/models/post.dart';
import '../../../core/utils/time_utils.dart';
import '../../shared/widgets/report_dialog.dart';
import 'discord/discord_media_attachment.dart';

class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback onTap;
  final VoidCallback onLike;
  final VoidCallback? onBookmark;
  final VoidCallback? onRepost;
  final VoidCallback? onShare;
  final Function(String pollId, String optionId)? onVotePoll;
  final Function(String reason)? onReport;
  final VoidCallback? onDelete;
  final bool isModerator;

  const PostCard({
    super.key,
    required this.post,
    required this.onTap,
    required this.onLike,
    this.onBookmark,
    this.onRepost,
    this.onShare,
    this.onVotePoll,
    this.onReport,
    this.onDelete,
    this.isModerator = false,
  });

  String _getCategoryLabel(String catId) {
    final match = USACConstants.forumCategories.where((c) => c.id == catId);
    return match.isNotEmpty ? match.first.label : 'General';
  }

  Widget _buildAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    int? count,
    bool isActive = false,
  }) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurface;
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: color),
                if (count != null && count > 0) ...[
                  const SizedBox(width: 4),
                  Text(
                    '$count',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final modStatus = post.moderationStatus;
    final showModBanner = isModerator && modStatus > 0;
    final modColor = modStatus == 1 ? const Color(0xFFEAB308) : const Color(0xFFEF4444);

    final cardBg = theme.colorScheme.surface;
    final cardBorder = showModBanner
        ? modColor
        : theme.colorScheme.outlineVariant;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(
          bottom: BorderSide(
            color: cardBorder,
            width: showModBanner ? 2.0 : 1.0,
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          hoverColor: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.45,
          ),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              if (showModBanner) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: modColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: modColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        modStatus == 1 ? Icons.hourglass_top : Icons.visibility_off,
                        size: 13,
                        color: modColor,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        modStatus == 1 ? 'Pendiente de revisión' : 'Ocultado por reportes',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: modColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // Pinned badge if applicable
              if (post.isPinned) ...[
                Row(
                  children: [
                    Icon(
                      Icons.push_pin,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Publicación Fijada',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              // Header: Author alias, Carrera/Faculty badge, Time ago
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 23,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 2,
                          children: [
                            Text(
                              post.authorAlias,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              _getCategoryLabel(post.category),
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 10,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          TimeUtils.timeAgo(post.createdAt),
                          style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  if (onReport != null || (post.isMine && onDelete != null))
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
                          title: 'Reportar Publicación',
                          subtitle: 'Publicación de ${post.authorAlias}',
                          onSubmitted: onReport!,
                        );
                      } else if (val == 'delete' && onDelete != null) {
                        onDelete!();
                      }
                    },
                    itemBuilder: (ctx) => [
                      if (post.isMine && onDelete != null)
                        const PopupMenuItem(
                          value: 'delete',
                          height: 44,
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline,
                                size: 17,
                                color: Colors.red,
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Eliminar publicación',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      if (onReport != null)
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
              const SizedBox(height: 12),

              // Post Title
              Text(
                post.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 6),

              // Post Preview Content
              Text(
                post.content,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                  height: 1.4,
                ),
              ),

              // Quoted Post Card (Quote Tweet style)
              if (post.quotedPost != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.format_quote, size: 14, color: theme.colorScheme.primary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              post.quotedPost!.authorAlias,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            TimeUtils.timeAgo(post.quotedPost!.createdAt),
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        post.quotedPost!.title,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        post.quotedPost!.content,
                        style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],

              // Interactive Poll Widget if available
              if (post.poll != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.6) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.poll_outlined,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              post.poll!.question,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...post.poll!.options.map((opt) {
                        final total = post.poll!.totalVotes;
                        final rawPercent = total > 0 ? (opt.votesCount / total) : 0.0;
                        final percent = (rawPercent.isNaN || rawPercent.isInfinite) ? 0.0 : rawPercent.clamp(0.0, 1.0);
                        final hasVoted = post.poll!.myVotedOptionId != null;
                        final isMyVote = post.poll!.myVotedOptionId == opt.id;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: InkWell(
                            onTap: onVotePoll != null
                                ? () => onVotePoll!(post.poll!.id, opt.id)
                                : null,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              height: 36,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isMyVote
                                      ? theme.colorScheme.primary
                                      : (isDark ? const Color(0xFF334155) : Colors.grey.shade300),
                                  width: isMyVote ? 1.5 : 1.0,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(7),
                                child: Stack(
                                  children: [
                                    if (hasVoted)
                                      FractionallySizedBox(
                                        widthFactor: percent,
                                        child: Container(
                                          color: isMyVote
                                              ? (isDark
                                                  ? const Color(0xFF3B82F6).withValues(alpha: 0.35)
                                                  : const Color(0xFF004B87).withValues(alpha: 0.22))
                                              : (isDark
                                                  ? Colors.white.withValues(alpha: 0.1)
                                                  : Colors.grey.withValues(alpha: 0.15)),
                                        ),
                                      ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Row(
                                              children: [
                                                if (isMyVote) ...[
                                                  Icon(
                                                    Icons.check_circle,
                                                    size: 14,
                                                    color: theme.colorScheme.primary,
                                                  ),
                                                  const SizedBox(width: 6),
                                                ],
                                                Flexible(
                                                  child: Text(
                                                    opt.optionText,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: isMyVote ? FontWeight.bold : FontWeight.normal,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (hasVoted)
                                            Text(
                                              '${(percent * 100).toStringAsFixed(0)}% · ${opt.votesCount} votos',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: isMyVote
                                                    ? (isDark ? const Color(0xFF93C5FD) : const Color(0xFF004B87))
                                                    : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                      Text(
                        '${post.poll!.totalVotes} votos registrados',
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ],

              // GIF Preview if available
              if (post.gifUrl != null && post.gifUrl!.isNotEmpty) ...[
                const SizedBox(height: 10),
                DiscordMediaAttachment(
                  imageUrl: post.gifUrl!,
                  title: post.title,
                  isGif: true,
                  maxHeight: 240,
                  maxWidth: 460,
                ),
              ],

              // Image Preview if available
              if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
                const SizedBox(height: 10),
                DiscordMediaAttachment(
                  imageUrl: post.imageUrl!,
                  title: post.title,
                  isGif: false,
                  maxHeight: 280,
                  maxWidth: 480,
                ),
              ],

              const SizedBox(height: 14),

              // Acciones en el orden de la interfaz de referencia.
              Row(
                children: [
                  _buildAction(
                    context,
                    icon: Icons.thumb_up_alt_outlined,
                    label: 'Me gusta',
                    onTap: onLike,
                    count: post.likes,
                    isActive: post.isLikedByMe,
                  ),
                  const SizedBox(width: 14),
                  _buildAction(
                    context,
                    icon: Icons.chat_bubble_outline,
                    label: 'Comentar',
                    onTap: onTap,
                    count: post.commentCount,
                  ),
                  const SizedBox(width: 14),
                  if (onRepost != null) ...[
                    _buildAction(
                      context,
                      icon: Icons.repeat,
                      label: 'Republicar',
                      onTap: onRepost,
                      count: post.repostsCount,
                    ),
                    const SizedBox(width: 14),
                  ],
                  if (onShare != null) ...[
                    _buildAction(
                      context,
                      icon: Icons.share_outlined,
                      label: 'Compartir',
                      onTap: onShare,
                    ),
                    const SizedBox(width: 14),
                  ],
                  if (onBookmark != null)
                    _buildAction(
                      context,
                      icon: post.isBookmarkedByMe
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                      label: post.isBookmarkedByMe
                          ? 'Quitar de guardados'
                          : 'Guardar',
                      onTap: onBookmark,
                      isActive: post.isBookmarkedByMe,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}
