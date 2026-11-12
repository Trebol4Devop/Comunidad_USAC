import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/constants/categories.dart';
import '../../../core/constants/zanate_colors.dart';
import '../../../core/models/post.dart';
import '../../../core/services/forum_service.dart';
import '../../../core/services/share_count_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/time_utils.dart';
import '../widgets/comment_item.dart';
import '../widgets/create_post_dialog.dart';
import '../../legal/widgets/terms_consent_modal.dart';
import '../../shared/widgets/alias_dice_button.dart';
import '../../../core/services/profile_service.dart';
import '../../shared/widgets/auth_modal.dart';
import '../../shared/widgets/gif_picker_modal.dart';
import '../../shared/widgets/report_dialog.dart';
import '../widgets/discord/discord_media_attachment.dart';

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
  late String _commentAlias;
  List<PostComment> _comments = [];
  bool _isLoadingComments = true;
  bool _commentsLoadError = false;
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();

  PostComment? _replyTarget;
  String? _commentGifUrl;
  bool _isSendingComment = false;

  @override
  void initState() {
    super.initState();
    _post = widget.initialPost;
    _commentAlias = widget.activeAlias;
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() {
      _isLoadingComments = true;
      _commentsLoadError = false;
    });
    try {
      final list = await ForumService.fetchCommentsTree(_post.id);
      if (mounted) {
        setState(() {
          _comments = list;
          _isLoadingComments = false;
          _commentsLoadError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingComments = false;
          _commentsLoadError = true;
        });
      }
    }
  }

  Future<void> _handleLike() async {
    if (SupabaseConfig.isConfigured && !SupabaseService.isAuthenticated) {
      AuthModal.show(
        context,
        title: 'Inicia Sesión para Votar',
        subtitle:
            'Para valorar publicaciones útiles en el foro, debes iniciar sesión.',
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

    try {
      final success = await ForumService.toggleLike(
        _post.copyWith(isLikedByMe: prevLiked),
      );
      if (mounted && success != !prevLiked) {
        setState(() {
          _post = _post.copyWith(isLikedByMe: prevLiked, likes: prevLikes);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo registrar el me gusta. Inténtalo de nuevo.',
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _post = _post.copyWith(isLikedByMe: prevLiked, likes: prevLikes);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo registrar el me gusta. Inténtalo de nuevo.',
          ),
        ),
      );
    }
  }

  Future<void> _handleShare() async {
    final newCount = _post.sharesCount + 1;
    setState(() {
      _post = _post.copyWith(sharesCount: newCount);
    });

    await ShareCountService.incrementShare(_post.id, table: 'posts');

    final shareText =
        '${_post.title}\n\n${_post.content}\n\n— ${_post.authorAlias} (Comunidad USAC)';
    try {
      await SharePlus.instance.share(
        ShareParams(text: shareText, subject: _post.title),
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: shareText));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Publicación compartida ($newCount veces). El texto se copió.'),
          backgroundColor: ZanateColors.zanateAccent,
        ),
      );
      return;
    }
  }

  Future<void> _handleBookmark() async {
    if (SupabaseConfig.isConfigured && !SupabaseService.isAuthenticated) {
      AuthModal.show(
        context,
        title: 'Inicia Sesión para Guardar',
        subtitle:
            'Para guardar publicaciones en tus marcadores, debes iniciar sesión.',
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
            content: Text(
              !prevBookmarked
                  ? 'Publicación guardada en marcadores.'
                  : 'Publicación eliminada de marcadores.',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _handleVotePoll(String pollId, String optionId) async {
    if (SupabaseConfig.isConfigured && !SupabaseService.isAuthenticated) {
      AuthModal.show(
        context,
        title: 'Inicia Sesión para Votar en la Encuesta',
        subtitle:
            'Para participar en las encuestas estudiantiles, debes iniciar sesión.',
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
        poll: oldPoll.copyWith(options: newOptions, myVotedOptionId: optionId),
      );
    });

    final ok = await ForumService.votePoll(pollId: pollId, optionId: optionId);
    if (mounted && !ok) {
      _loadComments();
    }
  }

  void _handleQuotePost() {
    if (SupabaseConfig.isConfigured && !SupabaseService.isAuthenticated) {
      AuthModal.show(
        context,
        title: 'Inicia Sesión para Citar',
        subtitle:
            'Para citar esta publicación en el foro, debes iniciar sesión.',
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

  Future<void> _handleDeletePost() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Publicación'),
        content: const Text(
          '¿Estás seguro de que deseas eliminar esta publicación?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final ok = await ForumService.softDeletePost(_post.id);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Publicación eliminada')));
      Navigator.of(context).pop(true);
    } else {
      final msg = _post.isLegalHold
          ? 'No se puede eliminar: contenido bajo retención legal.'
          : 'No se pudo eliminar la publicación.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _handleDeleteComment(PostComment comment) async {
    final ok = await ForumService.softDeleteComment(comment.id);
    if (!mounted) return;
    if (ok) {
      await _loadComments();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Comentario eliminado')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo eliminar el comentario.'),
        ),
      );
    }
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty && _commentGifUrl == null) return;

    if (SupabaseConfig.isConfigured) {
      if (!SupabaseService.isAuthenticated) {
        AuthModal.show(
          context,
          title: 'Inicia Sesión para Responder',
          subtitle:
              'Para participar y responder en este tema, debes iniciar sesión.',
          onAuthenticated: () => _sendComment(),
        );
        return;
      }

      final hasAccepted = await ProfileService.hasAcceptedTerms();
      if (!hasAccepted) {
        if (!mounted) return;
        final accepted = await TermsConsentModal.show(context);
        if (!accepted) return;
      }
    }

    setState(() => _isSendingComment = true);

    try {
      final newComment = await ForumService.addComment(
        postId: _post.id,
        content: text.isNotEmpty ? text : 'GIF adjunto',
        authorAlias: _commentAlias,
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
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
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
    final primaryTextColor = isDark ? Colors.white : ZanateColors.zanateDark;
    final secondaryTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final panelColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final panelSurface = isDark
        ? const Color(0xFF0F172A)
        : ZanateColors.surfaceBg;
    final panelBorder = isDark
        ? const Color(0xFF334155)
        : ZanateColors.subtleBorder;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : ZanateColors.surfaceBg,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: panelBorder, height: 0.8),
        ),
        title: Text(
          'Consulta en el Foro',
          style: TextStyle(
            color: primaryTextColor,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: PhosphorIcon(
            PhosphorIconsRegular.arrowLeft,
            color: primaryTextColor,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_post.isMine)
            IconButton(
              icon: PhosphorIcon(
                PhosphorIconsRegular.trash,
                color: Colors.red.shade400,
                size: 20,
              ),
              tooltip: 'Eliminar publicación',
              onPressed: _handleDeletePost,
            ),
          IconButton(
            icon: PhosphorIcon(
              _post.isBookmarkedByMe
                  ? PhosphorIconsFill.bookmarkSimple
                  : PhosphorIconsRegular.bookmarkSimple,
              color: _post.isBookmarkedByMe ? const Color(0xFFF59E0B) : primaryTextColor,
              size: 20,
            ),
            tooltip: 'Guardar publicación',
            onPressed: _handleBookmark,
          ),
          IconButton(
            icon: PhosphorIcon(
              PhosphorIconsRegular.repeat,
              color: primaryTextColor,
              size: 20,
            ),
            tooltip: 'Citar publicación',
            onPressed: _handleQuotePost,
          ),
          IconButton(
            icon: PhosphorIcon(
              PhosphorIconsRegular.shareNetwork,
              color: primaryTextColor,
              size: 20,
            ),
            tooltip: 'Compartir publicación',
            onPressed: _handleShare,
          ),
          IconButton(
            icon: PhosphorIcon(
              PhosphorIconsRegular.flag,
              color: primaryTextColor,
              size: 20,
            ),
            tooltip: 'Reportar post',
            onPressed: () {
              ReportDialog.show(
                context,
                title: 'Reportar Publicación',
                subtitle: 'Publicación de ${_post.authorAlias}',
                onSubmitted: (reason) {
                  ForumService.reportPost(postId: _post.id, reason: reason);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Gracias por tu reporte. Se ha enviado al equipo de moderación.',
                      ),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: MaxWidthContainer(
                maxWidth: 900,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Post Card Box (Reddit/X Modern Card)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: panelColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: panelBorder, width: 0.9),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Pinned badge if applicable
                          if (_post.isPinned) ...[
                            Row(
                              children: [
                                const PhosphorIcon(
                                  PhosphorIconsFill.pushPin,
                                  size: 15,
                                  color: ZanateColors.zanateAccent,
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'Publicación Fijada / Anuncio Oficial',
                                  style: TextStyle(
                                    color: ZanateColors.zanateAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Header: Author & Category
                          Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: ZanateColors.zanateAccent.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: PhosphorIcon(
                                    PhosphorIconsBold.user,
                                    size: 18,
                                    color: ZanateColors.zanateAccent,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _post.authorAlias,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: primaryTextColor,
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      TimeUtils.timeAgo(_post.createdAt),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: secondaryTextColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: panelSurface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: panelBorder, width: 0.8),
                                ),
                                child: Text(
                                  _getCategoryLabel(_post.category),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Title
                          Text(
                            _post.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 19,
                              height: 1.3,
                              letterSpacing: -0.3,
                              color: primaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Content
                          Text(
                            _post.content,
                            style: TextStyle(
                              fontSize: 14.5,
                              height: 1.55,
                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                            ),
                          ),

                          // Quoted Post Card if present
                          if (_post.quotedPost != null) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: panelSurface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: panelBorder),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const PhosphorIcon(
                                        PhosphorIconsRegular.quotes,
                                        size: 16,
                                        color: ZanateColors.zanateAccent,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          _post.quotedPost!.authorAlias,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        TimeUtils.timeAgo(
                                          _post.quotedPost!.createdAt,
                                        ),
                                        style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _post.quotedPost!.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    _post.quotedPost!.content,
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.grey.shade400
                                          : Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
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
                                color: panelSurface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: panelBorder),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const PhosphorIcon(
                                        PhosphorIconsRegular.chartBar,
                                        size: 18,
                                        color: ZanateColors.zanateAccent,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _post.poll!.question,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: primaryTextColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  ..._post.poll!.options.map((opt) {
                                    final total = _post.poll!.totalVotes;
                                    final rawPercent = (total > 0)
                                        ? (opt.votesCount / total)
                                        : 0.0;
                                    final percent =
                                        (rawPercent.isNaN ||
                                            rawPercent.isInfinite)
                                        ? 0.0
                                        : rawPercent.clamp(0.0, 1.0);
                                    final hasVoted =
                                        _post.poll!.myVotedOptionId != null;
                                    final isMyVote =
                                        _post.poll!.myVotedOptionId == opt.id;

                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: InkWell(
                                        onTap: () => _handleVotePoll(
                                          _post.poll!.id,
                                          opt.id,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                        child: Container(
                                          height: 40,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: isMyVote
                                                  ? ZanateColors.zanateAccent
                                                  : panelBorder,
                                              width: isMyVote ? 1.5 : 1.0,
                                            ),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(9),
                                            child: Stack(
                                              children: [
                                                if (hasVoted)
                                                  FractionallySizedBox(
                                                    widthFactor: percent,
                                                    child: Container(
                                                      color: isMyVote
                                                          ? ZanateColors.zanateAccent.withValues(alpha: 0.15)
                                                          : (isDark
                                                                ? Colors.white.withValues(alpha: 0.08)
                                                                : Colors.grey.withValues(alpha: 0.12)),
                                                    ),
                                                  ),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                      ),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Expanded(
                                                        child: Row(
                                                          children: [
                                                            if (isMyVote) ...[
                                                              const PhosphorIcon(
                                                                PhosphorIconsFill.checkCircle,
                                                                size: 16,
                                                                color: ZanateColors.zanateAccent,
                                                              ),
                                                              const SizedBox(
                                                                width: 8,
                                                              ),
                                                            ],
                                                            Flexible(
                                                              child: Text(
                                                                opt.optionText,
                                                                style: TextStyle(
                                                                  fontSize: 13,
                                                                  fontWeight:
                                                                      isMyVote
                                                                      ? FontWeight.w700
                                                                      : FontWeight.w500,
                                                                  color: primaryTextColor,
                                                                ),
                                                                overflow:
                                                                    TextOverflow.ellipsis,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      if (hasVoted)
                                                        Text(
                                                          '${(percent * 100).toStringAsFixed(0)}% · ${opt.votesCount} votos',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: isMyVote
                                                                ? ZanateColors.zanateAccent
                                                                : secondaryTextColor,
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
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: secondaryTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // GIF if present
                          if (_post.gifUrl != null &&
                              _post.gifUrl!.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            DiscordMediaAttachment(
                              imageUrl: _post.gifUrl!,
                              title: _post.title,
                              isGif: true,
                              maxHeight: 340,
                              maxWidth: 580,
                            ),
                          ],

                          // Image if present
                          if (_post.imageUrl != null &&
                              _post.imageUrl!.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            DiscordMediaAttachment(
                              imageUrl: _post.imageUrl!,
                              title: _post.title,
                              isGif: false,
                              maxHeight: 420,
                              maxWidth: 620,
                            ),
                          ],

                          const SizedBox(height: 18),
                          Divider(color: panelBorder, height: 1),
                          const SizedBox(height: 14),

                          // Actions (X/Reddit style stats & like pill)
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              InkWell(
                                onTap: _handleLike,
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _post.isLikedByMe
                                        ? ZanateColors.zanateAccent.withValues(alpha: 0.12)
                                        : panelSurface,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: _post.isLikedByMe
                                          ? ZanateColors.zanateAccent.withValues(alpha: 0.3)
                                          : panelBorder,
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      PhosphorIcon(
                                        _post.isLikedByMe
                                            ? PhosphorIconsFill.thumbsUp
                                            : PhosphorIconsRegular.thumbsUp,
                                        size: 17,
                                        color: _post.isLikedByMe
                                            ? ZanateColors.zanateAccent
                                            : secondaryTextColor,
                                      ),
                                      const SizedBox(width: 7),
                                      Text(
                                        '${_post.likes} votos útiles',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: _post.isLikedByMe
                                              ? ZanateColors.zanateAccent
                                              : primaryTextColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Reposts badge
                              if (_post.repostsCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: panelSurface,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: panelBorder, width: 0.8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      PhosphorIcon(
                                        PhosphorIconsRegular.repeat,
                                        size: 16,
                                        color: secondaryTextColor,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        '${_post.repostsCount} citas',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: primaryTextColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: panelSurface,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: panelBorder, width: 0.8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    PhosphorIcon(
                                      PhosphorIconsRegular.chatCircle,
                                      size: 16,
                                      color: secondaryTextColor,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      '${_comments.length} comentarios',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: primaryTextColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Share action badge
                              InkWell(
                                onTap: _handleShare,
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: panelSurface,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: panelBorder, width: 0.8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      PhosphorIcon(
                                        PhosphorIconsRegular.shareNetwork,
                                        size: 16,
                                        color: secondaryTextColor,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        _post.sharesCount > 0
                                            ? '${_post.sharesCount} compartidos'
                                            : 'Compartir',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: primaryTextColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    // Comments Section Header
                    Row(
                      children: [
                        const PhosphorIcon(
                          PhosphorIconsRegular.chatsCircle,
                          size: 20,
                          color: ZanateColors.zanateAccent,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Comentarios y Respuestas',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            letterSpacing: -0.2,
                            color: primaryTextColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Comments List
                    if (_isLoadingComments)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(28),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: ZanateColors.zanateAccent,
                          ),
                        ),
                      )
                    else if (_commentsLoadError)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: panelColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: panelBorder),
                        ),
                        child: Column(
                          children: [
                            Icon(PhosphorIconsRegular.warningCircle, size: 32, color: Colors.amber.shade700),
                            const SizedBox(height: 8),
                            Text(
                              'No se pudieron cargar los comentarios.',
                              style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: primaryTextColor,
                                side: BorderSide(color: panelBorder),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: _loadComments,
                              icon: const PhosphorIcon(PhosphorIconsRegular.arrowsClockwise, size: 16),
                              label: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      )
                    else if (_comments.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: panelColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: panelBorder, width: 0.9),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: ZanateColors.zanateAccent.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: PhosphorIcon(
                                  PhosphorIconsRegular.chatCircleDots,
                                  size: 26,
                                  color: ZanateColors.zanateAccent,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Aún no hay respuestas',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: primaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Sé el primero en aportar a esta consulta estudiantil.',
                              style: TextStyle(
                                fontSize: 13,
                                color: secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Column(
                        children: _comments.map((c) {
                          return CommentItemWidget(
                            key: ValueKey(c.id),
                            comment: c,
                            postAuthorUserId: _post.userId ?? '',
                            onReply: _startReplyTo,
                            onDelete: _handleDeleteComment,
                            onReport: (comment, reason) {
                              ForumService.reportComment(
                                commentId: comment.id,
                                reason: reason,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Reporte enviado a moderación.',
                                  ),
                                ),
                              );
                            },
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Reply Input Bar (X/Threads Style Composer)
          Container(
            decoration: BoxDecoration(
              color: panelColor,
              border: Border(
                top: BorderSide(color: panelBorder, width: 0.9),
              ),
            ),
            child: SafeArea(
              top: false,
              child: MaxWidthContainer(
                maxWidth: 900,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_replyTarget != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: ZanateColors.zanateAccent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: ZanateColors.zanateAccent.withValues(alpha: 0.25),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          children: [
                            const PhosphorIcon(
                              PhosphorIconsRegular.arrowBendDownRight,
                              size: 15,
                              color: ZanateColors.zanateAccent,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Respondiendo a ${_replyTarget!.authorAlias}: "${_replyTarget!.content}"',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: ZanateColors.zanateAccent,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const PhosphorIcon(PhosphorIconsRegular.x, size: 14),
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
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: panelSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: panelBorder),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                _commentGifUrl!,
                                height: 60,
                                width: 80,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'GIF adjunto al comentario',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: primaryTextColor,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const PhosphorIcon(PhosphorIconsRegular.x, size: 16),
                              onPressed: () =>
                                  setState(() => _commentGifUrl = null),
                            ),
                          ],
                        ),
                      ),
                    ],

                    Row(
                      children: [
                        AliasDiceButton(
                          alias: _commentAlias,
                          onAliasChanged: (newAlias) =>
                              setState(() => _commentAlias = newAlias),
                          compact: true,
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: PhosphorIcon(
                            PhosphorIconsRegular.gif,
                            size: 20,
                            color: ZanateColors.zanateAccent,
                          ),
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
                            onChanged: (_) => setState(() {}),
                            minLines: 1,
                            maxLines: 4,
                            style: TextStyle(
                              fontSize: 14,
                              color: primaryTextColor,
                            ),
                            decoration: InputDecoration(
                              hintText: _replyTarget != null
                                  ? 'Escribe tu respuesta a ${_replyTarget!.authorAlias}...'
                                  : 'Escribe tu comentario en el foro...',
                              hintStyle: TextStyle(
                                fontSize: 13,
                                color: secondaryTextColor,
                              ),
                              filled: true,
                              fillColor: panelSurface,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide: BorderSide(color: panelBorder, width: 0.8),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide: BorderSide(color: panelBorder, width: 0.8),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide: const BorderSide(
                                  color: ZanateColors.zanateAccent,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: ZanateColors.zanateDark,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: _isSendingComment
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const PhosphorIcon(
                                  PhosphorIconsBold.paperPlaneTilt,
                                  size: 18,
                                  color: Colors.white,
                                ),
                          onPressed:
                              _isSendingComment ||
                                  (_commentController.text.trim().isEmpty &&
                                      _commentGifUrl == null)
                              ? null
                              : _sendComment,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
