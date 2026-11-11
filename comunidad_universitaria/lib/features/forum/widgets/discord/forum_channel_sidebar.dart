import 'package:flutter/material.dart';

import '../../../profile/screens/profile_screen.dart';

import '../../../rules/screens/rules_screen.dart';

import '../../models/discord_forum_models.dart';

class ForumChannelSidebar extends StatelessWidget {
  final ForumServer activeServer;

  final ForumChannel activeChannel;

  final List<ForumChannel>? channels;

  final Function(ForumChannel) onSelectChannel;

  final VoidCallback? onAddServer;

  final String? activeAlias;

  final Function(String)? onAliasChanged;

  final VoidCallback? onToggleTheme;

  const ForumChannelSidebar({
    super.key,

    required this.activeServer,

    required this.activeChannel,

    this.channels,

    required this.onSelectChannel,

    this.onAddServer,

    this.activeAlias,

    this.onAliasChanged,

    this.onToggleTheme,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isDark = theme.brightness == Brightness.dark;

    final background = isDark ? const Color(0xFF1C1C1C) : Colors.white;

    final borderColor = isDark
        ? const Color(0xFF303030)
        : const Color(0xFFE5E5E5);

    final channelList =
        channels ??
        (activeServer.isGroups
            ? ForumChannel.groupsChannels
            : ForumChannel.defaultChannels);

    return Container(
      width: 240,

      color: background,

      child: Column(
        children: [
          Container(
            height: 62,

            width: double.infinity,

            padding: const EdgeInsets.symmetric(horizontal: 16),

            alignment: Alignment.centerLeft,

            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderColor)),
            ),

            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  activeServer.name
                      .replaceAll(RegExp(r'\s*\([^)]*\)'), '')
                      .trim(),

                  maxLines: 1,

                  overflow: TextOverflow.ellipsis,

                  style: const TextStyle(
                    fontSize: 14,

                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  activeServer.isGroups
                      ? 'Grupos de estudio'
                      : 'Comunidad universitaria',

                  style: TextStyle(
                    fontSize: 10,

                    color: isDark
                        ? const Color(0xFFAAAAAA)
                        : const Color(0xFF777777),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              primary: false,

              padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),

              children: [
                _sectionLabel(
                  activeServer.isGroups ? 'GRUPOS' : 'CANALES',

                  isDark,
                ),

                const SizedBox(height: 6),

                for (final channel in channelList)
                  _channelTile(
                    channel,

                    activeChannel.id == channel.id,

                    theme,

                    isDark,
                  ),

                if (!activeServer.isGroups) ...[
                  const SizedBox(height: 18),

                  _sectionLabel('PERSONAL', isDark),

                  const SizedBox(height: 6),

                  _channelTile(
                    ForumChannel.bookmarksChannel,

                    activeChannel.id == ForumChannel.bookmarksChannel.id,

                    theme,

                    isDark,
                  ),
                ],
              ],
            ),
          ),

          _buildBottomConfigSection(context, theme, isDark, borderColor),
        ],
      ),
    );
  }

  Widget _buildBottomConfigSection(
    BuildContext context,

    ThemeData theme,

    bool isDark,

    Color borderColor,
  ) {
    final foreground = isDark ? Colors.white : const Color(0xFF202020);

    final muted = isDark ? const Color(0xFFAAAAAA) : const Color(0xFF666666);

    final bgTile = isDark ? const Color(0xFF252525) : const Color(0xFFF3F4F6);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181818) : const Color(0xFFFAFAFA),

        border: Border(top: BorderSide(color: borderColor)),
      ),

      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),

      child: Row(
        children: [
          Expanded(
            child: Tooltip(
              message: 'Agregar servidor',

              child: InkWell(
                onTap: onAddServer,

                borderRadius: BorderRadius.circular(6),

                child: Container(
                  height: 38,

                  padding: const EdgeInsets.symmetric(horizontal: 10),

                  decoration: BoxDecoration(
                    color: bgTile,

                    borderRadius: BorderRadius.circular(6),

                    border: Border.all(color: borderColor),
                  ),

                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,

                    children: [
                      Icon(Icons.add, size: 16, color: foreground),

                      const SizedBox(width: 6),

                      Flexible(
                        child: Text(
                          'Agregar servidor',

                          maxLines: 1,

                          overflow: TextOverflow.ellipsis,

                          style: TextStyle(
                            fontSize: 12,

                            fontWeight: FontWeight.w600,

                            color: foreground,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 6),

          Tooltip(
            message: 'Configuración',

            child: Material(
              color: Colors.transparent,

              child: InkWell(
                onTap: () => _showConfigSheet(context, isDark),

                borderRadius: BorderRadius.circular(6),

                child: Container(
                  width: 38,

                  height: 38,

                  decoration: BoxDecoration(
                    color: bgTile,

                    borderRadius: BorderRadius.circular(6),

                    border: Border.all(color: borderColor),
                  ),

                  child: Icon(Icons.settings_outlined, size: 18, color: muted),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showConfigSheet(BuildContext context, bool isDark) {
    final theme = Theme.of(context);

    showModalBottomSheet<void>(
      context: context,

      useSafeArea: true,

      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,

      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),

      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),

          child: Column(
            mainAxisSize: MainAxisSize.min,

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Center(
                child: Container(
                  width: 36,

                  height: 4,

                  margin: const EdgeInsets.only(bottom: 16),

                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,

                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),

                child: Text(
                  'Configuración',

                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              if (activeAlias != null)
                ListTile(
                  leading: const Icon(Icons.person_outline),

                  title: const Text('Preferencias de usuario'),

                  subtitle: Text('Alias actual: $activeAlias'),

                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),

                  onTap: () {
                    Navigator.of(ctx).pop();

                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProfileScreen(
                          activeAlias: activeAlias!,

                          onAliasChanged: onAliasChanged ?? (_) {},
                        ),
                      ),
                    );
                  },
                ),

              if (onToggleTheme != null)
                ListTile(
                  leading: Icon(
                    isDark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                  ),

                  title: Text(isDark ? 'Tema claro' : 'Tema oscuro'),

                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),

                  onTap: () {
                    Navigator.of(ctx).pop();

                    onToggleTheme?.call();
                  },
                ),

              ListTile(
                leading: const Icon(Icons.shield_outlined),

                title: const Text('Normas y descargo'),

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),

                onTap: () {
                  Navigator.of(ctx).pop();

                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RulesScreen()),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionLabel(String label, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),

      child: Text(
        label,

        style: TextStyle(
          fontSize: 10,

          fontWeight: FontWeight.w700,

          letterSpacing: 0.7,

          color: isDark ? const Color(0xFF999999) : const Color(0xFF777777),
        ),
      ),
    );
  }

  Widget _channelTile(
    ForumChannel channel,

    bool isActive,

    ThemeData theme,

    bool isDark,
  ) {
    final activeColor = isDark ? Colors.white : const Color(0xFF202020);

    final mutedColor = isDark
        ? const Color(0xFFAAAAAA)
        : const Color(0xFF666666);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),

      child: Material(
        color: isActive
            ? (isDark ? const Color(0xFF333333) : const Color(0xFFF0F0F0))
            : Colors.transparent,

        child: InkWell(
          onTap: () => onSelectChannel(channel),

          child: SizedBox(
            height: 38,

            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),

              child: Row(
                children: [
                  Icon(
                    channel.icon,

                    size: 17,

                    color: isActive ? activeColor : mutedColor,
                  ),

                  const SizedBox(width: 9),

                  Expanded(
                    child: Text(
                      channel.name,

                      maxLines: 1,

                      overflow: TextOverflow.ellipsis,

                      style: TextStyle(
                        fontSize: 12,

                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.w500,

                        color: isActive ? activeColor : mutedColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
