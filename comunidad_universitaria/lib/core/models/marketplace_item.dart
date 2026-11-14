import '../services/share_count_service.dart';

enum MarketplaceCategory {
  comidaPostres,
  tutoriasAcademica,
  librosMateriales,
  serviciosEstudiantiles,
  otrosArticulos,
}

extension MarketplaceCategoryExtension on MarketplaceCategory {
  String get id {
    switch (this) {
      case MarketplaceCategory.comidaPostres:
        return 'comida_postres';
      case MarketplaceCategory.tutoriasAcademica:
        return 'tutorias_academica';
      case MarketplaceCategory.librosMateriales:
        return 'libros_materiales';
      case MarketplaceCategory.serviciosEstudiantiles:
        return 'servicios_estudiantiles';
      case MarketplaceCategory.otrosArticulos:
        return 'otros_articulos';
    }
  }

  String get label {
    switch (this) {
      case MarketplaceCategory.comidaPostres:
        return 'Comida & Postres';
      case MarketplaceCategory.tutoriasAcademica:
        return 'Tutorías & Asesoría';
      case MarketplaceCategory.librosMateriales:
        return 'Libros & Materiales';
      case MarketplaceCategory.serviciosEstudiantiles:
        return 'Servicios Estudiantiles';
      case MarketplaceCategory.otrosArticulos:
        return 'Otros Artículos';
    }
  }

  static MarketplaceCategory fromString(String val) {
    switch (val) {
      case 'comida_postres':
        return MarketplaceCategory.comidaPostres;
      case 'tutorias_academica':
        return MarketplaceCategory.tutoriasAcademica;
      case 'libros_materiales':
        return MarketplaceCategory.librosMateriales;
      case 'servicios_estudiantiles':
        return MarketplaceCategory.serviciosEstudiantiles;
      default:
        return MarketplaceCategory.otrosArticulos;
    }
  }
}

class MarketplaceItem {
  final String id;
  final String title;
  final String description;
  final double price; // 0 = Gratis
  final bool isFree;
  final String category; // comida_postres, tutorias_academica, etc.
  final String facultad;
  final String sede;
  final String buildingCode; // ej. T-3, S-12, CUM, etc.
  final String locationDetail; // ej. 2do nivel frente a cafetería
  final String? contactWhatsapp;
  final String? contactInstagram;
  final String? contactMessenger;
  final String? contactTelegram;
  final List<String> socialLinks; // Links a publicaciones de FB, IG, etc.
  final List<String> imageUrls;
  final String? videoUrl; // Exclusivo para patrocinadores / showcase
  final bool isSponsored; // Primera plana
  final String? sponsorBadgeText;
  final String? sponsorBrandName;
  final String authorAlias;
  final String? userId;
  final DateTime createdAt;
  final int moderationStatus; // 0: Activo, 1: En revisión, 2: Oculto/Bloqueado
  final int reportedCount;
  final int upvotes;
  final int sharesCount;
  final bool isUpvotedByMe;
  final String status; // available, reserved, sold, paused, archived
  final bool isSellerVerified;
  final bool isMine;

  // Nuevos campos UX-Marketplace
  final String? sellerPublicId;
  final String? sellerBusinessName;
  final String sellerPlanId;
  final String sellerPlanName;
  final String? sellerBadgeText;
  final bool sellerIsOnCampus;
  final String? sellerBuildingCode;
  final bool isBookmarked;
  final DateTime? expiresAt;
  final double score;
  final bool isHiddenFromFeed;
  final DateTime? bookmarkedAt;

  MarketplaceItem({
    required this.id,
    required this.title,
    required this.description,
    this.price = 0.0,
    this.isFree = false,
    required this.category,
    this.facultad = 'todas',
    this.sede = 'central',
    this.buildingCode = '',
    this.locationDetail = '',
    this.contactWhatsapp,
    this.contactInstagram,
    this.contactMessenger,
    this.contactTelegram,
    this.socialLinks = const [],
    this.imageUrls = const [],
    this.videoUrl,
    this.isSponsored = false,
    this.sponsorBadgeText,
    this.sponsorBrandName,
    required this.authorAlias,
    this.userId,
    required this.createdAt,
    this.moderationStatus = 0,
    this.reportedCount = 0,
    this.upvotes = 0,
    this.sharesCount = 0,
    this.isUpvotedByMe = false,
    this.status = 'available',
    this.isSellerVerified = false,
    this.isMine = false,
    this.sellerPublicId,
    this.sellerBusinessName,
    this.sellerPlanId = 'free',
    this.sellerPlanName = 'Estudiante',
    this.sellerBadgeText,
    this.sellerIsOnCampus = false,
    this.sellerBuildingCode,
    this.isBookmarked = false,
    this.expiresAt,
    this.score = 0.0,
    this.isHiddenFromFeed = false,
    this.bookmarkedAt,
  });

  String get formattedPrice {
    if (isFree || price <= 0.0) {
      return 'GRATIS';
    }
    return 'Q${price.toStringAsFixed(2)}';
  }

  bool get isSold => status == 'sold';
  bool get isReserved => status == 'reserved';
  bool get isAvailable => status == 'available';

  String? get normalizedSponsorBrandName {
    final name = sponsorBrandName?.trim();
    return name == null || name.isEmpty ? null : name;
  }

  bool get isHidden => isHiddenFromFeed || moderationStatus >= 2;
  bool get isUnderReview => moderationStatus == 1;

  int? get venceEnDias {
    if (expiresAt == null) return null;
    return expiresAt!.difference(DateTime.now()).inDays;
  }

  String? get planBadge => sellerBadgeText;
  String? get storeUrlId => sellerPublicId;

  bool get hasAnyContact =>
      (contactWhatsapp != null && contactWhatsapp!.trim().isNotEmpty) ||
      (contactInstagram != null && contactInstagram!.trim().isNotEmpty) ||
      (contactMessenger != null && contactMessenger!.trim().isNotEmpty) ||
      (contactTelegram != null && contactTelegram!.trim().isNotEmpty);

  String? get whatsappUrl {
    if (contactWhatsapp == null || contactWhatsapp!.trim().isEmpty) return null;
    final cleanPhone = contactWhatsapp!.replaceAll(RegExp(r'[^0-9+]'), '');
    final phone = cleanPhone.startsWith('+')
        ? cleanPhone.substring(1)
        : (cleanPhone.length == 8 ? '502$cleanPhone' : cleanPhone);
    final msg = Uri.encodeComponent(
      "Hola $authorAlias, vi tu publicación '$title' en el Marketplace universitario. ¿Sigue disponible?",
    );
    return 'https://wa.me/$phone?text=$msg';
  }

  String? get instagramUrl {
    if (contactInstagram == null || contactInstagram!.trim().isEmpty) {
      return null;
    }
    var user = contactInstagram!.trim();
    if (user.startsWith('http://') || user.startsWith('https://')) return user;
    if (user.startsWith('@')) user = user.substring(1);
    return 'https://instagram.com/$user';
  }

  String? get messengerUrl {
    if (contactMessenger == null || contactMessenger!.trim().isEmpty) {
      return null;
    }
    var user = contactMessenger!.trim();
    if (user.startsWith('http://') || user.startsWith('https://')) return user;
    if (user.startsWith('@')) user = user.substring(1);
    return 'https://m.me/$user';
  }

  String? get telegramUrl {
    if (contactTelegram == null || contactTelegram!.trim().isEmpty) return null;
    var user = contactTelegram!.trim();
    if (user.startsWith('http://') || user.startsWith('https://')) return user;
    if (user.startsWith('@')) user = user.substring(1);
    return 'https://t.me/$user';
  }

  MarketplaceItem copyWith({
    String? id,
    String? title,
    String? description,
    double? price,
    bool? isFree,
    String? category,
    String? facultad,
    String? sede,
    String? buildingCode,
    String? locationDetail,
    String? contactWhatsapp,
    String? contactInstagram,
    String? contactMessenger,
    String? contactTelegram,
    List<String>? socialLinks,
    List<String>? imageUrls,
    String? videoUrl,
    bool? isSponsored,
    String? sponsorBadgeText,
    String? sponsorBrandName,
    String? authorAlias,
    String? userId,
    DateTime? createdAt,
    int? moderationStatus,
    int? reportedCount,
    int? upvotes,
    int? sharesCount,
    bool? isUpvotedByMe,
    String? status,
    bool? isSellerVerified,
    bool? isMine,
    String? sellerPublicId,
    String? sellerBusinessName,
    String? sellerPlanId,
    String? sellerPlanName,
    String? sellerBadgeText,
    bool? sellerIsOnCampus,
    String? sellerBuildingCode,
    bool? isBookmarked,
    DateTime? expiresAt,
    double? score,
    bool? isHiddenFromFeed,
    DateTime? bookmarkedAt,
  }) {
    return MarketplaceItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      price: price ?? this.price,
      isFree: isFree ?? this.isFree,
      category: category ?? this.category,
      facultad: facultad ?? this.facultad,
      sede: sede ?? this.sede,
      buildingCode: buildingCode ?? this.buildingCode,
      locationDetail: locationDetail ?? this.locationDetail,
      contactWhatsapp: contactWhatsapp ?? this.contactWhatsapp,
      contactInstagram: contactInstagram ?? this.contactInstagram,
      contactMessenger: contactMessenger ?? this.contactMessenger,
      contactTelegram: contactTelegram ?? this.contactTelegram,
      socialLinks: socialLinks ?? this.socialLinks,
      imageUrls: imageUrls ?? this.imageUrls,
      videoUrl: videoUrl ?? this.videoUrl,
      isSponsored: isSponsored ?? this.isSponsored,
      sponsorBadgeText: sponsorBadgeText ?? this.sponsorBadgeText,
      sponsorBrandName: sponsorBrandName ?? this.sponsorBrandName,
      authorAlias: authorAlias ?? this.authorAlias,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      moderationStatus: moderationStatus ?? this.moderationStatus,
      reportedCount: reportedCount ?? this.reportedCount,
      upvotes: upvotes ?? this.upvotes,
      sharesCount: sharesCount ?? this.sharesCount,
      isUpvotedByMe: isUpvotedByMe ?? this.isUpvotedByMe,
      status: status ?? this.status,
      isSellerVerified: isSellerVerified ?? this.isSellerVerified,
      isMine: isMine ?? this.isMine,
      sellerPublicId: sellerPublicId ?? this.sellerPublicId,
      sellerBusinessName: sellerBusinessName ?? this.sellerBusinessName,
      sellerPlanId: sellerPlanId ?? this.sellerPlanId,
      sellerPlanName: sellerPlanName ?? this.sellerPlanName,
      sellerBadgeText: sellerBadgeText ?? this.sellerBadgeText,
      sellerIsOnCampus: sellerIsOnCampus ?? this.sellerIsOnCampus,
      sellerBuildingCode: sellerBuildingCode ?? this.sellerBuildingCode,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      expiresAt: expiresAt ?? this.expiresAt,
      score: score ?? this.score,
      isHiddenFromFeed: isHiddenFromFeed ?? this.isHiddenFromFeed,
      bookmarkedAt: bookmarkedAt ?? this.bookmarkedAt,
    );
  }

  factory MarketplaceItem.fromJson(Map<String, dynamic> json) =>
      MarketplaceItem.fromMap(json);

  factory MarketplaceItem.fromMap(
    Map<String, dynamic> map, {
    bool isUpvotedByMe = false,
  }) {
    List<String> imgs = [];
    if (map['image_urls'] is List) {
      imgs = (map['image_urls'] as List).map((e) => e.toString()).toList();
    } else if (map['image_url'] is String &&
        (map['image_url'] as String).isNotEmpty) {
      imgs = [map['image_url'] as String];
    }

    List<String> links = [];
    if (map['social_links'] is List) {
      links = (map['social_links'] as List).map((e) => e.toString()).toList();
    }

    final rawPrice = map['price'];
    final priceVal = (rawPrice is num)
        ? rawPrice.toDouble()
        : double.tryParse(rawPrice?.toString() ?? '0') ?? 0.0;
    final isFreeVal = map['is_free'] == true || priceVal <= 0.0;

    final modStatus = (map['moderation_status'] is int)
        ? map['moderation_status'] as int
        : int.tryParse(map['moderation_status']?.toString() ?? '0') ?? 0;

    final rawScore = map['score'];
    final scoreVal = (rawScore is num)
        ? rawScore.toDouble()
        : double.tryParse(rawScore?.toString() ?? '0') ?? 0.0;

    final isHiddenFeed = map['is_hidden'] == true || modStatus >= 2;

    return MarketplaceItem(
      id: map['id']?.toString() ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      price: priceVal,
      isFree: isFreeVal,
      category: map['category'] ?? 'otros_articulos',
      facultad: map['facultad'] ?? 'todas',
      sede: map['sede'] ?? 'central',
      buildingCode: map['building_code'] ?? '',
      locationDetail: map['location_detail'] ?? '',
      contactWhatsapp: map['contact_whatsapp'],
      contactInstagram: map['contact_instagram'],
      contactMessenger: map['contact_messenger'],
      contactTelegram: map['contact_telegram'],
      socialLinks: links,
      imageUrls: imgs,
      videoUrl: map['video_url'],
      isSponsored: map['is_sponsored'] == true,
      sponsorBadgeText: map['sponsor_badge_text'],
      sponsorBrandName:
          (map['sponsor_brand_name'] ??
                  map['sponsor_name'] ??
                  map['brand_name'])
              ?.toString(),
      authorAlias: map['author_alias'] ?? 'Estudiante Emprendedor',
      userId: null,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      moderationStatus: modStatus,
      reportedCount: (map['reported_count'] is int)
          ? map['reported_count']
          : int.tryParse(map['reported_count']?.toString() ?? '0') ?? 0,
      upvotes: (map['upvotes'] is int)
          ? map['upvotes']
          : int.tryParse(map['upvotes']?.toString() ?? '0') ?? 0,
      sharesCount: () {
        final rawShares = map['shares_count'] ?? map['shares'];
        int parsedShares = 0;
        if (rawShares != null) {
          parsedShares = (rawShares is int)
              ? rawShares
              : int.tryParse(rawShares.toString()) ?? 0;
        }
        final itemId = map['id']?.toString() ?? '';
        final localShares = ShareCountService.getCachedCount(itemId);
        return localShares > parsedShares ? localShares : parsedShares;
      }(),
      isUpvotedByMe: isUpvotedByMe || map['is_upvoted_by_me'] == true,
      status: map['status']?.toString() ?? 'available',
      isSellerVerified: map['seller_is_verified'] == true ||
          map['is_seller_verified'] == true ||
          map['is_verified'] == true,
      isMine: map['is_mine'] == true,
      sellerPublicId: map['seller_public_id']?.toString(),
      sellerBusinessName: map['seller_business_name']?.toString(),
      sellerPlanId: map['seller_plan_id']?.toString() ?? 'free',
      sellerPlanName: map['seller_plan_name']?.toString() ?? 'Estudiante',
      sellerBadgeText: map['seller_badge_text']?.toString(),
      sellerIsOnCampus: map['seller_is_on_campus'] == true,
      sellerBuildingCode: map['seller_building_code']?.toString(),
      isBookmarked: map['is_bookmarked_by_me'] == true ||
          map['is_bookmarked'] == true,
      expiresAt: map['expires_at'] != null
          ? DateTime.tryParse(map['expires_at'].toString())
          : null,
      score: scoreVal,
      isHiddenFromFeed: isHiddenFeed,
      bookmarkedAt: map['bookmarked_at'] != null
          ? DateTime.tryParse(map['bookmarked_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
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
      'moderation_status': moderationStatus,
      'reported_count': reportedCount,
      'upvotes': upvotes,
      'status': status,
    };
  }
}
