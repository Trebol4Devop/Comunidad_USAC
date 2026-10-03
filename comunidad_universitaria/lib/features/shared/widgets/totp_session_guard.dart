import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/services/supabase_service.dart';
import '../../profile/screens/totp_enrollment_screen.dart';

class TotpSessionGuard extends StatefulWidget {
  const TotpSessionGuard({super.key, required this.child});

  final Widget child;

  @override
  State<TotpSessionGuard> createState() => _TotpSessionGuardState();
}

enum _TotpGateState { none, checking, enrollment, challenge, error }

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
      if (assurance.currentLevel == AuthenticatorAssuranceLevels.aal2) {
        setState(() => _gateState = _TotpGateState.none);
        return;
      }

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
        _gateState = verifiedFactor == null
            ? _TotpGateState.enrollment
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
      case _TotpGateState.enrollment:
        return TotpEnrollmentScreen(
          isRequired: true,
          onEnrollmentComplete: _clearGate,
          onCancelRequired: _signOut,
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
      setState(() => _errorMessage = 'Ingresa el código actual de 6 dígitos.');
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
    } catch (_) {
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
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Verificación de seguridad'),
        actions: [
          TextButton(
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
                const Icon(Icons.security_outlined, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Confirma que eres tú',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ingresa el código actual de 6 dígitos de tu app autenticadora.',
                  textAlign: TextAlign.center,
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
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Código TOTP',
                    hintText: '123456',
                    prefixIcon: Icon(Icons.password_outlined),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isVerifying ? null : _verify,
                  child: _isVerifying
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Verificar código TOTP'),
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
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Autenticación protegida'),
        actions: onSignOut == null
            ? null
            : [
                TextButton(
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
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
              ],
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              if (onRetry != null) ...[
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: onRetry,
                  child: const Text('Reintentar'),
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Text(message, style: const TextStyle(color: Color(0xFFB91C1C))),
    );
  }
}
