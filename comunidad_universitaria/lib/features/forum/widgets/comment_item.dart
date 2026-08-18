import 'package:flutter/material.dart';
import '../../../core/models/post.dart';
import '../../../core/utils/time_utils.dart';
import '../../shared/widgets/report_dialog.dart';

class CommentItemWidget extends StatelessWidget {
  final PostComment comment;
  final String postAuthorUserId;
  final int depth;
  final Function(PostComment targetComment) onReply;
  final Function(PostComment targetComment, String reason)? onReport;

  const CommentItemWidget({
    super.key,
    required this.comment,
    required this.postAuthorUserId,
    this.depth = 0,
    required this.onReply,
    this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isPostAuthor = comment.userId != null && comment.userId == postAuthorUserId;

    // Cap visual indentation depth to 4 levels so it looks clean on mobile
    final visualDepth = depth.clamp(0, 4);

    return Padding(
      padding: EdgeInsets.only(
        left: visualDepth > 0 ? (visualDepth * 14.0) : 0.0,
        top: 6,
        bottom: 6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: depth == 0
                  ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC))
                  : (isDark ? const Color(0xFF162032) : const Color(0xFFF1F5F9)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: depth == 0
                    ? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))
                    : (isDark ? const Color(0xFF243044) : const Color(0xFFE2E8F0).withValues(alpha: 0.5)),
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Author alias, author badge, time ago, reply button
                Row(
                  children: [
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                      child: Icon(Icons.person, size: 12, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        comment.authorAlias,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (isPostAuthor) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'AUTOR',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 6),
                    Text(
                      '• ${TimeUtils.timeAgo(comment.createdAt)}',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () => onReply(comment),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Row(
                          children: [
                            Icon(Icons.reply, size: 14, color: theme.colorScheme.primary),
                            const SizedBox(width: 3),
                            Text(
                              'Responder',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (onReport != null)
                      IconButton(
                        icon: Icon(Icons.flag_outlined, size: 14, color: Colors.grey.shade500),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Reportar comentario',
                        onPressed: () {
                          ReportDialog.show(
                            context,
                            title: 'Reportar Comentario',
                            subtitle: 'Comentario de ${comment.authorAlias}',
                            onSubmitted: (reason) => onReport!(comment, reason),
                          );
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                // Comment text
                Text(
                  comment.content,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),

          // Render Nested Child Comments Recursively (limit max depth to 6 to prevent stack/memory runaway)
          if (depth < 6 && comment.children.isNotEmpty)
            ...comment.children.map(
              (child) => CommentItemWidget(
                comment: child,
                postAuthorUserId: postAuthorUserId,
                depth: depth + 1,
                onReply: onReply,
                onReport: onReport,
              ),
            ),
        ],
      ),
    );
  }
}
