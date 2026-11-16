import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:comunidad_universitaria/core/services/local_storage_service.dart';
import 'package:comunidad_universitaria/features/onboarding/state/session_controller.dart';
import '../../helpers/test_setup.dart';

class FakeAuthApi implements AuthApi {
  @override
  User? currentUser;
  final StreamController<AuthState> _authStateController =
      StreamController<AuthState>.broadcast();
  bool signInWithGoogleCalled = false;
  bool signOutCalled = false;
  String? lastRedirectTo;
  bool signInWithGoogleResult = true;

  FakeAuthApi({this.currentUser});

  @override
  Stream<AuthState> get onAuthStateChange => _authStateController.stream;

  @override
  Future<bool> signInWithGoogle({String? redirectTo}) async {
    signInWithGoogleCalled = true;
    lastRedirectTo = redirectTo;
    return signInWithGoogleResult;
  }

  @override
  Future<void> signOut() async {
    signOutCalled = true;
    currentUser = null;
    emitAuthState(const AuthState(AuthChangeEvent.signedOut, null));
  }

  void emitAuthState(AuthState state) {
    _authStateController.add(state);
  }

  void dispose() {
    _authStateController.close();
  }
}

User createFakeUser({
  required String id,
  String? email,
  bool isAnonymous = false,
}) {
  return User(
    id: id,
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: DateTime.now().toIso8601String(),
    email: email,
    isAnonymous: isAnonymous,
  );
}

void main() {
  setupTestLifecycle();

  group('SessionController Tests', () {
    late FakeAuthApi fakeApi;

    setUp(() {
      fakeApi = FakeAuthApi();
    });

    tearDown(() {
      fakeApi.dispose();
    });

    test('bootstrap autenticado con usuario real pasa a authenticated y limpia guest mode', () async {
      SharedPreferences.setMockInitialValues({'usac_guest_mode': true});
      final realUser = createFakeUser(
        id: 'real-user-1',
        email: 'estudiante@usac.edu.gt',
        isAnonymous: false,
      );
      fakeApi.currentUser = realUser;

      final controller = SessionController(api: fakeApi);
      expect(controller.phase, SessionPhase.loading);

      await controller.bootstrap();

      expect(controller.phase, SessionPhase.authenticated);
      expect(controller.isAuthenticated, isTrue);
      expect(controller.isGuest, isFalse);
      expect(await LocalStorageService.isGuestMode(), isFalse);
    });

    test('bootstrap con usuario anónimo legacy cae en guest', () async {
      final anonUser = createFakeUser(
        id: 'anon-user-1',
        isAnonymous: true,
      );
      fakeApi.currentUser = anonUser;

      final controller = SessionController(api: fakeApi);
      await controller.bootstrap();

      expect(controller.phase, SessionPhase.guest);
      expect(controller.isGuest, isTrue);
      expect(controller.isAuthenticated, isFalse);
    });

    test('bootstrap invitado recordado cuando usac_guest_mode == true y sin usuario', () async {
      SharedPreferences.setMockInitialValues({'usac_guest_mode': true});
      fakeApi.currentUser = null;

      final controller = SessionController(api: fakeApi);
      await controller.bootstrap();

      expect(controller.phase, SessionPhase.guest);
      expect(controller.isGuest, isTrue);
      expect(controller.isUnauthenticated, isFalse);
    });

    test('bootstrap sin sesión ni guest mode pasa a unauthenticated', () async {
      SharedPreferences.setMockInitialValues({});
      fakeApi.currentUser = null;

      final controller = SessionController(api: fakeApi);
      await controller.bootstrap();

      expect(controller.phase, SessionPhase.unauthenticated);
      expect(controller.isUnauthenticated, isTrue);
      expect(controller.isAuthenticated, isFalse);
      expect(controller.isGuest, isFalse);
    });

    test('continueAsGuest persiste usac_guest_mode = true y pasa a guest', () async {
      SharedPreferences.setMockInitialValues({});
      final controller = SessionController(api: fakeApi);
      await controller.bootstrap();
      expect(controller.phase, SessionPhase.unauthenticated);

      await controller.continueAsGuest();

      expect(controller.phase, SessionPhase.guest);
      expect(controller.isGuest, isTrue);
      expect(await LocalStorageService.isGuestMode(), isTrue);
    });

    test('signOut limpia usac_guest_mode, llama a api.signOut y pasa a unauthenticated', () async {
      SharedPreferences.setMockInitialValues({'usac_guest_mode': true});
      final realUser = createFakeUser(id: 'user-to-logout', email: 'test@usac.edu.gt');
      fakeApi.currentUser = realUser;

      final controller = SessionController(api: fakeApi);
      await controller.bootstrap();
      expect(controller.phase, SessionPhase.authenticated);

      await controller.signOut();

      expect(controller.phase, SessionPhase.unauthenticated);
      expect(fakeApi.signOutCalled, isTrue);
      expect(await LocalStorageService.isGuestMode(), isFalse);
    });

    test('escucha onAuthStateChange: signedIn con usuario real transiciona a authenticated', () async {
      SharedPreferences.setMockInitialValues({'usac_guest_mode': true});
      fakeApi.currentUser = null;

      final controller = SessionController(api: fakeApi);
      await controller.bootstrap();
      expect(controller.phase, SessionPhase.guest);

      final loggedInUser = createFakeUser(
        id: 'new-auth-user',
        email: 'alumno@ingenieria.usac.edu.gt',
        isAnonymous: false,
      );
      fakeApi.currentUser = loggedInUser;
      fakeApi.emitAuthState(AuthState(
        AuthChangeEvent.signedIn,
        Session(
          accessToken: 'fake-token',
          tokenType: 'bearer',
          user: loggedInUser,
        ),
      ));

      // Esperar propagación en stream
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(controller.phase, SessionPhase.authenticated);
      expect(await LocalStorageService.isGuestMode(), isFalse);
    });

    test('escucha onAuthStateChange: signedOut transiciona a unauthenticated', () async {
      final realUser = createFakeUser(id: 'user-active', email: 'user@usac.edu.gt');
      fakeApi.currentUser = realUser;

      final controller = SessionController(api: fakeApi);
      await controller.bootstrap();
      expect(controller.phase, SessionPhase.authenticated);

      fakeApi.currentUser = null;
      fakeApi.emitAuthState(const AuthState(AuthChangeEvent.signedOut, null));

      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(controller.phase, SessionPhase.unauthenticated);
    });

    test('signInWithGoogle delega en AuthApi sin mutar fase antes del evento', () async {
      final controller = SessionController(api: fakeApi);
      await controller.bootstrap();
      expect(controller.phase, SessionPhase.unauthenticated);

      final res = await controller.signInWithGoogle(redirectTo: 'https://custom/callback');

      expect(res, isTrue);
      expect(fakeApi.signInWithGoogleCalled, isTrue);
      expect(fakeApi.lastRedirectTo, 'https://custom/callback');
      // No debe mutar la fase de inmediato hasta que llegue el evento de auth
      expect(controller.phase, SessionPhase.unauthenticated);
    });

    test('refresh relee el usuario y flags correctamente', () async {
      final controller = SessionController(api: fakeApi);
      await controller.bootstrap();
      expect(controller.phase, SessionPhase.unauthenticated);

      // Ahora marcamos guest mode
      await LocalStorageService.setGuestMode(true);
      await controller.refresh();
      expect(controller.phase, SessionPhase.guest);
    });
  });
}
