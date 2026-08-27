import 'package:flutter/foundation.dart';
import '../config/supabase_config.dart';
import '../models/marketplace_item.dart';
import '../models/post.dart';
import '../models/user_profile.dart';
import '../models/whatsapp_group.dart';
import 'local_storage_service.dart';
import 'supabase_service.dart';

class ProfileService {
  static Future<UserProfile> loadProfile() async {
    return await LocalStorageService.getUserProfile();
  }

  static Future<void> saveProfile(UserProfile profile) async {
    await LocalStorageService.saveUserProfile(profile);
  }

  static Future<List<Post>> fetchUserPosts({
    required String alias,
    String? userId,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      return [];
    }

    try {
      var query = SupabaseService.client.from('posts').select('*, comments(count)');

      if (userId != null && userId.isNotEmpty && userId != 'local_user') {
        query = query.eq('user_id', userId);
      } else {
        query = query.eq('author_alias', alias.trim());
      }

      final response = await query.order('created_at', ascending: false).limit(50);
      final List<dynamic> data = response as List<dynamic>;

      return data.map((item) {
        final map = Map<String, dynamic>.from(item);
        int commentCount = 0;
        if (map['comments'] is List && (map['comments'] as List).isNotEmpty) {
          final countObj = (map['comments'] as List).first;
          commentCount = countObj['count'] ?? 0;
        }

        return Post.fromMap(
          map,
          isLikedByMe: false,
          commentCount: commentCount,
        );
      }).toList();
    } catch (e) {
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
      var query = SupabaseService.client.from('whatsapp_groups').select('*');

      if (userId != null && userId.isNotEmpty && userId != 'local_user') {
        query = query.eq('user_id', userId);
      } else {
        query = query.eq('author_alias', alias.trim());
      }

      final response = await query.order('created_at', ascending: false).limit(50);
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
      var query = SupabaseService.client.from('marketplace_items').select('*');

      if (userId != null && userId.isNotEmpty && userId != 'local_user') {
        query = query.eq('user_id', userId);
      } else {
        query = query.eq('author_alias', alias.trim());
      }

      final response = await query.order('created_at', ascending: false).limit(50);
      final List<dynamic> data = response as List<dynamic>;

      return data.map((item) {
        final map = Map<String, dynamic>.from(item);
        return MarketplaceItem.fromMap(map, isUpvotedByMe: false);
      }).toList();
    } catch (e) {
      debugPrint('Error al obtener publicaciones de marketplace del usuario: $e');
      return [];
    }
  }

  static Future<bool> deletePost(String postId) async {
    if (!SupabaseConfig.isConfigured) return true;
    try {
      await SupabaseService.client.from('posts').delete().eq('id', postId);
      return true;
    } catch (e) {
      debugPrint('Error al eliminar post: $e');
      return false;
    }
  }

  static Future<bool> deleteGroup(String groupId) async {
    if (!SupabaseConfig.isConfigured) return true;
    try {
      await SupabaseService.client.from('whatsapp_groups').delete().eq('id', groupId);
      return true;
    } catch (e) {
      debugPrint('Error al eliminar grupo: $e');
      return false;
    }
  }

  static Future<bool> deleteMarketplaceItem(String itemId) async {
    if (!SupabaseConfig.isConfigured) return true;
    try {
      await SupabaseService.client.from('marketplace_items').delete().eq('id', itemId);
      return true;
    } catch (e) {
      debugPrint('Error al eliminar anuncio de marketplace: $e');
      return false;
    }
  }
}
