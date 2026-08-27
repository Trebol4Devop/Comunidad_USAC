import 'package:flutter/material.dart';
import '../../../core/constants/categories.dart';
import '../../../core/models/whatsapp_group.dart';
import '../../../core/services/groups_service.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/utils/responsive.dart';
import '../widgets/create_group_dialog.dart';
import '../widgets/group_card.dart';
import '../../shared/widgets/empty_state_widget.dart';

class GroupsScreen extends StatefulWidget {
  final String activeAlias;
  final Function(String newAlias) onAliasChanged;

  const GroupsScreen({
    super.key,
    required this.activeAlias,
    required this.onAliasChanged,
  });

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  List<WhatsAppGroup> _groups = [];
  bool _isLoading = true;
  String _selectedFacultad = 'todas';
  String _selectedCarrera = 'todas';
  String _searchQuery = '';
  bool _showCleanupBanner = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkCleanupBanner();
    _loadGroups();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  Future<void> _loadGroups() async {
    setState(() => _isLoading = true);
    final list = await GroupsService.fetchGroups(
      carrera: _selectedCarrera,
      searchQuery: _searchQuery,
    );
    if (mounted) {
      setState(() {
        _groups = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleToggleUpvote(WhatsAppGroup group) async {
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
    CreateGroupDialog.show(
      context,
      activeAlias: widget.activeAlias,
      onAliasChanged: widget.onAliasChanged,
      onGroupCreated: (newGroup) {
        setState(() {
          _groups.insert(0, newGroup);
        });
      },
    );
  }

  List<Map<String, dynamic>> get _availableCarreras {
    final fac = USACConstants.facultades.firstWhere(
      (f) => f['id'] == _selectedFacultad,
      orElse: () => USACConstants.facultades.first,
    );
    final list = fac['carreras'] as List<dynamic>? ?? [];
    return list.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);

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
                // Top Header Banner
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F5132), Color(0xFF198754)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Directorio de Grupos de Estudio',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Comunidad libre para encontrar y compartir enlaces de grupos de WhatsApp, Telegram y Discord organizados por curso y facultad.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isDesktop) ...[
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF0F5132),
                          ),
                          onPressed: _openCreateGroupDialog,
                          icon: const Icon(Icons.add_link, size: 18),
                          label: const Text('Compartir Grupo'),
                        ),
                      ],
                    ],
                  ),
                ),

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

                // Filters Row
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Buscar por curso, catedrático o sección...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                    _loadGroups();
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        onSubmitted: (val) {
                          setState(() => _searchQuery = val);
                          _loadGroups();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Faculty Selector
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: isDesktop ? 260 : 160),
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedFacultad,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
                            _selectedFacultad = val ?? 'todas';
                            _selectedCarrera = 'todas';
                          });
                          _loadGroups();
                        },
                      ),
                    ),
                  ],
                ),

                // Career Filter chips if a specific faculty is chosen
                if (_selectedFacultad != 'todas' && _availableCarreras.length > 1) ...[
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _availableCarreras.map((car) {
                        final id = car['id'].toString();
                        final isSelected = _selectedCarrera == id;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(car['nombre'].toString()),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                _selectedCarrera = selected ? id : 'todas';
                              });
                              _loadGroups();
                            },
                          ),
                        );
                      }).toList(),
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
        onPressed: _openCreateGroupDialog,
        backgroundColor: const Color(0xFF198754),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.group_add),
        label: const Text('Compartir Grupo'),
      ),
    );
  }
}
