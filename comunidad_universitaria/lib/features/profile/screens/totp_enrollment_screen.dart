import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/zanate_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../shared/widgets/zanate_ui.dart';

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
  bool _isRemovingTotp = false;
  bool _isEnrolled = false;
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
      if (mounted) {
        setState(() {
          _isEnrolled = isEnrolled;
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Autenticador TOTP configurado.')),
      );
      if (widget.isRequired) widget.onEnrollmentComplete?.call();
    } catch (error) {
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _errorMessage = _friendlyError(error);
        });
      }
    }
  }

  Future<void> _removeTotp() async {
    final codeController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: ZanateColors.card(isDark),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: ZanateColors.border(isDark)),
        ),
        title: Text(
          'Desactivar autenticación TOTP',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            color: ZanateColors.textPrimary(isDark),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Para confirmar, ingresa el código actual de tu app autenticadora. '
              'Al desactivarlo se cerrará tu sesión y tendrás que configurarlo '
              'de nuevo al iniciar sesión.',
              style: TextStyle(
                color: ZanateColors.textSecondary(isDark),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(color: ZanateColors.textPrimary(isDark)),
              decoration: zanateInputDecoration(
                isDark: isDark,
                labelText: 'Código TOTP actual',
              ).copyWith(counterText: ''),
            ),
          ],
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: ZanateColors.textMuted(isDark),
            ),
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ZanateColors.ctaBg(isDark),
              foregroundColor: ZanateColors.ctaFg(isDark),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => Navigator.pop(dialogContext, codeController.text),
            child: const Text(
              'Verificar y desactivar',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
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
    final isDark = theme.brightness == Brightness.dark;
    final enrollment = _enrollment;
    final totp = enrollment?.totp;
    final bgColor = ZanateColors.bg(isDark);
    final cardColor = ZanateColors.card(isDark);
    final borderColor = ZanateColors.border(isDark);
    final textPrimary = ZanateColors.textPrimary(isDark);
    final textSecondary = ZanateColors.textSecondary(isDark);
    final textMuted = ZanateColors.textMuted(isDark);

    return PopScope(
      canPop: !widget.isRequired,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: bgColor,
          surfaceTintColor: Colors.transparent,
          centerTitle: true,
          automaticallyImplyLeading: !widget.isRequired,
          leading: widget.isRequired
              ? null
              : IconButton(
                  icon: Icon(
                    PhosphorIconsBold.caretLeft,
                    size: 22,
                    color: textPrimary,
                  ),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
          title: Text(
            'Autenticación en dos pasos',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: textPrimary,
            ),
          ),
          actions: widget.isRequired
              ? [
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: textMuted,
                    ),
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
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: ZanateColors.zanateEyeYellow.withValues(
                          alpha: 0.22,
                        ),
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
                    'Configura un autenticador',
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
                    'Vincula una app autenticadora a tu cuenta. Los códigos se generan en tu dispositivo y cambian periódicamente.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_errorMessage != null) ...[
                    _ErrorMessage(message: _errorMessage!),
                    const SizedBox(height: 16),
                  ],
                  if (_isLoading)
                    Center(
                      child: CircularProgressIndicator(
                        color: isDark
                            ? ZanateColors.zanateEyeYellow
                            : ZanateColors.zanateBlack,
                      ),
                    )
                  else if (_isEnrolled)
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: borderColor, width: 1.2),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            PhosphorIconsFill.sealCheck,
                            color: Color(0xFF10B981),
                            size: 38,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Autenticador configurado',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tu cuenta ya tiene un autenticador TOTP verificado.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: textSecondary),
                          ),
                          const SizedBox(height: 16),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFDC2626),
                            ),
                            onPressed: _isRemovingTotp ? null : _removeTotp,
                            icon: _isRemovingTotp
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(PhosphorIconsRegular.trash),
                            label: const Text('Desactivar TOTP'),
                          ),
                        ],
                      ),
                    )
                  else if (enrollment == null)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ZanateColors.ctaBg(isDark),
                        foregroundColor: ZanateColors.ctaFg(isDark),
                        elevation: 0,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _isStarting ? null : _beginEnrollment,
                      icon: _isStarting
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: ZanateColors.ctaFg(isDark),
                              ),
                            )
                          : const Icon(PhosphorIconsRegular.qrCode, size: 20),
                      label: Text(
                        _isStarting
                            ? 'Preparando...'
                            : 'Comenzar configuración',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    )
                  else ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: borderColor, width: 1.2),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '1. Escanea este código con tu app autenticadora',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (totp != null)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.all(10),
                              child: QrImageView(
                                data: totp.uri,
                                version: QrVersions.auto,
                                size: 220,
                              ),
                            ),
                          const SizedBox(height: 16),
                          Text(
                            'Si no puedes escanearlo, agrega esta clave manualmente:',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: textSecondary, fontSize: 13),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: ZanateColors.surface(isDark),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderColor),
                            ),
                            child: SelectableText(
                              totp?.secret ?? '',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                color: textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _codeController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            maxLength: 6,
                            style: TextStyle(
                              color: textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: zanateInputDecoration(
                              isDark: isDark,
                              labelText: '2. Ingresa el código de la app',
                              hintText: '123456',
                              prefixIcon: Icon(
                                PhosphorIconsRegular.password,
                                size: 20,
                                color: textMuted,
                              ),
                            ).copyWith(counterText: ''),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ZanateColors.ctaBg(isDark),
                                foregroundColor: ZanateColors.ctaFg(isDark),
                                elevation: 0,
                                minimumSize: const Size.fromHeight(50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: _isVerifying
                                  ? null
                                  : _verifyEnrollment,
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
                                      'Verificar y activar',
                                      style: TextStyle(fontWeight: FontWeight.w700),
                                    ),
                            ),
                          ),
                        ],
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
