import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'ocr_service.dart';

OcrService createOcrService() => IoOcrService();

class IoOcrService implements OcrService {
  @override
  bool get isSupported => Platform.isAndroid || Platform.isIOS;

  @override
  Future<OcrScanResult> scanDocument(String filePath) async {
    // Si no es un dispositivo móvil (ej. Linux, macOS, Windows en desarrollo)
    if (!isSupported) {
      return const OcrScanResult.unsupported(
        'El OCR local no está disponible en este dispositivo; tu documento irá a revisión manual.',
      );
    }

    String extractedText = '';
    String? qrUrl;

    // 1. Extracción de texto con Google ML Kit Text Recognition
    try {
      final inputImage = InputImage.fromFilePath(filePath);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final recognized = await textRecognizer.processImage(inputImage);
      extractedText = recognized.text;
      await textRecognizer.close();
    } catch (e) {
      debugPrint('[OcrService] Error en reconocimiento de texto ML Kit: $e');
    }

    // 2. Detección de código QR con mobile_scanner
    try {
      final scannerController = MobileScannerController();
      final BarcodeCapture? capture = await scannerController.analyzeImage(filePath);
      await scannerController.dispose();

      if (capture != null && capture.barcodes.isNotEmpty) {
        for (final barcode in capture.barcodes) {
          final val = barcode.rawValue ?? barcode.url?.url;
          if (val != null && val.trim().isNotEmpty) {
            qrUrl = val.trim();
            break;
          }
        }
      }
    } catch (e) {
      debugPrint('[OcrService] Error en lectura de QR con mobile_scanner: $e');
    }

    return OcrScanResult(
      text: extractedText,
      qrUrl: qrUrl,
      isSupported: true,
    );
  }

  @override
  void dispose() {}
}
