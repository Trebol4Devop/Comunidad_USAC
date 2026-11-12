import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:comunidad_universitaria/features/map/models/bathroom_tier_config.dart';
import 'package:comunidad_universitaria/features/map/widgets/bathroom_tier_badge.dart';

void main() {
  group('BathroomTierConfig Tests - Escala Oficial USAC', () {
    test('Resuelve Templo de los dioses para promedios >= 4.60', () {
      final tier = BathroomTierConfig.resolve(4.85);
      expect(tier.code, 'templo_dioses');
      expect(tier.label, 'Templo de los dioses');
      expect(tier.emoji, '🏛️');
      expect(tier.colorHex, 0xFFF59E0B);
    });

    test('Resuelve Disfrutable para promedios entre 4.00 y 4.59', () {
      final tier = BathroomTierConfig.resolve(4.20);
      expect(tier.code, 'disfrutable');
      expect(tier.label, 'Disfrutable');
      expect(tier.emoji, '✨');
      expect(tier.colorHex, 0xFF10B981);
    });

    test('Resuelve Cacada limpia para promedios entre 3.00 y 3.99', () {
      final tier = BathroomTierConfig.resolve(3.50);
      expect(tier.code, 'cacada_limpia');
      expect(tier.label, 'Cacada limpia');
      expect(tier.emoji, '🧼');
      expect(tier.colorHex, 0xFF84CC16);
    });

    test('Resuelve Cacada tolerable para promedios entre 2.00 y 2.99', () {
      final tier = BathroomTierConfig.resolve(2.40);
      expect(tier.code, 'cacada_tolerable');
      expect(tier.label, 'Cacada tolerable');
      expect(tier.emoji, '⚠️');
      expect(tier.colorHex, 0xFFEA580C);
    });

    test('Resuelve Cacada crítica para promedios menores a 2.00', () {
      final tier = BathroomTierConfig.resolve(1.50);
      expect(tier.code, 'cacada');
      expect(tier.label, 'Cacada');
      expect(tier.emoji, '💩');
      expect(tier.colorHex, 0xFFDC2626);
    });

    test('toRatingClassificationConfig genera esquema completo para sanitarios', () {
      final config = BathroomTierConfig.toRatingClassificationConfig();
      expect(config.category, 'sanitarios');
      expect(config.tiers.length, 5);
      expect(config.availableTags, contains('has_water'));
      expect(config.availableTags, contains('has_paper'));
      expect(config.availableTags, contains('has_soap'));
      expect(config.availableTags, contains('door_locks'));
      expect(config.availableTags, contains('is_clean'));
    });
  });

  group('BathroomTierBadge Widget Tests', () {
    testWidgets('Renderiza en modo expandido con emoji, label y tags', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BathroomTierBadge(
              averageRating: 4.8,
              totalReviews: 12,
              tagsSummary: {
                'has_water': 10,
                'has_soap': 8,
              },
            ),
          ),
        ),
      );

      expect(find.text('🏛️'), findsOneWidget);
      expect(find.text('Templo de los dioses'), findsOneWidget);
      expect(find.text('4.8 ★'), findsOneWidget);
      expect(find.text('💧 Agua (10)'), findsOneWidget);
      expect(find.text('🧼 Jabón (8)'), findsOneWidget);
    });

    testWidgets('Renderiza en modo compacto', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BathroomTierBadge(
              averageRating: 3.2,
              compact: true,
            ),
          ),
        ),
      );

      expect(find.text('🧼'), findsOneWidget);
      expect(find.text('Cacada limpia'), findsOneWidget);
      expect(find.text('3.2 ★'), findsOneWidget);
    });
  });
}
