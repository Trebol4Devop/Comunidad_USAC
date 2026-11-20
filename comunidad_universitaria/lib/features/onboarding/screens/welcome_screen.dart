import 'dart:math' as math;
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
  final VoidCallback? onCreateAccount;
  final VoidCallback? onContinueAsGuest;
  final VerificationController? verificationController;
  final SessionController? sessionController;

  const WelcomeScreen({
    super.key,
    this.onSignIn,
    this.onCreateAccount,
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

  void _handleCreateAccount(BuildContext context) {
    if (onCreateAccount != null) {
      onCreateAccount!();
      return;
    }
    if (onSignIn != null) {
      onSignIn!();
      return;
    }
    AuthGatewayScreen.show(
      context,
      verificationController: verificationController,
      sessionController: sessionController,
      title: 'Crear cuenta',
      subtitle:
          'Regístrate con tu cuenta de Google institucional o personal para empezar.',
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = ZanateColors.bg(isDark);
    return Scaffold(
      backgroundColor: bgColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 780;

          if (isWide) {
            return Row(
              children: [
                // Panel izquierdo: limpio con el Zanate protagonista y frase abajo a la izquierda
                const Expanded(
                  flex: 11,
                  child: _WhiteBrandPanel(),
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: ZanateColors.border(isDark),
                ),
                // Panel derecho: acciones e insignia abajo a la derecha
                Expanded(
                  flex: 9,
                  child: Container(
                    color: bgColor,
                    child: SafeArea(
                      child: Stack(
                        children: [
                          Center(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(
                                32,
                                32,
                                32,
                                56,
                              ),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 410),
                                child: _EntranceTransition(
                                  child: _ActionsColumn(
                                    showPanelHeading: true,
                                    onSignIn: () => _handleSignIn(context),
                                    onCreateAccount: () =>
                                        _handleCreateAccount(context),
                                    onContinueAsGuest: () =>
                                        _handleContinueAsGuest(context),
                                    onOpenRules: () => _openRules(context),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 28,
                            bottom: 10,
                            child: _TrebolCreditBadge(onDark: isDark),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          // Vista móvil / estrecha: fondo limpio en claro/oscuro, mejor distribución y crédito abajo
          return SafeArea(
            child: LayoutBuilder(
              builder: (context, mobileConstraints) {
                final logoSize = math.min(
                  118.0,
                  math.max(82.0, mobileConstraints.maxHeight * 0.14),
                );
                final isCompactHeight = mobileConstraints.maxHeight < 680;

                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: mobileConstraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 440,
                                  ),
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Padding(
                                        padding: EdgeInsets.only(
                                          top: isCompactHeight ? 12 : 20,
                                          bottom: isCompactHeight ? 12 : 20,
                                        ),
                                        child: _CompactMobileHeader(
                                          logoSize: logoSize,
                                          compact: isCompactHeight,
                                        ),
                                      ),
                                      _EntranceTransition(
                                        child: _ActionsColumn(
                                          showPanelHeading: false,
                                          compact: isCompactHeight,
                                          onSignIn: () =>
                                              _handleSignIn(context),
                                          onCreateAccount: () =>
                                              _handleCreateAccount(context),
                                          onContinueAsGuest: () =>
                                              _handleContinueAsGuest(context),
                                          onOpenRules: () =>
                                              _openRules(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 10, bottom: 6),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: _TrebolCreditBadge(onDark: isDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _EntranceTransition extends StatelessWidget {
  final Widget child;

  const _EntranceTransition({required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _WhiteBrandPanel extends StatelessWidget {
  const _WhiteBrandPanel();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: ZanateColors.bg(isDark),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Duplica el tamaño del logo en escritorio y escala en ventanas más bajas
            final logoSize = math.min(
              400.0,
              math.max(190.0, constraints.maxHeight * 0.44),
            );
            final taglineSize = constraints.maxHeight < 700 ? 30.0 : 38.0;

            return Stack(
              children: [
                Align(
                  alignment: const Alignment(0, -0.35),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 36),
                    child: _BrandHero(
                      logoSize: logoSize,
                      titleSize: 56,
                    ),
                  ),
                ),
                Positioned(
                  left: 36,
                  bottom: 28,
                  child: _ExplorationTagline(fontSize: taglineSize),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CompactMobileHeader extends StatelessWidget {
  final double logoSize;
  final bool compact;

  const _CompactMobileHeader({
    this.logoSize = 104,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = ZanateColors.textPrimary(isDark);
    final textSecondary = ZanateColors.textSecondary(isDark);
    final titleSize = compact ? 34.0 : 40.0;
    final phraseSize = compact ? 16.0 : 17.5;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: logoSize,
          height: logoSize,
          child: Image.asset(
            'assets/images/zanate_logo.png',
            fit: BoxFit.contain,
            semanticLabel: 'Logo de Zanate',
            errorBuilder: (context, error, stackTrace) => Icon(
              PhosphorIconsRegular.bird,
              size: logoSize * 0.6,
              color: textPrimary,
            ),
          ),
        ),
        SizedBox(height: compact ? 6 : 10),
        Text(
          'Zanate',
          textAlign: TextAlign.center,
          style: GoogleFonts.croissantOne(
            fontSize: titleSize,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: textPrimary,
          ),
        ),
        SizedBox(height: compact ? 8 : 12),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.start,
          children: [
            Text(
              'Explora lo que se vive ',
              style: GoogleFonts.outfit(
                fontSize: phraseSize,
                fontWeight: FontWeight.w600,
                height: 1.25,
                color: textSecondary,
              ),
            ),
            IntrinsicWidth(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'en la USAC',
                    maxLines: 1,
                    softWrap: false,
                    style: GoogleFonts.outfit(
                      fontSize: phraseSize + 0.5,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: ZanateColors.zanateEyeYellow,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BrandHero extends StatelessWidget {
  final double logoSize;
  final double titleSize;

  const _BrandHero({
    required this.logoSize,
    required this.titleSize,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = ZanateColors.textPrimary(isDark);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: logoSize,
          height: logoSize,
          child: Image.asset(
            'assets/images/zanate_logo.png',
            fit: BoxFit.contain,
            semanticLabel: 'Logo de Zanate',
            errorBuilder: (context, error, stackTrace) => Icon(
              PhosphorIconsRegular.bird,
              size: logoSize * 0.6,
              color: textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Zanate',
          textAlign: TextAlign.center,
          style: GoogleFonts.croissantOne(
            fontSize: titleSize,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: textPrimary,
          ),
        ),
      ],
    );
  }
}

class _ExplorationTagline extends StatelessWidget {
  final double fontSize;

  const _ExplorationTagline({required this.fontSize});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = ZanateColors.textPrimary(isDark);
    final baseStyle = GoogleFonts.outfit(
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      height: 1.08,
      letterSpacing: -0.6,
      color: ZanateColors.textSecondary(isDark),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Explora', style: baseStyle),
        Text('lo que se', style: baseStyle),
        Text('vive en', style: baseStyle),
        const SizedBox(height: 2),
        IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'la USAC',
                maxLines: 1,
                softWrap: false,
                style: GoogleFonts.outfit(
                  fontSize: fontSize + 2,
                  fontWeight: FontWeight.w800,
                  height: 1.08,
                  letterSpacing: -0.6,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 4.5,
                decoration: BoxDecoration(
                  color: ZanateColors.zanateEyeYellow,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionsColumn extends StatelessWidget {
  final bool showPanelHeading;
  final bool compact;
  final VoidCallback onSignIn;
  final VoidCallback onCreateAccount;
  final VoidCallback onContinueAsGuest;
  final VoidCallback onOpenRules;

  const _ActionsColumn({
    required this.showPanelHeading,
    this.compact = false,
    required this.onSignIn,
    required this.onCreateAccount,
    required this.onContinueAsGuest,
    required this.onOpenRules,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = ZanateColors.textPrimary(isDark);
    final textSecondary = ZanateColors.textSecondary(isDark);
    final textMuted = ZanateColors.textMuted(isDark);
    final borderColor = ZanateColors.border(isDark);
    final buttonHeight = compact ? 48.0 : 54.0;
    final buttonPadding = EdgeInsets.symmetric(
      horizontal: compact ? 20 : 24,
      vertical: compact ? 12 : 15,
    );
    final buttonRadius = BorderRadius.circular(compact ? 14 : 16);
    final gap = compact ? 10.0 : 12.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showPanelHeading) ...[
          Text(
            'Ingresa a la comunidad',
            style: GoogleFonts.outfit(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Elige cómo quieres entrar hoy.',
            style: TextStyle(
              fontSize: 14,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Botón Principal: Iniciar sesión (Amarillo del ojo del Zanate)
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: ZanateColors.zanateEyeYellow,
            foregroundColor: ZanateColors.zanateBlack,
            elevation: 0,
            minimumSize: Size.fromHeight(buttonHeight),
            padding: buttonPadding,
            shape: RoundedRectangleBorder(borderRadius: buttonRadius),
          ),
          onPressed: onSignIn,
          icon: Icon(PhosphorIconsBold.signIn, size: compact ? 19 : 21),
          label: Text(
            'Iniciar sesión',
            style: TextStyle(
              fontSize: compact ? 15 : 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ),
        SizedBox(height: gap),

        // Botón para nuevos usuarios: Crear cuenta
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor:
                isDark ? ZanateColors.darkSurfaceSubtle : ZanateColors.zanateBlack,
            foregroundColor:
                isDark ? ZanateColors.darkTextPrimary : Colors.white,
            side: isDark ? BorderSide(color: borderColor, width: 1.2) : null,
            elevation: 0,
            minimumSize: Size.fromHeight(buttonHeight),
            padding: buttonPadding,
            shape: RoundedRectangleBorder(borderRadius: buttonRadius),
          ),
          onPressed: onCreateAccount,
          icon: Icon(PhosphorIconsBold.userPlus, size: compact ? 18 : 20),
          label: Text(
            'Crear cuenta',
            style: TextStyle(
              fontSize: compact ? 14.5 : 15.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),

        Padding(
          padding: EdgeInsets.symmetric(vertical: compact ? 10 : 14),
          child: Row(
            children: [
              Expanded(child: Divider(color: borderColor, height: 1)),
              Flexible(
                flex: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    'o explora sin registro',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              Expanded(child: Divider(color: borderColor, height: 1)),
            ],
          ),
        ),

        // Botón Secundario: Continuar como anónimo
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: textPrimary,
            backgroundColor: ZanateColors.surface(isDark),
            side: BorderSide(
              color: isDark ? borderColor : const Color(0xFFCBD5E1),
              width: 1.3,
            ),
            minimumSize: Size.fromHeight(buttonHeight),
            padding: buttonPadding,
            shape: RoundedRectangleBorder(borderRadius: buttonRadius),
          ),
          onPressed: onContinueAsGuest,
          icon: Icon(
            PhosphorIconsRegular.eye,
            size: compact ? 18 : 20,
            color: textSecondary,
          ),
          label: Text(
            'Continuar como anónimo',
            style: TextStyle(
              fontSize: compact ? 14.5 : 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(height: compact ? 12 : 16),

        // Tarjeta explicativa del Modo Anónimo
        _AnonymousModeNoticeCard(compact: compact),
        SizedBox(height: compact ? 8 : 16),

        // Enlace a normas
        Center(
          child: TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: textSecondary,
              padding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: compact ? 4 : 8,
              ),
              tapTargetSize: compact
                  ? MaterialTapTargetSize.shrinkWrap
                  : MaterialTapTargetSize.padded,
            ),
            icon: const Icon(PhosphorIconsRegular.shieldCheck, size: 16),
            label: const Text(
              'Normas Comunitarias & Descargo Legal',
              style: TextStyle(
                fontSize: 12,
                decoration: TextDecoration.underline,
              ),
            ),
            onPressed: onOpenRules,
          ),
        ),
      ],
    );
  }
}

class _TrebolCreditBadge extends StatelessWidget {
  final bool onDark;

  const _TrebolCreditBadge({required this.onDark});

  @override
  Widget build(BuildContext context) {
    final textColor = onDark ? Colors.white : ZanateColors.zanateBlack;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/Logo Trébol Asociados_sinFondo.png',
          width: 24,
          height: 24,
          fit: BoxFit.contain,
          color: textColor,
          colorBlendMode: BlendMode.srcIn,
          semanticLabel: 'Logo de Trebol4Devop',
          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
        ),
        const SizedBox(width: 7),
        Text(
          'Trebol4Devop',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: textColor,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _AnonymousModeNoticeCard extends StatelessWidget {
  final bool compact;

  const _AnonymousModeNoticeCard({this.compact = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 14,
        vertical: compact ? 10 : 13,
      ),
      decoration: BoxDecoration(
        color: ZanateColors.zanateEyeYellow
            .withValues(alpha: isDark ? 0.16 : 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ZanateColors.zanateEyeYellow.withValues(alpha: 0.6),
          width: 1.1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              PhosphorIconsFill.info,
              size: compact ? 17 : 19,
              color: isDark
                  ? ZanateColors.zanateEyeYellow
                  : const Color(0xFFB45309),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                  fontSize: compact ? 12 : 12.5,
                  height: 1.35,
                  color: isDark
                      ? const Color(0xFFFDE68A)
                      : const Color(0xFF334155),
                  fontWeight: FontWeight.w500,
                ),
                children: [
                  TextSpan(
                    text: 'Modo anónimo: ',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: ZanateColors.textPrimary(isDark),
                    ),
                  ),
                  const TextSpan(
                    text:
                        'podrás explorar el foro y el marketplace, pero necesitas una cuenta para publicar.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
