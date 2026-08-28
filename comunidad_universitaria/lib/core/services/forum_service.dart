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
  }) async {
    if (!SupabaseConfig.isConfigured) return _getSamplePosts();

    try {
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

      final response = await query.order('created_at', ascending: false).limit(50);
      final List<dynamic> data = response as List<dynamic>;

      // Get list of liked posts for current user
      final currentUserId = SupabaseService.currentUserId;
      final Set<String> likedPostIds = {};

      if (currentUserId != null && data.isNotEmpty) {
        final postIds = data.map((item) => item['id'].toString()).toList();
        final likesRes = await SupabaseService.client
            .from('post_likes')
            .select('post_id')
            .eq('user_id', currentUserId)
            .inFilter('post_id', postIds);

        for (var item in likesRes) {
          likedPostIds.add(item['post_id'].toString());
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

        return Post.fromMap(
          map,
          isLikedByMe: likedPostIds.contains(postId),
          commentCount: commentCount,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error al obtener posts del foro: $e');
      return _getSamplePosts();
    }
  }

  static Future<bool> toggleLike(Post post) async {
    final currentUserId = SupabaseService.currentUserId;
    if (currentUserId == null || !SupabaseConfig.isConfigured) return !post.isLikedByMe;

    try {
      if (post.isLikedByMe) {
        // Remove like
        await SupabaseService.client
            .from('post_likes')
            .delete()
            .eq('post_id', post.id)
            .eq('user_id', currentUserId);

        final newLikes = (post.likes - 1).clamp(0, 999999);
        await SupabaseService.client
            .from('posts')
            .update({'likes': newLikes})
            .eq('id', post.id);

        return false;
      } else {
        // Add like
        await SupabaseService.client.from('post_likes').insert({
          'post_id': post.id,
          'user_id': currentUserId,
        });

        final newLikes = post.likes + 1;
        await SupabaseService.client
            .from('posts')
            .update({'likes': newLikes})
            .eq('id', post.id);

        return true;
      }
    } catch (e) {
      debugPrint('Error al procesar like: $e');
      return post.isLikedByMe;
    }
  }

  static Future<Post?> createPost({
    required String title,
    required String content,
    required String category,
    required String carrera,
    required String authorAlias,
    String? imageUrl,
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
        'likes': 0,
        'moderation_status': 0,
      };

      final res = await SupabaseService.client
          .from('posts')
          .insert(postMap)
          .select()
          .single();

      return Post.fromMap(Map<String, dynamic>.from(res));
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
          .order('created_at', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      final List<PostComment> allComments = data
          .map((item) => PostComment.fromMap(Map<String, dynamic>.from(item)))
          .toList();

      // Build hierarchical tree with cycle and loop prevention
      final Map<String, PostComment> map = {};
      final List<PostComment> rootComments = [];

      for (var c in allComments) {
        map[c.id] = c;
      }

      bool hasCycle(String currentId, String targetParentId) {
        String? next = targetParentId;
        int hops = 0;
        while (next != null && hops < 15) {
          if (next == currentId) return true;
          next = map[next]?.parentId;
          hops++;
        }
        return false;
      }

      for (var c in allComments) {
        if (c.parentId != null &&
            map.containsKey(c.parentId) &&
            c.parentId != c.id &&
            !hasCycle(c.id, c.parentId!)) {
          map[c.parentId]!.children.add(c);
        } else {
          rootComments.add(c);
        }
      }

      return rootComments;
    } catch (e) {
      debugPrint('Error al obtener comentarios: $e');
      return [];
    }
  }

  static Future<PostComment?> addComment({
    required String postId,
    required String content,
    required String authorAlias,
    String? parentId,
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
        'parent_id': parentId,
        'moderation_status': 0,
      };

      final res = await SupabaseService.client
          .from('comments')
          .insert(commentMap)
          .select()
          .single();

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
