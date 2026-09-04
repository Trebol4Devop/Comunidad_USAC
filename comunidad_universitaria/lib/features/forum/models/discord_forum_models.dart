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

  /// Official USAC Faculty servers (Vertical left rail servers)
  static const List<ForumServer> defaultServers = [
    ForumServer(
      id: 'todas',
      name: 'Campus Central (General)',
      shortCode: 'USAC',
      icon: Icons.account_balance,
      facultadId: 'todas',
      carreraId: 'todas',
      description: 'Comunidad universitaria general para todas las facultades, escuelas y sedes.',
      color: Color(0xFF004B87),
      memberCount: 12500,
    ),
    ForumServer(
      id: '01',
      name: 'Facultad de Agronomía',
      shortCode: 'AGRO',
      icon: Icons.eco,
      facultadId: '01',
      carreraId: 'todas',
      description: 'Servidor de la Facultad de Agronomía (FAUSAC). Cultivos, recursos naturales y ambiente.',
      color: Color(0xFF16A34A),
      memberCount: 1850,
    ),
    ForumServer(
      id: '02',
      name: 'Facultad de Arquitectura',
      shortCode: 'ARQ',
      icon: Icons.architecture,
      facultadId: '02',
      carreraId: 'todas',
      description: 'Servidor de la Facultad de Arquitectura (FARUSAC). Diseño gráfico, proyectos y urbanismo.',
      color: Color(0xFF059669),
      memberCount: 2420,
    ),
    ForumServer(
      id: '03',
      name: 'Facultad de Ciencias Económicas',
      shortCode: 'ECON',
      icon: Icons.trending_up,
      facultadId: '03',
      carreraId: 'todas',
      description: 'Servidor de Ciencias Económicas. Auditoría, administración de empresas y economía.',
      color: Color(0xFF0D9488),
      memberCount: 4210,
    ),
    ForumServer(
      id: '04',
      name: 'Facultad de Ciencias Jurídicas y Sociales',
      shortCode: 'DER',
      icon: Icons.gavel,
      facultadId: '04',
      carreraId: 'todas',
      description: 'Servidor de Derecho y Ciencias Jurídicas. Leyes, doctrina y clínicas jurídicas.',
      color: Color(0xFF7C3AED),
      memberCount: 4890,
    ),
    ForumServer(
      id: '05',
      name: 'Facultad de Ciencias Médicas (CUM)',
      shortCode: 'MED',
      icon: Icons.medical_services,
      facultadId: '05',
      carreraId: 'todas',
      description: 'Servidor de Ciencias Médicas. Medicina, enfermería, fisioterapia y clínicas.',
      color: Color(0xFFDC2626),
      memberCount: 3950,
    ),
    ForumServer(
      id: '06',
      name: 'Facultad de Ciencias Químicas y Farmacia',
      shortCode: 'FARM',
      icon: Icons.biotech,
      facultadId: '06',
      carreraId: 'todas',
      description: 'Servidor de Farmacia, Química Biológica, Nutrición y Biología.',
      color: Color(0xFFE11D48),
      memberCount: 1680,
    ),
    ForumServer(
      id: '07',
      name: 'Facultad de Humanidades',
      shortCode: 'HUM',
      icon: Icons.psychology,
      facultadId: '07',
      carreraId: 'todas',
      description: 'Servidor de la Facultad de Humanidades. Pedagogía, letras, filosofía e idiomas.',
      color: Color(0xFFD97706),
      memberCount: 3120,
    ),
    ForumServer(
      id: '08',
      name: 'Facultad de Ingeniería',
      shortCode: 'ING',
      icon: Icons.engineering,
      facultadId: '08',
      carreraId: 'todas',
      description: 'Servidor de la Facultad de Ingeniería (FIUSAC). Todas las escuelas y áreas de ingeniería.',
      color: Color(0xFF0284C7),
      memberCount: 5640,
    ),
    ForumServer(
      id: '09',
      name: 'Facultad de Odontología',
      shortCode: 'ODON',
      icon: Icons.medical_information,
      facultadId: '09',
      carreraId: 'todas',
      description: 'Servidor de la Facultad de Odontología. Clínicas dentales y formación odontológica.',
      color: Color(0xFF4F46E5),
      memberCount: 1320,
    ),
    ForumServer(
      id: '10',
      name: 'Facultad de Medicina Veterinaria y Zootecnia',
      shortCode: 'VET',
      icon: Icons.pets,
      facultadId: '10',
      carreraId: 'todas',
      description: 'Servidor de Veterinaria y Zootecnia (FMVZ). Cuidado animal y producción zootécnica.',
      color: Color(0xFF9333EA),
      memberCount: 1140,
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
