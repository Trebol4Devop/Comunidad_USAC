import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/models/post.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/services/forum_service.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/services/forum_server_preferences_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../models/discord_forum_models.dart';
import '../widgets/create_post_dialog.dart';
import '../widgets/discord/forum_channel_sidebar.dart';
import '../widgets/discord/forum_carrera_picker_dialog.dart';
import '../widgets/discord/forum_server_rail.dart';
import '../widgets/discord/popular_servers_sidebar.dart';
import '../widgets/post_card.dart';
import 'post_detail_screen.dart';
import '../../groups/screens/groups_screen.dart';
import '../../reviews/screens/seccion_reviews_screen.dart';
import '../../../core/services/profile_service.dart';
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
  FeedMode _feedMode = FeedMode.hot;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _feedScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final generalServer = ForumServer.defaultServers.first;
    _servers = [generalServer];
    _activeServer =
        widget.activeServer != null && !widget.activeServer!.isGroups
        ? widget.activeServer!
        : generalServer;
    if (!_servers.any((server) => server.id == _activeServer.id)) {
      _servers.add(_activeServer);
    }
    _loadSavedServers();
    _activeChannel =
        widget.activeChannel ??
        ForumChannel.defaultChannels.firstWhere(
          (c) => c.id == 'todos',
          orElse: () => ForumChannel.defaultChannels.first,
        );
    final initialGroupsChannels = ForumChannel.groupsChannelsForSubserver(
      _activeServer.isGroups
          ? _activeServer
          : ForumServer.groupsSubservers.first,
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

  Future<void> _loadSavedServers() async {
    final savedServers = await ForumServerPreferencesService.load();
    if (!mounted || savedServers.isEmpty) return;
    setState(() {
      for (final server in savedServers) {
        if (!_servers.any((item) => item.id == server.id)) {
          _servers.add(server);
        }
      }
    });
  }

  Future<void> _loadPopularServers() async {
    setState(() => _isLoadingPopular = true);
    try {
      final popular = await ForumService.fetchPopularServers(
        faculties: _faculties,
      );
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
    if (widget.activeChannel != null &&
        widget.activeChannel!.id != _activeChannel.id) {
      _activeChannel = widget.activeChannel!;
      shouldReload = true;
    }
    if (widget.activeServer != null &&
        !widget.activeServer!.isGroups &&
        widget.activeServer!.id != _activeServer.id) {
      _activeServer = widget.activeServer!;
      if (!_activeServer.isGroups) {
        shouldReload = true;
      }
    }
    if (widget.searchQuery != oldWidget.searchQuery &&
        widget.searchQuery != _searchQuery) {
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
        feedMode: _feedMode,
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

  Future<void> _addServerFromSidebar() async {
    ForumServer? selectedServer;
    await ForumCarreraPickerDialog.show(
      context,
      onServerSelected: (server) {
        selectedServer = server;
        _onAddServer(server);
      },
    );
    if (!mounted) return;
    if (selectedServer != null) {
      _onSelectServer(selectedServer!);
      if (_scaffoldKey.currentState?.isDrawerOpen == true) {
        Navigator.of(context).pop();
      }
    }
  }

  void _onSelectServer(ForumServer server) {
    if (server.isGroups) return;
    if (!_servers.any((item) => item.id == server.id)) {
      _onAddServer(server);
    }
    if (_activeServer.id == server.id) return;
    setState(() {
      _activeServer = server;
      _searchQuery = '';
      _searchController.clear();
      if (server.isGroups) {
        final subChannels = ForumChannel.groupsChannelsForSubserver(
          server,
          _faculties,
        );
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
    if (newServer.isGroups) return;
    final exists = _servers.any((server) => server.id == newServer.id);
    if (!exists) {
      setState(() => _servers.add(newServer));
      ForumServerPreferencesService.save(_servers);
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
        subtitle:
            'Para valorar publicaciones útiles en la comunidad, debes iniciar sesión.',
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

    try {
      final success = await ForumService.toggleLike(post);
      if (mounted && success != !prevLiked) {
        setState(() {
          final idx = _posts.indexWhere((p) => p.id == post.id);
          if (idx != -1) {
            _posts[idx] = post.copyWith(
              isLikedByMe: prevLiked,
              likes: prevLikes,
            );
          }
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
        final idx = _posts.indexWhere((p) => p.id == post.id);
        if (idx != -1) {
          _posts[idx] = post.copyWith(isLikedByMe: prevLiked, likes: prevLikes);
        }
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

  Future<void> _handleToggleBookmark(Post post) async {
    if (SupabaseConfig.isConfigured && !SupabaseService.isAuthenticated) {
      AuthModal.show(
        context,
        title: 'Inicia Sesión para Guardar',
        subtitle:
            'Para guardar publicaciones importantes en tus marcadores, debes iniciar sesión.',
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
            content: Text(
              !prevBookmarked
                  ? 'Publicación guardada en marcadores.'
                  : 'Publicación eliminada de marcadores.',
            ),
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
        subtitle:
            'Para participar en las votaciones comunitarias, debes iniciar sesión.',
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

  Future<void> _sharePost(Post post) async {
    final shareText =
        '${post.title}\n\n${post.content}\n\n— ${post.authorAlias}';
    try {
      await SharePlus.instance.share(
        ShareParams(text: shareText, subject: post.title),
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: shareText));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir compartir. El texto se copió.'),
        ),
      );
    }
  }

  void _handleQuotePost(Post post) {
    if (SupabaseConfig.isConfigured && !SupabaseService.isAuthenticated) {
      AuthModal.show(
        context,
        title: 'Inicia Sesión para Citar',
        subtitle:
            'Para republicar o citar esta consulta en el foro, debes iniciar sesión.',
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
          : (_activeChannel.id == 'todos'
                ? 'todos'
                : _activeChannel.categoryId),
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
        subtitle:
            'Para participar y crear consultas en el foro estudiantil, debes iniciar sesión.',
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
      initialCategory: _activeChannel.id == 'todos'
          ? 'todos'
          : _activeChannel.categoryId,
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
    final isDesktopOrTablet = !Responsive.isMobile(context);
    final showRightSidebar = Responsive.isDesktop(context);

    final feedBg = theme.scaffoldBackgroundColor;

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
              onSelectServer: _onSelectServer,
              onAddServer: _onAddServer,
              showAddButton: false,
            ),

            // 2. Channel Sidebar (240px)
            ForumChannelSidebar(
              activeServer: _activeServer,
              activeChannel: currentChannel,
              channels: currentChannels,
              onSelectChannel: _onSelectChannel,
              onAddServer: _addServerFromSidebar,
              activeAlias: widget.activeAlias,
              onAliasChanged: widget.onAliasChanged,
              onToggleTheme: widget.onToggleTheme,
            ),

            // 3. Main Content: GroupsScreen if isGroups, otherwise Channel Feed
            if (isGroups)
              Expanded(
                child: GroupsScreen(
                  activeAlias: widget.activeAlias,
                  onAliasChanged: widget.onAliasChanged,
                  activeServerName: _activeServer.name,
                  activeFacultadId: _activeServer.facultadId,
                  activeCarreraId: _groupsActiveChannel.categoryId,
                  activeChannelName: _groupsActiveChannel.name,
                  activeChannelDescription: _groupsActiveChannel.description,
                  activeChannelIcon: _groupsActiveChannel.icon,
                  showFloatingActionButton: Responsive.isMobile(context),
                  floatingActionButtonHeroTag: 'forum_groups_screen_fab',
                ),
              )
            else
              Expanded(child: _buildFeedContainer(theme, isDark)),

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
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        width: 312,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ForumServerRail(
              servers: _servers,
              activeServer: _activeServer,
              onSelectServer: (srv) {
                _onSelectServer(srv);
                if (_scaffoldKey.currentState?.isDrawerOpen == true) {
                  Navigator.of(context).pop();
                }
              },
              onAddServer: _onAddServer,
              showAddButton: false,
            ),
            Expanded(
              child: Column(
                children: [
                  SizedBox(
                    height: 48,
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.search_rounded, size: 20),
                          tooltip: 'Buscar publicaciones',
                          onPressed: _openSearchFromDrawer,
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.local_fire_department_rounded,
                            size: 20,
                            color: Color(0xFFF59E0B),
                          ),
                          tooltip: 'Comunidades populares',
                          onPressed: _openPopularServersFromDrawer,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ForumChannelSidebar(
                      activeServer: _activeServer,
                      activeChannel: currentChannel,
                      channels: currentChannels,
                      onSelectChannel: _onSelectChannel,
                      onAddServer: _addServerFromSidebar,
                      activeAlias: widget.activeAlias,
                      onAliasChanged: widget.onAliasChanged,
                      onToggleTheme: widget.onToggleTheme,
                    ),
                  ),
                ],
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
              _buildMobileChannelHeader(theme),
            Expanded(
              child: isGroups
                  ? GroupsScreen(
                      activeAlias: widget.activeAlias,
                      onAliasChanged: widget.onAliasChanged,
                      activeServerName: _activeServer.name,
                      activeFacultadId: _activeServer.facultadId,
                      activeCarreraId: _groupsActiveChannel.categoryId,
                      activeChannelName: _groupsActiveChannel.name,
                      activeChannelDescription:
                          _groupsActiveChannel.description,
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
        color: isDark ? const Color(0xFF1C1C1C) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF303030) : const Color(0xFFE2E8F0),
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
          const Icon(Icons.chat, size: 18, color: Color(0xFF25D366)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _groupsActiveChannel.name,
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

  String _welcomeChannelTitle() {
    final serverName = _activeServer.name
        .replaceAll(RegExp(r'\s*\([^)]*\)'), '')
        .trim();
    return '$serverName · ${_activeChannel.name}';
  }

  Widget _buildMobileChannelHeader(ThemeData theme) {
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu, size: 22),
            tooltip: 'Canales y servidores',
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          Expanded(
            child: Text(
              _welcomeChannelTitle(),
              textAlign: TextAlign.center,
              maxLines: 3,
              softWrap: true,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ),
          if (!_activeChannel.isSpecial)
            IconButton(
              icon: const Icon(Icons.add, size: 22),
              tooltip: 'Crear publicación',
              onPressed: _openCreateDialog,
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }

  void _openSearchFromDrawer() {
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showSearchDialog();
    });
  }

  void _openPopularServersFromDrawer() {
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showPopularServersModal(context);
    });
  }

  void _showSearchDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text('Buscar en el foro'),
        content: TextField(
          controller: _searchController,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Buscar publicaciones...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Limpiar búsqueda',
                    onPressed: _searchController.clear,
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
          onSubmitted: (value) {
            Navigator.of(dialogContext).pop();
            setState(() => _searchQuery = value.trim());
            _loadPosts();
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              setState(() => _searchQuery = _searchController.text.trim());
              _loadPosts();
            },
            child: const Text('Buscar'),
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (ctx) {
        return SizedBox(
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
        );
      },
    );
  }

  Widget _buildFeedContainer(ThemeData theme, bool isDark) {
    return Column(
      children: [
        // Barra superior fija para todos los canales con bienvenida, buscador y botón de publicar
        _buildDiscordWelcomeHero(theme, isDark),

        // Filtro de muro (En Llamas / Recientes) y acceso a Reseñas de Secciones
        _buildFeedFilterBar(theme, isDark),

        if (_isOffline) ...[
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.amber.shade900.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.amber.shade700.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.wifi_off, size: 16, color: Colors.amber.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No se pudo actualizar el feed. Comprueba tu conexión.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _isLoading ? null : _loadPosts,
                  child: const Text('Reintentar'),
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

  Widget _buildFeedFilterBar(ThemeData theme, bool isDark) {
    if (_activeChannel.isSpecial) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF232428) : const Color(0xFFF1F5F9),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF202225) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ChoiceChip(
              avatar: Icon(
                Icons.local_fire_department,
                size: 16,
                color: _feedMode == FeedMode.hot
                    ? Colors.white
                    : (isDark
                          ? Colors.orange.shade300
                          : Colors.orange.shade700),
              ),
              label: const Text('En Llamas'),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: _feedMode == FeedMode.hot
                    ? FontWeight.bold
                    : FontWeight.normal,
                color: _feedMode == FeedMode.hot
                    ? Colors.white
                    : (isDark ? Colors.grey.shade300 : const Color(0xFF334155)),
              ),
              selected: _feedMode == FeedMode.hot,
              selectedColor: isDark
                  ? const Color(0xFFEA580C)
                  : const Color(0xFFF97316),
              backgroundColor: isDark ? const Color(0xFF2B2D31) : Colors.white,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              onSelected: (selected) {
                if (selected && _feedMode != FeedMode.hot) {
                  setState(() => _feedMode = FeedMode.hot);
                  _loadPosts();
                }
              },
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              avatar: Icon(
                Icons.schedule,
                size: 16,
                color: _feedMode == FeedMode.recent
                    ? Colors.white
                    : (isDark
                          ? Colors.blue.shade300
                          : Colors.blue.shade700),
              ),
              label: const Text('Recientes'),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: _feedMode == FeedMode.recent
                    ? FontWeight.bold
                    : FontWeight.normal,
                color: _feedMode == FeedMode.recent
                    ? Colors.white
                    : (isDark ? Colors.grey.shade300 : const Color(0xFF334155)),
              ),
              selected: _feedMode == FeedMode.recent,
              selectedColor: isDark
                  ? const Color(0xFF2563EB)
                  : const Color(0xFF3B82F6),
              backgroundColor: isDark ? const Color(0xFF2B2D31) : Colors.white,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              onSelected: (selected) {
                if (selected && _feedMode != FeedMode.recent) {
                  setState(() => _feedMode = FeedMode.recent);
                  _loadPosts();
                }
              },
            ),
            const SizedBox(width: 10),
            ActionChip(
              avatar: const Icon(Icons.rate_review_outlined, size: 16),
              label: const Text(
                'Reseñas de Secciones',
                style: TextStyle(fontSize: 12),
              ),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SeccionReviewsScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
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
                : 'No hay mensajes en ${_activeChannel.name}',
            description: _activeChannel.isSpecial
                ? 'Guarda consultas importantes del foro tocando el icono de marcador.'
                : 'Sé el primero en iniciar una conversación o formular una duda en este canal.',
          ),
        ],
      );
    }

    return Scrollbar(
      controller: _feedScrollController,
      child: ListView.builder(
        controller: _feedScrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
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
            onShare: () => _sharePost(post),
            onVotePoll: (pollId, optionId) => _handleVotePoll(pollId, optionId),
            onDelete: post.isMine
                ? () async {
                    final ok = await ProfileService.deletePost(post.id);
                    if (!mounted) return;
                    if (ok) {
                      _loadPosts();
                    }
                  }
                : null,
            onReport: (reason) async {
              final success = await ForumService.reportPost(
                postId: post.id,
                reason: reason,
              );
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    success
                        ? 'Gracias por tu reporte. Se ha enviado al equipo de moderación.'
                        : 'No se pudo enviar el reporte. Inténtalo de nuevo.',
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDiscordWelcomeHero(ThemeData theme, bool isDark) {
    final isDesktop = !Responsive.isMobile(context);

    if (isDesktop) {
      return Container(
        height: 56,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1C) : const Color(0xFFF8FAFC),
          border: Border(
            bottom: BorderSide(
              color: isDark ? const Color(0xFF303030) : const Color(0xFFE2E8F0),
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
                color: isDark
                    ? const Color(0xFF252525)
                    : const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                _activeChannel.icon,
                size: 16,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _welcomeChannelTitle(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    softWrap: true,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _activeChannel.description,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark
                          ? const Color(0xFFAAAAAA)
                          : const Color(0xFF64748B),
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
                    color: isDark
                        ? const Color(0xFFAAAAAA)
                        : Colors.grey.shade500,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 15,
                    color: isDark
                        ? const Color(0xFFAAAAAA)
                        : Colors.grey.shade500,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            Icons.clear,
                            size: 13,
                            color: isDark
                                ? const Color(0xFFAAAAAA)
                                : Colors.grey.shade500,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                            _loadPosts();
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 8,
                  ),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF252525) : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(
                      color: isDark
                          ? const Color(0xFF303030)
                          : const Color(0xFFCBD5E1),
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(
                      color: isDark
                          ? const Color(0xFF303030)
                          : const Color(0xFFCBD5E1),
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
              if (Responsive.isTablet(context))
                IconButton.filled(
                  onPressed: _openCreateDialog,
                  tooltip: 'Publicar',
                  icon: const Icon(Icons.add),
                )
              else
                SizedBox(
                  height: 32,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    icon: const Icon(Icons.add, size: 15),
                    label: const Text(
                      'Publicar',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed: _openCreateDialog,
                  ),
                ),
            ],
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
