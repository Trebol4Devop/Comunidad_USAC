import 'dart:async';

import 'package:flutter/foundation.dart';
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
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
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
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSignUp = false;
  bool _isLoading = false;
  bool _waitingForGoogle = false;
  bool _googleAuthCompleted = false;
  StreamSubscription<AuthState>? _googleAuthSubscription;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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
      final currentUrl = kIsWeb ? Uri.base.toString() : null;
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
          _errorMessage = 'Error al conectar con Google: ${e.toString()}';
        });
      }
    }
  }

  String _friendlyAuthError(Object error) {
    final message = error
        .toString()
        .replaceAll('Exception: ', '')
        .replaceAll('AuthException: ', '');
    final lowerMessage = message.toLowerCase();

    if (lowerMessage.contains('email not confirmed') ||
        lowerMessage.contains('email_not_confirmed') ||
        lowerMessage.contains('exige confirmar el correo')) {
      return 'Supabase todavía exige confirmar el correo. Desactiva "Confirm email" en Authentication > Sign In / Providers > Email.';
    }
    if (lowerMessage.contains('invalid login credentials')) {
      return 'Credenciales inválidas. Verifica tu correo y contraseña.';
    }

    if (lowerMessage.contains('rate limit') ||
        lowerMessage.contains('too many')) {
      return 'Se alcanzó el límite de intentos. Espera un momento antes de volver a intentarlo.';
    }
    return message;
  }

  Future<void> _handleEmailAuth() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      if (_isSignUp) {
        final res = await SupabaseService.signUp(
          email: email,
          password: password,
        );
        if (res == null) {
          throw StateError(
            'Supabase no está configurado para registrar cuentas.',
          );
        }
        if (!mounted) return;

        if (res.session == null) {
          throw StateError(
            'Supabase todavía exige confirmar el correo antes de iniciar sesión.',
          );
        }
        if (!mounted) return;
        setState(() => _isLoading = false);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cuenta creada con éxito.'),
            backgroundColor: Color(0xFF004B87),
          ),
        );
        widget.onAuthenticated();
      } else {
        await SupabaseService.signInWithPassword(
          email: email,
          password: password,
        );
        if (mounted) {
          setState(() => _isLoading = false);
          Navigator.of(context).pop();
          widget.onAuthenticated();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = _friendlyAuthError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = Responsive.isMobile(context);

    Widget content = Form(
      key: _formKey,
      child: SingleChildScrollView(
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
                    color: const Color(0xFF004B87).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.lock_outline,
                    color: Color(0xFF004B87),
                    size: 24,
                  ),
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
                          color: Colors.grey.shade600,
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
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: Color(0xFFB91C1C),
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Google Sign-In Button
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(
                Icons.g_mobiledata,
                size: 24,
                color: Color(0xFFEA4335),
              ),
              label: const Text(
                'Continuar con Google',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              onPressed: (_isLoading || _waitingForGoogle)
                  ? null
                  : _handleGoogleSignIn,
            ),
            if (_waitingForGoogle) ...[
              const SizedBox(height: 10),
              const Text(
                'Completa el acceso en Google y regresa a Comunidad USAC. '
                'La sesión se confirmará al volver a la app.',
                textAlign: TextAlign.center,
              ),
            ],

            const SizedBox(height: 16),

            Row(
              children: const [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    'o con correo',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
                Expanded(child: Divider()),
              ],
            ),

            const SizedBox(height: 14),

            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
                hintText: 'tu_correo@ejemplo.com',
                prefixIcon: Icon(Icons.email_outlined, size: 18),
              ),
              validator: (val) {
                if (val == null || !val.contains('@')) {
                  return 'Ingresa un correo válido';
                }
                return null;
              },
            ),

            const SizedBox(height: 12),

            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Contraseña',
                hintText: '••••••••',
                prefixIcon: Icon(Icons.lock_outline, size: 18),
              ),
              validator: (val) {
                if (val == null || val.length < 6) {
                  return 'La contraseña debe tener al menos 6 caracteres';
                }
                return null;
              },
            ),

            const SizedBox(height: 18),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF004B87),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _isLoading ? null : _handleEmailAuth,
              child: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _isSignUp ? 'Crear Cuenta y Publicar' : 'Iniciar Sesión',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
            ),

            const SizedBox(height: 12),

            TextButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      setState(() {
                        _isSignUp = !_isSignUp;
                        _errorMessage = null;
                      });
                    },
              child: Text(
                _isSignUp
                    ? '¿Ya tienes cuenta? Inicia sesión'
                    : '¿No tienes cuenta? Regístrate aquí',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: content,
        ),
      );
    }
  }
}
