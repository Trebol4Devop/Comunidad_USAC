import 'package:flutter/material.dart';
import '../../../profile/screens/profile_screen.dart';
import '../../models/discord_forum_models.dart';
import 'forum_carrera_picker_dialog.dart';

class ForumChannelSidebar extends StatelessWidget {
  final ForumServer activeServer;
  final ForumChannel activeChannel;
  final List<ForumChannel>? channels;
  final Function(ForumChannel) onSelectChannel;
  final Function(ForumServer) onServerChanged;
  final String activeAlias;
  final Function(String) onAliasChanged;

  const ForumChannelSidebar({
    super.key,
    required this.activeServer,
    required this.activeChannel,
    this.channels,
    required this.onSelectChannel,
    required this.onServerChanged,
    required this.activeAlias,
    required this.onAliasChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Discord channel sidebar: dark: #2B2D31, light: #F2F3F5
    final sidebarBg = isDark ? const Color(0xFF2B2D31) : const Color(0xFFF2F3F5);

    return Container(
      width: 240,
      color: sidebarBg,
      child: Column(
        children: [
          // 1. Server Header Banner
          InkWell(
            onTap: () {
              ForumCarreraPickerDialog.show(
                context,
                onServerSelected: onServerChanged,
              );
            },
            child: Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF202225) : const Color(0xFFE2E8F0),
                    width: 1.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                activeServer.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.verified,
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                          ],
                        ),
                        Text(
                          activeServer.id == ForumServer.groupsServer.id
                              ? 'Directorio de WhatsApp · USAC'
                              : 'Servidor Estudiantil · USAC',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? const Color(0xFF949BA4) : const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (activeServer.id != ForumServer.groupsServer.id)
                    Icon(Icons.keyboard_arrow_down, size: 20, color: Colors.grey.shade500),
                ],
              ),
            ),
          ),

          // 2. Channels List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              children: [
                if (activeServer.id == ForumServer.groupsServer.id) ...[
                  // Category Header: FACULTADES Y ÁREAS
                  _buildCategoryHeader('FACULTADES Y ÁREAS', isDark),
                  const SizedBox(height: 4),

                  // Channels
                  ...(channels ?? ForumChannel.groupsChannels).map((channel) {
                    final isActive = activeChannel.id == channel.id;
                    return _buildChannelTile(
                      channel: channel,
                      isActive: isActive,
                      theme: theme,
                      isDark: isDark,
                    );
                  }),
                ] else ...[
                  // Category Header: CANALES DE DISCUSIÓN
                  _buildCategoryHeader('CANALES DE DISCUSIÓN', isDark),
                  const SizedBox(height: 4),

                  // Channels
                  ...(channels ?? ForumChannel.defaultChannels).map((channel) {
                    final isActive = activeChannel.id == channel.id;
                    return _buildChannelTile(
                      channel: channel,
                      isActive: isActive,
                      theme: theme,
                      isDark: isDark,
                    );
                  }),

                  const SizedBox(height: 16),

                  // Category Header: ACCESOS RÁPIDOS
                  _buildCategoryHeader('PERSONAL', isDark),
                  const SizedBox(height: 4),

                  // Bookmarks Channel
                  _buildChannelTile(
                    channel: ForumChannel.bookmarksChannel,
                    isActive: activeChannel.id == ForumChannel.bookmarksChannel.id,
                    theme: theme,
                    isDark: isDark,
                  ),
                ],
              ],
            ),
          ),

          // 3. Bottom User Profile Bar
          Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            color: isDark ? const Color(0xFF232428) : const Color(0xFFE3E5E8),
            child: Row(
              children: [
                // User Avatar
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: isDark ? const Color(0xFF2563EB) : const Color(0xFF004B87),
                      child: Text(
                        activeAlias.isNotEmpty ? activeAlias.characters.first.toUpperCase() : 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? const Color(0xFF232428) : Colors.white,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),

                // Alias & Subtitle
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activeAlias,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      Text(
                        'En línea',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? const Color(0xFF949BA4) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),

                // Settings / Preferences Button
                IconButton(
                  icon: const Icon(Icons.settings_outlined, size: 16),
                  tooltip: 'Preferencias de Usuario',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProfileScreen(
                          activeAlias: activeAlias,
                          onAliasChanged: onAliasChanged,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: isDark ? const Color(0xFF949BA4) : const Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _buildChannelTile({
    required ForumChannel channel,
    required bool isActive,
    required ThemeData theme,
    required bool isDark,
  }) {
    // Discord channel active styling
    final activeBg = isDark
        ? const Color(0xFF35373C)
        : theme.colorScheme.primary.withValues(alpha: 0.12);
    final activeColor = isDark ? Colors.white : theme.colorScheme.primary;
    final mutedColor = isDark ? const Color(0xFF949BA4) : const Color(0xFF64748B);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 1.5),
      child: InkWell(
        onTap: () => onSelectChannel(channel),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: isActive ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(
                channel.icon,
                size: 18,
                color: isActive ? activeColor : mutedColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  channel.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    color: isActive ? activeColor : (isDark ? Colors.grey.shade300 : Colors.grey.shade800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
