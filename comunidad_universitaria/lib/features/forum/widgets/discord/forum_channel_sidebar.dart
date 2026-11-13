import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../../core/constants/zanate_colors.dart';
import '../../../shared/widgets/settings_bottom_sheet.dart';
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
    final background = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF334155) : ZanateColors.subtleBorder;

    final channelList =
        channels ??
        (activeServer.isGroups
            ? ForumChannel.groupsChannels
            : ForumChannel.defaultChannels);

    return Container(
      width: 244,
      color: background,
      child: Column(
        children: [
          // Cabecera del servidor activo
          Container(
            height: 62,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: borderColor, width: 0.8),
              ),
            ),
            child: Row(
              children: [
                if (activeServer.resolvedLogoAsset != null) ...[
                  Container(
                    width: 28,
                    height: 28,
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF26282B) : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isDark ? const Color(0xFF383A40) : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    child: Image.asset(
                      activeServer.resolvedLogoAsset!,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        activeServer.icon,
                        size: 16,
                        color: activeServer.color,
                      ),
                    ),
                  ),
                ],
                Expanded(
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
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          color: isDark ? Colors.white : ZanateColors.zanateDark,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        activeServer.isGroups
                            ? 'Grupos de estudio'
                            : 'Comunidad universitaria',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : Colors.blueGrey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Lista de canales
          Expanded(
            child: ListView(
              primary: false,
              padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
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

          // Sección inferior con botones modernos
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
    final foreground = isDark ? Colors.white : ZanateColors.zanateDark;
    final muted = isDark ? const Color(0xFF94A3B8) : Colors.blueGrey.shade600;
    final bgTile = isDark ? const Color(0xFF0F172A) : ZanateColors.surfaceBg;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(top: BorderSide(color: borderColor, width: 0.8)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Tooltip(
              message: 'Agregar servidor',
              child: InkWell(
                onTap: onAddServer,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: bgTile,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor, width: 0.8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      PhosphorIcon(
                        PhosphorIconsRegular.plus,
                        size: 16,
                        color: foreground,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Agregar servidor',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
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
          const SizedBox(width: 8),
          Tooltip(
            message: 'Configuración y Perfil',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => SettingsBottomSheet.show(
                  context,
                  activeAlias: activeAlias ?? 'Estudiante',
                  onAliasChanged: onAliasChanged ?? (_) {},
                  onToggleTheme: onToggleTheme,
                ),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: bgTile,
                    border: Border.all(color: borderColor, width: 0.8),
                  ),
                  child: Center(
                    child: PhosphorIcon(
                      PhosphorIconsRegular.gear,
                      size: 20,
                      color: muted,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.9,
          color: isDark ? const Color(0xFF64748B) : Colors.blueGrey.shade400,
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
    final activeBg = isDark
        ? ZanateColors.zanateAccent.withValues(alpha: 0.25)
        : ZanateColors.zanateAccent.withValues(alpha: 0.10);
    final activeTextColor = isDark ? Colors.white : ZanateColors.zanateDark;
    final inactiveTextColor =
        isDark ? const Color(0xFF94A3B8) : Colors.blueGrey.shade700;

    final iconColor = isActive
        ? ZanateColors.zanateAccent
        : (isDark ? const Color(0xFF64748B) : Colors.blueGrey.shade500);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: isActive ? activeBg : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => onSelectChannel(channel),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  channel.icon,
                  size: 18,
                  color: iconColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    channel.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight:
                          isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive ? activeTextColor : inactiveTextColor,
                    ),
                  ),
                ),
                if (channel.isSpecial)
                  PhosphorIcon(
                    PhosphorIconsFill.bookmarkSimple,
                    size: 13,
                    color: iconColor,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
