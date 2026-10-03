import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef FakeResponseBuilder = dynamic Function(http.Request request);

/// Servidor simulado para PostgREST y endpoints de Supabase.
///
/// Utiliza `MockClient` de `package:http/testing.dart` inyectado en el constructor
/// de `SupabaseClient(url, key, httpClient: ...)`. Permite registrar rutas por método HTTP
/// y ruta (o regex), capturar las peticiones emitidas y devolver payloads JSON reales.
class FakePostgrestServer {
  FakePostgrestServer({
    this.baseUrl = 'https://fake.supabase.co',
    this.anonKey = 'fake-anon-key',
  });

  final String baseUrl;
  final String anonKey;
  final List<_RouteHandler> _routes = [];
  final List<http.Request> recordedRequests = [];

  /// Registra un handler para un método y patrón de ruta (String exacto o RegExp).
  void on(
    String method,
    Pattern pathPattern,
    FakeResponseBuilder responseBuilder, {
    int statusCode = 200,
    Map<String, String>? headers,
  }) {
    _routes.add(_RouteHandler(
      method: method.toUpperCase(),
      pattern: pathPattern,
      handler: (req) async {
        final result = responseBuilder(req);
        final dynamic resolved = result is Future ? await result : result;
        if (resolved is http.Response) {
          if (resolved.request == null) {
            return http.Response(
              resolved.body,
              resolved.statusCode,
              headers: resolved.headers,
              request: req,
            );
          }
          return resolved;
        }

        final resHeaders = <String, String>{
          'content-type': 'application/json; charset=utf-8',
          ...?headers,
        };

        final body = resolved is String ? resolved : jsonEncode(resolved);
        return http.Response(body, statusCode, headers: resHeaders, request: req);
      },
    ));
  }

  /// Atajo para peticiones GET.
  void onGet(Pattern pathPattern, FakeResponseBuilder responseBuilder, {int statusCode = 200}) {
    on('GET', pathPattern, responseBuilder, statusCode: statusCode);
  }

  /// Atajo para peticiones POST.
  void onPost(Pattern pathPattern, FakeResponseBuilder responseBuilder, {int statusCode = 200}) {
    on('POST', pathPattern, responseBuilder, statusCode: statusCode);
  }

  /// Atajo para peticiones PATCH.
  void onPatch(Pattern pathPattern, FakeResponseBuilder responseBuilder, {int statusCode = 200}) {
    on('PATCH', pathPattern, responseBuilder, statusCode: statusCode);
  }

  /// Atajo para peticiones DELETE.
  void onDelete(Pattern pathPattern, FakeResponseBuilder responseBuilder, {int statusCode = 200}) {
    on('DELETE', pathPattern, responseBuilder, statusCode: statusCode);
  }

  /// Limpia las rutas y peticiones registradas.
  void reset() {
    _routes.clear();
    recordedRequests.clear();
  }

  /// Handler principal del MockClient.
  Future<http.Response> handle(http.Request request) async {
    recordedRequests.add(request);
    final path = request.url.path;
    final method = request.method.toUpperCase();

    for (final route in _routes.reversed) {
      if (route.method == method && route.matches(path)) {
        return await route.handler(request);
      }
    }

    // Respuesta por defecto si no coincide ninguna regla explícita:
    final accept = request.headers['accept'] ?? '';
    if (accept.contains('vnd.pgrst.object')) {
      return http.Response(
        '{}',
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
        request: request,
      );
    }
    return http.Response(
      '[]',
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
      request: request,
    );
  }

  /// Instancia un `SupabaseClient` con este servidor simulado.
  SupabaseClient buildClient() {
    return SupabaseClient(
      baseUrl,
      anonKey,
      authOptions: AuthClientOptions(
        autoRefreshToken: false,
        authFlowType: AuthFlowType.pkce,
        pkceAsyncStorage: _MemoryGotrueAsyncStorage(),
      ),
      httpClient: MockClient(handle),
    );
  }
}

class _MemoryGotrueAsyncStorage extends GotrueAsyncStorage {
  final Map<String, String> _values = {};

  @override
  Future<String?> getItem({required String key}) async => _values[key];

  @override
  Future<void> setItem({required String key, required String value}) async {
    _values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    _values.remove(key);
  }
}

class _RouteHandler {
  _RouteHandler({
    required this.method,
    required this.pattern,
    required this.handler,
  });

  final String method;
  final Pattern pattern;
  final Future<http.Response> Function(http.Request) handler;

  bool matches(String path) {
    if (pattern is String) {
      return path == pattern || path.endsWith(pattern as String);
    } else if (pattern is RegExp) {
      return (pattern as RegExp).hasMatch(path);
    }
    return false;
  }
}

/// Helper funcional rápido para construir un SupabaseClient con un callback simple.
SupabaseClient buildFakeClient({
  required dynamic Function(http.Request request) handler,
  String baseUrl = 'https://fake.supabase.co',
  String anonKey = 'fake-anon-key',
}) {
  final client = MockClient((request) async {
    final result = handler(request);
    final dynamic resolved = result is Future ? await result : result;
    if (resolved is http.Response) {
      if (resolved.request == null) {
        return http.Response(
          resolved.body,
          resolved.statusCode,
          headers: resolved.headers,
          request: request,
        );
      }
      return resolved;
    }
    return http.Response(
      resolved is String ? resolved : jsonEncode(resolved),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
      request: request,
    );
  });

  return SupabaseClient(baseUrl, anonKey, httpClient: client);
}
