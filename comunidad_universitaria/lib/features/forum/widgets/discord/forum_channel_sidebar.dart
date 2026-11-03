import 'package:flutter/material.dart';
import '../../models/discord_forum_models.dart';

class ForumChannelSidebar extends StatelessWidget {
  final ForumServer activeServer;
  final ForumChannel activeChannel;
  final List<ForumChannel>? channels;
  final Function(ForumChannel) onSelectChannel;

  const ForumChannelSidebar({
    super.key,
    required this.activeServer,
    required this.activeChannel,
    this.channels,
    required this.onSelectChannel,
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
        ],
      ),
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
