import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';

class TotpEnrollmentScreen extends StatefulWidget {
  const TotpEnrollmentScreen({
    super.key,
    this.isRequired = false,
    this.onEnrollmentComplete,
    this.onCancelRequired,
  });

  final bool isRequired;
  final VoidCallback? onEnrollmentComplete;
  final Future<void> Function()? onCancelRequired;

  @override
  State<TotpEnrollmentScreen> createState() => _TotpEnrollmentScreenState();
}

class _TotpEnrollmentScreenState extends State<TotpEnrollmentScreen> {
  final _codeController = TextEditingController();

  bool _isLoading = true;
  bool _isStarting = false;
  bool _isVerifying = false;
  bool _isGeneratingRecoveryCodes = false;
  bool _isRemovingTotp = false;
  bool _isEnrolled = false;
  int? _recoveryCodesTotal;
  int? _recoveryCodesRemaining;
  List<String>? _newRecoveryCodes;
  AuthMFAEnrollResponse? _enrollment;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadEnrollmentStatus();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadEnrollmentStatus() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final factors = await SupabaseService.listTotpFactors();
      final isEnrolled = factors.any(
        (factor) => factor.status == FactorStatus.verified,
      );
      RecoveryCodeStatus? recoveryCodeStatus;
      if (isEnrolled) {
        try {
          recoveryCodeStatus = await SupabaseService.getRecoveryCodeStatus();
        } catch (_) {
          // The TOTP factor remains usable if recovery-code status is unavailable.
        }
      }
      if (mounted) {
        setState(() {
          _isEnrolled = isEnrolled;
          _recoveryCodesTotal = recoveryCodeStatus?.total;
          _recoveryCodesRemaining = recoveryCodeStatus?.remaining;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Inicia sesión con una cuenta para configurar un autenticador.';
        });
      }
    }
  }

  Future<void> _beginEnrollment() async {
    setState(() {
      _isStarting = true;
      _errorMessage = null;
    });

    try {
      final enrollment = await SupabaseService.beginTotpEnrollment();
      if (enrollment.totp == null) {
        throw StateError('Supabase no devolvió los datos del autenticador.');
      }
      if (mounted) {
        setState(() {
          _enrollment = enrollment;
          _isStarting = false;
          _codeController.clear();
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isStarting = false;
          _errorMessage = _friendlyError(error);
        });
      }
    }
  }

  Future<void> _verifyEnrollment() async {
    final enrollment = _enrollment;
    final code = _codeController.text.trim();
    if (enrollment == null) return;

    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _errorMessage = 'Ingresa el código actual de 6 dígitos.');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      await SupabaseService.verifyTotpEnrollment(
        factorId: enrollment.id,
        code: code,
      );
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _isEnrolled = true;
        _enrollment = null;
        _codeController.clear();
      });
      await _generateRecoveryCodes();
      if (!mounted) return;
      if (_newRecoveryCodes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Autenticador TOTP configurado.')),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _errorMessage = _friendlyError(error);
        });
      }
    }
  }

  Future<void> _generateRecoveryCodes({bool regenerate = false}) async {
    setState(() {
      _isGeneratingRecoveryCodes = true;
      _errorMessage = null;
    });
    try {
      final codes = await SupabaseService.generateRecoveryCodes(
        regenerate: regenerate,
      );
      if (!mounted) return;
      setState(() {
        _newRecoveryCodes = codes;
        _recoveryCodesTotal = codes.length;
        _recoveryCodesRemaining = codes.length;
        _isGeneratingRecoveryCodes = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _isGeneratingRecoveryCodes = false;
          _errorMessage = _recoveryCodeError(error);
        });
      }
    }
  }

  String _recoveryCodeError(Object error) {
    if (error is RecoveryCodeAssuranceException) {
      final nextLevel =
          error.nextLevel == null || error.nextLevel == error.currentLevel
          ? ''
          : ' Nivel siguiente: ${error.nextLevel}.';
      return 'La sesión actual está en ${error.currentLevel}; se requiere aal2. '
          'Completa la verificación TOTP y vuelve a intentarlo.$nextLevel';
    }
    if (error is RecoveryCodeRequestException) {
      final diagnostic = error.errorCode == null
          ? ''
          : ' Código: ${error.errorCode}.';
      final explanation = switch (error.statusCode) {
        401 => 'La sesión no fue aceptada; vuelve a iniciar sesión.',
        403 =>
          'Auth rechazó la operación; verifica que la sesión esté en aal2.',
        404 || 405 =>
          'Esta versión/configuración de Supabase Auth podría no ofrecer el endpoint de códigos de recuperación.',
        429 =>
          'Se alcanzó el límite de solicitudes; espera antes de reintentar.',
        _ => 'Supabase Auth rechazó la solicitud.',
      };
      return '$explanation (HTTP ${error.statusCode}.$diagnostic) '
          'Tu autenticador TOTP sigue activo.';
    }
    return 'No se pudieron generar los códigos (${error.runtimeType}). '
        'Tu autenticador TOTP sigue activo; comprueba la sesión y vuelve a intentarlo.';
  }

  Future<void> _confirmRecoveryCodesSaved() async {
    setState(() => _newRecoveryCodes = null);
    if (widget.isRequired) widget.onEnrollmentComplete?.call();
  }

  Future<void> _manageRecoveryCodes() async {
    final shouldRegenerate = (_recoveryCodesTotal ?? 0) > 0;
    if (shouldRegenerate) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Regenerar códigos'),
          content: const Text(
            'Los códigos anteriores dejarán de funcionar. Guarda los nuevos '
            'antes de cerrar esta pantalla. ¿Deseas continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Regenerar'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    await _generateRecoveryCodes(regenerate: shouldRegenerate);
  }

  Widget _buildRecoveryCodesCard(ThemeData theme, List<String> codes) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.vpn_key_outlined,
              size: 40,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Guarda tus códigos de recuperación',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Cada código se usa una sola vez. Solo se muestran ahora; guárdalos '
              'en un lugar seguro. Regenerarlos invalida los anteriores.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SelectableText(
              codes.join('\n'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
                height: 1.8,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: codes.join('\n')));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Códigos copiados al portapapeles.'),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Copiar códigos'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _confirmRecoveryCodesSaved,
              child: const Text('Ya los guardé'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeTotp() async {
    final codeController = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Desactivar autenticación TOTP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Para confirmar, ingresa el código actual de tu app autenticadora. '
              'Al desactivarlo se cerrará tu sesión y tendrás que configurarlo '
              'de nuevo al iniciar sesión.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Código TOTP actual',
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, codeController.text),
            child: const Text('Verificar y desactivar'),
          ),
        ],
      ),
    );
    codeController.dispose();
    if (code == null || !mounted) return;

    setState(() {
      _isRemovingTotp = true;
      _errorMessage = null;
    });
    try {
      final factors = await SupabaseService.listTotpFactors();
      final verifiedFactor = factors.cast<Factor?>().firstWhere(
        (factor) => factor?.status == FactorStatus.verified,
        orElse: () => null,
      );
      if (verifiedFactor == null) {
        throw StateError('No hay un factor TOTP verificado.');
      }
      await SupabaseService.disableTotpWithCurrentCode(
        factorId: verifiedFactor.id,
        code: code,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _isRemovingTotp = false;
          _errorMessage =
              'No se pudo desactivar TOTP. Verifica el código actual e inténtalo de nuevo.';
        });
      }
    }
  }

  String _friendlyError(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('invalid') ||
        message.contains('otp') ||
        message.contains('code')) {
      return 'El código no es válido o venció. Revisa tu app autenticadora e inténtalo de nuevo.';
    }
    if (message.contains('already') || message.contains('activo')) {
      return 'Esta cuenta ya tiene un autenticador TOTP activo.';
    }
    return 'No se pudo completar la configuración. Inténtalo de nuevo.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enrollment = _enrollment;
    final totp = enrollment?.totp;

    return PopScope(
      canPop: !widget.isRequired,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !widget.isRequired,
          title: const Text('Autenticación en dos pasos'),
          actions: widget.isRequired
              ? [
                  TextButton(
                    onPressed: widget.onCancelRequired,
                    child: const Text('Cerrar sesión'),
                  ),
                ]
              : null,
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.all(24),
                shrinkWrap: true,
                children: [
                  Icon(
                    Icons.security_outlined,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Configura un autenticador',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Vincula una app autenticadora a tu cuenta. Los códigos se generan en tu dispositivo y cambian periódicamente.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  if (_errorMessage != null) ...[
                    _ErrorMessage(message: _errorMessage!),
                    const SizedBox(height: 16),
                  ],
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_newRecoveryCodes != null)
                    _buildRecoveryCodesCard(theme, _newRecoveryCodes!)
                  else if (_isEnrolled)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.verified_user_outlined,
                              color: Color(0xFF059669),
                              size: 36,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Autenticador configurado',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Tu cuenta ya tiene un autenticador TOTP verificado.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _recoveryCodesRemaining == null
                                  ? 'No se pudo consultar el estado de los códigos de recuperación.'
                                  : 'Códigos de recuperación disponibles: $_recoveryCodesRemaining de ${_recoveryCodesTotal ?? 0}',
                              textAlign: TextAlign.center,
                            ),
                            if (_recoveryCodesTotal == null) ...[
                              TextButton(
                                onPressed: _loadEnrollmentStatus,
                                child: const Text('Reintentar consulta'),
                              ),
                            ],
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed:
                                  _isGeneratingRecoveryCodes ||
                                      _isRemovingTotp ||
                                      _recoveryCodesTotal == null
                                  ? null
                                  : _manageRecoveryCodes,
                              icon: _isGeneratingRecoveryCodes
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.vpn_key_outlined),
                              label: Text(
                                _isGeneratingRecoveryCodes
                                    ? 'Generando...'
                                    : (_recoveryCodesTotal ?? 0) > 0
                                    ? 'Regenerar códigos'
                                    : 'Generar códigos de recuperación',
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextButton.icon(
                              onPressed:
                                  _isRemovingTotp || _isGeneratingRecoveryCodes
                                  ? null
                                  : _removeTotp,
                              icon: _isRemovingTotp
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.delete_outline),
                              label: const Text('Desactivar TOTP'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (enrollment == null)
                    ElevatedButton.icon(
                      onPressed: _isStarting ? null : _beginEnrollment,
                      icon: _isStarting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.qr_code_2),
                      label: Text(
                        _isStarting
                            ? 'Preparando...'
                            : 'Comenzar configuración',
                      ),
                    )
                  else ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            const Text(
                              '1. Escanea este código con tu app autenticadora',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            if (totp != null)
                              Container(
                                color: Colors.white,
                                padding: const EdgeInsets.all(8),
                                child: QrImageView(
                                  data: totp.uri,
                                  version: QrVersions.auto,
                                  size: 220,
                                ),
                              ),
                            const SizedBox(height: 16),
                            const Text(
                              'Si no puedes escanearlo, agrega esta clave manualmente:',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              totp?.secret ?? '',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _codeController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              maxLength: 6,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: const InputDecoration(
                                labelText: '2. Ingresa el código de la app',
                                hintText: '123456',
                                prefixIcon: Icon(Icons.password_outlined),
                                counterText: '',
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isVerifying
                                    ? null
                                    : _verifyEnrollment,
                                child: _isVerifying
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Verificar y activar'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message});

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
