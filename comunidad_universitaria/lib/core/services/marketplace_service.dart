import 'package:flutter/foundation.dart';
import '../config/supabase_config.dart';
import '../models/marketplace_item.dart';
import 'supabase_service.dart';

class MarketplaceService {
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

  static String? validateContent({required String title, required String description}) {
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
    bool onlyFree = false,
    String searchQuery = '',
  }) async {
    if (!SupabaseConfig.isConfigured) {
      return _filterSampleListings(
        category: category,
        facultad: facultad,
        sede: sede,
        onlyFree: onlyFree,
        searchQuery: searchQuery,
      );
    }

    try {
      var query = SupabaseService.client
          .from('marketplace_items')
          .select('*')
          .lt('moderation_status', 2);

      if (category != 'todos') {
        query = query.eq('category', category);
      }

      if (facultad != 'todas') {
        query = query.eq('facultad', facultad);
      }

      if (sede != 'todas') {
        query = query.eq('sede', sede);
      }

      if (onlyFree) {
        query = query.or('is_free.eq.true,price.lte.0');
      }

      if (searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query.or('title.ilike.%$q%,description.ilike.%$q%,building_code.ilike.%$q%');
      }

      final response = await query
          .order('is_sponsored', ascending: false)
          .order('created_at', ascending: false)
          .limit(60);

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

      return data.map((item) {
        final map = Map<String, dynamic>.from(item);
        final itemId = map['id'].toString();
        return MarketplaceItem.fromMap(
          map,
          isUpvotedByMe: upvotedItemIds.contains(itemId),
        );
      }).toList();
    } catch (e) {
      debugPrint('Error al obtener publicaciones del marketplace: $e');
      return _filterSampleListings(
        category: category,
        facultad: facultad,
        sede: sede,
        onlyFree: onlyFree,
        searchQuery: searchQuery,
      );
    }
  }

  static Future<List<MarketplaceItem>> fetchSponsoredListings() async {
    if (!SupabaseConfig.isConfigured) {
      return _getSampleListings().where((item) => item.isSponsored).toList();
    }

    try {
      final response = await SupabaseService.client
          .from('marketplace_items')
          .select('*')
          .eq('is_sponsored', true)
          .lt('moderation_status', 2)
          .order('created_at', ascending: false)
          .limit(10);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((item) => MarketplaceItem.fromMap(Map<String, dynamic>.from(item))).toList();
    } catch (e) {
      debugPrint('Error obteniendo patrocinadores: $e');
      return _getSampleListings().where((item) => item.isSponsored).toList();
    }
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
    final violationError = validateContent(title: title, description: description);
    if (violationError != null) {
      throw Exception(violationError);
    }

    if (!SupabaseConfig.isConfigured) return null;

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
        'contact_whatsapp': contactWhatsapp?.trim().isEmpty == true ? null : contactWhatsapp?.trim(),
        'contact_instagram': contactInstagram?.trim().isEmpty == true ? null : contactInstagram?.trim(),
        'contact_messenger': contactMessenger?.trim().isEmpty == true ? null : contactMessenger?.trim(),
        'contact_telegram': contactTelegram?.trim().isEmpty == true ? null : contactTelegram?.trim(),
        'social_links': socialLinks,
        'image_urls': imageUrls,
        'video_url': videoUrl?.trim().isEmpty == true ? null : videoUrl?.trim(),
        'is_sponsored': isSponsored,
        'sponsor_badge_text': sponsorBadgeText,
        'author_alias': authorAlias.trim(),
        'user_id': SupabaseService.currentUserId,
        'moderation_status': 0,
        'reported_count': 0,
        'upvotes': 1,
      };

      final res = await SupabaseService.client
          .from('marketplace_items')
          .insert(itemMap)
          .select()
          .single();

      return MarketplaceItem.fromMap(Map<String, dynamic>.from(res), isUpvotedByMe: true);
    } catch (e) {
      debugPrint('Error al crear publicación de marketplace: $e');
      rethrow;
    }
  }

  static Future<bool> reportListing({
    required String itemId,
    required String reason,
    String? sellerUserId,
    String? sellerAlias,
  }) async {
    if (!SupabaseConfig.isConfigured) return true;

    try {
      // 1. Call RPC in Supabase with auto-moderation threshold
      await SupabaseService.client.rpc('report_marketplace_item', params: {
        'target_item_id': itemId,
        'report_reason': reason.trim(),
        'target_seller_id': sellerUserId,
        'target_seller_alias': sellerAlias,
      }).catchError((_) async {
        // Fallback standard insert
        await SupabaseService.client.from('marketplace_reports').insert({
          'item_id': itemId,
          'user_id': SupabaseService.currentUserId,
          'reason': reason.trim(),
          'seller_user_id': sellerUserId,
          'seller_alias': sellerAlias,
        });
      });

      // 2. Also register in general user_reports if seller is registered
      if (sellerUserId != null) {
        await SupabaseService.client.from('user_reports').insert({
          'reporter_id': SupabaseService.currentUserId,
          'reported_user_id': sellerUserId,
          'reported_user_alias': sellerAlias ?? 'Vendedor',
          'reason': 'Marketplace: $reason',
        }).catchError((_) {});
      }

      return true;
    } catch (e) {
      debugPrint('Error al reportar publicación de marketplace: $e');
      return true;
    }
  }

  static Future<bool> moderateListing({
    required String itemId,
    required int newStatus, // 0: Activo, 1: En revisión, 2: Oculto
  }) async {
    if (!SupabaseConfig.isConfigured) return false;

    try {
      final res = await SupabaseService.client.rpc('moderate_marketplace_item', params: {
        'target_item_id': itemId,
        'new_status': newStatus,
      }).catchError((_) async {
        await SupabaseService.client
            .from('marketplace_items')
            .update({'moderation_status': newStatus})
            .eq('id', itemId);
        return true;
      });

      return res == true;
    } catch (e) {
      debugPrint('Error al moderar publicación: $e');
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
  }) async {
    if (!SupabaseConfig.isConfigured) return true;

    try {
      await SupabaseService.client.from('sponsor_requests').insert({
        'brand_name': brandName.trim(),
        'contact_name': contactName.trim(),
        'contact_phone': contactPhone.trim(),
        'email': email.trim(),
        'proposal_details': proposalDetails.trim(),
        'expected_placement': expectedPlacement.trim(),
        'user_id': SupabaseService.currentUserId,
        'status': 'pending',
      });
      return true;
    } catch (e) {
      debugPrint('Error al enviar solicitud de patrocinio: $e');
      return true;
    }
  }

  static Future<bool> toggleUpvote(MarketplaceItem item) async {
    final currentUserId = SupabaseService.currentUserId;
    if (currentUserId == null || !SupabaseConfig.isConfigured) return !item.isUpvotedByMe;

    try {
      if (item.isUpvotedByMe) {
        await SupabaseService.client
            .from('marketplace_upvotes')
            .delete()
            .eq('item_id', item.id)
            .eq('user_id', currentUserId);

        final newUpvotes = (item.upvotes - 1).clamp(0, 999999);
        await SupabaseService.client
            .from('marketplace_items')
            .update({'upvotes': newUpvotes})
            .eq('id', item.id);

        return false;
      } else {
        await SupabaseService.client.from('marketplace_upvotes').insert({
          'item_id': item.id,
          'user_id': currentUserId,
        });

        final newUpvotes = item.upvotes + 1;
        await SupabaseService.client
            .from('marketplace_items')
            .update({'upvotes': newUpvotes})
            .eq('id', item.id);

        return true;
      }
    } catch (e) {
      debugPrint('Error procesando upvote en marketplace: $e');
      return item.isUpvotedByMe;
    }
  }

  static List<MarketplaceItem> _filterSampleListings({
    String category = 'todos',
    String facultad = 'todas',
    String sede = 'todas',
    bool onlyFree = false,
    String searchQuery = '',
  }) {
    var list = _getSampleListings();

    if (category != 'todos') {
      list = list.where((i) => i.category == category).toList();
    }

    if (facultad != 'todas') {
      list = list.where((i) => i.facultad == facultad || i.facultad == 'todas').toList();
    }

    if (sede != 'todas') {
      list = list.where((i) => i.sede == sede || i.sede == 'todas').toList();
    }

    if (onlyFree) {
      list = list.where((i) => i.isFree || i.price <= 0).toList();
    }

    if (searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase().trim();
      list = list.where((i) {
        return i.title.toLowerCase().contains(q) ||
            i.description.toLowerCase().contains(q) ||
            i.buildingCode.toLowerCase().contains(q);
      }).toList();
    }

    return list;
  }

  static List<MarketplaceItem> _getSampleListings() {
    return [
      MarketplaceItem(
        id: 'sponsor-1',
        title: 'Librería & Copistería Universitaria — Impresiones y Empastados',
        description: 'Servicio de fotocopias, ploteo de planos para Arquitectura e Ingeniería, empastados de tesis y venta de útiles. Descuento especial para estudiantes mostrando este anuncio.',
        price: 0.0,
        isFree: false,
        category: 'servicios_estudiantiles',
        facultad: '08',
        sede: 'central',
        buildingCode: 'T-3',
        locationDetail: 'Frente al Edificio T-3, Campus Central',
        contactWhatsapp: '50255550199',
        contactInstagram: 'libreria_central_usac',
        socialLinks: ['https://facebook.com/libreriacentralusac'],
        imageUrls: [
          'https://images.unsplash.com/photo-1568667256549-094345857637?w=800&q=80',
          'https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?w=800&q=80',
        ],
        videoUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        isSponsored: true,
        sponsorBadgeText: 'Patrocinador Destacado',
        authorAlias: 'Librería Central',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        upvotes: 42,
      ),
      MarketplaceItem(
        id: 'm-1',
        title: 'Pastel de Zanahoria & Brownies Artesanales',
        description: 'Porciones individuales recién horneadas. Entregas durante el cambio de período entre 10:00 AM y 2:00 PM.',
        price: 12.0,
        isFree: false,
        category: 'comida_postres',
        facultad: '08',
        sede: 'central',
        buildingCode: 'T-3',
        locationDetail: 'Bancas del Edificio T-3 y Plaza de los Mártires',
        contactWhatsapp: '50244441122',
        contactInstagram: 'postres_sancarlistas',
        socialLinks: ['https://instagram.com/p/sample_post'],
        imageUrls: [
          'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=800&q=80'
        ],
        authorAlias: 'Postres Sancarlistas',
        createdAt: DateTime.now().subtract(const Duration(hours: 4)),
        upvotes: 19,
      ),
      MarketplaceItem(
        id: 'm-2',
        title: 'Tutoría Gratuita de Matemática Básica 1 y 2 (Repaso de Parcial)',
        description: 'Sesión colaborativa en cubículos de Biblioteca Central. Revisaremos temas de límites, derivadas e integrales básicas sin costo.',
        price: 0.0,
        isFree: true,
        category: 'tutorias_academica',
        facultad: '08',
        sede: 'central',
        buildingCode: 'BIBLIO',
        locationDetail: 'Cubículos de estudio, Biblioteca Central',
        contactTelegram: 'tutor_mate_usac',
        authorAlias: 'Tutor Académico #402',
        createdAt: DateTime.now().subtract(const Duration(hours: 8)),
        upvotes: 35,
      ),
    ];
  }
}
