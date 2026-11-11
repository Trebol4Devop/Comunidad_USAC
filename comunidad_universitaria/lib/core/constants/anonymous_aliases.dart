import 'dart:math';

/// Catálogo y generador determinista de alias anónimos para la comunidad universitaria.
class AnonymousAliasGenerator {
  /// Sustantivos del catálogo oficial.
  static const List<String> nouns = [
    'Compilador',
    'Puntero',
    'Fantasma',
    'Sobreviviente',
    'Recursivo',
    'Kernel',
    'Bit',
    'Array',
    'Servidor',
    'Algoritmo',
    'Depurador',
    'Hilo',
    'Buffer',
    'Binario',
    'Parqueo',
    'Cafetero',
    'Sancarlista',
    'Búho',
    'Volcán',
    'Chicharra',
    'Referencia',
    'Mutex',
    'Paquete',
    'Semáforo',
    'Nodo',
    'Byte',
    'Caché',
    'Correo',
    'Monitor',
    'Teclado',
    'Código',
    'Parcial',
    'Laboratorio',
    'Examen',
    'Proyecto',
    'Carrera',
    'Catedrático',
    'Estudiante',
  ];

  /// Adjetivos del catálogo oficial.
  static const List<String> adjectives = [
    'Desvelado',
    'Sin Semestre',
    'En Llamas',
    'Del T-3',
    'Nocturno',
    'Ansioso',
    'Perdido',
    'Sin Café',
    'De Madrugada',
    'Empapelado',
    'Reprobado',
    'Recursivo',
    'Sin Sueño',
    'Del Lab',
    'En Parciales',
    'Caffeinado',
    'Fantasmal',
    'Anónimo',
    'Clandestino',
    'Invisible',
    'Sin Créditos',
    'Del Bloque',
    'De Turno',
    'Sin Notas',
    'Iluminado',
    'Confundido',
    'Apurado',
    'Del Bus',
    'En Crisis',
    'Sin WiFi',
    'Sin Almuerzo',
    'Del Grupo',
    'En Línea',
    'De Siempre',
    'Sin Plan',
  ];

  /// Genera un alias en formato "Sustantivo Adjetivo".
  /// Nunca devuelve una cadena vacía.
  static String generate([Random? random]) {
    final rng = random ?? Random();
    final noun = nouns[rng.nextInt(nouns.length)];
    final adj = adjectives[rng.nextInt(adjectives.length)];
    return '$noun $adj';
  }

  /// Valida que el alias cumpla las reglas de identidad anónima:
  /// - No vacío.
  /// - Sin '@'.
  /// - Sin 5 o más dígitos consecutivos.
  /// - Sin títulos honoríficos o profesionales (Ing./Lic./Dr./etc. + nombre).
  /// - Compuesto por sustantivo + adjetivo del catálogo (o formato legacy "Estudiante ... #NNN").
  static bool isValid(String alias) {
    final trimmed = alias.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.contains('@')) return false;
    if (RegExp(r'\d{5,}').hasMatch(trimmed)) return false;

    // Sin títulos (Ing./Lic./Dr./etc. + nombre)
    final titleRegex = RegExp(
      r'^(ing|lic|dr|dra|arq|msc|prof|ingeniero|licenciado|doctor|doctora)\.?\s+',
      caseSensitive: false,
    );
    if (titleRegex.hasMatch(trimmed)) return false;

    // Formato legacy: Estudiante ... #NNN
    final legacyRegex = RegExp(
      r'^Estudiante(\s+.*)?\s*#\d+$',
      caseSensitive: false,
    );
    if (legacyRegex.hasMatch(trimmed)) return true;

    // Compuesto por sustantivo + adjetivo del catálogo
    for (final noun in nouns) {
      if (trimmed.startsWith('$noun ')) {
        final remaining = trimmed.substring(noun.length + 1).trim();
        if (adjectives.contains(remaining)) {
          return true;
        }
      }
    }

    return false;
  }
}
