class Post {
  final String id;
  final String title;
  final String category;
  final String content;
  final String authorAlias;
  final int likes;
  final String? userId;
  final DateTime createdAt;
  final String carrera;
  final String? imageUrl;
  final int moderationStatus;
  final bool isLikedByMe;
  final int commentCount;

  Post({
    required this.id,
    required this.title,
    required this.category,
    required this.content,
    required this.authorAlias,
    required this.likes,
    this.userId,
    required this.createdAt,
    this.carrera = 'todas',
    this.imageUrl,
    this.moderationStatus = 0,
    this.isLikedByMe = false,
    this.commentCount = 0,
  });

  Post copyWith({
    String? id,
    String? title,
    String? category,
    String? content,
    String? authorAlias,
    int? likes,
    String? userId,
    DateTime? createdAt,
    String? carrera,
    String? imageUrl,
    int? moderationStatus,
    bool? isLikedByMe,
    int? commentCount,
  }) {
    return Post(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      content: content ?? this.content,
      authorAlias: authorAlias ?? this.authorAlias,
      likes: likes ?? this.likes,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      carrera: carrera ?? this.carrera,
      imageUrl: imageUrl ?? this.imageUrl,
      moderationStatus: moderationStatus ?? this.moderationStatus,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      commentCount: commentCount ?? this.commentCount,
    );
  }

  factory Post.fromMap(Map<String, dynamic> map, {bool isLikedByMe = false, int commentCount = 0}) {
    return Post(
      id: map['id']?.toString() ?? '',
      title: map['title'] ?? '',
      category: map['category'] ?? 'general',
      content: map['content'] ?? '',
      authorAlias: map['author_alias'] ?? 'Estudiante USAC',
      likes: (map['likes'] is int) ? map['likes'] : int.tryParse(map['likes']?.toString() ?? '0') ?? 0,
      userId: map['user_id']?.toString(),
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
      carrera: map['carrera'] ?? 'todas',
      imageUrl: map['image_url'],
      moderationStatus: (map['moderation_status'] is int)
          ? map['moderation_status']
          : int.tryParse(map['moderation_status']?.toString() ?? '0') ?? 0,
      isLikedByMe: isLikedByMe,
      commentCount: commentCount,
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'title': title,
      'category': category,
      'content': content,
      'author_alias': authorAlias,
      'user_id': userId,
      'carrera': carrera,
      'image_url': imageUrl,
      'likes': likes,
      'moderation_status': moderationStatus,
    };
  }
}

class PostComment {
  final String id;
  final String postId;
  final String authorAlias;
  final String content;
  final String? userId;
  final DateTime createdAt;
  final String? parentId;
  final int moderationStatus;
  List<PostComment> children;

  PostComment({
    required this.id,
    required this.postId,
    required this.authorAlias,
    required this.content,
    this.userId,
    required this.createdAt,
    this.parentId,
    this.moderationStatus = 0,
    List<PostComment>? children,
  }) : children = children ?? [];

  factory PostComment.fromMap(Map<String, dynamic> map) {
    return PostComment(
      id: map['id']?.toString() ?? '',
      postId: map['post_id']?.toString() ?? '',
      authorAlias: map['author_alias'] ?? 'Estudiante',
      content: map['content'] ?? '',
      userId: map['user_id']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      parentId: map['parent_id']?.toString(),
      moderationStatus: (map['moderation_status'] is int)
          ? map['moderation_status']
          : int.tryParse(map['moderation_status']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'post_id': postId,
      'author_alias': authorAlias,
      'content': content,
      'user_id': userId,
      'parent_id': parentId,
      'moderation_status': moderationStatus,
    };
  }
}
