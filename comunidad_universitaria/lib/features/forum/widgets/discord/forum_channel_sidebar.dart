import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../../core/constants/zanate_colors.dart';
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
            message: 'Configuración',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showConfigSheet(context, isDark),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: bgTile,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor, width: 0.8),
                  ),
                  child: Center(
                    child: PhosphorIcon(
                      PhosphorIconsRegular.gearSix,
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

  void _showConfigSheet(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    final borderColor =
        isDark ? const Color(0xFF334155) : ZanateColors.subtleBorder;

    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: borderColor, width: 0.8),
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
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(
                  'Configuración',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (activeAlias != null)
                ListTile(
                  leading: const PhosphorIcon(
                    PhosphorIconsRegular.userCircle,
                    size: 24,
                  ),
                  title: const Text(
                    'Preferencias de usuario',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text('Alias actual: $activeAlias'),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
                  leading: PhosphorIcon(
                    isDark
                        ? PhosphorIconsRegular.sun
                        : PhosphorIconsRegular.moon,
                    size: 24,
                  ),
                  title: Text(
                    isDark ? 'Tema claro' : 'Tema oscuro',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    onToggleTheme?.call();
                  },
                ),
              ListTile(
                leading: const PhosphorIcon(
                  PhosphorIconsRegular.shieldCheck,
                  size: 24,
                ),
                title: const Text(
                  'Normas y descargo',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
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
