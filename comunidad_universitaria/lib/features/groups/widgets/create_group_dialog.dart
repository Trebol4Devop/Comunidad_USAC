import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/categories.dart';
import '../../../core/models/whatsapp_group.dart';
import '../../../core/services/groups_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../profile/widgets/alias_modal.dart';
import '../../shared/widgets/auth_modal.dart';

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
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
  final _generalTitleController = TextEditingController();
  final _linkController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _uploadedImageUrl;
  bool _isUploadingImage = false;

  String _groupType = 'curso'; // 'curso', 'objetos_perdidos', 'comunidad', 'deportes', 'avisos', 'otro'
  String _selectedFacultad = '08';
  String _selectedCarrera = 'todas';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _cursoController.dispose();
    _sectionController.dispose();
    _generalTitleController.dispose();
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

  Future<void> _pickAndUploadImage() async {
    setState(() => _isUploadingImage = true);

    try {
      final XFile? file = await StorageService.pickSingleImage();
      if (file != null) {
        final url = await StorageService.uploadImageFile(file, folder: 'groups');
        if (url != null && mounted) {
          setState(() {
            _uploadedImageUrl = url;
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!SupabaseService.isAuthenticated) {
      AuthModal.show(
        context,
        title: 'Inicia Sesión para Compartir',
        subtitle: 'Para compartir enlaces de grupos estudiantiles, debes iniciar sesión.',
        onAuthenticated: () => _submit(),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    String title;
    String cursoName;
    String sectionName;

    if (_groupType == 'curso') {
      cursoName = _cursoController.text.trim();
      sectionName = _sectionController.text.trim().isEmpty ? 'Sección Única' : _sectionController.text.trim();
      title = '$cursoName - $sectionName';
    } else {
      title = _generalTitleController.text.trim();
      switch (_groupType) {
        case 'objetos_perdidos':
          cursoName = 'Objetos Perdidos & Hallazgos';
          break;
        case 'comunidad':
          cursoName = 'Comunidad de Facultad / Sede';
          break;
        case 'deportes':
          cursoName = 'Deportes & Actividades';
          break;
        case 'avisos':
          cursoName = 'Avisos & Organización';
          break;
        default:
          cursoName = 'Interés General';
      }
      sectionName = 'Comunidad Abierta';
    }

    try {
      final created = await GroupsService.createGroup(
        title: title,
        carrera: _selectedCarrera,
        curso: cursoName,
        section: sectionName,
        link: _linkController.text.trim(),
        description: _descriptionController.text.trim(),
        authorAlias: widget.activeAlias,
        imageUrl: _uploadedImageUrl,
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        if (created != null) {
          widget.onGroupCreated(created);
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Grupo estudiantil compartido con éxito.'),
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
                          'Compartir Enlace de Grupo',
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
              const Divider(height: 20),

              // Group Type Selector
              DropdownButtonFormField<String>(
                initialValue: _groupType,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Tipo de Grupo / Propósito',
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem(value: 'curso', child: Text('Curso Académico (Tareas, dudas y exámenes)', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'objetos_perdidos', child: Text('Objetos Perdidos & Hallazgos', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'comunidad', child: Text('Comunidad de Facultad / Sede', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'deportes', child: Text('Deportes & Actividades Extracurriculares', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'avisos', child: Text('Avisos & Organización Estudiantil', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'otro', child: Text('Interés General / Otro', overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (val) => setState(() => _groupType = val ?? 'curso'),
              ),

              const SizedBox(height: 12),

              // Faculty and Career (Always helpful for contextualizing)
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
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
                  SizedBox(
                    width: isMobile ? double.infinity : 240,
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('carrera_$_selectedFacultad'),
                      initialValue: _selectedCarrera,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Carrera (opcional)',
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
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Dynamic fields based on group type
              if (_groupType == 'curso') ...[
                // Course Name & Section
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    SizedBox(
                      width: isMobile ? double.infinity : 280,
                      child: TextFormField(
                        controller: _cursoController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre del Curso',
                          hintText: 'Ej. Matemática Básica 1',
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        validator: (val) => (val == null || val.trim().isEmpty) ? 'Ingresa el nombre del curso' : null,
                      ),
                    ),
                    SizedBox(
                      width: isMobile ? double.infinity : 200,
                      child: TextFormField(
                        controller: _sectionController,
                        decoration: const InputDecoration(
                          labelText: 'Sección',
                          hintText: 'Ej. Sección A',
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // General purpose title
                TextFormField(
                  controller: _generalTitleController,
                  decoration: InputDecoration(
                    labelText: _groupType == 'objetos_perdidos'
                        ? 'Título del Grupo de Objetos Perdidos'
                        : 'Nombre o Propósito del Grupo',
                    hintText: _groupType == 'objetos_perdidos'
                        ? 'Ej. Objetos Perdidos Campus Central / CUM'
                        : 'Ej. Club de Ajedrez USAC / Comunidad Primer Ingreso',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  validator: (val) => (val == null || val.trim().length < 4) ? 'Ingresa un nombre claro para el grupo' : null,
                ),
              ],

              const SizedBox(height: 12),

              // Invitation Link (WhatsApp, Telegram, Discord, Drive)
              TextFormField(
                controller: _linkController,
                decoration: const InputDecoration(
                  labelText: 'Enlace de Invitación (WhatsApp / Telegram / Discord / Drive)',
                  hintText: 'https://chat.whatsapp.com/..., https://t.me/..., https://discord.gg/...',
                  prefixIcon: Icon(Icons.link, size: 20),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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

              const SizedBox(height: 12),

              // Optional custom description
              TextFormField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Descripción, reglas o notas (opcional)',
                  hintText: 'Ej. Grupo para compartir reportes de objetos extraviados / tareas con el Ing. Morales.',
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),

              const SizedBox(height: 14),

              // Image Upload to Supabase Storage
              Text(
                'Imagen o Logotipo del Grupo (Opcional)',
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),

              if (_uploadedImageUrl != null) ...[
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _uploadedImageUrl!,
                        width: double.infinity,
                        height: 130,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) => Container(
                          height: 130,
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
              ] else ...[
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  onPressed: _isUploadingImage ? null : _pickAndUploadImage,
                  icon: _isUploadingImage
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_photo_alternate_outlined, size: 18),
                  label: Text(_isUploadingImage ? 'Subiendo imagen...' : 'Subir Imagen / Logotipo'),
                ),
              ],

              const SizedBox(height: 18),

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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F5132),
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
                        : const Icon(Icons.check, size: 16),
                    label: Text(_isSubmitting ? 'Guardando...' : 'Compartir Grupo'),
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
