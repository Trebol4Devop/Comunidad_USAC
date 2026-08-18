import 'package:flutter/material.dart';
import '../../../core/constants/categories.dart';
import '../../../core/models/post.dart';
import '../../../core/services/forum_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/time_utils.dart';
import '../widgets/comment_item.dart';
import '../../shared/widgets/report_dialog.dart';

class PostDetailScreen extends StatefulWidget {
  final Post initialPost;
  final String activeAlias;

  const PostDetailScreen({
    super.key,
    required this.initialPost,
    required this.activeAlias,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late Post _post;
  List<PostComment> _comments = [];
  bool _isLoadingComments = true;
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();

  PostComment? _replyTarget;
  bool _isSendingComment = false;

  @override
  void initState() {
    super.initState();
    _post = widget.initialPost;
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _isLoadingComments = true);
    final list = await ForumService.fetchCommentsTree(_post.id);
    if (mounted) {
      setState(() {
        _comments = list;
        _isLoadingComments = false;
      });
    }
  }

  Future<void> _handleLike() async {
    final prevLiked = _post.isLikedByMe;
    final prevLikes = _post.likes;

    setState(() {
      _post = _post.copyWith(
        isLikedByMe: !prevLiked,
        likes: prevLiked ? (prevLikes - 1).clamp(0, 999999) : prevLikes + 1,
      );
    });

    final success = await ForumService.toggleLike(_post);
    if (mounted && success != !prevLiked) {
      // Revert if failed
      setState(() {
        _post = _post.copyWith(isLikedByMe: prevLiked, likes: prevLikes);
      });
    }
  }

  void _startReplyTo(PostComment comment) {
    setState(() {
      _replyTarget = comment;
    });
    _commentFocusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyTarget = null;
    });
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSendingComment = true);

    final newComment = await ForumService.addComment(
      postId: _post.id,
      content: text,
      authorAlias: widget.activeAlias,
      parentId: _replyTarget?.id,
    );

    if (mounted) {
      setState(() {
        _isSendingComment = false;
        if (newComment != null) {
          _commentController.clear();
          _replyTarget = null;
          _post = _post.copyWith(commentCount: _post.commentCount + 1);
        }
      });
      // Reload comments tree to include new response
      _loadComments();
    }
  }

  String _getCategoryLabel(String catId) {
    final match = USACConstants.forumCategories.where((c) => c.id == catId);
    return match.isNotEmpty ? match.first.label : 'General';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discusión en el Foro'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            tooltip: 'Reportar post',
            onPressed: () {
              ReportDialog.show(
                context,
                title: 'Reportar Publicación',
                subtitle: 'Publicación de ${_post.authorAlias}',
                onSubmitted: (reason) {
                  if (_post.userId != null) {
                    ForumService.reportUser(
                      reportedUserId: _post.userId!,
                      reportedAlias: _post.authorAlias,
                      reason: reason,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Gracias por tu reporte. Se ha enviado al equipo de moderación.')),
                    );
                  }
                },
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: MaxWidthContainer(
                maxWidth: 900,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Post Card Box
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: theme.cardTheme.color ?? (isDark ? const Color(0xFF1C2541) : Colors.white),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header: Author & Category
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                                child: Icon(Icons.person, size: 18, color: theme.colorScheme.primary),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _post.authorAlias,
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      TimeUtils.timeAgo(_post.createdAt),
                                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _getCategoryLabel(_post.category),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Title
                          Text(
                            _post.title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 19,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Content
                          Text(
                            _post.content,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),

                          // Image if present
                          if (_post.imageUrl != null && _post.imageUrl!.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                _post.imageUrl!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                              ),
                            ),
                          ],

                          const SizedBox(height: 16),
                          const Divider(),

                          // Actions
                          Row(
                            children: [
                              InkWell(
                                onTap: _handleLike,
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: _post.isLikedByMe
                                        ? theme.colorScheme.primary.withValues(alpha: 0.12)
                                        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _post.isLikedByMe ? Icons.thumb_up : Icons.thumb_up_alt_outlined,
                                        size: 16,
                                        color: _post.isLikedByMe
                                            ? theme.colorScheme.primary
                                            : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${_post.likes} votos útiles',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: _post.isLikedByMe
                                              ? theme.colorScheme.primary
                                              : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '${_comments.length} comentarios',
                                style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Comments Section Header
                    Row(
                      children: [
                        const Icon(Icons.forum_outlined, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Comentarios y Respuestas',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Comments List
                    if (_isLoadingComments)
                      const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
                    else if (_comments.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 32, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            Text(
                              'Aún no hay respuestas',
                              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Sé el primero en aportar a esta consulta estudiantil.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _comments.length,
                        itemBuilder: (ctx, i) {
                          return CommentItemWidget(
                            comment: _comments[i],
                            postAuthorUserId: _post.userId ?? '',
                            onReply: _startReplyTo,
                            onReport: (comment, reason) {
                              if (comment.userId != null) {
                                ForumService.reportUser(
                                  reportedUserId: comment.userId!,
                                  reportedAlias: comment.authorAlias,
                                  reason: reason,
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Reporte enviado a moderación.')),
                                );
                              }
                            },
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Reply Input Bar
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF151E34) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: MaxWidthContainer(
              maxWidth: 900,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_replyTarget != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.reply, size: 14, color: theme.colorScheme.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Respondiendo a ${_replyTarget!.authorAlias}: "${_replyTarget!.content}"',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 14),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: _cancelReply,
                          ),
                        ],
                      ),
                    ),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          focusNode: _commentFocusNode,
                          minLines: 1,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: _replyTarget != null
                                ? 'Escribe tu respuesta a ${_replyTarget!.authorAlias}...'
                                : 'Escribe tu respuesta pública en el foro...',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        icon: _isSendingComment
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.send, size: 18),
                        onPressed: _isSendingComment ? null : _sendComment,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
