import 'package:flutter/material.dart';

class ForumServer {
  final String id;
  final String name;
  final String shortCode;
  final IconData icon;
  final String facultadId;
  final String carreraId;
  final String description;
  final Color color;
  final int memberCount;

  const ForumServer({
    required this.id,
    required this.name,
    required this.shortCode,
    required this.icon,
    required this.facultadId,
    required this.carreraId,
    required this.description,
    this.color = const Color(0xFF004B87),
    this.memberCount = 1250,
  });

  /// Popular predefined servers across USAC faculties
  static const List<ForumServer> defaultServers = [
    ForumServer(
      id: 'todas',
      name: 'Campus Central (General)',
      shortCode: 'USAC',
      icon: Icons.school,
      facultadId: 'todas',
      carreraId: 'todas',
      description: 'Servidor global para todas las facultades, escuelas no facultativas y campus central.',
      color: Color(0xFF004B87),
      memberCount: 8520,
    ),
    ForumServer(
      id: 'area_comun',
      name: 'Área Común / Cursos Básicos',
      shortCode: 'BAS',
      icon: Icons.auto_stories,
      facultadId: '08',
      carreraId: 'area_comun',
      description: 'Servidor para ciencias básicas, matemáticas, físicas, químicas y cursos iniciales.',
      color: Color(0xFF2563EB),
      memberCount: 4120,
    ),
    ForumServer(
      id: 'sistemas',
      name: 'Ingeniería en Sistemas',
      shortCode: 'SIST',
      icon: Icons.terminal,
      facultadId: '08',
      carreraId: 'sistemas',
      description: 'Servidor de la Escuela de Ciencias y Sistemas (FIUSAC). Código, proyectos y laboratorios.',
      color: Color(0xFF0284C7),
      memberCount: 3240,
    ),
    ForumServer(
      id: 'civil',
      name: 'Ingeniería Civil',
      shortCode: 'CIV',
      icon: Icons.construction,
      facultadId: '08',
      carreraId: 'civil',
      description: 'Servidor de Ingeniería Civil. Estructuras, topografía, materiales y diseño vial.',
      color: Color(0xFFD97706),
      memberCount: 2190,
    ),
    ForumServer(
      id: 'industrial',
      name: 'Ingeniería Industrial',
      shortCode: 'IND',
      icon: Icons.precision_manufacturing,
      facultadId: '08',
      carreraId: 'industrial',
      description: 'Servidor de Ingeniería Industrial y Mecánica. Producción, logística y operaciones.',
      color: Color(0xFFEA580C),
      memberCount: 1980,
    ),
    ForumServer(
      id: 'medicina',
      name: 'Ciencias Médicas (Medicina)',
      shortCode: 'MED',
      icon: Icons.medical_services,
      facultadId: '05',
      carreraId: 'medicina',
      description: 'Servidor de la Facultad de Ciencias Médicas (CUM). Anatomía, fisiología, clínicas e internado.',
      color: Color(0xFFDC2626),
      memberCount: 3410,
    ),
    ForumServer(
      id: 'derecho',
      name: 'Ciencias Jurídicas y Sociales',
      shortCode: 'DER',
      icon: Icons.gavel,
      facultadId: '04',
      carreraId: 'derecho',
      description: 'Servidor de la Facultad de Derecho (S-2 y S-7). Leyes, códigos, doctrina y clínicas jurídicas.',
      color: Color(0xFF7C3AED),
      memberCount: 3890,
    ),
    ForumServer(
      id: 'arquitectura',
      name: 'Facultad de Arquitectura',
      shortCode: 'ARQ',
      icon: Icons.architecture,
      facultadId: '02',
      carreraId: 'arquitectura',
      description: 'Servidor de Arquitectura y Diseño Gráfico (T-1 y T-2). Proyectos, talleres y planos.',
      color: Color(0xFF059669),
      memberCount: 1670,
    ),
    ForumServer(
      id: 'economicas',
      name: 'Ciencias Económicas',
      shortCode: 'ECON',
      icon: Icons.trending_up,
      facultadId: '03',
      carreraId: 'economicas',
      description: 'Servidor de Auditoría, Administración y Economía (S-3, S-6 y S-9). Contabilidad y finanzas.',
      color: Color(0xFF0D9488),
      memberCount: 2950,
    ),
    ForumServer(
      id: 'agronomia',
      name: 'Facultad de Agronomía',
      shortCode: 'AGRO',
      icon: Icons.eco,
      facultadId: '01',
      carreraId: 'agronomia',
      description: 'Servidor de Agronomía (T-8 y T-9). Recursos naturales, cultivos y gestión ambiental.',
      color: Color(0xFF16A34A),
      memberCount: 1120,
    ),
  ];
}

class ForumChannel {
  final String id;
  final String name;
  final String categoryId;
  final IconData icon;
  final String description;
  final bool isSpecial;

  const ForumChannel({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.icon,
    required this.description,
    this.isSpecial = false,
  });

  /// Default text channels inside each Carrera server
  static const List<ForumChannel> defaultChannels = [
    ForumChannel(
      id: 'todos',
      name: 'todos-los-temas',
      categoryId: 'todos',
      icon: Icons.tag,
      description: 'Visualiza todas las consultas y aportes de esta carrera en un solo lugar.',
    ),
    ForumChannel(
      id: 'prerrequisitos',
      name: 'dudas-y-pensum',
      categoryId: 'prerrequisitos',
      icon: Icons.school_outlined,
      description: 'Consultas sobre créditos, asignaciones, prerrequisitos y cierre de pensum.',
    ),
    ForumChannel(
      id: 'catedraticos',
      name: 'catedraticos-opiniones',
      categoryId: 'catedraticos',
      icon: Icons.record_voice_over_outlined,
      description: 'Experiencias, recomendaciones y estilo de evaluación de docentes y auxiliares.',
    ),
    ForumChannel(
      id: 'apuntes',
      name: 'apuntes-y-recursos',
      categoryId: 'apuntes',
      icon: Icons.folder_shared_outlined,
      description: 'Material de estudio, resúmenes, parciales pasados, libros y guías de laboratorio.',
    ),
    ForumChannel(
      id: 'horarios',
      name: 'horarios-y-secciones',
      categoryId: 'horarios',
      icon: Icons.schedule_outlined,
      description: 'Información de traslapes, cupos, secciones y asignación de laboratorios.',
    ),
    ForumChannel(
      id: 'general',
      name: 'charla-general',
      categoryId: 'general',
      icon: Icons.chat_bubble_outline,
      description: 'Cafetería estudiantil, avisos generales y vida universitaria en la carrera.',
    ),
  ];

  static const ForumChannel bookmarksChannel = ForumChannel(
    id: 'bookmarks',
    name: 'mis-guardados',
    categoryId: 'bookmarks',
    icon: Icons.bookmark_outline,
    description: 'Publicaciones y recursos que has guardado en tus marcadores.',
    isSpecial: true,
  );
}
