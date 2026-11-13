import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/marketplace_item.dart';
import '../models/post.dart';
import '../models/user_profile.dart';
import '../models/whatsapp_group.dart';
import 'local_storage_service.dart';
import 'supabase_service.dart';

class ProfileService {
  static const String termsVersion = 'v1.0-2026';

  static Future<UserProfile> loadProfile() async {
    return await LocalStorageService.getUserProfile();
  }

  static Future<void> saveProfile(UserProfile profile) async {
    await LocalStorageService.saveUserProfile(profile);
  }

  /// Verifica si el usuario actual ha aceptado la versión vigente de términos y condiciones.
  static Future<bool> hasAcceptedTerms() async {
    if (!SupabaseConfig.isConfigured) return false;
    final uid = SupabaseService.currentUserId;
    if (uid == null) return false;

    try {
      final res = await SupabaseService.client
          .from('profiles')
          .select('accepted_terms_version')
          .eq('id', uid)
          .maybeSingle();

      if (res == null) return false;
      return res['accepted_terms_version'] == termsVersion;
    } catch (e) {
      debugPrint('Error verificando aceptación de términos: $e');
      return false;
    }
  }

  /// Registra la aceptación de la versión vigente de términos y condiciones.
  static Future<void> acceptTerms() async {
    if (!SupabaseConfig.isConfigured) return;
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;

    try {
      await SupabaseService.client
          .from('profiles')
          .update({
            'accepted_terms_version': termsVersion,
            'accepted_terms_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', uid);
    } catch (e) {
      debugPrint('Error registrando aceptación de términos: $e');
      rethrow;
    }
  }

  /// Devuelve el estado de verificación y hashes del perfil propio, sin exponer datos sensibles.
  static Future<Map<String, dynamic>?> fetchVerificationStatus() async {
    if (!SupabaseConfig.isConfigured) return null;
    final uid = SupabaseService.currentUserId;
    if (uid == null) return null;

    try {
      final res = await SupabaseService.client
          .from('profiles')
          .select('is_verified, verified_at, cui_hash, carne_hash')
          .eq('id', uid)
          .maybeSingle();

      if (res == null) return null;
      return Map<String, dynamic>.from(res);
    } catch (e) {
      debugPrint('Error al obtener estado de verificación: $e');
      return null;
    }
  }

  static Future<List<Post>> fetchUserPosts({
    required String alias,
    String? userId,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      return [];
    }

    try {
      var query = SupabaseService.client
          .from('posts')
          .select(
            'id, title, category, content, author_alias, author_hash, likes, carrera, image_url, gif_url, is_pinned, quoted_post_id, reposts_count, moderation_status, created_at, comments_count, hot_score, expires_at, deleted_at, is_legal_hold',
          )
          .neq('moderation_status', 2);

      if (alias.trim().isNotEmpty) {
        query = query.eq('author_alias', alias.trim());
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(50);
      final List<dynamic> data = response as List<dynamic>;

      return data.map((item) {
        final map = Map<String, dynamic>.from(item);
        final commentCount = (map['comment_count'] is int)
            ? map['comment_count'] as int
            : int.tryParse(map['comment_count']?.toString() ?? '0') ?? 0;

        return Post.fromMap(
          map,
          isLikedByMe: false,
          commentCount: commentCount,
        );
      }).toList();
    } catch (e) {
      if (e is PostgrestException &&
          (e.code == '42501' ||
              e.message.contains('generate_author_hash') ||
              e.code == '42P01')) {
        try {
          var fallbackQuery = SupabaseService.client
              .from('posts')
              .select(
                'id, title, category, content, author_alias, author_hash, likes, carrera, image_url, gif_url, is_pinned, quoted_post_id, reposts_count, moderation_status, created_at, comments_count, hot_score, expires_at, deleted_at, is_legal_hold',
              )
              .isFilter('deleted_at', null)
              .neq('moderation_status', 2);
          if (alias.trim().isNotEmpty) {
            fallbackQuery = fallbackQuery.eq('author_alias', alias.trim());
          }
          final response = await fallbackQuery
              .order('created_at', ascending: false)
              .limit(50);
          final List<dynamic> data = response as List<dynamic>;
          return data.map((item) {
            return Post.fromMap(
              Map<String, dynamic>.from(item),
              isLikedByMe: false,
              commentCount: 0,
            );
          }).toList();
        } catch (inner) {
          debugPrint('Error en fallback directo a posts en perfil: $inner');
        }
      }
      debugPrint('Error al obtener posts del usuario: $e');
      return [];
    }
  }

  static Future<List<WhatsAppGroup>> fetchUserGroups({
    required String alias,
    String? userId,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      return [];
    }

    try {
      final response = await SupabaseService.client
          .from('safe_student_groups')
          .select('*')
          .eq('is_mine', true)
          .order('created_at', ascending: false)
          .limit(50);
      final List<dynamic> data = response as List<dynamic>;

      return data.map((item) {
        final map = Map<String, dynamic>.from(item);
        return WhatsAppGroup.fromMap(map, isUpvotedByMe: false);
      }).toList();
    } catch (e) {
      debugPrint('Error al obtener grupos del usuario: $e');
      return [];
    }
  }

  static Future<List<MarketplaceItem>> fetchUserMarketplaceItems({
    required String alias,
    String? userId,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      return [];
    }

    try {
      final response = await SupabaseService.client
          .from('safe_marketplace_items')
          .select('*')
          .eq('is_mine', true)
          .order('created_at', ascending: false)
          .limit(50);
      final List<dynamic> data = response as List<dynamic>;

      return data.map((item) {
        final map = Map<String, dynamic>.from(item);
        return MarketplaceItem.fromMap(map, isUpvotedByMe: false);
      }).toList();
    } catch (e) {
      debugPrint(
        'Error al obtener publicaciones de marketplace del usuario: $e',
      );
      return [];
    }
  }

  /// Soft delete de post respetando retención legal.
  static Future<bool> deletePost(String postId) async {
    if (!SupabaseConfig.isConfigured) return true;
    try {
      final check = await SupabaseService.client
          .from('posts')
          .select('is_legal_hold')
          .eq('id', postId)
          .maybeSingle();

      if (check != null && check['is_legal_hold'] == true) {
        debugPrint('Post $postId bajo retención legal; borrado rechazado.');
        return false;
      }

      await SupabaseService.client
          .from('posts')
          .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', postId);
      return true;
    } on PostgrestException catch (e) {
      debugPrint('Error Postgrest al eliminar post: $e');
      return false;
    } catch (e) {
      debugPrint('Error al eliminar post: $e');
      return false;
    }
  }

  /// Soft delete de grupo estudiantil respetando retención legal.
  static Future<bool> deleteGroup(String groupId) async {
    if (!SupabaseConfig.isConfigured) return true;
    try {
      final check = await SupabaseService.client
          .from('student_groups')
          .select('is_legal_hold')
          .eq('id', groupId)
          .maybeSingle();

      if (check != null && check['is_legal_hold'] == true) {
        debugPrint('Grupo $groupId bajo retención legal; borrado rechazado.');
        return false;
      }

      await SupabaseService.client
          .from('student_groups')
          .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', groupId);
      return true;
    } on PostgrestException catch (e) {
      debugPrint('Error Postgrest al eliminar grupo: $e');
      return false;
    } catch (e) {
      debugPrint('Error al eliminar grupo: $e');
      return false;
    }
  }

  /// Soft delete de artículo de marketplace respetando retención legal.
  static Future<bool> deleteMarketplaceItem(String itemId) async {
    if (!SupabaseConfig.isConfigured) return true;
    try {
      final check = await SupabaseService.client
          .from('marketplace_items')
          .select('is_legal_hold')
          .eq('id', itemId)
          .maybeSingle();

      if (check != null && check['is_legal_hold'] == true) {
        debugPrint('Artículo $itemId bajo retención legal; borrado rechazado.');
        return false;
      }

      await SupabaseService.client
          .from('marketplace_items')
          .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', itemId);
      return true;
    } on PostgrestException catch (e) {
      debugPrint('Error Postgrest al eliminar anuncio de marketplace: $e');
      return false;
    } catch (e) {
      debugPrint('Error al eliminar anuncio de marketplace: $e');
      return false;
    }
  }
}
