import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/local_storage_service.dart';
import '../../verification/screens/verification_flow_screen.dart';
import '../../verification/services/verification_service.dart';
import '../../verification/state/verification_controller.dart';
import '../../verification/utils/verification_validators.dart';
import '../../verification/widgets/verification_gate.dart';
import '../screens/merchant_verification_screen.dart';
import '../screens/no_institutional_email_screen.dart';
import '../screens/welcome_screen.dart';
import '../state/session_controller.dart';

/// Guardián reactivo de nivel superior que conmuta entre la pantalla de bienvenida
/// y el shell de la aplicación según la fase de la sesión.
/// Incluye despachador post-login para persistencia de intención OAuth en web.
class AuthGate extends StatefulWidget {
  final SessionController sessionController;
  final VerificationController? verificationController;
  final Widget child;
  final Future<String?> Function()? getPendingIntent;
  final Future<void> Function()? clearPendingIntent;
  final Future<bool> Function(User user)? checkIsVerified;

  const AuthGate({
    super.key,
    required this.sessionController,
    this.verificationController,
    required this.child,
    this.getPendingIntent,
    this.clearPendingIntent,
    this.checkIsVerified,
  });

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isDispatching = false;

  @override
  void initState() {
    super.initState();
    widget.sessionController.addListener(_onSessionStateChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndDispatch();
    });
  }

  @override
  void didUpdateWidget(AuthGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionController != widget.sessionController) {
      oldWidget.sessionController.removeListener(_onSessionStateChanged);
      widget.sessionController.addListener(_onSessionStateChanged);
    }
  }

  @override
  void dispose() {
    widget.sessionController.removeListener(_onSessionStateChanged);
    super.dispose();
  }

  void _onSessionStateChanged() {
    _checkAndDispatch();
  }

  /// Despachador post-login en web (normativo §4.1).
  /// Al pasar a `authenticated`, consume la intención una sola vez.
  Future<void> _checkAndDispatch() async {
    if (!mounted || _isDispatching) return;
    if (widget.sessionController.phase != SessionPhase.authenticated) return;

    final user = widget.sessionController.currentUser;
    // No disparar para invitados ni usuarios anónimos
    if (user == null || user.isAnonymous) return;

    final nav = Navigator.maybeOf(context);
    if (nav == null) return;

    _isDispatching = true;
    final getIntent =
        widget.getPendingIntent ?? LocalStorageService.getPendingAuthIntent;
    final clearIntent =
        widget.clearPendingIntent ?? LocalStorageService.clearPendingAuthIntent;

    try {
      final intent = await getIntent();
      if (intent == null || intent.trim().isEmpty) {
        return;
      }

      // Consumir y limpiar la intención siempre de forma inmediata (consumo único)
      await clearIntent();

      if (!mounted) return;

      final effectiveCtrl = widget.verificationController ??
          VerificationGate.maybeOf(context);

      switch (intent.trim()) {
        case 'student':
          final ctrl = effectiveCtrl ?? VerificationController();
          nav.push(
            MaterialPageRoute(
              builder: (_) => VerificationFlowScreen(
                controller: ctrl,
                initialTab: 1,
              ),
            ),
          );
          break;

        case 'merchant':
          nav.push(
            MaterialPageRoute(
              builder: (_) => MerchantVerificationScreen(
                verificationController: effectiveCtrl,
                sessionController: widget.sessionController,
              ),
            ),
          );
          break;

        case 'auto':
          bool isVerified = false;
          if (widget.checkIsVerified != null) {
            isVerified = await widget.checkIsVerified!(user);
          } else if (effectiveCtrl != null) {
            await effectiveCtrl.loadStatus();
            isVerified = effectiveCtrl.isVerified;
          } else {
            final data = await VerificationService().fetchVerificationStatus();
            isVerified = data?['is_verified'] == true ||
                data?['verification_status'] == 'verified';
          }

          if (!mounted) return;

          if (isVerified) {
            // Ya verificado: no hacer nada
            break;
          }

          final email = user.email ?? '';
          final isInst = VerificationValidators.isInstitutionalEmail(email);

          if (isInst) {
            final ctrl = effectiveCtrl ?? VerificationController();
            nav.push(
              MaterialPageRoute(
                builder: (_) => VerificationFlowScreen(
                  controller: ctrl,
                  initialTab: 0,
                ),
              ),
            );
          } else {
            nav.push(
              MaterialPageRoute(
                builder: (_) => NoInstitutionalEmailScreen(
                  verificationController: effectiveCtrl,
                  sessionController: widget.sessionController,
                ),
              ),
            );
          }
          break;
      }
    } catch (e) {
      debugPrint('[AuthGate] Error en despachador post-login: $e');
      try {
        await clearIntent();
      } catch (_) {}
    } finally {
      _isDispatching = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SessionScope(
      controller: widget.sessionController,
      child: ListenableBuilder(
        listenable: widget.sessionController,
        builder: (context, _) {
          switch (widget.sessionController.phase) {
            case SessionPhase.loading:
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            case SessionPhase.authenticated:
            case SessionPhase.guest:
              return widget.child;
            case SessionPhase.unauthenticated:
              return WelcomeScreen(
                verificationController: widget.verificationController,
                sessionController: widget.sessionController,
              );
          }
        },
      ),
    );
  }
}
