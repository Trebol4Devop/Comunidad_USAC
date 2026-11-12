import '../services/share_count_service.dart';

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

  factory PostPoll.fromMap(
    Map<String, dynamic> map, {
    String? myVotedOptionId,
  }) {
    final rawOptions = map['options'] as List<dynamic>? ?? [];
    return PostPoll(
      id: map['id']?.toString() ?? '',
      postId: map['post_id']?.toString() ?? '',
      question: map['question'] ?? '',
      options: rawOptions
          .map((o) => PollOption.fromMap(Map<String, dynamic>.from(o)))
          .toList(),
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
  final String? authorHash;
  final DateTime createdAt;
  final String carrera;
  final String? imageUrl;
  final String? gifUrl;
  final String? quotedPostId;
  final Post? quotedPost;
  final PostPoll? poll;
  final int repostsCount;
  final int sharesCount;
  final bool isPinned;
  final int moderationStatus;
  final bool isLikedByMe;
  final bool isBookmarkedByMe;
  final bool isMine;
  final int commentsCount;
  final double hotScore;
  final DateTime? expiresAt;
  final DateTime? deletedAt;
  final bool isLegalHold;

  // Compatibility getters
  bool get isMyPost => isMine;
  int get commentCount => commentsCount;

  Post({
    required this.id,
    required this.title,
    required this.category,
    required this.content,
    required this.authorAlias,
    required this.likes,
    this.userId,
    this.authorHash,
    required this.createdAt,
    this.carrera = 'todas',
    this.imageUrl,
    this.gifUrl,
    this.quotedPostId,
    this.quotedPost,
    this.poll,
    this.repostsCount = 0,
    this.sharesCount = 0,
    this.isPinned = false,
    this.moderationStatus = 0,
    this.isLikedByMe = false,
    this.isBookmarkedByMe = false,
    bool? isMine,
    bool? isMyPost,
    int? commentsCount,
    int? commentCount,
    this.hotScore = 0.0,
    this.expiresAt,
    this.deletedAt,
    this.isLegalHold = false,
  }) : isMine = isMine ?? isMyPost ?? false,
       commentsCount = commentsCount ?? commentCount ?? 0;

  Post copyWith({
    String? id,
    String? title,
    String? category,
    String? content,
    String? authorAlias,
    int? likes,
    String? userId,
    String? authorHash,
    DateTime? createdAt,
    String? carrera,
    String? imageUrl,
    String? gifUrl,
    String? quotedPostId,
    Post? quotedPost,
    PostPoll? poll,
    int? repostsCount,
    int? sharesCount,
    bool? isPinned,
    int? moderationStatus,
    bool? isLikedByMe,
    bool? isBookmarkedByMe,
    bool? isMine,
    bool? isMyPost,
    int? commentsCount,
    int? commentCount,
    double? hotScore,
    DateTime? expiresAt,
    DateTime? deletedAt,
    bool? isLegalHold,
  }) {
    return Post(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      content: content ?? this.content,
      authorAlias: authorAlias ?? this.authorAlias,
      likes: likes ?? this.likes,
      userId: userId ?? this.userId,
      authorHash: authorHash ?? this.authorHash,
      createdAt: createdAt ?? this.createdAt,
      carrera: carrera ?? this.carrera,
      imageUrl: imageUrl ?? this.imageUrl,
      gifUrl: gifUrl ?? this.gifUrl,
      quotedPostId: quotedPostId ?? this.quotedPostId,
      quotedPost: quotedPost ?? this.quotedPost,
      poll: poll ?? this.poll,
      repostsCount: repostsCount ?? this.repostsCount,
      sharesCount: sharesCount ?? this.sharesCount,
      isPinned: isPinned ?? this.isPinned,
      moderationStatus: moderationStatus ?? this.moderationStatus,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      isBookmarkedByMe: isBookmarkedByMe ?? this.isBookmarkedByMe,
      isMine: isMine ?? isMyPost ?? this.isMine,
      commentsCount: commentsCount ?? commentCount ?? this.commentsCount,
      hotScore: hotScore ?? this.hotScore,
      expiresAt: expiresAt ?? this.expiresAt,
      deletedAt: deletedAt ?? this.deletedAt,
      isLegalHold: isLegalHold ?? this.isLegalHold,
    );
  }

  factory Post.fromMap(
    Map<String, dynamic> map, {
    bool isLikedByMe = false,
    bool isBookmarkedByMe = false,
    int? commentCount,
    int? commentsCount,
    Post? quotedPost,
    PostPoll? poll,
  }) {
    final rawCount = map['comments_count'] ?? map['comment_count'];
    int parsedCount = commentsCount ?? commentCount ?? 0;
    if (rawCount != null) {
      parsedCount = (rawCount is int)
          ? rawCount
          : int.tryParse(rawCount.toString()) ?? parsedCount;
    }

    final rawHotScore = map['hot_score'];
    final double parsedHotScore = (rawHotScore is num)
        ? rawHotScore.toDouble()
        : double.tryParse(rawHotScore?.toString() ?? '0') ?? 0.0;

    final expiresAt = map['expires_at'] != null
        ? DateTime.tryParse(map['expires_at'].toString())
        : null;
    final deletedAt = map['deleted_at'] != null
        ? DateTime.tryParse(map['deleted_at'].toString())
        : null;

    final bool isMine = map.containsKey('is_mine')
        ? map['is_mine'] == true
        : map['is_my_post'] == true;

    final bool isLegalHold = map['is_legal_hold'] == true;

    // NO leas user_id del mapa: deja userId en null al leer datos públicos.
    return Post(
      id: map['id']?.toString() ?? '',
      title: map['title'] ?? '',
      category: map['category'] ?? 'general',
      content: map['content'] ?? '',
      authorAlias: map['author_alias'] ?? 'Estudiante USAC',
      likes: (map['likes'] is int)
          ? map['likes']
          : int.tryParse(map['likes']?.toString() ?? '0') ?? 0,
      userId: null,
      authorHash: map['author_hash']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      carrera: map['carrera'] ?? 'todas',
      imageUrl: map['image_url'],
      gifUrl: map['gif_url'],
      quotedPostId: map['quoted_post_id']?.toString(),
      quotedPost: quotedPost,
      poll: poll,
      repostsCount: (map['reposts_count'] is int)
          ? map['reposts_count']
          : int.tryParse(map['reposts_count']?.toString() ?? '0') ?? 0,
      sharesCount: () {
        final rawShares = map['shares_count'] ?? map['shares'];
        int parsedShares = 0;
        if (rawShares != null) {
          parsedShares = (rawShares is int)
              ? rawShares
              : int.tryParse(rawShares.toString()) ?? 0;
        }
        final postId = map['id']?.toString() ?? '';
        final localShares = ShareCountService.getCachedCount(postId);
        return localShares > parsedShares ? localShares : parsedShares;
      }(),
      isPinned: map['is_pinned'] == true,
      moderationStatus: (map['moderation_status'] is int)
          ? map['moderation_status']
          : int.tryParse(map['moderation_status']?.toString() ?? '0') ?? 0,
      isLikedByMe: isLikedByMe,
      isBookmarkedByMe: isBookmarkedByMe,
      isMine: isMine,
      commentsCount: parsedCount,
      hotScore: parsedHotScore,
      expiresAt: expiresAt,
      deletedAt: deletedAt,
      isLegalHold: isLegalHold,
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
      if (expiresAt != null) 'expires_at': expiresAt!.toUtc().toIso8601String(),
    };
  }
}

class PostComment {
  final String id;
  final String postId;
  final String authorAlias;
  final String content;
  final String? userId;
  final String? authorHash;
  final DateTime createdAt;
  final String? parentId;
  final String? gifUrl;
  final int moderationStatus;
  final bool isOp;
  final int likesCount;
  final bool isMine;
  final DateTime? deletedAt;
  List<PostComment> children;

  // Compatibility getters
  bool get isPostAuthor => isOp;
  bool get isMyComment => isMine;

  PostComment({
    required this.id,
    required this.postId,
    required this.authorAlias,
    required this.content,
    this.userId,
    this.authorHash,
    required this.createdAt,
    this.parentId,
    this.gifUrl,
    this.moderationStatus = 0,
    bool? isOp,
    bool? isPostAuthor,
    this.likesCount = 0,
    bool? isMine,
    bool? isMyComment,
    this.deletedAt,
    List<PostComment>? children,
  }) : isOp = isOp ?? isPostAuthor ?? false,
       isMine = isMine ?? isMyComment ?? false,
       children = children ?? [];

  PostComment copyWith({
    String? id,
    String? postId,
    String? authorAlias,
    String? content,
    String? userId,
    String? authorHash,
    DateTime? createdAt,
    String? parentId,
    String? gifUrl,
    int? moderationStatus,
    bool? isOp,
    bool? isPostAuthor,
    int? likesCount,
    bool? isMine,
    bool? isMyComment,
    DateTime? deletedAt,
    List<PostComment>? children,
  }) {
    return PostComment(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      authorAlias: authorAlias ?? this.authorAlias,
      content: content ?? this.content,
      userId: userId ?? this.userId,
      authorHash: authorHash ?? this.authorHash,
      createdAt: createdAt ?? this.createdAt,
      parentId: parentId ?? this.parentId,
      gifUrl: gifUrl ?? this.gifUrl,
      moderationStatus: moderationStatus ?? this.moderationStatus,
      isOp: isOp ?? isPostAuthor ?? this.isOp,
      likesCount: likesCount ?? this.likesCount,
      isMine: isMine ?? isMyComment ?? this.isMine,
      deletedAt: deletedAt ?? this.deletedAt,
      children: children ?? this.children,
    );
  }

  factory PostComment.fromMap(Map<String, dynamic> map) {
    final rawParentId = map['parent_id']?.toString().trim();
    final parentId =
        (rawParentId != null && rawParentId.isNotEmpty && rawParentId != 'null')
        ? rawParentId
        : null;

    final isOp = map.containsKey('is_op')
        ? map['is_op'] == true
        : map['is_post_author'] == true;

    final isMine = map.containsKey('is_mine')
        ? map['is_mine'] == true
        : map['is_my_comment'] == true;

    final rawLikesCount = map['likes_count'];
    final likesCount = (rawLikesCount is int)
        ? rawLikesCount
        : int.tryParse(rawLikesCount?.toString() ?? '0') ?? 0;

    final deletedAt = map['deleted_at'] != null
        ? DateTime.tryParse(map['deleted_at'].toString())
        : null;

    // NO leas user_id del mapa: deja userId en null al leer datos públicos.
    return PostComment(
      id: map['id']?.toString() ?? '',
      postId: map['post_id']?.toString() ?? '',
      authorAlias: map['author_alias'] ?? 'Estudiante',
      content: map['content'] ?? '',
      userId: null,
      authorHash: map['author_hash']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      parentId: parentId,
      gifUrl: map['gif_url'],
      moderationStatus: (map['moderation_status'] is int)
          ? map['moderation_status']
          : int.tryParse(map['moderation_status']?.toString() ?? '0') ?? 0,
      isOp: isOp,
      likesCount: likesCount,
      isMine: isMine,
      deletedAt: deletedAt,
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
