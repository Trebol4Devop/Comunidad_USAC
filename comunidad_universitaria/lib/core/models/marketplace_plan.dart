class MarketplacePlan {
  final String id;
  final String name;
  final double priceMonthly;
  final int maxActiveItems;
  final int maxImagesPerItem;
  final int sortOrder;
  final bool allowVideo;
  final bool autoSponsorItems;
  final bool hideCompetitorRelated;
  final bool isActive;
  final String? defaultBadgeText;
  final List<String> features;

  const MarketplacePlan({
    required this.id,
    required this.name,
    this.priceMonthly = 0.0,
    this.maxActiveItems = 3,
    this.maxImagesPerItem = 2,
    this.sortOrder = 0,
    this.allowVideo = false,
    this.autoSponsorItems = false,
    this.hideCompetitorRelated = false,
    this.isActive = true,
    this.defaultBadgeText,
    this.features = const [],
  });

  factory MarketplacePlan.fromMap(Map<String, dynamic> map) {
    List<String> feats = const [];
    if (map['features'] is List) {
      feats = (map['features'] as List).map((e) => e.toString()).toList();
    }

    final rawPrice = map['price_monthly'] ?? map['priceMonthly'];
    final priceVal = (rawPrice is num)
        ? rawPrice.toDouble()
        : double.tryParse(rawPrice?.toString() ?? '0') ?? 0.0;

    final rawMaxItems = map['max_active_items'] ?? map['maxActiveItems'];
    final maxItems = (rawMaxItems is int)
        ? rawMaxItems
        : int.tryParse(rawMaxItems?.toString() ?? '3') ?? 3;

    final rawMaxImgs = map['max_images_per_item'] ?? map['maxImagesPerItem'];
    final maxImgs = (rawMaxImgs is int)
        ? rawMaxImgs
        : int.tryParse(rawMaxImgs?.toString() ?? '2') ?? 2;

    final rawSort = map['sort_order'] ?? map['sortOrder'];
    final sort = (rawSort is int)
        ? rawSort
        : int.tryParse(rawSort?.toString() ?? '0') ?? 0;

    return MarketplacePlan(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      priceMonthly: priceVal,
      maxActiveItems: maxItems,
      maxImagesPerItem: maxImgs,
      sortOrder: sort,
      allowVideo: map['allow_video'] == true || map['allowVideo'] == true,
      autoSponsorItems:
          map['auto_sponsor_items'] == true || map['autoSponsorItems'] == true,
      hideCompetitorRelated: map['hide_competitor_related'] == true ||
          map['hideCompetitorRelated'] == true,
      isActive: map['is_active'] != false && map['isActive'] != false,
      defaultBadgeText:
          (map['default_badge_text'] ?? map['defaultBadgeText'])?.toString(),
      features: feats,
    );
  }

  factory MarketplacePlan.fromJson(Map<String, dynamic> json) =>
      MarketplacePlan.fromMap(json);

  String get formattedPrice {
    if (priceMonthly <= 0.0) return 'Q0';
    return 'Q${priceMonthly.toStringAsFixed(2)}';
  }

  bool get isUnlimited => maxActiveItems == 0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price_monthly': priceMonthly,
      'max_active_items': maxActiveItems,
      'max_images_per_item': maxImagesPerItem,
      'sort_order': sortOrder,
      'allow_video': allowVideo,
      'auto_sponsor_items': autoSponsorItems,
      'hide_competitor_related': hideCompetitorRelated,
      'is_active': isActive,
      'default_badge_text': defaultBadgeText,
      'features': features,
    };
  }
}
