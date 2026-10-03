import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
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

  group('SupabaseService signup email verification', () {
    test('verifies a signup OTP using the email and token', () async {
      fakeServer.onPost('/auth/v1/verify', (request) {
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        expect(payload['type'], 'signup');
        expect(payload['email'], 'student@usac.edu.gt');
        expect(payload['token'], '123456');

        return {
          'access_token': 'verified-access-token',
          'token_type': 'bearer',
          'expires_in': 3600,
          'refresh_token': 'verified-refresh-token',
          'user': {
            'id': 'verified-user',
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

      final response = await SupabaseService.verifySignupOtp(
        email: ' student@usac.edu.gt ',
        token: ' 123456 ',
      );

      expect(response?.user?.email, 'student@usac.edu.gt');
      expect(response?.session, isNotNull);
    });

    test('resends a signup OTP to the normalized email', () async {
      fakeServer.onPost('/auth/v1/resend', (request) {
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        expect(payload['type'], 'signup');
        expect(payload['email'], 'student@usac.edu.gt');
        return {'message_id': 'confirmation-message'};
      });

      await SupabaseService.resendSignupOtp(' student@usac.edu.gt ');
    });
  });

  group('SupabaseService password recovery', () {
    test(
      'requests recovery, verifies its OTP, and updates the password',
      () async {
        fakeServer.onPost('/auth/v1/recover', (request) {
          final payload = jsonDecode(request.body) as Map<String, dynamic>;
          expect(payload['email'], 'student@usac.edu.gt');
          return {'message_id': 'recovery-message'};
        });
        fakeServer.onPost('/auth/v1/verify', (request) {
          final payload = jsonDecode(request.body) as Map<String, dynamic>;
          expect(payload['type'], 'recovery');
          expect(payload['email'], 'student@usac.edu.gt');
          expect(payload['token'], '654321');
          return {
            'access_token': 'recovery-access-token',
            'token_type': 'bearer',
            'expires_in': 3600,
            'refresh_token': 'recovery-refresh-token',
            'user': {
              'id': 'recovery-user',
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
        fakeServer.on('PUT', '/auth/v1/user', (request) {
          final payload = jsonDecode(request.body) as Map<String, dynamic>;
          expect(payload['password'], 'new-password-123');
          return {
            'id': 'recovery-user',
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
          };
        });

        await SupabaseService.requestPasswordReset(' student@usac.edu.gt ');
        final response = await SupabaseService.verifyPasswordResetOtp(
          email: ' student@usac.edu.gt ',
          token: ' 654321 ',
        );
        expect(response?.session, isNotNull);

        await SupabaseService.updatePassword('new-password-123');
      },
    );

    test(
      'returns false when recovery cannot run without Supabase config',
      () async {
        SupabaseConfig.debugOverrideConfigured = false;

        expect(
          await SupabaseService.requestPasswordReset('student@usac.edu.gt'),
          isFalse,
        );
      },
    );
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

  group('SupabaseService recovery codes', () {
    Future<void> signIn({String aal = 'aal2'}) async {
      fakeServer.onPost('/auth/v1/token', (_) {
        return {
          'access_token': _testJwt(aal: aal),
          'token_type': 'bearer',
          'expires_in': 3600,
          'refresh_token': 'test-refresh-token',
          'user': {
            'id': 'recovery-user',
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
      SupabaseService.debugRecoveryCodesHttpClient = http_testing.MockClient(
        fakeServer.handle,
      );
    }

    test(
      'loads remaining count using the current bearer and anon key',
      () async {
        await signIn();
        fakeServer.onGet('/auth/v1/factors/recovery-codes', (request) {
          expect(
            request.headers['authorization'],
            'Bearer ${SupabaseService.client.auth.currentSession!.accessToken}',
          );
          expect(request.headers['apikey'], SupabaseConfig.supabaseAnonKey);
          return {'total': 10, 'remaining': 7};
        });

        final status = await SupabaseService.getRecoveryCodeStatus();

        expect(status.total, 10);
        expect(status.remaining, 7);
      },
    );

    test('generates recovery codes only for an AAL2 session', () async {
      await signIn();
      fakeServer.onPost('/auth/v1/factors/recovery-codes', (request) {
        expect(request.method, 'POST');
        return {
          'codes': ['first-one-time-code', 'second-one-time-code'],
        };
      });
      fakeServer.onGet('/auth/v1/factors/recovery-codes', (_) {
        return {'total': 10, 'remaining': 2};
      });

      final codes = await SupabaseService.generateRecoveryCodes();

      expect(codes, ['first-one-time-code', 'second-one-time-code']);
    });

    test('regenerates the set through Supabase Auth', () async {
      await signIn();
      fakeServer.onPost('/auth/v1/factors/recovery-codes/regenerate', (
        request,
      ) {
        expect(request.method, 'POST');
        return {
          'codes': ['replacement-code'],
        };
      });

      final codes = await SupabaseService.generateRecoveryCodes(
        regenerate: true,
      );

      expect(codes, ['replacement-code']);
    });

    test('rejects generating recovery codes below AAL2', () async {
      await signIn(aal: 'aal1');

      await expectLater(
        SupabaseService.generateRecoveryCodes(),
        throwsA(isA<StateError>()),
      );
      expect(
        fakeServer.recordedRequests.where(
          (request) => request.url.path.endsWith('/factors/recovery-codes'),
        ),
        isEmpty,
      );
    });

    test('redeems a recovery code and installs the AAL2 session', () async {
      await signIn();
      final aal2Token = _testJwt(aal: 'aal2');
      fakeServer.onPost('/auth/v1/factors/recovery-codes/verify', (request) {
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        expect(payload, {'code': 'one-time-recovery-code'});
        return {
          'access_token': aal2Token,
          'refresh_token': 'recovered-refresh-token',
        };
      });
      fakeServer.onGet('/auth/v1/user', (_) {
        return {
          'id': 'recovery-user',
          'aud': 'authenticated',
          'role': 'authenticated',
          'email': 'student@usac.edu.gt',
          'created_at': '2026-10-03T00:00:00.000Z',
          'app_metadata': {
            'provider': 'email',
            'providers': ['email'],
          },
          'user_metadata': {},
        };
      });

      await SupabaseService.verifyRecoveryCode(' one-time-recovery-code ');

      expect(
        SupabaseService.client.auth.currentSession?.accessToken,
        aal2Token,
      );
      expect(
        SupabaseService.client.auth.currentSession?.refreshToken,
        'recovered-refresh-token',
      );
    });

    test('preserves recovery-code rate-limit status for the UI', () async {
      await signIn();
      fakeServer.onPost(
        '/auth/v1/factors/recovery-codes/verify',
        (_) => {'code': 'mfa_recovery_codes_locked'},
        statusCode: 429,
      );

      await expectLater(
        SupabaseService.verifyRecoveryCode('incorrect-code'),
        throwsA(
          isA<RecoveryCodeRequestException>().having(
            (error) => error.statusCode,
            'statusCode',
            429,
          ),
        ),
      );
    });

    test('rejects TOTP removal without a six-digit current code', () async {
      await signIn();

      await expectLater(
        SupabaseService.disableTotpWithCurrentCode(
          factorId: 'verified-factor',
          code: 'recovery-code',
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
