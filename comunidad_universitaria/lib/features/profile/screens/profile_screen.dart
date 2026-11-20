import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../core/constants/avatar_presets.dart';
import '../../../core/constants/categories.dart';
import '../../../core/constants/zanate_colors.dart';
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
import '../../shared/widgets/empty_state_widget.dart';
import '../../shared/widgets/zanate_ui.dart';

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

  // Avatar color palette & icons (compartidos en AvatarPresets)
  static const List<Color> _avatarColors = AvatarPresets.colors;
  static const List<IconData> _avatarIcons = AvatarPresets.icons;

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
            backgroundColor: ZanateColors.zanateBlack,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ZanateColors.card(isDark),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: ZanateColors.border(isDark)),
        ),
        title: Text(
          title,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: ZanateColors.textPrimary(isDark),
          ),
        ),
        content: Text(
          message,
          style: TextStyle(
            fontSize: 13.5,
            color: ZanateColors.textSecondary(isDark),
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: ZanateColors.textMuted(isDark),
            ),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDesktop = Responsive.isDesktop(context);
    final canPop = Navigator.of(context).canPop();
    final bgColor = ZanateColors.bg(isDark);
    final textPrimary = ZanateColors.textPrimary(isDark);
    final borderColor = ZanateColors.border(isDark);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: bgColor,
                border: Border(
                  bottom: BorderSide(color: borderColor),
                ),
              ),
              child: Row(
                children: [
                  if (canPop)
                    IconButton(
                      icon: Icon(
                        PhosphorIconsBold.caretLeft,
                        size: 22,
                        color: textPrimary,
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
                        color: textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: isDark
                            ? ZanateColors.zanateEyeYellow
                            : ZanateColors.zanateBlack,
                      ),
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
                                    backgroundColor: ZanateColors.ctaBg(isDark),
                                    foregroundColor: ZanateColors.ctaFg(isDark),
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
                                      ? SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: ZanateColors.ctaFg(isDark),
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
    final isDark = theme.brightness == Brightness.dark;
    final isAuthenticated = SupabaseService.isAuthenticated;

    final avatarColor = _avatarColors[_selectedAvatarColor];
    final avatarIcon = _avatarIcons[_selectedAvatarIcon];
    final cardColor = ZanateColors.card(isDark);
    final borderColor = ZanateColors.border(isDark);
    final textPrimary = ZanateColors.textPrimary(isDark);
    final textSecondary = ZanateColors.textSecondary(isDark);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
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
                      color: ZanateColors.ctaBg(isDark),
                      shape: BoxShape.circle,
                      border: Border.all(color: cardColor, width: 1.5),
                    ),
                    child: Icon(
                      PhosphorIconsBold.pencilSimple,
                      size: 11,
                      color: ZanateColors.ctaFg(isDark),
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
                          color: textPrimary,
                        ),
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
                          : textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        isAuthenticated
                            ? 'Cuenta Verificada'
                            : 'Perfil Estudiantil',
                        style: TextStyle(
                          fontSize: 12,
                          color: isAuthenticated
                              ? const Color(0xFF059669)
                              : textSecondary,
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
                      color: ZanateColors.surface(isDark),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: borderColor,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          PhosphorIconsRegular.pencilSimple,
                          size: 14,
                          color: textPrimary,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Editar seudónimo',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
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
    Color bgColor = ZanateColors.zanateEyeYellow;
    Color fgColor = ZanateColors.zanateBlack;

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
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = ZanateColors.card(isDark);
    final borderColor = ZanateColors.border(isDark);
    final textPrimary = ZanateColors.textPrimary(isDark);
    final textMuted = ZanateColors.textMuted(isDark);
    final carreras = _getCarrerasForFacultad(_selectedFacultadId);

    // Validate that selected carrera belongs to this facultad
    final bool carreraExists = carreras.any((c) => c.id == _selectedCarreraId);
    if (!carreraExists && carreras.isNotEmpty) {
      _selectedCarreraId = carreras.first.id;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ZanateColors.surface(isDark),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                ),
                child: Icon(
                  PhosphorIconsRegular.graduationCap,
                  color: isDark
                      ? ZanateColors.zanateEyeYellow
                      : ZanateColors.zanateBlack,
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
                    color: textPrimary,
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
            itemHeight: null,
            dropdownColor: cardColor,
            style: TextStyle(fontSize: 13, color: textPrimary),
            borderRadius: BorderRadius.circular(14),
            decoration: zanateInputDecoration(
              isDark: isDark,
              labelText: 'Facultad / Unidad Académica',
              prefixIcon: Icon(
                PhosphorIconsRegular.buildings,
                size: 18,
                color: textMuted,
              ),
            ),
            items: USACConstants.facultades.map((f) {
              return DropdownMenuItem<String>(
                value: f['id'] as String,
                child: Text(
                  f['nombre'] as String,
                  style: TextStyle(fontSize: 13, color: textPrimary),
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
            itemHeight: null,
            dropdownColor: cardColor,
            style: TextStyle(fontSize: 13, color: textPrimary),
            borderRadius: BorderRadius.circular(14),
            decoration: zanateInputDecoration(
              isDark: isDark,
              labelText: 'Carrera',
              prefixIcon: Icon(
                PhosphorIconsRegular.bookOpen,
                size: 18,
                color: textMuted,
              ),
            ),
            items: carreras.map((c) {
              return DropdownMenuItem<String>(
                value: c.id,
                child: Text(
                  c.nombre,
                  style: TextStyle(fontSize: 13, color: textPrimary),
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
            itemHeight: null,
            dropdownColor: cardColor,
            style: TextStyle(fontSize: 13, color: textPrimary),
            borderRadius: BorderRadius.circular(14),
            decoration: zanateInputDecoration(
              isDark: isDark,
              labelText: 'Sede / Centro Universitario',
              prefixIcon: Icon(
                PhosphorIconsRegular.mapPin,
                size: 18,
                color: textMuted,
              ),
            ),
            items: USACConstants.sedes.map((s) {
              return DropdownMenuItem<String>(
                value: s['id'] as String,
                child: Text(
                  '${s['nombre']} (${s['departamento']})',
                  style: TextStyle(fontSize: 13, color: textPrimary),
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
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = ZanateColors.card(isDark);
    final borderColor = ZanateColors.border(isDark);
    final textPrimary = ZanateColors.textPrimary(isDark);
    final textMuted = ZanateColors.textMuted(isDark);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ZanateColors.surface(isDark),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                ),
                child: Icon(
                  PhosphorIconsRegular.addressBook,
                  color: isDark
                      ? ZanateColors.zanateEyeYellow
                      : ZanateColors.zanateBlack,
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
                    color: textPrimary,
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
            style: TextStyle(color: textPrimary),
            decoration: zanateInputDecoration(
              isDark: isDark,
              labelText: 'WhatsApp Predeterminado',
              hintText: '502 12345678',
              prefixIcon: Icon(
                PhosphorIconsRegular.whatsappLogo,
                size: 18,
                color: textMuted,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Instagram
          TextField(
            controller: _instagramController,
            style: TextStyle(color: textPrimary),
            decoration: zanateInputDecoration(
              isDark: isDark,
              labelText: 'Instagram',
              hintText: 'usuario_estudiante',
              prefixIcon: Icon(
                PhosphorIconsRegular.instagramLogo,
                size: 18,
                color: textMuted,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Telegram
          TextField(
            controller: _telegramController,
            style: TextStyle(color: textPrimary),
            decoration: zanateInputDecoration(
              isDark: isDark,
              labelText: 'Telegram',
              hintText: 'usuario_telegram',
              prefixIcon: Icon(
                PhosphorIconsRegular.paperPlaneTilt,
                size: 18,
                color: textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitySection(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = ZanateColors.card(isDark);
    final borderColor = ZanateColors.border(isDark);
    final textPrimary = ZanateColors.textPrimary(isDark);

    return Material(
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: 1.2),
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
                    color: ZanateColors.surface(isDark),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor),
                  ),
                  child: Icon(
                    PhosphorIconsRegular.clockCounterClockwise,
                    color: isDark
                        ? ZanateColors.zanateEyeYellow
                        : ZanateColors.zanateBlack,
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
                      color: textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    PhosphorIconsRegular.arrowsClockwise,
                    size: 18,
                    color: textPrimary,
                  ),
                  tooltip: 'Actualizar actividad',
                  onPressed: _loadUserActivity,
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            indicatorColor: ZanateColors.zanateEyeYellow,
            indicatorWeight: 3,
            dividerColor: borderColor,
            labelColor: textPrimary,
            unselectedLabelColor: ZanateColors.textMuted(isDark),
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
                ? Center(
                    child: CircularProgressIndicator(
                      color: isDark
                          ? ZanateColors.zanateEyeYellow
                          : ZanateColors.zanateBlack,
                    ),
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

  Widget _buildPostsTab(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    if (_myPosts.isEmpty) {
      return const EmptyStateWidget(
        icon: PhosphorIconsRegular.chatsCircle,
        title: 'Sin publicaciones en el foro',
        description:
            'Las consultas o aportes que crees en el Foro Estudiantil aparecerán aquí para que puedas gestionarlos.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _myPosts.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, color: ZanateColors.border(isDark)),
      itemBuilder: (context, index) {
        final post = _myPosts[index];
        return ListTile(
          dense: true,
          title: Text(
            post.title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: ZanateColors.textPrimary(isDark),
            ),
          ),
          subtitle: Text(
            '${TimeUtils.timeAgo(post.createdAt)} • ${post.likes} votos • ${post.commentCount} comentarios',
            style: TextStyle(fontSize: 11, color: ZanateColors.textMuted(isDark)),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  PhosphorIconsRegular.arrowSquareOut,
                  size: 18,
                  color: ZanateColors.textSecondary(isDark),
                ),
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
    final isDark = theme.brightness == Brightness.dark;
    if (_myGroups.isEmpty) {
      return const EmptyStateWidget(
        icon: PhosphorIconsRegular.usersThree,
        title: 'Sin grupos de estudio compartidos',
        description:
            'Los enlaces de grupos de WhatsApp o Discord que compartas se listarán aquí.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _myGroups.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, color: ZanateColors.border(isDark)),
      itemBuilder: (context, index) {
        final group = _myGroups[index];
        return ListTile(
          dense: true,
          title: Text(
            group.title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: ZanateColors.textPrimary(isDark),
            ),
          ),
          subtitle: Text(
            '${group.curso} (${group.section}) • ${group.upvotes} votos',
            style: TextStyle(fontSize: 11, color: ZanateColors.textMuted(isDark)),
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
    final isDark = theme.brightness == Brightness.dark;
    if (_myMarketplaceItems.isEmpty) {
      return const EmptyStateWidget(
        icon: PhosphorIconsRegular.shoppingBag,
        title: 'Sin anuncios en el Marketplace',
        description:
            'Tus publicaciones de productos, comidas, libros o tutorías aparecerán aquí.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _myMarketplaceItems.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, color: ZanateColors.border(isDark)),
      itemBuilder: (context, index) {
        final item = _myMarketplaceItems[index];
        final priceText = item.isFree
            ? 'Gratuito'
            : 'Q${item.price.toStringAsFixed(2)}';

        return ListTile(
          dense: true,
          title: Text(
            item.title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: ZanateColors.textPrimary(isDark),
            ),
          ),
          subtitle: Text(
            '$priceText • ${item.buildingCode} • ${TimeUtils.timeAgo(item.createdAt)}',
            style: TextStyle(fontSize: 11, color: ZanateColors.textMuted(isDark)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: ZanateColors.card(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final textPrimary = ZanateColors.textPrimary(isDark);
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
                          color: ZanateColors.border(isDark),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    Text(
                      'Editar Seudónimo',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _aliasController,
                      maxLength: 35,
                      autofocus: true,
                      style: TextStyle(color: textPrimary),
                      decoration: zanateInputDecoration(
                        isDark: isDark,
                        labelText: 'Seudónimo visible en la comunidad',
                        hintText: 'Ej. Estudiante USAC #402',
                        prefixIcon: Icon(
                          PhosphorIconsRegular.identificationBadge,
                          size: 18,
                          color: ZanateColors.textMuted(isDark),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            PhosphorIconsRegular.diceFive,
                            size: 19,
                            color: textPrimary,
                          ),
                          tooltip: 'Generar seudónimo aleatorio',
                          onPressed: () {
                            _generateRandomAlias();
                            setModalState(() {});
                          },
                        ),
                      ).copyWith(counterText: ''),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ZanateColors.ctaBg(isDark),
                        foregroundColor: ZanateColors.ctaFg(isDark),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: ZanateColors.card(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final textPrimary = ZanateColors.textPrimary(isDark);
            final textSecondary = ZanateColors.textSecondary(isDark);
            final borderColor = ZanateColors.border(isDark);

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
                          color: borderColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    Text(
                      'Personaliza tu Avatar Estudiantil',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Color Picker
                    Text(
                      'Color de Fondo',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: textSecondary,
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
                                    ? (isDark
                                          ? Colors.white
                                          : ZanateColors.zanateBlack)
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
                        color: textSecondary,
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
                                  ? ZanateColors.zanateEyeYellow.withValues(
                                      alpha: 0.22,
                                    )
                                  : ZanateColors.surface(isDark),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? (isDark
                                          ? ZanateColors.zanateEyeYellow
                                          : ZanateColors.zanateBlack)
                                    : borderColor,
                                width: isSelected ? 1.6 : 1.2,
                              ),
                            ),
                            child: Icon(
                              _avatarIcons[idx],
                              size: 20,
                              color: isSelected
                                  ? (isDark
                                        ? ZanateColors.zanateEyeYellow
                                        : ZanateColors.zanateBlack)
                                  : ZanateColors.textMuted(isDark),
                            ),
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 22),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ZanateColors.ctaBg(isDark),
                        foregroundColor: ZanateColors.ctaFg(isDark),
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
