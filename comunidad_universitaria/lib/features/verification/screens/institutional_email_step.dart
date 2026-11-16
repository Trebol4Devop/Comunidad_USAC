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
  final _cuiController = TextEditingController();
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
    _cuiController.dispose();
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

  /// Si el estudiante corrige el carné, el CUI o la carrera, ambas caras
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
        final cui = _cuiController.text.trim();
        final validation = isFront
            ? CarnetPhotoValidator.validateFront(
                ocrText: result.text,
                qrUrl: result.qrUrl,
                carne: carne,
                carreraNombre: _findCarrera(_selectedCarreraId)?['nombre'],
                facultadNombre: _selectedFacultadNombre,
                cui: cui.isEmpty ? null : cui,
              )
            : CarnetPhotoValidator.validateBack(
                ocrText: result.text,
                qrUrl: result.qrUrl,
                expectedCarne: carne,
                expectedCui: cui.isEmpty ? null : cui,
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
      final cui = _cuiController.text.trim();
      final ok = await widget.controller.claimCredentials(
        carne: carne,
        cui: cui.isEmpty ? null : cui,
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
              'Tu carné fue registrado, pero tu correo no fue reconocido como institucional automático. Puedes adjuntar tu documento para verificación por OCR o revisión manual.';
        });
      }
    } finally {
      _isClaiming = false;
    }
  }

  /// Sección de las dos caras del carné + verificación local de coherencia.
  Widget _buildCarnePhotoSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            Icon(
              Icons.photo_camera_outlined,
              size: 20,
              color: ZanateColors.zanateAccent,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Fotos del carné (verificación local)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
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
                color: isDark ? const Color(0xFF78350F) : const Color(0xFFFEF08A),
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
          _buildCarnetSideCard(
            isDark: isDark,
            title: 'Frente del carné',
            subtitle:
                'CUI, facultad, carrera, carné, "En caso de emergencia marque al 1592" y código de barras.',
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
            subtitle:
                'Nombre completo, "USAC TRICENTENARIA", "ESTUDIANTE UNIVERSITARIO" y QR de Registro y Estadística.',
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
          if (!_canRequestEmail) ...[
            const SizedBox(height: 8),
            const Text(
              'Adjunta y valida el frente y el reverso para habilitar el correo institucional.',
              style: TextStyle(fontSize: 11, color: Color(0xFFB45309)),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildCarnetSideCard({
    required bool isDark,
    required String title,
    required String subtitle,
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        borderRadius: BorderRadius.circular(8),
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
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              height: 1.3,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
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
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: const Text('Tomar foto'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  key: galleryKey,
                  onPressed: isScanning ? null : onGallery,
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Galería'),
                ),
              ),
            ],
          ),
          if (isScanning) ...[
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
          if (notice != null) ...[
            const SizedBox(height: 8),
            Text(
              notice,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFFB45309)),
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
                        ? const Color(0xFF451A1A)
                        : const Color(0xFFFEF2F2)),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: validation.passed
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444),
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
                          ? const Color(0xFF059669)
                          : const Color(0xFFB91C1C),
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...validation.items.map((item) {
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
        ],
      ),
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

            // Campo CUI opcional (aparece en el frente del carné)
            TextFormField(
              controller: _cuiController,
              keyboardType: TextInputType.number,
              maxLength: 13,
              decoration: const InputDecoration(
                labelText: 'CUI (opcional, 13 dígitos)',
                hintText: 'Ej. 1234567890101',
                prefixIcon: Icon(Icons.credit_card_outlined),
                border: OutlineInputBorder(),
                counterText: '',
              ),
              validator: VerificationValidators.validateCui,
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
