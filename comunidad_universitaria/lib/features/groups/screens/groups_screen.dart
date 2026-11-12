import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/models/whatsapp_group.dart';
import '../../../core/services/groups_service.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/responsive.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../core/constants/zanate_colors.dart';
import '../widgets/create_group_dialog.dart';
import '../widgets/group_card.dart';
import '../../shared/widgets/auth_modal.dart';
import '../../shared/widgets/empty_state_widget.dart';

class GroupsScreen extends StatefulWidget {
  final String activeAlias;
  final Function(String newAlias) onAliasChanged;
  final String? activeServerName;
  final String? activeFacultadId;
  final String? activeCarreraId;
  final String? activeChannelName;
  final String? activeChannelDescription;
  final IconData? activeChannelIcon;
  final bool showFloatingActionButton;
  final Object floatingActionButtonHeroTag;

  const GroupsScreen({
    super.key,
    required this.activeAlias,
    required this.onAliasChanged,
    this.activeServerName,
    this.activeFacultadId,
    this.activeCarreraId,
    this.activeChannelName,
    this.activeChannelDescription,
    this.activeChannelIcon,
    this.showFloatingActionButton = true,
    this.floatingActionButtonHeroTag = 'groups_fab',
  });

  @override
  GroupsScreenState createState() => GroupsScreenState();
}

class GroupsScreenState extends State<GroupsScreen> {
  List<WhatsAppGroup> _groups = [];
  bool _isLoading = true;
  String? _loadError;
  String _selectedFacultad = 'todas';
  String _selectedCarrera = 'todas';
  bool _showCleanupBanner = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  int _loadRequestId = 0;
  final Set<String> _votingGroupIds = {};

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
    if (widget.activeFacultadId != null &&
        widget.activeFacultadId != _selectedFacultad) {
      _selectedFacultad = widget.activeFacultadId!;
      shouldReload = true;
    }
    if (widget.activeCarreraId != null &&
        widget.activeCarreraId != _selectedCarrera) {
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
    if (mounted &&
        profile.facultadId.isNotEmpty &&
        widget.activeFacultadId == null) {
      setState(() {
        _selectedFacultad = profile.facultadId;
        _selectedCarrera = profile.carreraId.isNotEmpty
            ? profile.carreraId
            : 'todas';
      });
      _loadGroups();
    }
  }

  Future<void> _loadGroups() async {
    final requestId = ++_loadRequestId;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final list = await GroupsService.fetchGroups(
        facultad: _selectedFacultad,
        carrera: _selectedCarrera,
        searchQuery: _searchQuery,
      );
      if (mounted && requestId == _loadRequestId) {
        setState(() {
          _groups = list;
          _isLoading = false;
          _loadError = null;
        });
      }
    } catch (_) {
      if (mounted && requestId == _loadRequestId) {
        setState(() {
          _isLoading = false;
          _loadError =
              'No pudimos cargar los grupos. Comprueba tu conexión e inténtalo de nuevo.';
        });
      }
    }
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _loadGroups);
  }

  void _submitSearch(String _) {
    _searchDebounce?.cancel();
    _loadGroups();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildLoadError() {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 32,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            const SizedBox(height: 8),
            Text(
              'No se pudieron cargar los grupos',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(_loadError!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _loadGroups,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleToggleUpvote(WhatsAppGroup group) async {
    if (_votingGroupIds.contains(group.id)) return;
    if (SupabaseConfig.isConfigured && !SupabaseService.isAuthenticated) {
      AuthModal.show(
        context,
        title: 'Inicia Sesión para Votar',
        subtitle:
            'Para apoyar y verificar enlaces de grupos, debes iniciar sesión.',
        onAuthenticated: () => _handleToggleUpvote(group),
      );
      return;
    }

    final prevUpvoted = group.isUpvotedByMe;
    final prevUpvotes = group.upvotes;
    _votingGroupIds.add(group.id);

    // Optimistic UI update
    setState(() {
      final idx = _groups.indexWhere((g) => g.id == group.id);
      if (idx != -1) {
        _groups[idx] = group.copyWith(
          isUpvotedByMe: !prevUpvoted,
          upvotes: prevUpvoted
              ? (prevUpvotes - 1).clamp(0, 999999)
              : prevUpvotes + 1,
        );
      }
    });

    bool? persistedUpvoteState;
    try {
      persistedUpvoteState = await GroupsService.toggleUpvote(group);
    } catch (_) {
      persistedUpvoteState = null;
    }

    final succeeded = persistedUpvoteState == !prevUpvoted;
    if (mounted) {
      if (!succeeded) {
        setState(() {
          final idx = _groups.indexWhere((g) => g.id == group.id);
          if (idx != -1) {
            _groups[idx] = group.copyWith(
              isUpvotedByMe: prevUpvoted,
              upvotes: prevUpvotes,
            );
          }
        });
      }
      _votingGroupIds.remove(group.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            succeeded
                ? (prevUpvoted
                      ? 'Se retiró tu voto del grupo.'
                      : 'Tu voto se registró correctamente.')
                : 'No se pudo registrar tu voto. Inténtalo de nuevo.',
          ),
          backgroundColor: succeeded
              ? Theme.of(context).colorScheme.inverseSurface
              : Theme.of(context).colorScheme.error,
        ),
      );
    } else {
      _votingGroupIds.remove(group.id);
    }
  }

  Future<void> _handleReportGroup(WhatsAppGroup group, String reason) async {
    if (SupabaseConfig.isConfigured && !SupabaseService.isAuthenticated) {
      AuthModal.show(
        context,
        title: 'Inicia sesión para reportar',
        subtitle:
            'Para enviar un reporte sobre un grupo necesitas iniciar sesión.',
        onAuthenticated: () => _handleReportGroup(group, reason),
      );
      return;
    }

    final submitted = await GroupsService.reportGroup(
      groupId: group.id,
      reason: reason,
    );
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          submitted
              ? 'Gracias. Hemos recibido tu reporte sobre el enlace.'
              : 'No se pudo enviar el reporte. Inténtalo de nuevo.',
        ),
      ),
    );
  }

  Widget _buildGroupCard(WhatsAppGroup group) => GroupCard(
    group: group,
    onUpvote: () => _handleToggleUpvote(group),
    onReport: (reason) => _handleReportGroup(group, reason),
  );

  Widget _buildGroupList() => ListView.separated(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: _groups.length,
    separatorBuilder: (context, index) => const SizedBox(height: 12),
    itemBuilder: (context, index) => _buildGroupCard(_groups[index]),
  );

  Widget _buildGroupGrid() => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      mainAxisExtent: _groups.any((group) => group.imageUrl?.isNotEmpty == true)
          ? 440
          : 300,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
    ),
    itemCount: _groups.length,
    itemBuilder: (context, index) => _buildGroupCard(_groups[index]),
  );

  void openCreateGroupDialog() => _openCreateGroupDialog();

  void _openCreateGroupDialog() {
    if (SupabaseConfig.isConfigured && !SupabaseService.isAuthenticated) {
      AuthModal.show(
        context,
        title: 'Inicia Sesión para Compartir',
        subtitle:
            'Para compartir enlaces de grupos estudiantiles, debes iniciar sesión.',
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
    final channelDesc =
        widget.activeChannelDescription ??
        'Directorio oficial de grupos de WhatsApp y estudio USAC organizados por facultad y curso.';
    final channelIcon = widget.activeChannelIcon ?? Icons.tag;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF303030) : const Color(0xFFD9D9D9),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            channelIcon,
            size: 22,
            color: isDark ? Colors.white : Colors.black87,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¡Te damos la bienvenida a #$channelName!',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  channelDesc,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? const Color(0xFFAAAAAA)
                        : const Color(0xFF64748B),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (!Responsive.isMobile(context)) ...[
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Compartir Grupo',
              onPressed: _openCreateGroupDialog,
              icon: const Icon(Icons.group_add),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : ZanateColors.surfaceBg,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFFCD34D),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          PhosphorIconsRegular.info,
                          color: isDark
                              ? const Color(0xFFFDE68A)
                              : const Color(0xFFB45309),
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Para evitar enlaces caídos, los grupos se depuran automáticamente al iniciar cada nuevo semestre académico.',
                            style: TextStyle(
                              color: isDark
                                  ? const Color(0xFFFDE68A)
                                  : const Color(0xFF92400E),
                              fontSize: 12,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            PhosphorIconsRegular.x,
                            size: 15,
                            color: isDark
                                ? const Color(0xFFFDE68A)
                                : const Color(0xFF92400E),
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: _dismissCleanupBanner,
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 14),

                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  onSubmitted: _submitSearch,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Buscar cursos, secciones o palabras clave...',
                    hintStyle: TextStyle(
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8),
                      fontSize: 13,
                    ),
                    prefixIcon: Icon(
                      PhosphorIconsRegular.magnifyingGlass,
                      size: 18,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    suffixIcon: _searchQuery.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Limpiar búsqueda',
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                            icon: const Icon(PhosphorIconsRegular.x, size: 16),
                          ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark ? const Color(0xFF334155) : ZanateColors.subtleBorder,
                        width: 0.8,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark ? const Color(0xFF334155) : ZanateColors.subtleBorder,
                        width: 0.8,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: ZanateColors.zanateAccent,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                if (_loadError != null && _groups.isNotEmpty) ...[
                  _buildLoadError(),
                  const SizedBox(height: 16),
                ],

                // Groups Feed
                if (_isLoading && _groups.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_loadError != null && _groups.isEmpty)
                  _buildLoadError()
                else if (_groups.isEmpty)
                  EmptyStateWidget(
                    icon: Icons.groups_outlined,
                    title: 'No se encontraron grupos para este filtro',
                    description:
                        '¿Conoces o administras un grupo de WhatsApp o Discord para este curso? ¡Compártelo con tus compañeros!',
                    buttonText: 'Compartir Enlace',
                    onButtonPressed: _openCreateGroupDialog,
                  )
                else
                  Responsive(
                    mobile: _buildGroupList(),
                    tablet: widget.activeChannelName == null
                        ? _buildGroupGrid()
                        : _buildGroupList(),
                    desktop: _buildGroupGrid(),
                  ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: widget.showFloatingActionButton
          ? FloatingActionButton.extended(
              heroTag: widget.floatingActionButtonHeroTag,
              onPressed: _openCreateGroupDialog,
              backgroundColor: ZanateColors.zanateAccent,
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              icon: const Icon(PhosphorIconsBold.plus, size: 18),
              label: const Text(
                'Compartir Grupo',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            )
          : null,
    );
  }
}
