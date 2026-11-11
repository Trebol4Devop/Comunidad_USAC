import 'package:flutter_test/flutter_test.dart';
import 'package:comunidad_universitaria/core/constants/categories.dart';

void main() {
  group('USACConstants Catalog Integrity', () {
    test('Facultades: IDs únicos y nombres válidos', () {
      final facultyIds = <String>{};
      for (final fac in USACConstants.facultades) {
        final id = fac['id']?.toString() ?? '';
        final nombre = fac['nombre']?.toString() ?? '';

        expect(id, isNotEmpty, reason: 'El ID de facultad no debe estar vacío');
        expect(nombre, isNotEmpty, reason: 'El nombre de facultad no debe estar vacío');
        expect(
          facultyIds.contains(id),
          isFalse,
          reason: 'El ID de facultad "$id" está duplicado',
        );
        facultyIds.add(id);
      }
    });

    test('Carreras por facultad: id, codigo y nombre no vacíos', () {
      for (final fac in USACConstants.facultades) {
        final facId = fac['id'];
        final carreras = fac['carreras'] as List<dynamic>? ?? [];

        expect(carreras, isNotEmpty, reason: 'La facultad $facId debe tener carreras');
        final careerIdsInFaculty = <String>{};

        for (final item in carreras) {
          final carrera = Map<String, dynamic>.from(item as Map);
          final cId = carrera['id']?.toString() ?? '';
          final cCodigo = carrera['codigo']?.toString() ?? '';
          final cNombre = carrera['nombre']?.toString() ?? '';

          expect(cId, isNotEmpty, reason: 'ID de carrera vacío en facultad $facId');
          expect(cCodigo, isNotEmpty, reason: 'Código de carrera vacío para carrera $cId en $facId');
          expect(cNombre, isNotEmpty, reason: 'Nombre de carrera vacío para carrera $cId en $facId');

          expect(
            careerIdsInFaculty.contains(cId),
            isFalse,
            reason: 'Carrera ID "$cId" duplicado dentro de la facultad $facId',
          );
          careerIdsInFaculty.add(cId);
        }
      }
    });

    test('Sedes: IDs únicos y nombres válidos', () {
      final sedeIds = <String>{};
      for (final sede in USACConstants.sedes) {
        final id = sede['id'] ?? '';
        final nombre = sede['nombre'] ?? '';

        expect(id, isNotEmpty, reason: 'El ID de sede no debe estar vacío');
        expect(nombre, isNotEmpty, reason: 'El nombre de sede no debe estar vacío');
        expect(
          sedeIds.contains(id),
          isFalse,
          reason: 'El ID de sede "$id" está duplicado',
        );
        sedeIds.add(id);
      }
    });

    test('Campus Buildings: building_code válido, nombre y coordenadas numéricas en rango', () {
      for (final building in USACConstants.campusBuildings) {
        final id = building['id']?.toString() ?? '';
        final code = building['building_code']?.toString() ?? '';
        final lat = building['latitude'];
        final lng = building['longitude'];

        expect(id, isNotEmpty, reason: 'El ID de edificio no debe estar vacío');
        expect(code, isNotEmpty, reason: 'El building_code de edificio no debe estar vacío');
        if (lat != null) {
          expect(lat, isA<num>(), reason: 'Latitude debe ser numérica para $id');
          expect((lat as num).abs(), lessThanOrEqualTo(90.0));
        }
        if (lng != null) {
          expect(lng, isA<num>(), reason: 'Longitude debe ser numérica para $id');
          expect((lng as num).abs(), lessThanOrEqualTo(180.0));
        }
      }

      // La combinación id + building_code es única para cada registro de campusBuildings
      final uniqueBuildingEntries = <String>{};
      for (final building in USACConstants.campusBuildings) {
        final key = '${building['id']}_${building['building_code']}';
        expect(
          uniqueBuildingEntries.contains(key),
          isFalse,
          reason: 'Entrada duplicada: $key',
        );
        uniqueBuildingEntries.add(key);
      }
    });

    test('Categorías de foro y marketplace tienen IDs únicos', () {
      final forumCatIds = USACConstants.forumCategories.map((c) => c.id).toSet();
      expect(forumCatIds.length, USACConstants.forumCategories.length);

      final marketCatIds = USACConstants.marketplaceCategories.map((c) => c.id).toSet();
      expect(marketCatIds.length, USACConstants.marketplaceCategories.length);
    });
  });
}
