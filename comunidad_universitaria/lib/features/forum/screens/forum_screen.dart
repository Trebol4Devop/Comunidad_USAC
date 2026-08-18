import 'package:flutter/material.dart';
import '../../../core/constants/categories.dart';
import '../../../core/models/post.dart';
import '../../../core/services/forum_service.dart';
import '../../../core/utils/responsive.dart';
import '../widgets/create_post_dialog.dart';
import '../widgets/post_card.dart';
import 'post_detail_screen.dart';
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
      carrera: _selectedCarrera,
      searchQuery: _searchQuery,
    );
    if (mounted) {
      setState(() {
        _posts = posts;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleToggleLike(Post post) async {
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

  void _openCreateDialog() {
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
                              'Foro Universitario USAC',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Comparte dudas sobre cátedras, laboratorios, horarios y material de estudio con toda la comunidad sancarlista.',
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
                    // Faculty Selector Dropdown
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: isDesktop ? 260 : 160),
                      child: DropdownButtonFormField<String>(
                        value: _selectedFacultad,
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

                const SizedBox(height: 12),

                // Category Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: USACConstants.forumCategories.map((cat) {
                      final isSelected = _selectedCategory == cat.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(cat.label),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
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
                    }).toList(),
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
                    title: 'No se encontraron publicaciones',
                    description: 'Sé el primero en iniciar una conversación o formular una duda en esta categoría.',
                    buttonText: 'Crear Primera Publicación',
                    onButtonPressed: _openCreateDialog,
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _posts.length,
                    itemBuilder: (ctx, i) {
                      final post = _posts[i];
                      return PostCard(
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
