import 'package:flutter/material.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/models/post.dart';
import '../../../core/services/forum_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
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

  const ForumScreen({
    super.key,
    required this.activeAlias,
    required this.onAliasChanged,
  });

  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late List<ForumServer> _servers;
  late ForumServer _activeServer;
  late ForumChannel _activeChannel;

  List<Post> _posts = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _showMobileSearch = false;

  @override
  void initState() {
    super.initState();
    _servers = List.from(ForumServer.defaultServers);
    _activeServer = _servers.length > 2 ? _servers[2] : _servers.first;
    _activeChannel = ForumChannel.defaultChannels.first;
    _loadPosts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    setState(() => _isLoading = true);

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
      });
    }
  }

  void _onSelectServer(ForumServer server) {
    if (_activeServer.id == server.id) return;
    setState(() {
      _activeServer = server;
      _searchQuery = '';
      _searchController.clear();
      _showMobileSearch = false;
    });
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
      _showMobileSearch = false;
    });
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
        subtitle: 'Para valorar publicaciones útiles en el foro, debes iniciar sesión.',
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
        subtitle: 'Para participar en las votaciones estudiantiles, debes iniciar sesión.',
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = Responsive.isDesktop(context) || MediaQuery.of(context).size.width >= 800;
    final isDark = theme.brightness == Brightness.dark;

    final feedBg = isDark ? const Color(0xFF313338) : Colors.white;

    if (!isDesktop) {
      return _buildMobileScaffold(theme, isDark, feedBg);
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: feedBg,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Left Discord Server Rail (Carreras)
          ForumServerRail(
            servers: _servers,
            activeServer: _activeServer,
            onSelectServer: _onSelectServer,
            onAddServer: _onAddServer,
          ),

          // 2. Channels Sidebar (Categorías)
          ForumChannelSidebar(
            activeServer: _activeServer,
            activeChannel: _activeChannel,
            onSelectChannel: _onSelectChannel,
            onServerChanged: _onSelectServer,
            activeAlias: widget.activeAlias,
            onAliasChanged: widget.onAliasChanged,
          ),

          // 3. Main Channel Feed
          Expanded(
            child: Container(
              color: feedBg,
              child: Column(
                children: [
                  _buildDesktopChannelHeader(theme, isDark),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _loadPosts,
                      child: _buildFeedContent(theme, isDark),
                    ),
                  ),
                ],
              ),
            ),
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
        width: 312,
        child: Row(
          children: [
            ForumServerRail(
              servers: _servers,
              activeServer: _activeServer,
              onSelectServer: (s) {
                _onSelectServer(s);
              },
              onAddServer: _onAddServer,
            ),
            Expanded(
              child: ForumChannelSidebar(
                activeServer: _activeServer,
                activeChannel: _activeChannel,
                onSelectChannel: _onSelectChannel,
                onServerChanged: (s) {
                  _onSelectServer(s);
                },
                activeAlias: widget.activeAlias,
                onAliasChanged: widget.onAliasChanged,
              ),
            ),
          ],
        ),
      ),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Ver Carreras y Canales',
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        titleSpacing: 0,
        title: _showMobileSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Buscar en #${_activeChannel.name}...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                ),
                onSubmitted: (val) {
                  setState(() => _searchQuery = val);
                  _loadPosts();
                },
              )
            : Row(
                children: [
                  Icon(_activeChannel.icon, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '#${_activeChannel.name}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: _activeServer.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _activeServer.shortCode,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: _activeServer.color,
                      ),
                    ),
                  ),
                ],
              ),
        actions: [
          IconButton(
            icon: Icon(_showMobileSearch ? Icons.close : Icons.search, size: 20),
            onPressed: () {
              setState(() {
                if (_showMobileSearch && _searchQuery.isNotEmpty) {
                  _searchController.clear();
                  _searchQuery = '';
                  _loadPosts();
                }
                _showMobileSearch = !_showMobileSearch;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_circle, color: Color(0xFF004B87), size: 24),
            tooltip: 'Crear publicación',
            onPressed: _openCreateDialog,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadPosts,
        child: _buildFeedContent(theme, isDark),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateDialog,
        backgroundColor: const Color(0xFF004B87),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_comment, size: 20),
        label: Text('Publicar en #${_activeChannel.name}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildDesktopChannelHeader(ThemeData theme, bool isDark) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF313338) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF202225) : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(_activeChannel.icon, size: 20, color: Colors.grey.shade400),
          const SizedBox(width: 8),
          Text(
            _activeChannel.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(width: 12),
          Container(
            height: 20,
            width: 1,
            color: isDark ? const Color(0xFF3F4147) : Colors.grey.shade300,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _activeServer.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_activeServer.icon, size: 13, color: _activeServer.color),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _activeServer.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _activeServer.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _activeChannel.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF949BA4) : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 160,
            height: 32,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar...',
                hintStyle: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF949BA4) : Colors.grey.shade500),
                prefixIcon: const Icon(Icons.search, size: 15),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 13),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                          _loadPosts();
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E1F22) : const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (val) {
                setState(() => _searchQuery = val);
                _loadPosts();
              },
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF004B87),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.add, size: 15),
            label: const Text('Publicar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            onPressed: _openCreateDialog,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        _buildDiscordWelcomeHero(theme, isDark),
        const SizedBox(height: 16),
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
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PostDetailScreen(
                      initialPost: post,
                      activeAlias: widget.activeAlias,
                    ),
                  ),
                );
                _loadPosts();
              },
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2B2D31) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF383A40) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF3F4147) : Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Icon(_activeChannel.icon, size: 24, color: isDark ? Colors.white : const Color(0xFF004B87)),
          ),
          const SizedBox(height: 12),
          Text(
            '¡Te damos la bienvenida a #${_activeChannel.name}!',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 4),
          Text(
            'Este es el inicio del canal #${_activeChannel.name} en el servidor de ${_activeServer.name}. ${_activeChannel.description}',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: isDark ? const Color(0xFF949BA4) : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}
