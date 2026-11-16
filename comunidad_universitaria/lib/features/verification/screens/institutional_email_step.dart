import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/zanate_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../services/verification_service.dart';
import '../state/verification_controller.dart';
import '../utils/verification_validators.dart';

/// Camino A: Verificación mediante Correo Institucional USAC + Carné.
/// Permite autenticarse con Google OAuth o código OTP de correo institucional.
class InstitutionalEmailStep extends StatefulWidget {
  final VerificationController controller;
  final VoidCallback onSelectDocumentPath;
  final VoidCallback onSuccess;

  const InstitutionalEmailStep({
    super.key,
    required this.controller,
    required this.onSelectDocumentPath,
    required this.onSuccess,
  });

  @override
  State<InstitutionalEmailStep> createState() => _InstitutionalEmailStepState();
}

class _InstitutionalEmailStepState extends State<InstitutionalEmailStep> {
  final _formKey = GlobalKey<FormState>();
  final _carneController = TextEditingController();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();

  final VerificationService _service = VerificationService();

  List<Map<String, String>> _carreras = [];
  String? _selectedCarreraId;
  bool _loadingCarreras = true;

  bool _isBusy = false;
  bool _otpSent = false;
  String? _inlineError;
  String? _otpInfoMessage;

  StreamSubscription<AuthState>? _authSubscription;
  bool _isClaiming = false;
  String? _lastClaimKey;

  @override
  void initState() {
    super.initState();
    _loadCarreras();
    _listenForOAuthCompletion();
  }

  /// Google OAuth completa el inicio de sesión de forma asíncrona (deep link /
  /// redirect). Cuando la sesión pasa a un usuario real, vinculamos el carné
  /// que el estudiante ya escribió en el paso 1.
  void _listenForOAuthCompletion() {
    try {
      _authSubscription = SupabaseService.client.auth.onAuthStateChange.listen((
        state,
      ) {
        final user = state.session?.user;
        if (user == null || user.isAnonymous) return;
        final carne = _carneController.text.trim();
        if (carne.isEmpty) return;
        final claimKey = '${user.id}:$carne';
        if (_lastClaimKey == claimKey) return;
        _lastClaimKey = claimKey;
        _claimStudentCarne();
      });
    } catch (_) {
      // Entorno de testing o Supabase no inicializado.
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _carneController.dispose();
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _loadCarreras() async {
    try {
      final list = await _service.fetchCarreras();
      if (mounted) {
        setState(() {
          _carreras = list;
          if (list.isNotEmpty) {
            _selectedCarreraId = list.first['id'];
          }
          _loadingCarreras = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCarreras = false);
    }
  }

  /// Inicia el flujo de autenticación con Google Workspace institucional.
  Future<void> _handleGoogleSignIn() async {
    if (!_formKey.currentState!.validate()) return;

    // Si ya hay una sesión real (p. ej. OAuth completado antes), solo falta
    // vincular el carné: no hace falta relanzar el proveedor.
    if (SupabaseService.isAuthenticated) {
      setState(() {
        _isBusy = true;
        _inlineError = null;
      });
      try {
        await _claimStudentCarne();
      } finally {
        if (mounted) setState(() => _isBusy = false);
      }
      return;
    }

    setState(() {
      _isBusy = true;
      _inlineError = null;
    });

    try {
      final currentUrl = SupabaseService.oauthRedirectUrl;
      final launched = await SupabaseService.signInWithGoogle(redirectTo: currentUrl);
      if (!launched) {
        throw StateError('No se pudo abrir el proveedor de Google.');
      }

      // Al autenticarse mediante Google, procedemos a reclamar el carné
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Completando inicio de sesión con Google...'),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _inlineError = 'Error al iniciar sesión con Google. Puedes probar con código por correo.';
        });
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  /// Solicita un código OTP de 6 dígitos al correo institucional.
  Future<void> _handleSendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _inlineError = 'Ingresa un correo institucional válido.');
      return;
    }

    if (!VerificationValidators.isInstitutionalEmail(email)) {
      setState(() {
        _inlineError =
            'El dominio "$email" no es reconocido como institucional USAC (@usac.edu.gt, etc.). Puedes optar por verificación con documento.';
      });
      return;
    }

    setState(() {
      _isBusy = true;
      _inlineError = null;
    });

    try {
      await SupabaseService.client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: true,
      );

      if (mounted) {
        setState(() {
          _otpSent = true;
          _otpInfoMessage =
              'Hemos enviado un código OTP a $email. Si no lo recibes, revisa spam o inicia con Google.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _inlineError =
              'No se pudo enviar el código al correo ($e). Te recomendamos usar el botón de Google.';
        });
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  /// Valida el código OTP de 6 dígitos ingresado por el usuario.
  Future<void> _handleVerifyOtp() async {
    final token = _otpController.text.trim();
    final email = _emailController.text.trim().toLowerCase();

    if (token.length < 6) {
      setState(() => _inlineError = 'Ingresa el código OTP completo de 6 dígitos.');
      return;
    }

    setState(() {
      _isBusy = true;
      _inlineError = null;
    });

    try {
      final res = await SupabaseService.client.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.email,
      );

      if (res.user == null) {
        throw StateError('Código de verificación no válido o expirado.');
      }

      // Credenciales autenticadas: reclamar carné
      await _claimStudentCarne();
    } catch (e) {
      if (mounted) {
        setState(() {
          _inlineError = 'Código de verificación incorrecto o expirado ($e).';
        });
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  /// Reclama el carné una vez autenticado y valida el estado resultante.
  Future<void> _claimStudentCarne() async {
    if (_isClaiming) return;
    _isClaiming = true;
    try {
      final carne = _carneController.text.trim();
      final ok = await widget.controller.claimCredentials(carne: carne);

      if (!mounted) return;

      if (!ok) {
        setState(() {
          _inlineError = widget.controller.errorMessage ??
              'No se pudo vincular este carné. Contacta soporte.';
        });
        return;
      }

      // Verificar si el trigger institucional aprobó la cuenta
      await widget.controller.loadStatus();
      if (!mounted) return;

      if (widget.controller.isVerified) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF10B981),
            content: Text('¡Cuenta verificada exitosamente como estudiante USAC!'),
          ),
        );
        widget.onSuccess();
      } else {
        // El perfil no quedó verificado automáticamente (por ejemplo correo de dominio externo)
        setState(() {
          _inlineError =
              'Tu carné fue registrado, pero tu correo no fue reconocido como institucional automático. Puedes adjuntar tu documento para verificación por OCR o revisión manual.';
        });
      }
    } finally {
      _isClaiming = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Resumen del Camino A
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFBFDBFE),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.school_outlined,
                    color: ZanateColors.zanateAccent,
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Camino A: Validación automática instantánea mediante tu cuenta institucional USAC.',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: ZanateColors.zanateAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Campo Carné
            TextFormField(
              controller: _carneController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              maxLength: 9,
              decoration: const InputDecoration(
                labelText: 'Número de Carné USAC (9 dígitos)',
                hintText: 'Ej. 201901234',
                prefixIcon: Icon(Icons.badge_outlined),
                border: OutlineInputBorder(),
                counterText: '',
              ),
              validator: VerificationValidators.validateCarne,
            ),
            const SizedBox(height: 14),

            // Dropdown de Carrera
            if (_loadingCarreras)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              DropdownButtonFormField<String>(
                initialValue: _selectedCarreraId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Carrera Universitaria',
                  prefixIcon: Icon(Icons.account_balance_outlined),
                  border: OutlineInputBorder(),
                ),
                items: _carreras.map((c) {
                  return DropdownMenuItem<String>(
                    value: c['id'],
                    child: Text(
                      c['nombre'] ?? '',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedCarreraId = val),
              ),
            const SizedBox(height: 20),

            // Opción 1: Google OAuth
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: ZanateColors.zanateAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _isBusy ? null : _handleGoogleSignIn,
              icon: const Icon(Icons.login, size: 20),
              label: const Text(
                'Continuar con Google Institucional',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),

            // Separador
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'o mediante código OTP',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 16),

            // Aviso de sesión anónima
            if (SupabaseService.currentUser?.isAnonymous == true) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2D2415) : const Color(0xFFFEFCE8),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDark ? const Color(0xFF78350F) : const Color(0xFFFEF08A),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFFB45309), size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tu sesión actual es anónima. Al verificar tu correo, se migrará a tu cuenta real.',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFFB45309)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Campo Correo Institucional
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: _otpSent ? TextInputAction.next : TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Correo Institucional USAC',
                hintText: 'estudiante@ingenieria.usac.edu.gt',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),

            // Botón enviar OTP
            if (!_otpSent)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _isBusy ? null : _handleSendOtp,
                icon: const Icon(Icons.send_outlined, size: 18),
                label: const Text('Enviar código OTP por correo'),
              ),

            // Campo OTP si ya fue enviado
            if (_otpSent) ...[
              if (_otpInfoMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    _otpInfoMessage!,
                    style: const TextStyle(fontSize: 12, color: ZanateColors.zanateAccent),
                  ),
                ),
              TextFormField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Código de 6 dígitos (OTP)',
                  hintText: '123456',
                  prefixIcon: Icon(Icons.lock_clock_outlined),
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _isBusy ? null : _handleVerifyOtp,
                child: _isBusy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Confirmar código y verificar',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ],

            // Mensajes de error en línea
            if (_inlineError != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF451A1A) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA),
                  ),
                ),
                child: Text(
                  _inlineError!,
                  style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
                ),
              ),
            ],

            const SizedBox(height: 24),
            // Alternativa: ir a Camino B
            Center(
              child: TextButton.icon(
                onPressed: widget.onSelectDocumentPath,
                icon: const Icon(Icons.document_scanner_outlined, size: 18),
                label: const Text(
                  '¿No tienes correo activo? Usar verificación con documento (Camino B)',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
