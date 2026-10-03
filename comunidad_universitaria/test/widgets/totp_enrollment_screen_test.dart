import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:comunidad_universitaria/core/config/supabase_config.dart';
import 'package:comunidad_universitaria/core/services/supabase_service.dart';
import 'package:comunidad_universitaria/features/profile/screens/totp_enrollment_screen.dart';
import '../helpers/fake_postgrest.dart';
import '../helpers/test_setup.dart';

void main() {
  late FakePostgrestServer fakeServer;

  setUp(() async {
    await resetTestState();
    fakeServer = FakePostgrestServer();
    SupabaseConfig.debugOverrideConfigured = true;
    SupabaseService.debugClient = fakeServer.buildClient();
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
  });

  tearDown(() async {
    await resetTestState();
  });

  testWidgets('enrolls a TOTP factor after scanning and verifying its code', (
    tester,
  ) async {
    fakeServer.onPost(
      '/auth/v1/factors',
      (_) => {
        'id': 'totp-factor',
        'type': 'totp',
        'totp': {
          'qr_code': '<svg></svg>',
          'secret': 'test-secret',
          'uri': 'otpauth://totp/Comunidad%20USAC:test',
        },
      },
    );
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

    await tester.pumpWidget(const MaterialApp(home: TotpEnrollmentScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Comenzar configuración'));
    await tester.pumpAndSettle();

    expect(find.text('test-secret'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, '2. Ingresa el código de la app'),
      '123456',
    );
    final verifyButton = find.text('Verificar y activar');
    await tester.ensureVisible(verifyButton);
    await tester.pumpAndSettle();
    await tester.tap(verifyButton);
    await tester.pumpAndSettle();

    expect(find.text('Autenticador configurado'), findsOneWidget);
  });
}
