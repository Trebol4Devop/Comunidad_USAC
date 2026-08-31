import 'package:flutter/material.dart';
import '../../../core/constants/categories.dart';
import '../../../core/models/post.dart';
import '../../../core/services/forum_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../widgets/create_post_dialog.dart';
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
  List<Post> _posts = [];
  bool _isLoading = true;
  bool _showOnlyBookmarks = false;
  String _selectedCategory = 'todos';
  String _selectedFacultad = 'todas';
  String _selectedCarrera = 'todas';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    setState(() => _isLoading = true);
    final posts = await ForumService.fetchPosts(
      category: _selectedCategory,
      facultad: _selectedFacultad,
      carrera: _selectedCarrera,
      searchQuery: _searchQuery,
      showOnlyBookmarks: _showOnlyBookmarks,
    );
    if (mounted) {
      setState(() {
        _posts = posts;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleToggleLike(Post post) async {
    if (!SupabaseService.isAuthenticated) {
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

    // Optimistic UI update
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
    if (!SupabaseService.isAuthenticated) {
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
        if (_showOnlyBookmarks && prevBookmarked) {
          _loadPosts();
        }
      }
    }
  }

  Future<void> _handleVotePoll(String pollId, String optionId) async {
    if (!SupabaseService.isAuthenticated) {
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

      // Update options optimistic counts
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
    if (!SupabaseService.isAuthenticated) {
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
      onAliasChanged: widget.onAliasChanged,
      onPostCreated: (newPost) {
        setState(() {
          _posts.insert(0, newPost);
        });
      },
    );
  }

  void _openCreateDialog() {
    if (!SupabaseService.isAuthenticated) {
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
      onAliasChanged: widget.onAliasChanged,
      onPostCreated: (newPost) {
        setState(() {
          _posts.insert(0, newPost);
        });
      },
    );
  }

  List<Map<String, dynamic>> get _availableCarreras {
    final fac = USACConstants.facultades.firstWhere(
      (f) => f['id'] == _selectedFacultad,
      orElse: () => USACConstants.facultades.first,
    );
    final list = fac['carreras'] as List<dynamic>? ?? [];
    return list.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = Responsive.isDesktop(context);
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadPosts,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: MaxWidthContainer(
            maxWidth: 1100,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Welcome / Action Banner
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF004B87), Color(0xFF0066CC)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Foro Estudiantil Universitario',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Espacio libre e independiente para consultas académicas sobre cátedras, laboratorios, horarios y apuntes.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isDesktop) ...[
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEAB308),
                            foregroundColor: Colors.black87,
                          ),
                          onPressed: _openCreateDialog,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Crear Consulta'),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Search & Filter controls
                if (isMobile) ...[
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar dudas, apuntes, cursos o catedráticos...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                                _loadPosts();
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    onSubmitted: (val) {
                      setState(() => _searchQuery = val);
                      _loadPosts();
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedFacultad,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Facultad / Unidad',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: USACConstants.facultades
                        .map((f) => DropdownMenuItem<String>(
                              value: f['id'].toString(),
                              child: Text(
                                f['nombre'].toString(),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ))
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedFacultad = val ?? 'todas';
                        _selectedCarrera = 'todas';
                      });
                      _loadPosts();
                    },
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Buscar dudas, apuntes, cursos o catedráticos...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                      _loadPosts();
                                    },
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          onSubmitted: (val) {
                            setState(() => _searchQuery = val);
                            _loadPosts();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 260),
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedFacultad,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                          items: USACConstants.facultades
                              .map((f) => DropdownMenuItem<String>(
                                    value: f['id'].toString(),
                                    child: Text(
                                      f['nombre'].toString(),
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedFacultad = val ?? 'todas';
                              _selectedCarrera = 'todas';
                            });
                            _loadPosts();
                          },
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 12),

                // Category Filter Chips & Bookmarks toggle
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Bookmarks Filter Chip
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          avatar: Icon(
                            _showOnlyBookmarks ? Icons.bookmark : Icons.bookmark_border,
                            size: 14,
                            color: _showOnlyBookmarks ? Colors.white : const Color(0xFFD97706),
                          ),
                          label: const Text('Guardados'),
                          selected: _showOnlyBookmarks,
                          selectedColor: const Color(0xFFD97706),
                          checkmarkColor: Colors.white,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: _showOnlyBookmarks ? FontWeight.bold : FontWeight.normal,
                            color: _showOnlyBookmarks ? Colors.white : const Color(0xFFD97706),
                          ),
                          onSelected: (selected) {
                            setState(() {
                              _showOnlyBookmarks = selected;
                            });
                            _loadPosts();
                          },
                        ),
                      ),
                      ...USACConstants.forumCategories.map((cat) {
                        final isSelected = !_showOnlyBookmarks && _selectedCategory == cat.id;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(cat.label),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                _showOnlyBookmarks = false;
                                _selectedCategory = cat.id;
                              });
                              _loadPosts();
                            },
                            selectedColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? theme.colorScheme.primary : null,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                // Career Filter chips if a specific faculty is chosen
                if (_selectedFacultad != 'todas' && _availableCarreras.length > 1) ...[
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _availableCarreras.map((car) {
                        final id = car['id'].toString();
                        final isSelected = _selectedCarrera == id;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(car['nombre'].toString()),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                _selectedCarrera = selected ? id : 'todas';
                              });
                              _loadPosts();
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Posts Feed
                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_posts.isEmpty)
                  EmptyStateWidget(
                    icon: Icons.forum_outlined,
                    title: _showOnlyBookmarks ? 'No tienes publicaciones guardadas' : 'No se encontraron publicaciones',
                    description: _showOnlyBookmarks
                        ? 'Guarda publicaciones importantes del foro tocando el icono de marcador.'
                        : 'Sé el primero en iniciar una conversación o formular una duda en esta categoría.',
                    buttonText: 'Crear Primera Publicación',
                    onButtonPressed: _openCreateDialog,
                  )
                else
                  Column(
                    children: _posts.map((post) {
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
                    }).toList(),
                  ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateDialog,
        backgroundColor: const Color(0xFF004B87),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_comment),
        label: const Text('Nueva Consulta'),
      ),
    );
  }
}
