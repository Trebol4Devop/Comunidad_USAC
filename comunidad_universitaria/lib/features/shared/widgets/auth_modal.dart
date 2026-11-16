import 'package:flutter/material.dart';
import '../../onboarding/screens/auth_gateway_screen.dart';

/// Modal contextual de autenticación.
/// Delega en [AuthGatewayScreen] y ejecuta [onAuthenticated] únicamente
/// tras completar una sesión real con usuario autenticado.
class AuthModal extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onAuthenticated;

  const AuthModal({
    super.key,
    this.title = 'Inicia Sesión para Publicar',
    this.subtitle =
        'Para proteger la comunidad y mantener la autenticidad del Marketplace, debes iniciar sesión.',
    required this.onAuthenticated,
  });

  /// Muestra el gateway como modal (bottom sheet en móvil, diálogo en escritorio).
  /// Llama a [onAuthenticated] solo si el usuario completó una sesión real.
  static Future<void> show(
    BuildContext context, {
    String? title,
    String? subtitle,
    required VoidCallback onAuthenticated,
  }) async {
    final success = await AuthGatewayScreen.show(
      context,
      title: title,
      subtitle: subtitle,
      modal: true,
    );
    if (success) {
      onAuthenticated();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthGatewayScreen(
      title: title,
      subtitle: subtitle,
      isModal: true,
      onAuthenticatedSuccess: onAuthenticated,
    );
  }
}
