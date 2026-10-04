import 'package:flutter/material.dart';
import '../../core/utils/responsive.dart';
import '../forum/screens/forum_screen.dart';
import '../groups/screens/groups_screen.dart';
import '../groups/widgets/create_group_dialog.dart';
import '../marketplace/screens/marketplace_screen.dart';
import '../marketplace/widgets/create_listing_dialog.dart';
import '../profile/screens/profile_screen.dart';
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

  void _navigateToProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          activeAlias: widget.activeAlias,
          onAliasChanged: widget.onAliasChanged,
          onToggleTheme: widget.onToggleTheme,
          isDarkMode: widget.isDarkMode,
        ),
      ),
    );
  }

  void _navigateToRules() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const RulesScreen(),
      ),
    );
  }

  void _showDisclaimerModal() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.info_outline, color: Color(0xFF004B87)),
            SizedBox(width: 8),
            Expanded(
              child: Text('Aviso Comunitario', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 800;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF004B87),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.school, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 8),
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
                        Text(
                          isDesktop ? 'Comunidad Universitaria' : 'Comunidad USAC',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
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
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          // Rules & Norms Button
          IconButton(
            icon: const Icon(Icons.shield_outlined, size: 20),
            tooltip: 'Normas y Descargo',
            onPressed: _navigateToRules,
          ),
          const SizedBox(width: 4),

          // Theme toggle
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined, size: 20),
            tooltip: 'Cambiar tema',
            onPressed: widget.onToggleTheme,
          ),
          const SizedBox(width: 8),
        ],
        bottom: isDesktop
            ? PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  decoration: BoxDecoration(
                    color: widget.isDarkMode ? const Color(0xFF1E1F22) : Colors.white,
                    border: Border(
                      bottom: BorderSide(
                        color: widget.isDarkMode ? const Color(0xFF2B2D31) : const Color(0xFFE2E8F0),
                        width: 1.5,
                      ),
                    ),
                  ),
                  child: MaxWidthContainer(
                    maxWidth: 1200,
                    padding: EdgeInsets.zero,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildNavTab(index: 0, label: 'Foro Estudiantil', icon: Icons.forum_outlined),
                          _buildNavTab(index: 1, label: 'Grupos de Estudio', icon: Icons.groups_outlined),
                          _buildNavTab(index: 2, label: 'Marketplace & Tutorías', icon: Icons.storefront_outlined),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            : null,
      ),
      // IndexedStack avoids destroying and re-fetching screens when switching tabs
      body: IndexedStack(
        index: _currentIndex,
        children: [
          ForumScreen(
            activeAlias: widget.activeAlias,
            onAliasChanged: widget.onAliasChanged,
            onToggleTheme: widget.onToggleTheme,
            isDarkMode: widget.isDarkMode,
          ),
          GroupsScreen(
            activeAlias: widget.activeAlias,
            onAliasChanged: widget.onAliasChanged,
          ),
          MarketplaceScreen(
            activeAlias: widget.activeAlias,
            onAliasChanged: widget.onAliasChanged,
          ),
        ],
      ),
      floatingActionButton: !isDesktop ? _buildContextualFloatingActionButton() : null,
      bottomNavigationBar: isDesktop
          ? null
          : NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) {
                setState(() => _currentIndex = index);
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.forum_outlined),
                  selectedIcon: Icon(Icons.forum),
                  label: 'Foro',
                ),
                NavigationDestination(
                  icon: Icon(Icons.groups_outlined),
                  selectedIcon: Icon(Icons.groups),
                  label: 'Grupos',
                ),
                NavigationDestination(
                  icon: Icon(Icons.storefront_outlined),
                  selectedIcon: Icon(Icons.storefront),
                  label: 'Marketplace',
                ),
              ],
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
    final activeColor = widget.isDarkMode ? Colors.white : theme.colorScheme.primary;
    final inactiveColor = widget.isDarkMode ? const Color(0xFF949BA4) : Colors.grey.shade600;

    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? theme.colorScheme.primary : Colors.transparent,
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
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildContextualFloatingActionButton() {
    switch (_currentIndex) {
      case 1:
        // Grupos / Directorio: Sugiere un Enlace o Grupo
        return FloatingActionButton.extended(
          heroTag: 'shell_groups_fab',
          onPressed: () {
            CreateGroupDialog.show(
              context,
              activeAlias: widget.activeAlias,
              onAliasChanged: widget.onAliasChanged,
              onGroupCreated: (_) => setState(() {}),
            );
          },
          backgroundColor: const Color(0xFF16A34A),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.group_add, size: 22),
          label: const Text('Sugerir Enlace', style: TextStyle(fontWeight: FontWeight.bold)),
        );
      case 2:
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
          backgroundColor: const Color(0xFFEAB308),
          foregroundColor: Colors.black87,
          icon: const Icon(Icons.add_shopping_cart, size: 22),
          label: const Text('Publicar Artículo', style: TextStyle(fontWeight: FontWeight.bold)),
        );
      default:
        return null;
    }
  }
}
