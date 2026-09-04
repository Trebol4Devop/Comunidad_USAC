import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/models/post.dart';
import '../../../../core/utils/time_utils.dart';
import '../../../shared/widgets/image_viewer_dialog.dart';
import '../../../shared/widgets/report_dialog.dart';

class DiggPostCard extends StatefulWidget {
  final Post post;
  final VoidCallback onTap;
  final VoidCallback onLike;
  final VoidCallback? onBookmark;
  final VoidCallback? onRepost;
  final Function(String pollId, String optionId)? onVotePoll;
  final Function(String reason)? onReport;

  const DiggPostCard({
    super.key,
    required this.post,
    required this.onTap,
    required this.onLike,
    this.onBookmark,
    this.onRepost,
    this.onVotePoll,
    this.onReport,
  });

  @override
  State<DiggPostCard> createState() => _DiggPostCardState();
}

class _DiggPostCardState extends State<DiggPostCard> {
  bool _isDownvoted = false;

  String _extractDomain(Post post) {
    // If URL in content or image, extract domain name
    final urlRegex = RegExp(r'https?://(?:www\.)?([a-zA-Z0-9.-]+\.[a-zA-Z]{2,})');
    final contentMatch = urlRegex.firstMatch(post.content);
    if (contentMatch != null) {
      return contentMatch.group(1)!;
    }
    if (post.imageUrl != null) {
      final imgMatch = urlRegex.firstMatch(post.imageUrl!);
      if (imgMatch != null) {
        final d = imgMatch.group(1)!;
        if (!d.contains('supabase') && !d.contains('github')) {
          return d;
        }
      }
    }
    // Default thematic domains
    if (post.category == 'general') return 'comunidad.usac.gt';
    if (post.category == 'tutorias') return 'tutorias.usac.edu';
    if (post.category == 'anuncios') return 'noticias.usac.gt';
    if (post.carrera.isNotEmpty) return '${post.carrera.toLowerCase()}.usac.gt';
    return 'thegamepost.com';
  }

  void _handleDownvote() {
    setState(() {
      _isDownvoted = !_isDownvoted;
    });
    // Haptic feedback
    HapticFeedback.lightImpact();
  }

  void _handleShare(BuildContext context) {
    Clipboard.setData(ClipboardData(text: '${widget.post.title}\nhttps://comunidad.usac.edu.gt/p/${widget.post.id}'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Enlace copiado al portapapeles.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF27272A) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF3F3F46) : const Color(0xFFE2E8F0);
    final domain = _extractDomain(widget.post);
    final hasImage = widget.post.imageUrl != null && widget.post.imageUrl!.isNotEmpty;

    final displayLikes = widget.post.likes - (_isDownvoted ? 1 : 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16), // Concentric outer radius
        border: Border.all(color: cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Post Header: Subreddit / Category • Time ago • Domain
                Row(
                  children: [
                    // Subreddit / Category badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(6), // Concentric
                      ),
                      child: Text(
                        '/${widget.post.category.isNotEmpty ? widget.post.category : "general"}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '•',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF71717A) : const Color(0xFFA1A1AA),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      TimeUtils.timeAgo(widget.post.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '•',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF71717A) : const Color(0xFFA1A1AA),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        widget.post.authorAlias,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark ? const Color(0xFFD4D4D8) : const Color(0xFF52525B),
                        ),
                      ),
                    ),
                    if (widget.post.isPinned) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.push_pin_rounded, size: 14, color: Color(0xFF004B87)),
                    ],
                  ],
                ),
                const SizedBox(height: 10),

                // 2. Body (Headline + summary snippet) and Right-side Thumbnail
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Text Column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Headline
                          Text(
                            widget.post.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Summary fragment / introductory snippet
                          Text(
                            widget.post.content,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF52525B),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Right-side Thumbnail with Overlaid Source Tag
                    if (hasImage) ...[
                      const SizedBox(width: 14),
                      _buildRightThumbnail(widget.post.imageUrl!, domain, isDark),
                    ],
                  ],
                ),

                // Quoted Post if present
                if (widget.post.quotedPost != null) ...[
                  const SizedBox(height: 12),
                  _buildQuotedPost(widget.post.quotedPost!, isDark),
                ],

                // Interactive Poll if present
                if (widget.post.poll != null) ...[
                  const SizedBox(height: 12),
                  _buildPollWidget(widget.post.poll!, isDark),
                ],

                const SizedBox(height: 14),

                // 3. Bottom Social Interactions Bar (Upvote/Downvote, Comments, Share, ...)
                Row(
                  children: [
                    // Upvote / Downvote Net Pill
                    _buildVotingPill(displayLikes, isDark, theme),

                    const SizedBox(width: 10),

                    // Comments Button
                    _ScalePressButton(
                      onTap: widget.onTap,
                      child: Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFF4F4F5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 15,
                              color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF52525B),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${widget.post.commentCount}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFFD4D4D8) : const Color(0xFF3F3F46),
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    // Share Button
                    _ScalePressButton(
                      onTap: () => _handleShare(context),
                      child: Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFF4F4F5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.share_outlined,
                              size: 15,
                              color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF52525B),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Compartir',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isDark ? const Color(0xFFD4D4D8) : const Color(0xFF52525B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Context Menu (...)
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_horiz_rounded,
                        size: 20,
                        color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onSelected: (val) {
                        if (val == 'bookmark' && widget.onBookmark != null) {
                          widget.onBookmark!();
                        } else if (val == 'repost' && widget.onRepost != null) {
                          widget.onRepost!();
                        } else if (val == 'report' && widget.onReport != null) {
                          ReportDialog.show(
                            context,
                            title: 'Reportar Publicación',
                            subtitle: 'Publicación de ${widget.post.authorAlias}',
                            onSubmitted: widget.onReport!,
                          );
                        }
                      },
                      itemBuilder: (ctx) => [
                        PopupMenuItem(
                          value: 'bookmark',
                          child: Row(
                            children: [
                              Icon(
                                widget.post.isBookmarkedByMe ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                                size: 16,
                                color: widget.post.isBookmarkedByMe ? const Color(0xFFD97706) : null,
                              ),
                              const SizedBox(width: 8),
                              Text(widget.post.isBookmarkedByMe ? 'Eliminar de marcadores' : 'Guardar en marcadores'),
                            ],
                          ),
                        ),
                        if (widget.onRepost != null)
                          const PopupMenuItem(
                            value: 'repost',
                            child: Row(
                              children: [
                                Icon(Icons.repeat_rounded, size: 16),
                                SizedBox(width: 8),
                                Text('Citar publicación'),
                              ],
                            ),
                          ),
                        const PopupMenuItem(
                          value: 'report',
                          child: Row(
                            children: [
                              Icon(Icons.flag_outlined, size: 16, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Reportar contenido', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
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

  Widget _buildRightThumbnail(String imageUrl, String domain, bool isDark) {
    return _ScalePressButton(
      onTap: () => ImageViewerDialog.show(
        context,
        imageUrl: imageUrl,
        title: widget.post.title,
      ),
      child: Stack(
        children: [
          // Thumbnail with concentric radius (10px inside 16px card) and 1px outline
          Container(
            width: 112,
            height: 84,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0x1AFFFFFF) : const Color(0x14000000),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFF4F4F5),
                  child: const Center(
                    child: Icon(Icons.broken_image_rounded, size: 24, color: Colors.grey),
                  ),
                ),
              ),
            ),
          ),

          // Source Tag Overlaid in bottom right
          Positioned(
            right: 4,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      domain,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.north_east_rounded, size: 9, color: Colors.white70),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVotingPill(int displayLikes, bool isDark, ThemeData theme) {
    final isLiked = widget.post.isLikedByMe;

    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: isLiked
            ? const Color(0xFF004B87).withValues(alpha: 0.12)
            : (_isDownvoted
                ? Colors.red.withValues(alpha: 0.1)
                : (isDark ? const Color(0xFF3F3F46) : const Color(0xFFF4F4F5))),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Upvote
          _ScalePressButton(
            onTap: widget.onLike,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Icon(
                isLiked ? Icons.arrow_upward_rounded : Icons.arrow_upward_outlined,
                size: 16,
                color: isLiked
                    ? const Color(0xFF004B87)
                    : (isDark ? const Color(0xFFA1A1AA) : const Color(0xFF52525B)),
              ),
            ),
          ),

          // Net Vote Count with tabular figures
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              '$displayLikes',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isLiked
                    ? const Color(0xFF004B87)
                    : (_isDownvoted
                        ? Colors.red
                        : (isDark ? const Color(0xFFD4D4D8) : const Color(0xFF3F3F46))),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),

          // Downvote
          _ScalePressButton(
            onTap: _handleDownvote,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Icon(
                _isDownvoted ? Icons.arrow_downward_rounded : Icons.arrow_downward_outlined,
                size: 16,
                color: _isDownvoted
                    ? Colors.red
                    : (isDark ? const Color(0xFFA1A1AA) : const Color(0xFF52525B)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotedPost(Post quoted, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.format_quote_rounded, size: 14, color: Color(0xFF004B87)),
              const SizedBox(width: 4),
              Text(
                quoted.authorAlias,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
              const SizedBox(width: 6),
              Text(
                TimeUtils.timeAgo(quoted.createdAt),
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            quoted.title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            quoted.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPollWidget(PostPoll poll, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.poll_outlined, size: 16, color: Color(0xFF004B87)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  poll.question,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...poll.options.map((opt) {
            final total = poll.totalVotes;
            final percent = total > 0 ? (opt.votesCount / total).clamp(0.0, 1.0) : 0.0;
            final isMyVote = poll.myVotedOptionId == opt.id;

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _ScalePressButton(
                onTap: () => widget.onVotePoll?.call(poll.id, opt.id),
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isMyVote ? const Color(0xFF004B87) : Colors.grey.shade400.withValues(alpha: 0.4),
                      width: isMyVote ? 1.5 : 1.0,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Stack(
                      children: [
                        if (poll.myVotedOptionId != null)
                          FractionallySizedBox(
                            widthFactor: percent,
                            child: Container(
                              color: isMyVote
                                  ? const Color(0xFF004B87).withValues(alpha: 0.18)
                                  : Colors.grey.withValues(alpha: 0.12),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                opt.optionText,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isMyVote ? FontWeight.w700 : FontWeight.w500,
                                ),
                              ),
                              if (poll.myVotedOptionId != null)
                                Text(
                                  '${(percent * 100).toStringAsFixed(0)}% (${opt.votesCount})',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    fontFeatures: const [FontFeature.tabularFigures()],
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
        ],
      ),
    );
  }
}

class _ScalePressButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _ScalePressButton({required this.child, required this.onTap});

  @override
  State<_ScalePressButton> createState() => _ScalePressButtonState();
}

class _ScalePressButtonState extends State<_ScalePressButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
