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
import '../widgets/discord/popular_servers_sidebar.dart';
import '../widgets/post_card.dart';
import 'post_detail_screen.dart';
import '../../groups/screens/groups_screen.dart';
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
  final List<PopularServerItem>? initialPopularServers;

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
    this.initialPopularServers,
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
  late ForumChannel _groupsActiveChannel;
  List<ForumChannel> _channels = List.from(ForumChannel.defaultChannels);
  List<ForumFaculty> _faculties = List.from(ForumFaculty.defaultFaculties);
  List<PopularServerItem> _popularServers = [];
  bool _isLoadingPopular = false;

  // Data & Search States
  List<Post> _posts = [];
  bool _isLoading = true;
  bool _isOffline = false;
  UserProfile? _currentUserProfile;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _feedScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _servers = List.from(ForumServer.defaultServers);
    _activeServer = widget.activeServer ?? _servers.first;
    _activeChannel = widget.activeChannel ??
        ForumChannel.defaultChannels.firstWhere(
          (c) => c.id == 'todos',
          orElse: () => ForumChannel.defaultChannels.first,
        );
    final initialGroupsChannels = ForumChannel.groupsChannelsForSubserver(
      _activeServer.isGroups ? _activeServer : ForumServer.groupsSubservers.first,
      _faculties,
    );
    _groupsActiveChannel = initialGroupsChannels.first;
    if (widget.initialPopularServers != null) {
      _popularServers = List.from(widget.initialPopularServers!);
    }
    _searchQuery = widget.searchQuery;
    if (_searchQuery.isNotEmpty) {
      _searchController.text = _searchQuery;
    }
    _loadUserProfile();
    _loadForumStructure();
    if (widget.initialPopularServers == null) {
      _loadPopularServers();
    }
    if (!_activeServer.isGroups) {
      _loadPosts();
    }
  }

  Future<void> _loadPopularServers() async {
    setState(() => _isLoadingPopular = true);
    try {
      final popular = await ForumService.fetchPopularServers(faculties: _faculties);
      if (mounted) {
        setState(() {
          _popularServers = popular;
          _isLoadingPopular = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingPopular = false);
    }
  }

  Future<void> _loadForumStructure() async {
    try {
      final channels = await ForumService.fetchForumChannels();
      final faculties = await ForumService.fetchForumFaculties();
      if (mounted) {
        setState(() {
          _channels = channels;
          _faculties = faculties;
          if (_activeChannel.id == 'general' ||
              (!_channels.any((c) => c.id == _activeChannel.id) &&
                  _activeChannel.id != ForumChannel.bookmarksChannel.id)) {
            _activeChannel = _channels.firstWhere(
              (c) => c.id == 'todos',
              orElse: () => _channels.first,
            );
          }
        });
        if (widget.initialPopularServers == null) {
          _loadPopularServers();
        }
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
      if (!_activeServer.isGroups) {
        shouldReload = true;
      }
    }
    if (widget.searchQuery != oldWidget.searchQuery && widget.searchQuery != _searchQuery) {
      _searchQuery = widget.searchQuery;
      _searchController.text = _searchQuery;
      if (!_activeServer.isGroups) {
        shouldReload = true;
      }
    }
    if (shouldReload) {
      _loadPosts();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _feedScrollController.dispose();
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
      if (server.isGroups) {
        final subChannels = ForumChannel.groupsChannelsForSubserver(server, _faculties);
        _groupsActiveChannel = subChannels.first;
      } else {
        // Siempre por predeterminado se abre el canal de todos los temas
        _activeChannel = _channels.firstWhere(
          (c) => c.id == 'todos',
          orElse: () => _channels.first,
        );
      }
    });
    widget.onServerChanged?.call(server);
    if (!server.isGroups) {
      _loadPosts();
    }
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
    if (_activeServer.isGroups) {
      if (_groupsActiveChannel.id == channel.id) return;
      setState(() {
        _groupsActiveChannel = channel;
      });
      widget.onChannelChanged?.call(channel);
      if (_scaffoldKey.currentState?.isDrawerOpen == true) {
        Navigator.of(context).pop();
      }
      return;
    }

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
      initialCategory: _activeChannel.isSpecial
          ? 'prerrequisitos'
          : (_activeChannel.id == 'todos' ? 'todos' : _activeChannel.categoryId),
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
    if (_activeChannel.isSpecial) return;
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
    if (_activeChannel.isSpecial) return;
    CreatePostDialog.show(
      context,
      activeAlias: widget.activeAlias,
      serverName: _activeServer.name,
      channelName: _activeChannel.name,
      initialCategory: _activeChannel.id == 'todos' ? 'todos' : _activeChannel.categoryId,
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
    final showRightSidebar = width >= 1050;

    // Discord main chat background: #313338 dark, #FFFFFF light
    final feedBg = isDark ? const Color(0xFF313338) : Colors.white;

    final isGroups = _activeServer.isGroups;
    final currentChannel = isGroups ? _groupsActiveChannel : _activeChannel;
    final currentChannels = isGroups
        ? ForumChannel.groupsChannelsForSubserver(_activeServer, _faculties)
        : _channels;

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
              activeChannel: currentChannel,
              channels: currentChannels,
              onSelectChannel: _onSelectChannel,
              onServerChanged: _onSelectServer,
              activeAlias: widget.activeAlias,
              onAliasChanged: widget.onAliasChanged,
            ),

            // 3. Main Content: GroupsScreen if isGroups, otherwise Channel Feed
            if (isGroups)
              Expanded(
                child: GroupsScreen(
                  activeAlias: widget.activeAlias,
                  onAliasChanged: widget.onAliasChanged,
                  activeFacultadId: _activeServer.facultadId,
                  activeCarreraId: _groupsActiveChannel.categoryId,
                  activeChannelName: _groupsActiveChannel.name,
                  activeChannelDescription: _groupsActiveChannel.description,
                  activeChannelIcon: _groupsActiveChannel.icon,
                ),
              )
            else
              Expanded(
                child: _buildFeedContainer(theme, isDark),
              ),

            // 4. Barra lateral derecha fija y general: Top 5 comunidades más populares
            if (showRightSidebar)
              PopularServersSidebar(
                popularServers: _popularServers,
                activeServer: _activeServer,
                isLoading: _isLoadingPopular,
                onSelectServer: _onSelectServer,
                onRefresh: _loadPopularServers,
              ),
          ],
        ),
      );
    }

    // Mobile layout (< 768px): Unified, sleek Discord mobile layout
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
                activeChannel: currentChannel,
                channels: currentChannels,
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
            if (isGroups)
              _buildMobileGroupsHeader(theme, isDark)
            else
              _buildMobileChannelHeader(theme, isDark),
            Expanded(
              child: isGroups
                  ? GroupsScreen(
                      activeAlias: widget.activeAlias,
                      onAliasChanged: widget.onAliasChanged,
                      activeFacultadId: _activeServer.facultadId,
                      activeCarreraId: _groupsActiveChannel.categoryId,
                      activeChannelName: _groupsActiveChannel.name,
                      activeChannelDescription: _groupsActiveChannel.description,
                      activeChannelIcon: _groupsActiveChannel.icon,
                    )
                  : _buildFeedContainer(theme, isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileGroupsHeader(ThemeData theme, bool isDark) {
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
          const Icon(
            Icons.chat,
            size: 18,
            color: Color(0xFF25D366),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '#${_groupsActiveChannel.name}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF25D366).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'WAPP',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFF25D366),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(
              Icons.local_fire_department_rounded,
              size: 20,
              color: Color(0xFFF59E0B),
            ),
            tooltip: 'Comunidades Populares',
            onPressed: () => _showPopularServersModal(context),
          ),
        ],
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
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(
              Icons.local_fire_department_rounded,
              size: 20,
              color: Color(0xFFF59E0B),
            ),
            tooltip: 'Comunidades Populares',
            onPressed: () => _showPopularServersModal(context),
          ),
        ],
      ),
    );
  }

  void _showPopularServersModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: SizedBox(
            height: 480,
            child: PopularServersSidebar(
              popularServers: _popularServers,
              activeServer: _activeServer,
              isLoading: _isLoadingPopular,
              isModal: true,
              onSelectServer: (srv) {
                Navigator.of(ctx).pop();
                _onSelectServer(srv);
              },
              onRefresh: _loadPopularServers,
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeedContainer(ThemeData theme, bool isDark) {
    return Column(
      children: [
        // Barra superior fija para todos los canales con bienvenida, buscador y botón de publicar
        _buildDiscordWelcomeHero(theme, isDark),

        if (_isOffline) ...[
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
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

        // Área scrolleable de publicaciones con scrollbar dedicada y física estándar
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadPosts,
            child: _buildPostsFeed(theme, isDark),
          ),
        ),
      ],
    );
  }

  Widget _buildPostsFeed(ThemeData theme, bool isDark) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_posts.isEmpty) {
      return ListView(
        controller: _feedScrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          EmptyStateWidget(
            icon: _activeChannel.icon,
            title: _activeChannel.isSpecial
                ? 'No tienes publicaciones guardadas'
                : 'No hay mensajes en #${_activeChannel.name}',
            description: _activeChannel.isSpecial
                ? 'Guarda consultas importantes del foro tocando el icono de marcador.'
                : 'Sé el primero en iniciar una conversación o formular una duda en este canal.',
            buttonText: _activeChannel.isSpecial ? null : 'Crear Primera Publicación',
            onButtonPressed: _activeChannel.isSpecial ? null : _openCreateDialog,
          ),
        ],
      );
    }

    return Scrollbar(
      controller: _feedScrollController,
      child: ListView.builder(
        controller: _feedScrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: _posts.length,
        itemBuilder: (ctx, index) {
          final post = _posts[index];
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
        },
      ),
    );
  }

  Widget _buildDiscordWelcomeHero(ThemeData theme, bool isDark) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 800;

    if (isDesktop) {
      return Container(
        height: 56,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2B2D31) : const Color(0xFFF8FAFC),
          border: Border(
            bottom: BorderSide(
              color: isDark ? const Color(0xFF202225) : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF383A40) : const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(_activeChannel.icon, size: 16, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '¡Te damos la bienvenida a #${_activeChannel.name}!',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _activeChannel.description,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark ? const Color(0xFF949BA4) : const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 180,
              height: 32,
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
                    size: 15,
                    color: isDark ? const Color(0xFF949BA4) : Colors.grey.shade500,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            Icons.clear,
                            size: 13,
                            color: isDark ? const Color(0xFF949BA4) : Colors.grey.shade500,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                            _loadPosts();
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E1F22) : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(
                      color: isDark ? const Color(0xFF383A40) : const Color(0xFFCBD5E1),
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
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
            if (!_activeChannel.isSpecial) ...[
              const SizedBox(width: 8),
              SizedBox(
                height: 32,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  icon: const Icon(Icons.add, size: 15),
                  label: const Text('Publicar', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                  onPressed: _openCreateDialog,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2B2D31) : const Color(0xFFF8FAFC),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF202225) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_activeChannel.icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '¡Te damos la bienvenida a #${_activeChannel.name}!',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!_activeChannel.isSpecial)
                SizedBox(
                  height: 30,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('Publicar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: _openCreateDialog,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 34,
            child: TextField(
              controller: _searchController,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: 'Buscar en #${_activeChannel.name}...',
                hintStyle: TextStyle(
                  fontSize: 11.5,
                  color: isDark ? const Color(0xFF949BA4) : Colors.grey.shade500,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 16,
                  color: isDark ? const Color(0xFF949BA4) : Colors.grey.shade500,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        padding: EdgeInsets.zero,
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
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E1F22) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF383A40) : const Color(0xFFCBD5E1),
                    width: 1,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
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
        ],
      ),
    );
  }
}
