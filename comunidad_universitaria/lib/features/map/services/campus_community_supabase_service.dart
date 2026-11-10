import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/services/supabase_service.dart';
import '../models/bathroom_tier_config.dart';

/// Servicio de integración entre el módulo de mapa / reseñas y Supabase Cloud.
class CampusCommunitySupabaseService {
  final SupabaseClient? client;

  CampusCommunitySupabaseService({this.client});

  SupabaseClient? get supabase {
    if (client != null) return client;
    if (SupabaseConfig.isConfigured) {
      try {
        return SupabaseService.client;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// 1. Consulta los agregados precomputados de calificaciones y etiquetas para un lugar.
  Future<Map<String, dynamic>?> fetchTargetAggregate(String targetId) async {
    final client = supabase;
    if (client == null) return null;

    try {
      final response = await client
          .from('campus_rating_aggregates')
          .select('average_rating, total_reviews, bathroom_class, tags_summary')
          .eq('target_id', targetId)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('Aviso Supabase: No se pudo obtener agregado para $targetId ($e)');
      return null;
    }
  }

  /// 2. Consulta segura de reseñas mediante RPC con pseudónimo (protege datos reales del alumno).
  Future<List<Map<String, dynamic>>> loadTargetReviews(
    String targetId, {
    int limit = 20,
    int offset = 0,
  }) async {
    final client = supabase;
    if (client == null) return const [];

    try {
      final List<dynamic> response = await client.rpc(
        'get_target_reviews_with_authors',
        params: {
          'p_target_id': targetId,
          'p_limit': limit,
          'p_offset': offset,
        },
      );
      return response.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Aviso Supabase: Fallback RPC de reseñas para $targetId ($e)');
      return const [];
    }
  }

  /// 3. Publicación o actualización de una reseña de estudiante (Upsert protegido por RLS).
  Future<void> submitReview({
    required String targetId,
    required String targetType, // 'building' o 'poi'
    required String targetCategory, // 'sanitarios', 'general', etc.
    required int rating,
    String? comment,
    Map<String, bool>? tags,
  }) async {
    final client = supabase;
    if (client == null) return;

    final user = client.auth.currentUser;
    if (user == null) {
      throw StateError('Debes iniciar sesión para calificar un lugar del campus');
    }

    // Si es sanitario, calculamos la clase oficial para guardarla en el registro
    String? bathroomClass;
    if (targetCategory == 'sanitarios') {
      bathroomClass = BathroomTierConfig.resolve(rating.toDouble()).code;
    }

    await client.from('campus_reviews').upsert({
      'target_id': targetId,
      'target_type': targetType,
      'target_category': targetCategory,
      'user_id': user.id,
      'rating': rating,
      'bathroom_tier': bathroomClass,
      'comment': comment?.trim(),
      'tags': tags ?? {},
      'moderation_status': 1, // El trigger del backend audita si contiene palabras bloqueadas
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id,target_id');
  }

  /// 4. Publica un comentario en el foro del lugar con moderación antipalabrotas automática.
  Future<void> sendComment({
    required String postId,
    required String content,
    String? parentCommentId,
    String? fallbackAlias,
  }) async {
    final client = supabase;
    if (client == null) return;

    final user = client.auth.currentUser;
    if (user == null) {
      throw StateError('Inicia sesión para debatir en el foro del campus');
    }

    String alias = fallbackAlias ?? 'Estudiante USAC';
    try {
      final profile = await client
          .from('profiles')
          .select('alias')
          .eq('id', user.id)
          .maybeSingle();
      if (profile != null && profile['alias'] != null) {
        alias = profile['alias'] as String;
      }
    } catch (_) {}

    await client.from('comments').insert({
      'post_id': postId,
      'user_id': user.id,
      'author_alias': alias,
      'content': content.trim(),
      'parent_id': parentCommentId,
      'moderation_status': 1,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}

/// Controlador de suscripción en tiempo real a los comentarios de un hilo o lugar.
class ForumCommentsController {
  final String postId;
  final SupabaseClient? client;
  RealtimeChannel? _commentsChannel;

  ForumCommentsController({
    required this.postId,
    this.client,
  });

  SupabaseClient? get supabase {
    if (client != null) return client;
    if (SupabaseConfig.isConfigured) {
      try {
        return SupabaseService.client;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Se suscribe al WebSocket de Supabase Realtime para recibir nuevos comentarios y actualizaciones.
  void subscribeToComments({
    required void Function(Map<String, dynamic> newComment) onCommentInserted,
    required void Function(Map<String, dynamic> updatedComment) onCommentUpdated,
    required void Function(String deletedCommentId) onCommentDeleted,
  }) {
    final client = supabase;
    if (client == null) return;

    final channelName = 'public:comments:post_$postId';
    _commentsChannel = client.channel(channelName)
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'comments',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'post_id',
          value: postId,
        ),
        callback: (payload) {
          final row = payload.newRecord;
          // Solo mostrar si está aprobado (1) o si fue escrito por el usuario actual
          if (row['moderation_status'] == 1 ||
              row['user_id'] == client.auth.currentUser?.id) {
            onCommentInserted(row);
          }
        },
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'comments',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'post_id',
          value: postId,
        ),
        callback: (payload) {
          onCommentUpdated(payload.newRecord);
        },
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: 'comments',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'post_id',
          value: postId,
        ),
        callback: (payload) {
          final oldRecord = payload.oldRecord;
          if (oldRecord['id'] != null) {
            onCommentDeleted(oldRecord['id'].toString());
          }
        },
      )
      ..subscribe();
  }

  void dispose() {
    _commentsChannel?.unsubscribe();
  }
}
