/// Validadores y utilidades para el flujo de verificación estudiantil USAC.
/// Cumple con las especificaciones del contrato normativo (docs/verification/contract.md §4.2, §6.1, §7).
class VerificationValidators {
  /// Formato canónico de carné USAC:
  /// Exactamente 9 dígitos.
  /// Los primeros 4 dígitos corresponden al año de matrícula (entre 1980 y el año actual).
  static final RegExp carnePattern =
      RegExp(r'^(19[8-9][0-9]|20[0-9][0-9])[0-9]{5}$');

  /// Formato canónico de CUI (Código Único de Identificación de Guatemala):
  /// Exactamente 13 dígitos numéricos.
  /// Posiciones 10 y 11 representan el código de departamento (01 a 22).
  static final RegExp cuiPattern =
      RegExp(r'^[0-9]{9}(0[1-9]|1[0-9]|2[0-2])[0-9]{2}$');

  /// Dominios institucionales explícitos autorizados adicionales a usac.edu.gt
  static const Set<String> explicitAllowedDomains = {
    'usac.edu.gt',
    'ingenieria.usac.edu.gt',
    'ecys.org',
    'medicina.usac.edu.gt',
    'derecho.usac.edu.gt',
    'economicas.usac.edu.gt',
    'farusac.edu.gt',
    'fausac.gt',
  };

  /// Valida si un carné cumple con el formato y rango de años permitido.
  static bool isValidCarne(String? carne) {
    if (carne == null) return false;
    final clean = carne.trim();
    if (!carnePattern.hasMatch(clean)) return false;

    final year = int.tryParse(clean.substring(0, 4));
    if (year == null) return false;

    final currentYear = DateTime.now().year;
    return year >= 1980 && year <= currentYear;
  }

  /// Validador de formulario para el campo carné.
  static String? validateCarne(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Ingresa tu número de carné universitario.';
    }
    final clean = value.trim();
    if (clean.length != 9) {
      return 'El carné debe tener exactamente 9 dígitos.';
    }
    if (!isValidCarne(clean)) {
      final currentYear = DateTime.now().year;
      return 'Año de carné inválido (debe ser entre 1980 y $currentYear).';
    }
    return null;
  }

  /// Valida si un CUI es válido según las reglas de RENAP y contrato §4.2.
  static bool isValidCui(String? cui) {
    if (cui == null) return false;
    final clean = cui.trim();
    if (clean.isEmpty) return true; // CUI es opcional
    return cuiPattern.hasMatch(clean);
  }

  /// Validador de formulario para el campo CUI (opcional).
  static String? validateCui(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Opcional
    }
    final clean = value.trim();
    if (!isValidCui(clean)) {
      return 'El CUI debe tener 13 dígitos y un código departamental válido (01-22).';
    }
    return null;
  }

  /// Extrae el dominio de una dirección de correo electrónico en minúsculas.
  static String? extractEmailDomain(String? email) {
    if (email == null) return null;
    final clean = email.trim().toLowerCase();
    final atIndex = clean.indexOf('@');
    if (atIndex == -1 || atIndex == clean.length - 1) return null;
    return clean.substring(atIndex + 1);
  }

  /// Determina si un correo electrónico pertenece a un dominio institucional USAC.
  /// Contrato §1, §4.5:
  /// - Dominio principal: `usac.edu.gt`
  /// - Subdominios: `*.usac.edu.gt` (ej. `ingenieria.usac.edu.gt`)
  /// - Dominios en facultades: `ecys.org`, `fausac.gt`
  static bool isInstitutionalEmail(String? email) {
    final domain = extractEmailDomain(email);
    if (domain == null) return false;

    if (domain == 'usac.edu.gt' || domain.endsWith('.usac.edu.gt')) {
      return true;
    }
    return explicitAllowedDomains.contains(domain);
  }

  /// Enmascara un carné de forma segura para proteger la privacidad del estudiante.
  /// Ejemplo: '201912345' -> '2019****5'.
  static String maskCarne(String? carne) {
    if (carne == null || carne.trim().isEmpty) return '';
    final clean = carne.trim();
    if (clean.length < 5) return '****';
    final start = clean.substring(0, 4);
    final end = clean.substring(clean.length - 1);
    final stars = '*' * (clean.length - 5);
    return '$start$stars$end';
  }

  /// Mapea códigos de error del Worker o de la base de datos a mensajes
  /// amigables y seguros para el usuario final.
  ///
  /// IMPORTANTE (Contrato §6.1, §4.2):
  /// Nunca confirmar si una credencial existe o a quién pertenece.
  /// `credential_unavailable` debe mostrar un mensaje estrictamente genérico.
  static String mapErrorCode(String? code) {
    switch (code) {
      case 'credential_unavailable':
        return 'No pudimos vincular este carné. Si crees que es un error, contacta soporte.';
      case 'rate_limited':
        return 'Demasiados intentos de verificación en las últimas 24 horas. Por favor espera.';
      case 'invalid_carne':
        return 'El carné debe tener 9 dígitos y corresponder a un año de matrícula válido.';
      case 'invalid_cui':
        return 'El formato del CUI es inválido.';
      case 'invalid_document_type':
        return 'El tipo de documento seleccionado no es válido.';
      case 'unauthorized':
      case 'not_authenticated':
        return 'Debes iniciar sesión con una cuenta real para verificar tu identidad.';
      case 'file_too_large':
        return 'El archivo supera el tamaño máximo permitido de 10 MB.';
      case 'unsupported_media_type':
        return 'Formato de imagen inválido. Solo se admiten archivos JPEG, PNG y WebP.';
      case 'missing_fields':
        return 'Faltan campos obligatorios para procesar la verificación.';
      case 'invalid_qr_host':
        return 'El enlace del código QR debe pertenecer a un dominio oficial usac.edu.gt.';
      case 'upload_failed':
        return 'No se pudo subir el documento para revisión. Inténtalo nuevamente.';
      case 'network_error':
        return 'No se pudo establecer conexión con el servidor de verificación. Revisa tu conexión a internet e inténtalo de nuevo.';
      case 'worker_unconfigured':
        return 'El servicio de verificación de documentos no está configurado en este entorno.';
      default:
        return 'Ocurrió un error al procesar tu solicitud. Por favor intenta más tarde.';
    }
  }
}
