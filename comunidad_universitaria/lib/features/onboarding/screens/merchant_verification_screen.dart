import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../core/constants/zanate_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../verification/services/merchant_verification_service.dart';
import '../../verification/services/ocr_service.dart';
import '../../verification/state/verification_controller.dart';
import '../../verification/utils/verification_validators.dart';
import '../../verification/widgets/verification_gate.dart';
import '../state/session_controller.dart';
import 'auth_gateway_screen.dart';

/// Pantalla de solicitud de verificación para comerciantes del campus USAC.
/// Requiere sesión autenticada real, tres fotografías obligatorias (DPI frente,
/// DPI reverso, foto del establecimiento en el campus) y datos comerciales.
///
/// Especificación normativa: docs/verification/merchant-contract.md §1.3, §3.1, §4.1.
class MerchantVerificationScreen extends StatefulWidget {
  final VerificationController? verificationController;
  final SessionController? sessionController;
  final MerchantVerificationService? service;
  final OcrService? ocrService;
  final Future<XFile?> Function(ImageSource source)? imagePickerFn;

  const MerchantVerificationScreen({
    super.key,
    this.verificationController,
    this.sessionController,
    this.service,
    this.ocrService,
    this.imagePickerFn,
  });

  @override
  State<MerchantVerificationScreen> createState() =>
      _MerchantVerificationScreenState();
}

class _MerchantVerificationScreenState
    extends State<MerchantVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _dpiController = TextEditingController();
  final _establishmentNoteController = TextEditingController();

  late final MerchantVerificationService _merchantService;
  late final OcrService _ocrService;
  final ImagePicker _defaultPicker = ImagePicker();

  Uint8List? _dpiFrontBytes;
  String? _dpiFrontFileName;

  Uint8List? _dpiBackBytes;
  String? _dpiBackFileName;

  Uint8List? _establishmentBytes;
  String? _establishmentFileName;

  bool _isSubmitting = false;
  bool _isOcrScanning = false;
  String? _submissionError;
  String? _ocrNotice;

  @override
  void initState() {
    super.initState();
    _merchantService = widget.service ?? MerchantVerificationService();
    _ocrService = widget.ocrService ?? OcrService();
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _dpiController.dispose();
    _establishmentNoteController.dispose();
    _ocrService.dispose();
    super.dispose();
  }

  /// Verifica si la sesión actual es real y no anónima.
  bool get _isRealSession {
    final sCtrl =
        widget.sessionController ?? SessionController.maybeOf(context);
    if (sCtrl != null) {
      if (sCtrl.isAuthenticated && sCtrl.currentUser != null) {
        return !sCtrl.currentUser!.isAnonymous;
      }
      return false;
    }
    return SupabaseService.isAuthenticated &&
        !(SupabaseService.currentUser?.isAnonymous ?? true);
  }

  Future<void> _pickImage(
    ImageSource source, {
    required int docIndex, // 0: frente, 1: reverso, 2: establecimiento
  }) async {
    try {
      XFile? file;
      if (widget.imagePickerFn != null) {
        file = await widget.imagePickerFn!(source);
      } else {
        file = await _defaultPicker.pickImage(
          source: source,
          maxWidth: 2048,
          maxHeight: 2048,
          imageQuality: 88,
        );
      }

      if (file == null) return;

      final bytes = await file.readAsBytes();
      final name = file.name;

      setState(() {
        _submissionError = null;
        if (docIndex == 0) {
          _dpiFrontBytes = bytes;
          _dpiFrontFileName = name;
        } else if (docIndex == 1) {
          _dpiBackBytes = bytes;
          _dpiBackFileName = name;
        } else {
          _establishmentBytes = bytes;
          _establishmentFileName = name;
        }
      });

      // Si es el frente de DPI, intentar OCR inteligente en plataformas móviles soportadas
      if (docIndex == 0) {
        await _runOcrDpiExtraction(file.path);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submissionError = 'No se pudo seleccionar la imagen: $e';
        });
      }
    }
  }

  Future<void> _runOcrDpiExtraction(String filePath) async {
    if (!_ocrService.isSupported) {
      if (mounted) {
        setState(() {
          _ocrNotice =
              'El escaneo automático de DPI no está disponible en este dispositivo; ingresa el número manualmente.';
        });
      }
      return;
    }

    setState(() => _isOcrScanning = true);
    try {
      final res = await _ocrService.scanDocument(filePath);
      if (mounted && res.text.isNotEmpty && _dpiController.text.trim().isEmpty) {
        final match = VerificationValidators.cuiPattern.firstMatch(res.text);
        if (match != null) {
          _dpiController.text = match.group(0)!;
        }
      }
    } catch (e) {
      debugPrint('[MerchantVerification] Fallo en OCR prellenado: $e');
    } finally {
      if (mounted) setState(() => _isOcrScanning = false);
    }
  }

  bool get _hasAllPhotos =>
      _dpiFrontBytes != null &&
      _dpiBackBytes != null &&
      _establishmentBytes != null;

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_hasAllPhotos) {
      setState(() {
        _submissionError =
            'Debes adjuntar las 3 fotografías obligatorias para continuar.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submissionError = null;
    });

    final businessName = _businessNameController.text.trim();
    final dpiNumber = _dpiController.text.trim();
    final note = _establishmentNoteController.text.trim().isNotEmpty
        ? _establishmentNoteController.text.trim()
        : null;

    try {
      final result = await _merchantService.submitMerchantVerification(
        dpiFront: _dpiFrontBytes!,
        dpiBack: _dpiBackBytes!,
        establishment: _establishmentBytes!,
        businessName: businessName,
        dpiNumber: dpiNumber,
        establishmentNote: note,
      );

      if (!mounted) return;

      if (result.isSuccess || result.isManualReview) {
        final ctrl = widget.verificationController ??
            VerificationGate.maybeOf(context);
        ctrl?.markMerchantPending();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: ZanateColors.zanateAccent,
            content: Text(
              'Solicitud de comerciante enviada. Tu cuenta entrará en revisión manual.',
            ),
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _submissionError = result.message ??
              'Error al procesar la solicitud (${result.code ?? 'desconocido'}).';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submissionError =
              'Ocurrió un error inesperado de red al enviar la solicitud. Por favor intenta de nuevo.';
        });
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildPhotoSelector({
    required String title,
    required String description,
    required Uint8List? bytes,
    required String? fileName,
    required int docIndex,
    required bool isDark,
  }) {
    final hasFile = bytes != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.zero,
        border: Border.all(
          color: hasFile
              ? (isDark ? const Color(0xFF10B981) : const Color(0xFF059669))
              : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
          width: hasFile ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasFile
                    ? PhosphorIconsRegular.checkCircle
                    : PhosphorIconsRegular.camera,
                color: hasFile
                    ? const Color(0xFF10B981)
                    : (isDark ? Colors.grey.shade400 : const Color(0xFF475569)),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (hasFile)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withAlpha(30),
                  ),
                  child: const Text(
                    'Adjunta',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 12),
          if (hasFile) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.zero,
                    child: Image.memory(
                      bytes,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.insert_drive_file,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fileName ?? 'imagen.jpg',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${(bytes.lengthInBytes / (1024 * 1024)).toStringAsFixed(2)} MB',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? Colors.grey.shade500
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: 'Quitar foto',
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            setState(() {
                              if (docIndex == 0) {
                                _dpiFrontBytes = null;
                                _dpiFrontFileName = null;
                              } else if (docIndex == 1) {
                                _dpiBackBytes = null;
                                _dpiBackFileName = null;
                              } else {
                                _establishmentBytes = null;
                                _establishmentFileName = null;
                              }
                            });
                          },
                  ),
                ],
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    onPressed: _isSubmitting
                        ? null
                        : () => _pickImage(ImageSource.camera, docIndex: docIndex),
                    icon: const Icon(Icons.camera_alt_outlined, size: 18),
                    label: const Text('Cámara', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    onPressed: _isSubmitting
                        ? null
                        : () => _pickImage(ImageSource.gallery, docIndex: docIndex),
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: const Text('Galería', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUnauthenticatedPrompt(BuildContext context, bool isDark) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                PhosphorIconsRegular.lockKey,
                size: 48,
                color: ZanateColors.zanateAccent,
              ),
              const SizedBox(height: 16),
              const Text(
                'Sesión requerida para verificación',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Para registrar un establecimiento comercial en el campus y solicitar aprobación, debes iniciar sesión con una cuenta real de Google. Las sesiones de invitado no pueden enviar solicitudes.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ZanateColors.zanateAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                onPressed: () async {
                  await AuthGatewayScreen.show(
                    context,
                    verificationController: widget.verificationController,
                    sessionController: widget.sessionController,
                  );
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.login),
                label: const Text(
                  'Iniciar sesión con Google',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Verificación de Comerciante',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Regresar',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: !_isRealSession
            ? Padding(
                padding: const EdgeInsets.all(20),
                child: _buildUnauthenticatedPrompt(context, isDark),
              )
            : AbsorbPointer(
                absorbing: _isSubmitting,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Encabezado descriptivo
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1E293B)
                                    : const Color(0xFFF1F5F9),
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF334155)
                                      : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    PhosphorIconsRegular.storefront,
                                    color: Color(0xFFD97706),
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Registro de Comercio en el Campus',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Toda solicitud pasa por revisión manual del equipo administrativo antes de habilitar publicaciones.',
                                          style: TextStyle(
                                            fontSize: 12,
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
                            ),
                            const SizedBox(height: 20),

                            // Campo 1: Nombre del negocio
                            TextFormField(
                              controller: _businessNameController,
                              textCapitalization: TextCapitalization.words,
                              maxLength: 80,
                              decoration: const InputDecoration(
                                labelText: 'Nombre del negocio *',
                                hintText: 'Ej. Café Los Arcos, Impresiones T-3',
                                prefixIcon: Icon(PhosphorIconsRegular.buildings),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.zero,
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Ingresa el nombre del negocio.';
                                }
                                final clean = val.trim();
                                if (clean.length < 2 || clean.length > 80) {
                                  return 'El nombre del negocio debe tener entre 2 y 80 caracteres.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            // Campo 2: DPI (13 dígitos)
                            TextFormField(
                              controller: _dpiController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(13),
                              ],
                              maxLength: 13,
                              decoration: InputDecoration(
                                labelText: 'Número de DPI (13 dígitos) *',
                                hintText: 'Ej. 2501123450101',
                                prefixIcon: const Icon(PhosphorIconsRegular.identificationCard),
                                border: const OutlineInputBorder(
                                  borderRadius: BorderRadius.zero,
                                ),
                                helperText: _isOcrScanning
                                    ? 'Extrayendo DPI con OCR inteligente...'
                                    : null,
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Ingresa tu número de DPI.';
                                }
                                final clean = val.trim();
                                if (clean.length != 13 ||
                                    !VerificationValidators.cuiPattern
                                        .hasMatch(clean)) {
                                  return 'El DPI debe tener 13 dígitos y un código departamental válido (01-22).';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            // Campo 3: Nota de ubicación (opcional)
                            TextFormField(
                              controller: _establishmentNoteController,
                              maxLength: 160,
                              decoration: const InputDecoration(
                                labelText: 'Nota de ubicación en el campus (opcional)',
                                hintText: 'Ej. Frente a Ingeniería, pasillo T-3',
                                prefixIcon: Icon(PhosphorIconsRegular.mapPin),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.zero,
                                ),
                              ),
                              validator: (val) {
                                if (val != null && val.trim().length > 160) {
                                  return 'La nota de ubicación no debe superar los 160 caracteres.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Sección de 3 fotos obligatorias
                            Text(
                              'Documentación requerida (3 fotografías obligatorias):',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Foto 1: DPI Frente
                            _buildPhotoSelector(
                              title: '1. DPI — Frente',
                              description:
                                  'Fotografía nítida del frente de tu documento de identidad.',
                              bytes: _dpiFrontBytes,
                              fileName: _dpiFrontFileName,
                              docIndex: 0,
                              isDark: isDark,
                            ),

                            // Foto 2: DPI Reverso
                            _buildPhotoSelector(
                              title: '2. DPI — Reverso',
                              description:
                                  'Fotografía nítida de la parte posterior de tu DPI.',
                              bytes: _dpiBackBytes,
                              fileName: _dpiBackFileName,
                              docIndex: 1,
                              isDark: isDark,
                            ),

                            // Foto 3: Establecimiento en el campus
                            _buildPhotoSelector(
                              title: '3. Establecimiento en el campus',
                              description:
                                  'Fotografía del local, puesto o puesto móvil dentro del campus USAC.',
                              bytes: _establishmentBytes,
                              fileName: _establishmentFileName,
                              docIndex: 2,
                              isDark: isDark,
                            ),

                            // Aviso de OCR
                            if (_ocrNotice != null) ...[
                              Container(
                                padding: const EdgeInsets.all(10),
                                margin: const EdgeInsets.only(bottom: 14),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF1E293B)
                                      : const Color(0xFFF1F5F9),
                                  border: Border.all(
                                    color: isDark
                                        ? const Color(0xFF334155)
                                        : const Color(0xFFCBD5E1),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.info_outline,
                                      size: 16,
                                      color: ZanateColors.zanateAccent,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _ocrNotice!,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: ZanateColors.zanateAccent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // Aviso de privacidad
                            Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 18),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFFF8FAFC),
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF334155)
                                      : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    PhosphorIconsRegular.shieldCheck,
                                    size: 20,
                                    color: Color(0xFF10B981),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Tus documentos se guardan de forma privada y se eliminan después de la revisión.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? Colors.grey.shade300
                                            : const Color(0xFF334155),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Error de envío si existe
                            if (_submissionError != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 18),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF451A1A)
                                      : const Color(0xFFFEF2F2),
                                  border: Border.all(
                                    color: isDark
                                        ? const Color(0xFF7F1D1D)
                                        : const Color(0xFFFECACA),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.error_outline,
                                      color: Color(0xFFDC2626),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _submissionError!,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: isDark
                                              ? Colors.white
                                              : const Color(0xFF991B1B),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // Botón de Envío
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: ZanateColors.zanateAccent,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  elevation: 0,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.zero,
                                  ),
                                ),
                                onPressed: (_isSubmitting || !_hasAllPhotos)
                                    ? null
                                    : _handleSubmit,
                                child: _isSubmitting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Enviar Solicitud de Comerciante',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
