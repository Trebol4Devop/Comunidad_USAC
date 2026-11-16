import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../core/constants/zanate_colors.dart';
import '../../rules/screens/rules_screen.dart';
import '../../verification/state/verification_controller.dart';
import '../state/session_controller.dart';
import 'auth_gateway_screen.dart';

/// Pantalla de bienvenida inicial para usuarios sin sesión activa ni preferencia de invitado.
class WelcomeScreen extends StatelessWidget {
  final VoidCallback? onSignIn;
  final VoidCallback? onContinueAsGuest;
  final VerificationController? verificationController;
  final SessionController? sessionController;

  const WelcomeScreen({
    super.key,
    this.onSignIn,
    this.onContinueAsGuest,
    this.verificationController,
    this.sessionController,
  });

  void _handleSignIn(BuildContext context) {
    if (onSignIn != null) {
      onSignIn!();
      return;
    }
    AuthGatewayScreen.show(
      context,
      verificationController: verificationController,
      sessionController: sessionController,
      modal: false,
    );
  }

  void _handleContinueAsGuest(BuildContext context) {
    if (onContinueAsGuest != null) {
      onContinueAsGuest!();
      return;
    }
    final ctrl = sessionController ?? SessionController.maybeOf(context);
    ctrl?.continueAsGuest();
  }

  void _openRules(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RulesScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = ZanateColors.zanateAccent;
    final panelBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final panelBorder =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo / Ícono institucional Zanate
                  Center(
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: accent.withAlpha(isDark ? 40 : 25),
                        shape: BoxShape.circle,
                        border: Border.all(color: accent, width: 2),
                      ),
                      child: Center(
                        child: Icon(
                          PhosphorIconsRegular.graduationCap,
                          size: 42,
                          color: accent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Título principal
                  Text(
                    'Comunidad USAC',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Subtítulo
                  Text(
                    'Tu portal estudiantil independiente para foro, grupos, marketplace y campus universitario.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      height: 1.4,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Tarjeta explicativa del Modo Lectura
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: panelBg,
                      border: Border.all(color: panelBorder),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          PhosphorIconsRegular.info,
                          size: 20,
                          color: accent,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Modo lectura: podrás explorar el foro y el marketplace, pero necesitas una cuenta para publicar.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: isDark
                                  ? Colors.grey.shade300
                                  : const Color(0xFF334155),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Botón Principal: Iniciar sesión
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    onPressed: () => _handleSignIn(context),
                    child: const Text(
                      'Iniciar sesión',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Botón Secundario: Continuar como anónimo
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.white : const Color(0xFF1E293B),
                      side: BorderSide(color: panelBorder, width: 1.2),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    onPressed: () => _handleContinueAsGuest(context),
                    child: const Text(
                      'Continuar como anónimo',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Enlace a normas
                  Center(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor:
                            isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                      icon: const Icon(
                        PhosphorIconsRegular.shieldCheck,
                        size: 16,
                      ),
                      label: const Text(
                        'Normas Comunitarias & Descargo Legal',
                        style: TextStyle(
                          fontSize: 12,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      onPressed: () => _openRules(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
