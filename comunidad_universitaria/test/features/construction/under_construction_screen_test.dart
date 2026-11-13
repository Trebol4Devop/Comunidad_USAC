import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:comunidad_universitaria/core/config/supabase_config.dart';
import 'package:comunidad_universitaria/core/services/supabase_service.dart';
import 'package:comunidad_universitaria/features/construction/screens/under_construction_screen.dart';
import 'package:comunidad_universitaria/main.dart';

import '../../helpers/fake_postgrest.dart';
import '../../helpers/test_setup.dart';

void main() {
  late FakePostgrestServer fakeServer;

  String jwt() {
    final payload = base64Url
        .encode(utf8.encode(jsonEncode({'aal': 'aal1', 'role': 'authenticated'})))
        .replaceAll('=', '');
    return 'fake-header.$payload.fake-sig';
  }

  Map<String, dynamic> userJson({required String email}) => {
    'id': 'google-test-user-id',
    'aud': 'authenticated',
    'role': 'authenticated',
    'email': email,
    'is_anonymous': false,
    'created_at': '2026-11-12T00:00:00.000Z',
    'factors': [],
  };

  setUp(() async {
    await resetTestState();
    fakeServer = FakePostgrestServer();
    SupabaseConfig.debugOverrideConfigured = true;
    SupabaseService.debugClient = fakeServer.buildClient();
  });

  tearDown(() async {
    await resetTestState();
  });

  testWidgets(
      'UnderConstructionScreen renders unauthenticated state with only Google sign-in and no app features',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: UnderConstructionScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Must display "Sitio en Construcción"
    expect(find.text('Sitio en Construcción'), findsOneWidget);

    // Must display Google sign-in button
    expect(find.text('Continuar con Google'), findsOneWidget);

    // Must NOT display any app features / navigation tabs
    expect(find.text('Foro Estudiantil'), findsNothing);
    expect(find.text('Marketplace & Tutorías'), findsNothing);
    expect(find.text('Grupos WhatsApp & Info'), findsNothing);
    expect(find.text('Mapa del Campus'), findsNothing);
  });

  testWidgets(
      'UnderConstructionScreen renders authenticated state when user signs in with Google',
      (tester) async {
    fakeServer.onPost(
      '/auth/v1/token',
      (_) => {
        'access_token': jwt(),
        'token_type': 'bearer',
        'expires_in': 3600,
        'refresh_token': 'refresh-token',
        'user': userJson(email: 'estudiante@usac.edu.gt'),
      },
    );

    await SupabaseService.client.auth.signInWithPassword(
      email: 'estudiante@usac.edu.gt',
      password: 'password123',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: UnderConstructionScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Must still display "Sitio en Construcción"
    expect(find.text('Sitio en Construcción'), findsOneWidget);

    // Must display session status and user email
    expect(find.text('Sesión iniciada'), findsOneWidget);
    expect(find.text('estudiante@usac.edu.gt'), findsOneWidget);

    // Must display sign out button
    expect(find.text('Cerrar sesión'), findsOneWidget);

    // Must NOT display Google sign-in button since already logged in
    expect(find.text('Continuar con Google'), findsNothing);

    // Must NOT display any app features
    expect(find.text('Foro Estudiantil'), findsNothing);
    expect(find.text('Marketplace & Tutorías'), findsNothing);
    expect(find.text('Grupos WhatsApp & Info'), findsNothing);
    expect(find.text('Mapa del Campus'), findsNothing);
  });

  testWidgets(
      'ComunidadUSACApp routes any route to UnderConstructionScreen without 2FA guard',
      (tester) async {
    await tester.pumpWidget(
      const ComunidadUSACApp(),
    );
    await tester.pumpAndSettle();

    // Displays UnderConstructionScreen
    expect(find.text('Sitio en Construcción'), findsOneWidget);

    // No TotpSessionGuard screens (e.g., "Verificando seguridad" or "Autenticación en dos pasos")
    expect(find.text('Verificando seguridad'), findsNothing);
    expect(find.text('Autenticación en dos pasos'), findsNothing);
  });

  testWidgets(
      'ComunidadUSACApp routes /auth/authorize to SsoAuthorizeScreen for PEMTREE SSO',
      (tester) async {
    await tester.pumpWidget(
      Builder(
        builder: (context) => const ComunidadUSACApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Now push /auth/authorize route
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pushNamed(
      '/auth/authorize?client_id=pemtree&redirect_uri=http%3A%2F%2Flocalhost%3A5173%2Fauth%2Fcallback&state=test-state',
    );
    await tester.pumpAndSettle();

    // SsoAuthorizeScreen is rendered with PEMTREE consent / Google login
    expect(find.textContaining('PEMTREE'), findsWidgets);
    expect(find.text('Continuar con Google'), findsOneWidget);

    // No TotpSessionGuard screens
    expect(find.text('Verificando seguridad'), findsNothing);
    expect(find.text('Autenticación en dos pasos'), findsNothing);
  });
}
