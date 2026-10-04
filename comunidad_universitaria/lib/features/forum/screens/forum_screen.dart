import 'package:flutter/material.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/models/post.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/services/forum_service.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/services/supabase_service.dart';
import '../models/discord_forum_models.dart';
import '../widgets/create_post_dialog.dart';
import '../widgets/discord/forum_channel_sidebar.dart';
import '../widgets/discord/forum_server_rail.dart';
import '../widgets/post_card.dart';
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
  final Function(ForumChannel newChannel)? onChannelChanged;
  final Function(ForumServer newServer)? onServerChanged;
  final String searchQuery;
  final bool isEmbeddedInShell;
  final String activeSection;
  final String? activeCommunityId;

  const ForumScreen({
    super.key,
    required this.activeAlias,
    required this.onAliasChanged,
    this.onToggleTheme,
    this.isDarkMode = false,
    this.activeChannel,
    this.activeServer,
    this.onChannelChanged,
    this.onServerChanged,
    this.searchQuery = '',
    this.isEmbeddedInShell = false,
    this.activeSection = 'featured',
    this.activeCommunityId,
  });

  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Discord Forum Models State
  late List<ForumServer> _servers;
  late ForumServer _activeServer;
  late ForumChannel _activeChannel;
  List<ForumChannel> _channels = List.from(ForumChannel.defaultChannels);
  List<ForumFaculty> _faculties = List.from(ForumFaculty.defaultFaculties);

  // Data & Search States
  List<Post> _posts = [];
  bool _isLoading = true;
  bool _isOffline = false;
  UserProfile? _currentUserProfile;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _servers = List.from(ForumServer.defaultServers);
    _activeServer = widget.activeServer ?? _servers.first;
    _activeChannel = widget.activeChannel ?? ForumChannel.defaultChannels.first;
    _searchQuery = widget.searchQuery;
    if (_searchQuery.isNotEmpty) {
      _searchController.text = _searchQuery;
    }
    _loadUserProfile();
    _loadForumStructure();
    _loadPosts();
  }

  Future<void> _loadForumStructure() async {
    try {
      final channels = await ForumService.fetchForumChannels();
      final faculties = await ForumService.fetchForumFaculties();
      if (mounted) {
        setState(() {
          _channels = channels;
          _faculties = faculties;
          if (!_channels.any((c) => c.id == _activeChannel.id) &&
              _activeChannel.id != ForumChannel.bookmarksChannel.id) {
            _activeChannel = _channels.first;
          }
        });
      }
    } catch (e) {
      debugPrint('Error cargando estructura del foro desde DB: $e');
    }
  }

  Future<void> _loadUserProfile() async {
    final prof = await LocalStorageService.getUserProfile();
    if (mounted) {
      setState(() {
        _currentUserProfile = prof;
      });
    }
  }

  @override
  void didUpdateWidget(covariant ForumScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    bool shouldReload = false;
    if (widget.activeChannel != null && widget.activeChannel!.id != _activeChannel.id) {
      _activeChannel = widget.activeChannel!;
      shouldReload = true;
    }
    if (widget.activeServer != null && widget.activeServer!.id != _activeServer.id) {
      _activeServer = widget.activeServer!;
      shouldReload = true;
    }
    if (widget.searchQuery != oldWidget.searchQuery && widget.searchQuery != _searchQuery) {
      _searchQuery = widget.searchQuery;
      _searchController.text = _searchQuery;
      shouldReload = true;
    }
    if (shouldReload) {
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

    try {
      final isBookmarks = _activeChannel.isSpecial;
      final category = isBookmarks ? 'todos' : _activeChannel.categoryId;

      final posts = await ForumService.fetchPosts(
        category: category,
        facultad: _activeServer.facultadId,
        carrera: _activeServer.carreraId,
        searchQuery: _searchQuery,
        showOnlyBookmarks: isBookmarks,
      );

      if (mounted) {
        setState(() {
          _posts = posts;
          _isLoading = false;
          _isOffline = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isOffline = true;
        });
      }
    }
  }

  void _onSelectServer(ForumServer server) {
    if (_activeServer.id == server.id) return;
    setState(() {
      _activeServer = server;
      _searchQuery = '';
      _searchController.clear();
    });
    widget.onServerChanged?.call(server);
    _loadPosts();
  }

  void _onAddServer(ForumServer newServer) {
    final exists = _servers.any((s) => s.id == newServer.id);
    if (!exists) {
      setState(() {
        _servers.add(newServer);
      });
    }
  }

  void _onSelectChannel(ForumChannel channel) {
    if (_activeChannel.id == channel.id) return;
    setState(() {
      _activeChannel = channel;
      _searchQuery = '';
      _searchController.clear();
    });
    widget.onChannelChanged?.call(channel);
    _loadPosts();

    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.of(context).pop();
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
        if (_activeChannel.isSpecial && prevBookmarked) {
          _loadPosts();
        }
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
        subtitle: 'Para republicar o citar esta consulta en el foro, debes iniciar sesión.',
        onAuthenticated: () => _handleQuotePost(post),
      );
      return;
    }

    CreatePostDialog.show(
      context,
      activeAlias: widget.activeAlias,
      quotedPost: post,
      serverName: _activeServer.name,
      channelName: _activeChannel.name,
      initialCategory: _activeChannel.isSpecial ? 'general' : _activeChannel.categoryId,
      initialCarrera: _activeServer.carreraId,
      initialFacultad: _activeServer.facultadId,
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
        subtitle: 'Para participar y crear consultas en el foro estudiantil, debes iniciar sesión.',
        onAuthenticated: () {
          _showCreateDialog();
        },
      );
      return;
    }
    _showCreateDialog();
  }

  void _showCreateDialog() {
    CreatePostDialog.show(
      context,
      activeAlias: widget.activeAlias,
      serverName: _activeServer.name,
      channelName: _activeChannel.name,
      initialCategory: _activeChannel.isSpecial ? 'general' : _activeChannel.categoryId,
      initialCarrera: _activeServer.carreraId,
      initialFacultad: _activeServer.facultadId,
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
    final isDark = theme.brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final isDesktopOrTablet = width >= 768;

    // Discord main chat background: #313338 dark, #FFFFFF light
    final feedBg = isDark ? const Color(0xFF313338) : Colors.white;

    if (isDesktopOrTablet) {
      return Scaffold(
        backgroundColor: feedBg,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Server Rail (72px)
            ForumServerRail(
              servers: _servers,
              activeServer: _activeServer,
              faculties: _faculties,
              onSelectServer: _onSelectServer,
              onAddServer: _onAddServer,
            ),

            // 2. Channel Sidebar (240px)
            ForumChannelSidebar(
              activeServer: _activeServer,
              activeChannel: _activeChannel,
              channels: _channels,
              onSelectChannel: _onSelectChannel,
              onServerChanged: _onSelectServer,
              activeAlias: widget.activeAlias,
              onAliasChanged: widget.onAliasChanged,
            ),

            // 3. Central Channel Feed without redundant pinned header
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadPosts,
                child: _buildFeedContent(theme, isDark),
              ),
            ),
          ],
        ),
      );
    }

    // Mobile layout (< 768px): Unified, sleek Discord mobile layout without double AppBars or redundant FAB
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: feedBg,
      drawer: Drawer(
        width: 312,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ForumServerRail(
              servers: _servers,
              activeServer: _activeServer,
              faculties: _faculties,
              onSelectServer: (srv) {
                _onSelectServer(srv);
                if (_scaffoldKey.currentState?.isDrawerOpen == true) {
                  Navigator.of(context).pop();
                }
              },
              onAddServer: _onAddServer,
            ),
            Expanded(
              child: ForumChannelSidebar(
                activeServer: _activeServer,
                activeChannel: _activeChannel,
                channels: _channels,
                onSelectChannel: _onSelectChannel,
                onServerChanged: (srv) {
                  _onSelectServer(srv);
                  if (_scaffoldKey.currentState?.isDrawerOpen == true) {
                    Navigator.of(context).pop();
                  }
                },
                activeAlias: widget.activeAlias,
                onAliasChanged: widget.onAliasChanged,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Pinned Discord Mobile Channel Bar (clean, no second full AppBar)
            _buildMobileChannelHeader(theme, isDark),
            // Posts Feed
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadPosts,
                child: _buildFeedContent(theme, isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileChannelHeader(ThemeData theme, bool isDark) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF313338) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF202225) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu, size: 22),
            tooltip: 'Canales y Servidores',
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          const SizedBox(width: 4),
          Icon(
            _activeChannel.icon,
            size: 18,
            color: isDark ? const Color(0xFF949BA4) : theme.colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '#${_activeChannel.name}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _activeServer.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _activeServer.shortCode,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: _activeServer.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedContent(ThemeData theme, bool isDark) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      children: [
        _buildDiscordWelcomeHero(theme, isDark),
        const SizedBox(height: 12),

        if (_isOffline) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.amber.shade900.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Icon(Icons.wifi_off, size: 16, color: Colors.amber.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sin conexión — Mostrando contenido guardado.',
                    style: TextStyle(fontSize: 12, color: Colors.amber.shade700, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],

        if (_posts.isEmpty)
          EmptyStateWidget(
            icon: _activeChannel.icon,
            title: _activeChannel.isSpecial
                ? 'No tienes publicaciones guardadas'
                : 'No hay mensajes en #${_activeChannel.name}',
            description: _activeChannel.isSpecial
                ? 'Guarda consultas importantes del foro tocando el icono de marcador.'
                : 'Sé el primero en iniciar una conversación o formular una duda en este canal.',
            buttonText: 'Crear Primera Publicación',
            onButtonPressed: _openCreateDialog,
          )
        else
          ..._posts.map((post) {
            return PostCard(
              key: ValueKey(post.id),
              post: post,
              isModerator: _currentUserProfile?.isModerator == true,
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
          }),
      ],
    );
  }

  Widget _buildDiscordWelcomeHero(ThemeData theme, bool isDark) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 800;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2B2D31) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF383A40) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF3F4147) : const Color(0xFFEEF2FF),
                  shape: BoxShape.circle,
                ),
                child: Icon(_activeChannel.icon, size: 22, color: isDark ? Colors.white : const Color(0xFF5865F2)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¡Te damos la bienvenida a #${_activeChannel.name}!',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _activeChannel.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF949BA4) : const Color(0xFF64748B),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isDesktop) ...[
                const SizedBox(width: 14),
                SizedBox(
                  width: 180,
                  height: 36,
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Buscar...',
                      hintStyle: TextStyle(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF949BA4) : Colors.grey.shade500,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        size: 16,
                        color: isDark ? const Color(0xFF949BA4) : Colors.grey.shade500,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                size: 14,
                                color: isDark ? const Color(0xFF949BA4) : Colors.grey.shade500,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                                _loadPosts();
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E1F22) : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDark ? const Color(0xFF383A40) : const Color(0xFFCBD5E1),
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDark ? const Color(0xFF383A40) : const Color(0xFFCBD5E1),
                          width: 1,
                        ),
                      ),
                    ),
                    onSubmitted: (val) {
                      setState(() => _searchQuery = val);
                      _loadPosts();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5865F2), // Discord Blurple
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Publicar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: _openCreateDialog,
                ),
              ],
            ],
          ),
          if (!isDesktop) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Buscar en #${_activeChannel.name}...',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF949BA4) : Colors.grey.shade500,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          size: 18,
                          color: isDark ? const Color(0xFF949BA4) : Colors.grey.shade500,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  size: 16,
                                  color: isDark ? const Color(0xFF949BA4) : Colors.grey.shade500,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                  _loadPosts();
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E1F22) : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF383A40) : const Color(0xFFCBD5E1),
                            width: 1,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF383A40) : const Color(0xFFCBD5E1),
                            width: 1,
                          ),
                        ),
                      ),
                      onSubmitted: (val) {
                        setState(() => _searchQuery = val);
                        _loadPosts();
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5865F2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Publicar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: _openCreateDialog,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
