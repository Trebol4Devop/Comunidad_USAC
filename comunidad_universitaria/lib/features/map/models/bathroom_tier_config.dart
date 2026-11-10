import 'package:usac_campus_map/usac_campus_map.dart';

/// Las 5 clases oficiales de sanitarios del Campus Central de la USAC.
enum BathroomTier {
  cacada,
  cacadaTolerable,
  cacadaLimpia,
  disfrutable,
  temploDioses,
}

/// Configuración semántica, colores, emojis y umbrales para sanitarios USAC.
class BathroomTierConfig {
  final String code;
  final String label;
  final String emoji;
  final int colorHex;
  final String description;
  final double minRating;

  const BathroomTierConfig({
    required this.code,
    required this.label,
    required this.emoji,
    required this.colorHex,
    required this.description,
    this.minRating = 0.0,
  });

  /// Resuelve la clase oficial del sanitario según su promedio numérico (1.00 a 5.00).
  static BathroomTierConfig resolve(double avg) {
    if (avg >= 4.60) {
      return const BathroomTierConfig(
        code: 'templo_dioses',
        label: 'Templo de los dioses',
        emoji: '🏛️',
        colorHex: 0xFFF59E0B, // Dorado / Ámbar
        description: 'Impecable, papel garantizado, agua constante y aromatizado.',
        minRating: 4.60,
      );
    } else if (avg >= 4.00) {
      return const BathroomTierConfig(
        code: 'disfrutable',
        label: 'Disfrutable',
        emoji: '✨',
        colorHex: 0xFF10B981, // Esmeralda
        description: 'Muy limpio, agua corriente, jabón y pestillo seguro.',
        minRating: 4.00,
      );
    } else if (avg >= 3.00) {
      return const BathroomTierConfig(
        code: 'cacada_limpia',
        label: 'Cacada limpia',
        emoji: '🧼',
        colorHex: 0xFF84CC16, // Lima
        description: 'Aceptable: inodoros higiénicos y agua disponible.',
        minRating: 3.00,
      );
    } else if (avg >= 2.00) {
      return const BathroomTierConfig(
        code: 'cacada_tolerable',
        label: 'Cacada tolerable',
        emoji: '⚠️',
        colorHex: 0xFFEA580C, // Naranja
        description: 'Solo emergencias: falta papel higiénico o jabón.',
        minRating: 2.00,
      );
    } else {
      return const BathroomTierConfig(
        code: 'cacada',
        label: 'Cacada',
        emoji: '💩',
        colorHex: 0xFFDC2626, // Rojo Crítico
        description: 'Sin agua ni insumos, higiene deficiente. Evitar a toda costa.',
        minRating: 0.00,
      );
    }
  }

  /// Catálogo de los 5 niveles en orden descendente.
  static const List<BathroomTierConfig> allTiers = [
    BathroomTierConfig(
      code: 'templo_dioses',
      label: 'Templo de los dioses',
      emoji: '🏛️',
      colorHex: 0xFFF59E0B,
      description: 'Impecable, papel garantizado, agua constante y aromatizado.',
      minRating: 4.60,
    ),
    BathroomTierConfig(
      code: 'disfrutable',
      label: 'Disfrutable',
      emoji: '✨',
      colorHex: 0xFF10B981,
      description: 'Muy limpio, agua corriente, jabón y pestillo seguro.',
      minRating: 4.00,
    ),
    BathroomTierConfig(
      code: 'cacada_limpia',
      label: 'Cacada limpia',
      emoji: '🧼',
      colorHex: 0xFF84CC16,
      description: 'Aceptable: inodoros higiénicos y agua disponible.',
      minRating: 3.00,
    ),
    BathroomTierConfig(
      code: 'cacada_tolerable',
      label: 'Cacada tolerable',
      emoji: '⚠️',
      colorHex: 0xFFEA580C,
      description: 'Solo emergencias: falta papel higiénico o jabón.',
      minRating: 2.00,
    ),
    BathroomTierConfig(
      code: 'cacada',
      label: 'Cacada',
      emoji: '💩',
      colorHex: 0xFFDC2626,
      description: 'Sin agua ni insumos, higiene deficiente. Evitar a toda costa.',
      minRating: 0.00,
    ),
  ];

  /// Convierte el esquema oficial a `RatingClassificationConfig` para `usac_campus_map`.
  static RatingClassificationConfig toRatingClassificationConfig() {
    return RatingClassificationConfig(
      category: 'sanitarios',
      title: 'Clasificación Oficial de Sanitarios USAC',
      tiers: allTiers
          .map(
            (t) => RatingTierItem(
              code: t.code,
              label: t.label,
              emoji: t.emoji,
              colorHex: t.colorHex,
              description: t.description,
              minRating: t.minRating,
            ),
          )
          .toList(),
      availableTags: const [
        'has_water',
        'has_paper',
        'has_soap',
        'door_locks',
        'is_clean',
      ],
      tagLabels: const {
        'has_water': '💧 Agua corriente',
        'has_paper': '🧻 Papel higiénico',
        'has_soap': '🧼 Jabón de manos',
        'door_locks': '🔒 Pestillo seguro',
        'is_clean': '✨ Limpio',
      },
    );
  }
}
