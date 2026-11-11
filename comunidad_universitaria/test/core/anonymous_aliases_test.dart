import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:comunidad_universitaria/core/constants/anonymous_aliases.dart';

void main() {
  group('AnonymousAliasGenerator Unit Tests', () {
    test('nouns y adjectives no están vacíos y coinciden con el catálogo', () {
      expect(AnonymousAliasGenerator.nouns.length, equals(38));
      expect(AnonymousAliasGenerator.adjectives.length, equals(35));

      expect(AnonymousAliasGenerator.nouns.contains('Compilador'), isTrue);
      expect(AnonymousAliasGenerator.nouns.contains('Estudiante'), isTrue);
      expect(AnonymousAliasGenerator.adjectives.contains('Desvelado'), isTrue);
      expect(AnonymousAliasGenerator.adjectives.contains('Del T-3'), isTrue);
    });

    test(
      'generate() devuelve una combinación no vacía "Sustantivo Adjetivo"',
      () {
        for (int i = 0; i < 50; i++) {
          final alias = AnonymousAliasGenerator.generate();
          expect(alias.isNotEmpty, isTrue);
          expect(AnonymousAliasGenerator.isValid(alias), isTrue);
        }

        // Con generador determinista
        final fixedRandom = Random(42);
        final aliasFixed = AnonymousAliasGenerator.generate(fixedRandom);
        expect(aliasFixed.isNotEmpty, isTrue);
        expect(AnonymousAliasGenerator.isValid(aliasFixed), isTrue);
      },
    );

    test('isValid valida correctamente alias válidos e inválidos', () {
      // Válidos
      expect(AnonymousAliasGenerator.isValid('Compilador Desvelado'), isTrue);
      expect(AnonymousAliasGenerator.isValid('Búho Del T-3'), isTrue);
      expect(AnonymousAliasGenerator.isValid('Kernel Sin Sueño'), isTrue);
      expect(AnonymousAliasGenerator.isValid('Estudiante USAC #402'), isTrue);
      expect(AnonymousAliasGenerator.isValid('Estudiante #10'), isTrue);

      // Inválidos: Vacío o espacios
      expect(AnonymousAliasGenerator.isValid(''), isFalse);
      expect(AnonymousAliasGenerator.isValid('   '), isFalse);

      // Inválidos: Con @
      expect(AnonymousAliasGenerator.isValid('Compilador@Desvelado'), isFalse);
      expect(AnonymousAliasGenerator.isValid('user@usac.edu.gt'), isFalse);

      // Inválidos: 5 o más dígitos consecutivos
      expect(AnonymousAliasGenerator.isValid('Compilador 12345'), isFalse);

      // Inválidos: Títulos profesionales o académicos + nombre
      expect(AnonymousAliasGenerator.isValid('Ing. Carlos'), isFalse);
      expect(AnonymousAliasGenerator.isValid('Lic. Perez'), isFalse);
      expect(AnonymousAliasGenerator.isValid('Dr. Martinez'), isFalse);
      expect(AnonymousAliasGenerator.isValid('Prof. Gomez'), isFalse);

      // Inválidos: Sustantivo o adjetivo no en catálogo
      expect(AnonymousAliasGenerator.isValid('Computadora Desvelada'), isFalse);
      expect(AnonymousAliasGenerator.isValid('Compilador Feliz'), isFalse);
    });
  });
}
