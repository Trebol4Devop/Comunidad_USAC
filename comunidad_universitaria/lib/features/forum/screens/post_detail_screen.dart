import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
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
import '../../../core/services/profile_service.dart';
import '../../shared/widgets/auth_modal.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../../shared/widgets/gif_picker_modal.dart';
import '../../shared/widgets/report_dialog.dart';
import '../../shared/widgets/user_avatar_circle.dart';
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

    await ShareCountService.incrementShare(_post.id);

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
          backgroundColor: ZanateColors.zanateBlack,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
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
              'Eliminar Publicación',
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
          '¿Estás seguro de que deseas eliminar esta publicación?',
          style: TextStyle(
            color: ZanateColors.textSecondary(isDark),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancelar',
              style: TextStyle(
                color: ZanateColors.textMuted(isDark),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Eliminar',
              style: TextStyle(fontWeight: FontWeight.w700),
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
    final primaryTextColor = ZanateColors.textPrimary(isDark);
    final secondaryTextColor = ZanateColors.textMuted(isDark);
    final panelColor = ZanateColors.card(isDark);
    final panelSurface = ZanateColors.surface(isDark);
    final panelBorder = ZanateColors.border(isDark);

    return Scaffold(
      backgroundColor: ZanateColors.bg(isDark),
      appBar: AppBar(
        backgroundColor: panelColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          'Publicación',
          style: GoogleFonts.outfit(
            fontSize: 17.5,
            fontWeight: FontWeight.w700,
            color: primaryTextColor,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: panelBorder, height: 1.0),
        ),
        leading: IconButton(
          tooltip: 'Volver',
          icon: PhosphorIcon(
            PhosphorIconsBold.caretLeft,
            color: primaryTextColor,
            size: 22,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: PhosphorIcon(
              _post.isBookmarkedByMe
                  ? PhosphorIconsFill.bookmarkSimple
                  : PhosphorIconsRegular.bookmarkSimple,
              color: _post.isBookmarkedByMe
                  ? ZanateColors.zanateEyeYellow
                  : primaryTextColor,
              size: 20,
            ),
            tooltip: 'Guardar publicación',
            onPressed: _handleBookmark,
          ),
          PopupMenuButton<String>(
            tooltip: 'Más opciones',
            color: panelColor,
            surfaceTintColor: Colors.transparent,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: panelBorder),
            ),
            icon: PhosphorIcon(
              PhosphorIconsRegular.dotsThreeVertical,
              color: primaryTextColor,
              size: 20,
            ),
            onSelected: (value) {
              switch (value) {
                case 'quote':
                  _handleQuotePost();
                  break;
                case 'share':
                  _handleShare();
                  break;
                case 'report':
                  ReportDialog.show(
                    context,
                    title: 'Reportar Publicación',
                    subtitle: 'Publicación de ${_post.authorAlias}',
                    onSubmitted: (reason) {
                      ForumService.reportPost(
                        postId: _post.id,
                        reason: reason,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Gracias por tu reporte. Se ha enviado al equipo de moderación.',
                          ),
                        ),
                      );
                    },
                  );
                  break;
                case 'delete':
                  _handleDeletePost();
                  break;
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'quote',
                child: Row(
                  children: [
                    PhosphorIcon(
                      PhosphorIconsRegular.repeat,
                      size: 18,
                      color: primaryTextColor,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Citar publicación',
                      style: TextStyle(color: primaryTextColor),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    PhosphorIcon(
                      PhosphorIconsRegular.shareNetwork,
                      size: 18,
                      color: primaryTextColor,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Compartir publicación',
                      style: TextStyle(color: primaryTextColor),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    PhosphorIcon(
                      PhosphorIconsRegular.flag,
                      size: 18,
                      color: primaryTextColor,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Reportar post',
                      style: TextStyle(color: primaryTextColor),
                    ),
                  ],
                ),
              ),
              if (_post.isMine)
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      PhosphorIcon(
                        PhosphorIconsRegular.trash,
                        size: 18,
                        color: Colors.red.shade400,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Eliminar publicación',
                        style: TextStyle(color: Colors.red.shade400),
                      ),
                    ],
                  ),
                ),
            ],
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
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: ZanateColors.zanateEyeYellow
                                    .withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  PhosphorIcon(
                                    PhosphorIconsFill.pushPin,
                                    size: 14,
                                    color: isDark
                                        ? ZanateColors.zanateEyeYellow
                                        : ZanateColors.zanateBlack,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Publicación Fijada / Anuncio Oficial',
                                    style: GoogleFonts.outfit(
                                      color: isDark
                                          ? ZanateColors.zanateEyeYellow
                                          : ZanateColors.zanateBlack,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Header: Author & Category
                          Row(
                            children: [
                              UserAvatarCircle(
                                authorAlias: _post.authorAlias,
                                authorHash: _post.authorHash,
                                avatarColorIndex: _post.avatarColorIndex,
                                avatarIconIndex: _post.avatarIconIndex,
                                isMine: _post.isMine,
                                size: 38,
                                iconSize: 18,
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
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w700,
                              fontSize: 20,
                              height: 1.25,
                              letterSpacing: -0.3,
                              color: isDark
                                  ? Colors.white
                                  : ZanateColors.zanateBlack,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Content
                          Text(
                            _post.content,
                            style: TextStyle(
                              fontSize: 14.5,
                              height: 1.55,
                              color: ZanateColors.textSecondary(isDark),
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
                                      PhosphorIcon(
                                        PhosphorIconsRegular.quotes,
                                        size: 16,
                                        color: isDark
                                            ? ZanateColors.zanateEyeYellow
                                            : ZanateColors.zanateBlack,
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
                                      PhosphorIcon(
                                        PhosphorIconsRegular.chartBar,
                                        size: 18,
                                        color: isDark
                                            ? ZanateColors.zanateEyeYellow
                                            : ZanateColors.zanateBlack,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _post.poll!.question,
                                          style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14.5,
                                            color: isDark
                                                ? Colors.white
                                                : ZanateColors.zanateBlack,
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
                                                  ? (isDark
                                                      ? ZanateColors.zanateEyeYellow
                                                      : ZanateColors.zanateBlack)
                                                  : panelBorder,
                                              width: isMyVote ? 1.5 : 1.0,
                                            ),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(9),
                                            child: Stack(
                                              alignment: Alignment.centerLeft,
                                              children: [
                                                if (hasVoted)
                                                  Positioned.fill(
                                                    child: FractionallySizedBox(
                                                      alignment: Alignment.centerLeft,
                                                      widthFactor: percent,
                                                      child: Container(
                                                        color: isMyVote
                                                            ? ZanateColors.zanateEyeYellow
                                                                .withValues(
                                                                  alpha: isDark
                                                                      ? 0.25
                                                                      : 0.34,
                                                                )
                                                            : (isDark
                                                                  ? Colors.white.withValues(alpha: 0.08)
                                                                  : ZanateColors.pillBg),
                                                      ),
                                                    ),
                                                  ),
                                                Center(
                                                  child: Padding(
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
                                                              PhosphorIcon(
                                                                PhosphorIconsFill.checkCircle,
                                                                size: 16,
                                                                color: isDark
                                                                    ? ZanateColors.zanateEyeYellow
                                                                    : ZanateColors.zanateBlack,
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
                                                                ? (isDark
                                                                    ? ZanateColors.zanateEyeYellow
                                                                    : ZanateColors.zanateBlack)
                                                                : secondaryTextColor,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
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
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _post.isLikedByMe
                                        ? ZanateColors.zanateEyeYellow
                                            .withValues(alpha: isDark ? 0.22 : 0.30)
                                        : panelSurface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _post.isLikedByMe
                                          ? (isDark
                                              ? ZanateColors.zanateEyeYellow
                                              : ZanateColors.zanateBlack)
                                          : panelBorder,
                                      width: _post.isLikedByMe ? 1.2 : 1.0,
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
                                            ? (isDark
                                                ? ZanateColors.zanateEyeYellow
                                                : ZanateColors.zanateBlack)
                                            : secondaryTextColor,
                                      ),
                                      const SizedBox(width: 7),
                                      Text(
                                        '${_post.likes} votos útiles',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: _post.isLikedByMe
                                              ? (isDark
                                                  ? ZanateColors.zanateEyeYellow
                                                  : ZanateColors.zanateBlack)
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
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    // Comments Section Header
                    Row(
                      children: [
                        PhosphorIcon(
                          PhosphorIconsRegular.chatsCircle,
                          size: 20,
                          color: isDark
                              ? ZanateColors.zanateEyeYellow
                              : ZanateColors.zanateBlack,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Comentarios y Respuestas',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                            letterSpacing: -0.2,
                            color: primaryTextColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Comments List
                    if (_isLoadingComments)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: isDark
                                ? ZanateColors.zanateEyeYellow
                                : ZanateColors.zanateBlack,
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
                        decoration: BoxDecoration(
                          color: panelColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: panelBorder, width: 0.9),
                        ),
                        child: const EmptyStateWidget(
                          icon: PhosphorIconsRegular.chatCircleDots,
                          title: 'Aún no hay respuestas',
                          description:
                              'Sé el primero en aportar a esta consulta estudiantil.',
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
                          color: ZanateColors.zanateEyeYellow.withValues(
                            alpha: isDark ? 0.16 : 0.24,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: ZanateColors.zanateEyeYellow.withValues(
                              alpha: 0.45,
                            ),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            PhosphorIcon(
                              PhosphorIconsRegular.arrowBendDownRight,
                              size: 15,
                              color: isDark
                                  ? ZanateColors.zanateEyeYellow
                                  : ZanateColors.zanateBlack,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Respondiendo a ${_replyTarget!.authorAlias}: "${_replyTarget!.content}"',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark
                                      ? ZanateColors.zanateEyeYellow
                                      : ZanateColors.zanateBlack,
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
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: PhosphorIcon(
                            PhosphorIconsRegular.gif,
                            size: 22,
                            color: isDark
                                ? ZanateColors.zanateEyeYellow
                                : ZanateColors.zanateBlack,
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
                        const SizedBox(width: 4),
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
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: panelBorder, width: 1.0),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: panelBorder, width: 1.0),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? ZanateColors.zanateEyeYellow
                                      : ZanateColors.zanateBlack,
                                  width: 1.6,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: isDark
                                ? ZanateColors.zanateEyeYellow
                                : ZanateColors.zanateBlack,
                            foregroundColor: isDark
                                ? ZanateColors.zanateBlack
                                : Colors.white,
                            padding: const EdgeInsets.all(10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: _isSendingComment
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: isDark
                                        ? ZanateColors.zanateBlack
                                        : Colors.white,
                                  ),
                                )
                              : const PhosphorIcon(
                                  PhosphorIconsBold.paperPlaneTilt,
                                  size: 18,
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
