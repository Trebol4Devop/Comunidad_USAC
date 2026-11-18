import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../core/constants/zanate_colors.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/config/supabase_config.dart';
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
  final String? initialFacultad;
  final String? initialCarrera;

  const CreateGroupDialog({
    super.key,
    required this.activeAlias,
    required this.onAliasChanged,
    required this.onGroupCreated,
    this.initialFacultad,
    this.initialCarrera,
  });

  static Future<void> show(
    BuildContext context, {
    required String activeAlias,
    required Function(String) onAliasChanged,
    required Function(WhatsAppGroup) onGroupCreated,
    String? initialFacultad,
    String? initialCarrera,
  }) {
    if (Responsive.isMobile(context)) {
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF0F172A)
            : Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => CreateGroupDialog(
          activeAlias: activeAlias,
          onAliasChanged: onAliasChanged,
          onGroupCreated: onGroupCreated,
          initialFacultad: initialFacultad,
          initialCarrera: initialCarrera,
        ),
      );
    } else {
      return showDialog(
        context: context,
        builder: (ctx) => CreateGroupDialog(
          activeAlias: activeAlias,
          onAliasChanged: onAliasChanged,
          onGroupCreated: onGroupCreated,
          initialFacultad: initialFacultad,
          initialCarrera: initialCarrera,
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

  String _groupType =
      'curso'; // 'curso', 'objetos_perdidos', 'comunidad', 'deportes', 'avisos', 'otro'
  String _selectedFacultad = '08';
  String _selectedCarrera = 'todas';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialFacultad != null && widget.initialFacultad!.isNotEmpty) {
      _selectedFacultad = widget.initialFacultad!;
    }
    if (widget.initialCarrera != null && widget.initialCarrera!.isNotEmpty) {
      _selectedCarrera = widget.initialCarrera!;
    }
  }

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
        final url = await StorageService.uploadImageFile(
          file,
          folder: 'groups',
        );
        if (url != null && mounted) {
          setState(() {
            _uploadedImageUrl = url;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al subir imagen: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (SupabaseConfig.isConfigured && !SupabaseService.isAuthenticated) {
      AuthModal.show(
        context,
        title: 'Inicia Sesión para Compartir',
        subtitle:
            'Para compartir enlaces de grupos estudiantiles, debes iniciar sesión.',
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
      sectionName = _sectionController.text.trim().isEmpty
          ? 'Sección Única'
          : _sectionController.text.trim();
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

    final carreraToSave =
        (_selectedCarrera == 'todas' && _selectedFacultad != 'todas')
        ? '${_selectedFacultad}_todas'
        : _selectedCarrera;

    try {
      final created = await GroupsService.createGroup(
        title: title,
        carrera: carreraToSave,
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
            content: Text(
              e
                  .toString()
                  .replaceAll('Exception: ', '')
                  .replaceAll('AuthException: ', ''),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  InputDecoration _zanateInput(
    bool isDark, {
    required String labelText,
    String? hintText,
    Widget? prefixIcon,
  }) {
    final borderColor =
        isDark ? const Color(0xFF334155) : ZanateColors.subtleBorder;
    final focusColor =
        isDark ? ZanateColors.zanateEyeYellow : ZanateColors.zanateBlack;
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: isDark ? const Color(0xFF1E293B) : ZanateColors.surfaceBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: borderColor, width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: borderColor, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: focusColor, width: 1.6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMobile = Responsive.isMobile(context);
    final primaryTextColor = isDark ? Colors.white : ZanateColors.zanateBlack;
    final secondaryTextColor =
        isDark ? const Color(0xFF94A3B8) : ZanateColors.mutedText;
    final borderColor =
        isDark ? const Color(0xFF334155) : ZanateColors.subtleBorder;
    final maxHeight =
        MediaQuery.of(context).size.height * (isMobile ? 0.90 : 0.85);

    Widget content = Form(
      key: _formKey,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 20 : 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isMobile) ...[
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: borderColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
              // Header
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: ZanateColors.zanateEyeYellow.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: PhosphorIcon(
                        PhosphorIconsRegular.usersThree,
                        color: isDark
                            ? ZanateColors.zanateEyeYellow
                            : ZanateColors.zanateBlack,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Compartir Enlace de Grupo',
                          style: GoogleFonts.outfit(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Publicado por: ${widget.activeAlias}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: secondaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: ZanateColors.zanateEyeYellow,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: isDark
                          ? ZanateColors.zanateEyeYellow
                          : ZanateColors.zanateBlack,
                    ),
                    icon: const PhosphorIcon(
                      PhosphorIconsRegular.pencilSimple,
                      size: 15,
                    ),
                    label: const Text(
                      'Alias',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
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
              const SizedBox(height: 18),

              // Group Type Selector
              DropdownButtonFormField<String>(
                initialValue: _groupType,
                isExpanded: true,
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                decoration: _zanateInput(
                  isDark,
                  labelText: 'Tipo de Grupo / Propósito',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'curso',
                    child: Text(
                      'Curso Académico',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'objetos_perdidos',
                    child: Text(
                      'Objetos Perdidos & Hallazgos',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'comunidad',
                    child: Text(
                      'Comunidad de Facultad / Sede',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'deportes',
                    child: Text(
                      'Deportes & Actividades Extracurriculares',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'avisos',
                    child: Text(
                      'Avisos & Organización Estudiantil',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'otro',
                    child: Text(
                      'Interés General / Otro',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
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
                      dropdownColor:
                          isDark ? const Color(0xFF1E293B) : Colors.white,
                      decoration: _zanateInput(
                        isDark,
                        labelText: 'Facultad / Unidad',
                      ),
                      items: USACConstants.facultades
                          .map(
                            (f) => DropdownMenuItem<String>(
                              value: f['id'].toString(),
                              child: Text(
                                f['nombre'].toString(),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          )
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
                      dropdownColor:
                          isDark ? const Color(0xFF1E293B) : Colors.white,
                      decoration: _zanateInput(
                        isDark,
                        labelText: 'Carrera',
                      ),
                      items: _availableCarreras
                          .map(
                            (c) => DropdownMenuItem<String>(
                              value: c['id'].toString(),
                              child: Text(
                                c['nombre'].toString(),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedCarrera = val ?? 'todas'),
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
                        decoration: _zanateInput(
                          isDark,
                          labelText: 'Nombre del Curso',
                          hintText: 'Ej. Matemática Básica 1',
                        ),
                        validator: (val) => (val == null || val.trim().isEmpty)
                            ? 'Ingresa el nombre del curso'
                            : null,
                      ),
                    ),
                    SizedBox(
                      width: isMobile ? double.infinity : 200,
                      child: TextFormField(
                        controller: _sectionController,
                        decoration: _zanateInput(
                          isDark,
                          labelText: 'Sección',
                          hintText: 'Ej. Sección A',
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // General purpose title
                TextFormField(
                  controller: _generalTitleController,
                  decoration: _zanateInput(
                    isDark,
                    labelText: _groupType == 'objetos_perdidos'
                        ? 'Título del Grupo de Objetos Perdidos'
                        : 'Nombre o Propósito del Grupo',
                    hintText: _groupType == 'objetos_perdidos'
                        ? 'Ej. Objetos Perdidos Campus Central / CUM'
                        : 'Ej. Club de Ajedrez USAC / Comunidad Primer Ingreso',
                  ),
                  validator: (val) => (val == null || val.trim().length < 4)
                      ? 'Ingresa un nombre claro para el grupo'
                      : null,
                ),
              ],

              const SizedBox(height: 12),

              // Invitation Link
              TextFormField(
                controller: _linkController,
                decoration: _zanateInput(
                  isDark,
                  labelText: 'Enlace de Invitación',
                  hintText:
                      'https://chat.whatsapp.com/..., https://t.me/..., https://discord.gg/...',
                  prefixIcon: const Padding(
                    padding: EdgeInsets.all(12),
                    child: PhosphorIcon(PhosphorIconsRegular.link, size: 20),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Pega el enlace de invitación del grupo.';
                  }
                  final lower = val.toLowerCase();
                  if (!lower.startsWith('http://') &&
                      !lower.startsWith('https://')) {
                    return 'El enlace debe comenzar con https://';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 12),

              // Description
              TextFormField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: _zanateInput(
                  isDark,
                  labelText: 'Descripción, reglas o notas',
                  hintText:
                      'Ej. Grupo para compartir reportes de objetos extraviados / tareas con el Ing. Morales.',
                ),
              ),

              const SizedBox(height: 14),

              // Image Upload to Supabase Storage
              Text(
                'Imagen o Logotipo del Grupo',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),

              if (_uploadedImageUrl != null) ...[
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        _uploadedImageUrl!,
                        width: double.infinity,
                        height: 130,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) => Container(
                          height: 130,
                          color: isDark
                              ? const Color(0xFF1E293B)
                              : ZanateColors.surfaceBg,
                          child: Center(
                            child: PhosphorIcon(
                              PhosphorIconsRegular.imageBroken,
                              color: secondaryTextColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: InkWell(
                        onTap: () => setState(() => _uploadedImageUrl = null),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const PhosphorIcon(
                            PhosphorIconsRegular.x,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryTextColor,
                    backgroundColor: isDark
                        ? const Color(0xFF1E293B)
                        : ZanateColors.surfaceBg,
                    side: BorderSide(color: borderColor, width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  onPressed: _isUploadingImage ? null : _pickAndUploadImage,
                  icon: _isUploadingImage
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : PhosphorIcon(
                          PhosphorIconsRegular.image,
                          size: 18,
                          color: primaryTextColor,
                        ),
                  label: Text(
                    _isUploadingImage
                        ? 'Subiendo imagen...'
                        : 'Subir Imagen / Logotipo',
                  ),
                ),
              ],

              const SizedBox(height: 18),

              // Submit Buttons
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: secondaryTextColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark
                            ? ZanateColors.zanateEyeYellow
                            : ZanateColors.zanateBlack,
                        foregroundColor: isDark
                            ? ZanateColors.zanateBlack
                            : Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 13,
                        ),
                      ),
                      onPressed: _isSubmitting ? null : _submit,
                      icon: _isSubmitting
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: isDark
                                    ? ZanateColors.zanateBlack
                                    : Colors.white,
                              ),
                            )
                          : const PhosphorIcon(
                              PhosphorIconsBold.paperPlaneTilt,
                              size: 16,
                            ),
                      label: Text(
                        _isSubmitting ? 'Guardando...' : 'Compartir Grupo',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (isMobile) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: content,
      );
    } else {
      return Dialog(
        backgroundColor: theme.brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: theme.brightness == Brightness.dark ? const Color(0xFF334155) : ZanateColors.subtleBorder,
            width: 0.8,
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: content,
        ),
      );
    }
  }
}
