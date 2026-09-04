import 'package:flutter/material.dart';
import '../../models/discord_forum_models.dart';

class DiggSidebarLeft extends StatelessWidget {
  final ForumChannel? activeChannel;
  final Function(ForumChannel channel)? onSelectChannel;
  final List<ForumChannel> channels;
  final String activeAlias;
  final VoidCallback? onTapAvatar;
  final VoidCallback onOpenSettings;
  final VoidCallback? onOpenMoreCommunities;

  // Optional legacy fallbacks
  final String? activeSection;
  final String? activeCommunityId;
  final Function(String section)? onSelectSection;
  final Function(String communityId)? onSelectCommunity;

  const DiggSidebarLeft({
    super.key,
    this.activeChannel,
    this.onSelectChannel,
    this.channels = const [
      ...ForumChannel.defaultChannels,
      ForumChannel.bookmarksChannel,
    ],
    this.activeAlias = 'Estudiante',
    this.onTapAvatar,
    required this.onOpenSettings,
    this.onOpenMoreCommunities,
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

    final currentChannelId = activeChannel?.id ??
        (activeCommunityId ??
            (activeSection == 'questions'
                ? 'prerrequisitos'
                : activeSection == 'top'
                    ? 'catedraticos'
                    : 'todos'));

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
          // 1. Top Logo (Brand identity)
          _buildLogo(theme, isDark),

          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Divider(color: borderColor, height: 1, thickness: 1),
          ),
          const SizedBox(height: 10),

          // 2. Discord Channels Vertical Rail (ForumChannel models)
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: channels.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final ch = channels[index];
                final isSelected = ch.id == currentChannelId;
                return _buildChannelItem(
                  context: context,
                  channel: ch,
                  isSelected: isSelected,
                  theme: theme,
                  isDark: isDark,
                );
              },
            ),
          ),

          // 3. Bottom Controls (User Avatar & Settings)
          if (onOpenMoreCommunities != null) ...[
            _buildBottomAction(
              icon: Icons.explore_outlined,
              tooltip: 'Explorar Carreras y Canales',
              onTap: onOpenMoreCommunities!,
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
      message: 'Comunidad USAC - Canales Estudiantiles',
      child: _ScalePressButton(
        onTap: () {
          if (onSelectChannel != null && channels.isNotEmpty) {
            onSelectChannel!(channels.first);
          } else if (onSelectSection != null) {
            onSelectSection!('featured');
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

  Widget _buildChannelItem({
    required BuildContext context,
    required ForumChannel channel,
    required bool isSelected,
    required ThemeData theme,
    required bool isDark,
  }) {
    return Tooltip(
      message: '#${channel.name}\n${channel.description}',
      preferBelow: false,
      child: _ScalePressButton(
        onTap: () {
          if (onSelectChannel != null) {
            onSelectChannel!(channel);
          }
          if (onSelectCommunity != null) {
            onSelectCommunity!(channel.categoryId);
          }
        },
        child: Center(
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Discord-style Active Indicator Pill on the left
              if (isSelected)
                Positioned(
                  left: -14,
                  child: Container(
                    width: 4,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Color(0xFF004B87),
                      borderRadius: BorderRadius.horizontal(right: Radius.circular(4)),
                    ),
                  ),
                ),
              // Squircle / Circle Channel Icon
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF004B87)
                      : (isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(isSelected ? 13 : 21), // Discord squircle morph
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0x35004B87),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Icon(
                  channel.icon,
                  size: 20,
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
