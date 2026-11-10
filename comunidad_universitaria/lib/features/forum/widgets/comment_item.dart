import 'package:flutter/material.dart';
import '../../../core/models/post.dart';
import '../../shared/widgets/anonymous_author_header.dart';
import '../../shared/widgets/report_dialog.dart';
import 'discord/discord_media_attachment.dart';

class CommentItemWidget extends StatelessWidget {
  final PostComment comment;
  final String postAuthorUserId;
  final int depth;
  final Function(PostComment targetComment) onReply;
  final Function(PostComment targetComment, String reason)? onReport;
  final Function(PostComment targetComment)? onDelete;

  const CommentItemWidget({
    super.key,
    required this.comment,
    required this.postAuthorUserId,
    this.depth = 0,
    required this.onReply,
    this.onReport,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
                  : (isDark
                        ? const Color(0xFF162032)
                        : const Color(0xFFF1F5F9)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: depth == 0
                    ? (isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0))
                    : (isDark
                          ? const Color(0xFF243044)
                          : const Color(0xFFE2E8F0).withValues(alpha: 0.5)),
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header determinista anónimo
                AnonymousAuthorHeader(
                  authorAlias: comment.authorAlias,
                  authorHash: comment.authorHash,
                  isOp: comment.isOp,
                  isMine: comment.isMine,
                  createdAt: comment.createdAt,
                  compact: true,
                  onDelete: onDelete != null ? () => onDelete!(comment) : null,
                  onReport: onReport != null
                      ? () {
                          ReportDialog.show(
                            context,
                            title: 'Reportar Comentario',
                            subtitle: 'Comentario de ${comment.authorAlias}',
                            onSubmitted: (reason) => onReport!(comment, reason),
                          );
                        }
                      : null,
                  trailing: InkWell(
                    onTap: () => onReply(comment),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      constraints: const BoxConstraints(
                        minHeight: 48,
                        minWidth: 48,
                      ),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.reply,
                            size: 14,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
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

                // GIF in comment if present
                if (comment.gifUrl != null && comment.gifUrl!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  DiscordMediaAttachment(
                    imageUrl: comment.gifUrl!,
                    isGif: true,
                    maxHeight: 180,
                    maxWidth: 320,
                  ),
                ],
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
                onDelete: onDelete,
              ),
            ),
        ],
      ),
    );
  }
}
