import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/constants/zanate_colors.dart';
import '../../../core/models/post.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/services/forum_service.dart';
import '../../../core/services/share_count_service.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/services/forum_server_preferences_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../models/discord_forum_models.dart';
import '../widgets/create_post_dialog.dart';
import '../widgets/discord/forum_channel_sidebar.dart';
import '../widgets/discord/forum_carrera_picker_dialog.dart';
import '../widgets/discord/forum_server_rail.dart';
import '../widgets/post_card.dart';
import 'post_detail_screen.dart';
import '../../groups/screens/groups_screen.dart';
import '../../../core/services/profile_service.dart';
import '../../shared/widgets/auth_modal.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../../shared/widgets/network_state_widgets.dart';

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

  // Data & Search States
  List<Post> _posts = [];
  bool _isLoading = true;
  bool _isOffline = false;
  UserProfile? _currentUserProfile;
  String _searchQuery = '';
  FeedMode _feedMode = FeedMode.hot;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _feedScrollController = ScrollController();
  Timer? _searchDebounce;

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
    _searchQuery = widget.searchQuery;
    if (_searchQuery.isNotEmpty) {
      _searchController.text = _searchQuery;
    }
    _loadUserProfile();
    _loadForumStructure();
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
    _searchDebounce?.cancel();
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

      await ShareCountService.preload(posts.map((p) => p.id).toList());
      final enrichedPosts = posts.map((p) {
        final count = ShareCountService.getCachedCount(p.id);
        return count > p.sharesCount ? p.copyWith(sharesCount: count) : p;
      }).toList();

      if (mounted) {
        setState(() {
          _posts = enrichedPosts;
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
    final newCount = post.sharesCount + 1;
    setState(() {
      final idx = _posts.indexWhere((p) => p.id == post.id);
      if (idx != -1) {
        _posts[idx] = _posts[idx].copyWith(sharesCount: newCount);
      }
    });

    await ShareCountService.incrementShare(post.id);

    final shareText =
        '${post.title}\n\n${post.content}\n\n— ${post.authorAlias} (Comunidad USAC)';
    try {
      await SharePlus.instance.share(
        ShareParams(text: shareText, subject: post.title),
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

  void _handleQuotePost(Post post) {
    if (SupabaseConfig.isConfigured && !SupabaseService.isAuthenticated) {
      AuthModal.show(
        context,
        title: 'Inicia Sesión para Repostear',
        subtitle:
            'Para repostear o citar esta consulta en el foro, debes iniciar sesión.',
        onAuthenticated: () => _handleQuotePost(post),
      );
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = ZanateColors.textPrimary(isDark);
    final subtleColor = ZanateColors.textMuted(isDark);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ZanateColors.bg(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: ZanateColors.border(isDark),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: ZanateColors.zanateEyeYellow.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: PhosphorIcon(
                      PhosphorIconsBold.arrowsClockwise,
                      size: 20,
                      color: isDark
                          ? ZanateColors.zanateEyeYellow
                          : ZanateColors.zanateBlack,
                    ),
                  ),
                ),
                title: Text(
                  'Repostear ahora',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: primaryColor,
                  ),
                ),
                subtitle: Text(
                  'Comparte esta publicación en el foro al instante',
                  style: TextStyle(fontSize: 12, color: subtleColor),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _performDirectRepost(post);
                },
              ),
              const SizedBox(height: 4),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: ZanateColors.surface(isDark),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: PhosphorIcon(
                      PhosphorIconsRegular.quotes,
                      size: 20,
                      color: primaryColor,
                    ),
                  ),
                ),
                title: Text(
                  'Citar publicación',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: primaryColor,
                  ),
                ),
                subtitle: Text(
                  'Agrega tu comentario o punto de vista',
                  style: TextStyle(fontSize: 12, color: subtleColor),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _openQuoteDialog(post);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _performDirectRepost(Post post) async {
    try {
      final profile = await LocalStorageService.getUserProfile();
      final effectiveAlias = profile.alias.trim().isNotEmpty
          ? profile.alias.trim()
          : widget.activeAlias;
      final created = await ForumService.createPost(
        title: 'Repost: ${post.title}',
        content: post.content.isNotEmpty ? post.content : post.title,
        category: post.category,
        carrera: post.carrera,
        authorAlias: effectiveAlias,
        quotedPostId: post.id,
      );
      if (!mounted) return;
      if (created != null) {
        setState(() {
          final idx = _posts.indexWhere((p) => p.id == post.id);
          if (idx != -1) {
            _posts[idx] = _posts[idx].copyWith(
              repostsCount: _posts[idx].repostsCount + 1,
            );
          }
          _posts.insert(0, created.copyWith(quotedPost: post));
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Publicación reposteada en el foro.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo repostear: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openQuoteDialog(Post post) async {
    final profile = await LocalStorageService.getUserProfile();
    if (!mounted) return;
    final effectiveAlias = profile.alias.trim().isNotEmpty
        ? profile.alias.trim()
        : widget.activeAlias;
    CreatePostDialog.show(
      context,
      activeAlias: effectiveAlias,
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
          final idx = _posts.indexWhere((p) => p.id == post.id);
          if (idx != -1) {
            _posts[idx] = _posts[idx].copyWith(
              repostsCount: _posts[idx].repostsCount + 1,
            );
          }
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

  Future<void> _showCreateDialog() async {
    if (_activeChannel.isSpecial) return;
    final profile = await LocalStorageService.getUserProfile();
    if (!mounted) return;
    final effectiveAlias = profile.alias.trim().isNotEmpty
        ? profile.alias.trim()
        : widget.activeAlias;
    CreatePostDialog.show(
      context,
      activeAlias: effectiveAlias,
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

    final feedBg = ZanateColors.bg(isDark);

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
            // 1. Server Rail (68px)
            ForumServerRail(
              servers: _servers,
              activeServer: _activeServer,
              onSelectServer: _onSelectServer,
              onAddServer: _onAddServer,
              showAddButton: false,
            ),

            // 2. Channel Sidebar (244px)
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

            // 4. Barra lateral derecha eliminada: el filtro "En Llamas" ya cubre lo popular.
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
              child: SafeArea(
                left: false,
                right: false,
                bottom: false,
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
    final titleColor = ZanateColors.textPrimary(isDark);
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: ZanateColors.card(isDark),
        border: Border(
          bottom: BorderSide(
            color: ZanateColors.border(isDark),
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            icon: PhosphorIcon(
              PhosphorIconsRegular.list,
              size: 22,
              color: titleColor,
            ),
            tooltip: 'Menú de canales',
            splashRadius: 22,
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: ZanateColors.zanateEyeYellow.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(8),
            ),
            child: PhosphorIcon(
              PhosphorIconsFill.usersThree,
              size: 16,
              color: isDark ? ZanateColors.zanateEyeYellow : ZanateColors.zanateBlack,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _groupsActiveChannel.name,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w700,
                fontSize: 15.5,
                color: titleColor,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: ZanateColors.zanateEyeYellow,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'GRUPOS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: ZanateColors.zanateBlack,
              ),
            ),
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
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = ZanateColors.textPrimary(isDark);
    final serverName = _activeServer.name
        .replaceAll(RegExp(r'\s*\([^)]*\)'), '')
        .trim()
        .toUpperCase();
    final channelName = _activeChannel.name.replaceAll('#', '').trim();

    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ZanateColors.card(isDark),
        border: Border(
          bottom: BorderSide(
            color: ZanateColors.border(isDark),
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            icon: PhosphorIcon(
              PhosphorIconsRegular.list,
              size: 23,
              color: titleColor,
            ),
            tooltip: 'Menú de canales',
            splashRadius: 22,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  serverName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: ZanateColors.textMuted(isDark),
                  ),
                ),
                const SizedBox(height: 1),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '#',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        channelName,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          color: titleColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          if (!_activeChannel.isSpecial)
            IconButton(
              onPressed: _openCreateDialog,
              icon: PhosphorIcon(
                PhosphorIconsBold.plus,
                size: 22,
                color: titleColor,
              ),
              tooltip: 'Nueva consulta',
              splashRadius: 22,
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }

  void _onSearchChanged(String val) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final trimmed = val.trim();
      if (trimmed == _searchQuery) return;
      setState(() => _searchQuery = trimmed);
      _loadPosts();
    });
  }

  void _submitSearch(String val) {
    _searchDebounce?.cancel();
    setState(() => _searchQuery = val.trim());
    _loadPosts();
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() => _searchQuery = '');
    _loadPosts();
  }

  Widget _buildSearchField(bool isDark, {required bool isDesktop}) {
    final borderColor = ZanateColors.border(isDark);
    final hasQuery =
        _searchController.text.isNotEmpty || _searchQuery.isNotEmpty;

    return TextField(
      controller: _searchController,
      textInputAction: TextInputAction.search,
      onChanged: _onSearchChanged,
      onSubmitted: _submitSearch,
      style: TextStyle(
        fontSize: isDesktop ? 13 : 13.5,
        color: ZanateColors.textPrimary(isDark),
      ),
      decoration: InputDecoration(
        hintText: isDesktop ? 'Buscar...' : 'Buscar publicaciones...',
        hintStyle: TextStyle(
          fontSize: isDesktop ? 12.5 : 13,
          color: ZanateColors.textMuted(isDark),
        ),
        prefixIcon: PhosphorIcon(
          PhosphorIconsRegular.magnifyingGlass,
          size: isDesktop ? 16 : 17,
          color: ZanateColors.textMuted(isDark),
        ),
        suffixIcon: hasQuery
            ? IconButton(
                tooltip: 'Limpiar búsqueda',
                padding: EdgeInsets.zero,
                icon: PhosphorIcon(
                  PhosphorIconsRegular.x,
                  size: isDesktop ? 14 : 15,
                  color: ZanateColors.textMuted(isDark),
                ),
                onPressed: _clearSearch,
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 0,
          horizontal: 10,
        ),
        filled: true,
        fillColor: ZanateColors.surface(isDark),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: ZanateColors.focusBorder(isDark),
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildFeedContainer(ThemeData theme, bool isDark) {
    return Column(
      children: [
        // Barra superior fija para todos los canales con bienvenida, buscador y botón de publicar
        _buildDiscordWelcomeHero(theme, isDark),

        // Filtro de muro (En Llamas / Recientes)
        _buildFeedFilterBar(theme, isDark),

        if (_isOffline)
          OfflineBanner(
            message: 'No se pudo actualizar el feed. Comprueba tu conexión.',
            onRetry: _isLoading ? null : _loadPosts,
          ),

        // Área scrolleable de publicaciones con scrollbar dedicada y física estándar
        Expanded(
          child: RefreshIndicator(
            color: ZanateColors.focusBorder(isDark),
            backgroundColor: ZanateColors.card(isDark),
            onRefresh: _loadPosts,
            child: _buildPostsFeed(theme, isDark),
          ),
        ),
      ],
    );
  }

  Widget _buildFeedFilterBar(ThemeData theme, bool isDark) {
    if (_activeChannel.isSpecial) return const SizedBox.shrink();

    final isMobile = Responsive.isMobile(context);
    final isHot = _feedMode == FeedMode.hot;
    final isRecent = _feedMode == FeedMode.recent;
    const activeBg = ZanateColors.zanateEyeYellow;
    final inactiveBg = ZanateColors.pill(isDark);
    final inactiveText = ZanateColors.textMuted(isDark);
    final borderColor = ZanateColors.border(isDark);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(14, isMobile ? 8 : 10, 14, 10),
      decoration: BoxDecoration(
        color: ZanateColors.card(isDark),
        border: Border(
          bottom: BorderSide(color: borderColor, width: 1.0),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Chip "En Llamas"
            GestureDetector(
              onTap: () {
                if (!isHot) {
                  setState(() => _feedMode = FeedMode.hot);
                  _loadPosts();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isHot ? activeBg : inactiveBg,
                  borderRadius: BorderRadius.circular(12),
                  border: isHot
                      ? null
                      : Border.all(color: borderColor, width: 1.0),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PhosphorIcon(
                      PhosphorIconsFill.flame,
                      size: 16,
                      color: isHot
                          ? ZanateColors.zanateBlack
                          : inactiveText,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'En Llamas',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: isHot ? FontWeight.w700 : FontWeight.w600,
                        color: isHot ? ZanateColors.zanateBlack : inactiveText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Chip "Recientes"
            GestureDetector(
              onTap: () {
                if (!isRecent) {
                  setState(() => _feedMode = FeedMode.recent);
                  _loadPosts();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isRecent ? activeBg : inactiveBg,
                  borderRadius: BorderRadius.circular(12),
                  border: isRecent
                      ? null
                      : Border.all(color: borderColor, width: 1.0),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PhosphorIcon(
                      PhosphorIconsFill.clock,
                      size: 16,
                      color: isRecent
                          ? ZanateColors.zanateBlack
                          : inactiveText,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Recientes',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight:
                            isRecent ? FontWeight.w700 : FontWeight.w600,
                        color:
                            isRecent ? ZanateColors.zanateBlack : inactiveText,
                      ),
                    ),
                  ],
                ),
              ),
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
            icon: _activeChannel.isSpecial
                ? PhosphorIconsRegular.bookmarkSimple
                : null,
            title: _activeChannel.isSpecial
                ? 'No tienes publicaciones guardadas'
                : 'No hay mensajes en ${_activeChannel.name}',
            description: _activeChannel.isSpecial
                ? 'Guarda consultas importantes del foro tocando el icono de marcador.'
                : 'Sé el primero en formular una consulta o compartir información en este canal.',
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
      final borderColor = ZanateColors.border(isDark);

      return Container(
        constraints: const BoxConstraints(minHeight: 62),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: ZanateColors.card(isDark),
          border: Border(
            bottom: BorderSide(color: borderColor, width: 1.0),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: ZanateColors.surface(isDark),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor, width: 1.0),
              ),
              child: Center(
                child: Icon(
                  _activeChannel.icon,
                  size: 18,
                  color: isDark
                      ? ZanateColors.zanateEyeYellow
                      : ZanateColors.zanateBlack,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _welcomeChannelTitle(),
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                      letterSpacing: -0.2,
                      color: isDark ? Colors.white : ZanateColors.zanateBlack,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    _activeChannel.description,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : ZanateColors.mutedText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: SizedBox(
                  height: 38,
                  child: _buildSearchField(isDark, isDesktop: true),
                ),
              ),
            ),
            if (!_activeChannel.isSpecial) ...[
              const SizedBox(width: 10),
              IconButton(
                tooltip: 'Nueva publicación',
                style: IconButton.styleFrom(
                  backgroundColor: isDark
                      ? ZanateColors.zanateEyeYellow
                      : ZanateColors.zanateBlack,
                  foregroundColor:
                      isDark ? ZanateColors.zanateBlack : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const PhosphorIcon(
                  PhosphorIconsBold.plus,
                  size: 18,
                ),
                onPressed: _openCreateDialog,
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        14,
        10,
        14,
        _activeChannel.isSpecial ? 10 : 2,
      ),
      decoration: BoxDecoration(
        color: ZanateColors.card(isDark),
        border: _activeChannel.isSpecial
            ? Border(
                bottom: BorderSide(
                  color: ZanateColors.border(isDark),
                  width: 1.0,
                ),
              )
            : null,
      ),
      child: SizedBox(
        height: 40,
        child: _buildSearchField(isDark, isDesktop: false),
      ),
    );
  }
}
