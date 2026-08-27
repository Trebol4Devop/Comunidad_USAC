import 'package:flutter/material.dart';
import '../../core/utils/responsive.dart';
import '../forum/screens/forum_screen.dart';
import '../groups/screens/groups_screen.dart';
import '../marketplace/screens/marketplace_screen.dart';
import '../profile/screens/profile_screen.dart';
import '../rules/screens/rules_screen.dart';
import '../shared/widgets/alias_badge_button.dart';

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
    setState(() => _currentIndex = 3);
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
            Text('Aviso Comunitario', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Comunidad Universitaria es una plataforma estudiantil colaborativa, autónoma y sin fines de lucro. No representa formalmente a la administración ni a las autoridades de la Universidad de San Carlos de Guatemala (USAC). Los datos académicos, pensums y directorios son informativos y compartidos entre compañeros.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
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
    final isDesktop = Responsive.isDesktop(context);

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
            const SizedBox(width: 10),
            InkWell(
              onTap: _showDisclaimerModal,
              borderRadius: BorderRadius.circular(4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Comunidad Universitaria',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
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
                  Text(
                    'Red Estudiantil Autónoma e Independiente',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isDesktop ? Colors.grey.shade600 : theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // User Alias Pill that links directly to Profile
          AliasBadgeButton(
            alias: widget.activeAlias,
            onAliasChanged: widget.onAliasChanged,
            onTap: _navigateToProfile,
          ),
          const SizedBox(width: 8),

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
                    border: Border(
                      bottom: BorderSide(
                        color: widget.isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                  ),
                  child: MaxWidthContainer(
                    maxWidth: 1100,
                    padding: EdgeInsets.zero,
                    child: Row(
                      children: [
                        _buildNavTab(index: 0, label: 'Foro Estudiantil', icon: Icons.forum_outlined),
                        _buildNavTab(index: 1, label: 'Grupos de Estudio', icon: Icons.groups_outlined),
                        _buildNavTab(index: 2, label: 'Marketplace & Tutorías', icon: Icons.storefront_outlined),
                        _buildNavTab(index: 3, label: 'Mi Perfil', icon: Icons.person_outline),
                        _buildNavTab(index: 4, label: 'Normas & Descargo', icon: Icons.shield_outlined),
                      ],
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
          ),
          GroupsScreen(
            activeAlias: widget.activeAlias,
            onAliasChanged: widget.onAliasChanged,
          ),
          MarketplaceScreen(
            activeAlias: widget.activeAlias,
            onAliasChanged: widget.onAliasChanged,
          ),
          ProfileScreen(
            activeAlias: widget.activeAlias,
            onAliasChanged: widget.onAliasChanged,
            onToggleTheme: widget.onToggleTheme,
            isDarkMode: widget.isDarkMode,
          ),
          const RulesScreen(),
        ],
      ),
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
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Perfil',
                ),
                NavigationDestination(
                  icon: Icon(Icons.shield_outlined),
                  selectedIcon: Icon(Icons.shield),
                  label: 'Normas',
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

    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? theme.colorScheme.primary : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? theme.colorScheme.primary : Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? theme.colorScheme.primary : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
