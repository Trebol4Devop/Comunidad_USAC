import 'package:flutter/foundation.dart';
import '../config/supabase_config.dart';
import '../models/whatsapp_group.dart';
import 'supabase_service.dart';

class GroupsService {
  static Future<List<WhatsAppGroup>> fetchGroups({
    String carrera = 'todas',
    String searchQuery = '',
  }) async {
    if (!SupabaseConfig.isConfigured) return _getSampleGroups();

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

      return data.map((item) {
        final map = Map<String, dynamic>.from(item);
        final groupId = map['id'].toString();
        return WhatsAppGroup.fromMap(
          map,
          isUpvotedByMe: upvotedGroupIds.contains(groupId),
        );
      }).toList();
    } catch (e) {
      debugPrint('Error al obtener grupos estudiantiles: $e');
      return _getSampleGroups();
    }
  }

  static Future<bool> toggleUpvote(WhatsAppGroup group) async {
    final currentUserId = SupabaseService.currentUserId;
    if (currentUserId == null || !SupabaseConfig.isConfigured) return !group.isUpvotedByMe;

    try {
      if (group.isUpvotedByMe) {
        // Remove upvote (PostgreSQL trigger automatically syncs counter)
        await SupabaseService.client
            .from('student_group_upvotes')
            .delete()
            .eq('group_id', group.id)
            .eq('user_id', currentUserId);

        return false;
      } else {
        // Add upvote (PostgreSQL trigger automatically syncs counter)
        await SupabaseService.client.from('student_group_upvotes').insert({
          'group_id': group.id,
          'user_id': currentUserId,
        });

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
      return WhatsAppGroup(
        id: 'local-${DateTime.now().millisecondsSinceEpoch}',
        title: title.trim(),
        carrera: carrera,
        curso: curso.trim(),
        section: section.trim().isEmpty ? 'Sección Única' : section.trim(),
        link: link.trim(),
        description: description.trim(),
        authorAlias: authorAlias.trim(),
        imageUrl: imageUrl?.trim().isEmpty == true ? null : imageUrl?.trim(),
        upvotes: 1,
        reportedCount: 0,
        createdAt: DateTime.now(),
        isUpvotedByMe: true,
      );
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
    if (!SupabaseConfig.isConfigured) return true;

    try {
      await SupabaseService.client.from('student_group_reports').insert({
        'group_id': groupId,
        'user_id': SupabaseService.currentUserId,
        'reason': reason.trim(),
      });

      return true;
    } catch (e) {
      debugPrint('Error al reportar grupo: $e');
      return false;
    }
  }

  static List<WhatsAppGroup> _getSampleGroups() {
    return [
      WhatsAppGroup(
        id: 'sample-1',
        title: 'Matemática Básica 1 - Sección A (Ing. Pérez)',
        carrera: 'area_comun',
        curso: 'Matemática Básica 1',
        section: 'Sección A',
        link: 'https://chat.whatsapp.com/sample_link_mate1',
        description: 'Grupo estudiantil para resolución de dudas, tareas y parciales.',
        authorAlias: 'Estudiante MB #204',
        upvotes: 18,
        reportedCount: 0,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        isUpvotedByMe: false,
      ),
      WhatsAppGroup(
        id: 'sample-2',
        title: 'Estructuras de Datos - Proyectos y Debates C++',
        carrera: 'sistemas',
        curso: 'Estructuras de Datos',
        section: 'Sección Única',
        link: 'https://discord.gg/sample_link_edd',
        description: 'Servidor de Discord para debatir proyectos, punteros y árboles binarios.',
        authorAlias: 'Estudiante Sistemas #811',
        upvotes: 34,
        reportedCount: 0,
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        isUpvotedByMe: true,
      ),
    ];
  }
}
