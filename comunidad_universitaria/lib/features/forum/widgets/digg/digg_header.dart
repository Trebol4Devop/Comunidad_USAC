import 'package:flutter/material.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../shared/widgets/alias_badge_button.dart';
import '../../../shared/widgets/auth_modal.dart';
import '../../models/discord_forum_models.dart';
import '../discord/forum_carrera_picker_dialog.dart';

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

  void _handleAuthAction() {
    if (SupabaseService.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sesión activa como: ${SupabaseService.currentUser?.email ?? widget.activeAlias}'),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      AuthModal.show(
        context,
        title: 'Iniciar Sesión / Registro',
        subtitle: 'Accede con tu cuenta institucional o correo para personalizar tu feed.',
        onAuthenticated: () {
          setState(() {});
        },
      );
    }
  }

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
          // 1. Screen Navigation Tabs (Foro, Grupos, Marketplace, Perfil, Normas)
          _buildScreenNavigationTabs(theme, isDark),

          const SizedBox(width: 10),

          // 2. Channel & Server Selectors when inside Forum
          if (widget.currentIndex == 0) ...[
            _buildChannelSelector(theme, isDark),
            const SizedBox(width: 8),
            _buildServerBadge(theme, isDark),
          ],

          const Spacer(),

          // 3. Search Bar Section
          _buildSearchBar(theme, isDark),

          const SizedBox(width: 10),

          // 4. Create Button
          if (widget.onOpenCreatePost != null) ...[
            _ScalePressButton(
              onTap: widget.onOpenCreatePost!,
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF004B87),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x20004B87),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.add_rounded, size: 18, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'Publicar',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],

          // 5. Auth Button
          _buildAuthButton(theme, isDark),

          const SizedBox(width: 6),

          // 6. Theme toggle
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
          _buildScreenTab(
            index: 3,
            label: 'Perfil',
            icon: Icons.person_outline,
            activeIcon: Icons.person,
            isDark: isDark,
          ),
          _buildScreenTab(
            index: 4,
            label: 'Normas',
            icon: Icons.shield_outlined,
            activeIcon: Icons.shield,
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

  Widget _buildChannelSelector(ThemeData theme, bool isDark) {
    final currentCh = widget.activeChannel ??
        (widget.channels.isNotEmpty ? widget.channels.first : ForumChannel.defaultChannels.first);

    return PopupMenuButton<ForumChannel>(
      tooltip: 'Seleccionar Canal',
      offset: const Offset(0, 42),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (ch) {
        if (widget.onChannelChanged != null) {
          widget.onChannelChanged!(ch);
        }
      },
      itemBuilder: (ctx) => widget.channels.map((ch) {
        final isSelected = ch.id == currentCh.id;
        return PopupMenuItem<ForumChannel>(
          value: ch,
          child: Row(
            children: [
              Icon(
                ch.icon,
                size: 18,
                color: isSelected ? const Color(0xFF004B87) : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(
                '#${ch.name}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? const Color(0xFF004B87) : null,
                ),
              ),
            ],
          ),
        );
      }).toList(),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              currentCh.icon,
              size: 16,
              color: const Color(0xFF004B87),
            ),
            const SizedBox(width: 6),
            Text(
              '#${currentCh.name}',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFE4E4E7) : const Color(0xFF334155),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerBadge(ThemeData theme, bool isDark) {
    final srv = widget.activeServer ?? ForumServer.defaultServers.first;

    return Tooltip(
      message: 'Carrera: ${srv.name}',
      child: InkWell(
        onTap: () {
          ForumCarreraPickerDialog.show(
            context,
            onServerSelected: (newServer) {
              if (widget.onServerChanged != null) {
                widget.onServerChanged!(newServer);
              }
            },
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: srv.color.withValues(alpha: isDark ? 0.25 : 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: srv.color.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(srv.icon, size: 15, color: srv.color),
              const SizedBox(width: 6),
              Text(
                srv.shortCode,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: srv.color,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.unfold_more_rounded,
                size: 14,
                color: srv.color.withValues(alpha: 0.8),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme, bool isDark) {
    final searchBg = isDark ? const Color(0xFF27272A) : const Color(0xFFF4F4F5);

    String hintText = 'Buscar en la comunidad...';
    if (widget.currentIndex == 0) {
      final chName = widget.activeChannel?.name ?? 'foro';
      hintText = 'Buscar en #$chName...';
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

  Widget _buildAuthButton(ThemeData theme, bool isDark) {
    final isAuthenticated = SupabaseService.isAuthenticated;

    if (isAuthenticated) {
      return AliasBadgeButton(
        alias: widget.activeAlias,
        onAliasChanged: widget.onAliasChanged,
        onTap: () {
          if (widget.onSelectTab != null) {
            widget.onSelectTab!(3); // Navigate to Profile
          }
        },
      );
    }

    return _ScalePressButton(
      onTap: _handleAuthAction,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white : const Color(0xFF18181B),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          'Signup / Login',
          style: TextStyle(
            color: isDark ? const Color(0xFF18181B) : Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
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
