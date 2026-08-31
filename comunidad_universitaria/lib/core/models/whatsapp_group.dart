enum GroupPlatform {
  whatsApp,
  telegram,
  discord,
  drive,
  other,
}

class WhatsAppGroup {
  final String id;
  final String title;
  final String carrera;
  final String curso;
  final String section;
  final String link;
  final String description;
  final String? userId;
  final String authorAlias;
  final int upvotes;
  final int reportedCount;
  final DateTime createdAt;
  final String? imageUrl;
  final int moderationStatus;
  final bool isUpvotedByMe;

  WhatsAppGroup({
    required this.id,
    required this.title,
    required this.carrera,
    required this.curso,
    required this.section,
    required this.link,
    required this.description,
    this.userId,
    required this.authorAlias,
    required this.upvotes,
    required this.reportedCount,
    required this.createdAt,
    this.imageUrl,
    this.moderationStatus = 0,
    this.isUpvotedByMe = false,
  });

  static String platformToString(GroupPlatform p) {
    switch (p) {
      case GroupPlatform.whatsApp:
        return 'whatsapp';
      case GroupPlatform.telegram:
        return 'telegram';
      case GroupPlatform.discord:
        return 'discord';
      case GroupPlatform.drive:
        return 'drive';
      case GroupPlatform.other:
        return 'otro';
    }
  }

  static GroupPlatform stringToPlatform(String? p, String link) {
    if (p != null && p.isNotEmpty) {
      switch (p.toLowerCase()) {
        case 'whatsapp':
          return GroupPlatform.whatsApp;
        case 'telegram':
          return GroupPlatform.telegram;
        case 'discord':
          return GroupPlatform.discord;
        case 'drive':
          return GroupPlatform.drive;
        case 'otro':
          return GroupPlatform.other;
      }
    }
    final lower = link.toLowerCase();
    if (lower.contains('chat.whatsapp.com') || lower.contains('wa.me')) {
      return GroupPlatform.whatsApp;
    }
    if (lower.contains('t.me') || lower.contains('telegram.me')) {
      return GroupPlatform.telegram;
    }
    if (lower.contains('discord.gg') || lower.contains('discord.com')) {
      return GroupPlatform.discord;
    }
    if (lower.contains('drive.google.com') || lower.contains('docs.google.com')) {
      return GroupPlatform.drive;
    }
    return GroupPlatform.other;
  }

  GroupPlatform get platform => stringToPlatform(null, link);

  WhatsAppGroup copyWith({
    String? id,
    String? title,
    String? carrera,
    String? curso,
    String? section,
    String? link,
    String? description,
    String? userId,
    String? authorAlias,
    int? upvotes,
    int? reportedCount,
    DateTime? createdAt,
    String? imageUrl,
    int? moderationStatus,
    bool? isUpvotedByMe,
  }) {
    return WhatsAppGroup(
      id: id ?? this.id,
      title: title ?? this.title,
      carrera: carrera ?? this.carrera,
      curso: curso ?? this.curso,
      section: section ?? this.section,
      link: link ?? this.link,
      description: description ?? this.description,
      userId: userId ?? this.userId,
      authorAlias: authorAlias ?? this.authorAlias,
      upvotes: upvotes ?? this.upvotes,
      reportedCount: reportedCount ?? this.reportedCount,
      createdAt: createdAt ?? this.createdAt,
      imageUrl: imageUrl ?? this.imageUrl,
      moderationStatus: moderationStatus ?? this.moderationStatus,
      isUpvotedByMe: isUpvotedByMe ?? this.isUpvotedByMe,
    );
  }

  factory WhatsAppGroup.fromMap(Map<String, dynamic> map, {bool isUpvotedByMe = false}) {
    return WhatsAppGroup(
      id: map['id']?.toString() ?? '',
      title: map['title'] ?? '',
      carrera: map['carrera'] ?? 'todas',
      curso: map['curso'] ?? '',
      section: map['section'] ?? 'Sección Única',
      link: map['link'] ?? '',
      description: map['description'] ?? '',
      userId: map['user_id']?.toString(),
      authorAlias: map['author_alias'] ?? 'Estudiante USAC',
      upvotes: (map['upvotes'] is int)
          ? map['upvotes']
          : int.tryParse(map['upvotes']?.toString() ?? '0') ?? 0,
      reportedCount: (map['reported_count'] is int)
          ? map['reported_count']
          : int.tryParse(map['reported_count']?.toString() ?? '0') ?? 0,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      imageUrl: map['image_url'],
      moderationStatus: (map['moderation_status'] is int)
          ? map['moderation_status']
          : int.tryParse(map['moderation_status']?.toString() ?? '0') ?? 0,
      isUpvotedByMe: isUpvotedByMe,
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'title': title,
      'carrera': carrera,
      'curso': curso,
      'section': section,
      'link': link,
      'platform': platformToString(platform),
      'description': description,
      'user_id': userId,
      'author_alias': authorAlias,
      'upvotes': upvotes,
      'reported_count': reportedCount,
      'image_url': imageUrl,
      'moderation_status': moderationStatus,
    };
  }
}
