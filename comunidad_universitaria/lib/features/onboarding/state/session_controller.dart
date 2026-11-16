import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/services/supabase_service.dart';

/// Fases del ciclo de vida de la sesión de usuario en la aplicación.
enum SessionPhase { loading, authenticated, guest, unauthenticated }

/// Interfaz abstracta para la API de autenticación, permitiendo inyección en tests.
abstract class AuthApi {
  User? get currentUser;
  Stream<AuthState> get onAuthStateChange;
  Future<bool> signInWithGoogle({String? redirectTo});
  Future<void> signOut();
}

/// Implementación por defecto de [AuthApi] sobre [SupabaseService].
class SupabaseAuthApi implements AuthApi {
  @override
  User? get currentUser => SupabaseService.currentUser;

  @override
  Stream<AuthState> get onAuthStateChange {
    if (!SupabaseConfig.isConfigured) {
      return const Stream.empty();
    }
    return SupabaseService.client.auth.onAuthStateChange;
  }

  @override
  Future<bool> signInWithGoogle({String? redirectTo}) {
    return SupabaseService.signInWithGoogle(redirectTo: redirectTo);
  }

  @override
  Future<void> signOut() {
    return SupabaseService.signOut();
  }
}

/// Scope heredado para acceder al [SessionController] en el árbol de widgets.
class SessionScope extends InheritedWidget {
  final SessionController controller;

  const SessionScope({
    super.key,
    required this.controller,
    required super.child,
  });

  @override
  bool updateShouldNotify(SessionScope oldWidget) =>
      controller != oldWidget.controller;
}

/// Controlador reactivo del estado de sesión e identidad inicial.
class SessionController extends ChangeNotifier {
  final AuthApi _api;
  final Future<bool> Function() _getGuestMode;
  final Future<void> Function(bool) _setGuestMode;

  SessionPhase _phase = SessionPhase.loading;
  StreamSubscription<AuthState>? _authSubscription;

  SessionController({
    AuthApi? api,
    Future<bool> Function()? getGuestMode,
    Future<void> Function(bool)? setGuestMode,
  })  : _api = api ?? SupabaseAuthApi(),
        _getGuestMode = getGuestMode ?? LocalStorageService.isGuestMode,
        _setGuestMode = setGuestMode ?? LocalStorageService.setGuestMode;

  SessionPhase get phase => _phase;
  bool get isLoading => _phase == SessionPhase.loading;
  bool get isAuthenticated => _phase == SessionPhase.authenticated;
  bool get isGuest => _phase == SessionPhase.guest;
  bool get isUnauthenticated => _phase == SessionPhase.unauthenticated;
  User? get currentUser => _api.currentUser;
  AuthApi get api => _api;

  static SessionController? maybeOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SessionScope>();
    return scope?.controller;
  }

  static SessionController of(BuildContext context) {
    final ctrl = maybeOf(context);
    assert(ctrl != null, 'No SessionController found in context');
    return ctrl!;
  }

  /// Inicializa la sesión evaluando el estado del usuario o flag de invitado.
  Future<void> bootstrap() async {
    _phase = SessionPhase.loading;
    notifyListeners();

    _setupAuthListener();
    await _evaluateSession();
  }

  void _setupAuthListener() {
    _authSubscription?.cancel();
    try {
      _authSubscription = _api.onAuthStateChange.listen(_handleAuthStateChange);
    } catch (_) {
      // Ignorar en entornos de test sin stream activo
    }
  }

  void _handleAuthStateChange(AuthState state) {
    if (state.event == AuthChangeEvent.signedIn) {
      final user = state.session?.user ?? _api.currentUser;
      if (user != null && !user.isAnonymous) {
        _phase = SessionPhase.authenticated;
        unawaited(_setGuestMode(false));
        notifyListeners();
      } else if (user != null && user.isAnonymous) {
        _phase = SessionPhase.guest;
        notifyListeners();
      }
    } else if (state.event == AuthChangeEvent.signedOut) {
      _phase = SessionPhase.unauthenticated;
      notifyListeners();
    }
  }

  Future<void> _evaluateSession() async {
    final user = _api.currentUser;
    if (user != null) {
      if (!user.isAnonymous) {
        _phase = SessionPhase.authenticated;
        await _setGuestMode(false);
      } else {
        // Usuario anónimo legacy
        _phase = SessionPhase.guest;
      }
    } else {
      final guest = await _getGuestMode();
      if (guest) {
        _phase = SessionPhase.guest;
      } else {
        _phase = SessionPhase.unauthenticated;
      }
    }
    notifyListeners();
  }

  /// Activa el modo de solo lectura (invitado) y persiste la elección.
  Future<void> continueAsGuest() async {
    await _setGuestMode(true);
    _phase = SessionPhase.guest;
    notifyListeners();
  }

  /// Inicia el flujo de autenticación con Google OAuth.
  Future<bool> signInWithGoogle({String? redirectTo}) async {
    return await _api.signInWithGoogle(redirectTo: redirectTo);
  }

  /// Cierra sesión en Supabase y limpia la preferencia local de invitado.
  Future<void> signOut() async {
    await _setGuestMode(false);
    try {
      await _api.signOut();
    } catch (_) {
      // Fallback seguro si la red no responde
    }
    _phase = SessionPhase.unauthenticated;
    notifyListeners();
  }

  /// Re-evalúa el usuario y las banderas locales.
  Future<void> refresh() async {
    await _evaluateSession();
  }

  /// Establece explícitamente el usuario autenticado (utilidad para tests y callbacks directos).
  void setAuthenticated(User user) {
    if (!user.isAnonymous) {
      _phase = SessionPhase.authenticated;
      unawaited(_setGuestMode(false));
    } else {
      _phase = SessionPhase.guest;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
