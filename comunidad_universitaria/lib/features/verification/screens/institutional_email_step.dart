import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/categories.dart';
import '../../../core/constants/zanate_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../services/ocr_service.dart';
import '../services/verification_service.dart';
import '../state/verification_controller.dart';
import '../utils/carnet_photo_validator.dart';
import '../utils/verification_validators.dart';

/// Verificación automática mediante correo institucional USAC + carné.
/// Permite autenticarse con Google OAuth o código OTP de correo institucional.
class InstitutionalEmailStep extends StatefulWidget {
  final VerificationController controller;
  final VoidCallback onSelectSupportPath;
  final VoidCallback onSuccess;
  final OcrService? ocrService;
  final Future<XFile?> Function(ImageSource source)? imagePickerFn;

  const InstitutionalEmailStep({
    super.key,
    required this.controller,
    required this.onSelectSupportPath,
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

  Uint8List? _frontBytes;
  String? _frontName;
  bool _isScanningFront = false;
  CarnetPhotoValidation? _frontValidation;
  String? _frontNotice;

  Uint8List? _backBytes;
  String? _backName;
  bool _isScanningBack = false;
  CarnetPhotoValidation? _backValidation;
  String? _backNotice;

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
      !_ocrService.isSupported ||
      ((_frontValidation?.passed ?? false) &&
          (_backValidation?.passed ?? false));

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

  /// Si el estudiante corrige el carné o la carrera, ambas caras
  /// dejan de ser válidas y deben volver a analizarse.
  void _invalidateCarnePhotoCheck() {
    if (_frontValidation != null || _backValidation != null) {
      setState(() {
        _frontValidation = null;
        _backValidation = null;
        _frontNotice = null;
        _backNotice = null;
      });
    }
  }

  void _clearCarnetSide({required bool isFront}) {
    setState(() {
      if (isFront) {
        _frontBytes = null;
        _frontName = null;
        _frontValidation = null;
        _frontNotice = null;
      } else {
        _backBytes = null;
        _backName = null;
        _backValidation = null;
        _backNotice = null;
      }
    });
  }

  /// Captura/elige una cara del carné y la analiza localmente (OCR + QR).
  /// Las imágenes solo viven en memoria; no se suben ni se guardan.
  Future<void> _pickCarneSide(
    ImageSource source, {
    required bool isFront,
  }) async {
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
        if (isFront) {
          _frontBytes = bytes;
          _frontName = file.name;
          _frontValidation = null;
          _frontNotice = null;
        } else {
          _backBytes = bytes;
          _backName = file.name;
          _backValidation = null;
          _backNotice = null;
        }
        _inlineError = null;
      });

      if (!_ocrService.isSupported) {
        setState(() {
          if (isFront) {
            _frontNotice =
                'La verificación local no está disponible en este dispositivo. La foto se mantiene solo en memoria.';
          } else {
            _backNotice =
                'La verificación local no está disponible en este dispositivo. La foto se mantiene solo en memoria.';
          }
        });
        return;
      }

      setState(() {
        if (isFront) {
          _isScanningFront = true;
        } else {
          _isScanningBack = true;
        }
      });

      try {
        final result = await _ocrService.scanDocument(file.path);
        final carne = _carneController.text.trim();
        final validation = isFront
            ? CarnetPhotoValidator.validateFront(
                ocrText: result.text,
                qrUrl: result.qrUrl,
                carne: carne,
                carreraNombre: _findCarrera(_selectedCarreraId)?['nombre'],
                facultadNombre: _selectedFacultadNombre,
              )
            : CarnetPhotoValidator.validateBack(
                ocrText: result.text,
                qrUrl: result.qrUrl,
                expectedCarne: carne,
              );
        if (!mounted) return;
        setState(() {
          if (isFront) {
            _frontValidation = validation;
            _frontNotice = result.message;
          } else {
            _backValidation = validation;
            _backNotice = result.message;
          }
        });
      } catch (e) {
        if (mounted) {
          setState(() {
            if (isFront) {
              _frontNotice =
                  'No se pudo analizar el frente del carné. Inténtalo de nuevo con mejor luz.';
            } else {
              _backNotice =
                  'No se pudo analizar el reverso del carné. Inténtalo de nuevo con mejor luz.';
            }
          });
        }
      } finally {
        if (mounted) {
          setState(() {
            if (isFront) {
              _isScanningFront = false;
            } else {
              _isScanningBack = false;
            }
          });
        }
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
            'Adjunta el frente y el reverso de tu carné y espera la verificación local antes de continuar.';
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
            'Adjunta el frente y el reverso de tu carné y espera la verificación local antes de enviar el código.';
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
            'El dominio "$email" no es reconocido como institucional USAC (@usac.edu.gt, etc.). Puedes contactar con soporte.';
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
              'Hemos enviado un código a $email. Si no lo recibes, revisa spam o inicia con Google.';
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
      setState(() => _inlineError = 'Ingresa el código completo de 6 dígitos.');
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
      final ok = await widget.controller.claimCredentials(
        carne: carne,
      );

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
              'Tu carné fue registrado, pero tu correo no fue reconocido como institucional. Usa Contactar con soporte para revisar tu caso.';
        });
      }
    } finally {
      _isClaiming = false;
    }
  }

  /// Sección de las dos caras del carné + verificación local de coherencia.
  Widget _buildCarnePhotoSection(bool isDark) {
    final textPrimary = ZanateColors.textPrimary(isDark);
    final infoNoticeColor =
        isDark ? const Color(0xFFFDE68A) : const Color(0xFF334155);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              PhosphorIconsRegular.camera,
              size: 20,
              color: textPrimary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Fotos del carné',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                  color: textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (!_ocrService.isSupported)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: ZanateColors.zanateEyeYellow
                  .withValues(alpha: isDark ? 0.16 : 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  PhosphorIconsFill.info,
                  color: isDark
                      ? ZanateColors.zanateEyeYellow
                      : const Color(0xFFB45309),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'La validación local del carné solo aplica en móvil. Aquí puedes usar tu correo institucional.',
                    style: TextStyle(fontSize: 12, color: infoNoticeColor),
                  ),
                ),
              ],
            ),
          )
        else ...[
          _buildCarnetSideCard(
            isDark: isDark,
            title: 'Frente del carné',
            bytes: _frontBytes,
            fileName: _frontName,
            isScanning: _isScanningFront,
            validation: _frontValidation,
            notice: _frontNotice,
            cameraKey: const Key('carnet_front_camera'),
            galleryKey: const Key('carnet_front_gallery'),
            onCamera: () => _pickCarneSide(ImageSource.camera, isFront: true),
            onGallery: () => _pickCarneSide(ImageSource.gallery, isFront: true),
            onClear: () => _clearCarnetSide(isFront: true),
          ),
          const SizedBox(height: 14),
          _buildCarnetSideCard(
            isDark: isDark,
            title: 'Reverso del carné',
            bytes: _backBytes,
            fileName: _backName,
            isScanning: _isScanningBack,
            validation: _backValidation,
            notice: _backNotice,
            cameraKey: const Key('carnet_back_camera'),
            galleryKey: const Key('carnet_back_gallery'),
            onCamera: () => _pickCarneSide(ImageSource.camera, isFront: false),
            onGallery: () => _pickCarneSide(ImageSource.gallery, isFront: false),
            onClear: () => _clearCarnetSide(isFront: false),
          ),
        ],
      ],
    );
  }

  Widget _buildCarnetSideCard({
    required bool isDark,
    required String title,
    String? subtitle,
    required Uint8List? bytes,
    required String? fileName,
    required bool isScanning,
    required CarnetPhotoValidation? validation,
    required String? notice,
    required Key cameraKey,
    required Key galleryKey,
    required VoidCallback onCamera,
    required VoidCallback onGallery,
    required VoidCallback onClear,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ZanateColors.card(isDark),
        border: Border.all(
          color: ZanateColors.border(isDark),
          width: 1.2,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                ),
              ),
              if (bytes != null)
                TextButton(
                  onPressed: isScanning ? null : onClear,
                  child: const Text('Quitar', style: TextStyle(fontSize: 11)),
                ),
            ],
          ),
          if (subtitle != null && subtitle.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                height: 1.3,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (bytes != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                bytes,
                height: 130,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            if (fileName != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  fileName,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: cameraKey,
                  onPressed: isScanning ? null : onCamera,
                  icon: const Icon(PhosphorIconsRegular.camera, size: 18),
                  label: const Text('Tomar foto'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  key: galleryKey,
                  onPressed: isScanning ? null : onGallery,
                  icon: const Icon(PhosphorIconsRegular.images, size: 18),
                  label: const Text('Galería'),
                ),
              ),
            ],
          ),
          if (isScanning) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Analizando el carné en el dispositivo...',
                    style: TextStyle(
                      fontSize: 12,
                      color: ZanateColors.textSecondary(isDark),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (notice != null) ...[
            const SizedBox(height: 8),
            Text(
              notice,
              style: TextStyle(
                fontSize: 11.5,
                color: isDark
                    ? const Color(0xFFFBBF24)
                    : const Color(0xFFB45309),
              ),
            ),
          ],
          if (validation != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: validation.passed
                    ? (isDark
                        ? const Color(0xFF14301F)
                        : const Color(0xFFECFDF5))
                    : (isDark
                        ? const Color(0xFF3F1616)
                        : const Color(0xFFFEF2F2)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: validation.passed
                      ? const Color(0xFF10B981)
                      : (isDark
                          ? const Color(0xFF991B1B)
                          : const Color(0xFFEF4444)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    validation.passed
                        ? 'Verificación local aprobada'
                        : 'Revisa la foto de tu carné',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                      color: validation.passed
                          ? (isDark
                              ? const Color(0xFF34D399)
                              : const Color(0xFF059669))
                          : (isDark
                              ? const Color(0xFFFCA5A5)
                              : const Color(0xFFB91C1C)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...validation.items.map((item) {
                    final color = item.level == CarnetCheckLevel.ok
                        ? (isDark
                            ? const Color(0xFF34D399)
                            : const Color(0xFF059669))
                        : item.level == CarnetCheckLevel.warning
                            ? (isDark
                                ? const Color(0xFFFBBF24)
                                : const Color(0xFFB45309))
                            : (isDark
                                ? const Color(0xFFFCA5A5)
                                : const Color(0xFFB91C1C));
                    final icon = item.level == CarnetCheckLevel.ok
                        ? PhosphorIconsRegular.checkCircle
                        : item.level == CarnetCheckLevel.warning
                            ? PhosphorIconsRegular.warning
                            : PhosphorIconsRegular.warningCircle;
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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = ZanateColors.textPrimary(isDark);
    final textSecondary = ZanateColors.textSecondary(isDark);
    final textMuted = ZanateColors.textMuted(isDark);
    final borderColor = ZanateColors.border(isDark);
    final focusColor = ZanateColors.focusBorder(isDark);
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: borderColor, width: 1.2),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: focusColor, width: 1.6),
    );
    final errorBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: isDark ? const Color(0xFFF87171) : const Color(0xFFEF4444),
        width: 1.2,
      ),
    );
    InputDecoration zanateInput({
      required String labelText,
      String? hintText,
      Widget? prefixIcon,
      String? counterText,
    }) {
      return InputDecoration(
        labelText: labelText,
        hintText: hintText,
        counterText: counterText,
        prefixIcon: prefixIcon,
        filled: true,
        fillColor: ZanateColors.surface(isDark),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        labelStyle: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
          color: textMuted,
        ),
        floatingLabelStyle: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: focusColor,
        ),
        hintStyle: TextStyle(
          fontSize: 13.5,
          color: textMuted,
        ),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: focusedBorder,
        errorBorder: errorBorder,
        focusedErrorBorder: errorBorder,
      );
    }

    return ColoredBox(
      color: ZanateColors.bg(isDark),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Valida tu cuenta',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ZanateColors.zanateEyeYellow,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Valida tu correo institucional y tu carné USAC.',
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 18),

              // Campo Carné
              TextFormField(
                controller: _carneController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                maxLength: 9,
                style: TextStyle(color: textPrimary),
                decoration: zanateInput(
                  labelText: 'Número de Carné USAC (9 dígitos)',
                  hintText: 'Ej. 201901234',
                  prefixIcon: Icon(
                    PhosphorIconsRegular.identificationCard,
                    color: textSecondary,
                  ),
                  counterText: '',
                ),
                validator: VerificationValidators.validateCarne,
                onChanged: (_) => _invalidateCarnePhotoCheck(),
              ),
              const SizedBox(height: 14),

              // Dropdown de Carrera
              if (_loadingCarreras)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(color: focusColor),
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _selectedCarreraId,
                  isExpanded: true,
                  dropdownColor: ZanateColors.card(isDark),
                  borderRadius: BorderRadius.circular(14),
                  style: TextStyle(color: textPrimary, fontSize: 13.5),
                  decoration: zanateInput(
                    labelText: 'Carrera Universitaria',
                    prefixIcon: Icon(
                      PhosphorIconsRegular.graduationCap,
                      color: textSecondary,
                    ),
                  ),
                  items: _carreras.map((c) {
                    return DropdownMenuItem<String>(
                      value: c['id'],
                      child: Text(
                        c['nombre'] ?? '',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: textPrimary),
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
                  backgroundColor: ZanateColors.zanateEyeYellow,
                  foregroundColor: ZanateColors.zanateBlack,
                  elevation: 0,
                  minimumSize: const Size.fromHeight(52),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed:
                    (_isBusy || !_canRequestEmail) ? null : _handleGoogleSignIn,
                icon: const Icon(PhosphorIconsBold.signIn, size: 20),
                label: const Text(
                  'Continuar con Google Institucional',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                ),
              ),
            const SizedBox(height: 16),

            // Separador
            Row(
              children: [
                Expanded(child: Divider(color: borderColor)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'o mediante código',
                    style: TextStyle(
                      fontSize: 12,
                      color: textMuted,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: borderColor)),
              ],
            ),
            const SizedBox(height: 16),

            // Aviso de sesión anónima
            if (SupabaseService.currentUser?.isAnonymous == true) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: ZanateColors.zanateEyeYellow
                      .withValues(alpha: isDark ? 0.16 : 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      PhosphorIconsFill.info,
                      color: isDark
                          ? ZanateColors.zanateEyeYellow
                          : const Color(0xFFB45309),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tu sesión actual es anónima. Al verificar tu correo, se migrará a tu cuenta real.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? const Color(0xFFFDE68A)
                              : const Color(0xFF334155),
                        ),
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
              textInputAction:
                  _otpSent ? TextInputAction.next : TextInputAction.done,
              style: TextStyle(color: textPrimary),
              decoration: zanateInput(
                labelText: 'Correo Institucional USAC',
                hintText: 'estudiante@ingenieria.usac.edu.gt',
                prefixIcon: Icon(
                  PhosphorIconsRegular.envelopeSimple,
                  color: textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Botón enviar OTP
            if (!_otpSent)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: textPrimary,
                  backgroundColor: ZanateColors.surface(isDark),
                  side: BorderSide(color: borderColor, width: 1.3),
                  minimumSize: const Size.fromHeight(50),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed:
                    (_isBusy || !_canRequestEmail) ? null : _handleSendOtp,
                icon: const Icon(PhosphorIconsRegular.paperPlaneTilt, size: 18),
                label: const Text(
                  'Enviar código',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),

            // Campo OTP si ya fue enviado
            if (_otpSent) ...[
              if (_otpInfoMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    _otpInfoMessage!,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                ),
              TextFormField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                style: TextStyle(color: textPrimary),
                decoration: zanateInput(
                  labelText: 'Código de 6 dígitos',
                  hintText: '123456',
                  prefixIcon: Icon(
                    PhosphorIconsRegular.lockKey,
                    color: textSecondary,
                  ),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size.fromHeight(50),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed:
                    (_isBusy || !_canRequestEmail) ? null : _handleVerifyOtp,
                child: _isBusy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF3F1616)
                      : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF991B1B)
                        : const Color(0xFFFCA5A5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _inlineError!,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark
                            ? const Color(0xFFFCA5A5)
                            : const Color(0xFFB91C1C),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextButton.icon(
                      onPressed: widget.onSelectSupportPath,
                      style: TextButton.styleFrom(
                        foregroundColor: isDark
                            ? const Color(0xFFFCA5A5)
                            : const Color(0xFFB91C1C),
                      ),
                      icon: const Icon(PhosphorIconsRegular.headset, size: 16),
                      label: const Text(
                        'Contactar con soporte',
                        style: TextStyle(fontSize: 12),
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
    );
  }
}
