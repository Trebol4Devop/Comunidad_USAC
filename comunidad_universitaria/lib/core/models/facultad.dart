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

  const Carrera({
    required this.id,
    required this.nombre,
  });

  factory Carrera.fromMap(Map<String, dynamic> map) {
    return Carrera(
      id: map['id'] ?? '',
      nombre: map['nombre'] ?? '',
    );
  }
}
