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
  });

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
    ForumServer(
      id: 'area_comun',
      name: 'Área Común',
      shortCode: 'BAS',
      icon: Icons.auto_stories,
      facultadId: 'todas',
      carreraId: 'area_comun',
      description: 'Ciencias básicas, matemáticas, físicas y químicas de primeros semestres.',
      color: Color(0xFF2563EB),
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
    ForumChannel(
      id: 'general',
      name: 'charla-general',
      label: 'Consultas Generales',
      categoryId: 'general',
      icon: Icons.chat_bubble_outline,
      description: 'Cafetería estudiantil, avisos generales y vida universitaria en la carrera.',
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
          name: 'Todas las Carreras y Sedes',
          shortCode: 'ALL',
          icon: Icons.apps,
          facultadId: 'todas',
        ),
        ForumCareerItem(
          id: 'area_comun',
          name: 'Área Común',
          shortCode: 'BAS',
          icon: Icons.auto_stories,
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
          name: 'Área Común de Ingeniería',
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

