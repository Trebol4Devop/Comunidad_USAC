class MarketplaceSellerStatus {
  final bool canPublish;
  final bool allowVideo;
  final bool isVerified;
  final bool isOnCampus;
  final String reason;
  final String planId;
  final String planName;
  final String sellerType;
  final String verificationStatus;
  final int maxActiveItems;
  final int maxImagesPerItem;
  final int activeItems;
  final int remainingSlots;
  final DateTime? expiresAt;
  final String? sellerPublicId;
  final String? currentBuildingCode;

  const MarketplaceSellerStatus({
    this.canPublish = false,
    this.allowVideo = false,
    this.isVerified = false,
    this.isOnCampus = false,
    this.reason = '',
    this.planId = 'free',
    this.planName = 'Estudiante',
    this.sellerType = 'student',
    this.verificationStatus = 'pending',
    this.maxActiveItems = 3,
    this.maxImagesPerItem = 2,
    this.activeItems = 0,
    this.remainingSlots = 3,
    this.expiresAt,
    this.sellerPublicId,
    this.currentBuildingCode,
  });

  bool get isUnlimited => maxActiveItems == 0;

  factory MarketplaceSellerStatus.fromMap(Map<String, dynamic> map) {
    final rawMaxItems = map['max_active_items'] ?? map['maxActiveItems'];
    final maxItems = (rawMaxItems is int)
        ? rawMaxItems
        : int.tryParse(rawMaxItems?.toString() ?? '3') ?? 3;

    final rawMaxImgs = map['max_images_per_item'] ?? map['maxImagesPerItem'];
    final maxImgs = (rawMaxImgs is int)
        ? rawMaxImgs
        : int.tryParse(rawMaxImgs?.toString() ?? '2') ?? 2;

    final rawActive = map['active_items'] ?? map['activeItems'];
    final active = (rawActive is int)
        ? rawActive
        : int.tryParse(rawActive?.toString() ?? '0') ?? 0;

    final rawSlots = map['remaining_slots'] ?? map['remainingSlots'];
    final slots = (rawSlots is int)
        ? rawSlots
        : (int.tryParse(rawSlots?.toString() ?? '') ??
            (maxItems == 0 ? -1 : (maxItems - active).clamp(0, 999999)));

    final rawExpires =
        map['expires_at'] ?? map['expiresAt'] ?? map['plan_expires_at'];
    final exp =
        rawExpires != null ? DateTime.tryParse(rawExpires.toString()) : null;

    return MarketplaceSellerStatus(
      canPublish: map['can_publish'] == true || map['canPublish'] == true,
      allowVideo: map['allow_video'] == true || map['allowVideo'] == true,
      isVerified: map['is_verified'] == true || map['isVerified'] == true,
      isOnCampus: map['is_on_campus'] == true ||
          map['isOnCampus'] == true ||
          map['is_currently_on_campus'] == true,
      reason: (map['reason'] ?? '')?.toString() ?? '',
      planId: (map['plan_id'] ?? map['planId'])?.toString() ?? 'free',
      planName:
          (map['plan_name'] ?? map['planName'])?.toString() ?? 'Estudiante',
      sellerType:
          (map['seller_type'] ?? map['sellerType'])?.toString() ?? 'student',
      verificationStatus:
          (map['verification_status'] ?? map['verificationStatus'])
                  ?.toString() ??
              'pending',
      maxActiveItems: maxItems,
      maxImagesPerItem: maxImgs,
      activeItems: active,
      remainingSlots: slots,
      expiresAt: exp,
      sellerPublicId:
          (map['seller_public_id'] ?? map['sellerPublicId'])?.toString(),
      currentBuildingCode:
          (map['current_building_code'] ?? map['currentBuildingCode'])
              ?.toString(),
    );
  }

  factory MarketplaceSellerStatus.fromJson(Map<String, dynamic> json) =>
      MarketplaceSellerStatus.fromMap(json);

  Map<String, dynamic> toMap() {
    return {
      'can_publish': canPublish,
      'allow_video': allowVideo,
      'is_verified': isVerified,
      'is_on_campus': isOnCampus,
      'reason': reason,
      'plan_id': planId,
      'plan_name': planName,
      'seller_type': sellerType,
      'verification_status': verificationStatus,
      'max_active_items': maxActiveItems,
      'max_images_per_item': maxImagesPerItem,
      'active_items': activeItems,
      'remaining_slots': remainingSlots,
      'expires_at': expiresAt?.toIso8601String(),
      'seller_public_id': sellerPublicId,
      'current_building_code': currentBuildingCode,
    };
  }
}
