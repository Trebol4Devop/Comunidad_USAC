class MarketplaceException implements Exception {
  final String message;
  final String? code;

  const MarketplaceException(this.message, {this.code});

  @override
  String toString() =>
      'MarketplaceException: $message${code != null ? ' ($code)' : ''}';
}
