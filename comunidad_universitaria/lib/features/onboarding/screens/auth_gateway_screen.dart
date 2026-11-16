import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../verification/screens/verification_flow_screen.dart';
import '../../verification/state/verification_controller.dart';
import '../../verification/utils/verification_validators.dart';
import '../../verification/widgets/verification_gate.dart';
import '../state/session_controller.dart';
import 'no_institutional_email_screen.dart';

/// Destino posterior a un inicio de sesión exitoso.
enum AuthPostLoginDestination {
  caminoA,
  noInstitutional,
  alreadyVerified,
}

/// Pantalla / modal de acceso inicial donde se ofrece el inicio de sesión con Google
/// y el acceso alternativo para usuarios sin correo institucional.
class AuthGatewayScreen extends StatefulWidget {
  final VerificationController? verificationController;
  final SessionController? sessionController;
  final AuthApi? authApi;
  final bool isModal;
  final String? title;
  final String? subtitle;
  final VoidCallback? onAuthenticatedSuccess;

  const AuthGatewayScreen({
    super.key,
    this.verificationController,
    this.sessionController,
    this.authApi,
    this.isModal = false,
    this.title,
    this.subtitle,
    this.onAuthenticatedSuccess,
  });

  /// Evalúa a qué pantalla o paso debe dirigirse el usuario tras iniciar sesión.
  static AuthPostLoginDestination determinePostLoginDestination({
    required String? email,
    required bool isUnverified,
  }) {
    final cleanEmail = (email ?? '').trim();
    final isInst = VerificationValidators.isInstitutionalEmail(cleanEmail);
    if (isInst) {
      if (isUnverified) {
        return AuthPostLoginDestination.caminoA;
      } else {
        return AuthPostLoginDestination.alreadyVerified;
      }
    } else {
      return AuthPostLoginDestination.noInstitutional;
    }
  }

  /// Muestra el gateway de autenticación de forma modal o como pantalla.
  static Future<bool> show(
    BuildContext context, {
    VerificationController? verificationController,
    SessionController? sessionController,
    AuthApi? authApi,
    String? title,
    String? subtitle,
    bool modal = true,
  }) async {
    if (modal) {
      if (Responsive.isMobile(context)) {
        final res = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          builder: (ctx) => AuthGatewayScreen(
            verificationController: verificationController,
            sessionController: sessionController,
            authApi: authApi,
            title: title,
            subtitle: subtitle,
            isModal: true,
          ),
        );
        return res ?? false;
      } else {
        final res = await showDialog<bool>(
          context: context,
          builder: (ctx) => Dialog(
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AuthGatewayScreen(
                verificationController: verificationController,
                sessionController: sessionController,
                authApi: authApi,
                title: title,
                subtitle: subtitle,
                isModal: true,
              ),
            ),
          ),
        );
        return res ?? false;
      }
    } else {
      final res = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => AuthGatewayScreen(
            verificationController: verificationController,
            sessionController: sessionController,
            authApi: authApi,
            title: title,
            subtitle: subtitle,
            isModal: false,
          ),
        ),
      );
      return res ?? false;
    }
  }

  @override
  State<AuthGatewayScreen> createState() => _AuthGatewayScreenState();
}

class _AuthGatewayScreenState extends State<AuthGatewayScreen> {
  bool _isLoading = false;
  bool _waitingForGoogle = false;
  String? _errorMessage;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void dispose() {
    unawaited(_authSubscription?.cancel());
    super.dispose();
  }

  Future<void> _handlePostLogin(User user) async {
    final ctrl = widget.verificationController ??
        VerificationGate.maybeOf(context);
    // Asegura el estado real antes de decidir el destino (Camino A vs. ya
    // verificado). Sin esto, un perfil ya verificado podría entrar a Camino A.
    if (ctrl != null) {
      await ctrl.loadStatus();
    }
    final isUnverified = ctrl?.isUnverified ?? true;
    final destination = AuthGatewayScreen.determinePostLoginDestination(
      email: user.email,
      isUnverified: isUnverified,
    );

    if (!mounted) return;

    switch (destination) {
      case AuthPostLoginDestination.caminoA:
        final effectiveCtrl = ctrl ?? VerificationController();
        await VerificationFlowScreen.show(
          context,
          controller: effectiveCtrl,
          initialTab: 0,
        );
        if (mounted) {
          widget.onAuthenticatedSuccess?.call();
          Navigator.of(context).pop(true);
        }
        break;

      case AuthPostLoginDestination.noInstitutional:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => NoInstitutionalEmailScreen(
              verificationController: ctrl,
              sessionController: widget.sessionController,
              authApi: widget.authApi,
            ),
          ),
        );
        if (mounted) {
          widget.onAuthenticatedSuccess?.call();
          Navigator.of(context).pop(true);
        }
        break;

      case AuthPostLoginDestination.alreadyVerified:
        widget.onAuthenticatedSuccess?.call();
        Navigator.of(context).pop(true);
        break;
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final sCtrl =
        widget.sessionController ?? SessionController.maybeOf(context);
    setState(() {
      _isLoading = true;
      _waitingForGoogle = false;
      _errorMessage = null;
    });

    _authSubscription?.cancel();
    final api = widget.authApi;
    final stream = api != null
        ? api.onAuthStateChange
        : (SupabaseConfig.isConfigured
            ? SupabaseService.client.auth.onAuthStateChange
            : const Stream<AuthState>.empty());

    _authSubscription = stream.listen((state) {
      final user = state.session?.user;
      if (state.event == AuthChangeEvent.signedIn &&
          user != null &&
          !user.isAnonymous) {
        unawaited(_authSubscription?.cancel());
        _authSubscription = null;
        if (mounted) {
          setState(() {
            _isLoading = false;
            _waitingForGoogle = false;
          });
          _handlePostLogin(user);
        }
      }
    });

    try {
      final redirectUrl = SupabaseService.oauthRedirectUrl;
      bool launched = false;
      if (widget.authApi != null) {
        launched =
            await widget.authApi!.signInWithGoogle(redirectTo: redirectUrl);
      } else if (sCtrl != null) {
        launched = await sCtrl.signInWithGoogle(redirectTo: redirectUrl);
      } else {
        launched =
            await SupabaseService.signInWithGoogle(redirectTo: redirectUrl);
      }

      if (!launched) {
        throw StateError('No se pudo iniciar el acceso con Google.');
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _waitingForGoogle = true;
        });
      }
    } catch (e) {
      _authSubscription?.cancel();
      _authSubscription = null;
      if (mounted) {
        setState(() {
          _isLoading = false;
          _waitingForGoogle = false;
          _errorMessage =
              'No se pudo iniciar sesión con Google. Inténtalo de nuevo.';
        });
      }
    }
  }

  void _handleOpenNoInstitutional() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NoInstitutionalEmailScreen(
          verificationController: widget.verificationController,
          sessionController: widget.sessionController,
          authApi: widget.authApi,
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = isDark ? Colors.white : const Color(0xFF111827);
    final panelColor =
        isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final panelBorder =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final isMobile = Responsive.isMobile(context);
    final isBusy = _isLoading || _waitingForGoogle;

    final titleText = widget.title ?? 'Iniciar Sesión en Comunidad USAC';
    final subtitleText = widget.subtitle ??
        'Accede con tu cuenta institucional o personal de Google para participar activamente.';

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: panelColor,
                  borderRadius: BorderRadius.zero,
                ),
                child: Icon(Icons.lock_outline, color: accentColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titleText,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitleText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          // Manejo de errores con reintento
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF3B1E1E)
                    : const Color(0xFFFEF2F2),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFFEF4444)
                      : const Color(0xFFFCA5A5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Color(0xFFEF4444),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF991B1B),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                      ),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text(
                        'Reintentar',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: isBusy ? null : _handleGoogleSignIn,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Botón Continuar con Google
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: accentColor,
              side: BorderSide(color: panelBorder),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
            ),
            icon: _isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: accentColor,
                    ),
                  )
                : const Icon(
                    Icons.g_mobiledata,
                    size: 28,
                    color: Color(0xFFEA4335),
                  ),
            label: Text(
              _isLoading ? 'Conectando...' : 'Continuar con Google',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            onPressed: isBusy ? null : _handleGoogleSignIn,
          ),

          if (_waitingForGoogle) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: panelColor,
                border: Border.all(color: panelBorder),
              ),
              child: const Text(
                'Completa el acceso en Google y regresa a la app',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],

          const SizedBox(height: 14),
          Text(
            'Usa tu cuenta de Google para iniciar sesión o crear una cuenta.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),

          const SizedBox(height: 16),
          const Divider(height: 16),
          const SizedBox(height: 8),

          // Enlace a sin correo institucional
          Center(
            child: TextButton(
              onPressed: isBusy ? null : _handleOpenNoInstitutional,
              child: Text(
                '¿No cuentas con correo institucional?',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  color: isDark ? Colors.grey.shade300 : const Color(0xFF1E293B),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isModal) {
      if (Responsive.isMobile(context)) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: _buildBody(context),
        );
      } else {
        return _buildBody(context);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Acceso a Comunidad USAC',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Regresar',
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: _buildBody(context),
          ),
        ),
      ),
    );
  }
}
