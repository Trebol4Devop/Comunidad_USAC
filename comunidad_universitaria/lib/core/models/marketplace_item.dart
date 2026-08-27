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
  final String authorAlias;
  final String? userId;
  final DateTime createdAt;
  final int moderationStatus;
  final int upvotes;
  final bool isUpvotedByMe;

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
    required this.authorAlias,
    this.userId,
    required this.createdAt,
    this.moderationStatus = 0,
    this.upvotes = 0,
    this.isUpvotedByMe = false,
  });

  String get formattedPrice {
    if (isFree || price <= 0.0) {
      return 'GRATIS';
    }
    return 'Q${price.toStringAsFixed(2)}';
  }

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
    final msg = Uri.encodeComponent('¡Hola! Vi tu publicación en Comunidad USAC sobre "$title". ¿Sigue disponible?');
    return 'https://wa.me/$phone?text=$msg';
  }

  String? get instagramUrl {
    if (contactInstagram == null || contactInstagram!.trim().isEmpty) return null;
    var user = contactInstagram!.trim();
    if (user.startsWith('http://') || user.startsWith('https://')) return user;
    if (user.startsWith('@')) user = user.substring(1);
    return 'https://instagram.com/$user';
  }

  String? get messengerUrl {
    if (contactMessenger == null || contactMessenger!.trim().isEmpty) return null;
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
    String? authorAlias,
    String? userId,
    DateTime? createdAt,
    int? moderationStatus,
    int? upvotes,
    bool? isUpvotedByMe,
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
      authorAlias: authorAlias ?? this.authorAlias,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      moderationStatus: moderationStatus ?? this.moderationStatus,
      upvotes: upvotes ?? this.upvotes,
      isUpvotedByMe: isUpvotedByMe ?? this.isUpvotedByMe,
    );
  }

  factory MarketplaceItem.fromMap(Map<String, dynamic> map, {bool isUpvotedByMe = false}) {
    List<String> imgs = [];
    if (map['image_urls'] is List) {
      imgs = (map['image_urls'] as List).map((e) => e.toString()).toList();
    } else if (map['image_url'] is String && (map['image_url'] as String).isNotEmpty) {
      imgs = [map['image_url'] as String];
    }

    List<String> links = [];
    if (map['social_links'] is List) {
      links = (map['social_links'] as List).map((e) => e.toString()).toList();
    }

    final rawPrice = map['price'];
    final priceVal = (rawPrice is num) ? rawPrice.toDouble() : double.tryParse(rawPrice?.toString() ?? '0') ?? 0.0;
    final isFreeVal = map['is_free'] == true || priceVal <= 0.0;

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
      authorAlias: map['author_alias'] ?? 'Estudiante Emprendedor',
      userId: map['user_id']?.toString(),
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now() : DateTime.now(),
      moderationStatus: (map['moderation_status'] is int) ? map['moderation_status'] : int.tryParse(map['moderation_status']?.toString() ?? '0') ?? 0,
      upvotes: (map['upvotes'] is int) ? map['upvotes'] : int.tryParse(map['upvotes']?.toString() ?? '0') ?? 0,
      isUpvotedByMe: isUpvotedByMe,
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
      'user_id': userId,
      'moderation_status': moderationStatus,
      'upvotes': upvotes,
    };
  }
}
