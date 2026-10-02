import 'package:comunidad_universitaria/core/models/facultad.dart';
import 'package:comunidad_universitaria/core/models/marketplace_item.dart';
import 'package:comunidad_universitaria/core/models/post.dart';
import 'package:comunidad_universitaria/core/models/user_profile.dart';
import 'package:comunidad_universitaria/core/models/whatsapp_group.dart';

class TestFixtures {
  // ---------------------------------------------------------------------------
  // Post & Poll Fixtures
  // ---------------------------------------------------------------------------
  static Map<String, dynamic> pollOptionMap({
    String id = 'opt-1',
    String pollId = 'poll-1',
    String optionText = 'Opción A',
    dynamic votesCount = 5,
  }) {
    return {
      'id': id,
      'poll_id': pollId,
      'option_text': optionText,
      'votes_count': votesCount,
    };
  }

  static PollOption pollOption({
    String id = 'opt-1',
    String pollId = 'poll-1',
    String optionText = 'Opción A',
    int votesCount = 5,
  }) {
    return PollOption(
      id: id,
      pollId: pollId,
      optionText: optionText,
      votesCount: votesCount,
    );
  }

  static Map<String, dynamic> postPollMap({
    String id = 'poll-1',
    String postId = 'post-1',
    String question = '¿Qué pensás de este parcial?',
    List<Map<String, dynamic>>? options,
  }) {
    return {
      'id': id,
      'post_id': postId,
      'question': question,
      'options': options ??
          [
            pollOptionMap(id: 'opt-1', pollId: id, optionText: 'Fácil', votesCount: 10),
            pollOptionMap(id: 'opt-2', pollId: id, optionText: 'Difícil', votesCount: 20),
          ],
    };
  }

  static PostPoll postPoll({
    String id = 'poll-1',
    String postId = 'post-1',
    String question = '¿Qué pensás de este parcial?',
    List<PollOption>? options,
    String? myVotedOptionId,
  }) {
    return PostPoll(
      id: id,
      postId: postId,
      question: question,
      options: options ??
          [
            pollOption(id: 'opt-1', pollId: id, optionText: 'Fácil', votesCount: 10),
            pollOption(id: 'opt-2', pollId: id, optionText: 'Difícil', votesCount: 20),
          ],
      myVotedOptionId: myVotedOptionId,
    );
  }

  static Map<String, dynamic> postMap({
    String id = 'post-1',
    String title = 'Duda sobre Matemática Básica 1',
    String category = 'prerrequisitos',
    String content = '¿Alguien sabe si el libro de Stewart viene completo?',
    String authorAlias = 'Estudiante Ingenieril #101',
    dynamic likes = 4,
    String? userId = 'user-101',
    String? authorHash = 'hash-abc',
    String? createdAt = '2026-03-01T10:00:00.000Z',
    String carrera = 'sistemas',
    String? imageUrl,
    String? gifUrl,
    String? quotedPostId,
    dynamic repostsCount = 0,
    bool isPinned = false,
    dynamic moderationStatus = 0,
    dynamic commentCount = 2,
    bool isMyPost = false,
  }) {
    return {
      'id': id,
      'title': title,
      'category': category,
      'content': content,
      'author_alias': authorAlias,
      'likes': likes,
      'user_id': userId,
      'author_hash': authorHash,
      'created_at': createdAt,
      'carrera': carrera,
      'image_url': imageUrl,
      'gif_url': gifUrl,
      'quoted_post_id': quotedPostId,
      'reposts_count': repostsCount,
      'is_pinned': isPinned,
      'moderation_status': moderationStatus,
      'comment_count': commentCount,
      'is_my_post': isMyPost,
    };
  }

  static Post post({
    String id = 'post-1',
    String title = 'Duda sobre Matemática Básica 1',
    String category = 'prerrequisitos',
    String content = '¿Alguien sabe si el libro de Stewart viene completo?',
    String authorAlias = 'Estudiante Ingenieril #101',
    int likes = 4,
    String? userId = 'user-101',
    String? authorHash = 'hash-abc',
    DateTime? createdAt,
    String carrera = 'sistemas',
    String? imageUrl,
    String? gifUrl,
    String? quotedPostId,
    Post? quotedPost,
    PostPoll? poll,
    int repostsCount = 0,
    bool isPinned = false,
    int moderationStatus = 0,
    bool isLikedByMe = false,
    bool isBookmarkedByMe = false,
    bool isMyPost = false,
    int commentCount = 2,
  }) {
    return Post(
      id: id,
      title: title,
      category: category,
      content: content,
      authorAlias: authorAlias,
      likes: likes,
      userId: userId,
      authorHash: authorHash,
      createdAt: createdAt ?? DateTime.parse('2026-03-01T10:00:00.000Z'),
      carrera: carrera,
      imageUrl: imageUrl,
      gifUrl: gifUrl,
      quotedPostId: quotedPostId,
      quotedPost: quotedPost,
      poll: poll,
      repostsCount: repostsCount,
      isPinned: isPinned,
      moderationStatus: moderationStatus,
      isLikedByMe: isLikedByMe,
      isBookmarkedByMe: isBookmarkedByMe,
      isMyPost: isMyPost,
      commentCount: commentCount,
    );
  }

  // ---------------------------------------------------------------------------
  // PostComment Fixtures
  // ---------------------------------------------------------------------------
  static Map<String, dynamic> postCommentMap({
    String id = 'comment-1',
    String postId = 'post-1',
    String authorAlias = 'Compañero USAC',
    String content = 'Sí, viene todo en el anexo final.',
    dynamic userId = 'user-202',
    String? authorHash = 'hash-def',
    String? createdAt = '2026-03-01T10:15:00.000Z',
    dynamic parentId,
    String? gifUrl,
    dynamic moderationStatus = 0,
    bool isPostAuthor = false,
    bool isMyComment = false,
  }) {
    return {
      'id': id,
      'post_id': postId,
      'author_alias': authorAlias,
      'content': content,
      'user_id': userId,
      'author_hash': authorHash,
      'created_at': createdAt,
      'parent_id': parentId,
      'gif_url': gifUrl,
      'moderation_status': moderationStatus,
      'is_post_author': isPostAuthor,
      'is_my_comment': isMyComment,
    };
  }

  static PostComment postComment({
    String id = 'comment-1',
    String postId = 'post-1',
    String authorAlias = 'Compañero USAC',
    String content = 'Sí, viene todo en el anexo final.',
    String? userId = 'user-202',
    String? authorHash = 'hash-def',
    DateTime? createdAt,
    String? parentId,
    String? gifUrl,
    int moderationStatus = 0,
    bool isPostAuthor = false,
    bool isMyComment = false,
    List<PostComment>? children,
  }) {
    return PostComment(
      id: id,
      postId: postId,
      authorAlias: authorAlias,
      content: content,
      userId: userId,
      authorHash: authorHash,
      createdAt: createdAt ?? DateTime.parse('2026-03-01T10:15:00.000Z'),
      parentId: parentId,
      gifUrl: gifUrl,
      moderationStatus: moderationStatus,
      isPostAuthor: isPostAuthor,
      isMyComment: isMyComment,
      children: children,
    );
  }

  // ---------------------------------------------------------------------------
  // MarketplaceItem Fixtures
  // ---------------------------------------------------------------------------
  static Map<String, dynamic> marketplaceItemMap({
    String id = 'item-1',
    String title = 'Calculadora TI-84 Plus CE',
    String description = 'En perfecto estado con cargador',
    dynamic price = 650.0,
    bool isFree = false,
    String category = 'otros_articulos',
    String facultad = '08',
    String sede = 'central',
    String buildingCode = 'T-3',
    String locationDetail = 'Entrada principal pasillo 1',
    String? contactWhatsapp = '50212345678',
    String? contactInstagram = '@tienda_usac',
    String? contactMessenger = 'tiendausac',
    String? contactTelegram = 'tienda_usac_bot',
    List<String> socialLinks = const [],
    List<String> imageUrls = const ['https://example.com/item1.jpg'],
    String? videoUrl,
    bool isSponsored = false,
    String? sponsorBadgeText,
    String authorAlias = 'Vendedor Pro',
    String? userId = 'user-303',
    String? createdAt = '2026-03-01T12:00:00.000Z',
    dynamic moderationStatus = 0,
    dynamic reportedCount = 0,
    dynamic upvotes = 5,
    String status = 'available',
    bool isSellerVerified = true,
  }) {
    return {
      'id': id,
      'title': title,
      'description': description,
      'price': price,
      'is_free': isFree,
      'category': category,
      'facultad': facultad,
      'sede': sede,
      'building_code': buildingCode,
      'location_detail': locationDetail,
      'contact_whatsapp': contactWhatsapp,
      'contact_instagram': contactInstagram,
      'contact_messenger': contactMessenger,
      'contact_telegram': contactTelegram,
      'social_links': socialLinks,
      'image_urls': imageUrls,
      'video_url': videoUrl,
      'is_sponsored': isSponsored,
      'sponsor_badge_text': sponsorBadgeText,
      'author_alias': authorAlias,
      'user_id': userId,
      'created_at': createdAt,
      'moderation_status': moderationStatus,
      'reported_count': reportedCount,
      'upvotes': upvotes,
      'status': status,
      'is_seller_verified': isSellerVerified,
    };
  }

  static MarketplaceItem marketplaceItem({
    String id = 'item-1',
    String title = 'Calculadora TI-84 Plus CE',
    String description = 'En perfecto estado con cargador',
    double price = 650.0,
    bool isFree = false,
    String category = 'otros_articulos',
    String facultad = '08',
    String sede = 'central',
    String buildingCode = 'T-3',
    String locationDetail = 'Entrada principal pasillo 1',
    String? contactWhatsapp = '50212345678',
    String? contactInstagram = '@tienda_usac',
    String? contactMessenger = 'tiendausac',
    String? contactTelegram = 'tienda_usac_bot',
    List<String> socialLinks = const [],
    List<String> imageUrls = const ['https://example.com/item1.jpg'],
    String? videoUrl,
    bool isSponsored = false,
    String? sponsorBadgeText,
    String authorAlias = 'Vendedor Pro',
    String? userId = 'user-303',
    DateTime? createdAt,
    int moderationStatus = 0,
    int reportedCount = 0,
    int upvotes = 5,
    bool isUpvotedByMe = false,
    String status = 'available',
    bool isSellerVerified = true,
  }) {
    return MarketplaceItem(
      id: id,
      title: title,
      description: description,
      price: price,
      isFree: isFree,
      category: category,
      facultad: facultad,
      sede: sede,
      buildingCode: buildingCode,
      locationDetail: locationDetail,
      contactWhatsapp: contactWhatsapp,
      contactInstagram: contactInstagram,
      contactMessenger: contactMessenger,
      contactTelegram: contactTelegram,
      socialLinks: socialLinks,
      imageUrls: imageUrls,
      videoUrl: videoUrl,
      isSponsored: isSponsored,
      sponsorBadgeText: sponsorBadgeText,
      authorAlias: authorAlias,
      userId: userId,
      createdAt: createdAt ?? DateTime.parse('2026-03-01T12:00:00.000Z'),
      moderationStatus: moderationStatus,
      reportedCount: reportedCount,
      upvotes: upvotes,
      isUpvotedByMe: isUpvotedByMe,
      status: status,
      isSellerVerified: isSellerVerified,
    );
  }

  // ---------------------------------------------------------------------------
  // WhatsAppGroup Fixtures
  // ---------------------------------------------------------------------------
  static Map<String, dynamic> whatsAppGroupMap({
    String id = 'group-1',
    String title = 'Grupo Sistemas Oficial 2026',
    String carrera = 'sistemas',
    String curso = 'Estructuras de Datos',
    String section = 'Sección A',
    String link = 'https://chat.whatsapp.com/AbCdEfGhIjKl',
    String description = 'Grupo de estudio para tareas y proyectos',
    String? userId = 'user-404',
    String authorAlias = 'Auxiliar Sistemas',
    dynamic upvotes = 12,
    dynamic reportedCount = 0,
    String? createdAt = '2026-03-01T08:00:00.000Z',
    String? imageUrl,
    dynamic moderationStatus = 0,
  }) {
    return {
      'id': id,
      'title': title,
      'carrera': carrera,
      'curso': curso,
      'section': section,
      'link': link,
      'description': description,
      'user_id': userId,
      'author_alias': authorAlias,
      'upvotes': upvotes,
      'reported_count': reportedCount,
      'created_at': createdAt,
      'image_url': imageUrl,
      'moderation_status': moderationStatus,
    };
  }

  static WhatsAppGroup whatsAppGroup({
    String id = 'group-1',
    String title = 'Grupo Sistemas Oficial 2026',
    String carrera = 'sistemas',
    String curso = 'Estructuras de Datos',
    String section = 'Sección A',
    String link = 'https://chat.whatsapp.com/AbCdEfGhIjKl',
    String description = 'Grupo de estudio para tareas y proyectos',
    String? userId = 'user-404',
    String authorAlias = 'Auxiliar Sistemas',
    int upvotes = 12,
    int reportedCount = 0,
    DateTime? createdAt,
    String? imageUrl,
    int moderationStatus = 0,
    bool isUpvotedByMe = false,
  }) {
    return WhatsAppGroup(
      id: id,
      title: title,
      carrera: carrera,
      curso: curso,
      section: section,
      link: link,
      description: description,
      userId: userId,
      authorAlias: authorAlias,
      upvotes: upvotes,
      reportedCount: reportedCount,
      createdAt: createdAt ?? DateTime.parse('2026-03-01T08:00:00.000Z'),
      imageUrl: imageUrl,
      moderationStatus: moderationStatus,
      isUpvotedByMe: isUpvotedByMe,
    );
  }

  // ---------------------------------------------------------------------------
  // UserProfile Fixtures
  // ---------------------------------------------------------------------------
  static Map<String, dynamic> userProfileMap({
    String userId = 'user-505',
    String alias = 'Sancarlita #777',
    String role = 'student',
    String facultadId = '08',
    String carreraId = 'sistemas',
    String sedeId = 'central',
    String bio = 'Estudiante de 4to año',
    int avatarColorIndex = 1,
    int avatarIconIndex = 3,
    String? contactWhatsapp = '50255554444',
    String? contactTelegram = 'sancar777',
    String? contactInstagram = 'sancar.777',
    String? email = 'sancar777@ingenieria.usac.edu.gt',
    String? carne = '202012345',
    String? studentName = 'Carlos San Carlos',
    bool isCarneVerified = true,
  }) {
    return {
      'user_id': userId,
      'alias': alias,
      'role': role,
      'facultad_id': facultadId,
      'carrera_id': carreraId,
      'sede_id': sedeId,
      'bio': bio,
      'avatar_color_index': avatarColorIndex,
      'avatar_icon_index': avatarIconIndex,
      'contact_whatsapp': contactWhatsapp,
      'contact_telegram': contactTelegram,
      'contact_instagram': contactInstagram,
      'email': email,
      'carne': carne,
      'student_name': studentName,
      'is_carne_verified': isCarneVerified,
    };
  }

  static UserProfile userProfile({
    String userId = 'user-505',
    String alias = 'Sancarlita #777',
    String role = 'student',
    String facultadId = '08',
    String carreraId = 'sistemas',
    String sedeId = 'central',
    String bio = 'Estudiante de 4to año',
    int avatarColorIndex = 1,
    int avatarIconIndex = 3,
    String? contactWhatsapp = '50255554444',
    String? contactTelegram = 'sancar777',
    String? contactInstagram = 'sancar.777',
    String? email = 'sancar777@ingenieria.usac.edu.gt',
    String? carne = '202012345',
    String? studentName = 'Carlos San Carlos',
    bool isCarneVerified = true,
  }) {
    return UserProfile(
      userId: userId,
      alias: alias,
      role: role,
      facultadId: facultadId,
      carreraId: carreraId,
      sedeId: sedeId,
      bio: bio,
      avatarColorIndex: avatarColorIndex,
      avatarIconIndex: avatarIconIndex,
      contactWhatsapp: contactWhatsapp,
      contactTelegram: contactTelegram,
      contactInstagram: contactInstagram,
      email: email,
      carne: carne,
      studentName: studentName,
      isCarneVerified: isCarneVerified,
    );
  }

  // ---------------------------------------------------------------------------
  // Facultad / Carrera / Sede / CampusLocation Fixtures
  // ---------------------------------------------------------------------------
  static Map<String, dynamic> facultadMap({
    String id = '08',
    String codigo = '08',
    String nombre = 'Facultad de Ingeniería',
    String sitio = 'https://ingenieria.usac.edu.gt',
    List<Map<String, dynamic>>? carreras,
  }) {
    return {
      'id': id,
      'codigo': codigo,
      'nombre': nombre,
      'sitio': sitio,
      'carreras': carreras ??
          [
            carreraMap(id: 'sistemas', nombre: 'Ingeniería en Ciencias y Sistemas'),
          ],
    };
  }

  static Map<String, dynamic> carreraMap({
    String id = 'sistemas',
    String nombre = 'Ingeniería en Ciencias y Sistemas',
    String codigo = '08-01-01',
    String sede = 'Campus Central',
    List<String> modalidades = const ['Diario'],
  }) {
    return {
      'id': id,
      'nombre': nombre,
      'codigo': codigo,
      'sede': sede,
      'modalidades': modalidades,
    };
  }

  static Map<String, dynamic> sedeMap({
    String id = 'central',
    String nombre = 'Campus Central · Zona 12',
    String departamento = 'Guatemala',
    String municipio = 'Guatemala',
    String tipo = 'campus_central',
  }) {
    return {
      'id': id,
      'nombre': nombre,
      'departamento': departamento,
      'municipio': municipio,
      'tipo': tipo,
    };
  }

  static Map<String, dynamic> campusLocationMap({
    String id = 'cafeteria_t3',
    String nombre = 'Frente a Cafetería del T-3',
    String sedeId = 'central',
    String buildingCode = 'Cafetería T-3',
    double latitude = 14.5886,
    double longitude = -90.5516,
    String? description = 'Punto de alta concurrencia',
  }) {
    return {
      'id': id,
      'nombre': nombre,
      'sede_id': sedeId,
      'building_code': buildingCode,
      'latitude': latitude,
      'longitude': longitude,
      'description': description,
    };
  }

  static Facultad facultad({
    String id = '08',
    String codigo = '08',
    String nombre = 'Facultad de Ingeniería',
    String sitio = 'https://ingenieria.usac.edu.gt',
    List<Carrera>? carreras,
  }) {
    return Facultad(
      id: id,
      codigo: codigo,
      nombre: nombre,
      sitio: sitio,
      carreras: carreras ?? [carrera()],
    );
  }

  static Carrera carrera({
    String id = 'sistemas',
    String nombre = 'Ingeniería en Ciencias y Sistemas',
    String codigo = '08-01-01',
    String sede = 'Campus Central',
    List<String> modalidades = const ['Diario'],
  }) {
    return Carrera(
      id: id,
      nombre: nombre,
      codigo: codigo,
      sede: sede,
      modalidades: modalidades,
    );
  }

  static SedeUniversitaria sedeUniversitaria({
    String id = 'central',
    String nombre = 'Campus Central · Zona 12',
    String departamento = 'Guatemala',
    String municipio = 'Guatemala',
    String tipo = 'campus_central',
  }) {
    return SedeUniversitaria(
      id: id,
      nombre: nombre,
      departamento: departamento,
      municipio: municipio,
      tipo: tipo,
    );
  }

  static CampusLocation campusLocation({
    String id = 'cafeteria_t3',
    String nombre = 'Frente a Cafetería del T-3',
    String sedeId = 'central',
    String buildingCode = 'Cafetería T-3',
    double latitude = 14.5886,
    double longitude = -90.5516,
    String? description = 'Punto de alta concurrencia',
  }) {
    return CampusLocation(
      id: id,
      nombre: nombre,
      sedeId: sedeId,
      buildingCode: buildingCode,
      latitude: latitude,
      longitude: longitude,
      description: description,
    );
  }
}
