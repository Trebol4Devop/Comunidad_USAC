import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:comunidad_universitaria/core/config/supabase_config.dart';
import 'package:comunidad_universitaria/core/services/storage_service.dart';
import 'package:comunidad_universitaria/core/services/supabase_service.dart';
import '../helpers/fake_postgrest.dart';
import '../helpers/test_setup.dart';

void main() {
  setUp(() async {
    await resetTestState();
    final fakeServer = FakePostgrestServer();
    SupabaseConfig.debugOverrideConfigured = true;
    SupabaseService.debugClient = fakeServer.buildClient();
    fakeServer.onPost('/auth/v1/token', (_) => {
      'access_token': 'test-access-token',
      'token_type': 'bearer',
      'expires_in': 3600,
      'refresh_token': 'test-refresh-token',
      'user': {
        'id': 'uploader-123',
        'aud': 'authenticated',
        'role': 'authenticated',
        'email': 'uploader@usac.edu.gt',
        'created_at': '2026-10-03T00:00:00.000Z',
      },
    });
    await SupabaseService.client.auth.signInWithPassword(
      email: 'uploader@usac.edu.gt',
      password: 'password123',
    );
  });

  tearDown(() async {
    await resetTestState();
  });

  group('StorageService.uploadImageFile', () {
    test('flujo completo exitoso: /upload -> PUT a URL prefirmada -> URL pública', () async {
      final dummyBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]); // PNG header
      final tempDir = Directory.systemTemp.createTempSync('storage_test');
      final tempFile = File('${tempDir.path}/mi_foto.png')..writeAsBytesSync(dummyBytes);
      addTearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });
      final testFile = XFile(tempFile.path);

      bool uploadStepCalled = false;
      bool putStepCalled = false;

      final mockHttpClient = MockClient((request) async {
        if (request.method == 'POST' && request.url.path.endsWith('/upload')) {
          uploadStepCalled = true;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['folder'], 'listings');
          expect(body['contentType'], 'image/png');
          return http.Response(
            jsonEncode({'uploadUrl': 'https://r2-upload.fake.com/presigned-put'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (request.method == 'PUT' && request.url.toString() == 'https://r2-upload.fake.com/presigned-put') {
          putStepCalled = true;
          expect(request.bodyBytes, dummyBytes);
          return http.Response('', 200);
        }

        return http.Response('Not Found', 404);
      });

      final publicUrl = await http.runWithClient(
        () => StorageService.uploadImageFile(testFile, folder: 'listings'),
        () => mockHttpClient,
      );

      expect(publicUrl, isNotNull);
      expect(uploadStepCalled, isTrue);
      expect(putStepCalled, isTrue);
      expect(publicUrl, contains('/images/listings/uploader-123_'));
      expect(publicUrl, endsWith('_mi_foto.png'));
    });

    test('retorna null cuando el endpoint /upload responde con error HTTP (status != 200)', () async {
      final testFile = XFile.fromData(Uint8List.fromList([1, 2, 3]), name: 'foto.jpg');

      final mockHttpClient = MockClient((request) async {
        if (request.url.path.endsWith('/upload')) {
          return http.Response('Internal Server Error', 500);
        }
        return http.Response('', 200);
      });

      final result = await http.runWithClient(
        () => StorageService.uploadImageFile(testFile),
        () => mockHttpClient,
      );

      expect(result, isNull);
    });

    test('retorna null cuando el PUT a la URL prefirmada falla (status != 200)', () async {
      final testFile = XFile.fromData(Uint8List.fromList([1, 2, 3]), name: 'foto.webp');

      final mockHttpClient = MockClient((request) async {
        if (request.method == 'POST' && request.url.path.endsWith('/upload')) {
          return http.Response(
            jsonEncode({'uploadUrl': 'https://r2-upload.fake.com/target'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (request.method == 'PUT') {
          return http.Response('Forbidden', 403);
        }

        return http.Response('', 200);
      });

      final result = await http.runWithClient(
        () => StorageService.uploadImageFile(testFile),
        () => mockHttpClient,
      );

      expect(result, isNull);
    });

    test('retorna null inmediatamente si SupabaseConfig.isConfigured es falso', () async {
      SupabaseConfig.debugOverrideConfigured = false;
      final testFile = XFile.fromData(Uint8List.fromList([1, 2]), name: 'test.jpg');

      final result = await StorageService.uploadImageFile(testFile);
      expect(result, isNull);
    });
  });
}
