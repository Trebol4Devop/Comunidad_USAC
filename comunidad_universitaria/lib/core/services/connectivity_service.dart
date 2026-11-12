import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Servicio centralizado de conectividad a nivel de aplicación.
///
/// Encapsula la biblioteca `connectivity_plus` para monitorear el estado de red,
/// proveer streams reactivos y facilitar pruebas unitarias sin dependencias nativas.
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();

  /// Instancia singleton para acceso global.
  static ConnectivityService get instance => _instance;

  factory ConnectivityService() => _instance;

  final Connectivity _connectivity;

  ConnectivityService._internal({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  /// Constructor con inyección de dependencias para testing.
  @visibleForTesting
  factory ConnectivityService.custom({required Connectivity connectivity}) {
    return ConnectivityService._internal(connectivity: connectivity);
  }

  /// Override estático para pruebas unitarias. Si no es null, `isConnected` retorna este valor.
  @visibleForTesting
  static bool? debugIsConnected;

  /// Retorna `true` si el dispositivo tiene al menos una interfaz de red activa distinta a `none`.
  Future<bool> get isConnected async {
    if (debugIsConnected != null) return debugIsConnected!;

    try {
      final results = await _connectivity.checkConnectivity();
      return isOnline(results);
    } catch (e) {
      debugPrint('Aviso ConnectivityService: error al consultar conectividad ($e). Fallback a online.');
      return true;
    }
  }

  /// Consulta el listado crudo de interfaces activas reportadas por la plataforma.
  Future<List<ConnectivityResult>> checkConnectivity() async {
    try {
      return await _connectivity.checkConnectivity();
    } catch (_) {
      return const [ConnectivityResult.other];
    }
  }

  /// Stream reactivo que emite `true` (en línea) o `false` (sin conexión).
  ///
  /// Filtra valores duplicados consecutivos mediante `.distinct()`.
  Stream<bool> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged
        .map(isOnline)
        .distinct();
  }

  /// Stream con los resultados crudos emitidos por `connectivity_plus`.
  Stream<List<ConnectivityResult>> get onRawConnectivityChanged {
    return _connectivity.onConnectivityChanged;
  }

  /// Determina si un listado de resultados de conectividad representa un estado en línea.
  static bool isOnline(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((r) => r != ConnectivityResult.none);
  }

  /// Retorna una descripción amigable en español del tipo de conexión principal.
  static String getConnectionTypeDescription(List<ConnectivityResult> results) {
    if (!isOnline(results)) return 'Sin conexión';

    if (results.contains(ConnectivityResult.wifi)) return 'Wi-Fi';
    if (results.contains(ConnectivityResult.ethernet)) return 'Ethernet';
    if (results.contains(ConnectivityResult.mobile)) return 'Datos móviles';
    if (results.contains(ConnectivityResult.vpn)) return 'VPN';
    if (results.contains(ConnectivityResult.bluetooth)) return 'Bluetooth Tethering';
    return 'Red activa';
  }
}
