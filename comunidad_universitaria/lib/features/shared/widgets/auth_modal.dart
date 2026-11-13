import 'dart:async';

import 'package:flutter/material.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';

class AuthModal extends StatefulWidget {
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

  static Future<void> show(
    BuildContext context, {
    String? title,
    String? subtitle,
    required VoidCallback onAuthenticated,
  }) {
    if (Responsive.isMobile(context)) {
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        builder: (ctx) => AuthModal(
          title: title ?? 'Inicia Sesión para Publicar',
          subtitle:
              subtitle ??
              'Para proteger la comunidad y mantener la autenticidad del Marketplace, debes iniciar sesión.',
          onAuthenticated: onAuthenticated,
        ),
      );
    } else {
      return showDialog(
        context: context,
        builder: (ctx) => AuthModal(
          title: title ?? 'Inicia Sesión para Publicar',
          subtitle:
              subtitle ??
              'Para proteger la comunidad y mantener la autenticidad del Marketplace, debes iniciar sesión.',
          onAuthenticated: onAuthenticated,
        ),
      );
    }
  }

  @override
  State<AuthModal> createState() => _AuthModalState();
}

class _AuthModalState extends State<AuthModal> {
  bool _isLoading = false;
  bool _waitingForGoogle = false;
  bool _googleAuthCompleted = false;
  StreamSubscription<AuthState>? _googleAuthSubscription;
  String? _errorMessage;

  @override
  void dispose() {
    unawaited(_googleAuthSubscription?.cancel());
    super.dispose();
  }

  void _handleGoogleAuthState(AuthState state) {
    if (_googleAuthCompleted ||
        state.event != AuthChangeEvent.signedIn ||
        state.session?.user.isAnonymous != false) {
      return;
    }

    _googleAuthCompleted = true;
    unawaited(_googleAuthSubscription?.cancel());
    _googleAuthSubscription = null;
    if (!mounted) return;

    setState(() => _waitingForGoogle = false);
    Navigator.of(context).pop();
    widget.onAuthenticated();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _waitingForGoogle = false;
      _googleAuthCompleted = false;
      _errorMessage = null;
    });

    await _googleAuthSubscription?.cancel();
    _googleAuthSubscription = SupabaseService.client.auth.onAuthStateChange
        .listen(_handleGoogleAuthState);

    try {
      final currentUrl = SupabaseService.oauthRedirectUrl;
      final launched = await SupabaseService.signInWithGoogle(
        redirectTo: currentUrl,
      );
      if (!launched) {
        throw StateError('No se pudo iniciar el acceso con Google.');
      }
      if (mounted && !_googleAuthCompleted) {
        setState(() {
          _isLoading = false;
          _waitingForGoogle = true;
        });
      }
    } catch (e) {
      await _googleAuthSubscription?.cancel();
      _googleAuthSubscription = null;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = isDark ? Colors.white : const Color(0xFF111827);
    final panelColor = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFF1F5F9);
    final panelBorder = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final isMobile = Responsive.isMobile(context);
    final isBusy = _isLoading || _waitingForGoogle;

    Widget content = SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: panelColor,
                  borderRadius: BorderRadius.zero,
                ),
                child: Icon(Icons.lock_outline, color: accentColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Divider(height: 24),

          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: panelColor,
                border: Border.all(color: panelBorder),
              ),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: accentColor, fontSize: 12),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Google Sign-In Button
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: accentColor,
              side: BorderSide(color: panelBorder),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
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
                : const Icon(
                    Icons.g_mobiledata,
                    size: 26,
                    color: Color(0xFFEA4335),
                  ),
            label: Text(
              _isLoading ? 'Conectando...' : 'Continuar con Google',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            onPressed: isBusy ? null : _handleGoogleSignIn,
          ),

          if (_waitingForGoogle) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: panelColor,
                border: Border.all(color: panelBorder),
              ),
              child: const Text(
                'Completa el acceso en Google y regresa a Comunidad USAC. '
                'La sesión se confirmará al volver a la app.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],

          const SizedBox(height: 12),
          Text(
            'Usa tu cuenta de Google para iniciar sesión o crear una cuenta.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );

    if (isMobile) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: content,
      );
    } else {
      return Dialog(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: content,
        ),
      );
    }
  }
}
