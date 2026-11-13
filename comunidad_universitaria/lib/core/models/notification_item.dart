class NotificationItem {
  final String id;
  final String userId;
  final String type; // 'comment', 'reply', 'like', 'new_post'
  final String title;
  final String body;
  final String? actorAlias;
  final String? postId;
  final String? commentId;
  final DateTime? readAt;
  final DateTime? pushSentAt;
  final DateTime createdAt;

  NotificationItem({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.actorAlias,
    this.postId,
    this.commentId,
    this.readAt,
    this.pushSentAt,
    required this.createdAt,
  });

  bool get isRead => readAt != null;

  factory NotificationItem.fromMap(Map<String, dynamic> map) {
    return NotificationItem(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      type: map['type']?.toString() ?? 'comment',
      title: map['title']?.toString() ?? '',
      body: map['body']?.toString() ?? '',
      actorAlias: map['actor_alias']?.toString(),
      postId: map['post_id']?.toString(),
      commentId: map['comment_id']?.toString(),
      readAt: map['read_at'] != null
          ? DateTime.tryParse(map['read_at'].toString())
          : null,
      pushSentAt: map['push_sent_at'] != null
          ? DateTime.tryParse(map['push_sent_at'].toString())
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'type': type,
      'title': title,
      'body': body,
      'actor_alias': actorAlias,
      'post_id': postId,
      'comment_id': commentId,
      'read_at': readAt?.toUtc().toIso8601String(),
      'push_sent_at': pushSentAt?.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  NotificationItem copyWith({
    String? id,
    String? userId,
    String? type,
    String? title,
    String? body,
    String? actorAlias,
    String? postId,
    String? commentId,
    DateTime? readAt,
    DateTime? pushSentAt,
    DateTime? createdAt,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      actorAlias: actorAlias ?? this.actorAlias,
      postId: postId ?? this.postId,
      commentId: commentId ?? this.commentId,
      readAt: readAt ?? this.readAt,
      pushSentAt: pushSentAt ?? this.pushSentAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class NotificationPreferences {
  final String userId;
  final bool commentEnabled;
  final bool replyEnabled;
  final bool likeEnabled;
  final bool newPostEnabled;
  final List<String> carreras;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  NotificationPreferences({
    required this.userId,
    this.commentEnabled = true,
    this.replyEnabled = true,
    this.likeEnabled = true,
    this.newPostEnabled = false,
    this.carreras = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory NotificationPreferences.fromMap(Map<String, dynamic> map) {
    List<String> carrerasList = [];
    if (map['carreras'] is List) {
      carrerasList = (map['carreras'] as List)
          .map((e) => e.toString())
          .toList();
    }

    return NotificationPreferences(
      userId: map['user_id']?.toString() ?? '',
      commentEnabled: map['comment_enabled'] ?? true,
      replyEnabled: map['reply_enabled'] ?? true,
      likeEnabled: map['like_enabled'] ?? true,
      newPostEnabled: map['new_post_enabled'] ?? false,
      carreras: carrerasList,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'comment_enabled': commentEnabled,
      'reply_enabled': replyEnabled,
      'like_enabled': likeEnabled,
      'new_post_enabled': newPostEnabled,
    };
  }

  NotificationPreferences copyWith({
    String? userId,
    bool? commentEnabled,
    bool? replyEnabled,
    bool? likeEnabled,
    bool? newPostEnabled,
    List<String>? carreras,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NotificationPreferences(
      userId: userId ?? this.userId,
      commentEnabled: commentEnabled ?? this.commentEnabled,
      replyEnabled: replyEnabled ?? this.replyEnabled,
      likeEnabled: likeEnabled ?? this.likeEnabled,
      newPostEnabled: newPostEnabled ?? this.newPostEnabled,
      carreras: carreras ?? this.carreras,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
