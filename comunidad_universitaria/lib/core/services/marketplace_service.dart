import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/marketplace_exception.dart';
import '../models/marketplace_item.dart';
import '../models/marketplace_metrics.dart';
import '../models/marketplace_plan.dart';
import '../models/marketplace_seller_status.dart';
import '../models/seller_profile.dart';
import 'cache_service.dart';
import 'supabase_service.dart';

export '../models/marketplace_exception.dart';
export '../models/marketplace_metrics.dart';
export '../models/marketplace_plan.dart';
export '../models/marketplace_seller_status.dart';
export '../models/seller_profile.dart';

class MarketplaceService {
  static const String _marketColumns =
      'id, title, description, price, is_free, category, facultad, sede, '
      'building_code, location_detail, contact_whatsapp, contact_telegram, '
      'contact_instagram, contact_messenger, social_links, image_urls, video_url, '
      'is_sponsored, sponsor_badge_text, author_alias, upvotes, reported_count, '
      'moderation_status, status, moderation_label, moderation_confidence, '
      'moderation_reason, moderated_at, moderated_by, created_at, updated_at, '
      'deleted_at, is_legal_hold';

  static const String _planColumns =
      'id, name, price_monthly, max_active_items, max_images_per_item, '
      'allow_video, auto_sponsor_items, hide_competitor_related, '
      'default_badge_text, features, sort_order, is_active, created_at, updated_at';

  static const String _cacheNamespace = 'marketplace_items';

  static const Set<String> _validEventTypes = {
    'view',
    'click_whatsapp',
    'click_telegram',
    'click_instagram',
    'click_messenger',
    'share',
  };

  // Prohibited words and phrases filter according to community rules
  static final List<String> _prohibitedKeywords = [
    'hacer examenes',
    'hago examenes',
    'vender parcial',
    'vendo parcial',
    'suplantacion',
    'resolucion de examen',
    'resuelvo examen',
    'hago tareas completas por parcial',
    'arma',
    'armas',
    'droga',
    'drogas',
    'marihuana',
    'cocaina',
    'estafa',
    'piramidal',
    'alcohol',
    'cerveza',
    'licor',
  ];

  static String? validateContent({
    required String title,
    required String description,
  }) {
    final combined = '$title $description'.toLowerCase();
    for (var keyword in _prohibitedKeywords) {
      if (combined.contains(keyword)) {
        return 'Tu publicación contiene términos restringidos ("$keyword"). No se permiten productos o servicios contrarios a las normas comunitarias (Regla 5 y 6).';
      }
    }
    return null;
  }

  static Future<List<MarketplaceItem>> fetchListings({
    String category = 'todos',
    String facultad = 'todas',
    String sede = 'todas',
    String? buildingCode,
    bool onlyFree = false,
    String searchQuery = '',
    int offset = 0,
    int limit = 60,
  }) async {
    final isDefaultQuery =
        (category == 'todos' || category.trim().isEmpty) &&
        (facultad == 'todas' || facultad.trim().isEmpty) &&
        (sede == 'todas' || sede.trim().isEmpty) &&
        (buildingCode == null || buildingCode.trim().isEmpty) &&
        !onlyFree &&
        searchQuery.trim().isEmpty &&
        offset == 0;

    final cacheParams = <String, dynamic>{
      'user': SupabaseService.currentUserId ?? 'anon',
      'category': category,
      'facultad': facultad,
      'sede': sede,
      'onlyFree': onlyFree,
      'search': searchQuery.trim().toLowerCase(),
    };
    if (buildingCode != null && buildingCode.trim().isNotEmpty) {
      cacheParams['building_code'] = buildingCode.trim();
    }
    if (offset != 0) {
      cacheParams['offset'] = offset;
    }
    if (limit != 60) {
      cacheParams['limit'] = limit;
    }

    final cacheKey = CacheService.buildKey(cacheParams);

    final cached = CacheService.get<List<MarketplaceItem>>(
      _cacheNamespace,
      cacheKey,
    );
    if (cached != null) return List<MarketplaceItem>.from(cached);

    if (!SupabaseConfig.isConfigured) {
      throw Exception('La aplicación no está conectada a la base de datos.');
    }

    if (isDefaultQuery) {
      final persisted = await _readPersistedListings(cacheKey);
      if (persisted != null) return persisted;
    }

    try {
      final response = await SupabaseService.client.rpc(
        'get_marketplace_feed',
        params: {
          'p_sede': (sede == 'todas' || sede.trim().isEmpty) ? null : sede.trim(),
          'p_facultad':
              (facultad == 'todas' || facultad.trim().isEmpty)
                  ? null
                  : facultad.trim(),
          'p_building_code':
              (buildingCode == null || buildingCode.trim().isEmpty)
                  ? null
                  : buildingCode.trim(),
          'p_category':
              (category == 'todos' || category.trim().isEmpty)
                  ? null
                  : category.trim(),
          'p_search': searchQuery.trim().isEmpty ? null : searchQuery.trim(),
          'p_only_free': onlyFree,
          'p_sponsored_only': false,
          'p_limit': limit,
          'p_offset': offset,
        },
      );

      final List<dynamic> data = (response as List<dynamic>?) ?? [];
      final listings = data.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return MarketplaceItem.fromMap(
          map,
          isUpvotedByMe: map['is_upvoted_by_me'] == true,
        );
      }).toList();

      CacheService.set(
        _cacheNamespace,
        cacheKey,
        List<MarketplaceItem>.from(listings),
      );
      if (isDefaultQuery) {
        await CacheService.setPersisted(
          _cacheNamespace,
          cacheKey,
          listings.map(_listingToCacheMap).toList(),
        );
      }
      return listings;
    } on PostgrestException catch (e) {
      debugPrint(
        'PostgrestException al consumir get_marketplace_feed, ejecutando fallback: ${e.message}',
      );
      return _fetchListingsFallback(
        category: category,
        facultad: facultad,
        sede: sede,
        buildingCode: buildingCode,
        onlyFree: onlyFree,
        searchQuery: searchQuery,
        offset: offset,
        limit: limit,
        cacheKey: cacheKey,
        isDefaultQuery: isDefaultQuery,
      );
    } catch (e) {
      debugPrint('Error al obtener publicaciones del marketplace: $e');
      if (isDefaultQuery) {
        final persisted = await _readPersistedListings(
          cacheKey,
          allowStale: true,
        );
        if (persisted != null) return persisted;
      }
      rethrow;
    }
  }

  static Future<List<MarketplaceItem>> _fetchListingsFallback({
    required String category,
    required String facultad,
    required String sede,
    required String? buildingCode,
    required bool onlyFree,
    required String searchQuery,
    required int offset,
    required int limit,
    required String cacheKey,
    required bool isDefaultQuery,
  }) async {
    try {
      var query = SupabaseService.client
          .from('marketplace_items')
          .select(_marketColumns)
          .lt('moderation_status', 2);

      if (category != 'todos' && category.trim().isNotEmpty) {
        query = query.eq('category', category.trim());
      }

      if (facultad != 'todas' && facultad.trim().isNotEmpty) {
        query = query.eq('facultad', facultad.trim());
      }

      if (sede != 'todas' && sede.trim().isNotEmpty) {
        query = query.eq('sede', sede.trim());
      }

      if (buildingCode != null && buildingCode.trim().isNotEmpty) {
        query = query.eq('building_code', buildingCode.trim());
      }

      if (onlyFree) {
        query = query.or('is_free.eq.true,price.lte.0');
      }

      if (searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query.or(
          'title.ilike.%$q%,description.ilike.%$q%,building_code.ilike.%$q%',
        );
      }

      final response = await query
          .order('is_sponsored', ascending: false)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final List<dynamic> data = response as List<dynamic>;

      // Get upvotes for current user
      final currentUserId = SupabaseService.currentUserId;
      final Set<String> upvotedItemIds = {};

      if (currentUserId != null && data.isNotEmpty) {
        final itemIds = data.map((item) => item['id'].toString()).toList();
        final upvotesRes = await SupabaseService.client
            .from('marketplace_upvotes')
            .select('item_id')
            .eq('user_id', currentUserId)
            .inFilter('item_id', itemIds);

        for (var item in upvotesRes) {
          upvotedItemIds.add(item['item_id'].toString());
        }
      }

      final listings = data.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        final itemId = map['id'].toString();
        return MarketplaceItem.fromMap(
          map,
          isUpvotedByMe: upvotedItemIds.contains(itemId),
        );
      }).toList();

      CacheService.set(
        _cacheNamespace,
        cacheKey,
        List<MarketplaceItem>.from(listings),
      );
      if (isDefaultQuery) {
        await CacheService.setPersisted(
          _cacheNamespace,
          cacheKey,
          listings.map(_listingToCacheMap).toList(),
        );
      }
      return listings;
    } catch (e) {
      debugPrint('Error en fallback de marketplace_items: $e');
      if (isDefaultQuery) {
        final persisted = await _readPersistedListings(
          cacheKey,
          allowStale: true,
        );
        if (persisted != null) return persisted;
      }
      rethrow;
    }
  }

  /// Lee la primera página persistida (solo consultas por defecto).
  static Future<List<MarketplaceItem>?> _readPersistedListings(
    String cacheKey, {
    bool allowStale = false,
  }) {
    return CacheService.getPersisted<List<MarketplaceItem>>(
      _cacheNamespace,
      cacheKey,
      (data) {
        if (data is! List) {
          throw const FormatException('Caché de marketplace inválida');
        }
        return data
            .whereType<Map>()
            .map(
              (item) => _listingFromCacheMap(Map<String, dynamic>.from(item)),
            )
            .toList();
      },
      allowStale: allowStale,
    );
  }

  static Map<String, dynamic> _listingToCacheMap(MarketplaceItem item) {
    return {
      'id': item.id,
      'title': item.title,
      'description': item.description,
      'price': item.price,
      'is_free': item.isFree,
      'category': item.category,
      'facultad': item.facultad,
      'sede': item.sede,
      'building_code': item.buildingCode,
      'location_detail': item.locationDetail,
      'contact_whatsapp': item.contactWhatsapp,
      'contact_instagram': item.contactInstagram,
      'contact_messenger': item.contactMessenger,
      'contact_telegram': item.contactTelegram,
      'social_links': item.socialLinks,
      'image_urls': item.imageUrls,
      'video_url': item.videoUrl,
      'is_sponsored': item.isSponsored,
      'sponsor_badge_text': item.sponsorBadgeText,
      'sponsor_brand_name': item.sponsorBrandName,
      'author_alias': item.authorAlias,
      'created_at': item.createdAt.toIso8601String(),
      'moderation_status': item.moderationStatus,
      'reported_count': item.reportedCount,
      'upvotes': item.upvotes,
      'shares_count': item.sharesCount,
      'status': item.status,
      'is_seller_verified': item.isSellerVerified,
      'is_mine': item.isMine,
      'cache_upvoted': item.isUpvotedByMe,
      'seller_public_id': item.sellerPublicId,
      'seller_business_name': item.sellerBusinessName,
      'seller_plan_id': item.sellerPlanId,
      'seller_plan_name': item.sellerPlanName,
      'seller_badge_text': item.sellerBadgeText,
      'seller_is_on_campus': item.sellerIsOnCampus,
      'seller_building_code': item.sellerBuildingCode,
      'is_bookmarked_by_me': item.isBookmarked,
      'expires_at': item.expiresAt?.toIso8601String(),
      'score': item.score,
      'is_hidden': item.isHiddenFromFeed,
      'bookmarked_at': item.bookmarkedAt?.toIso8601String(),
    };
  }

  static MarketplaceItem _listingFromCacheMap(Map<String, dynamic> map) {
    return MarketplaceItem.fromMap(
      map,
      isUpvotedByMe: map['cache_upvoted'] == true,
    );
  }

  static Future<List<MarketplaceItem>> fetchSponsoredListings({
    String? sede,
    int limit = 5,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      throw Exception('La aplicación no está conectada a la base de datos.');
    }

    final safeLimit = limit.clamp(1, 5);

    try {
      final response = await SupabaseService.client.rpc(
        'get_marketplace_feed',
        params: {
          'p_sede':
              (sede == null || sede == 'todas' || sede.trim().isEmpty)
                  ? null
                  : sede.trim(),
          'p_sponsored_only': true,
          'p_limit': safeLimit,
        },
      );

      final List<dynamic> data = (response as List<dynamic>?) ?? [];
      return data.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return MarketplaceItem.fromMap(
          map,
          isUpvotedByMe: map['is_upvoted_by_me'] == true,
        );
      }).toList();
    } on PostgrestException catch (e) {
      debugPrint(
        'PostgrestException en fetchSponsoredListings RPC, usando fallback: ${e.message}',
      );
      return _fetchSponsoredFallback(sede: sede, limit: safeLimit);
    } catch (e) {
      debugPrint('Error obteniendo patrocinadores: $e');
      return _fetchSponsoredFallback(sede: sede, limit: safeLimit);
    }
  }

  static Future<List<MarketplaceItem>> _fetchSponsoredFallback({
    String? sede,
    int limit = 5,
  }) async {
    try {
      var query = SupabaseService.client
          .from('marketplace_items')
          .select(_marketColumns)
          .eq('is_sponsored', true)
          .lt('moderation_status', 2);

      if (sede != null && sede != 'todas' && sede.trim().isNotEmpty) {
        query = query.eq('sede', sede.trim());
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(limit);

      final List<dynamic> data = response as List<dynamic>;
      return data
          .map(
            (item) =>
                MarketplaceItem.fromMap(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
    } catch (e) {
      debugPrint('Error en fallback de patrocinadores: $e');
      return [];
    }
  }

  static Future<MarketplaceItem?> fetchItemDetail(String itemId) async {
    if (!SupabaseConfig.isConfigured) {
      throw Exception('La aplicación no está conectada a la base de datos.');
    }
    if (itemId.trim().isEmpty) return null;

    try {
      final response = await SupabaseService.client.rpc(
        'get_marketplace_item_detail',
        params: {'p_item_id': itemId.trim()},
      );

      if (response == null) return null;
      if (response is List) {
        if (response.isEmpty) return null;
        final map = Map<String, dynamic>.from(response.first as Map);
        return MarketplaceItem.fromMap(
          map,
          isUpvotedByMe: map['is_upvoted_by_me'] == true,
        );
      } else if (response is Map) {
        final map = Map<String, dynamic>.from(response);
        return MarketplaceItem.fromMap(
          map,
          isUpvotedByMe: map['is_upvoted_by_me'] == true,
        );
      }
      return null;
    } catch (e) {
      debugPrint('Error en fetchItemDetail: $e');
      return null;
    }
  }

  static Future<List<MarketplaceItem>> fetchSellerCatalog({
    required String sellerPublicId,
    String? excludeItemId,
    int limit = 6,
    int offset = 0,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      throw Exception('La aplicación no está conectada a la base de datos.');
    }

    try {
      final response = await SupabaseService.client.rpc(
        'get_seller_catalog',
        params: {
          'p_seller_public_id': sellerPublicId,
          'p_exclude_item_id': excludeItemId,
          'p_limit': limit,
          'p_offset': offset,
        },
      );

      final List<dynamic> data = (response as List<dynamic>?) ?? [];
      return data.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return MarketplaceItem.fromMap(
          map,
          isUpvotedByMe: map['is_upvoted_by_me'] == true,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error en fetchSellerCatalog: $e');
      return [];
    }
  }

  static Future<List<MarketplaceItem>> fetchRelatedListings({
    required String itemId,
    int limit = 8,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      throw Exception('La aplicación no está conectada a la base de datos.');
    }

    try {
      final response = await SupabaseService.client.rpc(
        'get_related_marketplace_items',
        params: {
          'p_item_id': itemId.trim(),
          'p_limit': limit,
        },
      );

      final List<dynamic> data = (response as List<dynamic>?) ?? [];
      return data.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return MarketplaceItem.fromMap(
          map,
          isUpvotedByMe: map['is_upvoted_by_me'] == true,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error en fetchRelatedListings: $e');
      return [];
    }
  }

  static Future<SellerProfile?> fetchSellerProfile(
    String sellerPublicId,
  ) async {
    if (!SupabaseConfig.isConfigured) {
      throw Exception('La aplicación no está conectada a la base de datos.');
    }

    try {
      final response = await SupabaseService.client.rpc(
        'get_seller_public_profile',
        params: {'p_seller_public_id': sellerPublicId.trim()},
      );

      if (response == null) return null;
      if (response is List) {
        if (response.isEmpty) return null;
        return SellerProfile.fromMap(
          Map<String, dynamic>.from(response.first as Map),
        );
      } else if (response is Map) {
        return SellerProfile.fromMap(Map<String, dynamic>.from(response));
      }
      return null;
    } catch (e) {
      debugPrint('Error en fetchSellerProfile: $e');
      return null;
    }
  }

  static Future<List<MarketplacePlan>> fetchPlans() async {
    if (!SupabaseConfig.isConfigured) {
      throw Exception('La aplicación no está conectada a la base de datos.');
    }

    try {
      final response = await SupabaseService.client
          .from('marketplace_plans')
          .select(_planColumns)
          .eq('is_active', true)
          .order('sort_order', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      return data
          .map(
            (item) =>
                MarketplacePlan.fromMap(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
    } catch (e) {
      debugPrint('Error en fetchPlans: $e');
      return [];
    }
  }

  static Future<MarketplaceSellerStatus?> fetchMyStatus() async {
    if (!SupabaseConfig.isConfigured) {
      throw Exception('La aplicación no está conectada a la base de datos.');
    }

    final userId = SupabaseService.currentUserId;
    if (userId == null || SupabaseService.currentUser?.isAnonymous == true) {
      return null;
    }

    try {
      final response = await SupabaseService.client.rpc(
        'get_my_marketplace_status',
      );
      if (response == null) return null;
      if (response is List) {
        if (response.isEmpty) return null;
        return MarketplaceSellerStatus.fromMap(
          Map<String, dynamic>.from(response.first as Map),
        );
      } else if (response is Map) {
        return MarketplaceSellerStatus.fromMap(
          Map<String, dynamic>.from(response),
        );
      }
      return null;
    } on PostgrestException catch (e) {
      debugPrint('PostgrestException en fetchMyStatus: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error en fetchMyStatus: $e');
      rethrow;
    }
  }

  static Future<List<MarketplaceItem>> fetchMyListings({
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      throw Exception('La aplicación no está conectada a la base de datos.');
    }

    try {
      final response = await SupabaseService.client.rpc(
        'get_my_marketplace_items',
        params: {
          'p_status': status,
          'p_limit': limit,
          'p_offset': offset,
        },
      );

      final List<dynamic> data = (response as List<dynamic>?) ?? [];
      return data.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return MarketplaceItem.fromMap(
          map,
          isUpvotedByMe: map['is_upvoted_by_me'] == true,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error en fetchMyListings: $e');
      return [];
    }
  }

  static Future<List<MarketplaceItem>> fetchBookmarkedListings({
    int limit = 50,
    int offset = 0,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      throw Exception('La aplicación no está conectada a la base de datos.');
    }

    try {
      final response = await SupabaseService.client.rpc(
        'get_my_bookmarked_items',
        params: {
          'p_limit': limit,
          'p_offset': offset,
        },
      );

      final List<dynamic> data = (response as List<dynamic>?) ?? [];
      return data.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return MarketplaceItem.fromMap(
          map,
          isUpvotedByMe: map['is_upvoted_by_me'] == true,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error en fetchBookmarkedListings: $e');
      return [];
    }
  }

  static Future<bool> toggleBookmark(String itemId) async {
    if (!SupabaseConfig.isConfigured) {
      throw const MarketplaceException(
        'La aplicación no está conectada a la base de datos.',
      );
    }
    final userId = SupabaseService.currentUserId;
    if (userId == null || SupabaseService.currentUser?.isAnonymous == true) {
      throw const MarketplaceException(
        'Debes iniciar sesión para guardar productos en tus marcadores',
        code: '42501',
      );
    }

    try {
      final result = await SupabaseService.client.rpc(
        'toggle_marketplace_bookmark',
        params: {'p_item_id': itemId.trim()},
      );
      await CacheService.invalidateAll(_cacheNamespace);
      return result == true;
    } on PostgrestException catch (e) {
      debugPrint('Error Postgrest al alternar marcador: ${e.message}');
      throw MarketplaceException(e.message, code: e.code);
    } catch (e) {
      debugPrint('Error al alternar marcador: $e');
      if (e is MarketplaceException) rethrow;
      throw MarketplaceException(e.toString());
    }
  }

  static Future<void> trackEvent(String itemId, String eventType) async {
    if (!_validEventTypes.contains(eventType)) {
      debugPrint('Evento de marketplace no válido: $eventType');
      return;
    }
    if (!SupabaseConfig.isConfigured) return;

    try {
      await SupabaseService.client.rpc(
        'track_marketplace_event',
        params: {
          'p_item_id': itemId.trim(),
          'p_event_type': eventType,
        },
      );
    } catch (e) {
      debugPrint(
        'Error no bloqueante al registrar telemetría ($eventType): $e',
      );
    }
  }

  static Future<List<MarketplaceMetrics>> fetchMyMetrics({
    int days = 7,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      throw Exception('La aplicación no está conectada a la base de datos.');
    }

    try {
      final response = await SupabaseService.client.rpc(
        'get_marketplace_metrics',
        params: {'p_days': days},
      );

      final List<dynamic> data = (response as List<dynamic>?) ?? [];
      return data
          .map(
            (item) => MarketplaceMetrics.fromMap(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('Error en fetchMyMetrics: $e');
      return [];
    }
  }

  static Future<bool> updateSellerProfile({
    required String sellerPublicId,
    String? businessName,
    String? businessDescription,
    String? businessLogoUrl,
    String? businessBannerUrl,
    Map<String, dynamic>? businessHours,
    bool? isCurrentlyOnCampus,
    String? currentBuildingCode,
    String? currentLocationNote,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      throw const MarketplaceException(
        'La aplicación no está conectada a la base de datos.',
      );
    }

    final updateData = <String, dynamic>{};
    if (businessName != null) updateData['business_name'] = businessName;
    if (businessDescription != null) {
      updateData['business_description'] = businessDescription;
    }
    if (businessLogoUrl != null) {
      updateData['business_logo_url'] = businessLogoUrl;
    }
    if (businessBannerUrl != null) {
      updateData['business_banner_url'] = businessBannerUrl;
    }
    if (businessHours != null) updateData['business_hours'] = businessHours;
    if (isCurrentlyOnCampus != null) {
      updateData['is_currently_on_campus'] = isCurrentlyOnCampus;
    }
    if (currentBuildingCode != null) {
      updateData['current_building_code'] = currentBuildingCode;
    }
    if (currentLocationNote != null) {
      updateData['current_location_note'] = currentLocationNote;
    }

    if (updateData.isEmpty) return true;

    try {
      final res = await SupabaseService.client
          .from('seller_profiles')
          .update(updateData)
          .eq('public_id', sellerPublicId)
          .select('public_id');

      return (res as List).isNotEmpty;
    } on PostgrestException catch (e) {
      debugPrint(
        'Error Postgrest al actualizar perfil comercial: ${e.message}',
      );
      throw MarketplaceException(e.message, code: e.code);
    } catch (e) {
      debugPrint('Error actualizando perfil comercial: $e');
      if (e is MarketplaceException) rethrow;
      throw MarketplaceException(e.toString());
    }
  }

  static Future<bool> updatePresence({
    required bool onCampus,
    String? buildingCode,
    String? note,
  }) async {
    final status = await fetchMyStatus();
    final publicId = status?.sellerPublicId;
    if (publicId == null || publicId.isEmpty) {
      throw const MarketplaceException(
        'No se encontró un perfil comercial asociado a la cuenta actual.',
      );
    }

    return updateSellerProfile(
      sellerPublicId: publicId,
      isCurrentlyOnCampus: onCampus,
      currentBuildingCode: buildingCode,
      currentLocationNote: note,
    );
  }

  static Future<bool> canCreateListing() async {
    if (!SupabaseConfig.isConfigured) return false;
    final userId = SupabaseService.currentUserId;
    if (userId == null || SupabaseService.currentUser?.isAnonymous == true) {
      return false;
    }

    try {
      final status = await fetchMyStatus();
      if (status != null) {
        return status.canPublish;
      }
    } on PostgrestException catch (e) {
      debugPrint(
        'Fallback en canCreateListing por PostgrestException: ${e.message}',
      );
      return true;
    } catch (e) {
      debugPrint('Fallback en canCreateListing por excepción: $e');
      return true;
    }

    return true;
  }

  static Future<MarketplaceItem?> createListing({
    required String title,
    required String description,
    required double price,
    required bool isFree,
    required String category,
    required String facultad,
    required String sede,
    required String buildingCode,
    required String locationDetail,
    String? contactWhatsapp,
    String? contactInstagram,
    String? contactMessenger,
    String? contactTelegram,
    List<String> socialLinks = const [],
    List<String> imageUrls = const [],
    String? videoUrl,
    bool isSponsored = false,
    String? sponsorBadgeText,
    required String authorAlias,
  }) async {
    // 1. Validate content with moderation blacklist
    final violationError = validateContent(
      title: title,
      description: description,
    );
    if (violationError != null) {
      throw Exception(violationError);
    }

    if (!SupabaseConfig.isConfigured) {
      throw Exception('La aplicación no está conectada a la base de datos.');
    }

    final userId = SupabaseService.currentUserId;
    if (userId == null || SupabaseService.currentUser?.isAnonymous == true) {
      throw StateError('Debes iniciar sesión para publicar en el marketplace.');
    }

    if (!await canCreateListing()) {
      throw StateError(
        'Publicar requiere que el equipo autorizado verifique tu identidad. '
        'La verificación institucional todavía no está disponible, así que tu anuncio no se guardó.',
      );
    }

    try {
      final itemMap = {
        'title': title.trim(),
        'description': description.trim(),
        'price': isFree ? 0.0 : price,
        'is_free': isFree || price <= 0.0,
        'category': category,
        'facultad': facultad,
        'sede': sede,
        'building_code': buildingCode.trim(),
        'location_detail': locationDetail.trim(),
        'contact_whatsapp': contactWhatsapp?.trim().isEmpty == true
            ? null
            : contactWhatsapp?.trim(),
        'contact_instagram': contactInstagram?.trim().isEmpty == true
            ? null
            : contactInstagram?.trim(),
        'contact_messenger': contactMessenger?.trim().isEmpty == true
            ? null
            : contactMessenger?.trim(),
        'contact_telegram': contactTelegram?.trim().isEmpty == true
            ? null
            : contactTelegram?.trim(),
        'social_links': socialLinks,
        'image_urls': imageUrls,
        'video_url': videoUrl?.trim().isEmpty == true ? null : videoUrl?.trim(),
        'author_alias': authorAlias.trim(),
        'user_id': userId,
      };

      const explicitColumns =
          'id, title, description, price, is_free, category, facultad, sede, '
          'building_code, location_detail, contact_whatsapp, contact_telegram, '
          'image_urls, video_url, is_sponsored, sponsor_badge_text, author_alias, '
          'upvotes, moderation_status, created_at, contact_instagram, '
          'contact_messenger, social_links, reported_count, status';

      final res = await SupabaseService.client
          .from('marketplace_items')
          .insert(itemMap)
          .select(explicitColumns)
          .single();

      final created = MarketplaceItem.fromMap(
        Map<String, dynamic>.from(res),
        isUpvotedByMe: true,
      ).copyWith(isMine: true);
      await CacheService.invalidateAll(_cacheNamespace);
      return created;
    } on PostgrestException catch (e) {
      debugPrint(
        'Error Postgrest al crear publicación: ${e.message} (code: ${e.code})',
      );
      if (e.code == '42501') {
        throw const MarketplaceException(
          'Debes verificar tu identidad estudiantil con carné o contar con una cuenta comercial aprobada para publicar.',
          code: '42501',
        );
      }
      if (e.code == '23514') {
        throw MarketplaceException(e.message, code: '23514');
      }
      throw MarketplaceException(e.message, code: e.code);
    } catch (e) {
      debugPrint('Error al crear publicación de marketplace: $e');
      if (e is MarketplaceException) rethrow;
      rethrow;
    }
  }

  static Future<bool> reportListing({
    required String itemId,
    required String reason,
    String? sellerUserId,
    String? sellerAlias,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      throw Exception('La aplicación no está conectada a la base de datos.');
    }

    try {
      final result = await SupabaseService.client
          .rpc(
            'report_marketplace_item',
            params: {
              'target_item_id': itemId,
              'report_reason': reason.trim(),
              'target_seller_id': sellerUserId,
              'target_seller_alias': sellerAlias,
            },
          )
          .catchError((_) async {
            await SupabaseService.client.from('entity_reports').insert({
              'reporter_id': SupabaseService.currentUserId,
              'entity_type': 'marketplace_item',
              'entity_id': itemId,
              'entity_owner_id':
                  (sellerUserId != null && sellerUserId.isNotEmpty)
                      ? sellerUserId
                      : null,
              'reason': reason.trim(),
              'moderation_status': 0,
              'metadata': {'seller_alias': sellerAlias},
            });
            return true;
          });

      return result == true;
    } catch (e) {
      debugPrint('Error al reportar publicación de marketplace: $e');
      return false;
    }
  }

  static Future<bool> moderateListing({
    required String itemId,
    required int newStatus, // 0: Activo, 1: En revisión, 2: Oculto
  }) async {
    if (!SupabaseConfig.isConfigured) {
      throw Exception('La aplicación no está conectada a la base de datos.');
    }

    try {
      final res = await SupabaseService.client.rpc(
        'moderate_marketplace_item',
        params: {'target_item_id': itemId, 'new_status': newStatus},
      );

      await CacheService.invalidateAll(_cacheNamespace);
      return res == true;
    } catch (e) {
      debugPrint('Error al moderar publicación: $e');
      return false;
    }
  }

  static Future<bool> updateItemStatus({
    required String itemId,
    required String newStatus, // available, reserved, sold, paused
  }) async {
    if (!SupabaseConfig.isConfigured) {
      throw const MarketplaceException(
        'La aplicación no está conectada a la base de datos.',
      );
    }

    const allowedStatuses = {'available', 'reserved', 'sold', 'paused'};
    if (!allowedStatuses.contains(newStatus)) return false;

    try {
      final updated = await SupabaseService.client
          .from('marketplace_items')
          .update({'status': newStatus})
          .eq('id', itemId)
          .select('id');
      if (updated.isEmpty) return false;
      await CacheService.invalidateAll(_cacheNamespace);
      return true;
    } on PostgrestException catch (e) {
      debugPrint('Error Postgrest actualizando estado del artículo: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Error actualizando estado del artículo: $e');
      return false;
    }
  }

  static Future<bool> requestSponsorship({
    required String brandName,
    required String contactName,
    required String contactPhone,
    required String email,
    required String proposalDetails,
    required String expectedPlacement,
    String? planId,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      throw Exception('La aplicación no está conectada a la base de datos.');
    }

    try {
      final payload = {
        'brand_name': brandName.trim(),
        'contact_name': contactName.trim(),
        'contact_phone': contactPhone.trim(),
        'email': email.trim(),
        'proposal_details': proposalDetails.trim(),
        'expected_placement': expectedPlacement.trim(),
        'user_id': SupabaseService.currentUserId,
        'status': 'pending',
      };
      if (planId != null && planId.trim().isNotEmpty) {
        payload['plan_id'] = planId.trim();
      }

      await SupabaseService.client.from('sponsor_requests').insert(payload);
      return true;
    } catch (e) {
      debugPrint('Error al enviar solicitud de patrocinio: $e');
      return false;
    }
  }

  static Future<bool> toggleUpvote(MarketplaceItem item) async {
    if (!SupabaseConfig.isConfigured) {
      throw Exception('La aplicación no está conectada a la base de datos.');
    }
    final currentUserId = SupabaseService.currentUserId;
    if (currentUserId == null) return item.isUpvotedByMe;

    try {
      if (item.isUpvotedByMe) {
        await SupabaseService.client
            .from('marketplace_upvotes')
            .delete()
            .eq('item_id', item.id)
            .eq('user_id', currentUserId);

        await CacheService.invalidateAll(_cacheNamespace);
        return false;
      } else {
        await SupabaseService.client.from('marketplace_upvotes').insert({
          'item_id': item.id,
          'user_id': currentUserId,
        });

        await CacheService.invalidateAll(_cacheNamespace);
        return true;
      }
    } catch (e) {
      debugPrint('Error procesando upvote en marketplace: $e');
      return item.isUpvotedByMe;
    }
  }
}
