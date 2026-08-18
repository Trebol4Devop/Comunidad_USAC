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

class USACConstants {
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

  static const List<Map<String, dynamic>> facultades = [
    {
      'id': 'todas',
      'codigo': '00',
      'nombre': 'Todas las Facultades / General',
      'sitio': 'https://usac.edu.gt',
      'carreras': [
        {'id': 'todas', 'nombre': 'Todas las Carreras'},
        {'id': 'area_comun', 'nombre': 'Área Común / Cursos Básicos'}
      ]
    },
    {
      'id': '08',
      'codigo': '08',
      'nombre': 'Facultad de Ingeniería',
      'sitio': 'https://portal.ingenieria.usac.edu.gt/',
      'carreras': [
        {'id': 'todas', 'nombre': 'Todas las Carreras de Ingeniería'},
        {'id': 'area_comun', 'nombre': 'Área Común (1er - 3er Semestre)'},
        {'id': 'sistemas', 'nombre': 'Ingeniería en Ciencias y Sistemas'},
        {'id': 'civil', 'nombre': 'Ingeniería Civil'},
        {'id': 'industrial', 'nombre': 'Ingeniería Industrial'},
        {'id': 'quimica', 'nombre': 'Ingeniería Química'},
        {'id': 'mecanica', 'nombre': 'Ingeniería Mecánica'},
        {'id': 'electrica', 'nombre': 'Ingeniería Eléctrica'},
        {'id': 'electronica', 'nombre': 'Ingeniería Electrónica'},
        {'id': 'mecanica_industrial', 'nombre': 'Ingeniería Mecánica Industrial'},
        {'id': 'mecanica_electrica', 'nombre': 'Ingeniería Mecánica Eléctrica'},
        {'id': 'ambiental', 'nombre': 'Ingeniería Ambiental'},
      ]
    },
    {
      'id': '03',
      'codigo': '03',
      'nombre': 'Facultad de Ciencias Económicas',
      'sitio': 'http://economicas.usac.edu.gt/',
      'carreras': [
        {'id': 'todas', 'nombre': 'Todas las Carreras de Económicas'},
        {'id': 'auditoria', 'nombre': 'Contaduría Pública y Auditoría'},
        {'id': 'administracion', 'nombre': 'Administración de Empresas'},
        {'id': 'economia', 'nombre': 'Economía'},
      ]
    },
    {
      'id': '05',
      'codigo': '05',
      'nombre': 'Facultad de Ciencias Médicas (CUM)',
      'sitio': 'http://medicina.usac.edu.gt/',
      'carreras': [
        {'id': 'todas', 'nombre': 'Todas las Carreras de Medicina'},
        {'id': 'medico_cirujano', 'nombre': 'Médico y Cirujano'},
        {'id': 'enfermeria', 'nombre': 'Técnico / Licenciatura en Enfermería'},
        {'id': 'fisioterapia', 'nombre': 'Técnico de Fisioterapia'},
        {'id': 'terapia_respiratoria', 'nombre': 'Técnico de Terapia Respiratoria'},
      ]
    },
    {
      'id': '04',
      'codigo': '04',
      'nombre': 'Facultad de Ciencias Jurídicas y Sociales',
      'sitio': 'https://www.derecho.cloud/',
      'carreras': [
        {'id': 'todas', 'nombre': 'Todas las Carreras de Derecho'},
        {'id': 'derecho', 'nombre': 'Abogacía y Notariado / Ciencias Jurídicas'},
      ]
    },
    {
      'id': '07',
      'codigo': '77',
      'nombre': 'Facultad de Humanidades',
      'sitio': 'https://humanidades.usac.edu.gt/',
      'carreras': [
        {'id': 'todas', 'nombre': 'Todas las Carreras de Humanidades'},
        {'id': 'pem_pedagogia_admin', 'nombre': 'PEM en Pedagogía y Administración Educativa'},
        {'id': 'pem_ingles', 'nombre': 'PEM en Idioma Inglés'},
        {'id': 'pem_ciencias_sociales', 'nombre': 'PEM en Pedagogía y Ciencias Sociales'},
        {'id': 'pem_ciencias_naturales', 'nombre': 'PEM en Ciencias Naturales y Orientación Ambiental'},
        {'id': 'lic_filosofia', 'nombre': 'Licenciatura en Filosofía'},
        {'id': 'lic_arte', 'nombre': 'Licenciatura en Arte'},
      ]
    },
    {
      'id': '02',
      'codigo': '02',
      'nombre': 'Facultad de Arquitectura',
      'sitio': 'https://farusac.edu.gt/sigaa-2/',
      'carreras': [
        {'id': 'todas', 'nombre': 'Todas las Carreras de Arquitectura'},
        {'id': 'arquitectura', 'nombre': 'Licenciatura en Arquitectura'},
        {'id': 'diseno_grafico', 'nombre': 'Licenciatura en Diseño Gráfico'},
      ]
    },
    {
      'id': '06',
      'codigo': '06',
      'nombre': 'Facultad de Ciencias Químicas y Farmacia',
      'sitio': 'https://portal.ccqqfar.usac.edu.gt/',
      'carreras': [
        {'id': 'todas', 'nombre': 'Todas las Carreras de Farmacia'},
        {'id': 'quimica_farmaceutica', 'nombre': 'Química Farmacéutica'},
        {'id': 'quimica_biologica', 'nombre': 'Química Biológica'},
        {'id': 'quimica_pura', 'nombre': 'Química Pura'},
        {'id': 'nutricion', 'nombre': 'Nutrición'},
        {'id': 'biologia', 'nombre': 'Biología'},
      ]
    },
    {
      'id': '01',
      'codigo': '01',
      'nombre': 'Facultad de Agronomía',
      'sitio': 'http://fausac.gt/',
      'carreras': [
        {'id': 'todas', 'nombre': 'Todas las Carreras de Agronomía'},
        {'id': 'agronomia_sistemas', 'nombre': 'Ingeniería Agronómica en Sistemas de Producción'},
        {'id': 'recursos_naturales', 'nombre': 'Ingeniería en Recursos Naturales Renovables'},
        {'id': 'industrias_agropecuarias', 'nombre': 'Ingeniería en Industrias Agropecuarias y Forestales'},
        {'id': 'gestion_ambiental', 'nombre': 'Ingeniería en Gestión Ambiental Local'},
      ]
    },
    {
      'id': '09',
      'codigo': '09',
      'nombre': 'Facultad de Odontología',
      'sitio': 'http://fo.usac.edu.gt/',
      'carreras': [
        {'id': 'todas', 'nombre': 'Todas las Carreras de Odontología'},
        {'id': 'cirujano_dentista', 'nombre': 'Cirujano Dentista'},
      ]
    },
    {
      'id': '10',
      'codigo': '10',
      'nombre': 'Facultad de Medicina Veterinaria y Zootecnia',
      'sitio': 'http://www.fmvz.usac.edu.gt/',
      'carreras': [
        {'id': 'todas', 'nombre': 'Todas las Carreras de Veterinaria'},
        {'id': 'medicina_veterinaria', 'nombre': 'Medicina Veterinaria'},
        {'id': 'zootecnia', 'nombre': 'Zootecnia'},
      ]
    },
  ];
}
