/// Validación local (en el dispositivo) de la foto del carné USAC.
///
/// No sustituye la verificación institucional: comprueba que la imagen es
/// coherente con los datos que el estudiante escribió antes de permitir el
/// envío del correo/OTP. La foto nunca se envía ni se persiste.
library;

enum CarnetCheckLevel { ok, warning, error }

class CarnetCheckItem {
  final String label;
  final CarnetCheckLevel level;
  final String? detail;

  const CarnetCheckItem(this.label, this.level, {this.detail});

  bool get isError => level == CarnetCheckLevel.error;
  bool get isWarning => level == CarnetCheckLevel.warning;
}

class CarnetPhotoValidation {
  final bool passed;
  final List<CarnetCheckItem> items;
  final String normalizedText;
  final String? detectedCode;

  const CarnetPhotoValidation({
    required this.passed,
    required this.items,
    required this.normalizedText,
    this.detectedCode,
  });
}

class CarnetPhotoValidator {
  static const List<String> institutionalKeywords = [
    'UNIVERSIDAD DE SAN CARLOS',
    'REGISTRO Y ESTADISTICA',
    'DEPARTAMENTO DE REGISTRO Y ESTADISTICA',
    'USAC TRICENTENARIA',
    'ESTUDIANTE UNIVERSITARIO',
  ];

  static const Set<String> _baseStopwords = {
    'FACULTAD',
    'CARRERA',
    'DE',
    'DEL',
    'LA',
    'LAS',
    'EL',
    'LOS',
    'EN',
    'Y',
    'E',
    'CENTRAL',
    'EXTENSIONES',
    'CUM',
  };

  static const Set<String> _careerStopwords = {
    'INGENIERIA',
    'LICENCIATURA',
    'TECNICO',
    'TECNICA',
  };

  /// Normaliza el texto del OCR: mayúsculas, sin tildes y espacios colapsados.
  static String normalize(String text) {
    if (text.trim().isEmpty) return '';
    var upper = text.toUpperCase();
    const replacements = <String, String>{
      'Á': 'A', 'À': 'A', 'Ä': 'A', 'Â': 'A', 'Ã': 'A', 'Å': 'A',
      'É': 'E', 'È': 'E', 'Ë': 'E', 'Ê': 'E',
      'Í': 'I', 'Ì': 'I', 'Ï': 'I', 'Î': 'I',
      'Ó': 'O', 'Ò': 'O', 'Ö': 'O', 'Ô': 'O', 'Õ': 'O',
      'Ú': 'U', 'Ù': 'U', 'Ü': 'U', 'Û': 'U',
      'Ñ': 'N', 'Ç': 'C',
    };
    replacements.forEach((from, to) {
      upper = upper.replaceAll(from, to);
    });
    return upper
        .replaceAll(RegExp(r'[^A-Z0-9@./:]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static List<String> _specificTokens(String value, {bool career = false}) {
    final stop = {
      ..._baseStopwords,
      if (career) ..._careerStopwords,
    };
    return normalize(value)
        .split(RegExp(r'[^A-Z0-9]+'))
        .where((token) => token.length >= 4 && !stop.contains(token))
        .toSet()
        .toList();
  }

  static bool _looksLikeUrl(String value) {
    final lower = value.trim().toLowerCase();
    return lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.contains('usac.edu.gt');
  }

  /// Valida que un QR pertenezca a `usac.edu.gt` o a uno de sus subdominios.
  static bool isValidUsacQr(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.host.isEmpty) return false;
    if (uri.scheme != 'https' && uri.scheme != 'http') return false;
    final host = uri.host.toLowerCase().replaceAll(RegExp(r'\.$'), '');
    return host == 'usac.edu.gt' || host.endsWith('.usac.edu.gt');
  }

  /// Valida el **frente** del carné: carné, CUI, facultad, carrera,
  /// leyenda de emergencia y código de barras.
  ///
  /// Errores (bloquean): no se pudo leer, carné distinto, institución ausente,
  /// CUI distinto (si se envió) o QR con dominio ajeno.
  /// Advertencias (no bloquean): facultad/carrera no confirmadas, leyenda 1592
  /// ausente o código no detectado.
  static CarnetPhotoValidation validateFront({
    required String ocrText,
    String? qrUrl,
    required String carne,
    String? carreraNombre,
    String? facultadNombre,
    String? cui,
    int minTextLength = 20,
  }) {
    final items = <CarnetCheckItem>[];
    final normalized = normalize(ocrText);
    final cleanCarne = carne.trim();

    if (normalized.length < minTextLength) {
      items.add(
        const CarnetCheckItem(
          'Lectura del frente',
          CarnetCheckLevel.error,
          detail:
              'No se pudo leer suficiente texto. Acerca la cámara, evita reflejos y vuelve a intentarlo.',
        ),
      );
    } else {
      items.add(
        const CarnetCheckItem('Lectura del frente', CarnetCheckLevel.ok),
      );
    }

    if (cleanCarne.isNotEmpty && normalized.contains(cleanCarne)) {
      items.add(CarnetCheckItem('Carné $cleanCarne', CarnetCheckLevel.ok));
    } else {
      items.add(
        const CarnetCheckItem(
          'Número de carné',
          CarnetCheckLevel.error,
          detail: 'El número escrito no aparece en la foto.',
        ),
      );
    }

    final hasKeyword =
        institutionalKeywords.any((keyword) => normalized.contains(keyword));
    if (hasKeyword) {
      items.add(const CarnetCheckItem('Institución USAC', CarnetCheckLevel.ok));
    } else {
      items.add(
        const CarnetCheckItem(
          'Institución USAC',
          CarnetCheckLevel.error,
          detail:
              'No se detectó "Universidad de San Carlos" ni "Registro y Estadística".',
        ),
      );
    }

    final cleanCui = cui?.trim();
    if (cleanCui != null && cleanCui.isNotEmpty) {
      if (normalized.contains(cleanCui)) {
        items.add(const CarnetCheckItem('CUI', CarnetCheckLevel.ok));
      } else {
        items.add(
          const CarnetCheckItem(
            'CUI',
            CarnetCheckLevel.error,
            detail: 'El CUI escrito no aparece en la foto.',
          ),
        );
      }
    }

    if (facultadNombre != null && facultadNombre.trim().isNotEmpty) {
      final tokens = _specificTokens(facultadNombre);
      if (tokens.isEmpty || tokens.any(normalized.contains)) {
        items.add(const CarnetCheckItem('Facultad', CarnetCheckLevel.ok));
      } else {
        items.add(
          CarnetCheckItem(
            'Facultad',
            CarnetCheckLevel.warning,
            detail: 'No se pudo confirmar "$facultadNombre" en la foto.',
          ),
        );
      }
    }

    if (carreraNombre != null && carreraNombre.trim().isNotEmpty) {
      final tokens = _specificTokens(carreraNombre, career: true);
      if (tokens.isEmpty || tokens.any(normalized.contains)) {
        items.add(const CarnetCheckItem('Carrera', CarnetCheckLevel.ok));
      } else {
        items.add(
          const CarnetCheckItem(
            'Carrera',
            CarnetCheckLevel.warning,
            detail: 'No se pudo confirmar la carrera en la foto.',
          ),
        );
      }
    }

    final hasEmergency =
        normalized.contains('1592') || normalized.contains('EMERGENCIA');
    if (hasEmergency) {
      items.add(
        const CarnetCheckItem('Leyenda de emergencia', CarnetCheckLevel.ok),
      );
    } else {
      items.add(
        const CarnetCheckItem(
          'Leyenda de emergencia',
          CarnetCheckLevel.warning,
          detail: 'No se detectó "En caso de emergencia marque al 1592".',
        ),
      );
    }

    if (qrUrl != null && qrUrl.trim().isNotEmpty) {
      if (_looksLikeUrl(qrUrl)) {
        if (isValidUsacQr(qrUrl)) {
          items.add(const CarnetCheckItem('Código QR', CarnetCheckLevel.ok));
        } else {
          items.add(
            const CarnetCheckItem(
              'Código QR',
              CarnetCheckLevel.error,
              detail: 'El QR no pertenece a un dominio usac.edu.gt.',
            ),
          );
        }
      } else {
        items.add(
          const CarnetCheckItem(
            'Código de barras del frente',
            CarnetCheckLevel.ok,
          ),
        );
      }
    } else {
      items.add(
        const CarnetCheckItem(
          'Código de barras del frente',
          CarnetCheckLevel.warning,
          detail:
              'No se detectó el código de barras. Si es visible, acerca la cámara y vuelve a intentarlo.',
        ),
      );
    }

    final passed = !items.any((item) => item.isError);
    return CarnetPhotoValidation(
      passed: passed,
      items: items,
      normalizedText: normalized,
      detectedCode: qrUrl,
    );
  }

  /// Compatibilidad con la validación de una sola foto (frente).
  static CarnetPhotoValidation validate({
    required String ocrText,
    String? qrUrl,
    required String carne,
    String? carreraNombre,
    String? facultadNombre,
    String? cui,
    int minTextLength = 20,
  }) =>
      validateFront(
        ocrText: ocrText,
        qrUrl: qrUrl,
        carne: carne,
        carreraNombre: carreraNombre,
        facultadNombre: facultadNombre,
        cui: cui,
        minTextLength: minTextLength,
      );

  /// Valida el **reverso** del carné: leyendas USAC y QR de Registro y
  /// Estadística. El QR debe ser una URL de `usac.edu.gt`; si además contiene
  /// el carné o el CUI, se refuerza la coherencia entre ambas caras.
  static CarnetPhotoValidation validateBack({
    required String ocrText,
    String? qrUrl,
    String? expectedCarne,
    String? expectedCui,
    int minTextLength = 10,
  }) {
    final items = <CarnetCheckItem>[];
    final normalized = normalize(ocrText);

    if (normalized.length < minTextLength) {
      items.add(
        const CarnetCheckItem(
          'Lectura del reverso',
          CarnetCheckLevel.error,
          detail:
              'No se pudo leer el reverso. Acerca la cámara, evita reflejos y vuelve a intentarlo.',
        ),
      );
    } else {
      items.add(
        const CarnetCheckItem('Lectura del reverso', CarnetCheckLevel.ok),
      );
    }

    final hasTricentenario = normalized.contains('TRICENTENARIA');
    final hasEstudiante = normalized.contains('ESTUDIANTE UNIVERSITARIO');
    if (hasTricentenario && hasEstudiante) {
      items.add(
        const CarnetCheckItem(
          'Leyendas USAC del reverso',
          CarnetCheckLevel.ok,
        ),
      );
    } else if (hasTricentenario || hasEstudiante) {
      items.add(
        const CarnetCheckItem(
          'Leyendas USAC del reverso',
          CarnetCheckLevel.warning,
          detail:
              'Solo se detectó una de las leyendas "USAC TRICENTENARIA" / "ESTUDIANTE UNIVERSITARIO".',
        ),
      );
    } else {
      items.add(
        const CarnetCheckItem(
          'Leyendas USAC del reverso',
          CarnetCheckLevel.error,
          detail:
              'No se detectó "USAC TRICENTENARIA" ni "ESTUDIANTE UNIVERSITARIO".',
        ),
      );
    }

    final cleanQr = qrUrl?.trim();
    if (cleanQr == null || cleanQr.isEmpty) {
      items.add(
        const CarnetCheckItem(
          'QR de Registro y Estadística',
          CarnetCheckLevel.error,
          detail: 'No se detectó el QR del reverso.',
        ),
      );
    } else if (!_looksLikeUrl(cleanQr)) {
      items.add(
        const CarnetCheckItem(
          'QR de Registro y Estadística',
          CarnetCheckLevel.error,
          detail: 'El reverso debe incluir un QR, no un código de barras.',
        ),
      );
    } else if (!isValidUsacQr(cleanQr)) {
      items.add(
        const CarnetCheckItem(
          'QR de Registro y Estadística',
          CarnetCheckLevel.error,
          detail:
              'El QR no pertenece a Registro y Estadística (usac.edu.gt).',
        ),
      );
    } else {
      items.add(
        const CarnetCheckItem(
          'QR de Registro y Estadística',
          CarnetCheckLevel.ok,
        ),
      );

      final cleanCarne = expectedCarne?.trim();
      final cleanCui = expectedCui?.trim();
      if (cleanCarne != null &&
          cleanCarne.isNotEmpty &&
          cleanQr.contains(cleanCarne)) {
        items.add(
          const CarnetCheckItem('QR vinculado al carné', CarnetCheckLevel.ok),
        );
      } else if (cleanCui != null &&
          cleanCui.isNotEmpty &&
          cleanQr.contains(cleanCui)) {
        items.add(
          const CarnetCheckItem('QR vinculado al CUI', CarnetCheckLevel.ok),
        );
      } else {
        items.add(
          const CarnetCheckItem(
            'Datos del QR',
            CarnetCheckLevel.warning,
            detail:
                'No se pudo confirmar el carné/CUI dentro del QR; se validó el dominio de Registro y Estadística.',
          ),
        );
      }
    }

    final passed = !items.any((item) => item.isError);
    return CarnetPhotoValidation(
      passed: passed,
      items: items,
      normalizedText: normalized,
      detectedCode: qrUrl,
    );
  }
}
