import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/constants/categories.dart';
import '../../../core/constants/zanate_colors.dart';
import '../../../core/models/whatsapp_group.dart';
import '../../../core/services/groups_service.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/services/supabase_service.dart';
import '../widgets/create_group_dialog.dart';
import '../widgets/group_card.dart';
import '../../shared/widgets/auth_modal.dart';
import '../../shared/widgets/empty_state_widget.dart';
import '../../shared/widgets/settings_bottom_sheet.dart';

class GroupsScreen extends StatefulWidget {
  final String activeAlias;
  final Function(String newAlias) onAliasChanged;
  final VoidCallback? onToggleTheme;
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
    this.onToggleTheme,
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

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _searchQuery = val.trim());
      _loadGroups();
    });
  }

  void _submitSearch(String val) {
    _searchDebounce?.cancel();
    setState(() => _searchQuery = val.trim());
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    final currentRequestId = ++_loadRequestId;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final groups = await GroupsService.fetchGroups(
        facultad: _selectedFacultad,
        carrera: _selectedCarrera,
        searchQuery: _searchQuery,
      );
      if (mounted && currentRequestId == _loadRequestId) {
        setState(() {
          _groups = groups;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && currentRequestId == _loadRequestId) {
        setState(() {
          _loadError = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleToggleUpvote(WhatsAppGroup group) async {
    if (_votingGroupIds.contains(group.id)) return;
    _votingGroupIds.add(group.id);

    if (SupabaseConfig.isConfigured && !SupabaseService.isAuthenticated) {
      _votingGroupIds.remove(group.id);
      AuthModal.show(
        context,
        title: 'Inicia sesión para votar',
        subtitle:
            'Para apoyar un enlace de grupo necesitas autenticar tu cuenta.',
        onAuthenticated: () => _handleToggleUpvote(group),
      );
      return;
    }

    final prevUpvoted = group.isUpvotedByMe;
    final prevUpvotes = group.upvotes;

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
    key: ValueKey(group.id),
    group: group,
    onUpvote: () => _handleToggleUpvote(group),
    onReport: (reason) => _handleReportGroup(group, reason),
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

  bool get _hasActivePreferences => _selectedFacultad != 'todas';

  String _getActivePreferencesLabel() {
    if (_selectedFacultad != 'todas') {
      final fac = USACConstants.facultades.firstWhere(
        (f) => f['id'].toString() == _selectedFacultad,
        orElse: () => {'nombre': 'Facultad'},
      );
      return fac['nombre']?.toString().replaceAll('Facultad de ', '') ?? 'Facultad';
    }
    return 'Facultad';
  }

  void _showPreferencesSheet(BuildContext context, bool isDark) {
    String tempFacultad = _selectedFacultad;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 16,
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          PhosphorIconsRegular.slidersHorizontal,
                          size: 20,
                          color: ZanateColors.zanateAccent,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Filtrar por Facultad',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            color: isDark ? Colors.white : ZanateColors.zanateDark,
                          ),
                        ),
                        const Spacer(),
                        if (tempFacultad != 'todas')
                          TextButton(
                            onPressed: () {
                              setSheetState(() => tempFacultad = 'todas');
                            },
                            child: const Text(
                              'Restablecer',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFFEF4444),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    Text(
                      'Selecciona tu facultad o unidad académica',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : ZanateColors.surfaceBg,
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : ZanateColors.subtleBorder,
                          width: 0.8,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: tempFacultad,
                          isExpanded: true,
                          icon: const Icon(PhosphorIconsRegular.caretDown, size: 14),
                          items: USACConstants.facultades
                              .map(
                                (f) => DropdownMenuItem<String>(
                                  value: f['id'].toString(),
                                  child: Text(
                                    f['nombre'].toString(),
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: isDark ? Colors.white : ZanateColors.zanateDark,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setSheetState(() => tempFacultad = val);
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          setState(() => _selectedFacultad = tempFacultad);
                          _loadGroups();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ZanateColors.zanateAccent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                        ),
                        child: const Text(
                          'Aplicar Filtro',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
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

  // 1. Squared Full-Width Header: Clean, Simple, Centered Title without Symbol, Gear for Settings on Left
  Widget _buildSquaredHeader(bool isDark, String titleText) {
    return Container(
      height: 56,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : ZanateColors.subtleBorder,
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        children: [
          // Left: Settings Button (Configuración y Perfil)
          IconButton(
            tooltip: 'Configuración y Perfil',
            onPressed: () => SettingsBottomSheet.show(
              context,
              activeAlias: widget.activeAlias,
              onAliasChanged: widget.onAliasChanged,
              onToggleTheme: widget.onToggleTheme,
            ),
            icon: Icon(
              PhosphorIconsRegular.gear,
              size: 21,
              color: isDark ? Colors.white : ZanateColors.zanateDark,
            ),
            splashRadius: 22,
          ),

          // Center: Clean, simple, centered title (Matching Forum layout, no symbol box)
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'DIRECTORIO ESTUDIANTIL',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : Colors.blueGrey.shade400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  titleText,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: isDark ? Colors.white : ZanateColors.zanateDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Right: Minimalist + button to share group
          IconButton(
            tooltip: 'Compartir Grupo',
            onPressed: _openCreateGroupDialog,
            icon: Icon(
              PhosphorIconsBold.plus,
              size: 22,
              color: isDark ? Colors.white : ZanateColors.zanateDark,
            ),
            splashRadius: 22,
          ),
        ],
      ),
    );
  }

  // 2. Squared Full-Width Search & Preferences Bar
  Widget _buildSquaredSearchBar(bool isDark) {
    return Container(
      height: 48,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : ZanateColors.subtleBorder,
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            PhosphorIconsRegular.magnifyingGlass,
            size: 18,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              onSubmitted: _submitSearch,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Buscar cursos, secciones o palabras clave...',
                hintStyle: TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white : ZanateColors.zanateDark,
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(PhosphorIconsRegular.x, size: 15),
              splashRadius: 16,
              onPressed: () {
                _searchController.clear();
                _onSearchChanged('');
              },
            ),
          const SizedBox(width: 4),

          // Discrete Preferences Pill
          InkWell(
            onTap: () => _showPreferencesSheet(context, isDark),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: _hasActivePreferences
                    ? ZanateColors.zanateAccent.withValues(alpha: isDark ? 0.25 : 0.1)
                    : (isDark ? const Color(0xFF0F172A) : ZanateColors.surfaceBg),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _hasActivePreferences
                      ? ZanateColors.zanateAccent
                      : (isDark ? const Color(0xFF334155) : ZanateColors.subtleBorder),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _hasActivePreferences
                        ? PhosphorIconsFill.slidersHorizontal
                        : PhosphorIconsRegular.slidersHorizontal,
                    size: 13,
                    color: _hasActivePreferences
                        ? ZanateColors.zanateAccent
                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _getActivePreferencesLabel(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: _hasActivePreferences ? FontWeight.w700 : FontWeight.w500,
                      color: _hasActivePreferences
                          ? ZanateColors.zanateAccent
                          : (isDark ? const Color(0xFFE2E8F0) : ZanateColors.zanateDark),
                    ),
                  ),
                  if (_hasActivePreferences) ...[
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () {
                        setState(() => _selectedFacultad = 'todas');
                        _loadGroups();
                      },
                      child: const Icon(
                        PhosphorIconsRegular.x,
                        size: 12,
                        color: ZanateColors.zanateAccent,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.1),
        border: const Border(
          bottom: BorderSide(
            color: Color(0xFFEF4444),
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(PhosphorIconsRegular.warningCircle, color: Color(0xFFEF4444), size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'No se pudieron cargar los grupos. Revisa tu conexión.',
              style: TextStyle(fontSize: 12, color: Color(0xFFEF4444)),
            ),
          ),
          TextButton(
            onPressed: _loadGroups,
            child: const Text('Reintentar', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupsFeed(bool isDark) {
    if (_isLoading && _groups.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_loadError != null && _groups.isEmpty) {
      return _buildLoadError();
    }

    if (_groups.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        children: const [
          EmptyStateWidget(
            icon: PhosphorIconsRegular.usersThree,
            title: 'No se encontraron grupos para este filtro',
            description:
                'Prueba ajustando tus preferencias o usa el botón + superior para compartir un enlace con tus compañeros.',
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: _groups.length,
      itemBuilder: (ctx, i) => _buildGroupCard(_groups[i]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleText = widget.activeChannelName != null
        ? '#${widget.activeChannelName}'
        : 'Grupos de Estudio';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      body: Column(
        children: [
          // 1. Squared Top Header (Matching Forum layout)
          _buildSquaredHeader(isDark, titleText),

          // 2. Squared Search & Preference Bar
          _buildSquaredSearchBar(isDark),

          if (_loadError != null && _groups.isNotEmpty) ...[
            _buildLoadError(),
          ],

          // 3. Squared Feed (ListView with 1px border dividers)
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadGroups,
              child: _buildGroupsFeed(isDark),
            ),
          ),
        ],
      ),
      floatingActionButton: null,
    );
  }
}
