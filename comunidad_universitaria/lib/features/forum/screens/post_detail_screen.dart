import 'package:flutter/material.dart';
import '../../../core/constants/categories.dart';
import '../../../core/models/post.dart';
import '../../../core/services/forum_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/time_utils.dart';
import '../widgets/comment_item.dart';
import '../widgets/create_post_dialog.dart';
import '../../shared/widgets/auth_modal.dart';
import '../../shared/widgets/gif_picker_modal.dart';
import '../../shared/widgets/image_viewer_dialog.dart';
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
  String? _commentGifUrl;
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
    if (!SupabaseService.isAuthenticated) {
      AuthModal.show(
        context,
        title: 'Inicia Sesión para Votar',
        subtitle: 'Para valorar publicaciones útiles en el foro, debes iniciar sesión.',
        onAuthenticated: () => _handleLike(),
      );
      return;
    }

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
      setState(() {
        _post = _post.copyWith(isLikedByMe: prevLiked, likes: prevLikes);
      });
    }
  }

  Future<void> _handleBookmark() async {
    if (!SupabaseService.isAuthenticated) {
      AuthModal.show(
        context,
        title: 'Inicia Sesión para Guardar',
        subtitle: 'Para guardar publicaciones en tus marcadores, debes iniciar sesión.',
        onAuthenticated: () => _handleBookmark(),
      );
      return;
    }

    final prevBookmarked = _post.isBookmarkedByMe;
    setState(() {
      _post = _post.copyWith(isBookmarkedByMe: !prevBookmarked);
    });

    final success = await ForumService.toggleBookmark(_post);
    if (mounted) {
      if (success != !prevBookmarked) {
        setState(() {
          _post = _post.copyWith(isBookmarkedByMe: prevBookmarked);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(!prevBookmarked ? 'Publicación guardada en marcadores.' : 'Publicación eliminada de marcadores.'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _handleVotePoll(String pollId, String optionId) async {
    if (!SupabaseService.isAuthenticated) {
      AuthModal.show(
        context,
        title: 'Inicia Sesión para Votar en la Encuesta',
        subtitle: 'Para participar en las encuestas estudiantiles, debes iniciar sesión.',
        onAuthenticated: () => _handleVotePoll(pollId, optionId),
      );
      return;
    }

    if (_post.poll == null) return;
    final oldPoll = _post.poll!;
    final oldMyVote = oldPoll.myVotedOptionId;

    final newOptions = oldPoll.options.map((opt) {
      int newCount = opt.votesCount;
      if (opt.id == optionId && oldMyVote != optionId) {
        newCount += 1;
      } else if (opt.id == oldMyVote && oldMyVote != optionId) {
        newCount = (newCount - 1).clamp(0, 999999);
      }
      return PollOption(
        id: opt.id,
        pollId: opt.pollId,
        optionText: opt.optionText,
        votesCount: newCount,
      );
    }).toList();

    setState(() {
      _post = _post.copyWith(
        poll: oldPoll.copyWith(
          options: newOptions,
          myVotedOptionId: optionId,
        ),
      );
    });

    final ok = await ForumService.votePoll(pollId: pollId, optionId: optionId);
    if (mounted && !ok) {
      _loadComments();
    }
  }

  void _handleQuotePost() {
    if (!SupabaseService.isAuthenticated) {
      AuthModal.show(
        context,
        title: 'Inicia Sesión para Citar',
        subtitle: 'Para citar esta publicación en el foro, debes iniciar sesión.',
        onAuthenticated: () => _handleQuotePost(),
      );
      return;
    }

    CreatePostDialog.show(
      context,
      activeAlias: widget.activeAlias,
      quotedPost: _post,
      onAliasChanged: (_) {},
      onPostCreated: (_) {
        setState(() {
          _post = _post.copyWith(repostsCount: _post.repostsCount + 1);
        });
      },
    );
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
    if (text.isEmpty && _commentGifUrl == null) return;

    if (!SupabaseService.isAuthenticated) {
      AuthModal.show(
        context,
        title: 'Inicia Sesión para Responder',
        subtitle: 'Para participar y responder en este tema, debes iniciar sesión.',
        onAuthenticated: () => _sendComment(),
      );
      return;
    }

    setState(() => _isSendingComment = true);

    try {
      final newComment = await ForumService.addComment(
        postId: _post.id,
        content: text.isNotEmpty ? text : 'GIF adjunto',
        authorAlias: widget.activeAlias,
        parentId: _replyTarget?.id,
        gifUrl: _commentGifUrl,
      );

      if (mounted) {
        setState(() {
          _isSendingComment = false;
          if (newComment != null) {
            _commentController.clear();
            _commentGifUrl = null;
            _replyTarget = null;
            _post = _post.copyWith(commentCount: _post.commentCount + 1);
          }
        });
        _loadComments();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSendingComment = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
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
            icon: Icon(_post.isBookmarkedByMe ? Icons.bookmark : Icons.bookmark_border),
            tooltip: 'Guardar publicación',
            color: _post.isBookmarkedByMe ? const Color(0xFFD97706) : null,
            onPressed: _handleBookmark,
          ),
          IconButton(
            icon: const Icon(Icons.repeat),
            tooltip: 'Citar publicación',
            onPressed: _handleQuotePost,
          ),
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
                          // Pinned badge if applicable
                          if (_post.isPinned) ...[
                            Row(
                              children: [
                                const Icon(Icons.push_pin, size: 14, color: Color(0xFF004B87)),
                                const SizedBox(width: 4),
                                Text(
                                  'Publicación Fijada / Anuncio Oficial',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFF004B87),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                          ],

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

                          // Quoted Post Card if present
                          if (_post.quotedPost != null) ...[
                            const SizedBox(height: 14),
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
                                      Text(
                                        _post.quotedPost!.authorAlias,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        TimeUtils.timeAgo(_post.quotedPost!.createdAt),
                                        style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _post.quotedPost!.title,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    _post.quotedPost!.content,
                                    style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontSize: 12),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Interactive Poll Widget if present
                          if (_post.poll != null) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.6) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.poll_outlined, size: 18, color: Color(0xFF004B87)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _post.poll!.question,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  ..._post.poll!.options.map((opt) {
                                    final total = _post.poll!.totalVotes;
                                    final percent = total > 0 ? (opt.votesCount / total) : 0.0;
                                    final hasVoted = _post.poll!.myVotedOptionId != null;
                                    final isMyVote = _post.poll!.myVotedOptionId == opt.id;

                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: InkWell(
                                        onTap: () => _handleVotePoll(_post.poll!.id, opt.id),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          height: 40,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: isMyVote ? const Color(0xFF004B87) : Colors.grey.shade300,
                                              width: isMyVote ? 1.5 : 1.0,
                                            ),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(7),
                                            child: Stack(
                                              children: [
                                                if (hasVoted)
                                                  FractionallySizedBox(
                                                    widthFactor: percent.clamp(0.0, 1.0),
                                                    child: Container(
                                                      color: isMyVote
                                                          ? const Color(0xFF004B87).withValues(alpha: 0.22)
                                                          : Colors.grey.withValues(alpha: 0.15),
                                                    ),
                                                  ),
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Expanded(
                                                        child: Row(
                                                          children: [
                                                            if (isMyVote) ...[
                                                              const Icon(Icons.check_circle, size: 16, color: Color(0xFF004B87)),
                                                              const SizedBox(width: 8),
                                                            ],
                                                            Flexible(
                                                              child: Text(
                                                                opt.optionText,
                                                                style: TextStyle(
                                                                  fontSize: 13,
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
                                                          '${(percent * 100).toStringAsFixed(0)}% (${opt.votesCount})',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.w600,
                                                            color: isMyVote ? const Color(0xFF004B87) : Colors.grey.shade600,
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
                                    '${_post.poll!.totalVotes} votos registrados en total',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // GIF if present
                          if (_post.gifUrl != null && _post.gifUrl!.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                _post.gifUrl!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (ctx, err, stack) => Container(
                                  height: 140,
                                  color: Colors.grey.shade300,
                                  child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                                ),
                              ),
                            ),
                          ],

                          // Image if present
                          if (_post.imageUrl != null && _post.imageUrl!.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            InkWell(
                              onTap: () => ImageViewerDialog.show(
                                context,
                                imageUrl: _post.imageUrl!,
                                title: _post.title,
                              ),
                              child: Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(
                                      _post.imageUrl!,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        height: 140,
                                        color: Colors.grey.shade300,
                                        child: const Center(
                                          child: Icon(Icons.broken_image, color: Colors.grey),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    margin: const EdgeInsets.all(8),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.65),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(Icons.zoom_in, color: Colors.white, size: 14),
                                        SizedBox(width: 4),
                                        Text('Ampliar', style: TextStyle(color: Colors.white, fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                ],
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
                              const SizedBox(width: 10),
                              // Reposts badge
                              if (_post.repostsCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.repeat, size: 16, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${_post.repostsCount} citas',
                                        style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(width: 10),
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

          // Bottom Reply Input Bar with GIF picker
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

                  if (_commentGifUrl != null) ...[
                    Container(
                      padding: const EdgeInsets.all(6),
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(_commentGifUrl!, height: 60, width: 80, fit: BoxFit.cover),
                          ),
                          const SizedBox(width: 8),
                          const Text('GIF adjunto al comentario', style: TextStyle(fontSize: 12)),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () => setState(() => _commentGifUrl = null),
                          ),
                        ],
                      ),
                    ),
                  ],

                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.gif_box_outlined, color: Color(0xFF004B87)),
                        tooltip: 'Insertar GIF',
                        onPressed: () {
                          GifPickerModal.show(
                            context,
                            onGifSelected: (url) {
                              setState(() => _commentGifUrl = url);
                            },
                          );
                        },
                      ),
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
