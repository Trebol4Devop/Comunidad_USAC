import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../verification/screens/verification_flow_screen.dart';
import '../../verification/state/verification_controller.dart';
import '../../verification/widgets/verification_gate.dart';
import '../state/session_controller.dart';
import 'merchant_support_screen.dart';

/// Pantalla que se presenta a usuarios sin correo institucional (@usac.edu.gt).
/// Ofrece contactar con soporte para estudiantes y el flujo de comerciante del campus.
class NoInstitutionalEmailScreen extends StatefulWidget {
  final VerificationController? verificationController;
  final SessionController? sessionController;
  final AuthApi? authApi;
  final VoidCallback? onStudentSelected;
  final VoidCallback? onMerchantSelected;

  static const Color _zanateBlack = Color(0xFF0B0D10);
  static const Color _zanateEyeYellow = Color(0xFFF5C518);

  const NoInstitutionalEmailScreen({
    super.key,
    this.verificationController,
    this.sessionController,
    this.authApi,
    this.onStudentSelected,
    this.onMerchantSelected,
  });

  @override
  State<NoInstitutionalEmailScreen> createState() =>
      _NoInstitutionalEmailScreenState();
}

class _NoInstitutionalEmailScreenState
    extends State<NoInstitutionalEmailScreen>
    with WidgetsBindingObserver {
  bool _isBusy = false;
  bool _waitingForGoogle = false;
  bool? _pendingStudent;
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
    if (_isAuthenticated) {
      final wasStudent = _pendingStudent;
      _resumeGraceTimer?.cancel();
      unawaited(_authSubscription?.cancel());
      _authSubscription = null;
      setState(() {
        _isBusy = false;
        _waitingForGoogle = false;
        _pendingStudent = null;
      });
      if (wasStudent == true) {
        _navigateToSupport();
      } else if (wasStudent == false) {
        _navigateToMerchant();
      }
      return;
    }

    _cancelPendingGoogleWait(
      message: 'No se completó el acceso con Google. Puedes intentarlo de nuevo.',
    );
  }

  void _cancelPendingGoogleWait({String? message}) {
    _resumeGraceTimer?.cancel();
    unawaited(_authSubscription?.cancel());
    _authSubscription = null;
    unawaited(LocalStorageService.clearPendingAuthIntent());
    if (!mounted) return;
    setState(() {
      _isBusy = false;
      _waitingForGoogle = false;
      _pendingStudent = null;
    });
    if (message != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  bool get _isAuthenticated {
    final sCtrl =
        widget.sessionController ?? SessionController.maybeOf(context);
    if (sCtrl != null) return sCtrl.isAuthenticated;
    final api = widget.authApi;
    if (api != null) {
      return api.currentUser != null && !api.currentUser!.isAnonymous;
    }
    return SupabaseService.isAuthenticated;
  }

  void _navigateToSupport() {
    if (widget.onStudentSelected != null) {
      widget.onStudentSelected!();
      return;
    }
    final ctrl = widget.verificationController ??
        VerificationGate.maybeOf(context) ??
        VerificationController();
    VerificationFlowScreen.show(context, controller: ctrl, initialTab: 1);
  }

  void _navigateToMerchant() {
    if (widget.onMerchantSelected != null) {
      widget.onMerchantSelected!();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const MerchantSupportScreen(),
      ),
    );
  }

  Future<void> _handleSelection({required bool isStudent}) async {
    if (_isBusy) return;

    if (_isAuthenticated) {
      if (isStudent) {
        _navigateToSupport();
      } else {
        _navigateToMerchant();
      }
      return;
    }

    final sCtrl =
        widget.sessionController ?? SessionController.maybeOf(context);

    // Si no hay sesión real, primero guardamos la intención y lanzamos Google OAuth
    final intent = isStudent ? 'student' : 'merchant';
    await LocalStorageService.setPendingAuthIntent(intent);

    setState(() {
      _isBusy = true;
      _waitingForGoogle = true;
      _pendingStudent = isStudent;
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
            _isBusy = false;
            _waitingForGoogle = false;
          });
          if (_pendingStudent == true) {
            _navigateToSupport();
          } else if (_pendingStudent == false) {
            _navigateToMerchant();
          }
        }
      }
    });

    try {
      bool launched = false;
      if (sCtrl != null) {
        launched = await sCtrl.signInWithGoogle();
      } else if (api != null) {
        launched = await api.signInWithGoogle();
      } else {
        launched = await SupabaseService.signInWithGoogle();
      }
      if (!launched && mounted) {
        setState(() {
          _isBusy = false;
          _waitingForGoogle = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo iniciar sesión con Google.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isBusy = false;
          _waitingForGoogle = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al conectar con Google: $e')),
        );
      }
    }
  }

  Widget _buildContent(BuildContext context) {
    const subtleText = Color(0xFF475569);
    const mutedText = Color(0xFF64748B);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '¿No puedes verificar automáticamente?',
          style: GoogleFonts.outfit(
            fontSize: 25,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            height: 1.15,
            color: NoInstitutionalEmailScreen._zanateBlack,
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: NoInstitutionalEmailScreen._zanateEyeYellow,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Si usas una cuenta personal o comercial, elige tu perfil. Soporte revisará tu caso manualmente.',
          style: TextStyle(
            fontSize: 13.5,
            color: subtleText,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 16),

        if (_waitingForGoogle) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: NoInstitutionalEmailScreen._zanateEyeYellow.withValues(
                alpha: 0.14,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: NoInstitutionalEmailScreen._zanateBlack,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Completa el acceso en Google y regresa a la app para continuar.',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _cancelPendingGoogleWait(),
                  style: TextButton.styleFrom(
                    foregroundColor: NoInstitutionalEmailScreen._zanateBlack,
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

        // Tarjeta 1: Estudiante
        _VerificationOptionCard(
          title: 'Estudiante USAC',
          subtitle:
              'No tengo correo institucional o la verificación automática falló',
          icon: PhosphorIconsRegular.student,
          buttonBg: NoInstitutionalEmailScreen._zanateEyeYellow,
          buttonFg: NoInstitutionalEmailScreen._zanateBlack,
          isBusy: _isBusy,
          buttonLabel: 'Contactar con soporte',
          buttonKey: const Key('student_support_button'),
          onTap: () => _handleSelection(isStudent: true),
        ),

        const SizedBox(height: 16),

        // Tarjeta 2: Comerciante
        _VerificationOptionCard(
          title: 'Comerciante del Campus',
          subtitle: 'Quiero registrar mi negocio en el campus',
          icon: PhosphorIconsRegular.storefront,
          buttonBg: NoInstitutionalEmailScreen._zanateBlack,
          buttonFg: Colors.white,
          isBusy: _isBusy,
          buttonLabel: 'Contactar con soporte',
          buttonKey: const Key('merchant_support_button'),
          onTap: () => _handleSelection(isStudent: false),
        ),

        const SizedBox(height: 16),
        const Text(
          'La app no almacena el contenido del correo ni el carné que decidas incluir; se envía desde tu propia cuenta.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11.5,
            height: 1.4,
            color: mutedText,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  child: _NoInstBrandPanel(),
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
                              onPressed: () => Navigator.of(context).pop(),
                              tooltip: 'Regresar',
                              icon: const Icon(
                                PhosphorIconsBold.caretLeft,
                                size: 24,
                                color: NoInstitutionalEmailScreen._zanateBlack,
                              ),
                            ),
                          ),
                          Center(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(
                                32,
                                44,
                                32,
                                40,
                              ),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 440),
                                child: _NoInstEntranceTransition(
                                  child: _buildContent(context),
                                ),
                              ),
                            ),
                          ),
                          const Positioned(
                            right: 28,
                            bottom: 10,
                            child: _NoInstTrebolCreditBadge(),
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
                                      color: NoInstitutionalEmailScreen
                                          ._zanateBlack,
                                    ),
                                    tooltip: 'Regresar',
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 460,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    child: _NoInstEntranceTransition(
                                      child: _buildContent(context),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.only(top: 10, bottom: 8),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: _NoInstTrebolCreditBadge(),
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

class _NoInstEntranceTransition extends StatelessWidget {
  final Widget child;

  const _NoInstEntranceTransition({required this.child});

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

class _NoInstBrandPanel extends StatelessWidget {
  const _NoInstBrandPanel();

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
                              color: NoInstitutionalEmailScreen._zanateBlack,
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
                            color: NoInstitutionalEmailScreen._zanateBlack,
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
                                color: NoInstitutionalEmailScreen._zanateBlack,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              height: 4.5,
                              decoration: BoxDecoration(
                                color:
                                    NoInstitutionalEmailScreen._zanateEyeYellow,
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

class _NoInstTrebolCreditBadge extends StatelessWidget {
  const _NoInstTrebolCreditBadge();

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
          color: NoInstitutionalEmailScreen._zanateBlack,
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
            color: NoInstitutionalEmailScreen._zanateBlack,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _VerificationOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color buttonBg;
  final Color buttonFg;
  final bool isBusy;
  final String buttonLabel;
  final Key? buttonKey;
  final VoidCallback onTap;

  const _VerificationOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.buttonBg,
    required this.buttonFg,
    required this.isBusy,
    required this.buttonLabel,
    this.buttonKey,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: NoInstitutionalEmailScreen._zanateBlack,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          color: NoInstitutionalEmailScreen._zanateBlack,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: buttonKey,
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonBg,
                  foregroundColor: buttonFg,
                  elevation: 0,
                  minimumSize: const Size.fromHeight(46),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: isBusy ? null : onTap,
                child: Text(
                  buttonLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
