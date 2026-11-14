class SellerProfile {
  final String publicId;
  final String displayName;
  final String? businessName;
  final String? businessDescription;
  final String? businessLogoUrl;
  final String? businessBannerUrl;
  final String? currentBuildingCode;
  final String? currentLocationNote;
  final Map<String, dynamic>? businessHours;
  final String sellerType;
  final String planId;
  final String planName;
  final String? badgeText;
  final bool isVerified;
  final bool isOnCampus;
  final bool isMyStore;
  final DateTime? memberSince;
  final int activeItems;

  const SellerProfile({
    required this.publicId,
    required this.displayName,
    this.businessName,
    this.businessDescription,
    this.businessLogoUrl,
    this.businessBannerUrl,
    this.currentBuildingCode,
    this.currentLocationNote,
    this.businessHours,
    this.sellerType = 'student',
    this.planId = 'free',
    this.planName = 'Estudiante',
    this.badgeText,
    this.isVerified = false,
    this.isOnCampus = false,
    this.isMyStore = false,
    this.memberSince,
    this.activeItems = 0,
  });

  String get storeInitials {
    final raw = (businessName != null && businessName!.trim().isNotEmpty)
        ? businessName!.trim()
        : displayName.trim();
    if (raw.isEmpty) return 'US';
    final parts =
        raw.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return raw.substring(0, raw.length >= 2 ? 2 : 1).toUpperCase();
  }

  factory SellerProfile.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic>? hours;
    if (map['business_hours'] is Map) {
      hours = Map<String, dynamic>.from(map['business_hours'] as Map);
    } else if (map['businessHours'] is Map) {
      hours = Map<String, dynamic>.from(map['businessHours'] as Map);
    }

    final rawActive = map['active_items'] ?? map['activeItems'];
    final active = (rawActive is int)
        ? rawActive
        : int.tryParse(rawActive?.toString() ?? '0') ?? 0;

    final rawMemberSince =
        map['member_since'] ?? map['memberSince'] ?? map['created_at'];
    final since = rawMemberSince != null
        ? DateTime.tryParse(rawMemberSince.toString())
        : null;

    return SellerProfile(
      publicId: (map['public_id'] ?? map['publicId'])?.toString() ?? '',
      displayName: (map['display_name'] ?? map['displayName'])?.toString() ??
          'Estudiante Emprendedor',
      businessName: (map['business_name'] ?? map['businessName'])?.toString(),
      businessDescription:
          (map['business_description'] ?? map['businessDescription'])
              ?.toString(),
      businessLogoUrl:
          (map['business_logo_url'] ?? map['businessLogoUrl'])?.toString(),
      businessBannerUrl:
          (map['business_banner_url'] ?? map['businessBannerUrl'])?.toString(),
      currentBuildingCode:
          (map['current_building_code'] ?? map['currentBuildingCode'])
              ?.toString(),
      currentLocationNote:
          (map['current_location_note'] ?? map['currentLocationNote'])
              ?.toString(),
      businessHours: hours,
      sellerType:
          (map['seller_type'] ?? map['sellerType'])?.toString() ?? 'student',
      planId: (map['plan_id'] ?? map['planId'])?.toString() ?? 'free',
      planName:
          (map['plan_name'] ?? map['planName'])?.toString() ?? 'Estudiante',
      badgeText: (map['badge_text'] ?? map['badgeText'])?.toString(),
      isVerified: map['is_verified'] == true || map['isVerified'] == true,
      isOnCampus: map['is_on_campus'] == true ||
          map['isOnCampus'] == true ||
          map['is_currently_on_campus'] == true,
      isMyStore: map['is_my_store'] == true || map['isMyStore'] == true,
      memberSince: since,
      activeItems: active,
    );
  }

  factory SellerProfile.fromJson(Map<String, dynamic> json) =>
      SellerProfile.fromMap(json);

  Map<String, dynamic> toMap() {
    return {
      'public_id': publicId,
      'display_name': displayName,
      'business_name': businessName,
      'business_description': businessDescription,
      'business_logo_url': businessLogoUrl,
      'business_banner_url': businessBannerUrl,
      'current_building_code': currentBuildingCode,
      'current_location_note': currentLocationNote,
      'business_hours': businessHours,
      'seller_type': sellerType,
      'plan_id': planId,
      'plan_name': planName,
      'badge_text': badgeText,
      'is_verified': isVerified,
      'is_on_campus': isOnCampus,
      'is_my_store': isMyStore,
      'member_since': memberSince?.toIso8601String(),
      'active_items': activeItems,
    };
  }
}
