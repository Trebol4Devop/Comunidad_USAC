import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/constants/categories.dart';
import '../../../core/constants/zanate_colors.dart';
import '../../../core/models/post.dart';
import '../../../core/services/forum_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../legal/widgets/terms_consent_modal.dart';
import '../../../core/services/profile_service.dart';
import '../../shared/widgets/auth_modal.dart';
import '../../shared/widgets/gif_picker_modal.dart';
import '../models/discord_forum_models.dart';

class CreatePostDialog extends StatefulWidget {
  final String activeAlias;
  final Post? quotedPost;
  final Function(String newAlias) onAliasChanged;
  final Function(Post newPost) onPostCreated;
  final String? initialCategory;
  final String? initialCarrera;
  final String? initialFacultad;
  final String? serverName;
  final String? channelName;

  const CreatePostDialog({
    super.key,
    required this.activeAlias,
    this.quotedPost,
    required this.onAliasChanged,
    required this.onPostCreated,
    this.initialCategory,
    this.initialCarrera,
    this.initialFacultad,
    this.serverName,
    this.channelName,
  });

  static Future<void> show(
    BuildContext context, {
    required String activeAlias,
    Post? quotedPost,
    required Function(String) onAliasChanged,
    required Function(Post) onPostCreated,
    String? initialCategory,
    String? initialCarrera,
    String? initialFacultad,
    String? serverName,
    String? channelName,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (ctx) => CreatePostDialog(
          activeAlias: activeAlias,
          quotedPost: quotedPost,
          onAliasChanged: onAliasChanged,
          onPostCreated: onPostCreated,
          initialCategory: initialCategory,
          initialCarrera: initialCarrera,
          initialFacultad: initialFacultad,
          serverName: serverName,
          channelName: channelName,
        ),
      ),
    );
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

  late String _selectedCategory;
  late String _selectedFacultad;
  late String _selectedCarrera;
  late String _authorAlias;
  bool _isSubmitting = false;
  bool _isEphemeral = false;

  bool get _canSelectCarrera =>
      widget.initialFacultad != null &&
      widget.initialFacultad != 'todas' &&
      (widget.initialCarrera == null || widget.initialCarrera == 'todas');

  List<ForumCareerItem> get _availableCareers {
    final fac = ForumFaculty.findByFacultadId(_selectedFacultad);
    return fac?.careers.where((c) => c.id != 'todas').toList() ?? [];
  }

  @override
  void initState() {
    super.initState();
    _authorAlias = widget.activeAlias;
    _selectedCategory =
        (widget.initialCategory != null &&
            widget.initialCategory != 'general' &&
            widget.initialCategory != 'bookmarks')
        ? widget.initialCategory!
        : 'todos';
    _selectedFacultad = widget.initialFacultad ?? '08';
    _selectedCarrera = widget.initialCarrera ?? 'todas';

    final careers = _availableCareers;
    if (_canSelectCarrera && careers.isNotEmpty) {
      if (!careers.any((c) => c.id == _selectedCarrera)) {
        _selectedCarrera = careers.first.id;
      }
    }

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

  bool get _canSelectChannel {
    if (widget.channelName != null &&
        widget.channelName!.isNotEmpty &&
        widget.channelName != 'todos-los-temas') {
      return false;
    }
    return widget.initialCategory == null ||
        widget.initialCategory == 'todos' ||
        widget.initialCategory == 'general';
  }

  String get _channelLabel {
    if (widget.channelName != null &&
        widget.channelName!.isNotEmpty &&
        widget.channelName != 'todos-los-temas') {
      return widget.channelName!;
    }
    final cat = USACConstants.forumCategories.firstWhere(
      (c) => c.id == _selectedCategory,
      orElse: () => USACConstants.forumCategories.first,
    );
    return cat.label;
  }

  String get _serverLabel {
    if (widget.serverName != null && widget.serverName!.isNotEmpty) {
      return widget.serverName!;
    }
    if (_selectedCarrera != 'todas') {
      for (var fac in USACConstants.facultades) {
        final carreras = fac['carreras'] as List<dynamic>? ?? [];
        for (var c in carreras) {
          if (c['id'] == _selectedCarrera) return c['nombre'] as String;
        }
      }
    }
    if (_selectedFacultad != 'todas') {
      final fac = USACConstants.facultades.firstWhere(
        (f) => f['id'] == _selectedFacultad,
        orElse: () => USACConstants.facultades.first,
      );
      return fac['nombre'] as String? ?? 'Campus Central';
    }
    return 'Campus Central';
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al subir imagen: $e')));
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

    if (SupabaseConfig.isConfigured) {
      if (!SupabaseService.isAuthenticated) {
        AuthModal.show(
          context,
          title: 'Inicia Sesión para Publicar',
          subtitle:
              'Para crear consultas o citar posts en el foro universitario, debes iniciar sesión.',
          onAuthenticated: () => _submit(),
        );
        return;
      }

      final hasAccepted = await ProfileService.hasAcceptedTerms();
      if (!hasAccepted) {
        if (!mounted) return;
        final accepted = await TermsConsentModal.show(context);
        if (!accepted) return;
      }
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
        authorAlias: _authorAlias,
        imageUrl: _uploadedImageUrl,
        gifUrl: _selectedGifUrl,
        quotedPostId: widget.quotedPost?.id,
        pollQuestion: _showPollForm ? pollQuestion : null,
        pollOptions: _showPollForm ? pollOptions : null,
        ephemeral: _isEphemeral,
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        if (newPost != null) {
          widget.onPostCreated(newPost);
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Publicación creada exitosamente en el foro.'),
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
    bool isDense = false,
    Color? fillColor,
  }) {
    final borderColor =
        isDark ? const Color(0xFF334155) : ZanateColors.subtleBorder;
    final focusColor =
        isDark ? ZanateColors.zanateEyeYellow : ZanateColors.zanateBlack;
    final labelColor =
        isDark ? const Color(0xFF94A3B8) : ZanateColors.mutedText;
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon,
      isDense: isDense,
      labelStyle: TextStyle(color: labelColor),
      floatingLabelStyle: TextStyle(
        color: focusColor,
        fontWeight: FontWeight.w600,
      ),
      filled: true,
      fillColor: fillColor ?? (isDark ? const Color(0xFF1E293B) : ZanateColors.surfaceBg),
      contentPadding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: isDense ? 10 : 12,
      ),
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

    final scaffoldBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final bgFill = isDark ? const Color(0xFF1E293B) : ZanateColors.surfaceBg;
    final borderColor = isDark ? const Color(0xFF334155) : ZanateColors.subtleBorder;
    final primaryTextColor = isDark ? Colors.white : ZanateColors.zanateBlack;
    final secondaryTextColor =
        isDark ? const Color(0xFF94A3B8) : ZanateColors.mutedText;
    final focusColor =
        isDark ? ZanateColors.zanateEyeYellow : ZanateColors.zanateBlack;

    final pageTitle = widget.quotedPost != null
        ? 'Citar Publicación'
        : 'Nueva Consulta en el Foro';

    Widget content = Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 18 : 28,
          vertical: isMobile ? 16 : 24,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

              // Quote preview banner if quoting a post
              if (widget.quotedPost != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: bgFill,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      PhosphorIcon(
                        PhosphorIconsRegular.quotes,
                        size: 20,
                        color: focusColor,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Citando a ${widget.quotedPost!.authorAlias}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                color: primaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.quotedPost!.title,
                              style: TextStyle(
                                fontSize: 12,
                                color: secondaryTextColor,
                              ),
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

              // Canal y Servidor
              if (_canSelectChannel) ...[
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _selectedCategory,
                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  decoration: InputDecoration(
                    labelText: 'Canal de publicación',
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(12),
                      child: PhosphorIcon(
                        PhosphorIconsRegular.hash,
                        size: 20,
                        color: focusColor,
                      ),
                    ),
                    helperText:
                        'Publica tu consulta en el canal correspondiente dentro de $_serverLabel.',
                    filled: true,
                    fillColor: bgFill,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
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
                      borderSide: BorderSide(
                        color: focusColor,
                        width: 1.6,
                      ),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'todos',
                      child: Text(
                        '#todos-los-temas · Todas las áreas / General',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'prerrequisitos',
                      child: Text(
                        '#dudas-y-pensum · Dudas & Pensum',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'catedraticos',
                      child: Text(
                        '#catedraticos-opiniones · Catedráticos',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'apuntes',
                      child: Text(
                        '#apuntes-y-recursos · Apuntes & Exámenes',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'horarios',
                      child: Text(
                        '#horarios-y-secciones · Horarios & Secciones',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedCategory = val);
                    }
                  },
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: bgFill,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      PhosphorIcon(
                        PhosphorIconsBold.hash,
                        size: 20,
                        color: focusColor,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    _channelLabel,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: primaryTextColor,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: ZanateColors.zanateEyeYellow
                                        .withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Canal asignado',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: focusColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Servidor: $_serverLabel',
                              style: TextStyle(
                                fontSize: 11,
                                color: secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PhosphorIcon(
                        PhosphorIconsRegular.lockSimple,
                        size: 16,
                        color: secondaryTextColor,
                      ),
                    ],
                  ),
                ),
              ],

              // Selector de carrera si aplica
              if (_canSelectCarrera && _availableCareers.isNotEmpty) ...[
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _selectedCarrera,
                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  decoration: InputDecoration(
                    labelText: 'Carrera o Especialidad',
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(12),
                      child: PhosphorIcon(
                        PhosphorIconsRegular.graduationCap,
                        size: 20,
                        color: focusColor,
                      ),
                    ),
                    helperText:
                        'Selecciona la carrera correspondiente dentro de $_serverLabel.',
                    filled: true,
                    fillColor: bgFill,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
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
                      borderSide: BorderSide(
                        color: focusColor,
                        width: 1.6,
                      ),
                    ),
                  ),
                  items: _availableCareers.map((c) {
                    return DropdownMenuItem<String>(
                      value: c.id,
                      child: Text(c.name, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedCarrera = val);
                    }
                  },
                ),
              ],

              const SizedBox(height: 16),

              // Post Title
              TextFormField(
                controller: _titleController,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: primaryTextColor,
                ),
                decoration: _zanateInput(
                  isDark,
                  labelText: 'Título de la consulta o aporte',
                  hintText: 'Ej. ¿Qué catedrático recomiendan para Física 1?',
                ),
                validator: (val) {
                  if (val == null || val.trim().length < 3) {
                    return 'El título debe tener al menos 3 caracteres.';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 14),

              // Post Content
              TextFormField(
                controller: _contentController,
                maxLines: 4,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: primaryTextColor,
                ),
                decoration: _zanateInput(
                  isDark,
                  labelText: 'Detalle o descripción',
                  hintText:
                      'Explica tu duda o comparte el material de estudio con la comunidad...',
                ),
                validator: (val) {
                  if (val == null || val.trim().length < 10) {
                    return 'El contenido debe tener al menos 10 caracteres.';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Media & Poll toolbar
              Row(
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryTextColor,
                      side: BorderSide(color: borderColor),
                      backgroundColor: bgFill,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    onPressed: _isUploadingImage ? null : _pickAndUploadImage,
                    icon: PhosphorIcon(
                      PhosphorIconsRegular.image,
                      size: 17,
                      color: focusColor,
                    ),
                    label: const Text('Foto', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryTextColor,
                      side: BorderSide(color: borderColor),
                      backgroundColor: bgFill,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
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
                    icon: PhosphorIcon(
                      PhosphorIconsRegular.gif,
                      size: 17,
                      color: focusColor,
                    ),
                    label: const Text('GIF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _showPollForm
                          ? ZanateColors.zanateBlack
                          : primaryTextColor,
                      side: BorderSide(
                        color: _showPollForm
                            ? ZanateColors.zanateEyeYellow
                            : borderColor,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: _showPollForm
                          ? ZanateColors.zanateEyeYellow
                          : bgFill,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    onPressed: () =>
                        setState(() => _showPollForm = !_showPollForm),
                    icon: PhosphorIcon(
                      PhosphorIconsRegular.chartBar,
                      size: 17,
                      color: _showPollForm
                          ? ZanateColors.zanateBlack
                          : focusColor,
                    ),
                    label: Text(
                      'Encuesta',
                      style: TextStyle(
                        fontSize: 12,
                        color: _showPollForm
                            ? ZanateColors.zanateBlack
                            : primaryTextColor,
                        fontWeight: _showPollForm
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              // Interactive Poll Creator Section (Zanate custom card)
              if (_showPollForm) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: bgFill,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor, width: 1.1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: ZanateColors.zanateEyeYellow,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: const Center(
                              child: PhosphorIcon(
                                PhosphorIconsBold.chartBar,
                                size: 16,
                                color: ZanateColors.zanateBlack,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Crear Encuesta Estudiantil',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: primaryTextColor,
                                  ),
                                ),
                                Text(
                                  '${_pollOptionControllers.length} de 5 opciones',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: secondaryTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              PhosphorIconsRegular.x,
                              size: 18,
                              color: secondaryTextColor,
                            ),
                            tooltip: 'Quitar encuesta',
                            onPressed: () =>
                                setState(() => _showPollForm = false),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _pollQuestionController,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: primaryTextColor,
                        ),
                        decoration: _zanateInput(
                          isDark,
                          labelText: 'Pregunta de la encuesta',
                          hintText: 'Opcional, por defecto usará el título',
                          isDense: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._pollOptionControllers.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final ctrl = entry.value;
                        final letter = String.fromCharCode(65 + idx);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: ZanateColors.zanateEyeYellow
                                      .withValues(alpha: isDark ? 0.22 : 0.35),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    letter,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: isDark
                                          ? ZanateColors.zanateEyeYellow
                                          : ZanateColors.zanateBlack,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: ctrl,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: primaryTextColor,
                                  ),
                                  decoration: _zanateInput(
                                    isDark,
                                    labelText: 'Opción ${idx + 1}',
                                    isDense: true,
                                    fillColor: isDark
                                        ? const Color(0xFF0F172A)
                                        : Colors.white,
                                  ),
                                ),
                              ),
                              if (_pollOptionControllers.length > 2)
                                IconButton(
                                  icon: Icon(
                                    PhosphorIconsRegular.trash,
                                    size: 18,
                                    color: Colors.red.shade400,
                                  ),
                                  onPressed: () => _removePollOption(idx),
                                ),
                            ],
                          ),
                        );
                      }),
                      if (_pollOptionControllers.length < 5)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: focusColor,
                              side: BorderSide(color: borderColor, width: 1.0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            onPressed: _addPollOption,
                            icon: const Icon(PhosphorIconsBold.plus, size: 15),
                            label: const Text(
                              'Añadir opción',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],

              // Attached GIF Preview
              if (_selectedGifUrl != null) ...[
                const SizedBox(height: 14),
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        _selectedGifUrl!,
                        width: double.infinity,
                        height: 160,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: InkWell(
                        onTap: () => setState(() => _selectedGifUrl = null),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            shape: BoxShape.circle,
                          ),
                          child: PhosphorIcon(
                            PhosphorIconsRegular.x,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              // Attached Image Preview
              if (_uploadedImageUrl != null) ...[
                const SizedBox(height: 14),
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        _uploadedImageUrl!,
                        width: double.infinity,
                        height: 160,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) => Container(
                          height: 160,
                          decoration: BoxDecoration(
                            color: bgFill,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Icon(
                              PhosphorIconsRegular.imageBroken,
                              size: 32,
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
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            shape: BoxShape.circle,
                          ),
                          child: PhosphorIcon(
                            PhosphorIconsRegular.x,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 14),

              // Tarjeta para post efímero (La Pizarra Nocturna)
              Material(
                color: bgFill,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: _isEphemeral
                        ? ZanateColors.zanateEyeYellow
                        : borderColor,
                    width: _isEphemeral ? 1.4 : 1.0,
                  ),
                ),
                child: SwitchListTile.adaptive(
                  value: _isEphemeral,
                  activeTrackColor: ZanateColors.zanateBlack,
                  onChanged: (val) => setState(() => _isEphemeral = val),
                  title: Text(
                    'Desaparece en 24h',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: primaryTextColor,
                    ),
                  ),
                  subtitle: Text(
                    'La Pizarra Nocturna: el post se ocultará al amanecer.',
                    style: TextStyle(
                      fontSize: 11,
                      color: secondaryTextColor,
                    ),
                  ),
                  secondary: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _isEphemeral
                          ? ZanateColors.zanateEyeYellow.withValues(alpha: 0.28)
                          : borderColor.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: PhosphorIcon(
                      PhosphorIconsRegular.moonStars,
                      color: _isEphemeral
                          ? (isDark
                              ? ZanateColors.zanateEyeYellow
                              : ZanateColors.zanateBlack)
                          : secondaryTextColor,
                      size: 20,
                    ),
                  ),
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 2,
                  ),
                ),
              ),

              if (_isEphemeral) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          PhosphorIconsRegular.timer,
                          size: 14,
                          color: const Color(0xFFD97706),
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          'Expira en 24 h',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFFD97706),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 22),

              // Action Buttons
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: secondaryTextColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        backgroundColor: isDark
                            ? ZanateColors.zanateEyeYellow
                            : ZanateColors.zanateBlack,
                        foregroundColor: isDark
                            ? ZanateColors.zanateBlack
                            : Colors.white,
                        elevation: 0,
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
                          : PhosphorIcon(
                              PhosphorIconsBold.paperPlaneTilt,
                              size: 16,
                              color: isDark
                                  ? ZanateColors.zanateBlack
                                  : Colors.white,
                            ),
                      label: Text(
                        _isSubmitting ? 'Publicando...' : 'Publicar',
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
      ),
    );

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: scaffoldBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: PhosphorIcon(
            PhosphorIconsBold.caretLeft,
            color: primaryTextColor,
            size: 22,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          pageTitle,
          style: GoogleFonts.outfit(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: primaryTextColor,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: borderColor),
        ),
      ),
      body: SafeArea(child: content),
    );
  }
}
