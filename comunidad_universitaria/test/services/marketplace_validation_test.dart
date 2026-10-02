import 'package:flutter_test/flutter_test.dart';
import 'package:comunidad_universitaria/core/services/marketplace_service.dart';

void main() {
  group('MarketplaceService.validateContent', () {
    const prohibitedKeywords = [
      'hacer examenes',
      'hago examenes',
      'vender parcial',
      'vendo parcial',
      'suplantacion',
      'resolucion de examen',
      'resuelvo examen',
      'hago tareas completas por parcial',
      'arma',
      'armas',
      'droga',
      'drogas',
      'marihuana',
      'cocaina',
      'estafa',
      'piramidal',
      'alcohol',
      'cerveza',
      'licor',
    ];

    test('detecta TODOS los keywords prohibidos en minúsculas y mayúsculas', () {
      for (final keyword in prohibitedKeywords) {
        // En minúsculas en el título
        final resLower = MarketplaceService.validateContent(
          title: 'Servicio de $keyword garantizado',
          description: 'Escribir por privado',
        );
        expect(
          resLower,
          isNotNull,
          reason: 'Debe detectar el keyword en minúsculas: "$keyword"',
        );
        expect(resLower, contains('términos restringidos'));

        // En mayúsculas en la descripción
        final resUpper = MarketplaceService.validateContent(
          title: 'Oferta especial',
          description: 'INCLUYE ${keyword.toUpperCase()} PARA TODOS',
        );
        expect(
          resUpper,
          isNotNull,
          reason: 'Debe detectar el keyword en mayúsculas: "${keyword.toUpperCase()}"',
        );
        expect(resUpper, contains('términos restringidos'));
      }
    });

    test('detecta término prohibido cuando está solo en el título', () {
      final res = MarketplaceService.validateContent(
        title: 'Vendo cerveza artesanal',
        description: 'Entrega en el parqueo de rectoría',
      );
      expect(res, isNotNull);
      expect(res, contains('cerveza'));
    });

    test('detecta término prohibido cuando está solo en la descripción', () {
      final res = MarketplaceService.validateContent(
        title: 'Tutoría de Matemática',
        description: 'También resuelvo examen durante el horario de clase',
      );
      expect(res, isNotNull);
      expect(res, contains('resuelvo examen'));
    });

    test('detecta término prohibido compuesto repartido entre título y descripción', () {
      final res = MarketplaceService.validateContent(
        title: 'Ofrezco hacer',
        description: 'examenes de física y química',
      );
      expect(res, isNotNull);
      expect(res, contains('hacer examenes'));
    });

    test('permite publicaciones con contenido legítimo y devuelve null', () {
      final res1 = MarketplaceService.validateContent(
        title: 'Calculadora Casio fx-991LA X Classwiz',
        description: 'Usada durante 1 semestre en Ingeniería, como nueva con estuche.',
      );
      expect(res1, isNull);

      final res2 = MarketplaceService.validateContent(
        title: 'Pastel de zanahoria por porción',
        description: 'Postres caseros frescos en el edificio S-12 al mediodía.',
      );
      expect(res2, isNull);

      final res3 = MarketplaceService.validateContent(
        title: 'Tutoría de Programación y Algoritmos',
        description: 'Clases de apoyo para proyectos universitarios y resolución de dudas.',
      );
      expect(res3, isNull);
    });
  });
}
