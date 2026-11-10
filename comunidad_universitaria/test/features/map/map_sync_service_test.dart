import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usac_campus_map/usac_campus_map.dart';
import 'package:comunidad_universitaria/core/services/connectivity_service.dart';
import 'package:comunidad_universitaria/features/map/services/map_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MapSyncService Tests', () {
    late Directory tempDir;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      tempDir = Directory.systemTemp.createTempSync('map_sync_test_');
      MapSyncService.debugDocumentsPath = tempDir.path;
    });

    tearDown(() {
      MapSyncService.debugDocumentsPath = null;
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('syncMapAssetsIfNeeded actualiza versiones cuando difieren del manifiesto remoto', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('map_version.json')) {
          return http.Response(
            jsonEncode({
              'buildings_version': 'v2.1',
              'pois_version': 'v2.1',
              'graph_version': 'v2.1',
            }),
            200,
          );
        }
        return http.Response('{"type":"FeatureCollection","features":[]}', 200);
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(MapSyncService.keyBuildingsVer, 'v1.0');

      final updated = await MapSyncService.syncMapAssetsIfNeeded(
        httpClient: mockClient,
        preferences: prefs,
      );

      expect(updated, isTrue);
      expect(prefs.getString(MapSyncService.keyBuildingsVer), equals('v2.1'));
      expect(prefs.getString(MapSyncService.keyPoisVer), equals('v2.1'));
      expect(prefs.getString(MapSyncService.keyGraphVer), equals('v2.1'));
    });

    test('syncMapAssetsIfNeeded no descarga nada si las versiones ya coinciden', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(MapSyncService.keyBuildingsVer, 'v2.0');
      await prefs.setString(MapSyncService.keyPoisVer, 'v2.0');
      await prefs.setString(MapSyncService.keyGraphVer, 'v2.0');

      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('map_version.json')) {
          return http.Response(
            jsonEncode({
              'buildings_version': 'v2.0',
              'pois_version': 'v2.0',
              'graph_version': 'v2.0',
            }),
            200,
          );
        }
        throw StateError('No debería descargar archivos');
      });

      final updated = await MapSyncService.syncMapAssetsIfNeeded(
        httpClient: mockClient,
        preferences: prefs,
      );

      expect(updated, isFalse);
    });

    test('syncMapAssetsIfNeeded maneja errores de red sin lanzar excepciones (offline)', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Server error', 500);
      });

      final prefs = await SharedPreferences.getInstance();
      final updated = await MapSyncService.syncMapAssetsIfNeeded(
        httpClient: mockClient,
        preferences: prefs,
      );

      expect(updated, isFalse);
    });

    test('syncMapAssetsIfNeeded omite peticiones HTTP si el dispositivo no tiene conexión', () async {
      ConnectivityService.debugIsConnected = false;

      final mockClient = MockClient((request) async {
        throw StateError('No debería realizar peticiones HTTP si no hay conexión');
      });

      final prefs = await SharedPreferences.getInstance();
      final updated = await MapSyncService.syncMapAssetsIfNeeded(
        httpClient: mockClient,
        preferences: prefs,
      );

      expect(updated, isFalse);
      ConnectivityService.debugIsConnected = null;
    });

    test('loadRepositoryData realiza fallback a assets empaquetados si no hay caché local', () async {
      final repository = CampusDataRepository();
      expect(repository.isLoaded, isFalse);

      await MapSyncService.loadRepositoryData(repository);
      expect(repository.isLoaded, isTrue);
      expect(repository.buildings, isNotEmpty);
    });
  });
}
