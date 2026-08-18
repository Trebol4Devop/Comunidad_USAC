import 'package:flutter/material.dart';
import '../../core/utils/responsive.dart';
import '../forum/screens/forum_screen.dart';
import '../groups/screens/groups_screen.dart';
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Comunidad USAC',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  'Id y Enseñad a Todos',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // User Alias Pill
          AliasBadgeButton(
            alias: widget.activeAlias,
            onAliasChanged: widget.onAliasChanged,
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
                        _buildNavTab(index: 0, label: 'Foro Universitario', icon: Icons.forum_outlined),
                        _buildNavTab(index: 1, label: 'Grupos Estudiantiles', icon: Icons.groups_outlined),
                        _buildNavTab(index: 2, label: 'Normas & Descargo', icon: Icons.shield_outlined),
                      ],
                    ),
                  ),
                ),
              )
            : null,
      ),
      // IndexedStack avoids destroying and re-fetching screens when switching tabs, preventing memory leaks & network thrashing
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
