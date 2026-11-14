class MarketplaceMetrics {
  final String itemId;
  final String title;
  final int views;
  final int clickWhatsapp;
  final int clickTelegram;
  final int clickInstagram;
  final int clickMessenger;
  final int shares;
  final double contactRate;

  const MarketplaceMetrics({
    required this.itemId,
    required this.title,
    this.views = 0,
    this.clickWhatsapp = 0,
    this.clickTelegram = 0,
    this.clickInstagram = 0,
    this.clickMessenger = 0,
    this.shares = 0,
    this.contactRate = 0.0,
  });

  int get totalClicks =>
      clickWhatsapp + clickTelegram + clickInstagram + clickMessenger;

  factory MarketplaceMetrics.fromMap(Map<String, dynamic> map) {
    int parseInt(dynamic val) {
      if (val is int) return val;
      return int.tryParse(val?.toString() ?? '0') ?? 0;
    }

    final rawRate = map['contact_rate'] ?? map['contactRate'];
    final rate = (rawRate is num)
        ? rawRate.toDouble()
        : double.tryParse(rawRate?.toString() ?? '0') ?? 0.0;

    return MarketplaceMetrics(
      itemId: (map['item_id'] ?? map['itemId'])?.toString() ?? '',
      title: (map['title'] ?? '')?.toString() ?? '',
      views: parseInt(map['views']),
      clickWhatsapp: parseInt(map['click_whatsapp'] ?? map['clickWhatsapp']),
      clickTelegram: parseInt(map['click_telegram'] ?? map['clickTelegram']),
      clickInstagram:
          parseInt(map['click_instagram'] ?? map['clickInstagram']),
      clickMessenger:
          parseInt(map['click_messenger'] ?? map['clickMessenger']),
      shares: parseInt(map['shares']),
      contactRate: rate,
    );
  }

  factory MarketplaceMetrics.fromJson(Map<String, dynamic> json) =>
      MarketplaceMetrics.fromMap(json);

  Map<String, dynamic> toMap() {
    return {
      'item_id': itemId,
      'title': title,
      'views': views,
      'click_whatsapp': clickWhatsapp,
      'click_telegram': clickTelegram,
      'click_instagram': clickInstagram,
      'click_messenger': clickMessenger,
      'shares': shares,
      'contact_rate': contactRate,
    };
  }
}
