import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/models/post.dart';
import '../../../../core/utils/time_utils.dart';

class DiggSidebarRight extends StatefulWidget {
  final List<Post> trendingPosts;
  final Function(Post post)? onTrendingPostTap;
  final Function(String communityId)? onJoinCommunity;

  const DiggSidebarRight({
    super.key,
    required this.trendingPosts,
    this.onTrendingPostTap,
    this.onJoinCommunity,
  });

  @override
  State<DiggSidebarRight> createState() => _DiggSidebarRightState();
}

class _DiggSidebarRightState extends State<DiggSidebarRight> {
  // Audio Player State
  bool _isPlaying = false;
  double _progress = 0.15; // 0.0 to 1.0
  int _currentSeconds = 44;
  final int _totalSeconds = 295; // 4:55
  Timer? _playbackTimer;

  // Subscribed communities local state
  final Set<String> _subscribedIds = {'anime-addiction'};

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _playbackTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (_currentSeconds >= _totalSeconds) {
            timer.cancel();
            setState(() {
              _isPlaying = false;
              _currentSeconds = 0;
              _progress = 0.0;
            });
          } else {
            setState(() {
              _currentSeconds++;
              _progress = _currentSeconds / _totalSeconds;
            });
          }
        });
      } else {
        _playbackTimer?.cancel();
      }
    });
  }

  void _seekRelative(int seconds) {
    setState(() {
      _currentSeconds = (_currentSeconds + seconds).clamp(0, _totalSeconds);
      _progress = _currentSeconds / _totalSeconds;
    });
  }

  String _formatTime(int totalSec) {
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _toggleSubscribe(String id) {
    setState(() {
      if (_subscribedIds.contains(id)) {
        _subscribedIds.remove(id);
      } else {
        _subscribedIds.add(id);
      }
    });
    widget.onJoinCommunity?.call(id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7);

    return Container(
      width: 320,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : const Color(0xFFFAFAFA),
        border: Border(
          left: BorderSide(color: borderColor, width: 1),
        ),
      ),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // 1. Digg Daily Player Widget
          _buildDiggDailyPlayer(theme, isDark),

          const SizedBox(height: 20),

          // 2. Discover Communities Widget
          _buildDiscoverCommunities(theme, isDark),

          const SizedBox(height: 20),

          // 3. Featured Posts (Trending)
          _buildTrendingPosts(theme, isDark),

          const SizedBox(height: 24),

          // Footer info / copyright
          Center(
            child: Text(
              'Digg Comunidad Universitaria • 2026\nRed Estudiantil Autónoma',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? const Color(0xFF71717A) : const Color(0xFFA1A1AA),
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // 1. Digg Daily Player Widget
  // -------------------------------------------------------------
  Widget _buildDiggDailyPlayer(ThemeData theme, bool isDark) {
    final playerBg = isDark ? const Color(0xFF27272A) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF3F3F46) : const Color(0xFFE2E8F0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: playerBg,
        borderRadius: BorderRadius.circular(16), // Concentric outer radius
        border: Border.all(color: cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date & Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DIGG DAILY • PODCAST',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: const Color(0xFF004B87),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    CircleAvatar(radius: 3, backgroundColor: Colors.red),
                    SizedBox(width: 4),
                    Text(
                      'HOY',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Title & Host
          const Text(
            'Resumen Académico & Noticias Clave',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Episodio #142 • Edición Express',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
            ),
          ),
          const SizedBox(height: 12),

          // Progress Scrubber Bar
          GestureDetector(
            onHorizontalDragUpdate: (details) {
              final box = context.findRenderObject() as RenderBox?;
              if (box != null) {
                final localX = details.localPosition.dx.clamp(0.0, 260.0);
                setState(() {
                  _progress = (localX / 260.0).clamp(0.0, 1.0);
                  _currentSeconds = (_progress * _totalSeconds).round();
                });
              }
            },
            child: Column(
              children: [
                Container(
                  height: 6,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE4E4E7),
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _progress.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF004B87),
                        borderRadius: BorderRadius.circular(9999),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatTime(_currentSeconds),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      _formatTime(_totalSeconds),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Controls (Chapters, -15s, Play/Pause, +15s)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Chapters dropdown
              PopupMenuButton<String>(
                tooltip: 'Capítulos',
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                itemBuilder: (ctx) => const [
                  PopupMenuItem(value: '1', child: Text('1. Introducción (0:00)')),
                  PopupMenuItem(value: '2', child: Text('2. Cambios en Pensums (1:30)')),
                  PopupMenuItem(value: '3', child: Text('3. Eventos Semanales (3:15)')),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFF4F4F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.list_rounded,
                        size: 14,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Capítulos',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // Jump -15s
              IconButton(
                icon: const Icon(Icons.replay_10_rounded, size: 20),
                tooltip: 'Retroceder 10s',
                onPressed: () => _seekRelative(-10),
              ),

              // Play / Pause Circle Button with optical center
              _ScalePressButton(
                onTap: _togglePlayPause,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF004B87),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33004B87),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Transform.translate(
                    offset: Offset(_isPlaying ? 0 : 1.5, 0), // Optical alignment compensation for play triangle
                    child: Icon(
                      _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),

              // Jump +15s
              IconButton(
                icon: const Icon(Icons.forward_10_rounded, size: 20),
                tooltip: 'Avanzar 10s',
                onPressed: () => _seekRelative(10),
              ),

              const Spacer(),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // 2. Discover Communities Widget
  // -------------------------------------------------------------
  Widget _buildDiscoverCommunities(ThemeData theme, bool isDark) {
    final cardBg = isDark ? const Color(0xFF27272A) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF3F3F46) : const Color(0xFFE2E8F0);

    final suggested = [
      {
        'id': 'anime-addiction',
        'name': '/anime-addiction',
        'desc': '14.2k miembros • 52 posts/d',
        'avatar': '⚡',
        'color': const Color(0xFFEC4899),
      },
      {
        'id': 'consolemods',
        'name': '/consolemods',
        'desc': '8.5k miembros • 18 posts/d',
        'avatar': '🎮',
        'color': const Color(0xFF6366F1),
      },
      {
        'id': 'pcgaming',
        'name': '/pcgaming',
        'desc': '29.1k miembros • 110 posts/d',
        'avatar': '🖥️',
        'color': const Color(0xFF0EA5E9),
      },
      {
        'id': 'usac-ingenieria',
        'name': '/usac-ingenieria',
        'desc': '18.7k miembros • 84 posts/d',
        'avatar': '⚙️',
        'color': const Color(0xFF004B87),
      },
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Discover Communities',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                'Ver todas',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...suggested.map((comm) {
            final isSubscribed = _subscribedIds.contains(comm['id']);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  // Avatar with 1px outline
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (comm['color'] as Color).withValues(alpha: 0.15),
                      border: Border.all(
                        color: isDark ? const Color(0x1AFFFFFF) : const Color(0x14000000),
                        width: 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      comm['avatar'] as String,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          comm['name'] as String,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          comm['desc'] as String,
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Quick Join Button (+)
                  _ScalePressButton(
                    onTap: () => _toggleSubscribe(comm['id'] as String),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isSubscribed
                            ? (isDark ? const Color(0xFF3F3F46) : const Color(0xFFE4E4E7))
                            : const Color(0xFF004B87),
                        borderRadius: BorderRadius.circular(8), // Concentric inner
                      ),
                      alignment: Alignment.center,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 150),
                        child: Icon(
                          isSubscribed ? Icons.check_rounded : Icons.add_rounded,
                          key: ValueKey(isSubscribed),
                          size: 16,
                          color: isSubscribed
                              ? (isDark ? Colors.white : const Color(0xFF18181B))
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // 3. Featured Posts (Trending) Widget
  // -------------------------------------------------------------
  Widget _buildTrendingPosts(ThemeData theme, bool isDark) {
    final cardBg = isDark ? const Color(0xFF27272A) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF3F3F46) : const Color(0xFFE2E8F0);

    final posts = widget.trendingPosts.take(4).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.trending_up_rounded, size: 16, color: Color(0xFFD97706)),
              SizedBox(width: 6),
              Text(
                'Featured Posts (Trending)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (posts.isEmpty)
            Text(
              'No hay tendencias destacadas en este momento.',
              style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
            )
          else
            ...List.generate(posts.length, (index) {
              final post = posts[index];
              return _ScalePressButton(
                onTap: () => widget.onTrendingPostTap?.call(post),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Index number
                      Text(
                        '#${index + 1}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isDark ? const Color(0xFF52525B) : const Color(0xFFA1A1AA),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Post Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  TimeUtils.timeAgo(post.createdAt),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '•  ▲ ${post.likes}  💬 ${post.commentCount}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Tiny 48x48 thumbnail with 1px border
                      if (post.imageUrl != null && post.imageUrl!.isNotEmpty)
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark ? const Color(0x1AFFFFFF) : const Color(0x14000000),
                              width: 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: Image.network(
                              post.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_outlined, size: 20),
                            ),
                          ),
                        ),
                    ],
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
