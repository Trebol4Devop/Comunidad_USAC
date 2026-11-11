class SsoSecurityValidator {
  /// Allowed hosts for local development
  static const Set<String> allowedLocalhostHosts = {
    'localhost',
    '127.0.0.1',
  };

  /// Allowed domain suffixes for PEMTREE in production / preview.
  /// Se usa el host completo de PEMTREE (no `netlify.app` a secas) para que
  /// un sitio ajeno como `evil.netlify.app` no pueda recibir tokens de sesión.
  /// Los previews de Netlify tienen la forma `<deploy>--pemtree.netlify.app`,
  /// que sí termina en `.pemtree.netlify.app`.
  static const List<String> allowedDomainSuffixes = [
    'pemtree.netlify.app',
    'pemtree.com',
    'pemtree.app',
    'pemtree.org',
  ];

  /// Única ruta válida del callback en producción.
  static const String productionCallbackPath = '/auth/callback';

  /// Default exact local redirect URI for PEMTREE in development
  static const String defaultLocalRedirectUri = 'http://localhost:5173/auth/callback';

  /// Validates that the redirectUri strictly belongs to authorized origins
  /// (Open Redirect Protection), without any asterisks or wildcards.
  static bool isValidRedirectUri(String? uriString) {
    final effectiveUri = (uriString == null || uriString.trim().isEmpty)
        ? defaultLocalRedirectUri
        : uriString.trim();

    // Strictly reject wildcards or asterisks in the redirect URL
    if (effectiveUri.contains('*')) return false;

    final uri = Uri.tryParse(effectiveUri);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) return false;

    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();

    // Prevent userInfo spoofing (e.g. https://evil.com@attacker.com)
    if (uri.userInfo.isNotEmpty) return false;

    // 1. Localhost development (PEMTREE on local dev server: http://localhost:5173)
    if (allowedLocalhostHosts.contains(host)) {
      if (scheme != 'http' && scheme != 'https') return false;
      return uri.path == productionCallbackPath;
    }

    // 2. Production / Preview domains (MUST be HTTPS)
    if (scheme != 'https') return false;

    for (final domain in allowedDomainSuffixes) {
      // Netlify publica previews como `<deploy>--pemtree.netlify.app` (guiones,
      // no punto), así que ese caso necesita su propia comparación.
      final hostMatches = domain == 'pemtree.netlify.app'
          ? (host == domain || host.endsWith('--$domain'))
          : (host == domain || host.endsWith('.$domain'));
      if (hostMatches) {
        return uri.path == productionCallbackPath;
      }
    }

    return false;
  }

  /// Builds the success redirect URL with access_token and refresh_token
  /// inside the hash fragment (#), preserving the state parameter.
  /// Uses exactly the redirect_uri provided or http://localhost:5173/auth/callback in development.
  static String buildSuccessRedirectUrl({
    required String redirectUri,
    required String accessToken,
    required String refreshToken,
    required String? state,
    String tokenType = 'bearer',
    int? expiresIn,
  }) {
    final cleanRedirect = redirectUri.trim().isEmpty ? defaultLocalRedirectUri : redirectUri.trim();
    final baseUri = Uri.parse(cleanRedirect);
    final params = <String, String>{
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'token_type': tokenType,
      if (expiresIn != null) 'expires_in': expiresIn.toString(),
      if (state != null && state.trim().isNotEmpty) 'state': state.trim(),
    };

    final hashQuery = params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');

    final existingFragment = baseUri.fragment;
    final finalFragment = existingFragment.isNotEmpty ? '$existingFragment&$hashQuery' : hashQuery;

    return baseUri.replace(fragment: finalFragment).toString();
  }

  /// Builds the cancel redirect URL with error info inside the hash fragment (#),
  /// preserving the state parameter.
  /// Uses exactly the redirect_uri provided or http://localhost:5173/auth/callback in development.
  static String buildCancelRedirectUrl({
    required String redirectUri,
    required String? state,
    String error = 'access_denied',
    String errorDescription = 'El usuario canceló la autorización',
  }) {
    final cleanRedirect = redirectUri.trim().isEmpty ? defaultLocalRedirectUri : redirectUri.trim();
    final baseUri = Uri.parse(cleanRedirect);
    final params = <String, String>{
      'error': error,
      'error_description': errorDescription,
      if (state != null && state.trim().isNotEmpty) 'state': state.trim(),
    };

    final hashQuery = params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');

    final existingFragment = baseUri.fragment;
    final finalFragment = existingFragment.isNotEmpty ? '$existingFragment&$hashQuery' : hashQuery;

    return baseUri.replace(fragment: finalFragment).toString();
  }
}
