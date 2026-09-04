import 'package:flutter/material.dart';
import '../../models/discord_forum_models.dart';

class DiggSidebarLeft extends StatelessWidget {
  final ForumServer? activeServer;
  final Function(ForumServer server)? onSelectServer;
  final List<ForumServer> servers;
  final String activeAlias;
  final VoidCallback? onTapAvatar;
  final VoidCallback onOpenSettings;
  final VoidCallback? onOpenMoreCommunities;
  final VoidCallback? onOpenRules;

  // Optional legacy / fallback properties for backward compatibility
  final ForumChannel? activeChannel;
  final Function(ForumChannel channel)? onSelectChannel;
  final String? activeSection;
  final String? activeCommunityId;
  final Function(String section)? onSelectSection;
  final Function(String communityId)? onSelectCommunity;

  const DiggSidebarLeft({
    super.key,
    this.activeServer,
    this.onSelectServer,
    this.servers = ForumServer.defaultServers,
    this.activeAlias = 'Estudiante',
    this.onTapAvatar,
    required this.onOpenSettings,
    this.onOpenMoreCommunities,
    this.onOpenRules,
    this.activeChannel,
    this.onSelectChannel,
    this.activeSection,
    this.activeCommunityId,
    this.onSelectSection,
    this.onSelectCommunity,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7);
    final bgSurface = isDark ? const Color(0xFF18181B) : const Color(0xFFFAFAFA);

    final currentServerId = activeServer?.id ?? (servers.isNotEmpty ? servers.first.id : 'todas');

    return Container(
      width: 70,
      decoration: BoxDecoration(
        color: bgSurface,
        border: Border(
          right: BorderSide(color: borderColor, width: 1),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // 1. Top Logo (Brand identity - returns to general USAC server)
          _buildLogo(theme, isDark),

          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Divider(color: borderColor, height: 1, thickness: 1),
          ),
          const SizedBox(height: 10),

          // 2. Discord Faculty Servers Vertical Rail (ForumServer models)
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: servers.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final srv = servers[index];
                final isSelected = srv.id == currentServerId;
                return _buildServerItem(
                  context: context,
                  server: srv,
                  isSelected: isSelected,
                  theme: theme,
                  isDark: isDark,
                );
              },
            ),
          ),

          // 3. Bottom Controls: Explorar, Normas, Avatar, Ajustes
          if (onOpenMoreCommunities != null) ...[
            _buildBottomAction(
              icon: Icons.explore_outlined,
              tooltip: 'Explorar Facultades y Carreras',
              onTap: onOpenMoreCommunities!,
              isDark: isDark,
            ),
            const SizedBox(height: 8),
          ],

          if (onOpenRules != null) ...[
            _buildBottomAction(
              icon: Icons.shield_outlined,
              tooltip: 'Normas de la Comunidad',
              onTap: onOpenRules!,
              isDark: isDark,
            ),
            const SizedBox(height: 8),
          ],

          // User Avatar directly above settings icon
          _buildUserAvatar(theme, isDark),
          const SizedBox(height: 6),

          _buildBottomAction(
            icon: Icons.settings_outlined,
            tooltip: 'Ajustes',
            onTap: onOpenSettings,
            isDark: isDark,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildLogo(ThemeData theme, bool isDark) {
    return Tooltip(
      message: 'Comunidad USAC - Campus Central',
      child: _ScalePressButton(
        onTap: () {
          if (onSelectServer != null && servers.isNotEmpty) {
            onSelectServer!(servers.first);
          } else if (onSelectChannel != null && activeChannel != null) {
            onSelectChannel!(activeChannel!);
          }
        },
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF004B87),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26004B87),
                offset: Offset(0, 3),
                blurRadius: 8,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.school_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _buildServerItem({
    required BuildContext context,
    required ForumServer server,
    required bool isSelected,
    required ThemeData theme,
    required bool isDark,
  }) {
    return Tooltip(
      message: '${server.name}\n${server.description}',
      preferBelow: false,
      child: _ScalePressButton(
        onTap: () {
          if (onSelectServer != null) {
            onSelectServer!(server);
          }
          if (onSelectCommunity != null) {
            onSelectCommunity!(server.id);
          }
        },
        child: Center(
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Discord-style Active Indicator Pill on the left rail edge
              AnimatedPositioned(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                left: -14,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  width: isSelected ? 4 : 0,
                  height: isSelected ? 28 : 0,
                  decoration: BoxDecoration(
                    color: server.color,
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                  ),
                ),
              ),
              // Squircle / Circle Server Icon (Discord Morphing Shape)
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isSelected
                      ? server.color
                      : (isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(isSelected ? 14 : 22), // Discord squircle morph
                  border: isSelected
                      ? Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.5)
                      : null,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: server.color.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Icon(
                  server.icon,
                  size: 21,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? const Color(0xFFA1A1AA) : const Color(0xFF64748B)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      child: _ScalePressButton(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark ? const Color(0xFF27272A) : const Color(0xFFF4F4F5),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
          ),
        ),
      ),
    );
  }

  Widget _buildUserAvatar(ThemeData theme, bool isDark) {
    final aliasLetter = activeAlias.trim().isNotEmpty
        ? activeAlias.trim()[0].toUpperCase()
        : 'U';

    return Tooltip(
      message: 'Mi Perfil ($activeAlias)',
      preferBelow: false,
      child: _ScalePressButton(
        onTap: onTapAvatar ?? onOpenSettings,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE0EDF8),
                border: Border.all(
                  color: const Color(0xFF004B87),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                aliasLetter,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF004B87),
                ),
              ),
            ),
            // Online indicator dot
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? const Color(0xFF18181B) : const Color(0xFFFAFAFA),
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
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
