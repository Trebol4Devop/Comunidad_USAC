import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:comunidad_universitaria/core/config/supabase_config.dart';
import 'package:comunidad_universitaria/core/services/supabase_service.dart';
import '../helpers/fake_postgrest.dart';
import '../helpers/test_setup.dart';

void main() {
  late FakePostgrestServer fakeServer;

  setUp(() async {
    await resetTestState();
    fakeServer = FakePostgrestServer();
    SupabaseConfig.debugOverrideConfigured = true;
    SupabaseService.debugClient = fakeServer.buildClient();
  });

  tearDown(() async {
    await resetTestState();
  });

  group('SupabaseService email/password session', () {
    test('signs in and clears the session on sign out', () async {
      fakeServer.onPost('/auth/v1/token', (request) {
        expect(request.url.queryParameters['grant_type'], 'password');
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        expect(payload['email'], 'student@usac.edu.gt');
        expect(payload['password'], 'password123');
        return {
          'access_token': 'login-access-token',
          'token_type': 'bearer',
          'expires_in': 3600,
          'refresh_token': 'login-refresh-token',
          'user': {
            'id': 'login-user',
            'aud': 'authenticated',
            'role': 'authenticated',
            'email': 'student@usac.edu.gt',
            'email_confirmed_at': '2026-10-03T00:00:00.000Z',
            'created_at': '2026-10-03T00:00:00.000Z',
            'app_metadata': {
              'provider': 'email',
              'providers': ['email'],
            },
            'user_metadata': {},
          },
        };
      });
      fakeServer.onPost('/auth/v1/logout', (_) => {});

      final userId = await SupabaseService.signInWithPassword(
        email: ' student@usac.edu.gt ',
        password: 'password123',
      );
      expect(userId, 'login-user');
      expect(SupabaseService.currentUserId, 'login-user');

      await SupabaseService.signOut();

      expect(SupabaseService.currentUser, isNull);
      expect(
        fakeServer.recordedRequests.any(
          (request) => request.url.path.endsWith('/auth/v1/logout'),
        ),
        isTrue,
      );
    });
  });

  group('SupabaseService TOTP enrollment', () {
    test('rejects TOTP enrollment for an anonymous session', () async {
      await expectLater(
        SupabaseService.listTotpFactors(),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'enrolls and verifies a TOTP factor for an authenticated account',
      () async {
        fakeServer.onPost(
          '/auth/v1/token',
          (_) => {
            'access_token': 'test-access-token',
            'token_type': 'bearer',
            'expires_in': 3600,
            'refresh_token': 'test-refresh-token',
            'user': {
              'id': 'totp-user',
              'aud': 'authenticated',
              'role': 'authenticated',
              'email': 'student@usac.edu.gt',
              'created_at': '2026-10-03T00:00:00.000Z',
            },
          },
        );
        await SupabaseService.client.auth.signInWithPassword(
          email: 'student@usac.edu.gt',
          password: 'password123',
        );

        fakeServer.onPost('/auth/v1/factors', (request) {
          final payload = jsonDecode(request.body) as Map<String, dynamic>;
          expect(payload['factor_type'], 'totp');
          expect(payload['issuer'], 'Comunidad USAC');
          return {
            'id': 'totp-factor',
            'type': 'totp',
            'totp': {
              'qr_code': '<svg></svg>',
              'secret': 'test-secret',
              'uri': 'otpauth://totp/Comunidad%20USAC:test',
            },
          };
        });
        fakeServer.onPost(
          '/auth/v1/factors/totp-factor/challenge',
          (_) => {'id': 'totp-challenge', 'expires_at': 1790985600},
        );
        fakeServer.onPost('/auth/v1/factors/totp-factor/verify', (request) {
          final payload = jsonDecode(request.body) as Map<String, dynamic>;
          expect(payload['challenge_id'], 'totp-challenge');
          expect(payload['code'], '123456');
          return {
            'access_token': 'aal2-access-token',
            'token_type': 'bearer',
            'expires_in': 3600,
            'refresh_token': 'aal2-refresh-token',
            'user': {
              'id': 'totp-user',
              'aud': 'authenticated',
              'role': 'authenticated',
              'email': 'student@usac.edu.gt',
              'created_at': '2026-10-03T00:00:00.000Z',
            },
          };
        });

        final enrollment = await SupabaseService.beginTotpEnrollment();
        expect(enrollment.id, 'totp-factor');
        expect(enrollment.totp?.secret, 'test-secret');

        final response = await SupabaseService.verifyTotpEnrollment(
          factorId: enrollment.id,
          code: ' 123456 ',
        );
        expect(response.user.id, 'totp-user');
      },
    );
  });

  group('SupabaseService TOTP management', () {
    Future<void> signIn() async {
      fakeServer.onPost('/auth/v1/token', (_) {
        return {
          'access_token': _testJwt(aal: 'aal2'),
          'token_type': 'bearer',
          'expires_in': 3600,
          'refresh_token': 'test-refresh-token',
          'user': {
            'id': 'totp-user',
            'aud': 'authenticated',
            'role': 'authenticated',
            'email': 'student@usac.edu.gt',
            'created_at': '2026-10-03T00:00:00.000Z',
            'app_metadata': {
              'provider': 'email',
              'providers': ['email'],
            },
            'user_metadata': {},
          },
        };
      });
      await SupabaseService.client.auth.signInWithPassword(
        email: 'student@usac.edu.gt',
        password: 'password123',
      );
    }

    test('rejects TOTP removal without a six-digit current code', () async {
      await signIn();

      await expectLater(
        SupabaseService.disableTotpWithCurrentCode(
          factorId: 'verified-factor',
          code: 'invalid-code',
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        fakeServer.recordedRequests.where(
          (request) => request.url.path.contains('/factors/verified-factor'),
        ),
        isEmpty,
      );
    });
  });

  group('SupabaseService.getUserRole', () {
    test(
      'retorna "student" si no hay sesión iniciada (currentUser == null)',
      () async {
        final role = await SupabaseService.getUserRole();
        expect(role, 'student');
      },
    );

    test(
      'retorna el rol específico ("admin" o "moderator") cuando el usuario tiene sesión y rol asignado',
      () async {
        const mockUserId = 'usr-admin-77';

        // 1. Simular autenticación exitosa mediante auth endpoint
        fakeServer.onPost('/auth/v1/token', (req) {
          return {
            'access_token': 'fake-jwt-token',
            'token_type': 'bearer',
            'expires_in': 3600,
            'refresh_token': 'fake-refresh-token',
            'user': {
              'id': mockUserId,
              'aud': 'authenticated',
              'role': 'authenticated',
              'email': 'admin@usac.edu.gt',
              'created_at': '2026-03-01T00:00:00.000Z',
            },
          };
        });

        await SupabaseService.client.auth.signInWithPassword(
          email: 'admin@usac.edu.gt',
          password: 'password123',
        );

        expect(SupabaseService.currentUser, isNotNull);
        expect(SupabaseService.currentUser!.id, mockUserId);

        // 2. Simular consulta a user_roles
        fakeServer.onGet('/rest/v1/user_roles', (req) {
          expect(req.url.queryParameters['user_id'], 'eq.$mockUserId');
          return {'role': 'admin'};
        });

        final role = await SupabaseService.getUserRole();
        expect(role, 'admin');
      },
    );

    test(
      'retorna "student" como fallback si la consulta a user_roles produce un error',
      () async {
        fakeServer.onPost('/auth/v1/token', (req) {
          return {
            'access_token': 'fake-jwt-token',
            'token_type': 'bearer',
            'expires_in': 3600,
            'refresh_token': 'fake-refresh-token',
            'user': {
              'id': 'user-error',
              'aud': 'authenticated',
              'role': 'authenticated',
              'email': 'user@usac.edu.gt',
              'created_at': '2026-03-01T00:00:00.000Z',
            },
          };
        });

        await SupabaseService.client.auth.signInWithPassword(
          email: 'user@usac.edu.gt',
          password: 'password123',
        );

        fakeServer.onGet('/rest/v1/user_roles', (req) {
          return http.Response(
            '{"message":"Error en BD"}',
            500,
            headers: {'content-type': 'application/json'},
          );
        });

        final role = await SupabaseService.getUserRole();
        expect(role, 'student');
      },
    );
  });
}

String _testJwt({required String aal}) {
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final payload = base64Url
      .encode(
        utf8.encode(
          jsonEncode({
            'sub': 'recovery-user',
            'aud': 'authenticated',
            'role': 'authenticated',
            'aal': aal,
            'iat': now,
            'exp': now + 3600,
            'amr': [],
          }),
        ),
      )
      .replaceAll('=', '');
  return 'eyJhbGciOiJub25lIn0.$payload.c2ln';
}
