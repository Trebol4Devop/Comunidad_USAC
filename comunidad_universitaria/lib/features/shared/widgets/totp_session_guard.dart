import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/constants/zanate_colors.dart';
import '../../../core/services/supabase_service.dart';
import 'zanate_ui.dart';

class TotpSessionGuard extends StatefulWidget {
  const TotpSessionGuard({super.key, required this.child});

  final Widget child;

  @override
  State<TotpSessionGuard> createState() => _TotpSessionGuardState();
}

enum _TotpGateState { none, checking, challenge, error }

class _TotpSessionGuardState extends State<TotpSessionGuard> {
  StreamSubscription<AuthState>? _authSubscription;
  _TotpGateState _gateState = _TotpGateState.none;
  String? _factorId;
  int _evaluationId = 0;

  @override
  void initState() {
    super.initState();
    if (!SupabaseConfig.isConfigured) return;

    _authSubscription = SupabaseService.client.auth.onAuthStateChange.listen(
      _handleAuthState,
    );
    if (SupabaseService.currentUser != null) {
      unawaited(_evaluateCurrentSession());
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _handleAuthState(AuthState state) {
    if (state.event == AuthChangeEvent.signedOut) {
      _clearGate();
      return;
    }

    if (state.event == AuthChangeEvent.initialSession ||
        state.event == AuthChangeEvent.signedIn ||
        state.event == AuthChangeEvent.userUpdated ||
        state.event == AuthChangeEvent.mfaChallengeVerified) {
      unawaited(_evaluateCurrentSession());
    }
  }

  Future<void> _evaluateCurrentSession() async {
    final evaluationId = ++_evaluationId;
    final user = SupabaseService.currentUser;
    if (user == null || user.isAnonymous) {
      if (mounted) setState(() => _gateState = _TotpGateState.none);
      return;
    }

    if (mounted) {
      setState(() {
        _gateState = _TotpGateState.checking;
        _factorId = null;
      });
    }

    try {
      final assurance = await SupabaseService.getTotpAssuranceLevel();
      if (evaluationId != _evaluationId || !mounted) return;

      final factors = await SupabaseService.listTotpFactors();
      if (evaluationId != _evaluationId || !mounted) return;
      final verifiedFactors = factors
          .where((factor) => factor.status == FactorStatus.verified)
          .toList();
      final verifiedFactor = verifiedFactors.isEmpty
          ? null
          : verifiedFactors.first;

      setState(() {
        _factorId = verifiedFactor?.id;
        // El autenticador es opcional: quien no lo tenga configurado entra
        // directamente a la app y puede activarlo desde su perfil.
        _gateState = verifiedFactor == null
            ? _TotpGateState.none
            : assurance.currentLevel == AuthenticatorAssuranceLevels.aal2
            ? _TotpGateState.none
            : _TotpGateState.challenge;
      });
    } catch (_) {
      if (evaluationId == _evaluationId && mounted) {
        setState(() => _gateState = _TotpGateState.error);
      }
    }
  }

  void _clearGate() {
    _evaluationId++;
    if (mounted) {
      setState(() {
        _gateState = _TotpGateState.none;
        _factorId = null;
      });
    }
  }

  Future<void> _signOut() async {
    try {
      await SupabaseService.signOut();
    } catch (_) {
      if (mounted) setState(() => _gateState = _TotpGateState.error);
    }
  }

  Widget _buildGate() {
    switch (_gateState) {
      case _TotpGateState.checking:
        return const _TotpStatusScreen(
          title: 'Verificando seguridad',
          message: 'Estamos comprobando la protección de tu cuenta.',
          showProgress: true,
        );
      case _TotpGateState.challenge:
        final factorId = _factorId;
        if (factorId == null) {
          return _TotpStatusScreen(
            title: 'No se pudo verificar la cuenta',
            message: 'Vuelve a intentarlo o cierra sesión.',
            onRetry: _evaluateCurrentSession,
            onSignOut: _signOut,
          );
        }
        return _TotpChallengeScreen(
          factorId: factorId,
          onVerified: _clearGate,
          onSignOut: _signOut,
        );
      case _TotpGateState.error:
        return _TotpStatusScreen(
          title: 'No se pudo verificar la seguridad',
          message: 'Comprueba tu conexión e inténtalo de nuevo.',
          onRetry: _evaluateCurrentSession,
          onSignOut: _signOut,
        );
      case _TotpGateState.none:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_gateState == _TotpGateState.none) return widget.child;

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned.fill(
          child: Overlay(
            key: ValueKey(_gateState),
            initialEntries: [
              OverlayEntry(
                builder: (context) => PopScope(
                  canPop: false,
                  child: Material(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: _buildGate(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TotpChallengeScreen extends StatefulWidget {
  const _TotpChallengeScreen({
    required this.factorId,
    required this.onVerified,
    required this.onSignOut,
  });

  final String factorId;
  final VoidCallback onVerified;
  final Future<void> Function() onSignOut;

  @override
  State<_TotpChallengeScreen> createState() => _TotpChallengeScreenState();
}

class _TotpChallengeScreenState extends State<_TotpChallengeScreen> {
  final _codeController = TextEditingController();
  bool _isVerifying = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() {
        _errorMessage = 'Ingresa el código actual de 6 dígitos.';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      await SupabaseService.verifyTotpChallenge(
        factorId: widget.factorId,
        code: code,
      );
      if (mounted) widget.onVerified();
    } catch (error) {
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _errorMessage =
              'El código no es válido o venció. Revisa tu app autenticadora.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = ZanateColors.bg(isDark);
    final textPrimary = ZanateColors.textPrimary(isDark);
    final textSecondary = ZanateColors.textSecondary(isDark);
    final textMuted = ZanateColors.textMuted(isDark);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          'Verificación de seguridad',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: textPrimary,
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: textMuted),
            onPressed: widget.onSignOut,
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: ZanateColors.zanateEyeYellow.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      PhosphorIconsFill.shieldCheck,
                      size: 36,
                      color: isDark
                          ? ZanateColors.zanateEyeYellow
                          : ZanateColors.zanateBlack,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Confirma que eres tú',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Center(child: ZanateAccentBar()),
                const SizedBox(height: 12),
                Text(
                  'Ingresa el código actual de 6 dígitos de tu app autenticadora.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textSecondary, height: 1.4),
                ),
                const SizedBox(height: 20),
                if (_errorMessage != null) ...[
                  _TotpErrorMessage(message: _errorMessage!),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: zanateInputDecoration(
                    isDark: isDark,
                    labelText: 'Código TOTP',
                    hintText: '123456',
                    prefixIcon: Icon(
                      PhosphorIconsRegular.password,
                      size: 20,
                      color: textMuted,
                    ),
                  ).copyWith(counterText: ''),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ZanateColors.ctaBg(isDark),
                    foregroundColor: ZanateColors.ctaFg(isDark),
                    elevation: 0,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _isVerifying ? null : _verify,
                  child: _isVerifying
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: ZanateColors.ctaFg(isDark),
                          ),
                        )
                      : const Text(
                          'Verificar código TOTP',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TotpStatusScreen extends StatelessWidget {
  const _TotpStatusScreen({
    required this.title,
    required this.message,
    this.showProgress = false,
    this.onRetry,
    this.onSignOut,
  });

  final String title;
  final String message;
  final bool showProgress;
  final Future<void> Function()? onRetry;
  final Future<void> Function()? onSignOut;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = ZanateColors.bg(isDark);
    final textPrimary = ZanateColors.textPrimary(isDark);
    final textSecondary = ZanateColors.textSecondary(isDark);
    final textMuted = ZanateColors.textMuted(isDark);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          'Autenticación protegida',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: textPrimary,
          ),
        ),
        actions: onSignOut == null
            ? null
            : [
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: textMuted),
                  onPressed: onSignOut,
                  child: const Text('Cerrar sesión'),
                ),
              ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showProgress) ...[
                CircularProgressIndicator(
                  color: isDark
                      ? ZanateColors.zanateEyeYellow
                      : ZanateColors.zanateBlack,
                ),
                const SizedBox(height: 20),
              ],
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: textSecondary, height: 1.4),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ZanateColors.ctaBg(isDark),
                    foregroundColor: ZanateColors.ctaFg(isDark),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: onRetry,
                  child: const Text(
                    'Reintentar',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TotpErrorMessage extends StatelessWidget {
  const _TotpErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF7F1D1D).withValues(alpha: 0.35)
            : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? const Color(0xFFF87171).withValues(alpha: 0.45)
              : const Color(0xFFFCA5A5),
        ),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
        ),
      ),
    );
  }
}
