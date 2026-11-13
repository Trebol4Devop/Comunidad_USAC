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
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSignUp = false;
  bool _isLoading = false;
  bool _isEmailLoading = false;
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

  String _friendlyAuthError(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('email not confirmed') ||
        message.contains('email_not_confirmed')) {
      return 'Esta cuenta requiere confirmar el correo antes de iniciar sesión.';
    }
    if (message.contains('invalid login credentials') ||
        message.contains('invalid_credentials')) {
      return 'Correo o contraseña incorrectos.';
    }
    if (message.contains('weak password') ||
        message.contains('password should')) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }
    if (message.contains('already registered') ||
        message.contains('user already exists')) {
      return 'Ese correo ya tiene una cuenta. Inicia sesión.';
    }
    if (message.contains('rate limit') || message.contains('too many')) {
      return 'Se alcanzó el límite de intentos. Espera un momento e inténtalo de nuevo.';
    }
    if (message.contains('network') ||
        message.contains('socket') ||
        message.contains('timeout')) {
      return 'No hay conexión estable. Comprueba tu internet e inténtalo de nuevo.';
    }
    return 'No se pudo completar la autenticación. Revisa tus datos e inténtalo de nuevo.';
  }

  Future<void> _handleEmailAuth() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isEmailLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      if (_isSignUp) {
        final response = await SupabaseService.signUp(
          email: email,
          password: password,
        );
        if (response == null) {
          throw StateError(
            'Supabase no está configurado para registrar cuentas.',
          );
        }
        if (!mounted) return;
        if (response.session == null) {
          setState(() {
            _isEmailLoading = false;
            _errorMessage =
                'La cuenta se creó, pero la configuración de Supabase requiere confirmar el correo antes de entrar.';
          });
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cuenta creada con éxito.')),
        );
      } else {
        final userId = await SupabaseService.signInWithPassword(
          email: email,
          password: password,
        );
        if (userId == null) {
          throw StateError('Supabase no está configurado para iniciar sesión.');
        }
      }

      if (!mounted) return;
      setState(() => _isEmailLoading = false);
      Navigator.of(context).pop();
      widget.onAuthenticated();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isEmailLoading = false;
        _errorMessage = _friendlyAuthError(error);
      });
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
    final isBusy = _isLoading || _isEmailLoading || _waitingForGoogle;

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
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
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
              enabled: !isBusy,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
                prefixIcon: Icon(Icons.email_outlined, size: 18),
              ),
              validator: (value) {
                final email = value?.trim() ?? '';
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                  return 'Ingresa un correo válido.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              enabled: !isBusy,
              obscureText: true,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: isBusy ? null : (_) => _handleEmailAuth(),
              decoration: const InputDecoration(
                labelText: 'Contraseña',
                prefixIcon: Icon(Icons.lock_outline, size: 18),
              ),
              validator: (value) {
                if ((value ?? '').length < 6) {
                  return 'La contraseña debe tener al menos 6 caracteres.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: isDark ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
              ),
              onPressed: isBusy ? null : _handleEmailAuth,
              child: _isEmailLoading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: isDark ? Colors.black : Colors.white,
                      ),
                    )
                  : Text(
                      _isSignUp ? 'Crear cuenta' : 'Iniciar sesión',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
            TextButton(
              onPressed: isBusy
                  ? null
                  : () => setState(() {
                      _isSignUp = !_isSignUp;
                      _errorMessage = null;
                    }),
              child: Text(
                _isSignUp
                    ? '¿Ya tienes cuenta? Inicia sesión'
                    : '¿No tienes cuenta? Regístrate',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'TOTP no se solicitará al iniciar sesión por ahora.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
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
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: content,
        ),
      );
    }
  }
}
