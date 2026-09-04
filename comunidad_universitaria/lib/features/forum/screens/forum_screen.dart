import 'package:flutter/material.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/models/post.dart';
import '../../../core/services/forum_service.dart';
import '../../../core/services/supabase_service.dart';
import '../models/discord_forum_models.dart';
import '../widgets/create_post_dialog.dart';
import '../widgets/digg/digg_header.dart';
import '../widgets/digg/digg_post_card.dart';
import '../widgets/digg/digg_sidebar_left.dart';
import '../widgets/digg/digg_sidebar_right.dart';
import 'post_detail_screen.dart';
import '../../shared/widgets/auth_modal.dart';
import '../../shared/widgets/empty_state_widget.dart';

class ForumScreen extends StatefulWidget {
  final String activeAlias;
  final Function(String newAlias) onAliasChanged;
  final VoidCallback? onToggleTheme;
  final bool isDarkMode;
  final ForumChannel? activeChannel;
  final ForumServer? activeServer;
  final String activeSection;
  final String? activeCommunityId;
  final DiggFeedFilter activeFeedFilter;
  final String searchQuery;
  final bool isEmbeddedInShell;
  final Function(ForumChannel newChannel)? onChannelChanged;

  const ForumScreen({
    super.key,
    required this.activeAlias,
    required this.onAliasChanged,
    this.onToggleTheme,
    this.isDarkMode = false,
    this.activeChannel,
    this.activeServer,
    this.onChannelChanged,
    this.activeSection = 'featured',
    this.activeCommunityId,
    this.activeFeedFilter = DiggFeedFilter.myFeed,
    this.searchQuery = '',
    this.isEmbeddedInShell = false,
  });

  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Discord Forum Models State
  late ForumChannel _activeChannel;
  late ForumServer _activeServer;

  // Filter & Navigation States
  DiggFeedFilter _activeFeedFilter = DiggFeedFilter.myFeed;
  final String _activeSection = 'featured'; // 'questions', 'featured', 'top'

  // Data & Search States
  List<Post> _posts = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();


  @override
  void initState() {
    super.initState();
    _activeChannel = widget.activeChannel ?? ForumChannel.defaultChannels.first;
    _activeServer = widget.activeServer ?? ForumServer.defaultServers.first;
    _loadPosts();
  }

  @override
  void didUpdateWidget(covariant ForumScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeChannel?.id != widget.activeChannel?.id ||
        oldWidget.activeServer?.id != widget.activeServer?.id ||
        oldWidget.activeSection != widget.activeSection ||
        oldWidget.activeCommunityId != widget.activeCommunityId ||
        oldWidget.searchQuery != widget.searchQuery ||
        oldWidget.activeFeedFilter != widget.activeFeedFilter) {
      if (widget.activeChannel != null) {
        _activeChannel = widget.activeChannel!;
      }
      if (widget.activeServer != null) {
        _activeServer = widget.activeServer!;
      }
      _loadPosts();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    setState(() => _isLoading = true);

    final ch = widget.activeChannel ?? _activeChannel;
    final srv = widget.activeServer ?? _activeServer;
    final query = widget.isEmbeddedInShell ? widget.searchQuery : _searchQuery;

    final isBookmarks = ch.isSpecial;
    final category = isBookmarks ? 'todos' : ch.categoryId;

    final posts = await ForumService.fetchPosts(
      category: category,
      facultad: srv.facultadId,
      carrera: srv.carreraId,
      searchQuery: query,
      showOnlyBookmarks: isBookmarks,
    );

    // If section is 'top', sort posts by likes descending
    if (widget.activeSection == 'top' || _activeSection == 'top') {
      posts.sort((a, b) => b.likes.compareTo(a.likes));
    }

    if (mounted) {
      setState(() {
        _posts = posts;
        _isLoading = false;
      });
    }
  }



  Future<void> _handleToggleLike(Post post) async {
    if (SupabaseConfig.isConfigured && !SupabaseService.isAuthenticated) {
      AuthModal.show(
        context,
        title: 'Inicia Sesión para Votar',
        subtitle: 'Para valorar publicaciones útiles en la comunidad, debes iniciar sesión.',
        onAuthenticated: () => _handleToggleLike(post),
      );
      return;
    }

    final prevLiked = post.isLikedByMe;
    final prevLikes = post.likes;

    setState(() {
      final idx = _posts.indexWhere((p) => p.id == post.id);
      if (idx != -1) {
        _posts[idx] = post.copyWith(
          isLikedByMe: !prevLiked,
          likes: prevLiked ? (prevLikes - 1).clamp(0, 999999) : prevLikes + 1,
        );
      }
    });

    final success = await ForumService.toggleLike(post);
    if (mounted && success != !prevLiked) {
      setState(() {
        final idx = _posts.indexWhere((p) => p.id == post.id);
        if (idx != -1) {
          _posts[idx] = post.copyWith(isLikedByMe: prevLiked, likes: prevLikes);
        }
      });
    }
  }

  Future<void> _handleToggleBookmark(Post post) async {
    if (SupabaseConfig.isConfigured && !SupabaseService.isAuthenticated) {
      AuthModal.show(
        context,
        title: 'Inicia Sesión para Guardar',
        subtitle: 'Para guardar publicaciones importantes en tus marcadores, debes iniciar sesión.',
        onAuthenticated: () => _handleToggleBookmark(post),
      );
      return;
    }

    final prevBookmarked = post.isBookmarkedByMe;
    setState(() {
      final idx = _posts.indexWhere((p) => p.id == post.id);
      if (idx != -1) {
        _posts[idx] = post.copyWith(isBookmarkedByMe: !prevBookmarked);
      }
    });

    final success = await ForumService.toggleBookmark(post);
    if (mounted) {
      if (success != !prevBookmarked) {
        setState(() {
          final idx = _posts.indexWhere((p) => p.id == post.id);
          if (idx != -1) {
            _posts[idx] = post.copyWith(isBookmarkedByMe: prevBookmarked);
          }
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
    if (SupabaseConfig.isConfigured && !SupabaseService.isAuthenticated) {
      AuthModal.show(
        context,
        title: 'Inicia Sesión para Votar en la Encuesta',
        subtitle: 'Para participar en las votaciones comunitarias, debes iniciar sesión.',
        onAuthenticated: () => _handleVotePoll(pollId, optionId),
      );
      return;
    }

    final postIdx = _posts.indexWhere((p) => p.poll?.id == pollId);
    if (postIdx != -1) {
      final oldPoll = _posts[postIdx].poll!;
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
        _posts[postIdx] = _posts[postIdx].copyWith(
          poll: oldPoll.copyWith(
            options: newOptions,
            myVotedOptionId: optionId,
          ),
        );
      });
    }

    final ok = await ForumService.votePoll(pollId: pollId, optionId: optionId);
    if (mounted && !ok) {
      _loadPosts();
    }
  }

  void _handleQuotePost(Post post) {
    if (SupabaseConfig.isConfigured && !SupabaseService.isAuthenticated) {
      AuthModal.show(
        context,
        title: 'Inicia Sesión para Citar',
        subtitle: 'Para republicar o citar esta noticia en el feed, debes iniciar sesión.',
        onAuthenticated: () => _handleQuotePost(post),
      );
      return;
    }

    final ch = widget.activeChannel ?? _activeChannel;
    final srv = widget.activeServer ?? _activeServer;

    CreatePostDialog.show(
      context,
      activeAlias: widget.activeAlias,
      quotedPost: post,
      serverName: srv.name,
      channelName: ch.name,
      initialCategory: ch.categoryId,
      initialFacultad: srv.facultadId,
      initialCarrera: srv.carreraId,
      onAliasChanged: widget.onAliasChanged,
      onPostCreated: (newPost) {
        setState(() {
          _posts.insert(0, newPost);
        });
      },
    );
  }

  void _openCreateDialog() {
    if (SupabaseConfig.isConfigured && !SupabaseService.isAuthenticated) {
      AuthModal.show(
        context,
        title: 'Inicia Sesión para Publicar',
        subtitle: 'Para crear publicaciones y compartir novedades, debes iniciar sesión.',
        onAuthenticated: () {
          _showCreateDialog();
        },
      );
      return;
    }
    _showCreateDialog();
  }

  void _showCreateDialog() {
    final ch = widget.activeChannel ?? _activeChannel;
    final srv = widget.activeServer ?? _activeServer;

    CreatePostDialog.show(
      context,
      activeAlias: widget.activeAlias,
      serverName: srv.name,
      channelName: ch.name,
      initialCategory: ch.categoryId,
      initialFacultad: srv.facultadId,
      initialCarrera: srv.carreraId,
      onAliasChanged: widget.onAliasChanged,
      onPostCreated: (newPost) {
        setState(() {
          _posts.insert(0, newPost);
        });
      },
    );
  }

  void _openPostDetail(Post post) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(
          initialPost: post,
          activeAlias: widget.activeAlias,
        ),
      ),
    );
    _loadPosts();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 1080;
    final isTablet = width >= 768 && width < 1080;
    final isDark = theme.brightness == Brightness.dark;

    final feedBg = isDark ? const Color(0xFF18181B) : const Color(0xFFF4F4F5);

    if (!isDesktop && !isTablet) {
      return _buildMobileScaffold(theme, isDark, feedBg);
    }

    if (widget.isEmbeddedInShell) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Central Column (Feed List with Facebook-style Create Post composer)
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadPosts,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: _buildFeedList(theme, isDark),
                ),
              ),
            ),
          ),

          // Right Sidebar (Widgets & Recommendations - on wide desktop)
          if (isDesktop)
            DiggSidebarRight(
              trendingPosts: _posts,
              onTrendingPostTap: _openPostDetail,
              onJoinCommunity: (commId) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Te has unido a /$commId con éxito.')),
                );
              },
            ),
        ],
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: feedBg,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Left Navigation & USAC Faculty Rail (68px)
          DiggSidebarLeft(
            activeServer: _activeServer,
            onSelectServer: (srv) {
              setState(() {
                _activeServer = srv;
              });
              _loadPosts();
            },
            activeChannel: _activeChannel,
            onSelectChannel: (ch) {
              setState(() {
                _activeChannel = ch;
              });
              _loadPosts();
            },
            activeAlias: widget.activeAlias,
            onOpenSettings: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ajustes y preferencias de la cuenta.')),
              );
            },
          ),

          // 2. Central Column (Header + Feed)
          Expanded(
            child: Container(
              color: feedBg,
              child: Column(
                children: [
                  // Top Control Header
                  DiggHeader(
                    currentIndex: 0,
                    activeChannel: _activeChannel,
                    onChannelChanged: (ch) {
                      setState(() => _activeChannel = ch);
                      _loadPosts();
                    },
                    activeServer: _activeServer,
                    onServerChanged: (srv) {
                      setState(() => _activeServer = srv);
                      _loadPosts();
                    },
                    activeFilter: _activeFeedFilter,
                    onFilterChanged: (filter) {
                      setState(() => _activeFeedFilter = filter);
                      _loadPosts();
                    },
                    searchController: _searchController,
                    onSearchSubmitted: (val) {
                      setState(() => _searchQuery = val);
                      _loadPosts();
                    },
                    onClearSearch: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                      _loadPosts();
                    },
                    activeAlias: widget.activeAlias,
                    onAliasChanged: widget.onAliasChanged,
                    onOpenCreatePost: _openCreateDialog,
                    onToggleTheme: widget.onToggleTheme,
                    isDarkMode: widget.isDarkMode,
                  ),

                  // Feed List
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _loadPosts,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 720),
                          child: _buildFeedList(theme, isDark),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Right Sidebar (Widgets & Recommendations - on wide desktop)
          if (isDesktop)
            DiggSidebarRight(
              trendingPosts: _posts,
              onTrendingPostTap: _openPostDetail,
              onJoinCommunity: (commId) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Te has unido a /$commId con éxito.')),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMobileScaffold(ThemeData theme, bool isDark, Color feedBg) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: feedBg,
      drawer: Drawer(
        width: 280,
        child: Row(
          children: [
            DiggSidebarLeft(
              activeServer: _activeServer,
              onSelectServer: (srv) {
                setState(() {
                  _activeServer = srv;
                });
                _loadPosts();
                if (_scaffoldKey.currentState?.isDrawerOpen == true) {
                  Navigator.of(context).pop();
                }
              },
              activeChannel: _activeChannel,
              onSelectChannel: (ch) {
                setState(() {
                  _activeChannel = ch;
                });
                _loadPosts();
                if (_scaffoldKey.currentState?.isDrawerOpen == true) {
                  Navigator.of(context).pop();
                }
              },
              activeAlias: widget.activeAlias,
              onOpenSettings: () {},
            ),
            Expanded(
              child: Container(
                color: isDark ? const Color(0xFF27272A) : Colors.white,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 32),
                    const Text(
                      'Comunidades USAC',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Selecciona una facultad en la barra izquierda para filtrar debates y aportes.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      appBar: AppBar(
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF004B87),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'USAC',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _activeServer.shortCode,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () {
              showSearch(
                context: context,
                delegate: _PostSearchDelegate(posts: _posts, onTapPost: _openPostDetail),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadPosts,
        child: _buildFeedList(theme, isDark),
      ),
    );
  }

  Widget _buildFacebookCreatePostBox(ThemeData theme, bool isDark) {
    final cardBg = isDark ? const Color(0xFF27272A) : Colors.white;
    final inputBg = isDark ? const Color(0xFF18181B) : const Color(0xFFF4F4F5);
    final borderColor = isDark ? const Color(0xFF3F3F46) : const Color(0xFFE4E4E7);
    final hintColor = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A);
    final aliasLetter = widget.activeAlias.trim().isNotEmpty
        ? widget.activeAlias.trim()[0].toUpperCase()
        : 'U';

    final srv = widget.activeServer ?? _activeServer;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row: User Avatar + Clickable Input Box
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE0EDF8),
                  border: Border.all(
                    color: const Color(0xFF004B87),
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  aliasLetter,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF004B87),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: _openCreateDialog,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: inputBg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: borderColor.withValues(alpha: 0.6)),
                    ),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '¿Qué estás pensando, ${widget.activeAlias}? Publica en ${srv.shortCode}...',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: hintColor,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: borderColor.withValues(alpha: 0.6), height: 1),
          const SizedBox(height: 8),

          // Bottom Quick Actions: Foto / Imagen, Encuesta, Duda Académica
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildFacebookActionItem(
                icon: Icons.photo_library_outlined,
                iconColor: const Color(0xFF16A34A),
                label: 'Foto / Archivo',
                onTap: _openCreateDialog,
                isDark: isDark,
              ),
              _buildFacebookActionItem(
                icon: Icons.poll_outlined,
                iconColor: const Color(0xFF2563EB),
                label: 'Encuesta',
                onTap: _openCreateDialog,
                isDark: isDark,
              ),
              _buildFacebookActionItem(
                icon: Icons.help_outline_rounded,
                iconColor: const Color(0xFFD97706),
                label: 'Consulta',
                onTap: _openCreateDialog,
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFacebookActionItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFD4D4D8) : const Color(0xFF52525B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedList(ThemeData theme, bool isDark) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final displayPosts = _posts;

    if (displayPosts.isEmpty) {
      final srv = widget.activeServer ?? _activeServer;
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          _buildFacebookCreatePostBox(theme, isDark),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: EmptyStateWidget(
              icon: Icons.newspaper_rounded,
              title: 'No hay publicaciones en ${srv.name}',
              description: _searchQuery.isNotEmpty
                  ? 'No se encontraron resultados para "$_searchQuery".'
                  : 'Sé el primero en compartir un aporte o consulta en esta facultad.',
              buttonText: 'Crear Primera Publicación',
              onButtonPressed: _openCreateDialog,
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: displayPosts.length + 1, // First item is the Facebook create post box
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildFacebookCreatePostBox(theme, isDark);
        }

        final post = displayPosts[index - 1];
        return DiggPostCard(
          key: ValueKey(post.id),
          post: post,
          onTap: () => _openPostDetail(post),
          onLike: () => _handleToggleLike(post),
          onBookmark: () => _handleToggleBookmark(post),
          onRepost: () => _handleQuotePost(post),
          onVotePoll: (pollId, optionId) => _handleVotePoll(pollId, optionId),
          onReport: (reason) {
            if (post.userId != null) {
              ForumService.reportUser(
                reportedUserId: post.userId!,
                reportedAlias: post.authorAlias,
                reason: reason,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Reporte enviado con éxito.')),
              );
            }
          },
        );
      },
    );
  }
}

class _PostSearchDelegate extends SearchDelegate<String> {
  final List<Post> posts;
  final Function(Post post) onTapPost;

  _PostSearchDelegate({required this.posts, required this.onTapPost});

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, ''),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildList();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildList();
  }

  Widget _buildList() {
    final filtered = posts.where((p) {
      final q = query.toLowerCase();
      return p.title.toLowerCase().contains(q) ||
          p.content.toLowerCase().contains(q) ||
          p.authorAlias.toLowerCase().contains(q);
    }).toList();

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final post = filtered[index];
        return ListTile(
          title: Text(post.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${post.authorAlias} • ${post.category}'),
          onTap: () {
            close(context, '');
            onTapPost(post);
          },
        );
      },
    );
  }
}
