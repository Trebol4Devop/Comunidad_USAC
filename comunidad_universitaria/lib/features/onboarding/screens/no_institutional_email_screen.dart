import 'dart:async';
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/constants/zanate_colors.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../verification/screens/verification_flow_screen.dart';
import '../../verification/state/verification_controller.dart';
import '../../verification/widgets/verification_gate.dart';
import '../state/session_controller.dart';
import 'merchant_verification_screen.dart';

/// Pantalla que se presenta a usuarios sin correo institucional (@usac.edu.gt),
/// permitiendo elegir entre el camino de estudiante (Camino B con documento)
/// y el camino de comerciante del campus.
class NoInstitutionalEmailScreen extends StatefulWidget {
  final VerificationController? verificationController;
  final SessionController? sessionController;
  final AuthApi? authApi;
  final VoidCallback? onStudentSelected;
  final VoidCallback? onMerchantSelected;

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
    extends State<NoInstitutionalEmailScreen> {
  bool _isBusy = false;
  bool _waitingForGoogle = false;
  bool? _pendingStudent;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void dispose() {
    unawaited(_authSubscription?.cancel());
    super.dispose();
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

  void _navigateToStudent() {
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
    final ctrl = widget.verificationController ??
        VerificationGate.maybeOf(context);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MerchantVerificationScreen(
          verificationController: ctrl,
          sessionController: widget.sessionController,
        ),
      ),
    );
  }

  Future<void> _handleSelection({required bool isStudent}) async {
    if (_isBusy) return;

    if (_isAuthenticated) {
      if (isStudent) {
        _navigateToStudent();
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
        unawaited(_authSubscription?.cancel());
        _authSubscription = null;
        if (mounted) {
          setState(() {
            _isBusy = false;
            _waitingForGoogle = false;
          });
          if (_pendingStudent == true) {
            _navigateToStudent();
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
        final msg = SupabaseService.lastGoogleAuthError ??
            'No se pudo iniciar sesión con Google.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
        return;
      }

      final currentUser = api?.currentUser ?? SupabaseService.currentUser;
      if (currentUser != null && !currentUser.isAnonymous) {
        unawaited(_authSubscription?.cancel());
        _authSubscription = null;
        if (mounted) {
          setState(() {
            _isBusy = false;
            _waitingForGoogle = false;
          });
          if (_pendingStudent == true) {
            _navigateToStudent();
          } else if (_pendingStudent == false) {
            _navigateToMerchant();
          }
        }
        return;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final studentColor = isDark
        ? const Color(0xFF60A5FA)
        : ZanateColors.zanateAccent;
    final merchantColor = isDark
        ? const Color(0xFFFBBF24)
        : const Color(0xFFD97706);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Opciones de Verificación',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Regresar',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Encabezado explicativo
                  Text(
                    '¿No cuentas con correo institucional?',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Si usas una cuenta de correo personal o comercial, elige tu perfil para validar tu identidad dentro de la comunidad:',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (_waitingForGoogle) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFEFF6FF),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF3B82F6)
                              : const Color(0xFF93C5FD),
                        ),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Completa el acceso en Google y regresa a la app para continuar.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white : Colors.blue.shade900,
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
                    subtitle: 'Tengo constancia de inscripción o carné físico',
                    description:
                        'Verifica tu condición estudiantil subiendo una fotografía de tu carné, boleta de pago o constancia de inscripción mediante escaneo OCR.',
                    badgeText: 'Camino B Estudiantil',
                    icon: PhosphorIconsRegular.student,
                    accentColor: studentColor,
                    isDark: isDark,
                    isBusy: _isBusy,
                    buttonLabel: 'Verificar como Estudiante',
                    onTap: () => _handleSelection(isStudent: true),
                  ),

                  const SizedBox(height: 18),

                  // Tarjeta 2: Comerciante
                  _VerificationOptionCard(
                    title: 'Comerciante del Campus',
                    subtitle: 'Tengo un negocio dentro del campus (DPI + local)',
                    description:
                        'Para propietarios y encargados de locales o puestos comerciales dentro del campus central o sedes. Requiere DPI vigente y fotografía del establecimiento.',
                    badgeText: 'Comercio Local',
                    icon: PhosphorIconsRegular.storefront,
                    accentColor: merchantColor,
                    isDark: isDark,
                    isBusy: _isBusy,
                    buttonLabel: 'Solicitar acceso de Comerciante',
                    onTap: () => _handleSelection(isStudent: false),
                  ),

                  const SizedBox(height: 28),
                  Text(
                    'Tu información está protegida. Las imágenes de documentos se procesan de forma cifrada y no se almacenan en texto plano.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
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

class _VerificationOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String description;
  final String badgeText;
  final IconData icon;
  final Color accentColor;
  final bool isDark;
  final bool isBusy;
  final String buttonLabel;
  final VoidCallback onTap;

  const _VerificationOptionCard({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.badgeText,
    required this.icon,
    required this.accentColor,
    required this.isDark,
    required this.isBusy,
    required this.buttonLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        border: Border.all(color: cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 40 : 10),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Barra de acento superior
          Container(
            height: 4,
            color: accentColor,
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: accentColor.withAlpha(isDark ? 45 : 30),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: accentColor, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: accentColor.withAlpha(isDark ? 35 : 25),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  badgeText,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: accentColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.grey.shade300
                                  : const Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    onPressed: isBusy ? null : onTap,
                    child: Text(
                      buttonLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
