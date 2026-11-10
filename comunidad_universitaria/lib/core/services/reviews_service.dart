import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/seccion_review.dart';
import 'supabase_service.dart';

class ReviewsService {
  /// Obtiene la lista de reseñas de secciones desde la vista `safe_seccion_reviews`.
  /// Aplica filtros opcionales y ordena por upvotes descendente y fecha de creación descendente.
  static Future<List<SeccionReview>> fetchReviews({
    String? cursoCodigo,
    String? seccion,
    String? semestre,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      return [];
    }

    try {
      var query = SupabaseService.client
          .from('safe_seccion_reviews')
          .select('*');

      if (cursoCodigo != null && cursoCodigo.trim().isNotEmpty) {
        query = query.eq('curso_codigo', cursoCodigo.trim());
      }

      if (seccion != null && seccion.trim().isNotEmpty) {
        query = query.eq('seccion', seccion.trim());
      }

      if (semestre != null && semestre.trim().isNotEmpty) {
        query = query.eq('semestre', semestre.trim());
      }

      final response = await query
          .order('upvotes', ascending: false)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 10));

      final List<dynamic> data = response as List<dynamic>;
      return data
          .map((item) => SeccionReview.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      debugPrint('Error al obtener reseñas de secciones: $e');
      return [];
    }
  }

  /// Crea una nueva reseña de sección vinculada al usuario autenticado.
  /// No proyecta `user_id` en la respuesta para preservar la privacidad de datos.
  static Future<SeccionReview?> createReview({
    required String cursoCodigo,
    required String seccion,
    required bool recomienda,
    String? catedraticoNombre,
    int? dificultad,
    int? cargaTareas,
    String? comentario,
    String semestre = '1S-2026',
  }) async {
    if (!SupabaseConfig.isConfigured) {
      throw Exception('La aplicación no está conectada a la base de datos.');
    }

    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      throw Exception(
        'Debes iniciar sesión para publicar una reseña de curso.',
      );
    }

    try {
      final insertMap = {
        'curso_codigo': cursoCodigo.trim(),
        'seccion': seccion.trim(),
        'recomienda': recomienda,
        'catedratico_nombre': catedraticoNombre?.trim(),
        'dificultad': dificultad,
        'carga_tareas': cargaTareas,
        'comentario': comentario?.trim(),
        'semestre': semestre.trim(),
        'user_id': userId,
        'upvotes': 0,
      };

      const selectColumns =
          'id, curso_codigo, seccion, recomienda, catedratico_nombre, dificultad, carga_tareas, comentario, semestre, upvotes, created_at, updated_at';

      final res = await SupabaseService.client
          .from('seccion_reviews')
          .insert(insertMap)
          .select(selectColumns)
          .single()
          .timeout(const Duration(seconds: 10));

      return SeccionReview.fromMap(
        Map<String, dynamic>.from(res),
      ).copyWith(isMine: true);
    } catch (e) {
      debugPrint('Error al crear reseña de sección: $e');
      rethrow;
    }
  }

  /// Registra un voto positivo para la reseña indicada mediante el RPC `upvote_seccion_review`.
  /// Si el RPC no existe aún en el backend (código 42883 o PGRST202), devuelve false sin lanzar excepción.
  static Future<bool> upvoteReview(String reviewId) async {
    if (!SupabaseConfig.isConfigured) return false;

    try {
      final res = await SupabaseService.client.rpc(
        'upvote_seccion_review',
        params: {'p_review_id': reviewId},
      );
      return res == true;
    } catch (e) {
      if (e is PostgrestException &&
          (e.code == '42883' ||
              e.code == 'PGRST202' ||
              e.message.contains('upvote_seccion_review'))) {
        debugPrint(
          'RPC upvote_seccion_review no disponible aún en DB: ${e.message}',
        );
        return false;
      }
      debugPrint('Error al registrar upvote de reseña: $e');
      return false;
    }
  }

  /// NOTA DE PRIVACIDAD Y CUMPLIMIENTO LEGAL:
  /// El borrado físico de reseñas está prohibido por normativas de retención de auditoría.
  /// La tabla `seccion_reviews` no cuenta con columna `deleted_at` para soft delete,
  /// por lo que el método de borrado se omite intencionalmente para evitar borrados destructivos.
}
