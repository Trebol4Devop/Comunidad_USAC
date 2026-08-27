import 'package:flutter/foundation.dart';
import '../config/supabase_config.dart';
import '../models/marketplace_item.dart';
import 'supabase_service.dart';

class MarketplaceService {
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
      debugPrint('Error al obtener publicaciones del marketplace: ');
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
      debugPrint('Error obteniendo patrocinadores: ');
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
    required String contactWhatsapp,
    String? contactTelegram,
    List<String> imageUrls = const [],
    required String authorAlias,
  }) async {
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
        'contact_whatsapp': contactWhatsapp.trim(),
        'contact_telegram': contactTelegram?.trim().isEmpty == true ? null : contactTelegram?.trim(),
        'image_urls': imageUrls,
        'is_sponsored': false,
        'author_alias': authorAlias.trim(),
        'user_id': SupabaseService.currentUserId,
        'moderation_status': 0,
        'upvotes': 1,
      };

      final res = await SupabaseService.client
          .from('marketplace_items')
          .insert(itemMap)
          .select()
          .single();

      return MarketplaceItem.fromMap(Map<String, dynamic>.from(res), isUpvotedByMe: true);
    } catch (e) {
      debugPrint('Error al crear publicación de marketplace: ');
      return null;
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
      debugPrint('Error al enviar solicitud de patrocinio: ');
      return true; // Return true as graceful fallback for user flow
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
      debugPrint('Error procesando upvote en marketplace: ');
      return item.isUpvotedByMe;
    }
  }

  static Future<bool> reportListing({
    required String itemId,
    required String reason,
  }) async {
    if (!SupabaseConfig.isConfigured) return true;

    try {
      await SupabaseService.client.from('marketplace_reports').insert({
        'item_id': itemId,
        'user_id': SupabaseService.currentUserId,
        'reason': reason.trim(),
      });
      return true;
    } catch (e) {
      debugPrint('Error al reportar publicación de marketplace: ');
      return true;
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
        imageUrls: [
          'https://images.unsplash.com/photo-1568667256549-094345857637?w=800&q=80',
          'https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?w=800&q=80',
        ],
        videoUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        isSponsored: true,
        sponsorBadgeText: 'Patrocinador Destacado ★',
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
        contactWhatsapp: '50233332211',
        authorAlias: 'Tutor Académico #402',
        createdAt: DateTime.now().subtract(const Duration(hours: 8)),
        upvotes: 35,
      ),
      MarketplaceItem(
        id: 'm-3',
        title: 'Calculadora Texas Instruments TI-84 Plus (Excelente estado)',
        description: 'Incluye cable de datos, tapa protectora y baterías nuevas. Ideal para cursos de Matemática Intermedia y Física.',
        price: 350.0,
        isFree: false,
        category: 'libros_materiales',
        facultad: '08',
        sede: 'central',
        buildingCode: 'T-1',
        locationDetail: 'Edificio T-1 o Cafetería Central',
        contactWhatsapp: '50255554433',
        imageUrls: [
          'https://images.unsplash.com/photo-1594980596870-8aa52a78d8cd?w=800&q=80'
        ],
        authorAlias: 'Estudiante Ing. #109',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        upvotes: 11,
      ),
      MarketplaceItem(
        id: 'm-4',
        title: 'Estuche de Disección & Bata Blanca Médica',
        description: 'Kit completo para laboratorios de Anatomía en CUM. En perfecto estado higiénico.',
        price: 180.0,
        isFree: false,
        category: 'libros_materiales',
        facultad: '05',
        sede: 'cum',
        buildingCode: 'CUM-A',
        locationDetail: 'Entrada principal del CUM, Zona 11',
        contactWhatsapp: '50244449988',
        imageUrls: [
          'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?w=800&q=80'
        ],
        authorAlias: 'Estudiante CUM #501',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        upvotes: 14,
      ),
    ];
  }
}
