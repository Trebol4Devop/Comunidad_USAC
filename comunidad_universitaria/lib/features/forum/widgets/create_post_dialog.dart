import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/categories.dart';
import '../../../core/models/post.dart';
import '../../../core/services/forum_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../profile/widgets/alias_modal.dart';
import '../../shared/widgets/auth_modal.dart';
import '../../shared/widgets/gif_picker_modal.dart';

class CreatePostDialog extends StatefulWidget {
  final String activeAlias;
  final Post? quotedPost;
  final Function(String newAlias) onAliasChanged;
  final Function(Post newPost) onPostCreated;

  const CreatePostDialog({
    super.key,
    required this.activeAlias,
    this.quotedPost,
    required this.onAliasChanged,
    required this.onPostCreated,
  });

  static Future<void> show(
    BuildContext context, {
    required String activeAlias,
    Post? quotedPost,
    required Function(String) onAliasChanged,
    required Function(Post) onPostCreated,
  }) {
    if (Responsive.isMobile(context)) {
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => CreatePostDialog(
          activeAlias: activeAlias,
          quotedPost: quotedPost,
          onAliasChanged: onAliasChanged,
          onPostCreated: onPostCreated,
        ),
      );
    } else {
      return showDialog(
        context: context,
        builder: (ctx) => CreatePostDialog(
          activeAlias: activeAlias,
          quotedPost: quotedPost,
          onAliasChanged: onAliasChanged,
          onPostCreated: onPostCreated,
        ),
      );
    }
  }

  @override
  State<CreatePostDialog> createState() => _CreatePostDialogState();
}

class _CreatePostDialogState extends State<CreatePostDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  String? _uploadedImageUrl;
  String? _selectedGifUrl;
  bool _isUploadingImage = false;

  bool _showPollForm = false;
  final _pollQuestionController = TextEditingController();
  final List<TextEditingController> _pollOptionControllers = [
    TextEditingController(text: 'Opción 1'),
    TextEditingController(text: 'Opción 2'),
  ];

  String _selectedCategory = 'general';
  String _selectedFacultad = '08';
  String _selectedCarrera = 'todas';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.quotedPost != null) {
      _titleController.text = 'Re: ${widget.quotedPost!.title}';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _pollQuestionController.dispose();
    for (var c in _pollOptionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  List<Map<String, dynamic>> get _availableCarreras {
    final fac = USACConstants.facultades.firstWhere(
      (f) => f['id'] == _selectedFacultad,
      orElse: () => USACConstants.facultades.first,
    );
    final list = fac['carreras'] as List<dynamic>? ?? [];
    return list.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> _pickAndUploadImage() async {
    setState(() => _isUploadingImage = true);

    try {
      final XFile? file = await StorageService.pickSingleImage();
      if (file != null) {
        final url = await StorageService.uploadImageFile(file, folder: 'forum');
        if (url != null && mounted) {
          setState(() {
            _uploadedImageUrl = url;
            _selectedGifUrl = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir imagen: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  void _addPollOption() {
    if (_pollOptionControllers.length < 5) {
      setState(() {
        _pollOptionControllers.add(TextEditingController());
      });
    }
  }

  void _removePollOption(int index) {
    if (_pollOptionControllers.length > 2) {
      setState(() {
        _pollOptionControllers.removeAt(index).dispose();
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!SupabaseService.isAuthenticated) {
      AuthModal.show(
        context,
        title: 'Inicia Sesión para Publicar',
        subtitle: 'Para crear consultas o citar posts en el foro universitario, debes iniciar sesión.',
        onAuthenticated: () => _submit(),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      String? pollQuestion;
      List<String>? pollOptions;

      if (_showPollForm) {
        pollQuestion = _pollQuestionController.text.trim().isNotEmpty
            ? _pollQuestionController.text.trim()
            : _titleController.text.trim();
        pollOptions = _pollOptionControllers
            .map((c) => c.text.trim())
            .where((text) => text.isNotEmpty)
            .toList();
      }

      final newPost = await ForumService.createPost(
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        category: _selectedCategory,
        carrera: _selectedCarrera,
        authorAlias: widget.activeAlias,
        imageUrl: _uploadedImageUrl,
        gifUrl: _selectedGifUrl,
        quotedPostId: widget.quotedPost?.id,
        pollQuestion: _showPollForm ? pollQuestion : null,
        pollOptions: _showPollForm ? pollOptions : null,
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        if (newPost != null) {
          widget.onPostCreated(newPost);
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Publicación creada exitosamente en el foro.'),
              backgroundColor: Color(0xFF004B87),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '').replaceAll('AuthException: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = Responsive.isMobile(context);
    final maxHeight = MediaQuery.of(context).size.height * (isMobile ? 0.90 : 0.85);

    Widget content = Form(
      key: _formKey,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      widget.quotedPost != null ? Icons.format_quote : Icons.add_comment_outlined,
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
                          widget.quotedPost != null ? 'Citar Publicación (Quote Post)' : 'Nueva Consulta en el Foro',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Publicando como: ${widget.activeAlias}',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.edit, size: 14),
                    label: const Text('Alias', style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      AliasModal.show(
                        context,
                        currentAlias: widget.activeAlias,
                        onSaved: widget.onAliasChanged,
                      );
                    },
                  ),
                ],
              ),
              const Divider(height: 20),

              // Quote preview banner if quoting a post
              if (widget.quotedPost != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.format_quote, size: 18, color: Color(0xFF004B87)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Citando a ${widget.quotedPost!.authorAlias}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                            Text(
                              widget.quotedPost!.title,
                              style: const TextStyle(fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Category & Faculty Row
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  // Category dropdown
                  SizedBox(
                    width: isMobile ? double.infinity : 240,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Categoría del tema',
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      items: USACConstants.forumCategories
                          .where((c) => c.id != 'todos')
                          .map((c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(c.label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                              ))
                          .toList(),
                      onChanged: (val) => setState(() => _selectedCategory = val ?? 'general'),
                    ),
                  ),

                  // Faculty dropdown
                  SizedBox(
                    width: isMobile ? double.infinity : 240,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedFacultad,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Facultad / Unidad',
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      items: USACConstants.facultades
                          .map((f) => DropdownMenuItem<String>(
                                value: f['id'].toString(),
                                child: Text(
                                  f['nombre'].toString(),
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ))
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedFacultad = val ?? '08';
                          _selectedCarrera = 'todas';
                        });
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Career dropdown
              DropdownButtonFormField<String>(
                key: ValueKey('carrera_$_selectedFacultad'),
                initialValue: _selectedCarrera,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Carrera específica (opcional)',
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                items: _availableCarreras
                    .map((c) => DropdownMenuItem<String>(
                          value: c['id'].toString(),
                          child: Text(c['nombre'].toString(), overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                        ))
                    .toList(),
                onChanged: (val) => setState(() => _selectedCarrera = val ?? 'todas'),
              ),

              const SizedBox(height: 12),

              // Post Title
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Título de la consulta o aporte',
                  hintText: 'Ej. ¿Qué catedrático recomiendan para Física 1?',
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                validator: (val) {
                  if (val == null || val.trim().length < 5) {
                    return 'El título debe tener al menos 5 caracteres.';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 12),

              // Post Content
              TextFormField(
                controller: _contentController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Detalle o descripción',
                  hintText: 'Explica tu duda o comparte el material de estudio con la comunidad...',
                ),
                validator: (val) {
                  if (val == null || val.trim().length < 10) {
                    return 'El contenido debe tener al menos 10 caracteres.';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 14),

              // Media & Poll toolbar
              Row(
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    onPressed: _isUploadingImage ? null : _pickAndUploadImage,
                    icon: const Icon(Icons.image_outlined, size: 16),
                    label: const Text('Foto', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    onPressed: () {
                      GifPickerModal.show(
                        context,
                        onGifSelected: (url) {
                          setState(() {
                            _selectedGifUrl = url;
                            _uploadedImageUrl = null;
                          });
                        },
                      );
                    },
                    icon: const Icon(Icons.gif_box_outlined, size: 16),
                    label: const Text('GIF', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: _showPollForm ? const Color(0xFF004B87).withValues(alpha: 0.12) : null,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    onPressed: () => setState(() => _showPollForm = !_showPollForm),
                    icon: Icon(Icons.poll_outlined, size: 16, color: _showPollForm ? const Color(0xFF004B87) : null),
                    label: Text(
                      'Encuesta',
                      style: TextStyle(
                        fontSize: 12,
                        color: _showPollForm ? const Color(0xFF004B87) : null,
                        fontWeight: _showPollForm ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),

              // Interactive Poll Creator Section
              if (_showPollForm) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF004B87).withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF004B87).withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Crear Encuesta Estudiantil',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF004B87)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () => setState(() => _showPollForm = false),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _pollQuestionController,
                        decoration: const InputDecoration(
                          labelText: 'Pregunta de la encuesta (opcional, usa el título por defecto)',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._pollOptionControllers.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final ctrl = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: ctrl,
                                  decoration: InputDecoration(
                                    labelText: 'Opción ${idx + 1}',
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                ),
                              ),
                              if (_pollOptionControllers.length > 2)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                  onPressed: () => _removePollOption(idx),
                                ),
                            ],
                          ),
                        );
                      }),
                      if (_pollOptionControllers.length < 5)
                        TextButton.icon(
                          onPressed: _addPollOption,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Añadir opción', style: TextStyle(fontSize: 12)),
                        ),
                    ],
                  ),
                ),
              ],

              // Attached GIF Preview
              if (_selectedGifUrl != null) ...[
                const SizedBox(height: 12),
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _selectedGifUrl!,
                        width: double.infinity,
                        height: 150,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: InkWell(
                        onTap: () => setState(() => _selectedGifUrl = null),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              // Attached Image Preview
              if (_uploadedImageUrl != null) ...[
                const SizedBox(height: 12),
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _uploadedImageUrl!,
                        width: double.infinity,
                        height: 140,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) => Container(
                          height: 140,
                          color: Colors.grey.shade300,
                          child: const Center(child: Icon(Icons.broken_image)),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: InkWell(
                        onTap: () => setState(() => _uploadedImageUrl = null),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 18),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF004B87),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send, size: 16),
                    label: Text(_isSubmitting ? 'Publicando...' : 'Publicar Consulta'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (isMobile) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: content,
      );
    } else {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: content,
        ),
      );
    }
  }
}

