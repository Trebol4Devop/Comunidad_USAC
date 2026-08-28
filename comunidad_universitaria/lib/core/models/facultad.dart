class Facultad {
  final String id;
  final String codigo;
  final String nombre;
  final String sitio;
  final List<Carrera> carreras;

  const Facultad({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.sitio,
    required this.carreras,
  });

  factory Facultad.fromMap(Map<String, dynamic> map) {
    final rawCarreras = map['carreras'] as List<dynamic>? ?? [];
    return Facultad(
      id: map['id'] ?? '',
      codigo: map['codigo'] ?? '',
      nombre: map['nombre'] ?? '',
      sitio: map['sitio'] ?? '',
      carreras: rawCarreras
          .map((c) => Carrera.fromMap(Map<String, dynamic>.from(c)))
          .toList(),
    );
  }
}

class Carrera {
  final String id;
  final String nombre;
  final String codigo;
  final String sede;
  final List<String> modalidades;

  const Carrera({
    required this.id,
    required this.nombre,
    this.codigo = '',
    this.sede = 'Campus Central',
    this.modalidades = const ['Diario'],
  });

  factory Carrera.fromMap(Map<String, dynamic> map) {
    List<String> mods = [];
    if (map['modalidades'] is List) {
      mods = (map['modalidades'] as List).map((e) => e.toString()).toList();
    } else if (map['modalidad'] is String) {
      mods = [map['modalidad'] as String];
    } else {
      mods = const ['Diario'];
    }

    return Carrera(
      id: map['id'] ?? '',
      nombre: map['nombre'] ?? '',
      codigo: map['codigo'] ?? '',
      sede: map['sede'] ?? 'Campus Central',
      modalidades: mods,
    );
  }
}

class SedeUniversitaria {
  final String id;
  final String nombre;
  final String departamento;
  final String municipio;
  final String tipo; // 'campus_central', 'metropolitana', 'centro_regional', 'extension'

  const SedeUniversitaria({
    required this.id,
    required this.nombre,
    required this.departamento,
    required this.municipio,
    required this.tipo,
  });

  factory SedeUniversitaria.fromMap(Map<String, dynamic> map) {
    return SedeUniversitaria(
      id: map['id'] ?? '',
      nombre: map['nombre'] ?? '',
      departamento: map['departamento'] ?? 'Guatemala',
      municipio: map['municipio'] ?? 'Guatemala',
      tipo: map['tipo'] ?? 'extension',
    );
  }
}

/// Representa un edificio o punto de encuentro en el campus.
/// Diseñado con soporte de coordenadas para vincularse de forma nativa
/// con futuros mapas interactivos del campus.
class CampusLocation {
  final String id;
  final String nombre;
  final String sedeId;
  final String buildingCode;
  final double? latitude;
  final double? longitude;
  final String? description;

  const CampusLocation({
    required this.id,
    required this.nombre,
    required this.sedeId,
    required this.buildingCode,
    this.latitude,
    this.longitude,
    this.description,
  });

  factory CampusLocation.fromMap(Map<String, dynamic> map) {
    return CampusLocation(
      id: map['id'] ?? '',
      nombre: map['nombre'] ?? '',
      sedeId: map['sede_id'] ?? 'central',
      buildingCode: map['building_code'] ?? '',
      latitude: (map['latitude'] is num) ? (map['latitude'] as num).toDouble() : null,
      longitude: (map['longitude'] is num) ? (map['longitude'] as num).toDouble() : null,
      description: map['description'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'sede_id': sedeId,
      'building_code': buildingCode,
      'latitude': latitude,
      'longitude': longitude,
      'description': description,
    };
  }
}
