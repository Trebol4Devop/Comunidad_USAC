import 'package:flutter/material.dart';
import '../../verification/state/verification_controller.dart';
import '../screens/welcome_screen.dart';
import '../state/session_controller.dart';

/// Guardián reactivo de nivel superior que conmuta entre la pantalla de bienvenida
/// y el shell de la aplicación según la fase de la sesión.
class AuthGate extends StatelessWidget {
  final SessionController sessionController;
  final VerificationController? verificationController;
  final Widget child;

  const AuthGate({
    super.key,
    required this.sessionController,
    this.verificationController,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SessionScope(
      controller: sessionController,
      child: ListenableBuilder(
        listenable: sessionController,
        builder: (context, _) {
          switch (sessionController.phase) {
            case SessionPhase.loading:
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            case SessionPhase.authenticated:
            case SessionPhase.guest:
              return child;
            case SessionPhase.unauthenticated:
              return WelcomeScreen(
                verificationController: verificationController,
                sessionController: sessionController,
              );
          }
        },
      ),
    );
  }
}
