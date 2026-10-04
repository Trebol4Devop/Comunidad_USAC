import 'package:flutter/material.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/models/whatsapp_group.dart';
import '../../../core/services/groups_service.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import '../widgets/create_group_dialog.dart';
import '../widgets/group_card.dart';
import '../../shared/widgets/auth_modal.dart';
import '../../shared/widgets/empty_state_widget.dart';

class GroupsScreen extends StatefulWidget {
  final String activeAlias;
  final Function(String newAlias) onAliasChanged;
  final String? activeFacultadId;
  final String? activeCarreraId;
  final String? activeChannelName;
  final String? activeChannelDescription;
  final IconData? activeChannelIcon;

  const GroupsScreen({
    super.key,
    required this.activeAlias,
    required this.onAliasChanged,
    this.activeFacultadId,
    this.activeCarreraId,
    this.activeChannelName,
    this.activeChannelDescription,
    this.activeChannelIcon,
  });

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  List<WhatsAppGroup> _groups = [];
  bool _isLoading = true;
  String _selectedFacultad = 'todas';
  String _selectedCarrera = 'todas';
  bool _showCleanupBanner = true;

  @override
  void initState() {
    super.initState();
    if (widget.activeFacultadId != null) {
      _selectedFacultad = widget.activeFacultadId!;
    }
    if (widget.activeCarreraId != null) {
      _selectedCarrera = widget.activeCarreraId!;
    }
    _checkCleanupBanner();
    if (widget.activeFacultadId == null) {
      _loadUserAcademicContext();
    }
    _loadGroups();
  }

  @override
  void didUpdateWidget(covariant GroupsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    bool shouldReload = false;
    if (widget.activeFacultadId != null && widget.activeFacultadId != _selectedFacultad) {
      _selectedFacultad = widget.activeFacultadId!;
      shouldReload = true;
    }
    if (widget.activeCarreraId != null && widget.activeCarreraId != _selectedCarrera) {
      _selectedCarrera = widget.activeCarreraId!;
      shouldReload = true;
    }
    if (shouldReload) {
      _loadGroups();
    }
  }

  Future<void> _checkCleanupBanner() async {
    final dismissed = await LocalStorageService.isCleanupNoticeDismissed();
    if (mounted && dismissed) {
      setState(() => _showCleanupBanner = false);
    }
  }

  Future<void> _dismissCleanupBanner() async {
    await LocalStorageService.dismissCleanupNotice();
    if (mounted) {
      setState(() => _showCleanupBanner = false);
    }
  }

  Future<void> _loadUserAcademicContext() async {
    final profile = await LocalStorageService.getUserProfile();
    if (mounted && profile.facultadId.isNotEmpty && widget.activeFacultadId == null) {
      setState(() {
        _selectedFacultad = profile.facultadId;
        _selectedCarrera = profile.carreraId.isNotEmpty ? profile.carreraId : 'todas';
      });
      _loadGroups();
    }
  }

  Future<void> _loadGroups() async {
    setState(() => _isLoading = true);
    try {
      final list = await GroupsService.fetchGroups(
        facultad: _selectedFacultad,
        carrera: _selectedCarrera,
        searchQuery: '',
      );
      if (mounted) {
        setState(() {
          _groups = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _groups = [];
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleToggleUpvote(WhatsAppGroup group) async {
    if (SupabaseConfig.isConfigured && !SupabaseService.isAuthenticated) {
      AuthModal.show(
        context,
        title: 'Inicia Sesión para Votar',
        subtitle: 'Para apoyar y verificar enlaces de grupos, debes iniciar sesión.',
        onAuthenticated: () => _handleToggleUpvote(group),
      );
      return;
    }

    final prevUpvoted = group.isUpvotedByMe;
    final prevUpvotes = group.upvotes;

    // Optimistic UI update
    setState(() {
      final idx = _groups.indexWhere((g) => g.id == group.id);
      if (idx != -1) {
        _groups[idx] = group.copyWith(
          isUpvotedByMe: !prevUpvoted,
          upvotes: prevUpvoted ? (prevUpvotes - 1).clamp(0, 999999) : prevUpvotes + 1,
        );
      }
    });

    final success = await GroupsService.toggleUpvote(group);
    if (mounted && success != !prevUpvoted) {
      setState(() {
        final idx = _groups.indexWhere((g) => g.id == group.id);
        if (idx != -1) {
          _groups[idx] = group.copyWith(isUpvotedByMe: prevUpvoted, upvotes: prevUpvotes);
        }
      });
    }
  }

  void _openCreateGroupDialog() {
    if (SupabaseConfig.isConfigured && !SupabaseService.isAuthenticated) {
      AuthModal.show(
        context,
        title: 'Inicia Sesión para Compartir',
        subtitle: 'Para compartir enlaces de grupos estudiantiles, debes iniciar sesión.',
        onAuthenticated: () {
          _showCreateGroupDialog();
        },
      );
      return;
    }
    _showCreateGroupDialog();
  }

  void _showCreateGroupDialog() {
    CreateGroupDialog.show(
      context,
      activeAlias: widget.activeAlias,
      onAliasChanged: widget.onAliasChanged,
      initialFacultad: _selectedFacultad != 'todas' ? _selectedFacultad : null,
      initialCarrera: _selectedCarrera != 'todas' ? _selectedCarrera : null,
      onGroupCreated: (newGroup) {
        setState(() {
          _groups.insert(0, newGroup);
        });
      },
    );
  }

  Widget _buildDiscordWelcomeHero(ThemeData theme, bool isDark) {
    final channelName = widget.activeChannelName ?? 'todos-los-grupos';
    final channelDesc = widget.activeChannelDescription ??
        'Directorio oficial de grupos de WhatsApp y estudio USAC organizados por facultad y curso.';
    final channelIcon = widget.activeChannelIcon ?? Icons.tag;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2B2D31) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF383A40) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF3F4147) : const Color(0xFFDCFCE7),
              shape: BoxShape.circle,
            ),
            child: Icon(channelIcon, size: 22, color: const Color(0xFF16A34A)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¡Te damos la bienvenida a #$channelName!',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 3),
                Text(
                  channelDesc,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF949BA4) : const Color(0xFF64748B),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadGroups,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: MaxWidthContainer(
            maxWidth: 1100,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Welcome Hero banner (estilo Discord)
                _buildDiscordWelcomeHero(theme, isDark),

                // Semester Cleanup Notice
                if (_showCleanupBanner) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3CD),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFEEBA)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Color(0xFF856404), size: 20),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Para evitar enlaces caídos, los grupos se depuran automáticamente al iniciar cada nuevo semestre académico.',
                            style: TextStyle(color: Color(0xFF856404), fontSize: 12),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16, color: Color(0xFF856404)),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: _dismissCleanupBanner,
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Groups Feed
                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_groups.isEmpty)
                  EmptyStateWidget(
                    icon: Icons.groups_outlined,
                    title: 'No se encontraron grupos para este filtro',
                    description: '¿Conoces o administras un grupo de WhatsApp o Discord para este curso? ¡Compártelo con tus compañeros!',
                    buttonText: 'Compartir Enlace',
                    onButtonPressed: _openCreateGroupDialog,
                  )
                else
                  Responsive(
                    mobile: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _groups.length,
                      itemBuilder: (ctx, i) {
                        final group = _groups[i];
                        return GroupCard(
                          group: group,
                          onUpvote: () => _handleToggleUpvote(group),
                          onReport: (reason) {
                            GroupsService.reportGroup(
                              groupId: group.id,
                              reason: reason,
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Gracias. Hemos recibido tu reporte sobre el enlace.')),
                            );
                          },
                        );
                      },
                    ),
                    desktop: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.6,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: _groups.length,
                      itemBuilder: (ctx, i) {
                        final group = _groups[i];
                        return GroupCard(
                          group: group,
                          onUpvote: () => _handleToggleUpvote(group),
                          onReport: (reason) {
                            GroupsService.reportGroup(
                              groupId: group.id,
                              reason: reason,
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Gracias. Hemos recibido tu reporte sobre el enlace.')),
                            );
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'groups_fab',
        onPressed: _openCreateGroupDialog,
        backgroundColor: const Color(0xFF198754),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.group_add),
        label: const Text('Compartir Grupo'),
      ),
    );
  }
}
