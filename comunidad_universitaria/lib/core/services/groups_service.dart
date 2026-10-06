import 'package:flutter/foundation.dart';
import '../config/supabase_config.dart';
import '../models/whatsapp_group.dart';
import 'cache_service.dart';
import 'supabase_service.dart';

class GroupsService {
  static const String _cacheNamespace = 'student_groups';

  static const Map<String, List<String>> _facultyAliases = {
    '08': ['sistemas', 'civil', 'industrial', 'mecanica', 'quimica', 'electronica', 'ingenieria', 'fi', 'area_comun', 'basicas'],
    '05': ['medicina', 'salud', 'medicas', 'cirujano', 'cum'],
    '04': ['derecho', 'juridicas', 'leyes', 'sociales'],
    '03': ['economicas', 'auditoria', 'administracion', 'economia'],
    '02': ['arquitectura', 'diseno', 'farq'],
    '01': ['agronomia', 'ambiental', 'agricola', 'fausac'],
    '06': ['farmacia', 'bioquimica', 'quimica', 'quimicas', 'farmaceutica'],
    '77': ['humanidades', 'pedagogia', 'profesorado', 'filosofia', 'letras', 'fahusac'],
    '07': ['humanidades', 'pedagogia', 'profesorado', 'filosofia', 'letras', 'fahusac'],
    '09': ['odontologia', 'dental', 'fousac'],
    '10': ['veterinaria', 'zootecnia', 'fmvz'],
    'area_comun': ['area_comun', 'basicas'],
  };

  static Future<List<WhatsAppGroup>> fetchGroups({
    String facultad = 'todas',
    String carrera = 'todas',
    String searchQuery = '',
  }) async {
    final isDefaultQuery = facultad == 'todas' && carrera == 'todas' && searchQuery.trim().isEmpty;
    final cacheKey = CacheService.buildKey({
      'user': SupabaseService.currentUserId ?? 'anon',
      if (facultad != 'todas') 'facultad': facultad,
      'carrera': carrera,
      'search': searchQuery.trim().toLowerCase(),
    });

    final cached = CacheService.get<List<WhatsAppGroup>>(_cacheNamespace, cacheKey);
    if (cached != null) return List<WhatsAppGroup>.from(cached);

    if (!SupabaseConfig.isConfigured) {
      throw Exception('La aplicación no está conectada a la base de datos.');
    }

    if (isDefaultQuery) {
      final persisted = await _readPersistedGroups(cacheKey);
      if (persisted != null) return persisted;
    }

    try {
      var query = SupabaseService.client
          .from('student_groups')
          .select('*')
          .lt('moderation_status', 2);

      if (carrera != 'todas') {
        query = query.eq('carrera', carrera);
      }

      if (searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query.or('title.ilike.%$q%,curso.ilike.%$q%,description.ilike.%$q%');
      }

      final response = await query.order('upvotes', ascending: false).order('created_at', ascending: false);
      final List<dynamic> data = response as List<dynamic>;

      // Get upvotes for current user
      final currentUserId = SupabaseService.currentUserId;
      final Set<String> upvotedGroupIds = {};

      if (currentUserId != null && data.isNotEmpty) {
        final groupIds = data.map((item) => item['id'].toString()).toList();
        final upvotesRes = await SupabaseService.client
            .from('student_group_upvotes')
            .select('group_id')
            .eq('user_id', currentUserId)
            .inFilter('group_id', groupIds);

        for (var item in upvotesRes) {
          upvotedGroupIds.add(item['group_id'].toString());
        }
      }

      var groups = data.map((item) {
        final map = Map<String, dynamic>.from(item);
        final groupId = map['id'].toString();
        return WhatsAppGroup.fromMap(
          map,
          isUpvotedByMe: upvotedGroupIds.contains(groupId),
        );
      }).toList();

      if (facultad != 'todas' && carrera == 'todas') {
        final facultyKeywords = _facultyAliases[facultad] ?? [];
        groups = groups.where((g) {
          // 1. La carrera inicia con el código de la facultad (ej. 08, 08-01-01, 08_todas)
          if (g.carrera.startsWith(facultad)) return true;

          // 2. Si la carrera coincide con algún alias de la facultad (ej. 'sistemas', 'civil', etc.)
          final carreraLower = g.carrera.toLowerCase().trim();
          if (carreraLower.isNotEmpty &&
              carreraLower != 'todas' &&
              facultyKeywords.any((kw) => carreraLower == kw || carreraLower.contains(kw))) {
            return true;
          }

          // 3. Caso especial de Área Común (Ingeniería o general)
          if (carreraLower == 'area_comun' && (facultad == '08' || facultad == 'area_comun')) {
            return true;
          }

          // 4. Si la carrera fue registrada como 'todas' o vacía, SOLO se incluye si su título, curso
          // o descripción menciona explícitamente palabras clave de esta facultad específica (evitando
          // que grupos de otras facultades o grupos globales USAC se cuelen en este servidor).
          if (carreraLower == 'todas' || carreraLower.isEmpty) {
            final searchable = '${g.title} ${g.curso} ${g.description}'.toLowerCase();
            return facultyKeywords.any((kw) => searchable.contains(kw));
          }

          return false;
        }).toList();
      }

      CacheService.set(_cacheNamespace, cacheKey, List<WhatsAppGroup>.from(groups));
      if (isDefaultQuery) {
        await CacheService.setPersisted(
          _cacheNamespace,
          cacheKey,
          groups.map(_groupToCacheMap).toList(),
        );
      }
      return groups;
    } catch (e) {
      debugPrint('Error al obtener grupos estudiantiles: $e');
      if (isDefaultQuery) {
        final persisted = await _readPersistedGroups(cacheKey);
        if (persisted != null) return persisted;
      }
      rethrow;
    }
  }

  /// Lee la primera página persistida (solo consultas por defecto).
  static Future<List<WhatsAppGroup>?> _readPersistedGroups(String cacheKey) {
    return CacheService.getPersisted<List<WhatsAppGroup>>(
      _cacheNamespace,
      cacheKey,
      (data) {
        if (data is! List) throw const FormatException('Caché de grupos inválida');
        return data
            .whereType<Map>()
            .map((item) => _groupFromCacheMap(Map<String, dynamic>.from(item)))
            .toList();
      },
    );
  }

  static Map<String, dynamic> _groupToCacheMap(WhatsAppGroup group) {
    final map = group.toInsertMap();
    map['id'] = group.id;
    map['created_at'] = group.createdAt.toIso8601String();
    map['cache_upvoted'] = group.isUpvotedByMe;
    return map;
  }

  static WhatsAppGroup _groupFromCacheMap(Map<String, dynamic> map) {
    return WhatsAppGroup.fromMap(map, isUpvotedByMe: map['cache_upvoted'] == true);
  }

  static Future<bool> toggleUpvote(WhatsAppGroup group) async {
    if (!SupabaseConfig.isConfigured) {
      throw Exception('La aplicación no está conectada a la base de datos.');
    }
    final currentUserId = SupabaseService.currentUserId;
    if (currentUserId == null) return group.isUpvotedByMe;

    try {
      if (group.isUpvotedByMe) {
        // Remove upvote (PostgreSQL trigger automatically syncs counter)
        await SupabaseService.client
            .from('student_group_upvotes')
            .delete()
            .eq('group_id', group.id)
            .eq('user_id', currentUserId);

        await CacheService.invalidateAll(_cacheNamespace);
        return false;
      } else {
        // Add upvote (PostgreSQL trigger automatically syncs counter)
        await SupabaseService.client.from('student_group_upvotes').insert({
          'group_id': group.id,
          'user_id': currentUserId,
        });

        await CacheService.invalidateAll(_cacheNamespace);
        return true;
      }
    } catch (e) {
      debugPrint('Error procesando upvote de grupo: $e');
      return group.isUpvotedByMe;
    }
  }

  static Future<WhatsAppGroup?> createGroup({
    required String title,
    required String carrera,
    required String curso,
    required String section,
    required String link,
    required String description,
    required String authorAlias,
    String? imageUrl,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      throw Exception('La aplicación no está conectada a la base de datos.');
    }

    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      throw Exception('Debes iniciar sesión para compartir un grupo estudiantil.');
    }

    try {
      final platform = WhatsAppGroup.stringToPlatform(null, link);
      final groupMap = {
        'title': title.trim(),
        'carrera': carrera,
        'curso': curso.trim(),
        'section': section.trim().isEmpty ? 'Sección Única' : section.trim(),
        'link': link.trim(),
        'platform': WhatsAppGroup.platformToString(platform),
        'description': description.trim(),
        'author_alias': authorAlias.trim(),
        'user_id': userId,
        'image_url': imageUrl?.trim().isEmpty == true ? null : imageUrl?.trim(),
        'upvotes': 1, // Start with 1 upvote from creator
        'reported_count': 0,
        'moderation_status': 0,
      };

      final res = await SupabaseService.client
          .from('student_groups')
          .insert(groupMap)
          .select()
          .single();

      final created = WhatsAppGroup.fromMap(Map<String, dynamic>.from(res), isUpvotedByMe: true);

      // Auto-upvote for creator
      await SupabaseService.client.from('student_group_upvotes').insert({
        'group_id': created.id,
        'user_id': userId,
      });

      await CacheService.invalidateAll(_cacheNamespace);
      return created;
    } catch (e) {
      debugPrint('Error al crear grupo: $e');
      rethrow;
    }
  }

  static Future<bool> reportGroup({
    required String groupId,
    required String reason,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      throw Exception('La aplicación no está conectada a la base de datos.');
    }

    try {
      await SupabaseService.client.from('entity_reports').insert({
        'reporter_id': SupabaseService.currentUserId,
        'entity_type': 'group',
        'entity_id': groupId,
        'reason': reason.trim(),
        'moderation_status': 0,
      });

      return true;
    } catch (e) {
      debugPrint('Error al reportar grupo: $e');
      return false;
    }
  }
}
