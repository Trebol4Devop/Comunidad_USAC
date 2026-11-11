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
  final int? memberCount;
  final bool isGroups;

  const ForumServer({
    required this.id,
    required this.name,
    required this.shortCode,
    required this.icon,
    required this.facultadId,
    required this.carreraId,
    required this.description,
    this.color = const Color(0xFF004B87),
    this.memberCount,
    this.isGroups = false,
  });

  /// Official Grupos de Estudio / WhatsApp Server
  static const ForumServer groupsServer = ForumServer(
    id: 'grupos_estudio',
    name: 'Grupos de Estudio',
    shortCode: 'GRUPOS',
    icon: Icons.chat,
    facultadId: 'todas',
    carreraId: 'todas',
    description: 'Directorio oficial de grupos de WhatsApp y estudio USAC organizados por facultad y curso.',
    color: Color(0xFF25D366),
    isGroups: true,
  );

  /// Subservidores oficiales de Grupos de Estudio (facultades y áreas)
  static const List<ForumServer> groupsSubservers = [
    ForumServer(
      id: 'groups_todas',
      name: 'Todas las Facultades',
      shortCode: 'TODAS',
      icon: Icons.school,
      facultadId: 'todas',
      carreraId: 'todas',
      description: 'Grupos de estudio y WhatsApp de todas las facultades de la USAC.',
      color: Color(0xFF004B87),
      isGroups: true,
    ),
    ForumServer(
      id: 'groups_humanidades',
      name: 'Facultad de Humanidades',
      shortCode: 'HUM',
      icon: Icons.psychology,
      facultadId: '07',
      carreraId: 'todas',
      description: 'Grupos de estudio para profesorados, pedagogía y licenciaturas de Humanidades.',
      color: Color(0xFFD97706),
      isGroups: true,
    ),
    ForumServer(
      id: 'groups_medicina',
      name: 'Médico y Cirujano',
      shortCode: 'MED',
      icon: Icons.medical_services,
      facultadId: '05',
      carreraId: '05-00-01',
      description: 'Grupos de WhatsApp de materias clínicas, ciencias básicas y años de Medicina.',
      color: Color(0xFFDC2626),
      isGroups: true,
    ),
    ForumServer(
      id: 'groups_veterinaria',
      name: 'Medicina Veterinaria y Zootecnia',
      shortCode: 'VET',
      icon: Icons.pets,
      facultadId: '10',
      carreraId: 'todas',
      description: 'Grupos de WhatsApp para Medicina Veterinaria y Zootecnia.',
      color: Color(0xFF9333EA),
      isGroups: true,
    ),
    ForumServer(
      id: 'groups_odontologia',
      name: 'Facultad de Odontología',
      shortCode: 'ODON',
      icon: Icons.healing,
      facultadId: '09',
      carreraId: 'todas',
      description: 'Grupos de WhatsApp para cursos y clínicas dentales de Odontología.',
      color: Color(0xFF4F46E5),
      isGroups: true,
    ),
    ForumServer(
      id: 'groups_ingenieria',
      name: 'Facultad de Ingeniería',
      shortCode: 'ING',
      icon: Icons.engineering,
      facultadId: '08',
      carreraId: 'todas',
      description: 'Grupos de WhatsApp de cursos de Área Común y carreras de Ingeniería.',
      color: Color(0xFF0284C7),
      isGroups: true,
    ),
    ForumServer(
      id: 'groups_quimica_farmacia',
      name: 'Ciencias Químicas y Farmacéuticas',
      shortCode: 'FARM',
      icon: Icons.biotech,
      facultadId: '06',
      carreraId: 'todas',
      description: 'Grupos de WhatsApp de Química, Farmacia, Biología, Nutrición y Química Biológica.',
      color: Color(0xFFE11D48),
      isGroups: true,
    ),
    ForumServer(
      id: 'groups_ciencias_medicas',
      name: 'Facultad de Ciencias Médicas',
      shortCode: 'CMED',
      icon: Icons.health_and_safety,
      facultadId: '05',
      carreraId: 'todas',
      description: 'Grupos de WhatsApp de la Facultad de Ciencias Médicas, enfermería y fisioterapia.',
      color: Color(0xFFDC2626),
      isGroups: true,
    ),
    ForumServer(
      id: 'groups_derecho',
      name: 'Ciencias Jurídicas y Sociales',
      shortCode: 'DER',
      icon: Icons.gavel,
      facultadId: '04',
      carreraId: 'todas',
      description: 'Grupos de WhatsApp de Ciencias Jurídicas y Sociales.',
      color: Color(0xFF7C3AED),
      isGroups: true,
    ),
    ForumServer(
      id: 'groups_economicas',
      name: 'Facultad de Ciencias Económicas',
      shortCode: 'ECON',
      icon: Icons.trending_up,
      facultadId: '03',
      carreraId: 'todas',
      description: 'Grupos de WhatsApp de Contaduría Pública y Auditoría, Administración y Economía.',
      color: Color(0xFF0D9488),
      isGroups: true,
    ),
    ForumServer(
      id: 'groups_arquitectura',
      name: 'Facultad de Arquitectura',
      shortCode: 'ARQ',
      icon: Icons.architecture,
      facultadId: '02',
      carreraId: 'todas',
      description: 'Grupos de WhatsApp de Licenciatura en Arquitectura y Diseño Gráfico.',
      color: Color(0xFF059669),
      isGroups: true,
    ),
    ForumServer(
      id: 'groups_agronomia',
      name: 'Facultad de Agronomía',
      shortCode: 'AGRO',
      icon: Icons.eco,
      facultadId: '01',
      carreraId: 'todas',
      description: 'Grupos de WhatsApp de Sistemas de Producción Agrícola y Recursos Naturales.',
      color: Color(0xFF16A34A),
      isGroups: true,
    ),
  ];

  /// Popular predefined servers across USAC faculties aligned with database
  static const List<ForumServer> defaultServers = [
    ForumServer(
      id: 'todas',
      name: 'Todas las Facultades',
      shortCode: 'USAC',
      icon: Icons.school,
      facultadId: 'todas',
      carreraId: 'todas',
      description: 'Espacio general para todas las facultades, escuelas y sedes.',
      color: Color(0xFF004B87),
    ),
    groupsServer,
    ForumServer(
      id: 'area_comun',
      name: 'Área Común',
      shortCode: 'BAS',
      icon: Icons.auto_stories,
      facultadId: '08',
      carreraId: 'area_comun',
      description: 'Ciencias básicas, matemáticas, físicas y químicas de primeros semestres.',
      color: Color(0xFF0284C7),
    ),
    ForumServer(
      id: 'sistemas',
      name: 'Ingeniería en Sistemas',
      shortCode: 'SIST',
      icon: Icons.terminal,
      facultadId: '08',
      carreraId: 'sistemas',
      description: 'Escuela de Ciencias y Sistemas. Programación, proyectos y tecnología.',
      color: Color(0xFF0284C7),
    ),
    ForumServer(
      id: 'civil',
      name: 'Ingeniería Civil',
      shortCode: 'CIV',
      icon: Icons.construction,
      facultadId: '08',
      carreraId: 'civil',
      description: 'Estructuras, topografía, materiales y diseño vial.',
      color: Color(0xFFD97706),
    ),
    ForumServer(
      id: 'industrial',
      name: 'Ingeniería Industrial',
      shortCode: 'IND',
      icon: Icons.precision_manufacturing,
      facultadId: '08',
      carreraId: 'industrial',
      description: 'Producción, logística, procesos y operaciones.',
      color: Color(0xFFEA580C),
    ),
    ForumServer(
      id: 'medicina',
      name: 'Ciencias Médicas',
      shortCode: 'MED',
      icon: Icons.medical_services,
      facultadId: '05',
      carreraId: '05-00-01',
      description: 'Anatomía, fisiología, materias clínicas e internado.',
      color: Color(0xFFDC2626),
    ),
    ForumServer(
      id: 'derecho',
      name: 'Ciencias Jurídicas y Sociales',
      shortCode: 'DER',
      icon: Icons.gavel,
      facultadId: '04',
      carreraId: '04-00-01',
      description: 'Leyes, doctrina, ramas del derecho y clínicas jurídicas.',
      color: Color(0xFF7C3AED),
    ),
    ForumServer(
      id: 'arquitectura',
      name: 'Facultad de Arquitectura',
      shortCode: 'ARQ',
      icon: Icons.architecture,
      facultadId: '02',
      carreraId: '02-00-01',
      description: 'Arquitectura, diseño, talleres y proyectos.',
      color: Color(0xFF059669),
    ),
    ForumServer(
      id: 'economicas',
      name: 'Ciencias Económicas',
      shortCode: 'ECON',
      icon: Icons.trending_up,
      facultadId: '03',
      carreraId: '03-00-01',
      description: 'Auditoría, administración, contabilidad y finanzas.',
      color: Color(0xFF0D9488),
    ),
    ForumServer(
      id: 'agronomia',
      name: 'Facultad de Agronomía',
      shortCode: 'AGRO',
      icon: Icons.eco,
      facultadId: '01',
      carreraId: '01-00-02',
      description: 'Recursos naturales, producción agrícola y gestión ambiental.',
      color: Color(0xFF16A34A),
    ),
  ];
}

class ForumChannel {
  final String id;
  final String name;
  final String label;
  final String categoryId;
  final IconData icon;
  final String description;
  final bool isSpecial;

  const ForumChannel({
    required this.id,
    required this.name,
    this.label = '',
    required this.categoryId,
    required this.icon,
    required this.description,
    this.isSpecial = false,
  });

  /// Factory that builds a ForumChannel directly from a `categorias_foro` database record
  static ForumChannel fromDbCategory({required String id, required String nombre}) {
    switch (id) {
      case 'todos':
        return ForumChannel(
          id: id,
          name: 'todos-los-temas',
          label: nombre,
          categoryId: id,
          icon: Icons.tag,
          description: 'Visualiza todas las consultas y aportes de esta carrera en un solo lugar.',
        );
      case 'prerrequisitos':
        return ForumChannel(
          id: id,
          name: 'dudas-y-pensum',
          label: nombre,
          categoryId: id,
          icon: Icons.school_outlined,
          description: 'Consultas sobre créditos, asignaciones, prerrequisitos y cierre de pensum.',
        );
      case 'catedraticos':
        return ForumChannel(
          id: id,
          name: 'catedraticos-opiniones',
          label: nombre,
          categoryId: id,
          icon: Icons.record_voice_over_outlined,
          description: 'Experiencias, recomendaciones y estilo de evaluación de docentes y auxiliares.',
        );
      case 'apuntes':
        return ForumChannel(
          id: id,
          name: 'apuntes-y-recursos',
          label: nombre,
          categoryId: id,
          icon: Icons.folder_shared_outlined,
          description: 'Material de estudio, resúmenes, parciales pasados, libros y guías de laboratorio.',
        );
      case 'horarios':
        return ForumChannel(
          id: id,
          name: 'horarios-y-secciones',
          label: nombre,
          categoryId: id,
          icon: Icons.schedule_outlined,
          description: 'Información de traslapes, cupos, secciones y asignación de laboratorios.',
        );
      case 'general':
        return ForumChannel(
          id: id,
          name: 'charla-general',
          label: nombre,
          categoryId: id,
          icon: Icons.chat_bubble_outline,
          description: 'Cafetería estudiantil, avisos generales y vida universitaria en la carrera.',
        );
      default:
        final slug = id.replaceAll('_', '-').toLowerCase();
        return ForumChannel(
          id: id,
          name: slug,
          label: nombre,
          categoryId: id,
          icon: Icons.tag,
          description: nombre,
        );
    }
  }

  /// Default text channels inside each Carrera server based on DB `categorias_foro`
  static const List<ForumChannel> defaultChannels = [
    ForumChannel(
      id: 'todos',
      name: 'todos-los-temas',
      label: 'Todas las áreas',
      categoryId: 'todos',
      icon: Icons.tag,
      description: 'Visualiza todas las consultas y aportes de esta carrera en un solo lugar.',
    ),
    ForumChannel(
      id: 'prerrequisitos',
      name: 'dudas-y-pensum',
      label: 'Prerrequisitos & Pensum',
      categoryId: 'prerrequisitos',
      icon: Icons.school_outlined,
      description: 'Consultas sobre créditos, asignaciones, prerrequisitos y cierre de pensum.',
    ),
    ForumChannel(
      id: 'catedraticos',
      name: 'catedraticos-opiniones',
      label: 'Catedráticos & Auxiliares',
      categoryId: 'catedraticos',
      icon: Icons.record_voice_over_outlined,
      description: 'Experiencias, recomendaciones y estilo de evaluación de docentes y auxiliares.',
    ),
    ForumChannel(
      id: 'apuntes',
      name: 'apuntes-y-recursos',
      label: 'Apuntes & Exámenes',
      categoryId: 'apuntes',
      icon: Icons.folder_shared_outlined,
      description: 'Material de estudio, resúmenes, parciales pasados, libros y guías de laboratorio.',
    ),
    ForumChannel(
      id: 'horarios',
      name: 'horarios-y-secciones',
      label: 'Horarios & Secciones',
      categoryId: 'horarios',
      icon: Icons.schedule_outlined,
      description: 'Información de traslapes, cupos, secciones y asignación de laboratorios.',
    ),
  ];

  static const ForumChannel bookmarksChannel = ForumChannel(
    id: 'bookmarks',
    name: 'mis-guardados',
    label: 'Marcadores',
    categoryId: 'bookmarks',
    icon: Icons.bookmark_outline,
    description: 'Publicaciones y recursos que has guardado en tus marcadores.',
    isSpecial: true,
  );

  /// Official Channels for Grupos de Estudio server based on DB `facultades`
  static const List<ForumChannel> groupsChannels = [
    ForumChannel(
      id: 'todas',
      name: 'todos-los-grupos',
      label: 'Todas las Facultades',
      categoryId: 'todas',
      icon: Icons.tag,
      description: 'Directorio completo de grupos de WhatsApp de todas las facultades.',
    ),
    ForumChannel(
      id: '08',
      name: 'ingenieria',
      label: 'Facultad de Ingeniería',
      categoryId: '08',
      icon: Icons.terminal,
      description: 'Grupos de WhatsApp para cursos y carreras de Ingeniería.',
    ),
    ForumChannel(
      id: '05',
      name: 'ciencias-medicas',
      label: 'Ciencias Médicas',
      categoryId: '05',
      icon: Icons.medical_services,
      description: 'Grupos de WhatsApp de Medicina y carreras afines.',
    ),
    ForumChannel(
      id: '03',
      name: 'ciencias-economicas',
      label: 'Ciencias Económicas',
      categoryId: '03',
      icon: Icons.trending_up,
      description: 'Grupos de WhatsApp para Auditoría, Administración y Economía.',
    ),
    ForumChannel(
      id: '04',
      name: 'ciencias-juridicas',
      label: 'Ciencias Jurídicas y Sociales',
      categoryId: '04',
      icon: Icons.gavel,
      description: 'Grupos de WhatsApp de Derecho y Ciencias Jurídicas.',
    ),
    ForumChannel(
      id: '02',
      name: 'arquitectura',
      label: 'Facultad de Arquitectura',
      categoryId: '02',
      icon: Icons.architecture,
      description: 'Grupos de WhatsApp para Arquitectura y Diseño Gráfico.',
    ),
    ForumChannel(
      id: '01',
      name: 'agronomia',
      label: 'Facultad de Agronomía',
      categoryId: '01',
      icon: Icons.eco,
      description: 'Grupos de WhatsApp para Recursos Naturales y Agronomía.',
    ),
    ForumChannel(
      id: '06',
      name: 'quimica-y-farmacia',
      label: 'Ciencias Químicas y Farmacia',
      categoryId: '06',
      icon: Icons.biotech,
      description: 'Grupos de WhatsApp de Química, Farmacia y Biología.',
    ),
    ForumChannel(
      id: '77',
      name: 'humanidades',
      label: 'Facultad de Humanidades',
      categoryId: '77',
      icon: Icons.menu_book,
      description: 'Grupos de WhatsApp para Profesorados y Pedagogía.',
    ),
    ForumChannel(
      id: '09',
      name: 'odontologia',
      label: 'Facultad de Odontología',
      categoryId: '09',
      icon: Icons.healing,
      description: 'Grupos de WhatsApp para materias y clínicas de Odontología.',
    ),
    ForumChannel(
      id: '10',
      name: 'veterinaria',
      label: 'Veterinaria y Zootecnia',
      categoryId: '10',
      icon: Icons.pets,
      description: 'Grupos de WhatsApp para Medicina Veterinaria y Zootecnia.',
    ),
  ];

  /// Builds groups channels dynamically from database faculties
  static List<ForumChannel> groupsChannelsFromFaculties(List<ForumFaculty> faculties) {
    if (faculties.isEmpty) return groupsChannels;
    final List<ForumChannel> list = [];
    for (final f in faculties) {
      final slug = f.id == 'todas'
          ? 'todos-los-grupos'
          : f.name
              .toLowerCase()
              .replaceAll('facultad de ', '')
              .replaceAll('ciencias ', 'ciencias-')
              .replaceAll(' ', '-')
              .replaceAll('á', 'a')
              .replaceAll('é', 'e')
              .replaceAll('í', 'i')
              .replaceAll('ó', 'o')
              .replaceAll('ú', 'u')
              .replaceAll('ñ', 'n');

      list.add(
        ForumChannel(
          id: f.id,
          name: slug,
          label: f.name,
          categoryId: f.id,
          icon: f.icon,
          description: 'Grupos de WhatsApp de ${f.name}.',
        ),
      );
    }
    return list;
  }

  /// Construye los canales (categorías / carreras) correspondientes a cada subservidor de grupos
  static List<ForumChannel> groupsChannelsForSubserver(
    ForumServer server,
    List<ForumFaculty> faculties,
  ) {
    if (server.id == 'groups_medicina') {
      return const [
        ForumChannel(
          id: 'todas',
          name: 'todos-los-grupos',
          label: 'Todos los Grupos de Medicina',
          categoryId: 'todas',
          icon: Icons.tag,
          description: 'Todos los grupos de estudio de Médico y Cirujano.',
        ),
        ForumChannel(
          id: '05-00-01',
          name: 'medico-y-cirujano',
          label: 'Médico y Cirujano',
          categoryId: '05-00-01',
          icon: Icons.medical_services,
          description: 'Grupos de estudio para Médico y Cirujano.',
        ),
      ];
    }

    if (server.facultadId == 'todas') {
      return const [
        ForumChannel(
          id: 'todas',
          name: 'todos-los-grupos',
          label: 'Todas las Facultades',
          categoryId: 'todas',
          icon: Icons.tag,
          description: 'Directorio completo de grupos de WhatsApp de todas las facultades.',
        ),
      ];
    }

    // Buscamos la facultad correspondiente
    final fac = faculties.firstWhere(
      (f) => f.id == server.facultadId,
      orElse: () => ForumFaculty.defaultFaculties.firstWhere(
        (f) => f.id == server.facultadId,
        orElse: () => ForumFaculty.defaultFaculties.first,
      ),
    );

    final List<ForumChannel> list = [
      ForumChannel(
        id: 'todas',
        name: 'todos-los-grupos',
        label: 'Todos los Grupos',
        categoryId: 'todas',
        icon: Icons.tag,
        description: 'Todos los grupos de WhatsApp y estudio de ${fac.name}.',
      ),
    ];

    for (final career in fac.careers) {
      if (career.id == 'todas') continue;

      final slug = career.name
          .toLowerCase()
          .replaceAll('licenciatura en ', '')
          .replaceAll('ingeniería en ', '')
          .replaceAll('ingeniería ', '')
          .replaceAll('pem en ', '')
          .replaceAll('técnico en ', '')
          .replaceAll('técnico de ', '')
          .replaceAll('profesorado en ', '')
          .replaceAll('ciencias y ', '')
          .replaceAll(' ', '-')
          .replaceAll('á', 'a')
          .replaceAll('é', 'e')
          .replaceAll('í', 'i')
          .replaceAll('ó', 'o')
          .replaceAll('ú', 'u')
          .replaceAll('ñ', 'n')
          .replaceAll(RegExp(r'[^a-z0-9\-]'), '');

      list.add(
        ForumChannel(
          id: career.id,
          name: slug.isEmpty ? career.shortCode.toLowerCase() : slug,
          label: career.name,
          categoryId: career.id,
          icon: career.icon,
          description: 'Grupos de WhatsApp para ${career.name}.',
        ),
      );
    }

    return list;
  }
}

class ForumFaculty {
  final String id;
  final String name;
  final String shortCode;
  final IconData icon;
  final Color color;
  final List<ForumCareerItem> careers;

  const ForumFaculty({
    required this.id,
    required this.name,
    required this.shortCode,
    required this.icon,
    required this.color,
    required this.careers,
  });

  ForumFaculty copyWith({
    String? id,
    String? name,
    String? shortCode,
    IconData? icon,
    Color? color,
    List<ForumCareerItem>? careers,
  }) {
    return ForumFaculty(
      id: id ?? this.id,
      name: name ?? this.name,
      shortCode: shortCode ?? this.shortCode,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      careers: careers ?? this.careers,
    );
  }

  ForumServer toGeneralServer() {
    return ForumServer(
      id: id == 'todas' ? 'todas' : 'fac_$id',
      name: id == 'todas' ? 'Todas las Facultades' : name,
      shortCode: shortCode,
      icon: icon,
      facultadId: id,
      carreraId: 'todas',
      description: 'Espacio de discusión e intercambio para $name.',
      color: color,
    );
  }

  static ForumFaculty? findByFacultadId(String facultadId) {
    try {
      return defaultFaculties.firstWhere((f) => f.id == facultadId);
    } catch (_) {
      return null;
    }
  }

  static const List<ForumFaculty> defaultFaculties = [
    ForumFaculty(
      id: 'todas',
      name: 'Todas las Facultades',
      shortCode: 'USAC',
      icon: Icons.school,
      color: Color(0xFF004B87),
      careers: [
        ForumCareerItem(
          id: 'todas',
          name: 'Todas las Carreras',
          shortCode: 'USAC',
          icon: Icons.school,
          facultadId: 'todas',
        ),
      ],
    ),
    ForumFaculty(
      id: '01',
      name: 'Facultad de Agronomía',
      shortCode: 'AGRO',
      icon: Icons.eco,
      color: Color(0xFF16A34A),
      careers: [
        ForumCareerItem(
          id: '01-00-02',
          name: 'Sistemas de Producción Agrícola',
          shortCode: 'PROD',
          icon: Icons.agriculture,
          facultadId: '01',
        ),
        ForumCareerItem(
          id: '01-00-03',
          name: 'Recursos Naturales Renovables',
          shortCode: 'RNAT',
          icon: Icons.forest,
          facultadId: '01',
        ),
        ForumCareerItem(
          id: '01-00-04',
          name: 'Industrias Agropecuarias y Forestales',
          shortCode: 'FORE',
          icon: Icons.park,
          facultadId: '01',
        ),
        ForumCareerItem(
          id: '01-00-07',
          name: 'Gestión Ambiental Local',
          shortCode: 'AMBL',
          icon: Icons.nature_people,
          facultadId: '01',
        ),
      ],
    ),
    ForumFaculty(
      id: '02',
      name: 'Facultad de Arquitectura',
      shortCode: 'ARQ',
      icon: Icons.architecture,
      color: Color(0xFF059669),
      careers: [
        ForumCareerItem(
          id: '02-00-01',
          name: 'Licenciatura en Arquitectura',
          shortCode: 'ARQT',
          icon: Icons.home_work,
          facultadId: '02',
        ),
        ForumCareerItem(
          id: '02-00-03',
          name: 'Licenciatura en Diseño Gráfico',
          shortCode: 'DG',
          icon: Icons.palette,
          facultadId: '02',
        ),
      ],
    ),
    ForumFaculty(
      id: '03',
      name: 'Facultad de Ciencias Económicas',
      shortCode: 'ECON',
      icon: Icons.trending_up,
      color: Color(0xFF0D9488),
      careers: [
        ForumCareerItem(
          id: '03-00-01',
          name: 'Contaduría Pública y Auditoría',
          shortCode: 'CPA',
          icon: Icons.calculate,
          facultadId: '03',
        ),
        ForumCareerItem(
          id: '03-00-02',
          name: 'Licenciatura en Economía',
          shortCode: 'ECON',
          icon: Icons.query_stats,
          facultadId: '03',
        ),
        ForumCareerItem(
          id: '03-00-03',
          name: 'Administración de Empresas',
          shortCode: 'ADM',
          icon: Icons.business_center,
          facultadId: '03',
        ),
        ForumCareerItem(
          id: '03-02-01',
          name: 'CPA - Extensión',
          shortCode: 'CPA-E',
          icon: Icons.domain,
          facultadId: '03',
        ),
        ForumCareerItem(
          id: '03-02-02',
          name: 'Economía - Extensión',
          shortCode: 'EC-EX',
          icon: Icons.show_chart,
          facultadId: '03',
        ),
        ForumCareerItem(
          id: '03-02-03',
          name: 'Administración - Extensión',
          shortCode: 'AD-EX',
          icon: Icons.store,
          facultadId: '03',
        ),
      ],
    ),
    ForumFaculty(
      id: '04',
      name: 'Ciencias Jurídicas y Sociales',
      shortCode: 'DER',
      icon: Icons.gavel,
      color: Color(0xFF7C3AED),
      careers: [
        ForumCareerItem(
          id: '04-00-01',
          name: 'Ciencias Jurídicas y Sociales',
          shortCode: 'ABOG',
          icon: Icons.balance,
          facultadId: '04',
        ),
      ],
    ),
    ForumFaculty(
      id: '05',
      name: 'Facultad de Ciencias Médicas',
      shortCode: 'MED',
      icon: Icons.medical_services,
      color: Color(0xFFDC2626),
      careers: [
        ForumCareerItem(
          id: '05-00-01',
          name: 'Médico y Cirujano',
          shortCode: 'MED',
          icon: Icons.health_and_safety,
          facultadId: '05',
        ),
        ForumCareerItem(
          id: '05-01-03',
          name: 'Técnico de Enfermería',
          shortCode: 'ENF',
          icon: Icons.vaccines,
          facultadId: '05',
        ),
        ForumCareerItem(
          id: '05-04-04',
          name: 'Técnico de Fisioterapia',
          shortCode: 'FIS',
          icon: Icons.accessibility_new,
          facultadId: '05',
        ),
        ForumCareerItem(
          id: '05-05-05',
          name: 'Terapia Respiratoria',
          shortCode: 'RESP',
          icon: Icons.air,
          facultadId: '05',
        ),
        ForumCareerItem(
          id: '05-02-03',
          name: 'Enfermería - Quetzaltenango',
          shortCode: 'EN-X',
          icon: Icons.local_hospital,
          facultadId: '05',
        ),
        ForumCareerItem(
          id: '05-03-03',
          name: 'Enfermería - Cobán',
          shortCode: 'EN-C',
          icon: Icons.local_hospital,
          facultadId: '05',
        ),
      ],
    ),
    ForumFaculty(
      id: '06',
      name: 'Ciencias Químicas y Farmacia',
      shortCode: 'FARM',
      icon: Icons.biotech,
      color: Color(0xFFE11D48),
      careers: [
        ForumCareerItem(
          id: '06-00-01',
          name: 'Licenciatura en Química',
          shortCode: 'QUIM',
          icon: Icons.science,
          facultadId: '06',
        ),
        ForumCareerItem(
          id: '06-00-02',
          name: 'Química Biológica',
          shortCode: 'QB',
          icon: Icons.coronavirus,
          facultadId: '06',
        ),
        ForumCareerItem(
          id: '06-00-03',
          name: 'Química Farmacéutica',
          shortCode: 'QF',
          icon: Icons.medication,
          facultadId: '06',
        ),
        ForumCareerItem(
          id: '06-00-04',
          name: 'Licenciatura en Biología',
          shortCode: 'BIOL',
          icon: Icons.bug_report,
          facultadId: '06',
        ),
        ForumCareerItem(
          id: '06-00-05',
          name: 'Licenciatura en Nutrición',
          shortCode: 'NUTR',
          icon: Icons.restaurant,
          facultadId: '06',
        ),
      ],
    ),
    ForumFaculty(
      id: '07',
      name: 'Facultad de Humanidades',
      shortCode: 'HUM',
      icon: Icons.psychology,
      color: Color(0xFFD97706),
      careers: [
        ForumCareerItem(
          id: '77-00-55',
          name: 'Pedagogía y Admón. Educativa',
          shortCode: 'PAE',
          icon: Icons.menu_book,
          facultadId: '07',
        ),
        ForumCareerItem(
          id: '77-00-18',
          name: 'Pedagogía, DDHH y Cultura de Paz',
          shortCode: 'DDHH',
          icon: Icons.volunteer_activism,
          facultadId: '07',
        ),
        ForumCareerItem(
          id: '77-00-28',
          name: 'Pedagogía y Ciencias Sociales',
          shortCode: 'PCS',
          icon: Icons.groups,
          facultadId: '07',
        ),
        ForumCareerItem(
          id: '77-00-23',
          name: 'PEM en Idioma Inglés',
          shortCode: 'INGL',
          icon: Icons.translate,
          facultadId: '07',
        ),
        ForumCareerItem(
          id: '77-00-78',
          name: 'Pedagogía y Ciencias Naturales',
          shortCode: 'PCN',
          icon: Icons.eco,
          facultadId: '07',
        ),
        ForumCareerItem(
          id: '77-00-17',
          name: 'Ciencias Económico Contables',
          shortCode: 'CEC',
          icon: Icons.receipt_long,
          facultadId: '07',
        ),
        ForumCareerItem(
          id: '77-00-74',
          name: 'Educación Intercultural',
          shortCode: 'INTC',
          icon: Icons.public,
          facultadId: '07',
        ),
        ForumCareerItem(
          id: '77-00-26',
          name: 'Artes Plásticas e Historia del Arte',
          shortCode: 'ARTE',
          icon: Icons.brush,
          facultadId: '07',
        ),
        ForumCareerItem(
          id: '77-00-27',
          name: 'Educación Musical',
          shortCode: 'MUS',
          icon: Icons.music_note,
          facultadId: '07',
        ),
        ForumCareerItem(
          id: '77-00-46',
          name: 'Licenciatura en Filosofía',
          shortCode: 'FILO',
          icon: Icons.auto_stories,
          facultadId: '07',
        ),
        ForumCareerItem(
          id: '77-00-07',
          name: 'Licenciatura en Arte',
          shortCode: 'L-ART',
          icon: Icons.color_lens,
          facultadId: '07',
        ),
        ForumCareerItem(
          id: '77-00-53',
          name: 'Ciencias Información Documental',
          shortCode: 'DOCU',
          icon: Icons.folder_shared,
          facultadId: '07',
        ),
        ForumCareerItem(
          id: '77-00-67',
          name: 'Investigación Educativa',
          shortCode: 'INVE',
          icon: Icons.find_in_page,
          facultadId: '07',
        ),
      ],
    ),
    ForumFaculty(
      id: '08',
      name: 'Facultad de Ingeniería',
      shortCode: 'ING',
      icon: Icons.engineering,
      color: Color(0xFF0284C7),
      careers: [
        ForumCareerItem(
          id: 'area_comun',
          name: 'Área Común',
          shortCode: 'BAS',
          icon: Icons.auto_stories,
          facultadId: '08',
        ),
        ForumCareerItem(
          id: 'sistemas',
          name: 'Ingeniería en Ciencias y Sistemas',
          shortCode: 'SIST',
          icon: Icons.terminal,
          facultadId: '08',
        ),
        ForumCareerItem(
          id: 'civil',
          name: 'Ingeniería Civil',
          shortCode: 'CIV',
          icon: Icons.construction,
          facultadId: '08',
        ),
        ForumCareerItem(
          id: 'industrial',
          name: 'Ingeniería Industrial',
          shortCode: 'IND',
          icon: Icons.precision_manufacturing,
          facultadId: '08',
        ),
        ForumCareerItem(
          id: 'quimica',
          name: 'Ingeniería Química',
          shortCode: 'QUIM',
          icon: Icons.science,
          facultadId: '08',
        ),
        ForumCareerItem(
          id: 'mecanica',
          name: 'Ingeniería Mecánica',
          shortCode: 'MEC',
          icon: Icons.settings,
          facultadId: '08',
        ),
        ForumCareerItem(
          id: 'electrica',
          name: 'Ingeniería Eléctrica',
          shortCode: 'ELEC',
          icon: Icons.bolt,
          facultadId: '08',
        ),
        ForumCareerItem(
          id: 'electronica',
          name: 'Ingeniería Electrónica',
          shortCode: 'ELET',
          icon: Icons.memory,
          facultadId: '08',
        ),
        ForumCareerItem(
          id: 'mecanica_industrial',
          name: 'Mecánica Industrial',
          shortCode: 'ME-IN',
          icon: Icons.handyman,
          facultadId: '08',
        ),
        ForumCareerItem(
          id: 'mecanica_electrica',
          name: 'Mecánica Eléctrica',
          shortCode: 'ME-EL',
          icon: Icons.offline_bolt,
          facultadId: '08',
        ),
        ForumCareerItem(
          id: 'ambiental',
          name: 'Ingeniería Ambiental',
          shortCode: 'AMB',
          icon: Icons.forest,
          facultadId: '08',
        ),
      ],
    ),
    ForumFaculty(
      id: '09',
      name: 'Facultad de Odontología',
      shortCode: 'ODON',
      icon: Icons.medical_information,
      color: Color(0xFF4F46E5),
      careers: [
        ForumCareerItem(
          id: '09-00-01',
          name: 'Cirujano Dentista',
          shortCode: 'DENT',
          icon: Icons.sentiment_very_satisfied,
          facultadId: '09',
        ),
      ],
    ),
    ForumFaculty(
      id: '10',
      name: 'Medicina Veterinaria y Zootecnia',
      shortCode: 'VET',
      icon: Icons.pets,
      color: Color(0xFF9333EA),
      careers: [
        ForumCareerItem(
          id: '10-00-02',
          name: 'Medicina Veterinaria',
          shortCode: 'MVET',
          icon: Icons.cruelty_free,
          facultadId: '10',
        ),
        ForumCareerItem(
          id: '10-00-03',
          name: 'Zootecnia',
          shortCode: 'ZOOT',
          icon: Icons.grass,
          facultadId: '10',
        ),
      ],
    ),
  ];
}

class ForumCareerItem {
  final String id;
  final String name;
  final String shortCode;
  final IconData icon;
  final String facultadId;
  final String codigo;

  const ForumCareerItem({
    required this.id,
    required this.name,
    required this.shortCode,
    required this.icon,
    required this.facultadId,
    this.codigo = '',
  });

  ForumCareerItem copyWith({
    String? id,
    String? name,
    String? shortCode,
    IconData? icon,
    String? facultadId,
    String? codigo,
  }) {
    return ForumCareerItem(
      id: id ?? this.id,
      name: name ?? this.name,
      shortCode: shortCode ?? this.shortCode,
      icon: icon ?? this.icon,
      facultadId: facultadId ?? this.facultadId,
      codigo: codigo ?? this.codigo,
    );
  }

  ForumServer toServer({required Color facultyColor}) {
    return ForumServer(
      id: '${facultadId}_$id',
      name: name,
      shortCode: shortCode,
      icon: icon,
      facultadId: facultadId,
      carreraId: id,
      description: 'Espacio de discusión e intercambio para $name.',
      color: facultyColor,
    );
  }
}

class PopularServerItem {
  final ForumServer server;
  final String facultyName;
  final int postCount;
  final int likesCount;
  final double score;
  final DateTime? latestPostDate;

  const PopularServerItem({
    required this.server,
    required this.facultyName,
    required this.postCount,
    required this.likesCount,
    required this.score,
    this.latestPostDate,
  });

  static List<PopularServerItem> defaultPopularServers() {
    return [
      PopularServerItem(
        server: ForumServer(
          id: 'server_sistemas',
          name: 'Ingeniería en Ciencias y Sistemas',
          shortCode: 'SIST',
          icon: Icons.terminal,
          facultadId: '08',
          carreraId: 'sistemas',
          description: 'Espacio de discusión para Ingeniería en Ciencias y Sistemas.',
          color: const Color(0xFF0284C7),
        ),
        facultyName: 'Facultad de Ingeniería',
        postCount: 48,
        likesCount: 230,
        score: 211.0,
      ),
      PopularServerItem(
        server: ForumServer(
          id: 'server_05-00-01',
          name: 'Médico y Cirujano',
          shortCode: 'MED',
          icon: Icons.medical_services,
          facultadId: '05',
          carreraId: '05-00-01',
          description: 'Espacio de discusión para Médico y Cirujano.',
          color: const Color(0xFFDC2626),
        ),
        facultyName: 'Ciencias Médicas',
        postCount: 39,
        likesCount: 185,
        score: 170.5,
      ),
      PopularServerItem(
        server: ForumServer(
          id: 'server_04-00-01',
          name: 'Ciencias Jurídicas y Sociales',
          shortCode: 'ABOG',
          icon: Icons.balance,
          facultadId: '04',
          carreraId: '04-00-01',
          description: 'Espacio de discusión para Ciencias Jurídicas y Sociales.',
          color: const Color(0xFF7C3AED),
        ),
        facultyName: 'Ciencias Jurídicas y Sociales',
        postCount: 32,
        likesCount: 142,
        score: 135.0,
      ),
      PopularServerItem(
        server: ForumServer(
          id: 'server_area_comun',
          name: 'Área Común',
          shortCode: 'BAS',
          icon: Icons.auto_stories,
          facultadId: '08',
          carreraId: 'area_comun',
          description: 'Espacio de discusión para Área Común.',
          color: const Color(0xFF0284C7),
        ),
        facultyName: 'Facultad de Ingeniería',
        postCount: 28,
        likesCount: 116,
        score: 114.0,
      ),
      PopularServerItem(
        server: ForumServer(
          id: 'server_03-00-01',
          name: 'Contaduría Pública y Auditoría',
          shortCode: 'CPA',
          icon: Icons.calculate,
          facultadId: '03',
          carreraId: '03-00-01',
          description: 'Espacio de discusión para Contaduría Pública y Auditoría.',
          color: const Color(0xFF0D9488),
        ),
        facultyName: 'Ciencias Económicas',
        postCount: 22,
        likesCount: 94,
        score: 91.0,
      ),
    ];
  }
}


