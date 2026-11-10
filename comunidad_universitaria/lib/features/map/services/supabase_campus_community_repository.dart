import 'package:flutter/foundation.dart';
import 'package:usac_campus_map/usac_campus_map.dart';
import '../../../core/services/supabase_service.dart';
import '../models/bathroom_tier_config.dart';
import 'campus_community_supabase_service.dart';

/// Repositorio híbrido que combina la reactividad offline de `usac_campus_map`
/// con la persistencia en tiempo real y RLS de Supabase.
class SupabaseCampusCommunityRepository extends CampusCommunityRepository {
  final CampusCommunitySupabaseService _supabaseService;

  SupabaseCampusCommunityRepository({
    CampusCommunitySupabaseService? supabaseService,
  })  : _supabaseService = supabaseService ?? CampusCommunitySupabaseService(),
        super.isolated() {
    _registerCustomSchemes();
  }

  void _registerCustomSchemes() {
    // 1. Sanitarios oficiales USAC (5 Clases)
    registerClassification(BathroomTierConfig.toRatingClassificationConfig());

    // 2. Cafeterías y Comedores del Campus Central
    registerClassification(
      const RatingClassificationConfig(
        category: 'cafeterias',
        title: 'Evaluación Gastronómica',
        tiers: [
          RatingTierItem(
            code: 'excelente',
            label: 'Exquisito',
            emoji: '🍽️',
            colorHex: 0xFF10B981,
            description: 'Calidad superior, higiene óptima y rapidez.',
            minRating: 4.5,
          ),
          RatingTierItem(
            code: 'bueno',
            label: 'Recomendable',
            emoji: '🥪',
            colorHex: 0xFF3B82F6,
            description: 'Buen sabor, porciones generosas y precio justo.',
            minRating: 3.5,
          ),
          RatingTierItem(
            code: 'regular',
            label: 'Económico',
            emoji: '🥤',
            colorHex: 0xFFF59E0B,
            description: 'Comida básica y rápida.',
            minRating: 2.5,
          ),
          RatingTierItem(
            code: 'deficiente',
            label: 'No Recomendado',
            emoji: '⚠️',
            colorHex: 0xFFEF4444,
            description: 'Servicio lento o higiene deficiente.',
            minRating: 0.0,
          ),
        ],
        availableTags: [
          'fast_service',
          'clean_tables',
          'card_payment',
          'affordable_combos',
        ],
        tagLabels: {
          'fast_service': '⚡ Servicio Rápido',
          'clean_tables': '✨ Mesas Limpias',
          'card_payment': '💳 Acepta Tarjeta',
          'affordable_combos': '💰 Combos Económicos',
        },
      ),
    );

    // 3. Edificios y Aulas Generales
    registerClassification(
      const RatingClassificationConfig(
        category: 'general',
        title: 'Evaluación General de Instalaciones',
        tiers: [
          RatingTierItem(
            code: 'excelente',
            label: 'Óptimo',
            emoji: '⭐',
            colorHex: 0xFF10B981,
            description: 'Instalaciones modernas, confortables y funcionales.',
            minRating: 4.5,
          ),
          RatingTierItem(
            code: 'bueno',
            label: 'Adecuado',
            emoji: '👍',
            colorHex: 0xFF3B82F6,
            description: 'Buenas condiciones para el estudio diario.',
            minRating: 3.5,
          ),
          RatingTierItem(
            code: 'regular',
            label: 'Básico',
            emoji: '⚠️',
            colorHex: 0xFFF59E0B,
            description: 'Aceptable, con áreas de mejora.',
            minRating: 2.5,
          ),
          RatingTierItem(
            code: 'deficiente',
            label: 'Deficiente',
            emoji: '🛑',
            colorHex: 0xFFDC2626,
            description: 'Requiere mantenimiento urgente.',
            minRating: 0.0,
          ),
        ],
        availableTags: [
          'has_wifi',
          'has_power_outlets',
          'good_lighting',
          'quiet_area',
          'accessible',
        ],
        tagLabels: {
          'has_wifi': '📶 Buen WiFi',
          'has_power_outlets': '🔌 Tomacorrientes',
          'good_lighting': '💡 Buena Iluminación',
          'quiet_area': '🤫 Área Silenciosa',
          'accessible': '♿ Accesible',
        },
      ),
    );
  }

  /// Sincroniza en segundo plano las reseñas y agregados de Supabase para un lugar específico.
  Future<void> syncFromSupabase(String targetId, {String? targetCategory}) async {
    try {
      // 1. Cargar agregado de Supabase si existe
      await _supabaseService.fetchTargetAggregate(targetId);

      // 2. Cargar reseñas RPC
      final reviewsData = await _supabaseService.loadTargetReviews(targetId);
      if (reviewsData.isNotEmpty) {
        for (final r in reviewsData) {
          final authorAlias = r['author_alias'] as String? ?? 'Estudiante USAC';
          final authorCarrera = r['author_carrera'] as String?;
          final isVerified = r['author_is_verified'] == true;
          final rating = (r['rating'] as num?)?.toInt() ?? 5;
          final comment = r['comment'] as String?;
          final rawTags = r['tags'];
          final tags = <String, bool>{};
          if (rawTags is Map) {
            rawTags.forEach((k, v) {
              tags[k.toString()] = v == true;
            });
          }

          super.submitReview(
            targetId: targetId,
            targetType: r['target_type'] as String? ?? 'building',
            targetCategory: targetCategory ?? 'general',
            rating: rating,
            comment: comment,
            tags: tags,
            authorAlias: authorAlias,
            authorCarrera: authorCarrera,
            authorIsVerified: isVerified,
          );
        }
      }
    } catch (e) {
      debugPrint('Aviso: Fallback offline activo para $targetId: $e');
    }
  }

  @override
  CampusReview submitReview({
    required String targetId,
    required String targetType,
    required String targetCategory,
    required int rating,
    String? comment,
    Map<String, bool>? tags,
    String authorAlias = 'Estudiante Sancarlista',
    String? authorCarrera,
    bool authorIsVerified = true,
  }) {
    // 1. Actualización local inmediata (optimistic UI)
    final review = super.submitReview(
      targetId: targetId,
      targetType: targetType,
      targetCategory: targetCategory,
      rating: rating,
      comment: comment,
      tags: tags,
      authorAlias: authorAlias,
      authorCarrera: authorCarrera,
      authorIsVerified: authorIsVerified,
    );

    // 2. Persistencia en Supabase Cloud si hay sesión autenticada
    if (SupabaseService.currentUser != null) {
      _supabaseService
          .submitReview(
            targetId: targetId,
            targetType: targetType,
            targetCategory: targetCategory,
            rating: rating,
            comment: comment,
            tags: tags,
          )
          .catchError((err) {
            debugPrint('Error enviando reseña a Supabase (modo offline): $err');
          });
    }

    return review;
  }

  @override
  CampusComment submitComment({
    required String targetId,
    required String content,
    String? parentId,
    String authorAlias = 'Estudiante USAC',
  }) {
    // 1. Actualización local inmediata
    final comment = super.submitComment(
      targetId: targetId,
      content: content,
      parentId: parentId,
      authorAlias: authorAlias,
    );

    // 2. Persistencia en Supabase
    if (SupabaseService.currentUser != null) {
      _supabaseService
          .sendComment(
            postId: targetId,
            content: content,
            parentCommentId: parentId,
            fallbackAlias: authorAlias,
          )
          .catchError((err) {
            debugPrint('Error enviando comentario a Supabase: $err');
          });
    }

    return comment;
  }
}
