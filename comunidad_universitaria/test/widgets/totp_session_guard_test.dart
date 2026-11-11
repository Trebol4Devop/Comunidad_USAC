import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:comunidad_universitaria/core/config/supabase_config.dart';
import 'package:comunidad_universitaria/core/services/supabase_service.dart';
import 'package:comunidad_universitaria/features/shared/widgets/totp_session_guard.dart';

import '../helpers/fake_postgrest.dart';
import '../helpers/test_setup.dart';

void main() {
  late FakePostgrestServer fakeServer;
  late List<Map<String, dynamic>> factors;

  Map<String, dynamic> userJson() => {
    'id': 'totp-user',
    'aud': 'authenticated',
    'role': 'authenticated',
    'email': 'student@usac.edu.gt',
    'created_at': '2026-10-03T00:00:00.000Z',
    'factors': factors,
  };

  setUp(() async {
    await resetTestState();
    factors = [];
    fakeServer = FakePostgrestServer();
    SupabaseConfig.debugOverrideConfigured = true;
    SupabaseService.debugClient = fakeServer.buildClient();
    fakeServer.onPost(
      '/auth/v1/token',
      (_) => {
        'access_token': _jwt('aal1'),
        'token_type': 'bearer',
        'expires_in': 3600,
        'refresh_token': 'test-refresh-token',
        'user': userJson(),
      },
    );
  });

  tearDown(() async {
    await resetTestState();
  });

  Future<void> signIn() async {
    await SupabaseService.client.auth.signInWithPassword(
      email: 'student@usac.edu.gt',
      password: 'password123',
    );
  }

  Widget buildGuardedApp() {
    return MaterialApp(
      home: const Scaffold(
        body: Center(child: Text('Contenido privado de la app')),
      ),
      builder: (context, child) =>
          TotpSessionGuard(child: child ?? const SizedBox.shrink()),
    );
  }

  testWidgets(
    'requires a TOTP challenge for an account with an enrolled factor',
    (tester) async {
      factors = [_verifiedFactor];
      await signIn();
      fakeServer.onPost(
        '/auth/v1/factors/totp-factor/challenge',
        (_) => {'id': 'totp-challenge', 'expires_at': 1790985600},
      );
      fakeServer.onPost('/auth/v1/factors/totp-factor/verify', (request) {
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        expect(payload['challenge_id'], 'totp-challenge');
        expect(payload['code'], '123456');
        return {
          'access_token': _jwt('aal2'),
          'token_type': 'bearer',
          'expires_in': 3600,
          'refresh_token': 'aal2-refresh-token',
          'user': userJson(),
        };
      });

      await tester.pumpWidget(buildGuardedApp());
      await tester.pumpAndSettle();

      expect(find.text('Verificación de seguridad'), findsOneWidget);
      expect(
        find.text('No tengo mi app: usar código de recuperación'),
        findsNothing,
      );
      await tester.enterText(find.byType(TextField), '123456');
      await tester.tap(find.text('Verificar código TOTP'));
      await tester.pumpAndSettle();

      expect(find.text('Contenido privado de la app'), findsOneWidget);
      expect(find.text('Verificación de seguridad'), findsNothing);
    },
  );

  testWidgets('requires new accounts to enroll TOTP before accessing the app', (
    tester,
  ) async {
    await signIn();

    await tester.pumpWidget(buildGuardedApp());
    await tester.pumpAndSettle();

    expect(find.text('Comenzar configuración'), findsOneWidget);
    expect(find.text('Configura un autenticador'), findsOneWidget);
    // It stays mounted, but the full-screen gate prevents interaction.
    expect(find.text('Contenido privado de la app'), findsOneWidget);
    expect(
      find.text('Contenido privado de la app').hitTestable(),
      findsNothing,
    );
  });
}

const Map<String, dynamic> _verifiedFactor = {
  'id': 'totp-factor',
  'friendly_name': 'Comunidad USAC',
  'factor_type': 'totp',
  'status': 'verified',
  'created_at': '2026-10-03T00:00:00.000Z',
  'updated_at': '2026-10-03T00:00:00.000Z',
};

String _jwt(String assuranceLevel) {
  String encode(Map<String, dynamic> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');

  final header = encode({'alg': 'HS256', 'typ': 'JWT'});
  final payload = encode({
    'sub': 'totp-user',
    'aud': 'authenticated',
    'role': 'authenticated',
    'aal': assuranceLevel,
    'exp':
        DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
        1000,
  });
  return '$header.$payload.fake-signature';
}
