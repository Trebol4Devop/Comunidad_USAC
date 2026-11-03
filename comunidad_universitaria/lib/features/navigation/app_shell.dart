import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/utils/responsive.dart';
import '../forum/screens/forum_screen.dart';
import '../groups/screens/groups_screen.dart';
import '../profile/screens/profile_screen.dart';
import '../marketplace/screens/marketplace_screen.dart';
import '../marketplace/widgets/create_listing_dialog.dart';
import '../map/screens/campus_map_screen.dart';
import '../rules/screens/rules_screen.dart';

class AppShell extends StatefulWidget {
  final String activeAlias;
  final Function(String newAlias) onAliasChanged;
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  const AppShell({
    super.key,
    required this.activeAlias,
    required this.onAliasChanged,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;
  final Set<int> _visitedTabs = {0};
  final GlobalKey<GroupsScreenState> _groupsScreenKey =
      GlobalKey<GroupsScreenState>();
  final List<FocusNode> _desktopTabFocusNodes = List.generate(
    4,
    (index) => FocusNode(debugLabel: 'Desktop tab $index'),
  );

  @override
  void dispose() {
    for (final focusNode in _desktopTabFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _selectDesktopTab(int index) {
    if (_currentIndex != index || !_visitedTabs.contains(index)) {
      setState(() {
        _currentIndex = index;
        _visitedTabs.add(index);
      });
    }
    _desktopTabFocusNodes[index].requestFocus();
  }

  KeyEventResult _handleDesktopTabKey(int index, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final nextIndex = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowRight =>
        (index + 1) % _desktopTabFocusNodes.length,
      LogicalKeyboardKey.arrowLeft =>
        (index - 1 + _desktopTabFocusNodes.length) %
            _desktopTabFocusNodes.length,
      LogicalKeyboardKey.home => 0,
      LogicalKeyboardKey.end => _desktopTabFocusNodes.length - 1,
      LogicalKeyboardKey.enter || LogicalKeyboardKey.space => index,
      _ => null,
    };

    if (nextIndex == null) return KeyEventResult.ignored;

    _selectDesktopTab(nextIndex);
    return KeyEventResult.handled;
  }

  void _navigateToRules() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const RulesScreen()));
  }

  void _showDisclaimerModal() {
    showDialog(
      context: context,
      requestFocus: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.info_outline, color: Color(0xFF004B87)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Aviso Comunitario',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Text(
          'Comunidad Universitaria es una plataforma estudiantil colaborativa, autónoma y sin fines de lucro. No representa formalmente a la administración ni a las autoridades de la Universidad de San Carlos de Guatemala. Los datos académicos, pensums y directorios son informativos y compartidos entre compañeros.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _navigateToRules();
            },
            child: const Text('Ver Normas Completas'),
          ),
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: isMobile ? 64 : kToolbarHeight,
        centerTitle: isMobile,
        titleSpacing: isMobile ? 0 : 16,
        title: isMobile
            ? InkWell(
                onTap: _showDisclaimerModal,
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildBrandMark(),
                    const SizedBox(width: 8),
                    const Text(
                      'Zanate',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              )
            : Row(
                children: [
                  _buildBrandMark(),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: _showDisclaimerModal,
                      borderRadius: BorderRadius.circular(4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text(
                                'Zanate',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  'No Oficial',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Comunidad Universitaria',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
        actions: isMobile
            ? [
                PopupMenuButton<String>(
                  tooltip: 'Ajustes',
                  color: theme.colorScheme.surface,
                  surfaceTintColor: Colors.transparent,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                  icon: const Icon(Icons.settings_outlined, size: 21),
                  onSelected: (value) {
                    switch (value) {
                      case 'profile':
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ProfileScreen(
                              activeAlias: widget.activeAlias,
                              onAliasChanged: widget.onAliasChanged,
                            ),
                          ),
                        );
                      case 'theme':
                        widget.onToggleTheme();
                      case 'rules':
                        _navigateToRules();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'profile',
                      child: ListTile(
                        leading: Icon(Icons.person_outline),
                        title: Text('Perfil'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'theme',
                      child: ListTile(
                        leading: Icon(
                          widget.isDarkMode
                              ? Icons.light_mode_outlined
                              : Icons.dark_mode_outlined,
                        ),
                        title: Text(
                          widget.isDarkMode ? 'Tema claro' : 'Tema oscuro',
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'rules',
                      child: ListTile(
                        leading: Icon(Icons.shield_outlined),
                        title: Text('Normas y descargo'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.shield_outlined, size: 20),
                  tooltip: 'Normas y Descargo',
                  onPressed: _navigateToRules,
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(
                    widget.isDarkMode
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                    size: 20,
                  ),
                  tooltip: 'Cambiar tema',
                  onPressed: widget.onToggleTheme,
                ),
                const SizedBox(width: 8),
              ],
        bottom: !isMobile
            ? PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  decoration: BoxDecoration(
                    color: widget.isDarkMode
                        ? const Color(0xFF1E1F22)
                        : Colors.white,
                    border: Border(
                      bottom: BorderSide(
                        color: widget.isDarkMode
                            ? const Color(0xFF2B2D31)
                            : const Color(0xFFE2E8F0),
                        width: 1.5,
                      ),
                    ),
                  ),
                  child: MaxWidthContainer(
                    maxWidth: 1200,
                    padding: EdgeInsets.zero,
                    child: FocusTraversalGroup(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Semantics(
                          container: true,
                          explicitChildNodes: true,
                          role: SemanticsRole.tabBar,
                          child: Row(
                            children: [
                              _buildNavTab(
                                index: 0,
                                label: 'Foro Estudiantil',
                                icon: Icons.forum_outlined,
                              ),
                              _buildNavTab(
                                index: 1,
                                label: 'Marketplace & Tutorías',
                                icon: Icons.storefront_outlined,
                              ),
                              _buildNavTab(
                                index: 2,
                                label: 'Grupos de Estudio',
                                icon: Icons.groups_outlined,
                              ),
                              _buildNavTab(
                                index: 3,
                                label: 'Mapa',
                                icon: Icons.map_outlined,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              )
            : null,
      ),
      // IndexedStack preserves each screen's state while switching destinations.
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _visitedTabs.contains(0)
              ? ExcludeSemantics(
                  excluding: _currentIndex != 0,
                  child: ForumScreen(
                    activeAlias: widget.activeAlias,
                    onAliasChanged: widget.onAliasChanged,
                    onToggleTheme: widget.onToggleTheme,
                    isDarkMode: widget.isDarkMode,
                  ),
                )
              : const SizedBox.shrink(),
          _visitedTabs.contains(1)
              ? ExcludeSemantics(
                  excluding: _currentIndex != 1,
                  child: MarketplaceScreen(
                    activeAlias: widget.activeAlias,
                    onAliasChanged: widget.onAliasChanged,
                    showFloatingActionButton: !isMobile,
                  ),
                )
              : const SizedBox.shrink(),
          _visitedTabs.contains(2)
              ? ExcludeSemantics(
                  excluding: _currentIndex != 2,
                  child: GroupsScreen(
                    key: _groupsScreenKey,
                    activeAlias: widget.activeAlias,
                    onAliasChanged: widget.onAliasChanged,
                    showFloatingActionButton: false,
                    floatingActionButtonHeroTag: 'shell_groups_screen_fab',
                  ),
                )
              : const SizedBox.shrink(),
          _visitedTabs.contains(3)
              ? ExcludeSemantics(
                  excluding: _currentIndex != 3,
                  child: const CampusMapScreen(),
                )
              : const SizedBox.shrink(),
        ],
      ),
      floatingActionButton: isMobile
          ? _buildContextualFloatingActionButton()
          : null,
      bottomNavigationBar: !isMobile
          ? null
          : Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
              ),
              child: NavigationBarTheme(
                data: NavigationBarThemeData(
                  height: 58,
                  indicatorColor: Colors.transparent,
                  backgroundColor: theme.colorScheme.surface,
                  elevation: 0,
                  iconTheme: WidgetStateProperty.resolveWith((states) {
                    return IconThemeData(
                      size: 23,
                      color: theme.colorScheme.onSurface,
                    );
                  }),
                ),
                child: NavigationBar(
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
                  selectedIndex: _navigationIndexForScreen(_currentIndex),
                  onDestinationSelected: (index) {
                    final screenIndex = _screenIndexForNavigation(index);
                    setState(() {
                      _currentIndex = screenIndex;
                      _visitedTabs.add(screenIndex);
                    });
                  },
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.chat_bubble_outline),
                      selectedIcon: Icon(Icons.chat_bubble_outline),
                      label: 'Foro',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.groups_outlined),
                      selectedIcon: Icon(Icons.groups_outlined),
                      label: 'Grupos',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.map_outlined),
                      selectedIcon: Icon(Icons.map_outlined),
                      label: 'Mapa',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.local_mall_outlined),
                      selectedIcon: Icon(Icons.local_mall_outlined),
                      label: 'Marketplace',
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  int _screenIndexForNavigation(int navigationIndex) {
    return const [0, 2, 3, 1][navigationIndex];
  }

  int _navigationIndexForScreen(int screenIndex) {
    return switch (screenIndex) {
      0 => 0,
      2 => 1,
      3 => 2,
      1 => 3,
      _ => 0,
    };
  }

  Widget _buildBrandMark() {
    return SizedBox(
      width: 48,
      height: 48,
      child: Image.asset(
        'assets/images/zanate_logo.png',
        fit: BoxFit.contain,
        semanticLabel: 'Logo de Zanate',
      ),
    );
  }

  Widget _buildNavTab({
    required int index,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _currentIndex == index;
    final theme = Theme.of(context);
    final activeColor = widget.isDarkMode
        ? Colors.white
        : theme.colorScheme.primary;
    final inactiveColor = widget.isDarkMode
        ? const Color(0xFF949BA4)
        : Colors.grey.shade600;

    return Semantics(
      container: true,
      label: label,
      selected: isSelected,
      role: SemanticsRole.tab,
      onTap: () => _selectDesktopTab(index),
      child: ExcludeSemantics(
        child: Focus(
          focusNode: _desktopTabFocusNodes[index],
          skipTraversal: !isSelected,
          onKeyEvent: (_, event) => _handleDesktopTabKey(index, event),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: InkWell(
              canRequestFocus: false,
              onTap: () => _selectDesktopTab(index),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 18,
                      color: isSelected ? activeColor : inactiveColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isSelected ? activeColor : inactiveColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget? _buildContextualFloatingActionButton() {
    switch (_currentIndex) {
      case 1:
        // Marketplace: Publica un Artículo
        return FloatingActionButton.extended(
          heroTag: 'shell_market_fab',
          onPressed: () {
            CreateListingDialog.show(
              context,
              activeAlias: widget.activeAlias,
              onAliasChanged: widget.onAliasChanged,
              onListingCreated: (_) => setState(() {}),
            );
          },
          backgroundColor: Theme.of(context).colorScheme.onSurface,
          foregroundColor: Theme.of(context).colorScheme.surface,
          icon: const Icon(Icons.add_business_outlined, size: 22),
          label: const Text(
            'Publicar Artículo',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      case 2:
        return FloatingActionButton.extended(
          heroTag: 'shell_groups_fab',
          onPressed: () =>
              _groupsScreenKey.currentState?.openCreateGroupDialog(),
          backgroundColor: Theme.of(context).colorScheme.onSurface,
          foregroundColor: Theme.of(context).colorScheme.surface,
          icon: const Icon(Icons.group_add, size: 22),
          label: const Text(
            'Compartir Grupo',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      default:
        return null;
    }
  }
}
