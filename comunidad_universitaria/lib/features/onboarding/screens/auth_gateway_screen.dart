import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../verification/screens/verification_flow_screen.dart';
import '../../verification/state/verification_controller.dart';
import '../../verification/utils/verification_validators.dart';
import '../../verification/widgets/verification_gate.dart';
import '../state/session_controller.dart';
import '../widgets/auth_gate.dart';
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

  static const Color _zanateBlack = Color(0xFF0B0D10);
  static const Color _zanateEyeYellow = Color(0xFFF5C518);

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
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
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

class _AuthGatewayScreenState extends State<AuthGatewayScreen>
    with WidgetsBindingObserver {
  bool _isLoading = false;
  bool _waitingForGoogle = false;
  String? _errorMessage;
  StreamSubscription<AuthState>? _authSubscription;
  Timer? _resumeGraceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _resumeGraceTimer?.cancel();
    unawaited(_authSubscription?.cancel());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _waitingForGoogle) {
      _resumeGraceTimer?.cancel();
      _resumeGraceTimer = Timer(
        const Duration(milliseconds: 1500),
        _verifyAuthAfterResume,
      );
    }
  }

  void _verifyAuthAfterResume() {
    if (!mounted || !_waitingForGoogle) return;
    final api = widget.authApi;
    final currentUser = api != null
        ? api.currentUser
        : (SupabaseConfig.isConfigured
            ? SupabaseService.client.auth.currentUser
            : null);

    if (currentUser != null && !currentUser.isAnonymous) {
      _resumeGraceTimer?.cancel();
      unawaited(_authSubscription?.cancel());
      _authSubscription = null;
      setState(() {
        _isLoading = false;
        _waitingForGoogle = false;
      });
      if (AuthGate.hasActiveInstance) {
        widget.onAuthenticatedSuccess?.call();
        Navigator.of(context).pop(true);
        return;
      }
      _handlePostLogin(currentUser);
      return;
    }

    _cancelPendingGoogleWait();
  }

  void _cancelPendingGoogleWait() {
    _resumeGraceTimer?.cancel();
    unawaited(_authSubscription?.cancel());
    _authSubscription = null;
    unawaited(LocalStorageService.clearPendingAuthIntent());
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _waitingForGoogle = false;
    });
  }

  Future<void> _handlePostLogin(User user) async {
    final ctrl = widget.verificationController ??
        VerificationGate.maybeOf(context);
    // Asegura el estado real antes de decidir el destino (verificación automática vs. ya
    // verificado). Sin esto, un perfil ya verificado podría entrar a la verificación automática.
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
        _resumeGraceTimer?.cancel();
        unawaited(_authSubscription?.cancel());
        _authSubscription = null;
        if (mounted) {
          setState(() {
            _isLoading = false;
            _waitingForGoogle = false;
          });
          if (AuthGate.hasActiveInstance) {
            widget.onAuthenticatedSuccess?.call();
            Navigator.of(context).pop(true);
            return;
          }
          _handlePostLogin(user);
        }
      }
    });

    try {
      await LocalStorageService.setPendingAuthIntent('auto');
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

      final currentUser =
          widget.authApi?.currentUser ?? SupabaseService.currentUser;
      if (currentUser != null && !currentUser.isAnonymous) {
        unawaited(_authSubscription?.cancel());
        _authSubscription = null;
        if (mounted) {
          setState(() {
            _isLoading = false;
            _waitingForGoogle = false;
          });
          _handlePostLogin(currentUser);
        }
        return;
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

  Widget _buildAuthContent(
    BuildContext context, {
    required bool isDark,
    bool showLogoBadge = true,
  }) {
    final theme = Theme.of(context);
    final accentColor = isDark ? Colors.white : AuthGatewayScreen._zanateBlack;
    final subtleText =
        isDark ? Colors.grey.shade400 : const Color(0xFF475569);
    final dividerColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final buttonBorderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
    final buttonBgColor =
        isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final isBusy = _isLoading || _waitingForGoogle;

    final titleText = widget.title ?? 'Inicio de sesión';
    final subtitleText = widget.subtitle ??
        'Accede con tu cuenta institucional o personal de Google para participar activamente.';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showLogoBadge) ...[
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: Image.asset(
                    'assets/images/zanate_logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      PhosphorIconsRegular.bird,
                      color: accentColor,
                      size: 48,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Zanate',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.croissantOne(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        Text(
          titleText,
          textAlign: showLogoBadge ? TextAlign.center : TextAlign.start,
          style: GoogleFonts.outfit(
            fontSize: widget.isModal ? 22 : 26,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            height: 1.15,
            color: accentColor,
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: showLogoBadge ? Alignment.center : Alignment.centerLeft,
          child: Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: AuthGatewayScreen._zanateEyeYellow,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          subtitleText,
          textAlign: showLogoBadge ? TextAlign.center : TextAlign.start,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 13.5,
            height: 1.4,
            color: subtleText,
          ),
        ),
        const SizedBox(height: 22),

        // Manejo de errores con reintento
        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF3B1E1E)
                  : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(14),
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
                      PhosphorIconsRegular.warningCircle,
                      color: Color(0xFFEF4444),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color:
                              isDark ? Colors.white : const Color(0xFF991B1B),
                          fontSize: 12.5,
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
                        horizontal: 10,
                        vertical: 4,
                      ),
                    ),
                    icon: const Icon(PhosphorIconsRegular.arrowClockwise, size: 16),
                    label: const Text(
                      'Reintentar',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: isBusy ? null : _handleGoogleSignIn,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Botón Continuar con Google
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: accentColor,
            backgroundColor: buttonBgColor,
            side: BorderSide(color: buttonBorderColor, width: 1.3),
            minimumSize: const Size.fromHeight(54),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
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
              : const _GoogleGIcon(size: 20),
          label: Text(
            _isLoading ? 'Conectando...' : 'Continuar con Google',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          onPressed: isBusy ? null : _handleGoogleSignIn,
        ),

        if (_waitingForGoogle) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AuthGatewayScreen._zanateEyeYellow.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  PhosphorIconsFill.info,
                  size: 18,
                  color: Color(0xFFB45309),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Completa el acceso en Google y regresa a la app',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : const Color(0xFF334155),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _cancelPendingGoogleWait,
                  style: TextButton.styleFrom(
                    foregroundColor: accentColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 18),
        Divider(color: dividerColor, height: 1),
        const SizedBox(height: 12),

        // Enlace a sin correo institucional
        Center(
          child: TextButton(
            onPressed: isBusy ? null : _handleOpenNoInstitutional,
            style: TextButton.styleFrom(
              foregroundColor:
                  isDark ? Colors.grey.shade300 : AuthGatewayScreen._zanateBlack,
            ),
            child: Text(
              '¿No cuentas con correo institucional?',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                color: isDark
                    ? Colors.grey.shade300
                    : const Color(0xFF1E293B),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModalBody(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = Responsive.isMobile(context);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: isMobile
            ? const BorderRadius.vertical(top: Radius.circular(20))
            : BorderRadius.circular(20),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 20 : 28),
        child: _buildAuthContent(context, isDark: isDark, showLogoBadge: true),
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
          child: _buildModalBody(context),
        );
      } else {
        return _buildModalBody(context);
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 780;

          if (isWide) {
            return Row(
              children: [
                const Expanded(
                  flex: 11,
                  child: _AuthBrandPanel(),
                ),
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: Color(0xFFE2E8F0),
                ),
                Expanded(
                  flex: 9,
                  child: Container(
                    color: Colors.white,
                    child: SafeArea(
                      child: Stack(
                        children: [
                          Positioned(
                            top: 16,
                            left: 16,
                            child: IconButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              tooltip: 'Regresar',
                              icon: const Icon(
                                PhosphorIconsBold.caretLeft,
                                size: 24,
                                color: AuthGatewayScreen._zanateBlack,
                              ),
                            ),
                          ),
                          Center(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(
                                32,
                                64,
                                32,
                                56,
                              ),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 410),
                                child: _AuthEntranceTransition(
                                  child: _buildAuthContent(
                                    context,
                                    isDark: false,
                                    showLogoBadge: false,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const Positioned(
                            right: 28,
                            bottom: 10,
                            child: _AuthTrebolCreditBadge(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          return SafeArea(
            child: LayoutBuilder(
              builder: (context, mobileConstraints) {
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
                            Padding(
                              padding: const EdgeInsets.only(top: 8, bottom: 4),
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      PhosphorIconsBold.caretLeft,
                                      size: 24,
                                      color: AuthGatewayScreen._zanateBlack,
                                    ),
                                    tooltip: 'Regresar',
                                    onPressed: () =>
                                        Navigator.of(context).pop(false),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 420,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    child: _AuthEntranceTransition(
                                      child: _buildAuthContent(
                                        context,
                                        isDark: false,
                                        showLogoBadge: true,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.only(top: 10, bottom: 8),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: _AuthTrebolCreditBadge(),
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

class _AuthEntranceTransition extends StatelessWidget {
  final Widget child;

  const _AuthEntranceTransition({required this.child});

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

class _AuthBrandPanel extends StatelessWidget {
  const _AuthBrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final logoSize = math.min(
              400.0,
              math.max(190.0, constraints.maxHeight * 0.44),
            );
            final taglineSize = constraints.maxHeight < 700 ? 30.0 : 38.0;
            final baseStyle = GoogleFonts.outfit(
              fontSize: taglineSize,
              fontWeight: FontWeight.w700,
              height: 1.08,
              letterSpacing: -0.6,
              color: const Color(0xFF334155),
            );

            return Stack(
              children: [
                Align(
                  alignment: const Alignment(0, -0.35),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 36),
                    child: Column(
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
                              color: AuthGatewayScreen._zanateBlack,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Zanate',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.croissantOne(
                            fontSize: 56,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: AuthGatewayScreen._zanateBlack,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 36,
                  bottom: 28,
                  child: Column(
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
                                fontSize: taglineSize + 2,
                                fontWeight: FontWeight.w800,
                                height: 1.08,
                                letterSpacing: -0.6,
                                color: AuthGatewayScreen._zanateBlack,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              height: 4.5,
                              decoration: BoxDecoration(
                                color: AuthGatewayScreen._zanateEyeYellow,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AuthTrebolCreditBadge extends StatelessWidget {
  const _AuthTrebolCreditBadge();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/Logo Trébol Asociados_sinFondo.png',
          width: 24,
          height: 24,
          fit: BoxFit.contain,
          color: AuthGatewayScreen._zanateBlack,
          colorBlendMode: BlendMode.srcIn,
          semanticLabel: 'Logo de Trebol4Devop',
          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
        ),
        const SizedBox(width: 7),
        const Text(
          'Trebol4Devop',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AuthGatewayScreen._zanateBlack,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _GoogleGIcon extends StatelessWidget {
  final double size;

  const _GoogleGIcon({this.size = 20});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GoogleGPainter(),
      ),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final strokeWidth = size.width * 0.21;
    final radius = size.width * 0.37;
    final arcRect = Rect.fromCircle(center: center, radius: radius);

    Paint arcPaint(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    const deg = math.pi / 180;

    // Rojo (parte superior)
    canvas.drawArc(
      arcRect,
      -150 * deg,
      110 * deg,
      false,
      arcPaint(const Color(0xFFEA4335)),
    );

    // Amarillo (lado izquierdo)
    canvas.drawArc(
      arcRect,
      147 * deg,
      65 * deg,
      false,
      arcPaint(const Color(0xFFFBBC05)),
    );

    // Verde (parte inferior)
    canvas.drawArc(
      arcRect,
      44 * deg,
      105 * deg,
      false,
      arcPaint(const Color(0xFF34A853)),
    );

    // Azul (lado derecho inferior) + barra horizontal de la G
    final blueColor = const Color(0xFF4285F4);
    canvas.drawArc(
      arcRect,
      -6 * deg,
      52 * deg,
      false,
      arcPaint(blueColor),
    );

    canvas.save();
    final outerClip = Path()
      ..addOval(
        Rect.fromCircle(
          center: center,
          radius: radius + strokeWidth / 2,
        ),
      );
    canvas.clipPath(outerClip);
    canvas.drawRect(
      Rect.fromLTRB(
        center.dx,
        center.dy - strokeWidth * 0.46,
        size.width,
        center.dy + strokeWidth * 0.46,
      ),
      Paint()..color = blueColor,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
