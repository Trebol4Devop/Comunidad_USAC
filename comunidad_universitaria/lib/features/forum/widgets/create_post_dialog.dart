import 'package:flutter/material.dart';
import '../../../core/constants/categories.dart';
import '../../../core/models/post.dart';
import '../../../core/services/forum_service.dart';
import '../../../core/utils/responsive.dart';
import '../../profile/widgets/alias_modal.dart';

class CreatePostDialog extends StatefulWidget {
  final String activeAlias;
  final Function(String newAlias) onAliasChanged;
  final Function(Post newPost) onPostCreated;

  const CreatePostDialog({
    super.key,
    required this.activeAlias,
    required this.onAliasChanged,
    required this.onPostCreated,
  });

  static Future<void> show(
    BuildContext context, {
    required String activeAlias,
    required Function(String) onAliasChanged,
    required Function(Post) onPostCreated,
  }) {
    if (Responsive.isMobile(context)) {
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => CreatePostDialog(
          activeAlias: activeAlias,
          onAliasChanged: onAliasChanged,
          onPostCreated: onPostCreated,
        ),
      );
    } else {
      return showDialog(
        context: context,
        builder: (ctx) => CreatePostDialog(
          activeAlias: activeAlias,
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
  final _imageUrlController = TextEditingController();

  String _selectedCategory = 'general';
  String _selectedFacultad = '08';
  String _selectedCarrera = 'todas';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _imageUrlController.dispose();
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final newPost = await ForumService.createPost(
      title: _titleController.text.trim(),
      content: _contentController.text.trim(),
      category: _selectedCategory,
      carrera: _selectedCarrera,
      authorAlias: widget.activeAlias,
      imageUrl: _imageUrlController.text.trim(),
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (newPost != null) {
        widget.onPostCreated(newPost);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Publicación creada exitosamente en el foro!'),
            backgroundColor: Color(0xFF004B87),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al crear publicación. Inténtalo de nuevo.'),
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

    Widget content = Form(
      key: _formKey,
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
                  child: Icon(Icons.add_comment_outlined, color: theme.colorScheme.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nueva Consulta en el Foro',
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
                  label: const Text('Cambiar Alias', style: TextStyle(fontSize: 12)),
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
            const Divider(height: 24),

            // Category & Faculty Row
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                // Category dropdown
                SizedBox(
                  width: isMobile ? double.infinity : 240,
                  child: DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Categoría del tema',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: USACConstants.forumCategories
                        .where((c) => c.id != 'todos')
                        .map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.label, style: const TextStyle(fontSize: 13)),
                            ))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedCategory = val ?? 'general'),
                  ),
                ),

                // Faculty dropdown
                SizedBox(
                  width: isMobile ? double.infinity : 240,
                  child: DropdownButtonFormField<String>(
                    value: _selectedFacultad,
                    decoration: const InputDecoration(
                      labelText: 'Facultad USAC',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: USACConstants.facultades
                        .map((f) => DropdownMenuItem<String>(
                              value: f['id'].toString(),
                              child: Text(
                                f['nombre'].toString(),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
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

            const SizedBox(height: 12),

            // Career dropdown
            DropdownButtonFormField<String>(
              value: _selectedCarrera,
              decoration: const InputDecoration(
                labelText: 'Carrera específica (opcional)',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: _availableCarreras
                  .map((c) => DropdownMenuItem<String>(
                        value: c['id'].toString(),
                        child: Text(c['nombre'].toString(), overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                      ))
                  .toList(),
              onChanged: (val) => setState(() => _selectedCarrera = val ?? 'todas'),
            ),

            const SizedBox(height: 14),

            // Post Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Título de la consulta o aporte',
                hintText: 'Ej. ¿Qué catedrático recomiendan para Física 1?',
              ),
              validator: (val) {
                if (val == null || val.trim().length < 5) {
                  return 'El título debe tener al menos 5 caracteres.';
                }
                return null;
              },
            ),

            const SizedBox(height: 14),

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

            // Image URL (optional)
            TextFormField(
              controller: _imageUrlController,
              decoration: const InputDecoration(
                labelText: 'Enlace de imagen o captura (opcional)',
                hintText: 'https://ejemplo.com/horario.png',
                prefixIcon: Icon(Icons.image_outlined, size: 20),
              ),
            ),

            const SizedBox(height: 20),

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
          constraints: const BoxConstraints(maxWidth: 600),
          child: content,
        ),
      );
    }
  }
}
