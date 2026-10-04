import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/forum/models/discord_forum_models.dart';
import '../config/supabase_config.dart';
import '../constants/categories.dart';
import '../models/post.dart';
import 'cache_service.dart';
import 'supabase_service.dart';

class ForumService {
  static const String _cacheNamespace = 'forum_posts';

  static Future<List<Post>> fetchPosts({
    String category = 'todos',
    String facultad = 'todas',
    String carrera = 'todas',
    String searchQuery = '',
    bool showOnlyBookmarks = false,
  }) async {
    final isDefaultQuery = category == 'todos' &&
        facultad == 'todas' &&
        carrera == 'todas' &&
        searchQuery.trim().isEmpty &&
        !showOnlyBookmarks;
    final cacheKey = CacheService.buildKey({
      'user': SupabaseService.currentUserId ?? 'anon',
      'category': category,
      'facultad': facultad,
      'carrera': carrera,
      'search': searchQuery.trim().toLowerCase(),
      'bookmarks': showOnlyBookmarks,
    });

    final cached = CacheService.get<List<Post>>(_cacheNamespace, cacheKey);
    if (cached != null) return List<Post>.from(cached);

    if (!SupabaseConfig.isConfigured) {
      throw Exception('La aplicación no está conectada a la base de datos.');
    }

    if (isDefaultQuery) {
      final persisted = await _readPersistedPosts(cacheKey);
      if (persisted != null) return persisted;
    }

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
            .from('v_public_posts')
            .select('*')
            .inFilter('id', bookmarkedIds)
            .timeout(const Duration(seconds: 10));
        final List<dynamic> data = postsRes as List<dynamic>;
        final posts = await _hydratePosts(data, currentUserId);
        CacheService.set(_cacheNamespace, cacheKey, List<Post>.from(posts));
        return posts;
      }

      var query = SupabaseService.client
          .from('v_public_posts')
          .select('*');

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
      final posts = await _hydratePosts(data, currentUserId);

      CacheService.set(_cacheNamespace, cacheKey, List<Post>.from(posts));
      if (isDefaultQuery) {
        await CacheService.setPersisted(
          _cacheNamespace,
          cacheKey,
          posts.map(_postToCacheMap).toList(),
        );
      }
      return posts;
    } catch (e) {
      if (e is PostgrestException && (e.code == '42501' || e.message.contains('generate_author_hash'))) {
        try {
          var fallbackQuery = SupabaseService.client
              .from('posts')
              .select('id, title, category, content, author_alias, author_hash, likes, carrera, image_url, gif_url, is_pinned, quoted_post_id, created_at, moderation_status')
              .neq('moderation_status', 2);

          if (category != 'todos') {
            fallbackQuery = fallbackQuery.eq('category', category);
          }

          if (carrera != 'todas') {
            fallbackQuery = fallbackQuery.eq('carrera', carrera);
          } else if (facultad != 'todas') {
            final fac = USACConstants.facultades.firstWhere(
              (f) => f['id'] == facultad,
              orElse: () => USACConstants.facultades.first,
            );
            final rawCarreras = fac['carreras'] as List<dynamic>? ?? [];
            final careerIds = rawCarreras.map((c) => c['id'].toString()).toSet()..add('todas');
            fallbackQuery = fallbackQuery.inFilter('carrera', careerIds.toList());
          }

          if (searchQuery.trim().isNotEmpty) {
            final q = searchQuery.trim();
            fallbackQuery = fallbackQuery.or('title.ilike.%$q%,content.ilike.%$q%');
          }

          final response = await fallbackQuery
              .order('is_pinned', ascending: false)
              .order('created_at', ascending: false)
              .limit(50)
              .timeout(const Duration(seconds: 10));
          final List<dynamic> data = response as List<dynamic>;
          final posts = await _hydratePosts(data, SupabaseService.currentUserId);

          CacheService.set(_cacheNamespace, cacheKey, List<Post>.from(posts));
          return posts;
        } catch (innerError) {
          debugPrint('Error en fallback directo a tabla posts: $innerError');
        }
      }
      debugPrint('Error al obtener posts del foro: $e');
      if (isDefaultQuery) {
        final persisted = await _readPersistedPosts(cacheKey);
        if (persisted != null) return persisted;
      }
      rethrow;
    }
  }

  /// Lee la primera página persistida (solo consultas por defecto).
  static Future<List<Post>?> _readPersistedPosts(String cacheKey) {
    return CacheService.getPersisted<List<Post>>(
      _cacheNamespace,
      cacheKey,
      (data) {
        if (data is! List) throw const FormatException('Caché de posts inválida');
        return data
            .whereType<Map>()
            .map((item) => _postFromCacheMap(Map<String, dynamic>.from(item)))
            .toList();
      },
    );
  }

  static Map<String, dynamic> _postToCacheMap(Post post) {
    return {
      'id': post.id,
      'title': post.title,
      'category': post.category,
      'content': post.content,
      'author_alias': post.authorAlias,
      'likes': post.likes,
      'user_id': post.userId,
      'author_hash': post.authorHash,
      'created_at': post.createdAt.toIso8601String(),
      'carrera': post.carrera,
      'image_url': post.imageUrl,
      'gif_url': post.gifUrl,
      'quoted_post_id': post.quotedPostId,
      'reposts_count': post.repostsCount,
      'is_pinned': post.isPinned,
      'moderation_status': post.moderationStatus,
      'is_my_post': post.isMyPost,
      'comment_count': post.commentCount,
      'cache_liked': post.isLikedByMe,
      'cache_bookmarked': post.isBookmarkedByMe,
      'cache_poll': post.poll == null ? null : _pollToCacheMap(post.poll!),
      'cache_quoted_post': post.quotedPost == null ? null : _postToCacheMap(post.quotedPost!),
    };
  }

  static Post _postFromCacheMap(Map<String, dynamic> map) {
    final rawPoll = map['cache_poll'];
    final rawQuoted = map['cache_quoted_post'];
    return Post.fromMap(
      map,
      isLikedByMe: map['cache_liked'] == true,
      isBookmarkedByMe: map['cache_bookmarked'] == true,
      poll: rawPoll is Map ? _pollFromCacheMap(Map<String, dynamic>.from(rawPoll)) : null,
      quotedPost:
          rawQuoted is Map ? _postFromCacheMap(Map<String, dynamic>.from(rawQuoted)) : null,
    );
  }

  static Map<String, dynamic> _pollToCacheMap(PostPoll poll) {
    return {
      'id': poll.id,
      'post_id': poll.postId,
      'question': poll.question,
      'my_voted_option_id': poll.myVotedOptionId,
      'options': poll.options.map((option) => option.toMap()).toList(),
    };
  }

  static PostPoll _pollFromCacheMap(Map<String, dynamic> map) {
    return PostPoll.fromMap(
      {...map, 'options': map['options'] ?? const []},
      myVotedOptionId: map['my_voted_option_id']?.toString(),
    );
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
            .from('v_public_posts')
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
    if (!SupabaseConfig.isConfigured) {
      throw Exception('La aplicación no está conectada a la base de datos.');
    }
    final currentUserId = SupabaseService.currentUserId;
    if (currentUserId == null) return post.isLikedByMe;

    try {
      if (post.isLikedByMe) {
        await SupabaseService.client
            .from('post_likes')
            .delete()
            .eq('post_id', post.id)
            .eq('user_id', currentUserId);
        await CacheService.invalidateAll(_cacheNamespace);
        return false;
      } else {
        await SupabaseService.client.from('post_likes').insert({
          'post_id': post.id,
          'user_id': currentUserId,
        });
        await CacheService.invalidateAll(_cacheNamespace);
        return true;
      }
    } catch (e) {
      debugPrint('Error al procesar like: $e');
      return post.isLikedByMe;
    }
  }

  static Future<bool> toggleBookmark(Post post) async {
    if (!SupabaseConfig.isConfigured) {
      throw Exception('La aplicación no está conectada a la base de datos.');
    }
    final currentUserId = SupabaseService.currentUserId;
    if (currentUserId == null) return post.isBookmarkedByMe;

    try {
      if (post.isBookmarkedByMe) {
        await SupabaseService.client
            .from('post_bookmarks')
            .delete()
            .eq('post_id', post.id)
            .eq('user_id', currentUserId);
        await CacheService.invalidateAll(_cacheNamespace);
        return false;
      } else {
        await SupabaseService.client.from('post_bookmarks').insert({
          'post_id': post.id,
          'user_id': currentUserId,
        });
        await CacheService.invalidateAll(_cacheNamespace);
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
    if (!SupabaseConfig.isConfigured) {
      throw Exception('La aplicación no está conectada a la base de datos.');
    }
    final currentUserId = SupabaseService.currentUserId;
    if (currentUserId == null) return false;

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

      await CacheService.invalidateAll(_cacheNamespace);
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
    if (!SupabaseConfig.isConfigured) {
      throw Exception('La aplicación no está conectada a la base de datos.');
    }

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
          .select('id, title, category, content, author_alias, author_hash, likes, carrera, image_url, gif_url, is_pinned, quoted_post_id, reposts_count, moderation_status, created_at')
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

      await CacheService.invalidateAll(_cacheNamespace);
      return createdPost;
    } catch (e) {
      debugPrint('Error al crear post: $e');
      rethrow;
    }
  }

  static Future<List<PostComment>> fetchCommentsTree(String postId) async {
    if (!SupabaseConfig.isConfigured) {
      throw Exception('La aplicación no está conectada a la base de datos.');
    }

    try {
      final response = await SupabaseService.client
          .from('v_public_comments')
          .select('*')
          .eq('post_id', postId)
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
      if (e is PostgrestException && (e.code == '42501' || e.message.contains('generate_author_hash'))) {
        try {
          final fallbackRes = await SupabaseService.client
              .from('comments')
              .select('id, post_id, parent_id, content, author_alias, author_hash, gif_url, created_at, moderation_status')
              .eq('post_id', postId)
              .neq('moderation_status', 2)
              .order('created_at', ascending: true)
              .timeout(const Duration(seconds: 10));
          final List<dynamic> data = fallbackRes as List<dynamic>;
          final List<PostComment> allComments = data
              .map((item) => PostComment.fromMap(Map<String, dynamic>.from(item)))
              .toList();
          for (var c in allComments) {
            c.children = [];
          }
          final Map<String, PostComment> map = {};
          final List<PostComment> rootComments = [];
          for (var c in allComments) {
            map[c.id] = c;
          }
          for (var c in allComments) {
            final pId = c.parentId;
            if (pId != null && pId.trim().isNotEmpty && map.containsKey(pId) && pId != c.id) {
              map[pId]!.children.add(c);
            } else {
              rootComments.add(c);
            }
          }
          return rootComments;
        } catch (inner) {
          debugPrint('Error en fallback directo a tabla comments: $inner');
        }
      }
      debugPrint('Error al obtener comentarios: $e');
      rethrow;
    }
  }

  static Future<PostComment?> addComment({
    required String postId,
    required String content,
    required String authorAlias,
    String? parentId,
    String? gifUrl,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      throw Exception('La aplicación no está conectada a la base de datos.');
    }

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
          .select('id, post_id, parent_id, content, author_alias, author_hash, gif_url, created_at, moderation_status')
          .single()
          .timeout(const Duration(seconds: 12));

      final comment = PostComment.fromMap(Map<String, dynamic>.from(res));
      await CacheService.invalidateAll(_cacheNamespace);
      return comment;
    } catch (e) {
      debugPrint('Error al agregar comentario: $e');
      rethrow;
    }
  }

  static Future<bool> reportPost({
    required String postId,
    required String reason,
    String? details,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      throw Exception('La aplicación no está conectada a la base de datos.');
    }
    try {
      final res = await SupabaseService.client.rpc('report_forum_post', params: {
        'p_post_id': postId,
        'p_reason': reason.trim(),
        'p_details': details?.trim(),
      });
      return res == true;
    } catch (e) {
      debugPrint('Error reportando post: $e');
      return false;
    }
  }

  static Future<bool> reportComment({
    required String commentId,
    required String reason,
    String? details,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      throw Exception('La aplicación no está conectada a la base de datos.');
    }
    try {
      final res = await SupabaseService.client.rpc('report_forum_comment', params: {
        'p_comment_id': commentId,
        'p_reason': reason.trim(),
        'p_details': details?.trim(),
      });
      return res == true;
    } catch (e) {
      debugPrint('Error reportando comentario: $e');
      return false;
    }
  }

  static Future<bool> reportUser({
    required String reportedUserId,
    required String reportedAlias,
    required String reason,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      throw Exception('La aplicación no está conectada a la base de datos.');
    }
    try {
      await SupabaseService.client.from('entity_reports').insert({
        'reporter_id': SupabaseService.currentUserId,
        'entity_type': 'user',
        'entity_id': reportedUserId,
        'reported_user_id': reportedUserId,
        'reason': reason.trim(),
        'moderation_status': 0,
        'metadata': {'reported_user_alias': reportedAlias},
      });
      return true;
    } catch (e) {
      debugPrint('Error reportando usuario: $e');
      return false;
    }
  }

  /// Obtiene los canales del foro consultando la tabla `categorias_foro` en Supabase
  static Future<List<ForumChannel>> fetchForumChannels() async {
    if (!SupabaseConfig.isConfigured) {
      return List<ForumChannel>.from(ForumChannel.defaultChannels);
    }

    try {
      final response = await SupabaseService.client
          .from('categorias_foro')
          .select('id, nombre')
          .order('id')
          .timeout(const Duration(seconds: 8));

      final List<dynamic> data = response as List<dynamic>;
      if (data.isEmpty) {
        return List<ForumChannel>.from(ForumChannel.defaultChannels);
      }

      // Orden estándar alineado con el flujo de uso del foro
      const canonicalOrder = ['todos', 'prerrequisitos', 'catedraticos', 'apuntes', 'horarios', 'general'];
      final List<dynamic> sortedData = List.from(data);
      sortedData.sort((a, b) {
        final idA = a['id']?.toString() ?? '';
        final idB = b['id']?.toString() ?? '';
        final idxA = canonicalOrder.indexOf(idA);
        final idxB = canonicalOrder.indexOf(idB);
        if (idxA != -1 && idxB != -1) return idxA.compareTo(idxB);
        if (idxA != -1) return -1;
        if (idxB != -1) return 1;
        return idA.compareTo(idB);
      });

      final List<ForumChannel> channels = [];
      for (final row in sortedData) {
        final id = row['id']?.toString() ?? '';
        final nombre = row['nombre']?.toString() ?? id;
        channels.add(ForumChannel.fromDbCategory(id: id, nombre: nombre));
      }

      return channels;
    } catch (e) {
      debugPrint('Error al obtener canales desde categorias_foro: $e');
      return List<ForumChannel>.from(ForumChannel.defaultChannels);
    }
  }

  /// Obtiene la estructura de servidores de facultades y carreras oficiales desde la DB
  static Future<List<ForumFaculty>> fetchForumFaculties() async {
    if (!SupabaseConfig.isConfigured) {
      return ForumFaculty.defaultFaculties;
    }

    try {
      final facsRes = await SupabaseService.client
          .from('facultades')
          .select('id, codigo, nombre')
          .order('codigo')
          .timeout(const Duration(seconds: 8));
      final carsRes = await SupabaseService.client
          .from('carreras')
          .select('id, facultad_id, codigo, nombre')
          .order('codigo')
          .timeout(const Duration(seconds: 8));

      final List<dynamic> facsData = facsRes as List<dynamic>;
      final List<dynamic> carsData = carsRes as List<dynamic>;

      if (facsData.isEmpty || carsData.isEmpty) {
        return ForumFaculty.defaultFaculties;
      }

      // Mapa de metadatos predefinidos (íconos, colores, códigos cortos)
      final Map<String, ForumCareerItem> careerMeta = {};
      final Map<String, ForumFaculty> facultyMeta = {};
      for (final f in ForumFaculty.defaultFaculties) {
        facultyMeta[f.id] = f;
        for (final c in f.careers) {
          careerMeta[c.id] = c;
        }
      }

      final Map<String, List<ForumCareerItem>> careersByFacultad = {};
      for (final row in carsData) {
        final carId = row['id']?.toString() ?? '';
        final facId = row['facultad_id']?.toString() ?? '';
        final nombre = row['nombre']?.toString() ?? '';
        final codigo = row['codigo']?.toString() ?? '';

        final existing = careerMeta[carId];
        final shortCode = existing?.shortCode ??
            (codigo.isNotEmpty && codigo.length <= 6
                ? codigo
                : (carId.length > 4 ? carId.substring(0, 4).toUpperCase() : carId.toUpperCase()));

        careersByFacultad.putIfAbsent(facId, () => []).add(
          ForumCareerItem(
            id: carId,
            name: nombre,
            shortCode: shortCode,
            icon: existing?.icon ?? Icons.school_outlined,
            facultadId: facId,
            codigo: codigo,
          ),
        );
      }

      final List<ForumFaculty> faculties = [];
      for (final facRow in facsData) {
        final facId = facRow['id']?.toString() ?? '';
        final nombre = facRow['nombre']?.toString() ?? '';
        final codigo = facRow['codigo']?.toString() ?? '';
        final existing = facultyMeta[facId];
        final careers = careersByFacultad[facId] ?? existing?.careers ?? [];

        faculties.add(
          ForumFaculty(
            id: facId,
            name: nombre,
            shortCode: existing?.shortCode ?? (codigo.isNotEmpty ? codigo : facId.toUpperCase()),
            icon: existing?.icon ?? Icons.school,
            color: existing?.color ?? const Color(0xFF004B87),
            careers: careers,
          ),
        );
      }

      // El servidor de hasta arriba SIEMPRE debe ser el de Todas las Facultades
      final defaultRoot = ForumFaculty.defaultFaculties.first;
      final todasIndex = faculties.indexWhere((f) => f.id == 'todas');
      ForumFaculty todasFaculty;
      if (todasIndex != -1) {
        final existingTodas = faculties.removeAt(todasIndex);
        final baseCareers = existingTodas.careers.isNotEmpty ? existingTodas.careers : defaultRoot.careers;
        final updatedCareers = baseCareers.map((c) {
          if (c.id == 'todas') {
            return c.copyWith(
              name: 'Todas las Carreras',
              shortCode: 'USAC',
              icon: Icons.school,
            );
          }
          return c;
        }).toList();

        todasFaculty = existingTodas.copyWith(
          name: 'Todas las Facultades',
          shortCode: 'USAC',
          icon: Icons.school,
          careers: updatedCareers,
        );
      } else {
        todasFaculty = defaultRoot;
      }
      faculties.insert(0, todasFaculty);

      return faculties;
    } catch (e) {
      debugPrint('Error al obtener facultades y carreras de la DB: $e');
      return ForumFaculty.defaultFaculties;
    }
  }
}
