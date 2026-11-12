import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/forum/models/discord_forum_models.dart';

class ForumServerPreferencesService {
  static const _key = 'zanate_forum_selected_servers';

  static Future<List<ForumServer>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_key);
    if (saved == null || saved.isEmpty) return const [];

    try {
      final decoded = jsonDecode(saved) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(_fromJson)
          .where((server) => server != null && !server.isGroups)
          .cast<ForumServer>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> save(List<ForumServer> servers) async {
    final preferences = await SharedPreferences.getInstance();
    final userServers = servers.where((server) => !server.isGroups).toList();
    await preferences.setString(
      _key,
      jsonEncode(userServers.map(_toJson).toList()),
    );
  }

  static Map<String, Object?> _toJson(ForumServer server) => {
    'id': server.id,
    'name': server.name,
    'shortCode': server.shortCode,
    'facultadId': server.facultadId,
    'carreraId': server.carreraId,
    'description': server.description,
    'color': server.color.toARGB32(),
    'memberCount': server.memberCount,
    'logoAsset': server.resolvedLogoAsset,
  };

  static IconData _iconForFaculty(String facultyId) {
    if (facultyId == 'todas') return Icons.school;
    for (final faculty in ForumFaculty.defaultFaculties) {
      if (faculty.id == facultyId) return faculty.icon;
    }
    return Icons.school;
  }

  static ForumServer? _fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final shortCode = json['shortCode'];

    final facultadId = json['facultadId'];
    final carreraId = json['carreraId'];
    final description = json['description'];
    final color = json['color'];
    if (id is! String ||
        name is! String ||
        shortCode is! String ||
        facultadId is! String ||
        carreraId is! String ||
        description is! String ||
        color is! int) {
      return null;
    }

    final memberCount = json['memberCount'];
    final logoAsset = json['logoAsset'] as String?;
    return ForumServer(
      id: id,
      name: name,
      shortCode: shortCode,
      icon: _iconForFaculty(facultadId),
      facultadId: facultadId,
      carreraId: carreraId,
      description: description,
      color: Color(color),
      memberCount: memberCount is int ? memberCount : null,
      logoAsset: logoAsset ?? ForumServer.getLogoAssetFor(id: id, facultadId: facultadId),
    );
  }
}
