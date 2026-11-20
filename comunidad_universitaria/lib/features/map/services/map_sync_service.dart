import 'dart:convert';
import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usac_campus_map/usac_campus_map.dart';
import '../../../core/services/connectivity_service.dart';

Map<String, Map<String, dynamic>> _decodeMapJsonBundle(
  Map<String, String> raw,
) {
  return {
    'boundary': jsonDecode(raw['boundary']!) as Map<String, dynamic>,
    'buildings': jsonDecode(raw['buildings']!) as Map<String, dynamic>,
    'graph': jsonDecode(raw['graph']!) as Map<String, dynamic>,
    'pois': jsonDecode(raw['pois']!) as Map<String, dynamic>,
  };
}

/// Servicio de sincronización cartográfica con Cloudflare R2 y almacenamiento en caché inteligente.
/// Evita descargas redundantes comparando versiones en `map_version.json` (~150 B).
class MapSyncService {
  /// URL base pública de Cloudflare R2 para los assets cartográficos.
  static String r2BaseUrl =
      const String.fromEnvironment('R2_MAP_BASE_URL', defaultValue: 'https://usac-map-assets.r2.dev');

  static const String keyBuildingsVer = 'cached_buildings_version';
  static const String keyPoisVer = 'cached_pois_version';
  static const String keyGraphVer = 'cached_graph_version';

  @visibleForTesting
  static String? debugDocumentsPath;

  @visibleForTesting
  static bool? debugUseCompute;

  static Future<String> _getStorageDir() async {
    if (debugDocumentsPath != null) return debugDocumentsPath!;
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  /// Sincroniza selectivamente los activos cartográficos desde Cloudflare R2 si cambiaron de versión.
  /// Retorna `true` si se descargó alguna actualización.
  static Future<bool> syncMapAssetsIfNeeded({
    http.Client? httpClient,
    SharedPreferences? preferences,
    ConnectivityService? connectivityService,
  }) async {
    final connectivity = connectivityService ?? ConnectivityService.instance;
    final isOnline = await connectivity.isConnected;
    if (!isOnline) {
      debugPrint('MapSyncService: Dispositivo sin conexión. Se omite comprobación con R2.');
      return false;
    }

    final client = httpClient ?? http.Client();
    final prefs = preferences ?? await SharedPreferences.getInstance();
    bool updated = false;

    try {
      final uri = Uri.parse(
        '$r2BaseUrl/map_version.json?t=${DateTime.now().millisecondsSinceEpoch}',
      );
      final response = await client.get(uri).timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) return false;
      final remoteManifest = jsonDecode(response.body) as Map<String, dynamic>;

      final localBldVer = prefs.getString(keyBuildingsVer) ?? '';
      final localPoisVer = prefs.getString(keyPoisVer) ?? '';
      final localGraphVer = prefs.getString(keyGraphVer) ?? '';

      // A. Edificios GeoJSON
      final remoteBldVer = remoteManifest['buildings_version']?.toString();
      if (remoteBldVer != null && remoteBldVer != localBldVer) {
        final success = await _downloadAndSaveFile('usac_buildings.geojson', client: client);
        if (success) {
          await prefs.setString(keyBuildingsVer, remoteBldVer);
          updated = true;
        }
      }

      // B. POIs, Sanitarios y Niveles Interiores
      final remotePoisVer = remoteManifest['pois_version']?.toString();
      if (remotePoisVer != null && remotePoisVer != localPoisVer) {
        final ok1 = await _downloadAndSaveFile('usac_pois_and_indoors.json', client: client);
        await _downloadAndSaveFile('campus_places_info.json', client: client);
        if (ok1) {
          await prefs.setString(keyPoisVer, remotePoisVer);
          updated = true;
        }
      }

      // C. Grafo de Ruteo Peatonal
      final remoteGraphVer = remoteManifest['graph_version']?.toString();
      if (remoteGraphVer != null && remoteGraphVer != localGraphVer) {
        final success = await _downloadAndSaveFile('campus_graph.json', client: client);
        if (success) {
          await prefs.setString(keyGraphVer, remoteGraphVer);
          updated = true;
        }
      }
    } catch (e) {
      debugPrint('Modo Offline: Usando mapa local/empaquetado. Detalle: $e');
    } finally {
      if (httpClient == null) {
        client.close();
      }
    }

    return updated;
  }

  /// Descarga un archivo desde el CDN R2 y lo almacena localmente en la carpeta de documentos.
  static Future<bool> _downloadAndSaveFile(
    String filename, {
    required http.Client client,
  }) async {
    if (kIsWeb) return false; // En Web usamos la caché del navegador o assets

    try {
      final res = await client.get(Uri.parse('$r2BaseUrl/$filename'));
      if (res.statusCode == 200) {
        final dirPath = await _getStorageDir();
        final file = File('$dirPath/$filename');
        await file.parent.create(recursive: true);
        await file.writeAsString(res.body);
        return true;
      }
    } catch (e) {
      debugPrint('Error al guardar archivo descargado $filename: $e');
    }
    return false;
  }

  /// Carga el JSON desde el almacenamiento local si existe
  static Future<String> loadLocalMapFile(String filename) async {
    if (kIsWeb) return '';
    try {
      final dirPath = await _getStorageDir();
      final file = File('$dirPath/$filename');
      if (await file.exists()) {
        return await file.readAsString();
      }
    } catch (e) {
      debugPrint('Error leyendo archivo local $filename: $e');
    }
    return '';
  }

  static Future<String> _loadAssetWithFallback(
    AssetBundle bundle,
    String assetPath,
  ) async {
    try {
      return await bundle.loadString('packages/usac_campus_map/$assetPath');
    } catch (_) {
      return await bundle.loadString(assetPath);
    }
  }

  /// Carga los datos en el [CampusDataRepository], priorizando la caché de R2
  /// y haciendo fallback automático a los assets offline si no hay caché local.
  static Future<void> loadRepositoryData(
    CampusDataRepository repository, {
    AssetBundle? bundle,
  }) async {
    final effectiveBundle = bundle ?? rootBundle;
    final useIsolate =
        !kIsWeb &&
        bundle == null &&
        (debugUseCompute ?? (WidgetsBinding.instance is WidgetsFlutterBinding));

    try {
      String boundaryStr = '';
      String buildingsStr = '';
      String graphStr = '';
      String poisStr = '';

      if (!kIsWeb) {
        final localFiles = await Future.wait([
          loadLocalMapFile('usac_buildings.geojson'),
          loadLocalMapFile('usac_pois_and_indoors.json'),
          loadLocalMapFile('campus_graph.json'),
        ]);
        if (localFiles[0].isNotEmpty &&
            localFiles[1].isNotEmpty &&
            localFiles[2].isNotEmpty) {
          boundaryStr = await _loadAssetWithFallback(
            effectiveBundle,
            'assets/geojson/usac_boundary.geojson',
          );
          buildingsStr = localFiles[0];
          poisStr = localFiles[1];
          graphStr = localFiles[2];
        }
      }

      if (buildingsStr.isEmpty || poisStr.isEmpty || graphStr.isEmpty) {
        final assetStrings = await Future.wait([
          _loadAssetWithFallback(
            effectiveBundle,
            'assets/geojson/usac_boundary.geojson',
          ),
          _loadAssetWithFallback(
            effectiveBundle,
            'assets/geojson/usac_buildings.geojson',
          ),
          _loadAssetWithFallback(
            effectiveBundle,
            'assets/graph/campus_graph.json',
          ),
          _loadAssetWithFallback(
            effectiveBundle,
            'assets/pois/usac_pois_and_indoors.json',
          ),
        ]);
        boundaryStr = assetStrings[0];
        buildingsStr = assetStrings[1];
        graphStr = assetStrings[2];
        poisStr = assetStrings[3];
      }

      final rawMap = <String, String>{
        'boundary': boundaryStr,
        'buildings': buildingsStr,
        'graph': graphStr,
        'pois': poisStr,
      };
      final decoded = useIsolate
          ? await compute(_decodeMapJsonBundle, rawMap)
          : _decodeMapJsonBundle(rawMap);

      repository.loadFromJson(
        boundaryJson: decoded['boundary']!,
        buildingsJson: decoded['buildings']!,
        graphJson: decoded['graph']!,
        poisJson: decoded['pois']!,
      );
      return;
    } catch (e) {
      debugPrint('Fallback a assets empaquetados por error en caché/isolate: $e');
    }

    // Fallback completo a los assets offline empaquetados
    await repository.loadFromAssets(bundle: bundle);
  }
}
