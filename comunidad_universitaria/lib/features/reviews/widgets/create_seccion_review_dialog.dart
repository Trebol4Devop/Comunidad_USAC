import 'package:flutter/material.dart';
import '../../../core/models/seccion_review.dart';
import '../../../core/services/reviews_service.dart';

class CreateSeccionReviewDialog extends StatefulWidget {
  final String? initialCursoCodigo;
  final String? initialSeccion;
  final Future<SeccionReview?> Function({
    required String cursoCodigo,
    required String seccion,
    required bool recomienda,
    String? catedraticoNombre,
    int? dificultad,
    int? cargaTareas,
    String? comentario,
    String semestre,
  })?
  createReviewHandler;

  const CreateSeccionReviewDialog({
    super.key,
    this.initialCursoCodigo,
    this.initialSeccion,
    this.createReviewHandler,
  });

  static Future<SeccionReview?> show(
    BuildContext context, {
    String? initialCursoCodigo,
    String? initialSeccion,
    Future<SeccionReview?> Function({
      required String cursoCodigo,
      required String seccion,
      required bool recomienda,
      String? catedraticoNombre,
      int? dificultad,
      int? cargaTareas,
      String? comentario,
      String semestre,
    })?
    createReviewHandler,
  }) {
    final isMobile = MediaQuery.of(context).size.width < 700;
    if (isMobile) {
      return showModalBottomSheet<SeccionReview>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: CreateSeccionReviewDialog(
            initialCursoCodigo: initialCursoCodigo,
            initialSeccion: initialSeccion,
            createReviewHandler: createReviewHandler,
          ),
        ),
      );
    } else {
      return showDialog<SeccionReview>(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: CreateSeccionReviewDialog(
              initialCursoCodigo: initialCursoCodigo,
              initialSeccion: initialSeccion,
              createReviewHandler: createReviewHandler,
            ),
          ),
        ),
      );
    }
  }

  @override
  State<CreateSeccionReviewDialog> createState() =>
      _CreateSeccionReviewDialogState();
}

class _CreateSeccionReviewDialogState extends State<CreateSeccionReviewDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _cursoController;
  late final TextEditingController _seccionController;
  final _catedraticoController = TextEditingController();
  final _comentarioController = TextEditingController();

  String _semestre = '1S-2026';
  bool _recomienda = true;
  int _dificultad = 3;
  int _cargaTareas = 3;
  bool _isSubmitting = false;

  static const List<String> _semestres = [
    '1S-2026',
    '2S-2025',
    '1S-2025',
    '2S-2024',
    '1S-2024',
  ];

  @override
  void initState() {
    super.initState();
    _cursoController = TextEditingController(
      text: widget.initialCursoCodigo ?? '',
    );
    _seccionController = TextEditingController(
      text: widget.initialSeccion ?? '',
    );
  }

  @override
  void dispose() {
    _cursoController.dispose();
    _seccionController.dispose();
    _catedraticoController.dispose();
    _comentarioController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final createFn =
          widget.createReviewHandler ?? ReviewsService.createReview;
      final review = await createFn(
        cursoCodigo: _cursoController.text.trim(),
        seccion: _seccionController.text.trim().toUpperCase(),
        recomienda: _recomienda,
        catedraticoNombre: _catedraticoController.text.trim().isEmpty
            ? null
            : _catedraticoController.text.trim(),
        dificultad: _dificultad,
        cargaTareas: _cargaTareas,
        comentario: _comentarioController.text.trim().isEmpty
            ? null
            : _comentarioController.text.trim(),
        semestre: _semestre,
      );

      if (!mounted) return;

      if (review == null) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo crear la reseña. Inténtalo de nuevo.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      Navigator.of(context).pop(review);
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear reseña: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final maxHeight = MediaQuery.of(context).size.height * 0.88;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Encabezado
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.rate_review,
                      color: theme.colorScheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nueva Reseña de Sección',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Comparte tu experiencia para ayudar a otros estudiantes',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Código de curso y Sección
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      key: const Key('curso_codigo_input'),
                      controller: _cursoController,
                      decoration: const InputDecoration(
                        labelText: 'Código de curso *',
                        hintText: 'Ej. 0770 o IPC 1',
                        prefixIcon: Icon(Icons.school_outlined, size: 20),
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.characters,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Obligatorio';
                        }
                        if (val.trim().length < 2) {
                          return 'Mín. 2 caracteres';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      key: const Key('seccion_input'),
                      controller: _seccionController,
                      decoration: const InputDecoration(
                        labelText: 'Sección *',
                        hintText: 'Ej. A',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.characters,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Obligatorio';
                        }
                        if (val.trim().isEmpty) {
                          return 'Mín. 1';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Catedrático (opcional)
              TextFormField(
                key: const Key('catedratico_input'),
                controller: _catedraticoController,
                decoration: const InputDecoration(
                  labelText: 'Catedrático (opcional)',
                  hintText: 'Nombre del docente',
                  prefixIcon: Icon(Icons.person_outline, size: 20),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Semestre
              DropdownButtonFormField<String>(
                key: const Key('semestre_input'),
                initialValue: _semestre,
                decoration: const InputDecoration(
                  labelText: 'Semestre *',
                  prefixIcon: Icon(Icons.calendar_today_outlined, size: 20),
                  border: OutlineInputBorder(),
                ),
                items: _semestres
                    .map(
                      (sem) => DropdownMenuItem(value: sem, child: Text(sem)),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _semestre = val);
                },
                validator: (val) => (val == null || val.isEmpty)
                    ? 'Selecciona un semestre'
                    : null,
              ),
              const SizedBox(height: 16),

              // Recomienda (Switch)
              Card(
                elevation: 0,
                color: isDark
                    ? const Color(0xFF2B2D31)
                    : const Color(0xFFF1F5F9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isDark
                        ? const Color(0xFF383A40)
                        : const Color(0xFFCBD5E1),
                  ),
                ),
                child: SwitchListTile(
                  key: const Key('recomienda_switch'),
                  title: const Text(
                    '¿Recomiendas cursar esta sección?',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Text(
                    _recomienda
                        ? 'Sí, recomiendo cursar con esta sección'
                        : 'No, preferible buscar otra alternativa',
                    style: TextStyle(
                      fontSize: 12,
                      color: _recomienda
                          ? (isDark
                                ? Colors.green.shade300
                                : Colors.green.shade800)
                          : (isDark
                                ? Colors.red.shade300
                                : Colors.red.shade800),
                    ),
                  ),
                  value: _recomienda,
                  onChanged: (val) => setState(() => _recomienda = val),
                ),
              ),
              const SizedBox(height: 16),

              // Dificultad (Slider 1-5)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Dificultad:',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '$_dificultad / 5',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    key: const Key('dificultad_slider'),
                    value: _dificultad.toDouble(),
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: '$_dificultad',
                    onChanged: (val) =>
                        setState(() => _dificultad = val.round()),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Carga de tareas (Slider 1-5)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Carga de tareas / proyectos:',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '$_cargaTareas / 5',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    key: const Key('carga_tareas_slider'),
                    value: _cargaTareas.toDouble(),
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: '$_cargaTareas',
                    onChanged: (val) =>
                        setState(() => _cargaTareas = val.round()),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Comentario multiline (máx. 500)
              TextFormField(
                key: const Key('comentario_input'),
                controller: _comentarioController,
                maxLines: 4,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Comentario u opinión (opcional)',
                  hintText:
                      'Consejos sobre parciales, tareas, ritmo de clases...',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (val) {
                  if (val != null && val.trim().length > 500) {
                    return 'Máximo 500 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Botones de acción
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    key: const Key('guardar_review_button'),
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 16),
                    label: Text(
                      _isSubmitting ? 'Guardando...' : 'Publicar reseña',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
