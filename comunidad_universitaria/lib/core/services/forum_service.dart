import 'package:flutter/foundation.dart';
import '../config/supabase_config.dart';
import '../constants/categories.dart';
import '../models/post.dart';
import 'supabase_service.dart';

class ForumService {
  static Future<List<Post>> fetchPosts({
    String category = 'todos',
    String facultad = 'todas',
    String carrera = 'todas',
    String searchQuery = '',
    bool showOnlyBookmarks = false,
  }) async {
    if (!SupabaseConfig.isConfigured) return _getSamplePosts();

    try {
      final currentUserId = SupabaseService.currentUserId;

      if (showOnlyBookmarks) {
        if (currentUserId == null) return [];
        final bookmarksRes = await SupabaseService.client
            .from('post_bookmarks')
            .select('post_id')
            .eq('user_id', currentUserId)
            .order('created_at', ascending: false)
            .timeout(const Duration(seconds: 10));
        final bookmarkedIds = (bookmarksRes as List<dynamic>).map((e) => e['post_id'].toString()).toList();
        if (bookmarkedIds.isEmpty) return [];

        final postsRes = await SupabaseService.client
            .from('posts')
            .select('*, comments(count)')
            .inFilter('id', bookmarkedIds)
            .lt('moderation_status', 2)
            .timeout(const Duration(seconds: 10));
        final List<dynamic> data = postsRes as List<dynamic>;
        return _hydratePosts(data, currentUserId);
      }

      var query = SupabaseService.client
          .from('posts')
          .select('*, comments(count)')
          .lt('moderation_status', 2);

      if (category != 'todos') {
        query = query.eq('category', category);
      }

      if (carrera != 'todas') {
        query = query.eq('carrera', carrera);
      } else if (facultad != 'todas') {
        final fac = USACConstants.facultades.firstWhere(
          (f) => f['id'] == facultad,
          orElse: () => USACConstants.facultades.first,
        );
        final rawCarreras = fac['carreras'] as List<dynamic>? ?? [];
        final careerIds = rawCarreras.map((c) => c['id'].toString()).toSet()..add('todas');
        query = query.inFilter('carrera', careerIds.toList());
      }

      if (searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query.or('title.ilike.%$q%,content.ilike.%$q%');
      }

      final response = await query
          .order('is_pinned', ascending: false)
          .order('created_at', ascending: false)
          .limit(50)
          .timeout(const Duration(seconds: 10));
      final List<dynamic> data = response as List<dynamic>;

      return _hydratePosts(data, currentUserId);
    } catch (e) {
      debugPrint('Error al obtener posts del foro: $e');
      return _getSamplePosts();
    }
  }

  static Future<List<Post>> _hydratePosts(List<dynamic> data, String? currentUserId) async {
    if (data.isEmpty) return [];

    final postIds = data.map((item) => item['id'].toString()).toList();
    final Set<String> likedPostIds = {};
    final Set<String> bookmarkedPostIds = {};
    final Map<String, String> userVotesByPollId = {};
    final Map<String, PostPoll> pollsByPostId = {};
    final Map<String, Post> quotedPostsMap = {};

    // 1. Liked and Bookmarked sets
    if (currentUserId != null) {
      final likesRes = await SupabaseService.client
          .from('post_likes')
          .select('post_id')
          .eq('user_id', currentUserId)
          .inFilter('post_id', postIds);

      for (var item in likesRes) {
        likedPostIds.add(item['post_id'].toString());
      }

      final bookmarksRes = await SupabaseService.client
          .from('post_bookmarks')
          .select('post_id')
          .eq('user_id', currentUserId)
          .inFilter('post_id', postIds);

      for (var item in bookmarksRes) {
        bookmarkedPostIds.add(item['post_id'].toString());
      }
    }

    // 2. Polls for posts
    try {
      final pollsRes = await SupabaseService.client
          .from('post_polls')
          .select('*, post_poll_options(*)')
          .inFilter('post_id', postIds);

      final pollIds = (pollsRes as List<dynamic>).map((p) => p['id'].toString()).toList();

      if (currentUserId != null && pollIds.isNotEmpty) {
        final votesRes = await SupabaseService.client
            .from('post_poll_votes')
            .select('poll_id, option_id')
            .eq('user_id', currentUserId)
            .inFilter('poll_id', pollIds);

        for (var v in votesRes) {
          userVotesByPollId[v['poll_id'].toString()] = v['option_id'].toString();
        }
      }

      for (var p in pollsRes) {
        final pollId = p['id'].toString();
        final postId = p['post_id'].toString();
        final rawOptions = p['post_poll_options'] as List<dynamic>? ?? [];
        final options = rawOptions.map((o) => PollOption.fromMap(Map<String, dynamic>.from(o))).toList();
        // Sort options deterministically
        options.sort((a, b) => a.id.compareTo(b.id));

        pollsByPostId[postId] = PostPoll(
          id: pollId,
          postId: postId,
          question: p['question'] ?? '',
          options: options,
          myVotedOptionId: userVotesByPollId[pollId],
        );
      }
    } catch (e) {
      debugPrint('Error cargando encuestas: $e');
    }

    // 3. Quoted posts
    final quotedIds = data
        .map((item) => item['quoted_post_id']?.toString())
        .where((id) => id != null && id.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();

    if (quotedIds.isNotEmpty) {
      try {
        final quotedRes = await SupabaseService.client
            .from('posts')
            .select('*')
            .inFilter('id', quotedIds);

        for (var q in quotedRes) {
          final qPost = Post.fromMap(Map<String, dynamic>.from(q));
          quotedPostsMap[qPost.id] = qPost;
        }
      } catch (e) {
        debugPrint('Error cargando posts citados: $e');
      }
    }

    return data.map((item) {
      final map = Map<String, dynamic>.from(item);
      final postId = map['id'].toString();
      int commentCount = 0;
      if (map['comments'] is List && (map['comments'] as List).isNotEmpty) {
        final countObj = (map['comments'] as List).first;
        commentCount = countObj['count'] ?? 0;
      }

      final qId = map['quoted_post_id']?.toString();
      final quoted = (qId != null) ? quotedPostsMap[qId] : null;

      return Post.fromMap(
        map,
        isLikedByMe: likedPostIds.contains(postId),
        isBookmarkedByMe: bookmarkedPostIds.contains(postId),
        commentCount: commentCount,
        poll: pollsByPostId[postId],
        quotedPost: quoted,
      );
    }).toList();
  }

  static Future<bool> toggleLike(Post post) async {
    final currentUserId = SupabaseService.currentUserId;
    if (currentUserId == null || !SupabaseConfig.isConfigured) return !post.isLikedByMe;

    try {
      if (post.isLikedByMe) {
        await SupabaseService.client
            .from('post_likes')
            .delete()
            .eq('post_id', post.id)
            .eq('user_id', currentUserId);
        return false;
      } else {
        await SupabaseService.client.from('post_likes').insert({
          'post_id': post.id,
          'user_id': currentUserId,
        });
        return true;
      }
    } catch (e) {
      debugPrint('Error al procesar like: $e');
      return post.isLikedByMe;
    }
  }

  static Future<bool> toggleBookmark(Post post) async {
    final currentUserId = SupabaseService.currentUserId;
    if (currentUserId == null || !SupabaseConfig.isConfigured) return !post.isBookmarkedByMe;

    try {
      if (post.isBookmarkedByMe) {
        await SupabaseService.client
            .from('post_bookmarks')
            .delete()
            .eq('post_id', post.id)
            .eq('user_id', currentUserId);
        return false;
      } else {
        await SupabaseService.client.from('post_bookmarks').insert({
          'post_id': post.id,
          'user_id': currentUserId,
        });
        return true;
      }
    } catch (e) {
      debugPrint('Error al procesar marcador guardado: $e');
      return post.isBookmarkedByMe;
    }
  }

  static Future<bool> votePoll({
    required String pollId,
    required String optionId,
  }) async {
    final currentUserId = SupabaseService.currentUserId;
    if (currentUserId == null || !SupabaseConfig.isConfigured) return false;

    try {
      // Delete previous vote on this poll if any, then insert new vote
      await SupabaseService.client
          .from('post_poll_votes')
          .delete()
          .eq('poll_id', pollId)
          .eq('user_id', currentUserId);

      await SupabaseService.client.from('post_poll_votes').insert({
        'poll_id': pollId,
        'option_id': optionId,
        'user_id': currentUserId,
      });

      return true;
    } catch (e) {
      debugPrint('Error al votar en encuesta: $e');
      return false;
    }
  }

  static Future<Post?> createPost({
    required String title,
    required String content,
    required String category,
    required String carrera,
    required String authorAlias,
    String? imageUrl,
    String? gifUrl,
    String? quotedPostId,
    String? pollQuestion,
    List<String>? pollOptions,
  }) async {
    if (!SupabaseConfig.isConfigured) return null;

    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      throw Exception('Debes iniciar sesión para publicar en el foro estudiantil.');
    }

    try {
      final postMap = {
        'title': title.trim(),
        'content': content.trim(),
        'category': category,
        'carrera': carrera,
        'author_alias': authorAlias.trim(),
        'user_id': userId,
        'image_url': imageUrl?.trim().isEmpty == true ? null : imageUrl?.trim(),
        'gif_url': gifUrl?.trim().isEmpty == true ? null : gifUrl?.trim(),
        'quoted_post_id': quotedPostId,
        'likes': 0,
        'reposts_count': 0,
        'moderation_status': 0,
      };

      final res = await SupabaseService.client
          .from('posts')
          .insert(postMap)
          .select()
          .single();

      final createdPost = Post.fromMap(Map<String, dynamic>.from(res));

      // Create poll if provided
      if (pollQuestion != null &&
          pollQuestion.trim().isNotEmpty &&
          pollOptions != null &&
          pollOptions.length >= 2) {
        final pollRes = await SupabaseService.client
            .from('post_polls')
            .insert({
              'post_id': createdPost.id,
              'question': pollQuestion.trim(),
            })
            .select()
            .single();

        final pollId = pollRes['id'].toString();
        final optionsInserts = pollOptions
            .where((opt) => opt.trim().isNotEmpty)
            .map((opt) => {'poll_id': pollId, 'option_text': opt.trim()})
            .toList();

        if (optionsInserts.isNotEmpty) {
          await SupabaseService.client.from('post_poll_options').insert(optionsInserts);
        }
      }

      return createdPost;
    } catch (e) {
      debugPrint('Error al crear post: $e');
      rethrow;
    }
  }

  static Future<List<PostComment>> fetchCommentsTree(String postId) async {
    if (!SupabaseConfig.isConfigured) return _getSampleComments(postId);

    try {
      final response = await SupabaseService.client
          .from('comments')
          .select('*')
          .eq('post_id', postId)
          .lt('moderation_status', 2)
          .order('created_at', ascending: true)
          .timeout(const Duration(seconds: 10));

      final List<dynamic> data = response as List<dynamic>;
      final List<PostComment> allComments = data
          .map((item) => PostComment.fromMap(Map<String, dynamic>.from(item)))
          .toList();

      // Clear any pre-existing children references
      for (var c in allComments) {
        c.children = [];
      }

      // Build hierarchical tree with cycle and loop prevention
      final Map<String, PostComment> map = {};
      final List<PostComment> rootComments = [];

      for (var c in allComments) {
        map[c.id] = c;
      }

      bool hasCycle(String currentId, String targetParentId) {
        String? next = targetParentId;
        int hops = 0;
        final Set<String> visited = {currentId};
        while (next != null && hops < 15) {
          if (visited.contains(next)) return true;
          visited.add(next);
          next = map[next]?.parentId;
          hops++;
        }
        return false;
      }

      for (var c in allComments) {
        final pId = c.parentId;
        if (pId != null &&
            pId.trim().isNotEmpty &&
            map.containsKey(pId) &&
            pId != c.id &&
            !hasCycle(c.id, pId)) {
          map[pId]!.children.add(c);
        } else {
          rootComments.add(c);
        }
      }

      return rootComments;
    } catch (e) {
      debugPrint('Error al obtener comentarios: $e');
      return _getSampleComments(postId);
    }
  }

  static Future<PostComment?> addComment({
    required String postId,
    required String content,
    required String authorAlias,
    String? parentId,
    String? gifUrl,
  }) async {
    if (!SupabaseConfig.isConfigured) return null;

    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      throw Exception('Debes iniciar sesión para responder en el foro.');
    }

    try {
      final commentMap = {
        'post_id': postId,
        'content': content.trim(),
        'author_alias': authorAlias.trim(),
        'user_id': userId,
        'parent_id': (parentId != null && parentId.trim().isNotEmpty) ? parentId.trim() : null,
        'gif_url': gifUrl?.trim().isEmpty == true ? null : gifUrl?.trim(),
        'moderation_status': 0,
      };

      final res = await SupabaseService.client
          .from('comments')
          .insert(commentMap)
          .select()
          .single()
          .timeout(const Duration(seconds: 12));

      return PostComment.fromMap(Map<String, dynamic>.from(res));
    } catch (e) {
      debugPrint('Error al agregar comentario: $e');
      rethrow;
    }
  }

  static Future<bool> reportUser({
    required String reportedUserId,
    required String reportedAlias,
    required String reason,
  }) async {
    if (!SupabaseConfig.isConfigured) return true;
    try {
      await SupabaseService.client.from('user_reports').insert({
        'reporter_id': SupabaseService.currentUserId,
        'reported_user_id': reportedUserId,
        'reported_user_alias': reportedAlias,
        'reason': reason.trim(),
      });
      return true;
    } catch (e) {
      debugPrint('Error reportando usuario: $e');
      return false;
    }
  }

  static List<Post> _getSamplePosts() {
    return [
      Post(
        id: 'mock-1',
        title: '¿Recomendaciones para Catedrático de Matemática Básica 1 y 2?',
        category: 'catedraticos',
        carrera: 'area_comun',
        content: 'Hola compañeros, el próximo semestre llevo MB2. ¿Qué catedrático recomiendan que explique claro y dé buenas tareas preparatorias para los parciales?',
        authorAlias: 'Estudiante USAC #312',
        likes: 12,
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        commentCount: 4,
      ),
      Post(
        id: 'mock-2',
        title: 'Guías de laboratorio y resúmenes de Estructuras de Datos',
        category: 'apuntes',
        carrera: 'sistemas',
        content: 'Dejo este hilo para compartir apuntes sobre apuntadores, árboles AVL, grafos y memoria dinámica en C++.',
        authorAlias: 'Estudiante Sistemas #804',
        likes: 25,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        commentCount: 7,
      ),
    ];
  }

  static List<PostComment> _getSampleComments(String postId) {
    final parent = PostComment(
      id: 'c-1',
      postId: postId,
      authorAlias: 'Estudiante FIUSAC #901',
      content: 'El Ing. Morales explica muy bien la teoría y sus exámenes son justos si haces las tareas.',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    );
    parent.children.add(
      PostComment(
        id: 'c-2',
        postId: postId,
        parentId: 'c-1',
        authorAlias: 'Estudiante #312',
        content: '¡Muchas gracias por el dato! ¿Da puntos por asistencia?',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
    );
    return [parent];
  }
}
