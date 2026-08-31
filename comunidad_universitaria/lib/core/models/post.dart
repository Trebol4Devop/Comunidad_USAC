class PollOption {
  final String id;
  final String pollId;
  final String optionText;
  final int votesCount;

  PollOption({
    required this.id,
    required this.pollId,
    required this.optionText,
    required this.votesCount,
  });

  factory PollOption.fromMap(Map<String, dynamic> map) {
    return PollOption(
      id: map['id']?.toString() ?? '',
      pollId: map['poll_id']?.toString() ?? '',
      optionText: map['option_text'] ?? '',
      votesCount: (map['votes_count'] is int)
          ? map['votes_count']
          : int.tryParse(map['votes_count']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'poll_id': pollId,
      'option_text': optionText,
      'votes_count': votesCount,
    };
  }
}

class PostPoll {
  final String id;
  final String postId;
  final String question;
  final List<PollOption> options;
  final String? myVotedOptionId;

  PostPoll({
    required this.id,
    required this.postId,
    required this.question,
    required this.options,
    this.myVotedOptionId,
  });

  int get totalVotes => options.fold(0, (sum, opt) => sum + opt.votesCount);

  factory PostPoll.fromMap(Map<String, dynamic> map, {String? myVotedOptionId}) {
    final rawOptions = map['options'] as List<dynamic>? ?? [];
    return PostPoll(
      id: map['id']?.toString() ?? '',
      postId: map['post_id']?.toString() ?? '',
      question: map['question'] ?? '',
      options: rawOptions.map((o) => PollOption.fromMap(Map<String, dynamic>.from(o))).toList(),
      myVotedOptionId: myVotedOptionId,
    );
  }

  PostPoll copyWith({
    String? id,
    String? postId,
    String? question,
    List<PollOption>? options,
    String? myVotedOptionId,
  }) {
    return PostPoll(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      question: question ?? this.question,
      options: options ?? this.options,
      myVotedOptionId: myVotedOptionId ?? this.myVotedOptionId,
    );
  }
}

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
  final String? gifUrl;
  final String? quotedPostId;
  final Post? quotedPost;
  final PostPoll? poll;
  final int repostsCount;
  final bool isPinned;
  final int moderationStatus;
  final bool isLikedByMe;
  final bool isBookmarkedByMe;
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
    this.gifUrl,
    this.quotedPostId,
    this.quotedPost,
    this.poll,
    this.repostsCount = 0,
    this.isPinned = false,
    this.moderationStatus = 0,
    this.isLikedByMe = false,
    this.isBookmarkedByMe = false,
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
    String? gifUrl,
    String? quotedPostId,
    Post? quotedPost,
    PostPoll? poll,
    int? repostsCount,
    bool? isPinned,
    int? moderationStatus,
    bool? isLikedByMe,
    bool? isBookmarkedByMe,
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
      gifUrl: gifUrl ?? this.gifUrl,
      quotedPostId: quotedPostId ?? this.quotedPostId,
      quotedPost: quotedPost ?? this.quotedPost,
      poll: poll ?? this.poll,
      repostsCount: repostsCount ?? this.repostsCount,
      isPinned: isPinned ?? this.isPinned,
      moderationStatus: moderationStatus ?? this.moderationStatus,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      isBookmarkedByMe: isBookmarkedByMe ?? this.isBookmarkedByMe,
      commentCount: commentCount ?? this.commentCount,
    );
  }

  factory Post.fromMap(
    Map<String, dynamic> map, {
    bool isLikedByMe = false,
    bool isBookmarkedByMe = false,
    int commentCount = 0,
    Post? quotedPost,
    PostPoll? poll,
  }) {
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
      gifUrl: map['gif_url'],
      quotedPostId: map['quoted_post_id']?.toString(),
      quotedPost: quotedPost,
      poll: poll,
      repostsCount: (map['reposts_count'] is int)
          ? map['reposts_count']
          : int.tryParse(map['reposts_count']?.toString() ?? '0') ?? 0,
      isPinned: map['is_pinned'] == true,
      moderationStatus: (map['moderation_status'] is int)
          ? map['moderation_status']
          : int.tryParse(map['moderation_status']?.toString() ?? '0') ?? 0,
      isLikedByMe: isLikedByMe,
      isBookmarkedByMe: isBookmarkedByMe,
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
      'gif_url': gifUrl,
      'quoted_post_id': quotedPostId,
      'is_pinned': isPinned,
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
  final String? gifUrl;
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
    this.gifUrl,
    this.moderationStatus = 0,
    List<PostComment>? children,
  }) : children = children ?? [];

  factory PostComment.fromMap(Map<String, dynamic> map) {
    final rawParentId = map['parent_id']?.toString().trim();
    final parentId = (rawParentId != null && rawParentId.isNotEmpty && rawParentId != 'null')
        ? rawParentId
        : null;

    final rawUserId = map['user_id']?.toString().trim();
    final userId = (rawUserId != null && rawUserId.isNotEmpty && rawUserId != 'null')
        ? rawUserId
        : null;

    return PostComment(
      id: map['id']?.toString() ?? '',
      postId: map['post_id']?.toString() ?? '',
      authorAlias: map['author_alias'] ?? 'Estudiante',
      content: map['content'] ?? '',
      userId: userId,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      parentId: parentId,
      gifUrl: map['gif_url'],
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
      'gif_url': gifUrl,
      'moderation_status': moderationStatus,
    };
  }
}
