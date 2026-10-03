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
