import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/zanate_colors.dart';
import '../models/verification_status.dart';
import '../services/ocr_service.dart';
import '../services/verification_service.dart';
import '../state/verification_controller.dart';
import '../utils/verification_validators.dart';

/// Camino B: Verificación de documento estudiantil con OCR, QR y envío al Worker.
class DocumentVerificationScreen extends StatefulWidget {
  final VerificationController controller;
  final VoidCallback onSelectEmailPath;
  final VoidCallback onSuccess;

  const DocumentVerificationScreen({
    super.key,
    required this.controller,
    required this.onSelectEmailPath,
    required this.onSuccess,
  });

  @override
  State<DocumentVerificationScreen> createState() =>
      _DocumentVerificationScreenState();
}

class _DocumentVerificationScreenState
    extends State<DocumentVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _carneController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final OcrService _ocrService = OcrService();
  final VerificationService _verificationService = VerificationService();

  VerificationDocumentType _selectedDocType =
      VerificationDocumentType.constanciaInscripcion;

  XFile? _selectedFile;
  Uint8List? _fileBytes;
  String? _clientOcrText;
  String? _qrUrl;
  bool _isScanningOcr = false;
  bool _isSubmitting = false;
  String? _ocrNotice;
  String? _submissionError;

  @override
  void dispose() {
    _carneController.dispose();
    _ocrService.dispose();
    super.dispose();
  }

  /// Permite capturar foto con la cámara o seleccionar de la galería.
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 88,
      );

      if (file == null) return;

      final bytes = await file.readAsBytes();

      setState(() {
        _selectedFile = file;
        _fileBytes = bytes;
        _clientOcrText = null;
        _qrUrl = null;
        _submissionError = null;
        _ocrNotice = null;
      });

      // Ejecutar OCR y detección de QR si la plataforma lo soporta
      await _runOcrAnalysis(file.path);
    } catch (e) {
      if (mounted) {
        setState(() {
          _submissionError = 'No se pudo cargar la imagen seleccionada ($e).';
        });
      }
    }
  }

  /// Ejecuta el escaneo de OCR y código QR
  Future<void> _runOcrAnalysis(String filePath) async {
    if (!_ocrService.isSupported) {
      setState(() {
        _ocrNotice =
            'El OCR local no está disponible en este dispositivo; tu documento irá a revisión manual.';
      });
      return;
    }

    setState(() => _isScanningOcr = true);

    try {
      final scanResult = await _ocrService.scanDocument(filePath);
      if (mounted) {
        setState(() {
          _clientOcrText = scanResult.text.isNotEmpty ? scanResult.text : null;
          _qrUrl = scanResult.qrUrl;

          // Intento de autocompletado inteligente de carné si no fue llenado
          if (_carneController.text.trim().isEmpty && scanResult.text.isNotEmpty) {
            final match = VerificationValidators.carnePattern.firstMatch(scanResult.text);
            if (match != null) {
              _carneController.text = match.group(0)!;
            }
          }
        });
      }
    } catch (e) {
      debugPrint('[DocumentVerification] Error en escaneo OCR');
    } finally {
      if (mounted) setState(() => _isScanningOcr = false);
    }
  }

  /// Envía el formulario y archivo al Cloudflare Worker
  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_fileBytes == null || _selectedFile == null) {
      setState(() => _submissionError = 'Debes adjuntar una foto o archivo de tu documento.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submissionError = null;
    });

    final carne = _carneController.text.trim();

    try {
      final result = await widget.controller.submitDocument(
        fileBytes: _fileBytes!,
        fileName: _selectedFile!.name,
        carne: carne,
        documentType: _selectedDocType,
        clientOcrText: _clientOcrText,
        qrUrl: _qrUrl,
      );

      if (!mounted) return;

      if (result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Text(
              '¡Documento validado! Tu cuenta ha sido verificada (${widget.controller.maskedCarne ?? ''}).',
            ),
          ),
        );
        widget.onSuccess();
      } else if (result.isManualReview) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: ZanateColors.zanateAccent,
            content: Text(
              'Tu documento fue enviado a revisión manual. Podrás publicar en cuanto el equipo valide tus datos.',
            ),
          ),
        );
        widget.onSuccess();
      } else {
        setState(() {
          _submissionError = result.message ??
              VerificationValidators.mapErrorCode(result.code);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submissionError = VerificationValidators.mapErrorCode('network_error');
        });
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Verificar si el Worker está configurado
    if (!_verificationService.isWorkerConfigured) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.build_circle_outlined, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            const Text(
              'Servicio de verificación con documento no disponible',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'El endpoint del Worker de verificación de documentos no está configurado en este entorno. Por favor utiliza la verificación mediante correo institucional.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: widget.onSelectEmailPath,
              child: const Text('Ir a Verificación con Correo'),
            ),
          ],
        ),
      );
    }

    return AbsorbPointer(
      absorbing: _isSubmitting,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Resumen Camino B
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.document_scanner_outlined,
                      color: ZanateColors.zanateAccent,
                      size: 24,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Camino B: Validación mediante fotografía de documento oficial (constancia, carné o boleta).',
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
              const SizedBox(height: 12),

              // Indicador visual Zero-PII de destrucción inmediata
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? const Color(0xFF166534) : const Color(0xFFBBF7D0),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.auto_delete_outlined,
                      color: Color(0xFF16A34A),
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Si la validación automática es exitosa, la imagen se destruye al instante y no se almacena en ningún servidor.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF15803D),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Tipo de Documento
              DropdownButtonFormField<VerificationDocumentType>(
                initialValue: _selectedDocType,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Tipo de Documento Oficial',
                  prefixIcon: Icon(Icons.assignment_outlined),
                  border: OutlineInputBorder(),
                ),
                items: VerificationDocumentType.values.map((type) {
                  return DropdownMenuItem<VerificationDocumentType>(
                    value: type,
                    child: Text(type.displayName, style: const TextStyle(fontSize: 13)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedDocType = val);
                },
              ),
              const SizedBox(height: 14),

              // Campo Carné
              TextFormField(
                controller: _carneController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
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
              const SizedBox(height: 16),

              // Selector de Imagen: Cámara o Galería
              Text(
                'Foto o captura del documento:',
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Tomar foto'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Galería'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Vista previa del archivo seleccionado
              if (_selectedFile != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.image_outlined, color: ZanateColors.zanateAccent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedFile!.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (_isScanningOcr)
                              const Text(
                                'Analizando OCR y código QR...',
                                style: TextStyle(fontSize: 11, color: ZanateColors.zanateAccent),
                              )
                            else if (_clientOcrText != null && _clientOcrText!.isNotEmpty)
                              const Text(
                                '✓ Texto extraído para validación rápida',
                                style: TextStyle(fontSize: 11, color: Color(0xFF10B981)),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        tooltip: 'Eliminar imagen',
                        onPressed: () => setState(() {
                          _selectedFile = null;
                          _fileBytes = null;
                          _clientOcrText = null;
                          _qrUrl = null;
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Aviso si OCR no está soportado (web/desktop)
              if (_ocrNotice != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 18, color: ZanateColors.zanateAccent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _ocrNotice!,
                          style: const TextStyle(fontSize: 11.5, color: ZanateColors.zanateAccent),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Errores de envío
              if (_submissionError != null) ...[
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
                    _submissionError!,
                    style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Botón de Enviar Documento
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ZanateColors.zanateAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: (_isSubmitting || _isScanningOcr) ? null : _handleSubmit,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Enviar Documento para Verificación',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
              ),

              const SizedBox(height: 20),
              // Enlace de vuelta al Camino A
              Center(
                child: TextButton.icon(
                  onPressed: widget.onSelectEmailPath,
                  icon: const Icon(Icons.mail_outline, size: 18),
                  label: const Text(
                    'Prefiero verificar con mi correo institucional (Camino A)',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
