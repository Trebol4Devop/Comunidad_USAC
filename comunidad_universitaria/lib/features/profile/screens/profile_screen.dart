import 'dart:math';
import 'package:flutter/material.dart';
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
import '../../rules/screens/rules_screen.dart';
import '../../shared/widgets/auth_modal.dart';
import '../../shared/widgets/empty_state_widget.dart';

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

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
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
    Icons.school,
    Icons.person,
    Icons.menu_book,
    Icons.science,
    Icons.engineering,
    Icons.palette,
    Icons.laptop_chromebook,
    Icons.account_balance,
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
        _selectedAvatarColor = profile.avatarColorIndex.clamp(0, _avatarColors.length - 1);
        _selectedAvatarIcon = profile.avatarIconIndex.clamp(0, _avatarIcons.length - 1);
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
        contactWhatsapp: _whatsappController.text.trim().isEmpty ? null : _whatsappController.text.trim(),
        contactTelegram: _telegramController.text.trim().isEmpty ? null : _telegramController.text.trim(),
        contactInstagram: _instagramController.text.trim().isEmpty ? null : _instagramController.text.trim(),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar perfil: $e')),
        );
      }
    }
  }

  Future<void> _deletePost(Post post) async {
    final confirm = await _showConfirmDialog(
      title: 'Eliminar Publicación',
      message: '¿Estás seguro de que deseas eliminar este tema del foro? Esta acción no se puede deshacer.',
    );
    if (confirm != true) return;

    final success = await ProfileService.deletePost(post.id);
    if (success && mounted) {
      setState(() {
        _myPosts.removeWhere((p) => p.id == post.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Publicación eliminada.')),
      );
    }
  }

  Future<void> _deleteGroup(WhatsAppGroup group) async {
    final confirm = await _showConfirmDialog(
      title: 'Eliminar Grupo',
      message: '¿Estás seguro de que deseas retirar este grupo de estudio compartido?',
    );
    if (confirm != true) return;

    final success = await ProfileService.deleteGroup(group.id);
    if (success && mounted) {
      setState(() {
        _myGroups.removeWhere((g) => g.id == group.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Grupo eliminado.')),
      );
    }
  }

  Future<void> _deleteMarketplaceItem(MarketplaceItem item) async {
    final confirm = await _showConfirmDialog(
      title: 'Eliminar Anuncio',
      message: '¿Estás seguro de que deseas retirar este artículo o servicio del Marketplace?',
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

  Future<bool?> _showConfirmDialog({required String title, required String message}) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text(message, style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
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
    return rawList.map((c) => Carrera.fromMap(Map<String, dynamic>.from(c))).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = Responsive.isDesktop(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 32 : 16,
                vertical: 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Profile Header Card
                  _buildHeaderCard(theme, isDesktop),
                  const SizedBox(height: 20),

                  // Academic & Contact Settings (Two columns on desktop, stacked on mobile)
                  if (isDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildAcademicCard(theme)),
                        const SizedBox(width: 20),
                        Expanded(child: _buildContactCard(theme)),
                      ],
                    )
                  else ...[
                    _buildAcademicCard(theme),
                    const SizedBox(height: 16),
                    _buildContactCard(theme),
                  ],

                  const SizedBox(height: 24),

                  // Save Profile Button
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF004B87),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isSaving ? null : _saveProfile,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save_outlined, size: 18),
                      label: Text(
                        _isSaving ? 'Guardando...' : 'Guardar Cambios de Perfil',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // User Activity Section (Tabs)
                  _buildActivitySection(theme),

                  const SizedBox(height: 28),

                  // Data Usage & Privacy Transparency Section
                  _buildDataUsageCard(theme),

                  const SizedBox(height: 28),

                  // Account & Preferences Section
                  _buildAccountSection(theme),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(ThemeData theme, bool isDesktop) {
    final isDark = theme.brightness == Brightness.dark;
    final isAuthenticated = SupabaseService.isAuthenticated;
    final userEmail = SupabaseService.currentUser?.email;

    final avatarColor = _avatarColors[_selectedAvatarColor];
    final avatarIcon = _avatarIcons[_selectedAvatarIcon];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar with visual picker
              Stack(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: avatarColor,
                    child: Icon(avatarIcon, size: 36, color: Colors.white),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: InkWell(
                      onTap: _showAvatarPickerModal,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Icon(Icons.edit, size: 12, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),

              // Title and Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _aliasController.text.isEmpty ? 'Estudiante USAC' : _aliasController.text,
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildRoleBadge(theme),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Auth State Badge
                    Row(
                      children: [
                        Icon(
                          isAuthenticated ? Icons.cloud_done_outlined : Icons.lock_open_outlined,
                          size: 14,
                          color: isAuthenticated ? const Color(0xFF059669) : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isAuthenticated
                              ? 'Cuenta Verificada ($userEmail)'
                              : 'Modo Anónimo (Identidad Protegida Localmente)',
                          style: TextStyle(
                            fontSize: 11,
                            color: isAuthenticated ? const Color(0xFF059669) : Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Pseudonym input field
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _aliasController,
                            maxLength: 35,
                            decoration: InputDecoration(
                              labelText: 'Seudónimo Visible en la Comunidad',
                              hintText: 'Ej. Estudiante USAC #402',
                              prefixIcon: const Icon(Icons.badge_outlined, size: 18),
                              isDense: true,
                              counterText: '',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.shuffle, size: 18),
                                tooltip: 'Generar seudónimo aleatorio',
                                onPressed: _generateRandomAlias,
                              ),
                            ),
                            onChanged: (val) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Bio field
          TextField(
            controller: _bioController,
            maxLines: 2,
            maxLength: 140,
            decoration: const InputDecoration(
              labelText: 'Presentación o Bio Estudiantil (Opcional)',
              hintText: 'Ej. Estudiante de 6to semestre apasionado por desarrollo y proyectos comunitarios...',
              prefixIcon: Icon(Icons.edit_note_outlined, size: 18),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleBadge(ThemeData theme) {
    final role = _profile?.role ?? 'student';
    String label = 'Estudiante';
    IconData icon = Icons.school;
    Color color = const Color(0xFF004B87);

    if (role == 'admin') {
      label = 'Administrador';
      icon = Icons.verified_user;
      color = const Color(0xFFDC2626);
    } else if (role == 'moderator') {
      label = 'Moderador';
      icon = Icons.shield;
      color = const Color(0xFFD97706);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildAcademicCard(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final carreras = _getCarrerasForFacultad(_selectedFacultadId);

    // Validate that selected carrera belongs to this facultad
    final bool carreraExists = carreras.any((c) => c.id == _selectedCarreraId);
    if (!carreraExists && carreras.isNotEmpty) {
      _selectedCarreraId = carreras.first.id;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF004B87).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.school_outlined, color: Color(0xFF004B87), size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'Información Académica',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Facultad Dropdown
          DropdownButtonFormField<String>(
            key: ValueKey('facultad_$_selectedFacultadId'),
            initialValue: _selectedFacultadId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Facultad / Unidad Académica',
              prefixIcon: Icon(Icons.account_balance_outlined, size: 18),
              isDense: true,
            ),
            items: USACConstants.facultades.map((f) {
              return DropdownMenuItem<String>(
                value: f['id'] as String,
                child: Text(
                  f['nombre'] as String,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              );
            }).toList(),
            onChanged: (newFacultadId) {
              if (newFacultadId != null) {
                setState(() {
                  _selectedFacultadId = newFacultadId;
                  final availableCarreras = _getCarrerasForFacultad(newFacultadId);
                  _selectedCarreraId = availableCarreras.isNotEmpty ? availableCarreras.first.id : 'todas';
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
            decoration: const InputDecoration(
              labelText: 'Carrera',
              prefixIcon: Icon(Icons.menu_book_outlined, size: 18),
              isDense: true,
            ),
            items: carreras.map((c) {
              return DropdownMenuItem<String>(
                value: c.id,
                child: Text(
                  c.nombre,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
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
            decoration: const InputDecoration(
              labelText: 'Sede / Centro Universitario',
              prefixIcon: Icon(Icons.location_on_outlined, size: 18),
              isDense: true,
            ),
            items: USACConstants.sedes.map((s) {
              return DropdownMenuItem<String>(
                value: s['id'] as String,
                child: Text(
                  '${s['nombre']} (${s['departamento']})',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
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

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.contact_phone_outlined, color: Color(0xFF0D9488), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Canales de Contacto',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Se autocompletarán al publicar en Marketplace o coordinar tutorías',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // WhatsApp
          TextField(
            controller: _whatsappController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'WhatsApp Predeterminado',
              hintText: '502 12345678',
              prefixIcon: Icon(Icons.chat_outlined, size: 18),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),

          // Instagram
          TextField(
            controller: _instagramController,
            decoration: const InputDecoration(
              labelText: 'Instagram',
              hintText: 'usuario_estudiante',
              prefixIcon: Icon(Icons.camera_alt_outlined, size: 18),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),

          // Telegram
          TextField(
            controller: _telegramController,
            decoration: const InputDecoration(
              labelText: 'Telegram',
              hintText: 'usuario_telegram',
              prefixIcon: Icon(Icons.send_outlined, size: 18),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitySection(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
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
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF004B87).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.history_edu_outlined, color: Color(0xFF004B87), size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  'Mi Actividad y Contenidos',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  tooltip: 'Actualizar actividad',
                  onPressed: _loadUserActivity,
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            tabs: [
              Tab(
                icon: const Icon(Icons.forum_outlined, size: 16),
                text: 'Mis Posts (${_myPosts.length})',
              ),
              Tab(
                icon: const Icon(Icons.groups_outlined, size: 16),
                text: 'Mis Grupos (${_myGroups.length})',
              ),
              Tab(
                icon: const Icon(Icons.storefront_outlined, size: 16),
                text: 'Mis Anuncios (${_myMarketplaceItems.length})',
              ),
            ],
          ),
          SizedBox(
            height: 320,
            child: _isLoadingActivity
                ? const Center(child: CircularProgressIndicator())
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
    if (_myPosts.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.forum_outlined,
        title: 'Sin publicaciones en el foro',
        description: 'Las consultas o aportes que crees en el Foro Estudiantil aparecerán aquí para que puedas gestionarlos.',
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
                icon: const Icon(Icons.open_in_new, size: 18),
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
                icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFDC2626)),
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
      return const EmptyStateWidget(
        icon: Icons.groups_outlined,
        title: 'Sin grupos de estudio compartidos',
        description: 'Los enlaces de grupos de WhatsApp o Discord que compartas se listarán aquí.',
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
            icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFDC2626)),
            tooltip: 'Eliminar grupo',
            onPressed: () => _deleteGroup(group),
          ),
        );
      },
    );
  }

  Widget _buildMarketplaceTab(ThemeData theme) {
    if (_myMarketplaceItems.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.storefront_outlined,
        title: 'Sin anuncios en el Marketplace',
        description: 'Tus publicaciones de productos, comidas, libros o tutorías aparecerán aquí.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _myMarketplaceItems.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = _myMarketplaceItems[index];
        final priceText = item.isFree ? 'Gratuito' : 'Q${item.price.toStringAsFixed(2)}';

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
            icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFDC2626)),
            tooltip: 'Eliminar anuncio',
            onPressed: () => _deleteMarketplaceItem(item),
          ),
        );
      },
    );
  }

  Widget _buildDataUsageCard(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.privacy_tip_outlined, color: Color(0xFF0284C7), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Uso de Datos y Privacidad',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '¿Cómo y por qué se utiliza tu información en la plataforma?',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Item 1: Alias & Identity
          _buildDataUsageItem(
            theme: theme,
            icon: Icons.badge_outlined,
            iconColor: const Color(0xFF004B87),
            title: 'Seudónimo y Protección de Identidad',
            description:
                'Tu seudónimo protege tu privacidad frente a otros estudiantes. Es el único identificador visible al publicar en el foro o compartir grupos de estudio, evitando exponer tu nombre real o datos personales.',
          ),
          const SizedBox(height: 12),

          // Item 2: Academic Info
          _buildDataUsageItem(
            theme: theme,
            icon: Icons.school_outlined,
            iconColor: const Color(0xFF0D9488),
            title: 'Información Académica (Facultad, Carrera y Sede)',
            description:
                'Se utiliza exclusivamente para filtrar y mostrarte contenido relevante: dudas sobre prerrequisitos de tu carrera, grupos de cursos específicos y artículos de marketplace en tu misma sede.',
          ),
          const SizedBox(height: 12),

          // Item 3: Contact Channels
          _buildDataUsageItem(
            theme: theme,
            icon: Icons.chat_outlined,
            iconColor: const Color(0xFF16A34A),
            title: 'Canales de Contacto (WhatsApp, Redes)',
            description:
                'Se almacenan localmente en tu dispositivo como borrador de conveniencia. Solo se adjuntan a los anuncios específicos que tú decidas publicar en el Marketplace o tutorías para que los interesados te contacten directamente.',
          ),
          const SizedBox(height: 12),

          // Item 4: Data Control & Retention
          _buildDataUsageItem(
            theme: theme,
            icon: Icons.shield_outlined,
            iconColor: const Color(0xFF7C3AED),
            title: 'Control Total y No Comercialización',
            description:
                'Comunidad Universitaria es una iniciativa sin fines de lucro. No comercializamos, no rastreamos con fines publicitarios ni compartimos tus datos con entidades externas ni con autoridades de la universidad. Puedes editar tus datos o eliminar tus publicaciones en cualquier momento.',
          ),

          const SizedBox(height: 14),

          // Reassurance Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, size: 16, color: Color(0xFF0284C7)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tus aportes colaborativos fortalecen la red estudiantil manteniendo la autonomía y privacidad de cada compañero.',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                      height: 1.3,
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

  Widget _buildDataUsageItem({
    required ThemeData theme,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151E34) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSection(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final isAuthenticated = SupabaseService.isAuthenticated;

    return Material(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.settings_outlined, color: Color(0xFF7C3AED), size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'Cuenta y Preferencias',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Theme Switch
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              widget.isDarkMode ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
              size: 22,
            ),
            title: const Text('Tema de la Aplicación', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            subtitle: Text(
              widget.isDarkMode ? 'Modo Oscuro activado' : 'Modo Claro activado',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            trailing: Switch(
              value: widget.isDarkMode,
              onChanged: (_) => widget.onToggleTheme?.call(),
            ),
          ),

          const Divider(),

          // Community Rules Link
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.shield_outlined, size: 22),
            title: const Text('Normas de Convivencia y Descargo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            subtitle: const Text('Conoce los lineamientos de respeto y privacidad', style: TextStyle(fontSize: 11)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (ctx) => const Scaffold(body: RulesScreen())),
              );
            },
          ),

          const Divider(),

          // Login or Logout
          if (!isAuthenticated) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.login, size: 22, color: Color(0xFF004B87)),
              title: const Text('Iniciar Sesión o Registrarse', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              subtitle: const Text(
                'Vincular con Google o Correo para sincronizar tus publicaciones en otros dispositivos',
                style: TextStyle(fontSize: 11),
              ),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF004B87),
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  AuthModal.show(
                    context,
                    title: 'Acceso a Cuenta Estudiantil',
                    subtitle: 'Inicia sesión para sincronizar tus aportes y publicaciones.',
                    onAuthenticated: () {
                      _loadFullProfile();
                    },
                  );
                },
                child: const Text('Acceder'),
              ),
            ),
          ] else ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.logout, size: 22, color: Color(0xFFDC2626)),
              title: const Text('Cerrar Sesión', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              subtitle: Text(
                'Sesión iniciada como ${SupabaseService.currentUser?.email ?? 'Usuario'}',
                style: const TextStyle(fontSize: 11),
              ),
              trailing: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFDC2626),
                  side: const BorderSide(color: Color(0xFFDC2626)),
                ),
                onPressed: () async {
                  await SupabaseService.signOut();
                  await _loadFullProfile();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sesión cerrada.')),
                    );
                  }
                },
                child: const Text('Cerrar Sesión'),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

  void _showAvatarPickerModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Personaliza tu Avatar Estudiantil',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 16),

                  // Color Picker
                  const Text('Color de Fondo', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  const SizedBox(height: 8),
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
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _avatarColors[idx],
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.transparent,
                              width: 2.5,
                            ),
                            boxShadow: isSelected
                                ? [const BoxShadow(color: Colors.black26, blurRadius: 6)]
                                : null,
                          ),
                          child: isSelected ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 18),

                  // Icon Picker
                  const Text('Icono Representativo', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  const SizedBox(height: 8),
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
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            _avatarIcons[idx],
                            size: 20,
                            color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.shade700,
                          ),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Listo'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
