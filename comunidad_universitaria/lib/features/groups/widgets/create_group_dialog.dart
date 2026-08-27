import 'package:flutter/material.dart';
import '../../../core/constants/categories.dart';
import '../../../core/models/whatsapp_group.dart';
import '../../../core/services/groups_service.dart';
import '../../../core/utils/responsive.dart';
import '../../profile/widgets/alias_modal.dart';

class CreateGroupDialog extends StatefulWidget {
  final String activeAlias;
  final Function(String newAlias) onAliasChanged;
  final Function(WhatsAppGroup newGroup) onGroupCreated;

  const CreateGroupDialog({
    super.key,
    required this.activeAlias,
    required this.onAliasChanged,
    required this.onGroupCreated,
  });

  static Future<void> show(
    BuildContext context, {
    required String activeAlias,
    required Function(String) onAliasChanged,
    required Function(WhatsAppGroup) onGroupCreated,
  }) {
    if (Responsive.isMobile(context)) {
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => CreateGroupDialog(
          activeAlias: activeAlias,
          onAliasChanged: onAliasChanged,
          onGroupCreated: onGroupCreated,
        ),
      );
    } else {
      return showDialog(
        context: context,
        builder: (ctx) => CreateGroupDialog(
          activeAlias: activeAlias,
          onAliasChanged: onAliasChanged,
          onGroupCreated: onGroupCreated,
        ),
      );
    }
  }

  @override
  State<CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<CreateGroupDialog> {
  final _formKey = GlobalKey<FormState>();
  final _cursoController = TextEditingController();
  final _sectionController = TextEditingController(text: 'Sección A');
  final _titleController = TextEditingController();
  final _linkController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedFacultad = '08';
  String _selectedCarrera = 'todas';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _cursoController.dispose();
    _sectionController.dispose();
    _titleController.dispose();
    _linkController.dispose();
    _descriptionController.dispose();
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

    final title = _titleController.text.trim().isEmpty
        ? '${_cursoController.text.trim()} - ${_sectionController.text.trim()}'
        : _titleController.text.trim();

    final created = await GroupsService.createGroup(
      title: title,
      carrera: _selectedCarrera,
      curso: _cursoController.text.trim(),
      section: _sectionController.text.trim(),
      link: _linkController.text.trim(),
      description: _descriptionController.text.trim(),
      authorAlias: widget.activeAlias,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (created != null) {
        widget.onGroupCreated(created);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Grupo estudiantil compartido con éxito!'),
            backgroundColor: Color(0xFF004B87),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al compartir el enlace. Revisa los datos.'),
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
                    color: const Color(0xFF25D366).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.group_add_outlined, color: Color(0xFF25D366), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Compartir Grupo Estudiantil',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Publicado por: ${widget.activeAlias}',
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
            const Divider(height: 24),

            // Faculty and Career
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: isMobile ? double.infinity : 240,
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedFacultad,
                    decoration: const InputDecoration(
                      labelText: 'Facultad / Unidad Académica',
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
                SizedBox(
                  width: isMobile ? double.infinity : 240,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('carrera_$_selectedFacultad'),
                    initialValue: _selectedCarrera,
                    decoration: const InputDecoration(
                      labelText: 'Carrera',
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
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Course Name & Section
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _cursoController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del Curso',
                      hintText: 'Ej. Matemática Básica 1',
                    ),
                    validator: (val) => (val == null || val.trim().isEmpty) ? 'Ingresa el curso' : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _sectionController,
                    decoration: const InputDecoration(
                      labelText: 'Sección',
                      hintText: 'Ej. Sección A',
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Invitation Link (WhatsApp, Telegram, Discord, Drive)
            TextFormField(
              controller: _linkController,
              decoration: const InputDecoration(
                labelText: 'Enlace de Invitación (WhatsApp / Telegram / Discord)',
                hintText: 'https://chat.whatsapp.com/..., https://t.me/..., https://discord.gg/...',
                prefixIcon: Icon(Icons.link, size: 20),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Pega el enlace de invitación del grupo.';
                }
                final lower = val.toLowerCase();
                if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
                  return 'El enlace debe comenzar con https://';
                }
                return null;
              },
            ),

            const SizedBox(height: 14),

            // Optional custom title & description
            TextFormField(
              controller: _descriptionController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Descripción o Catedrático (opcional)',
                hintText: 'Ej. Grupo para tareas y dudas con el Ing. Morales.',
              ),
            ),

            const SizedBox(height: 20),

            // Submit Buttons
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
                      : const Icon(Icons.check, size: 16),
                  label: Text(_isSubmitting ? 'Guardando...' : 'Compartir Grupo'),
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
          constraints: const BoxConstraints(maxWidth: 580),
          child: content,
        ),
      );
    }
  }
}
