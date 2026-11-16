import 'package:flutter/material.dart';
import '../../../core/services/supabase_service.dart';
import '../screens/verification_flow_screen.dart';
import '../state/verification_controller.dart';
import 'verification_banner.dart';

class _VerificationScope extends InheritedWidget {
  final VerificationController controller;

  const _VerificationScope({
    required this.controller,
    required super.child,
  });

  @override
  bool updateShouldNotify(_VerificationScope oldWidget) =>
      controller != oldWidget.controller;
}

/// Contenedor de nivel superior que envuelve [AppShell].
/// Provee el [VerificationController] mediante el árbol de elementos
/// y renderiza el [VerificationBanner] superior cuando corresponda.
class VerificationGate extends StatelessWidget {
  final VerificationController controller;
  final Widget child;
  final VoidCallback? onRetryVerification;

  const VerificationGate({
    super.key,
    required this.controller,
    required this.child,
    this.onRetryVerification,
  });

  static VerificationController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_VerificationScope>();
    assert(scope != null, 'No VerificationGate found in context');
    return scope!.controller;
  }

  static VerificationController? maybeOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_VerificationScope>();
    return scope?.controller;
  }

  /// Indica si la sesión actual es de invitado o anónima (solo lectura).
  static bool isGuest(BuildContext context) {
    return !SupabaseService.isAuthenticated;
  }

  /// Indica si el usuario actual cuenta con credenciales verificadas para publicar.
  static bool canPublish(BuildContext context) {
    final ctrl = maybeOf(context);
    return ctrl?.isVerified ?? false;
  }

  void _handleRetry(BuildContext context) {
    if (onRetryVerification != null) {
      onRetryVerification!();
    } else {
      VerificationFlowScreen.show(context, controller: controller);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _VerificationScope(
      controller: controller,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          return Column(
            children: [
              VerificationBanner(
                controller: controller,
                onRetry: () => _handleRetry(context),
              ),
              Expanded(child: child),
            ],
          );
        },
      ),
    );
  }
}
