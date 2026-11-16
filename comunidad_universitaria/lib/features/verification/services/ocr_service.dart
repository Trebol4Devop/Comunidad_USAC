import 'ocr_service_stub.dart'
    if (dart.library.io) 'ocr_service_io.dart';

/// Resultado del escaneo de OCR y código QR de un documento estudiantil.
class OcrScanResult {
  final String text;
  final String? qrUrl;
  final bool isSupported;
  final String? message;

  const OcrScanResult({
    required this.text,
    this.qrUrl,
    required this.isSupported,
    this.message,
  });

  const OcrScanResult.unsupported([String? customMessage])
      : text = '',
        qrUrl = null,
        isSupported = false,
        message = customMessage ??
            'El OCR local no está disponible en este dispositivo; tu documento irá a revisión manual.';
}

/// Interfaz para el reconocimiento óptico de caracteres y escaneo de QR.
abstract class OcrService {
  factory OcrService() => createOcrService();

  /// Indica si la plataforma actual soporta extracción nativa de texto y QR.
  bool get isSupported;

  /// Analiza un archivo de imagen en disco para extraer texto y códigos QR.
  Future<OcrScanResult> scanDocument(String filePath);

  /// Libera recursos.
  void dispose();
}
