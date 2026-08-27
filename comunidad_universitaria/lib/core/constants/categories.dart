class ForumCategory {
  final String id;
  final String label;
  final String description;

  const ForumCategory({
    required this.id,
    required this.label,
    required this.description,
  });
}

class MarketplaceCategoryOption {
  final String id;
  final String label;
  final String iconName;
  final String description;

  const MarketplaceCategoryOption({
    required this.id,
    required this.label,
    required this.iconName,
    required this.description,
  });
}

class USACConstants {
  // Descargos y Política de Identidad Independiente
  static const String appName = 'Comunidad Universitaria';
  static const String appSubtitle = 'Plataforma Estudiantil Independiente';
  static const String appDisclaimer =
      'Comunidad Universitaria es una iniciativa estudiantil 100% independiente, autónoma y sin fines de lucro. No representa, no pertenece ni cuenta con afiliación oficial con las autoridades de la Universidad de San Carlos de Guatemala (USAC). Los datos académicos se recopilan con fines exclusivamente orientativos y de libre acceso.';
  static const String marketplaceDisclaimer =
      'Esta plataforma no interviene en las transacciones comerciales ni custodia fondos. Toda compra, venta o coordinación de tutoría se realiza de forma directa y bajo la responsabilidad mutua de los estudiantes participantes.';

  // Categorías del Foro
  static const List<ForumCategory> forumCategories = [
    ForumCategory(
      id: 'todos',
      label: 'Todas las áreas',
      description: 'Ver todas las publicaciones sin filtro de tema.',
    ),
    ForumCategory(
      id: 'prerrequisitos',
      label: 'Prerrequisitos & Pensum',
      description: 'Dudas sobre créditos, prerrequisitos, equivalencias y cierres de pensum.',
    ),
    ForumCategory(
      id: 'catedraticos',
      label: 'Catedráticos & Auxiliares',
      description: 'Experiencias, metodología de enseñanza y recomendaciones de catedráticos.',
    ),
    ForumCategory(
      id: 'horarios',
      label: 'Horarios & Secciones',
      description: 'Información sobre traslapes, asignaciones de secciones y laboratorios.',
    ),
    ForumCategory(
      id: 'apuntes',
      label: 'Apuntes & Exámenes',
      description: 'Material de estudio, resúmenes, parciales pasados y guías de laboratorio.',
    ),
    ForumCategory(
      id: 'general',
      label: 'Consultas Generales',
      description: 'Preguntas administrativas, trámites de secretaría y vida universitaria.',
    ),
  ];

  // Categorías del Marketplace Estudiantil
  static const List<MarketplaceCategoryOption> marketplaceCategories = [
    MarketplaceCategoryOption(
      id: 'todos',
      label: 'Todo el Marketplace',
      iconName: 'storefront',
      description: 'Explora todos los productos, comidas, tutorías y materiales.',
    ),
    MarketplaceCategoryOption(
      id: 'comida_postres',
      label: 'Comida & Postres',
      iconName: 'cake',
      description: 'Postres, almuerzos, café, snacks y antojitos en el campus.',
    ),
    MarketplaceCategoryOption(
      id: 'tutorias_academica',
      label: 'Tutorías & Asesorías',
      iconName: 'school',
      description: 'Clases particulares, resolución de dudas y asesorías de cursos (gratuitas o con costo).',
    ),
    MarketplaceCategoryOption(
      id: 'libros_materiales',
      label: 'Libros & Materiales',
      iconName: 'menu_book',
      description: 'Libros de texto, batas, calculadoras, instrumental médico, odontológico o dibujo.',
    ),
    MarketplaceCategoryOption(
      id: 'servicios_estudiantiles',
      label: 'Servicios Estudiantiles',
      iconName: 'design_services',
      description: 'Impresiones, empastados, desarrollo de software, diseño gráfico y asesoría técnica.',
    ),
    MarketplaceCategoryOption(
      id: 'otros_articulos',
      label: 'Otros Artículos',
      iconName: 'inventory_2',
      description: 'Accesorios, tecnología, ropa y artículos varios de segunda mano o nuevos.',
    ),
  ];

  // Catálogo de Sedes y Centros Universitarios
  static const List<Map<String, String>> sedes = [
    {'id': 'todas', 'nombre': 'Todas las Sedes / General', 'departamento': 'Nacional'},
    {'id': 'central', 'nombre': 'Campus Central (Zona 12)', 'departamento': 'Guatemala'},
    {'id': 'cum', 'nombre': 'CUM - Centro Univ. Metropolitano (Zona 11)', 'departamento': 'Guatemala'},
    {'id': 'cunoc', 'nombre': 'CUNOC - Quetzaltenango', 'departamento': 'Quetzaltenango'},
    {'id': 'cunor', 'nombre': 'CUNOR - Cobán, Alta Verapaz', 'departamento': 'Alta Verapaz'},
    {'id': 'cuchim', 'nombre': 'Sede Chimaltenango', 'departamento': 'Chimaltenango'},
    {'id': 'cuesc', 'nombre': 'Sede Escuintla', 'departamento': 'Escuintla'},
    {'id': 'cunoroc', 'nombre': 'CUNOROC - Huehuetenango', 'departamento': 'Huehuetenango'},
    {'id': 'cunori', 'nombre': 'CUNORI - Chiquimula', 'departamento': 'Chiquimula'},
    {'id': 'cunizab', 'nombre': 'CUNIZAB - Puerto Barrios / Izabal', 'departamento': 'Izabal'},
    {'id': 'cusam', 'nombre': 'CUSAM - San Marcos', 'departamento': 'San Marcos'},
    {'id': 'cujal', 'nombre': 'Sede Jalapa', 'departamento': 'Jalapa'},
    {'id': 'cujut', 'nombre': 'Sede Jutiapa', 'departamento': 'Jutiapa'},
    {'id': 'cuqui', 'nombre': 'Sede Quiché', 'departamento': 'Quiché'},
    {'id': 'cunret', 'nombre': 'Sede Retalhuleu', 'departamento': 'Retalhuleu'},
    {'id': 'cunsuroc', 'nombre': 'CUNSUROC - Mazatenango / Suchitepéquez', 'departamento': 'Suchitepéquez'},
    {'id': 'cusantarosa', 'nombre': 'Sede Santa Rosa (Barberena/Casillas)', 'departamento': 'Santa Rosa'},
    {'id': 'cuzac', 'nombre': 'Sede Zacapa', 'departamento': 'Zacapa'},
    {'id': 'cubajaverapaz', 'nombre': 'Sede Baja Verapaz (Salamá/Rabinal)', 'departamento': 'Baja Verapaz'},
    {'id': 'cudep', 'nombre': 'CUDEP - Petén', 'departamento': 'Petén'},
    {'id': 'cusac', 'nombre': 'Sede Sacatepéquez (Antigua/San Lucas)', 'departamento': 'Sacatepéquez'},
    {'id': 'cusol', 'nombre': 'Sede Sololá', 'departamento': 'Sololá'},
    {'id': 'cutot', 'nombre': 'Sede Totonicapán', 'departamento': 'Totonicapán'},
    {'id': 'cuprog', 'nombre': 'Sede El Progreso (Sanarate)', 'departamento': 'El Progreso'},
    {'id': 'metropolitana_mixco', 'nombre': 'Sede Mixco', 'departamento': 'Guatemala'},
    {'id': 'metropolitana_villanueva', 'nombre': 'Sede Villa Nueva', 'departamento': 'Guatemala'},
    {'id': 'metropolitana_amatitlan', 'nombre': 'Sede Amatitlán', 'departamento': 'Guatemala'},
    {'id': 'metropolitana_pinula', 'nombre': 'Sede San José Pinula', 'departamento': 'Guatemala'},
  ];

  // Catálogo de Edificios y Puntos de Encuentro (Preparado para Mapa Interactivo)
  static const List<Map<String, dynamic>> campusBuildings = [
    {
      'id': 't3',
      'building_code': 'T-3',
      'nombre': 'Edificio T-3 (Facultad de Ingeniería)',
      'sede_id': 'central',
      'latitude': 14.5886,
      'longitude': -90.5516,
      'description': 'Aulas de Ingeniería, fotocopiadoras y cafetín.',
    },
    {
      'id': 't1',
      'building_code': 'T-1',
      'nombre': 'Edificio T-1 (Ingeniería Mecánica / Eléctrica)',
      'sede_id': 'central',
      'latitude': 14.5892,
      'longitude': -90.5512,
      'description': 'Laboratorios y talleres técnicos.',
    },
    {
      'id': 's12',
      'building_code': 'S-12',
      'nombre': 'Edificio S-12 (Facultad de Ciencias Económicas)',
      'sede_id': 'central',
      'latitude': 14.5878,
      'longitude': -90.5524,
      'description': 'Área principal de Administración, Auditoría y Economía.',
    },
    {
      'id': 's3',
      'building_code': 'S-3',
      'nombre': 'Edificio S-3 (Agronomía / Farmacia)',
      'sede_id': 'central',
      'latitude': 14.5865,
      'longitude': -90.5530,
      'description': 'Facultad de Agronomía y Ciencias Químicas y Farmacia.',
    },
    {
      'id': 'm3',
      'building_code': 'M-3',
      'nombre': 'Edificio M-3 (Facultad de Odontología)',
      'sede_id': 'central',
      'latitude': 14.5872,
      'longitude': -90.5505,
      'description': 'Clínicas dentales y laboratorios de odontología.',
    },
    {
      'id': 's2',
      'building_code': 'S-2',
      'nombre': 'Edificio S-2 (Ciencias Jurídicas y Sociales)',
      'sede_id': 'central',
      'latitude': 14.5861,
      'longitude': -90.5521,
      'description': 'Facultad de Derecho y bufete popular.',
    },
    {
      'id': 's4',
      'building_code': 'S-4',
      'nombre': 'Edificio S-4 (Facultad de Humanidades)',
      'sede_id': 'central',
      'latitude': 14.5855,
      'longitude': -90.5535,
      'description': 'Aulas y dirección de profesorados y licenciaturas.',
    },
    {
      'id': 't2',
      'building_code': 'T-2',
      'nombre': 'Edificio T-2 (Facultad de Arquitectura)',
      'sede_id': 'central',
      'latitude': 14.5880,
      'longitude': -90.5508,
      'description': 'Talleres de diseño, maquetas y arquitectura.',
    },
    {
      'id': 'fmvz',
      'building_code': 'FMVZ',
      'nombre': 'Edificio Veterinaria y Zootecnia',
      'sede_id': 'central',
      'latitude': 14.5848,
      'longitude': -90.5542,
      'description': 'Hospital veterinario y módulos de zootecnia.',
    },
    {
      'id': 'plaza_martires',
      'building_code': 'PLAZA',
      'nombre': 'Plaza de los Mártires (Frente a Rectoría)',
      'sede_id': 'central',
      'latitude': 14.5875,
      'longitude': -90.5518,
      'description': 'Punto de encuentro central, quioscos y actividades.',
    },
    {
      'id': 'biblioteca_central',
      'building_code': 'BIBLIO',
      'nombre': 'Biblioteca Central',
      'sede_id': 'central',
      'latitude': 14.5870,
      'longitude': -90.5515,
      'description': 'Salas de estudio, mesas al aire libre y cubículos.',
    },
    {
      'id': 'cum_a',
      'building_code': 'CUM-A',
      'nombre': 'CUM Edificio A (Medicina y Cirugía)',
      'sede_id': 'cum',
      'latitude': 14.6152,
      'longitude': -90.5489,
      'description': 'Centro Universitario Metropolitano, Zona 11.',
    },
    {
      'id': 'cum_b',
      'building_code': 'CUM-B',
      'nombre': 'CUM Edificio B (Enfermería y Fisioterapia)',
      'sede_id': 'cum',
      'latitude': 14.6155,
      'longitude': -90.5492,
      'description': 'Escuelas técnicas de salud y laboratorios.',
    },
    {
      'id': 'general_sede',
      'building_code': 'SEDE',
      'nombre': 'Punto de encuentro en Sede Departamental',
      'sede_id': 'todas',
      'latitude': null,
      'longitude': null,
      'description': 'Entrega coordinada dentro de las instalaciones de la sede.',
    }
  ];

  // Catálogo Completo de Facultades y Carreras (Dataset Oficial)
  static const List<Map<String, dynamic>> facultades = [
    {
      'id': 'todas',
      'codigo': '00',
      'nombre': 'Todas las Facultades / General',
      'sitio': 'https://usac.edu.gt',
      'carreras': [
        {'id': 'todas', 'nombre': 'Todas las Carreras', 'codigo': '00-00-00', 'sede': 'Campus Central', 'modalidades': ['Diario', 'Sabatino', 'Dominical']},
        {'id': 'area_comun', 'nombre': 'Área Común / Cursos Básicos', 'codigo': '00-00-01', 'sede': 'Campus Central', 'modalidades': ['Diario', 'Sabatino', 'Dominical']}
      ]
    },
    {
      'id': '01',
      'codigo': '01',
      'nombre': '01 — Facultad de Agronomía',
      'sitio': 'http://fausac.gt/',
      'carreras': [
        {'id': 'todas', 'nombre': 'Todas las Carreras de Agronomía', 'codigo': '01-00-00', 'sede': 'Campus Central', 'modalidades': ['Diario']},
        {'id': '01-00-02', 'nombre': 'Ingeniería Agronómica en Sistemas de Producción Agrícola', 'codigo': '01-00-02', 'sede': 'Campus Central', 'modalidades': ['Diario', 'Sabatino', 'Dominical']},
        {'id': '01-00-03', 'nombre': 'Ingeniería Agronómica en Recursos Naturales Renovables', 'codigo': '01-00-03', 'sede': 'Campus Central', 'modalidades': ['Diario', 'Sabatino', 'Dominical']},
        {'id': '01-00-04', 'nombre': 'Ingeniería en Industrias Agropecuarias y Forestales', 'codigo': '01-00-04', 'sede': 'Campus Central', 'modalidades': ['Diario', 'Sabatino']},
        {'id': '01-00-07', 'nombre': 'Ingeniería en Gestión Ambiental Local', 'codigo': '01-00-07', 'sede': 'Campus Central', 'modalidades': ['Diario', 'Sabatino', 'Dominical']},
      ]
    },
    {
      'id': '02',
      'codigo': '02',
      'nombre': '02 — Facultad de Arquitectura',
      'sitio': 'https://farusac.edu.gt/sigaa-2/',
      'carreras': [
        {'id': 'todas', 'nombre': 'Todas las Carreras de Arquitectura', 'codigo': '02-00-00', 'sede': 'Campus Central', 'modalidades': ['Diario']},
        {'id': '02-00-01', 'nombre': 'Licenciatura en Arquitectura', 'codigo': '02-00-01', 'sede': 'Campus Central', 'modalidades': ['Diario']},
        {'id': '02-00-03', 'nombre': 'Licenciatura en Diseño Gráfico', 'codigo': '02-00-03', 'sede': 'Campus Central', 'modalidades': ['Diario']},
      ]
    },
    {
      'id': '03',
      'codigo': '03',
      'nombre': '03 — Facultad de Ciencias Económicas',
      'sitio': 'http://economicas.usac.edu.gt/',
      'carreras': [
        {'id': 'todas', 'nombre': 'Todas las Carreras de Económicas', 'codigo': '03-00-00', 'sede': 'Campus Central', 'modalidades': ['Diario']},
        {'id': '03-00-01', 'nombre': 'Contaduría Pública y Auditoría (Campus Central)', 'codigo': '03-00-01', 'sede': 'Campus Central', 'modalidades': ['Diario', 'Sabatino', 'Dominical']},
        {'id': '03-00-02', 'nombre': 'Economía (Campus Central)', 'codigo': '03-00-02', 'sede': 'Campus Central', 'modalidades': ['Diario', 'Sabatino', 'Dominical']},
        {'id': '03-00-03', 'nombre': 'Administración de Empresas (Campus Central)', 'codigo': '03-00-03', 'sede': 'Campus Central', 'modalidades': ['Diario', 'Sabatino', 'Dominical']},
        {'id': '03-02-01', 'nombre': 'Contaduría Pública y Auditoría (Extensión)', 'codigo': '03-02-01', 'sede': 'Extensión', 'modalidades': ['Diario', 'Sabatino', 'Dominical']},
        {'id': '03-02-02', 'nombre': 'Economía - Área común (Extensión)', 'codigo': '03-02-02', 'sede': 'Extensión', 'modalidades': ['Diario', 'Sabatino', 'Dominical']},
        {'id': '03-02-03', 'nombre': 'Administración de Empresas (Extensión)', 'codigo': '03-02-03', 'sede': 'Extensión', 'modalidades': ['Diario', 'Sabatino', 'Dominical']},
      ]
    },
    {
      'id': '04',
      'codigo': '04',
      'nombre': '04 — Facultad de Ciencias Jurídicas y Sociales',
      'sitio': 'https://www.derecho.cloud/',
      'carreras': [
        {'id': 'todas', 'nombre': 'Todas las Carreras de Derecho', 'codigo': '04-00-00', 'sede': 'Campus Central', 'modalidades': ['Diario']},
        {'id': '04-00-01', 'nombre': 'Licenciatura en Ciencias Jurídicas y Sociales (Abogado y Notario)', 'codigo': '04-00-01', 'sede': 'Campus Central / Extensiones', 'modalidades': ['Diario', 'Sabatino', 'Dominical']},
      ]
    },
    {
      'id': '05',
      'codigo': '05',
      'nombre': '05 — Facultad de Ciencias Médicas (CUM)',
      'sitio': 'http://medicina.usac.edu.gt/',
      'carreras': [
        {'id': 'todas', 'nombre': 'Todas las Carreras de Medicina y Salud', 'codigo': '05-00-00', 'sede': 'CUM, Zona 11', 'modalidades': ['Diario']},
        {'id': '05-00-01', 'nombre': 'Médico y Cirujano', 'codigo': '05-00-01', 'sede': 'CUM, Zona 11', 'modalidades': ['Diario', 'Sabatino']},
        {'id': '05-01-03', 'nombre': 'Técnico de Enfermería (ENF-Guatemala)', 'codigo': '05-01-03', 'sede': 'Zona 11, Ciudad de Guatemala', 'modalidades': ['Diario', 'Sabatino']},
        {'id': '05-04-04', 'nombre': 'Técnico de Fisioterapia (ETFOE)', 'codigo': '05-04-04', 'sede': 'Escuela de Fisioterapia', 'modalidades': ['Diario', 'Sabatino']},
        {'id': '05-05-05', 'nombre': 'Técnico de Terapia Respiratoria (ETR)', 'codigo': '05-05-05', 'sede': 'Hospital Roosevelt', 'modalidades': ['Diario']},
        {'id': '05-02-03', 'nombre': 'Técnico en Enfermería (Quetzaltenango - ENEO)', 'codigo': '05-02-03', 'sede': 'Quetzaltenango', 'modalidades': ['Diario']},
        {'id': '05-03-03', 'nombre': 'Licenciatura en Enfermería nivel técnico (Cobán)', 'codigo': '05-03-03', 'sede': 'Cobán, Alta Verapaz', 'modalidades': ['Diario', 'Sabatino']},
      ]
    },
    {
      'id': '06',
      'codigo': '06',
      'nombre': '06 — Facultad de Ciencias Químicas y Farmacia',
      'sitio': 'https://portal.ccqqfar.usac.edu.gt/',
      'carreras': [
        {'id': 'todas', 'nombre': 'Todas las Carreras de Farmacia y Química', 'codigo': '06-00-00', 'sede': 'Campus Central', 'modalidades': ['Diario']},
        {'id': '06-00-01', 'nombre': 'Licenciatura en Química', 'codigo': '06-00-01', 'sede': 'Campus Central', 'modalidades': ['Diario', 'Sabatino', 'Dominical']},
        {'id': '06-00-02', 'nombre': 'Licenciatura en Química Biológica', 'codigo': '06-00-02', 'sede': 'Campus Central', 'modalidades': ['Diario', 'Sabatino', 'Dominical']},
        {'id': '06-00-03', 'nombre': 'Licenciatura en Química Farmacéutica', 'codigo': '06-00-03', 'sede': 'Campus Central', 'modalidades': ['Diario', 'Sabatino', 'Dominical']},
        {'id': '06-00-04', 'nombre': 'Licenciatura en Biología', 'codigo': '06-00-04', 'sede': 'Campus Central', 'modalidades': ['Diario', 'Sabatino', 'Dominical']},
        {'id': '06-00-05', 'nombre': 'Licenciatura en Nutrición', 'codigo': '06-00-05', 'sede': 'Campus Central', 'modalidades': ['Diario', 'Sabatino']},
      ]
    },
    {
      'id': '07',
      'codigo': '77',
      'nombre': '07 — Facultad de Humanidades (Central & Extensiones)',
      'sitio': 'https://humanidades.usac.edu.gt/',
      'carreras': [
        {'id': 'todas', 'nombre': 'Todas las Carreras de Humanidades', 'codigo': '77-00-00', 'sede': 'Campus Central / Extensiones', 'modalidades': ['Diario', 'Sabatino', 'Dominical']},
        {'id': '77-00-55', 'nombre': 'PEM en Pedagogía y Técnico en Administración Educativa', 'codigo': '77-00-55', 'sede': 'Central & Sedes Departamentales', 'modalidades': ['Diario', 'Sabatino', 'Dominical']},
        {'id': '77-00-18', 'nombre': 'PEM en Pedagogía, Promotor de DDHH y Cultura de Paz', 'codigo': '77-00-18', 'sede': 'Central & Sedes Departamentales', 'modalidades': ['Diario', 'Sabatino', 'Dominical']},
        {'id': '77-00-28', 'nombre': 'PEM en Pedagogía, Ciencias Sociales y Formación Ciudadana', 'codigo': '77-00-28', 'sede': 'Central & Sedes Departamentales', 'modalidades': ['Diario', 'Sabatino', 'Dominical']},
        {'id': '77-00-23', 'nombre': 'PEM en Idioma Inglés', 'codigo': '77-00-23', 'sede': 'Central, Antigua, Quetzaltenango', 'modalidades': ['Diario', 'Sabatino']},
        {'id': '77-00-78', 'nombre': 'PEM en Pedagogía y Ciencias Naturales con Orientación Ambiental', 'codigo': '77-00-78', 'sede': 'Central & Sedes Departamentales', 'modalidades': ['Sabatino', 'Dominical']},
        {'id': '77-00-17', 'nombre': 'PEM en Ciencias Económico Contables', 'codigo': '77-00-17', 'sede': 'Central & Sedes Departamentales', 'modalidades': ['Sabatino', 'Dominical']},
        {'id': '77-00-74', 'nombre': 'PEM en Pedagogía y Educación Intercultural', 'codigo': '77-00-74', 'sede': 'Sedes Departamentales', 'modalidades': ['Sabatino', 'Dominical']},
        {'id': '77-00-26', 'nombre': 'PEM en Artes Plásticas e Historia del Arte', 'codigo': '77-00-26', 'sede': 'Campus Central', 'modalidades': ['Diario', 'Sabatino']},
        {'id': '77-00-27', 'nombre': 'PEM en Educación Musical', 'codigo': '77-00-27', 'sede': 'Campus Central', 'modalidades': ['Diario', 'Sabatino']},
        {'id': '77-00-46', 'nombre': 'Licenciatura en Filosofía', 'codigo': '77-00-46', 'sede': 'Campus Central', 'modalidades': ['Diario']},
        {'id': '77-00-07', 'nombre': 'Licenciatura en Arte', 'codigo': '77-00-07', 'sede': 'Campus Central', 'modalidades': ['Diario', 'Sabatino']},
        {'id': '77-00-53', 'nombre': 'Profesorado en Ciencias de la Información Documental (b-learning)', 'codigo': '77-00-53', 'sede': 'Central & Chimaltenango', 'modalidades': ['Diario', 'Sabatino']},
        {'id': '77-00-67', 'nombre': 'PEM en Pedagogía y Técnico en Investigación Educativa', 'codigo': '77-00-67', 'sede': 'Jalapa, Morales, Yupiltepeque', 'modalidades': ['Sabatino']},
      ]
    },
    {
      'id': '08',
      'codigo': '08',
      'nombre': '08 — Facultad de Ingeniería',
      'sitio': 'https://portal.ingenieria.usac.edu.gt/',
      'carreras': [
        {'id': 'todas', 'nombre': 'Todas las Carreras de Ingeniería', 'codigo': '08-00-00', 'sede': 'Campus Central', 'modalidades': ['Diario']},
        {'id': 'area_comun', 'nombre': 'Área Común de Ingeniería (1er - 3er Semestre)', 'codigo': '08-00-00-AC', 'sede': 'Campus Central', 'modalidades': ['Diario', 'Sabatino', 'Dominical']},
        {'id': 'sistemas', 'nombre': '08-00-09 — Ingeniería en Ciencias y Sistemas', 'codigo': '08-00-09', 'sede': 'Campus Central', 'modalidades': ['Diario', 'Sabatino', 'Dominical']},
        {'id': 'civil', 'nombre': '08-00-01 — Ingeniería Civil', 'codigo': '08-00-01', 'sede': 'Campus Central', 'modalidades': ['Diario', 'Sabatino', 'Dominical']},
        {'id': 'industrial', 'nombre': '08-00-05 — Ingeniería Industrial', 'codigo': '08-00-05', 'sede': 'Campus Central', 'modalidades': ['Diario', 'Sabatino', 'Dominical']},
        {'id': 'quimica', 'nombre': '08-00-02 — Ingeniería Química', 'codigo': '08-00-02', 'sede': 'Campus Central', 'modalidades': ['Diario', 'Sabatino', 'Dominical']},
        {'id': 'mecanica', 'nombre': '08-00-03 — Ingeniería Mecánica', 'codigo': '08-00-03', 'sede': 'Campus Central', 'modalidades': ['Diario', 'Sabatino', 'Dominical']},
        {'id': 'electrica', 'nombre': '08-00-04 — Ingeniería Eléctrica', 'codigo': '08-00-04', 'sede': 'Campus Central', 'modalidades': ['Diario', 'Sabatino', 'Dominical']},
        {'id': 'electronica', 'nombre': '08-00-13 — Ingeniería Electrónica', 'codigo': '08-00-13', 'sede': 'Campus Central', 'modalidades': ['Diario', 'Sabatino', 'Dominical']},
        {'id': 'mecanica_industrial', 'nombre': '08-00-07 — Ingeniería Mecánica Industrial', 'codigo': '08-00-07', 'sede': 'Campus Central', 'modalidades': ['Diario', 'Sabatino', 'Dominical']},
        {'id': 'mecanica_electrica', 'nombre': '08-00-06 — Ingeniería Mecánica Eléctrica', 'codigo': '08-00-06', 'sede': 'Campus Central', 'modalidades': ['Diario', 'Sabatino', 'Dominical']},
        {'id': 'ambiental', 'nombre': '08-00-35 — Ingeniería Ambiental', 'codigo': '08-00-35', 'sede': 'Campus Central', 'modalidades': ['Diario', 'Sabatino', 'Dominical']},
      ]
    },
    {
      'id': '09',
      'codigo': '09',
      'nombre': '09 — Facultad de Odontología',
      'sitio': 'http://fo.usac.edu.gt/',
      'carreras': [
        {'id': 'todas', 'nombre': 'Todas las Carreras de Odontología', 'codigo': '09-00-00', 'sede': 'Campus Central', 'modalidades': ['Diario']},
        {'id': '09-00-01', 'nombre': 'Cirujano Dentista', 'codigo': '09-00-01', 'sede': 'Campus Central', 'modalidades': ['Diario', 'Sabatino']},
      ]
    },
    {
      'id': '10',
      'codigo': '10',
      'nombre': '10 — Facultad de Medicina Veterinaria y Zootecnia',
      'sitio': 'http://www.fmvz.usac.edu.gt/',
      'carreras': [
        {'id': 'todas', 'nombre': 'Todas las Carreras de Veterinaria', 'codigo': '10-00-00', 'sede': 'Campus Central', 'modalidades': ['Diario']},
        {'id': '10-00-02', 'nombre': 'Medicina Veterinaria', 'codigo': '10-00-02', 'sede': 'Campus Central', 'modalidades': ['Diario', 'Sabatino']},
        {'id': '10-00-03', 'nombre': 'Zootecnia', 'codigo': '10-00-03', 'sede': 'Campus Central', 'modalidades': ['Diario', 'Sabatino', 'Dominical']},
      ]
    },
  ];
}
