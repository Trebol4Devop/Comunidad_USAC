import 'package:flutter/material.dart';
import '../../models/discord_forum_models.dart';

enum DiggFeedFilter { myFeed, allDigg }

class DiggHeader extends StatefulWidget {
  final int currentIndex;
  final Function(int index)? onSelectTab;
  final ForumChannel? activeChannel;
  final Function(ForumChannel channel)? onChannelChanged;
  final List<ForumChannel> channels;
  final ForumServer? activeServer;
  final Function(ForumServer server)? onServerChanged;
  final List<ForumServer> servers;
  final DiggFeedFilter activeFilter;
  final Function(DiggFeedFilter filter) onFilterChanged;
  final TextEditingController searchController;
  final Function(String query) onSearchSubmitted;
  final VoidCallback onClearSearch;
  final String activeAlias;
  final Function(String newAlias) onAliasChanged;
  final VoidCallback? onOpenCreatePost;
  final VoidCallback? onToggleTheme;
  final bool isDarkMode;

  const DiggHeader({
    super.key,
    this.currentIndex = 0,
    this.onSelectTab,
    this.activeChannel,
    this.onChannelChanged,
    this.channels = const [
      ...ForumChannel.defaultChannels,
      ForumChannel.bookmarksChannel,
    ],
    this.activeServer,
    this.onServerChanged,
    this.servers = ForumServer.defaultServers,
    required this.activeFilter,
    required this.onFilterChanged,
    required this.searchController,
    required this.onSearchSubmitted,
    required this.onClearSearch,
    required this.activeAlias,
    required this.onAliasChanged,
    this.onOpenCreatePost,
    this.onToggleTheme,
    this.isDarkMode = false,
  });

  @override
  State<DiggHeader> createState() => _DiggHeaderState();
}

class _DiggHeaderState extends State<DiggHeader> {
  bool _isSearchExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7);
    final bgHeader = isDark ? const Color(0xFF18181B) : Colors.white;

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: bgHeader,
        border: Border(
          bottom: BorderSide(color: borderColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          // 1. Screen Navigation Tabs (Foro, Grupos, Marketplace)
          _buildScreenNavigationTabs(theme, isDark),

          const Spacer(),

          // 2. Search Bar Section
          _buildSearchBar(theme, isDark),

          const SizedBox(width: 10),

          // 3. Theme toggle
          if (widget.onToggleTheme != null)
            IconButton(
              icon: Icon(
                widget.isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                size: 20,
              ),
              tooltip: 'Cambiar tema',
              onPressed: widget.onToggleTheme,
            ),
        ],
      ),
    );
  }

  Widget _buildScreenNavigationTabs(ThemeData theme, bool isDark) {
    final pillBg = isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9);

    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: pillBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildScreenTab(
            index: 0,
            label: 'Foro',
            icon: Icons.forum_outlined,
            activeIcon: Icons.forum,
            isDark: isDark,
          ),
          _buildScreenTab(
            index: 1,
            label: 'Grupos',
            icon: Icons.groups_outlined,
            activeIcon: Icons.groups,
            isDark: isDark,
          ),
          _buildScreenTab(
            index: 2,
            label: 'Marketplace',
            icon: Icons.storefront_outlined,
            activeIcon: Icons.storefront,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildScreenTab({
    required int index,
    required String label,
    required IconData icon,
    required IconData activeIcon,
    required bool isDark,
  }) {
    final isSelected = widget.currentIndex == index;

    return _ScalePressButton(
      onTap: () {
        if (widget.onSelectTab != null) {
          widget.onSelectTab!(index);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF3F3F46) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              size: 16,
              color: isSelected
                  ? const Color(0xFF004B87)
                  : (isDark ? const Color(0xFFA1A1AA) : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                    : (isDark ? const Color(0xFFA1A1AA) : const Color(0xFF64748B)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme, bool isDark) {
    final searchBg = isDark ? const Color(0xFF27272A) : const Color(0xFFF4F4F5);

    String hintText = 'Buscar en la comunidad...';
    if (widget.currentIndex == 0) {
      final srv = widget.activeServer ?? ForumServer.defaultServers.first;
      hintText = 'Buscar en ${srv.shortCode}...';
    } else if (widget.currentIndex == 1) {
      hintText = 'Buscar grupos...';
    } else if (widget.currentIndex == 2) {
      hintText = 'Buscar productos...';
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: _isSearchExpanded ? 240 : 180,
      height: 36,
      child: TextField(
        controller: widget.searchController,
        onTap: () => setState(() => _isSearchExpanded = true),
        onEditingComplete: () => setState(() => _isSearchExpanded = false),
        onSubmitted: (val) {
          widget.onSearchSubmitted(val);
          setState(() => _isSearchExpanded = false);
        },
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            fontSize: 12,
            color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF94A3B8),
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 18,
            color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF64748B),
          ),
          suffixIcon: widget.searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  onPressed: widget.onClearSearch,
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          filled: true,
          fillColor: searchBg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _ScalePressButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _ScalePressButton({required this.child, required this.onTap});

  @override
  State<_ScalePressButton> createState() => _ScalePressButtonState();
}

class _ScalePressButtonState extends State<_ScalePressButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
