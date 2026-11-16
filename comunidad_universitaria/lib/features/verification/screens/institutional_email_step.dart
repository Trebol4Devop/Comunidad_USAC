import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/categories.dart';
import '../../../core/constants/zanate_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../services/ocr_service.dart';
import '../services/verification_service.dart';
import '../state/verification_controller.dart';
import '../utils/carnet_photo_validator.dart';
import '../utils/verification_validators.dart';

/// Camino A: Verificación mediante Correo Institucional USAC + Carné.
/// Permite autenticarse con Google OAuth o código OTP de correo institucional.
class InstitutionalEmailStep extends StatefulWidget {
  final VerificationController controller;
  final VoidCallback onSelectDocumentPath;
  final VoidCallback onSuccess;
  final OcrService? ocrService;
  final Future<XFile?> Function(ImageSource source)? imagePickerFn;

  const InstitutionalEmailStep({
    super.key,
    required this.controller,
    required this.onSelectDocumentPath,
    required this.onSuccess,
    this.ocrService,
    this.imagePickerFn,
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
  late final OcrService _ocrService;
  final ImagePicker _picker = ImagePicker();

  List<Map<String, String>> _carreras = [];
  String? _selectedCarreraId;
  bool _loadingCarreras = true;

  Uint8List? _carnePhotoBytes;
  String? _carnePhotoName;
  bool _isScanningCarne = false;
  CarnetPhotoValidation? _carnePhotoValidation;
  String? _carnePhotoNotice;

  bool _isBusy = false;
  bool _otpSent = false;
  String? _inlineError;
  String? _otpInfoMessage;

  StreamSubscription<AuthState>? _authSubscription;
  bool _isClaiming = false;
  String? _lastClaimKey;

  /// La verificación local del carné solo se exige donde el OCR nativo está
  /// disponible (Android/iOS). En web/desktop se mantiene el correo
  /// institucional como prueba principal.
  bool get _canRequestEmail =>
      !_ocrService.isSupported || (_carnePhotoValidation?.passed ?? false);

  @override
  void initState() {
    super.initState();
    _ocrService = widget.ocrService ?? OcrService();
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
    _ocrService.dispose();
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

  Map<String, String>? _findCarrera(String? id) {
    if (id == null) return null;
    for (final carrera in _carreras) {
      if (carrera['id'] == id) return carrera;
    }
    return null;
  }

  String? get _selectedFacultadNombre {
    final carrera = _findCarrera(_selectedCarreraId);
    final facultadId = carrera?['facultad_id'];
    if (facultadId == null) return null;
    for (final facultad in USACConstants.facultades) {
      if (facultad['id'] == facultadId) {
        return facultad['nombre']?.toString();
      }
    }
    return null;
  }

  /// Si el estudiante corrige el carné o la carrera, la foto deja de ser
  /// válida y debe volver a analizarse.
  void _invalidateCarnePhotoCheck() {
    if (_carnePhotoValidation != null) {
      setState(() {
        _carnePhotoValidation = null;
        _carnePhotoNotice = null;
      });
    }
  }

  /// Captura/elige la foto del carné y la analiza localmente (OCR + QR).
  /// La imagen solo vive en memoria; no se sube ni se guarda.
  Future<void> _pickCarnePhoto(ImageSource source) async {
    try {
      final file = widget.imagePickerFn != null
          ? await widget.imagePickerFn!(source)
          : await _picker.pickImage(
              source: source,
              maxWidth: 2048,
              maxHeight: 2048,
              imageQuality: 90,
            );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      if (!mounted) return;

      setState(() {
        _carnePhotoBytes = bytes;
        _carnePhotoName = file.name;
        _carnePhotoValidation = null;
        _carnePhotoNotice = null;
        _inlineError = null;
      });

      if (!_ocrService.isSupported) {
        setState(() {
          _carnePhotoNotice =
              'La verificación local del carné no está disponible en este dispositivo. La foto se mantiene solo en memoria.';
        });
        return;
      }

      setState(() => _isScanningCarne = true);
      try {
        final result = await _ocrService.scanDocument(file.path);
        final carrera = _findCarrera(_selectedCarreraId);
        final validation = CarnetPhotoValidator.validate(
          ocrText: result.text,
          qrUrl: result.qrUrl,
          carne: _carneController.text.trim(),
          carreraNombre: carrera?['nombre'],
          facultadNombre: _selectedFacultadNombre,
        );
        if (!mounted) return;
        setState(() {
          _carnePhotoValidation = validation;
          _carnePhotoNotice = result.message;
        });
      } catch (e) {
        if (mounted) {
          setState(() {
            _carnePhotoNotice =
                'No se pudo analizar la foto del carné. Inténtalo de nuevo con mejor luz.';
          });
        }
      } finally {
        if (mounted) setState(() => _isScanningCarne = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _inlineError = 'No se pudo cargar la foto del carné.';
        });
      }
    }
  }

  /// Inicia el flujo de autenticación con Google Workspace institucional.
  Future<void> _handleGoogleSignIn() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_canRequestEmail) {
      setState(() {
        _inlineError =
            'Adjunta una foto legible de tu carné y espera la verificación local antes de continuar.';
      });
      return;
    }

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
    if (!_canRequestEmail) {
      setState(() {
        _inlineError =
            'Adjunta una foto legible de tu carné y espera la verificación local antes de enviar el código.';
      });
      return;
    }

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

  /// Sección de foto del carné + verificación local de coherencia.
  Widget _buildCarnePhotoSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.photo_camera_outlined,
              size: 20,
              color: ZanateColors.zanateAccent,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Foto de tu carné (verificación local)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            if (_carnePhotoBytes != null)
              TextButton(
                onPressed: _isScanningCarne
                    ? null
                    : () {
                        setState(() {
                          _carnePhotoBytes = null;
                          _carnePhotoName = null;
                          _carnePhotoValidation = null;
                          _carnePhotoNotice = null;
                        });
                      },
                child: const Text('Quitar', style: TextStyle(fontSize: 11)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (!_ocrService.isSupported)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2D2415) : const Color(0xFFFEFCE8),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF78350F)
                    : const Color(0xFFFEF08A),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFFB45309), size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'La verificación local del carné solo está disponible en Android/iOS. En este dispositivo puedes continuar con tu correo institucional.',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFFB45309)),
                  ),
                ),
              ],
            ),
          )
        else ...[
          if (_carnePhotoBytes != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                _carnePhotoBytes!,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            if (_carnePhotoName != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _carnePhotoName!,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ] else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0),
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.badge_outlined,
                    size: 30,
                    color: ZanateColors.zanateAccent,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Adjunta una foto legible del frente de tu carné. Se analiza en tu dispositivo y no se envía al servidor.',
                      style: TextStyle(fontSize: 11.5, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isScanningCarne
                      ? null
                      : () => _pickCarnePhoto(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: const Text('Tomar foto'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isScanningCarne
                      ? null
                      : () => _pickCarnePhoto(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Galería'),
                ),
              ),
            ],
          ),
          if (_isScanningCarne) ...[
            const SizedBox(height: 10),
            const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Analizando el carné en el dispositivo...',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
          if (_carnePhotoNotice != null) ...[
            const SizedBox(height: 8),
            Text(
              _carnePhotoNotice!,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFFB45309)),
            ),
          ],
          if (_carnePhotoValidation != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _carnePhotoValidation!.passed
                    ? (isDark
                        ? const Color(0xFF14301F)
                        : const Color(0xFFECFDF5))
                    : (isDark
                        ? const Color(0xFF451A1A)
                        : const Color(0xFFFEF2F2)),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _carnePhotoValidation!.passed
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _carnePhotoValidation!.passed
                        ? 'Verificación local aprobada'
                        : 'Revisa la foto de tu carné',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                      color: _carnePhotoValidation!.passed
                          ? const Color(0xFF059669)
                          : const Color(0xFFB91C1C),
                    ),
                  ),
                  const SizedBox(height: 6),
                  ..._carnePhotoValidation!.items.map((item) {
                    final color = item.level == CarnetCheckLevel.ok
                        ? const Color(0xFF059669)
                        : item.level == CarnetCheckLevel.warning
                            ? const Color(0xFFB45309)
                            : const Color(0xFFB91C1C);
                    final icon = item.level == CarnetCheckLevel.ok
                        ? Icons.check_circle_outline
                        : item.level == CarnetCheckLevel.warning
                            ? Icons.warning_amber_rounded
                            : Icons.error_outline;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(icon, size: 15, color: color),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item.detail == null
                                  ? item.label
                                  : '${item.label}: ${item.detail}',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: color,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
          if (!_canRequestEmail) ...[
            const SizedBox(height: 6),
            const Text(
              'Adjunta una foto legible del carné para habilitar el correo institucional.',
              style: TextStyle(fontSize: 11, color: Color(0xFFB45309)),
            ),
          ],
        ],
      ],
    );
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
              onChanged: (_) => _invalidateCarnePhotoCheck(),
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
                onChanged: (val) {
                  setState(() => _selectedCarreraId = val);
                  _invalidateCarnePhotoCheck();
                },
              ),
            const SizedBox(height: 18),
            _buildCarnePhotoSection(isDark),
            const SizedBox(height: 20),

            // Opción 1: Google OAuth
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: ZanateColors.zanateAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: (_isBusy || !_canRequestEmail) ? null : _handleGoogleSignIn,
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
                onPressed: (_isBusy || !_canRequestEmail) ? null : _handleSendOtp,
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
                onPressed: (_isBusy || !_canRequestEmail) ? null : _handleVerifyOtp,
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
