import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../core/constants/categories.dart';
import '../../../core/models/facultad.dart';
import '../../../core/models/marketplace_item.dart';
import '../../../core/models/post.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/models/whatsapp_group.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/time_utils.dart';
import '../../forum/screens/post_detail_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String activeAlias;
  final Function(String newAlias) onAliasChanged;
  final VoidCallback? onToggleTheme;
  final bool isDarkMode;

  const ProfileScreen({
    super.key,
    required this.activeAlias,
    required this.onAliasChanged,
    this.onToggleTheme,
    this.isDarkMode = false,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isLoading = true;
  bool _isSaving = false;
  UserProfile? _profile;

  // Controllers for editing
  late TextEditingController _aliasController;
  late TextEditingController _bioController;
  late TextEditingController _whatsappController;
  late TextEditingController _telegramController;
  late TextEditingController _instagramController;

  String _selectedFacultadId = '08';
  String _selectedCarreraId = 'sistemas';
  String _selectedSedeId = 'central';
  int _selectedAvatarColor = 0;
  int _selectedAvatarIcon = 0;

  // Activity lists
  List<Post> _myPosts = [];
  List<WhatsAppGroup> _myGroups = [];
  List<MarketplaceItem> _myMarketplaceItems = [];
  bool _isLoadingActivity = false;

  // Avatar color palette
  static const List<Color> _avatarColors = [
    Color(0xFF004B87), // USAC Blue
    Color(0xFF0D9488), // Teal
    Color(0xFF7C3AED), // Purple
    Color(0xFFD97706), // Amber
    Color(0xFFDC2626), // Red
    Color(0xFF2563EB), // Royal Blue
    Color(0xFF059669), // Emerald
    Color(0xFF475569), // Slate
  ];

  // Avatar icons
  static const List<IconData> _avatarIcons = [
    PhosphorIconsRegular.graduationCap,
    PhosphorIconsRegular.user,
    PhosphorIconsRegular.bookOpen,
    PhosphorIconsRegular.flask,
    PhosphorIconsRegular.wrench,
    PhosphorIconsRegular.palette,
    PhosphorIconsRegular.laptop,
    PhosphorIconsRegular.bank,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _aliasController = TextEditingController(text: widget.activeAlias);
    _bioController = TextEditingController();
    _whatsappController = TextEditingController();
    _telegramController = TextEditingController();
    _instagramController = TextEditingController();

    _loadFullProfile();
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeAlias != widget.activeAlias && _profile != null) {
      if (_aliasController.text != widget.activeAlias) {
        _aliasController.text = widget.activeAlias;
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _aliasController.dispose();
    _bioController.dispose();
    _whatsappController.dispose();
    _telegramController.dispose();
    _instagramController.dispose();
    super.dispose();
  }

  Future<void> _loadFullProfile() async {
    setState(() => _isLoading = true);

    try {
      final profile = await ProfileService.loadProfile();
      setState(() {
        _profile = profile;
        _aliasController.text = profile.alias;
        _bioController.text = profile.bio;
        _selectedFacultadId = profile.facultadId;
        _selectedCarreraId = profile.carreraId;
        _selectedSedeId = profile.sedeId;
        _selectedAvatarColor = profile.avatarColorIndex.clamp(
          0,
          _avatarColors.length - 1,
        );
        _selectedAvatarIcon = profile.avatarIconIndex.clamp(
          0,
          _avatarIcons.length - 1,
        );
        _whatsappController.text = profile.contactWhatsapp ?? '';
        _telegramController.text = profile.contactTelegram ?? '';
        _instagramController.text = profile.contactInstagram ?? '';
        _isLoading = false;
      });

      _loadUserActivity();
    } catch (e) {
      debugPrint('Error cargando perfil: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUserActivity() async {
    if (_profile == null) return;
    setState(() => _isLoadingActivity = true);

    try {
      final posts = await ProfileService.fetchUserPosts(
        alias: _profile!.alias,
        userId: _profile!.userId,
      );
      final groups = await ProfileService.fetchUserGroups(
        alias: _profile!.alias,
        userId: _profile!.userId,
      );
      final items = await ProfileService.fetchUserMarketplaceItems(
        alias: _profile!.alias,
        userId: _profile!.userId,
      );

      if (mounted) {
        setState(() {
          _myPosts = posts;
          _myGroups = groups;
          _myMarketplaceItems = items;
          _isLoadingActivity = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando actividad de usuario: $e');
      if (mounted) {
        setState(() => _isLoadingActivity = false);
      }
    }
  }

  void _generateRandomAlias() {
    final num = 100 + Random().nextInt(900);
    setState(() {
      _aliasController.text = 'Estudiante USAC #$num';
    });
  }

  Future<void> _saveProfile() async {
    final aliasText = _aliasController.text.trim();
    if (aliasText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El seudónimo no puede estar vacío.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final updatedProfile = _profile!.copyWith(
        alias: aliasText,
        bio: _bioController.text.trim(),
        facultadId: _selectedFacultadId,
        carreraId: _selectedCarreraId,
        sedeId: _selectedSedeId,
        avatarColorIndex: _selectedAvatarColor,
        avatarIconIndex: _selectedAvatarIcon,
        contactWhatsapp: _whatsappController.text.trim().isEmpty
            ? null
            : _whatsappController.text.trim(),
        contactTelegram: _telegramController.text.trim().isEmpty
            ? null
            : _telegramController.text.trim(),
        contactInstagram: _instagramController.text.trim().isEmpty
            ? null
            : _instagramController.text.trim(),
      );

      await ProfileService.saveProfile(updatedProfile);
      widget.onAliasChanged(aliasText);

      setState(() {
        _profile = updatedProfile;
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil guardado exitosamente.'),
            backgroundColor: Color(0xFF004B87),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al guardar perfil: $e')));
      }
    }
  }

  Future<void> _deletePost(Post post) async {
    final confirm = await _showConfirmDialog(
      title: 'Eliminar Publicación',
      message:
          '¿Estás seguro de que deseas eliminar este tema del foro? Esta acción no se puede deshacer.',
    );
    if (confirm != true) return;

    final success = await ProfileService.deletePost(post.id);
    if (success && mounted) {
      setState(() {
        _myPosts.removeWhere((p) => p.id == post.id);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Publicación eliminada.')));
    }
  }

  Future<void> _deleteGroup(WhatsAppGroup group) async {
    final confirm = await _showConfirmDialog(
      title: 'Eliminar Grupo',
      message:
          '¿Estás seguro de que deseas retirar este grupo de estudio compartido?',
    );
    if (confirm != true) return;

    final success = await ProfileService.deleteGroup(group.id);
    if (success && mounted) {
      setState(() {
        _myGroups.removeWhere((g) => g.id == group.id);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Grupo eliminado.')));
    }
  }

  Future<void> _deleteMarketplaceItem(MarketplaceItem item) async {
    final confirm = await _showConfirmDialog(
      title: 'Eliminar Anuncio',
      message:
          '¿Estás seguro de que deseas retirar este artículo o servicio del Marketplace?',
    );
    if (confirm != true) return;

    final success = await ProfileService.deleteMarketplaceItem(item.id);
    if (success && mounted) {
      setState(() {
        _myMarketplaceItems.removeWhere((i) => i.id == item.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Anuncio retirado del Marketplace.')),
      );
    }
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Text(message, style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  List<Carrera> _getCarrerasForFacultad(String facultadId) {
    final facultadMap = USACConstants.facultades.firstWhere(
      (f) => f['id'] == facultadId,
      orElse: () => USACConstants.facultades.first,
    );
    final rawList = facultadMap['carreras'] as List<dynamic>? ?? [];
    return rawList
        .map((c) => Carrera.fromMap(Map<String, dynamic>.from(c)))
        .toList();
  }

  static const _zanateBlack = Color(0xFF0B0D10);
  static const _zanateEyeYellow = Color(0xFFF5C518);
  static const _subtleText = Color(0xFF475569);

  InputDecoration _zanateInput({
    required String labelText,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    String? counterText,
  }) {
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _zanateBlack, width: 1.6),
    );
    final errorBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
    );

    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      counterText: counterText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: const TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
        color: Color(0xFF64748B),
      ),
      floatingLabelStyle: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: _zanateBlack,
      ),
      hintStyle: const TextStyle(
        fontSize: 13.5,
        color: Color(0xFF94A3B8),
      ),
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: focusedBorder,
      errorBorder: errorBorder,
      focusedErrorBorder: errorBorder,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = Responsive.isDesktop(context);
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                children: [
                  if (canPop)
                    IconButton(
                      icon: const Icon(
                        PhosphorIconsBold.caretLeft,
                        size: 22,
                        color: _zanateBlack,
                      ),
                      tooltip: 'Regresar',
                      onPressed: () => Navigator.of(context).pop(),
                    )
                  else
                    const SizedBox(width: 48),
                  Expanded(
                    child: Text(
                      'Preferencias de Usuario',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _zanateBlack,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: _zanateBlack),
                    )
                  : SingleChildScrollView(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1000),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: isDesktop ? 32 : 20,
                              vertical: 20,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Profile Header Card
                                _buildHeaderCard(theme, isDesktop),
                                const SizedBox(height: 16),

                                // Academic & Contact Settings (Two columns on desktop, stacked on mobile)
                                if (isDesktop)
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: _buildAcademicCard(theme),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(child: _buildContactCard(theme)),
                                    ],
                                  )
                                else ...[
                                  _buildAcademicCard(theme),
                                  const SizedBox(height: 16),
                                  _buildContactCard(theme),
                                ],

                                const SizedBox(height: 20),

                                // Save Profile Button
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _zanateBlack,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    minimumSize: const Size.fromHeight(52),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: _isSaving ? null : _saveProfile,
                                  icon: _isSaving
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(
                                          PhosphorIconsBold.floppyDisk,
                                          size: 19,
                                        ),
                                  label: Text(
                                    _isSaving
                                        ? 'Guardando...'
                                        : 'Guardar Cambios de Perfil',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14.5,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 24),

                                // User Activity Section (Tabs)
                                _buildActivitySection(theme),
                                const SizedBox(height: 40),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(ThemeData theme, bool isDesktop) {
    final isAuthenticated = SupabaseService.isAuthenticated;

    final avatarColor = _avatarColors[_selectedAvatarColor];
    final avatarIcon = _avatarIcons[_selectedAvatarIcon];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar with visual picker
          Stack(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: avatarColor,
                child: Icon(avatarIcon, size: 32, color: Colors.white),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: InkWell(
                  onTap: _showAvatarPickerModal,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: _zanateBlack,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Icon(
                      PhosphorIconsBold.pencilSimple,
                      size: 11,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),

          // Title, Role Badge & Edit Pseudonym Action
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        _aliasController.text.isEmpty
                            ? 'Estudiante USAC'
                            : _aliasController.text,
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: _zanateBlack,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildRoleBadge(theme),
                  ],
                ),
                const SizedBox(height: 4),

                // Auth State Badge (sin correo)
                Row(
                  children: [
                    Icon(
                      isAuthenticated
                          ? PhosphorIconsRegular.cloudCheck
                          : PhosphorIconsRegular.user,
                      size: 14,
                      color: isAuthenticated
                          ? const Color(0xFF059669)
                          : _subtleText,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        isAuthenticated
                            ? 'Cuenta Verificada'
                            : 'Perfil Estudiantil',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isAuthenticated
                              ? const Color(0xFF059669)
                              : _subtleText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Edit pseudonym button
                InkWell(
                  onTap: _showAliasEditorModal,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          PhosphorIconsRegular.pencilSimple,
                          size: 14,
                          color: _zanateBlack,
                        ),
                        const SizedBox(width: 6),
                        const Flexible(
                          child: Text(
                            'Editar seudónimo',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _zanateBlack,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleBadge(ThemeData theme) {
    final role = _profile?.role ?? 'student';
    String label = 'Estudiante';
    IconData icon = PhosphorIconsRegular.graduationCap;
    Color bgColor = _zanateEyeYellow;
    Color fgColor = _zanateBlack;

    if (role == 'admin') {
      label = 'Admin';
      icon = PhosphorIconsFill.shieldCheck;
      bgColor = const Color(0xFFDC2626);
      fgColor = Colors.white;
    } else if (role == 'moderator') {
      label = 'Mod';
      icon = PhosphorIconsRegular.shield;
      bgColor = const Color(0xFFD97706);
      fgColor = Colors.white;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: fgColor),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: fgColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcademicCard(ThemeData theme) {
    final carreras = _getCarrerasForFacultad(_selectedFacultadId);

    // Validate that selected carrera belongs to this facultad
    final bool carreraExists = carreras.any((c) => c.id == _selectedCarreraId);
    if (!carreraExists && carreras.isNotEmpty) {
      _selectedCarreraId = carreras.first.id;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Icon(
                  PhosphorIconsRegular.graduationCap,
                  color: _zanateBlack,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Información Académica (Opcional)',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700,
                    fontSize: 15.5,
                    color: _zanateBlack,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Facultad Dropdown
          DropdownButtonFormField<String>(
            key: ValueKey('facultad_$_selectedFacultadId'),
            initialValue: _selectedFacultadId,
            isExpanded: true,
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(14),
            decoration: _zanateInput(
              labelText: 'Facultad / Unidad Académica',
              prefixIcon: const Icon(
                PhosphorIconsRegular.buildings,
                size: 18,
                color: _subtleText,
              ),
            ),
            items: USACConstants.facultades.map((f) {
              return DropdownMenuItem<String>(
                value: f['id'] as String,
                child: Text(
                  f['nombre'] as String,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              );
            }).toList(),
            onChanged: (newFacultadId) {
              if (newFacultadId != null) {
                setState(() {
                  _selectedFacultadId = newFacultadId;
                  final availableCarreras = _getCarrerasForFacultad(
                    newFacultadId,
                  );
                  _selectedCarreraId = availableCarreras.isNotEmpty
                      ? availableCarreras.first.id
                      : 'todas';
                });
              }
            },
          ),
          const SizedBox(height: 12),

          // Carrera Dropdown
          DropdownButtonFormField<String>(
            key: ValueKey('carrera_${_selectedFacultadId}_$_selectedCarreraId'),
            initialValue: _selectedCarreraId,
            isExpanded: true,
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(14),
            decoration: _zanateInput(
              labelText: 'Carrera',
              prefixIcon: const Icon(
                PhosphorIconsRegular.bookOpen,
                size: 18,
                color: _subtleText,
              ),
            ),
            items: carreras.map((c) {
              return DropdownMenuItem<String>(
                value: c.id,
                child: Text(
                  c.nombre,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              );
            }).toList(),
            onChanged: (newCarreraId) {
              if (newCarreraId != null) {
                setState(() => _selectedCarreraId = newCarreraId);
              }
            },
          ),
          const SizedBox(height: 12),

          // Sede Dropdown
          DropdownButtonFormField<String>(
            key: ValueKey('sede_$_selectedSedeId'),
            initialValue: _selectedSedeId,
            isExpanded: true,
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(14),
            decoration: _zanateInput(
              labelText: 'Sede / Centro Universitario',
              prefixIcon: const Icon(
                PhosphorIconsRegular.mapPin,
                size: 18,
                color: _subtleText,
              ),
            ),
            items: USACConstants.sedes.map((s) {
              return DropdownMenuItem<String>(
                value: s['id'] as String,
                child: Text(
                  '${s['nombre']} (${s['departamento']})',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              );
            }).toList(),
            onChanged: (newSedeId) {
              if (newSedeId != null) {
                setState(() => _selectedSedeId = newSedeId);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Icon(
                  PhosphorIconsRegular.addressBook,
                  color: _zanateBlack,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Canales de Contacto (Opcional)',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700,
                    fontSize: 15.5,
                    color: _zanateBlack,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // WhatsApp
          TextField(
            controller: _whatsappController,
            keyboardType: TextInputType.phone,
            decoration: _zanateInput(
              labelText: 'WhatsApp Predeterminado',
              hintText: '502 12345678',
              prefixIcon: const Icon(
                PhosphorIconsRegular.whatsappLogo,
                size: 18,
                color: _subtleText,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Instagram
          TextField(
            controller: _instagramController,
            decoration: _zanateInput(
              labelText: 'Instagram',
              hintText: 'usuario_estudiante',
              prefixIcon: const Icon(
                PhosphorIconsRegular.instagramLogo,
                size: 18,
                color: _subtleText,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Telegram
          TextField(
            controller: _telegramController,
            decoration: _zanateInput(
              labelText: 'Telegram',
              hintText: 'usuario_telegram',
              prefixIcon: const Icon(
                PhosphorIconsRegular.paperPlaneTilt,
                size: 18,
                color: _subtleText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitySection(ThemeData theme) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Icon(
                    PhosphorIconsRegular.clockCounterClockwise,
                    color: _zanateBlack,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Mi Actividad y Contenidos',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w700,
                      fontSize: 15.5,
                      color: _zanateBlack,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    PhosphorIconsRegular.arrowsClockwise,
                    size: 18,
                    color: _zanateBlack,
                  ),
                  tooltip: 'Actualizar actividad',
                  onPressed: _loadUserActivity,
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            indicatorColor: _zanateEyeYellow,
            indicatorWeight: 3,
            dividerColor: const Color(0xFFE2E8F0),
            labelColor: _zanateBlack,
            unselectedLabelColor: const Color(0xFF64748B),
            labelStyle: GoogleFonts.outfit(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            unselectedLabelStyle: GoogleFonts.outfit(
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
            tabs: [
              Tab(
                icon: const Icon(PhosphorIconsRegular.chatsCircle, size: 18),
                text: 'Mis Posts · ${_myPosts.length}',
              ),
              Tab(
                icon: const Icon(PhosphorIconsRegular.usersThree, size: 18),
                text: 'Mis Grupos · ${_myGroups.length}',
              ),
              Tab(
                icon: const Icon(PhosphorIconsRegular.shoppingBag, size: 18),
                text: 'Mis Anuncios · ${_myMarketplaceItems.length}',
              ),
            ],
          ),
          SizedBox(
            height: 350,
            child: _isLoadingActivity
                ? const Center(
                    child: CircularProgressIndicator(color: _zanateBlack),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildPostsTab(theme),
                      _buildGroupsTab(theme),
                      _buildMarketplaceTab(theme),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyActivityState({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF8FAFC),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1.2,
                ),
              ),
              child: Icon(icon, size: 32, color: _zanateBlack),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _zanateBlack,
              ),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: _subtleText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostsTab(ThemeData theme) {
    if (_myPosts.isEmpty) {
      return _buildEmptyActivityState(
        icon: PhosphorIconsRegular.chatsCircle,
        title: 'Sin publicaciones en el foro',
        description:
            'Las consultas o aportes que crees en el Foro Estudiantil aparecerán aquí para que puedas gestionarlos.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _myPosts.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final post = _myPosts[index];
        return ListTile(
          dense: true,
          title: Text(
            post.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          subtitle: Text(
            '${TimeUtils.timeAgo(post.createdAt)} • ${post.likes} votos • ${post.commentCount} comentarios',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(PhosphorIconsRegular.arrowSquareOut, size: 18),
                tooltip: 'Ver detalle de post',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => PostDetailScreen(
                        initialPost: post,
                        activeAlias: widget.activeAlias,
                      ),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(
                  PhosphorIconsRegular.trash,
                  size: 18,
                  color: Color(0xFFDC2626),
                ),
                tooltip: 'Eliminar tema',
                onPressed: () => _deletePost(post),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGroupsTab(ThemeData theme) {
    if (_myGroups.isEmpty) {
      return _buildEmptyActivityState(
        icon: PhosphorIconsRegular.usersThree,
        title: 'Sin grupos de estudio compartidos',
        description:
            'Los enlaces de grupos de WhatsApp o Discord que compartas se listarán aquí.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _myGroups.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final group = _myGroups[index];
        return ListTile(
          dense: true,
          title: Text(
            group.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          subtitle: Text(
            '${group.curso} (${group.section}) • ${group.upvotes} votos',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          trailing: IconButton(
            icon: const Icon(
              PhosphorIconsRegular.trash,
              size: 18,
              color: Color(0xFFDC2626),
            ),
            tooltip: 'Eliminar grupo',
            onPressed: () => _deleteGroup(group),
          ),
        );
      },
    );
  }

  Widget _buildMarketplaceTab(ThemeData theme) {
    if (_myMarketplaceItems.isEmpty) {
      return _buildEmptyActivityState(
        icon: PhosphorIconsRegular.shoppingBag,
        title: 'Sin anuncios en el Marketplace',
        description:
            'Tus publicaciones de productos, comidas, libros o tutorías aparecerán aquí.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _myMarketplaceItems.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = _myMarketplaceItems[index];
        final priceText = item.isFree
            ? 'Gratuito'
            : 'Q${item.price.toStringAsFixed(2)}';

        return ListTile(
          dense: true,
          title: Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          subtitle: Text(
            '$priceText • ${item.buildingCode} • ${TimeUtils.timeAgo(item.createdAt)}',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          trailing: IconButton(
            icon: const Icon(
              PhosphorIconsRegular.trash,
              size: 18,
              color: Color(0xFFDC2626),
            ),
            tooltip: 'Eliminar anuncio',
            onPressed: () => _deleteMarketplaceItem(item),
          ),
        );
      },
    );
  }

  void _showAliasEditorModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  20 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    Text(
                      'Editar Seudónimo',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        color: _zanateBlack,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _aliasController,
                      maxLength: 35,
                      autofocus: true,
                      decoration: _zanateInput(
                        labelText: 'Seudónimo visible en la comunidad',
                        hintText: 'Ej. Estudiante USAC #402',
                        prefixIcon: const Icon(
                          PhosphorIconsRegular.identificationBadge,
                          size: 18,
                          color: _subtleText,
                        ),
                        counterText: '',
                        suffixIcon: IconButton(
                          icon: const Icon(
                            PhosphorIconsRegular.diceFive,
                            size: 19,
                            color: _zanateBlack,
                          ),
                          tooltip: 'Generar seudónimo aleatorio',
                          onPressed: () {
                            _generateRandomAlias();
                            setModalState(() {});
                          },
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _zanateBlack,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text(
                        'Listo',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAvatarPickerModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    Text(
                      'Personaliza tu Avatar Estudiantil',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        color: _zanateBlack,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Color Picker
                    Text(
                      'Color de Fondo',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: _subtleText,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: List.generate(_avatarColors.length, (idx) {
                        final isSelected = _selectedAvatarColor == idx;
                        return InkWell(
                          onTap: () {
                            setModalState(() => _selectedAvatarColor = idx);
                            setState(() => _selectedAvatarColor = idx);
                          },
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: _avatarColors[idx],
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? _zanateBlack
                                    : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(
                                    PhosphorIconsBold.check,
                                    size: 18,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 18),

                    // Icon Picker
                    Text(
                      'Icono Representativo',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: _subtleText,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: List.generate(_avatarIcons.length, (idx) {
                        final isSelected = _selectedAvatarIcon == idx;
                        return InkWell(
                          onTap: () {
                            setModalState(() => _selectedAvatarIcon = idx);
                            setState(() => _selectedAvatarIcon = idx);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? _zanateEyeYellow.withValues(alpha: 0.22)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? _zanateBlack
                                    : const Color(0xFFE2E8F0),
                                width: isSelected ? 1.6 : 1.2,
                              ),
                            ),
                            child: Icon(
                              _avatarIcons[idx],
                              size: 20,
                              color: isSelected ? _zanateBlack : _subtleText,
                            ),
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 22),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _zanateBlack,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text(
                        'Listo',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
