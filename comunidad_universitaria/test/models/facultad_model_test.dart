import 'package:flutter_test/flutter_test.dart';
import 'package:comunidad_universitaria/core/models/facultad.dart';

void main() {
  group('Facultad Model', () {
    test('Facultad.fromMap construye objeto y lista de carreras anidadas', () {
      final map = {
        'id': '08',
        'codigo': '08',
        'nombre': 'Facultad de Ingeniería',
        'sitio': 'https://ingenieria.usac.edu.gt',
        'carreras': [
          {
            'id': 'sistemas',
            'nombre': 'Ingeniería en Ciencias y Sistemas',
            'codigo': '08-01-01',
            'modalidades': ['Diario', 'Plan Fin de Semana'],
          },
        ],
      };

      final fac = Facultad.fromMap(map);
      expect(fac.id, '08');
      expect(fac.codigo, '08');
      expect(fac.nombre, 'Facultad de Ingeniería');
      expect(fac.sitio, 'https://ingenieria.usac.edu.gt');
      expect(fac.carreras.length, 1);
      expect(fac.carreras.first.id, 'sistemas');
      expect(fac.carreras.first.modalidades, ['Diario', 'Plan Fin de Semana']);
    });

    test('Facultad.fromMap maneja mapa vacío o sin carreras', () {
      final fac = Facultad.fromMap({});
      expect(fac.id, '');
      expect(fac.nombre, '');
      expect(fac.carreras, isEmpty);
    });
  });

  group('Carrera Model', () {
    test('Carrera.fromMap maneja modalidades como lista, string y default', () {
      // 1. Como lista
      final c1 = Carrera.fromMap({
        'id': 'c1',
        'nombre': 'Agronomía',
        'modalidades': ['Matutina', 'Vespertina'],
      });
      expect(c1.modalidades, ['Matutina', 'Vespertina']);

      // 2. Como string único (clave 'modalidad')
      final c2 = Carrera.fromMap({
        'id': 'c2',
        'nombre': 'Derecho',
        'modalidad': 'Nocturna',
      });
      expect(c2.modalidades, ['Nocturna']);

      // 3. Ausente o null -> default ['Diario']
      final c3 = Carrera.fromMap({
        'id': 'c3',
        'nombre': 'Medicina',
      });
      expect(c3.modalidades, ['Diario']);
      expect(c3.sede, 'Campus Central');
    });
  });

  group('SedeUniversitaria Model', () {
    test('SedeUniversitaria.fromMap aplica valores por defecto', () {
      final sede = SedeUniversitaria.fromMap({
        'id': 'cunoc',
        'nombre': 'CUNOC · Quetzaltenango',
      });

      expect(sede.id, 'cunoc');
      expect(sede.nombre, 'CUNOC · Quetzaltenango');
      expect(sede.departamento, 'Guatemala');
      expect(sede.municipio, 'Guatemala');
      expect(sede.tipo, 'extension');
    });

    test('SedeUniversitaria.fromMap con todos los campos provistos', () {
      final sede = SedeUniversitaria.fromMap({
        'id': 'cusam',
        'nombre': 'CUSAM · San Marcos',
        'departamento': 'San Marcos',
        'municipio': 'San Marcos',
        'tipo': 'centro_regional',
      });

      expect(sede.id, 'cusam');
      expect(sede.departamento, 'San Marcos');
      expect(sede.municipio, 'San Marcos');
      expect(sede.tipo, 'centro_regional');
    });
  });

  group('CampusLocation Model', () {
    test('CampusLocation.fromMap parsea coordenadas numéricas y valores por defecto', () {
      final loc = CampusLocation.fromMap({
        'id': 'edificio_t3',
        'nombre': 'Edificio T-3',
        'building_code': 'T-3',
        'latitude': 14.5886,
        'longitude': -90.5516,
        'description': 'Edificio de Ingeniería',
      });

      expect(loc.id, 'edificio_t3');
      expect(loc.nombre, 'Edificio T-3');
      expect(loc.sedeId, 'central');
      expect(loc.buildingCode, 'T-3');
      expect(loc.latitude, 14.5886);
      expect(loc.longitude, -90.5516);
      expect(loc.description, 'Edificio de Ingeniería');
    });

    test('CampusLocation toMap serializa correctamente', () {
      const loc = CampusLocation(
        id: 'biblio_central',
        nombre: 'Biblioteca Central',
        sedeId: 'central',
        buildingCode: 'BIBLIO',
        latitude: 14.5891,
        longitude: -90.5520,
        description: 'Biblioteca principal',
      );

      final map = loc.toMap();
      expect(map['id'], 'biblio_central');
      expect(map['nombre'], 'Biblioteca Central');
      expect(map['sede_id'], 'central');
      expect(map['building_code'], 'BIBLIO');
      expect(map['latitude'], 14.5891);
      expect(map['longitude'], -90.5520);
      expect(map['description'], 'Biblioteca principal');
    });
  });
}
