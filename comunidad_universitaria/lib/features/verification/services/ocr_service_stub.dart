import 'ocr_service.dart';

OcrService createOcrService() => StubOcrService();

class StubOcrService implements OcrService {
  @override
  bool get isSupported => false;

  @override
  Future<OcrScanResult> scanDocument(String filePath) async {
    return const OcrScanResult.unsupported(
      'El OCR local no está disponible en este dispositivo; tu documento irá a revisión manual.',
    );
  }

  @override
  void dispose() {}
}
