import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_all_platforms/google_sign_in_all_platforms.dart';
import 'package:mocktail/mocktail.dart';
import 'package:comunidad_universitaria/core/config/google_auth_config.dart';
import 'package:comunidad_universitaria/core/config/supabase_config.dart';
import 'package:comunidad_universitaria/core/services/google_auth_desktop_service.dart';
import 'package:comunidad_universitaria/core/services/supabase_service.dart';
import '../../helpers/fake_postgrest.dart';
import '../../helpers/test_setup.dart';

class MockGoogleSignIn extends Mock implements GoogleSignIn {}

void main() {
  late FakePostgrestServer fakeServer;
  late MockGoogleSignIn mockGoogleSignIn;

  setUpAll(() {
    registerFallbackValue(
      const GoogleSignInParams(
        clientId: 'fallback-id',
        clientSecret: 'fallback-secret',
      ),
    );
  });

  setUp(() async {
    await resetTestState();
    fakeServer = FakePostgrestServer();
    SupabaseConfig.debugOverrideConfigured = true;
    SupabaseService.debugClient = fakeServer.buildClient();

    mockGoogleSignIn = MockGoogleSignIn();
    GoogleAuthDesktopService.debugGoogleSignIn = mockGoogleSignIn;
  });

  tearDown(() async {
    await resetTestState();
    GoogleAuthConfig.resetForTests();
    GoogleAuthDesktopService.resetForTests();
  });

  group('GoogleAuthConfig Tests', () {
    test('Defaults and platform detection', () {
      expect(GoogleAuthConfig.scopes, contains('openid'));
      expect(GoogleAuthConfig.effectiveRedirectPort, 8000);
      expect(
        GoogleAuthConfig.effectiveClientId,
        '',
      );
      expect(
        GoogleAuthConfig.effectiveClientSecret,
        '',
      );
      expect(GoogleAuthConfig.isConfigured, isFalse);
    });

    test('Configuration validation when credentials are empty', () {
      GoogleAuthConfig.debugOverrideIsDesktop = true;
      GoogleAuthConfig.debugClientId = '';
      GoogleAuthConfig.debugClientSecret = '';
      expect(GoogleAuthConfig.isConfigured, isFalse);
    });

    test('Configuration validation on desktop requires clientId and clientSecret', () {
      GoogleAuthConfig.debugOverrideIsDesktop = true;
      GoogleAuthConfig.debugClientId = 'test-client-id';
      GoogleAuthConfig.debugClientSecret = '';
      expect(GoogleAuthConfig.isConfigured, isFalse);

      GoogleAuthConfig.debugClientSecret = 'test-client-secret';
      expect(GoogleAuthConfig.isConfigured, isTrue);
    });

    test('Configuration validation on non-desktop only requires clientId', () {
      GoogleAuthConfig.debugOverrideIsDesktop = false;
      GoogleAuthConfig.debugClientId = 'test-client-id';
      expect(GoogleAuthConfig.isConfigured, isTrue);
    });

    test('resetForTests clears all overrides', () {
      GoogleAuthConfig.debugOverrideIsDesktop = true;
      GoogleAuthConfig.debugClientId = 'id';
      GoogleAuthConfig.debugClientSecret = 'secret';
      GoogleAuthConfig.debugRedirectPort = 9000;

      GoogleAuthConfig.resetForTests();

      expect(GoogleAuthConfig.debugOverrideIsDesktop, isNull);
      expect(GoogleAuthConfig.debugClientId, isNull);
      expect(GoogleAuthConfig.debugClientSecret, isNull);
      expect(GoogleAuthConfig.debugRedirectPort, isNull);
    });
  });

  group('GoogleAuthDesktopService Tests', () {
    test('signIn returns null when credentials are not configured', () async {
      GoogleAuthConfig.debugOverrideIsDesktop = true;
      GoogleAuthConfig.debugClientId = '';
      GoogleAuthConfig.debugClientSecret = '';

      final creds = await GoogleAuthDesktopService.signIn();
      expect(creds, isNull);
      expect(GoogleAuthDesktopService.lastError, contains('Faltan GOOGLE_CLIENT_ID'));
      verifyNever(() => mockGoogleSignIn.signIn());
    });

    test('signIn delegates to GoogleSignIn when configured', () async {
      GoogleAuthConfig.debugOverrideIsDesktop = true;
      GoogleAuthConfig.debugClientId = 'client-id.apps.googleusercontent.com';
      GoogleAuthConfig.debugClientSecret = 'client-secret';

      const mockCreds = GoogleSignInCredentials(
        accessToken: 'mock-access-token',
        idToken: 'mock-id-token',
        tokenType: 'Bearer',
      );

      when(() => mockGoogleSignIn.signIn())
          .thenAnswer((_) async => mockCreds);

      final result = await GoogleAuthDesktopService.signIn();
      expect(result, isNotNull);
      expect(result?.accessToken, 'mock-access-token');
      expect(result?.idToken, 'mock-id-token');
      verify(() => mockGoogleSignIn.signIn()).called(1);
    });

    test('silentSignIn delegates to GoogleSignIn.silentSignIn', () async {
      GoogleAuthConfig.debugOverrideIsDesktop = true;
      GoogleAuthConfig.debugClientId = 'client-id.apps.googleusercontent.com';
      GoogleAuthConfig.debugClientSecret = 'client-secret';

      const mockCreds = GoogleSignInCredentials(
        accessToken: 'silent-access-token',
        idToken: 'silent-id-token',
      );

      when(() => mockGoogleSignIn.silentSignIn())
          .thenAnswer((_) async => mockCreds);

      final result = await GoogleAuthDesktopService.silentSignIn();
      expect(result?.accessToken, 'silent-access-token');
      verify(() => mockGoogleSignIn.silentSignIn()).called(1);
    });

    test('signOut delegates to GoogleSignIn.signOut', () async {
      when(() => mockGoogleSignIn.signOut()).thenAnswer((_) async {});

      await GoogleAuthDesktopService.signOut();
      verify(() => mockGoogleSignIn.signOut()).called(1);
    });
  });

  group('SupabaseService Desktop Google Auth Flow', () {
    setUp(() {
      SupabaseService.debugUseDirectGoogleAuthOnDesktop = true;
    });

    tearDown(() {
      SupabaseService.debugUseDirectGoogleAuthOnDesktop = null;
    });

    test('signInWithGoogle on desktop returns false if not configured', () async {
      GoogleAuthConfig.debugOverrideIsDesktop = true;
      GoogleAuthConfig.debugClientId = '';
      GoogleAuthConfig.debugClientSecret = '';

      final success = await SupabaseService.signInWithGoogle();
      expect(success, isFalse);
      expect(SupabaseService.lastGoogleAuthError, contains('Faltan credenciales de Google OAuth'));
    });

    test('signInWithGoogle on desktop authenticates via signInWithIdToken in Supabase', () async {
      GoogleAuthConfig.debugOverrideIsDesktop = true;
      GoogleAuthConfig.debugClientId = 'client-id.apps.googleusercontent.com';
      GoogleAuthConfig.debugClientSecret = 'client-secret';

      const mockCreds = GoogleSignInCredentials(
        accessToken: 'google-access-token',
        idToken: 'google-id-token',
        tokenType: 'Bearer',
      );

      when(() => mockGoogleSignIn.signIn())
          .thenAnswer((_) async => mockCreds);

      fakeServer.onPost('/auth/v1/token', (request) {
        expect(request.url.queryParameters['grant_type'], 'id_token');
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        expect(payload['provider'], 'google');
        expect(payload['id_token'], 'google-id-token');
        expect(payload['access_token'], 'google-access-token');

        return {
          'access_token': 'supabase-session-token',
          'token_type': 'bearer',
          'expires_in': 3600,
          'refresh_token': 'supabase-refresh-token',
          'user': {
            'id': 'google-desktop-user-id',
            'aud': 'authenticated',
            'role': 'authenticated',
            'email': 'estudiante@usac.edu.gt',
            'created_at': '2026-11-16T00:00:00.000Z',
          },
        };
      });

      final success = await SupabaseService.signInWithGoogle();
      expect(success, isTrue);
      expect(SupabaseService.currentUserId, 'google-desktop-user-id');
      expect(SupabaseService.currentUser?.email, 'estudiante@usac.edu.gt');
      expect(SupabaseService.isAuthenticated, isTrue);
    });

    test('signInWithGoogle on desktop returns false when user cancels login', () async {
      GoogleAuthConfig.debugOverrideIsDesktop = true;
      GoogleAuthConfig.debugClientId = 'client-id.apps.googleusercontent.com';
      GoogleAuthConfig.debugClientSecret = 'client-secret';

      when(() => mockGoogleSignIn.signIn()).thenAnswer((_) async => null);

      final success = await SupabaseService.signInWithGoogle();
      expect(success, isFalse);
      expect(SupabaseService.currentUser, isNull);
    });

    test('signOut on desktop calls GoogleAuthDesktopService.signOut', () async {
      GoogleAuthConfig.debugOverrideIsDesktop = true;
      when(() => mockGoogleSignIn.signOut()).thenAnswer((_) async {});
      fakeServer.onPost('/auth/v1/logout', (_) => {});

      await SupabaseService.signOut();

      verify(() => mockGoogleSignIn.signOut()).called(1);
    });
  });
}
