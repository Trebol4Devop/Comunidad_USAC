import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../../core/constants/zanate_colors.dart';
import '../../models/discord_forum_models.dart';
import 'forum_carrera_picker_dialog.dart';

class ForumServerRail extends StatelessWidget {
  final List<ForumServer> servers;
  final ForumServer activeServer;
  final Function(ForumServer) onSelectServer;
  final Function(ForumServer) onAddServer;
  final bool showAddButton;

  const ForumServerRail({
    super.key,
    required this.servers,
    required this.activeServer,
    required this.onSelectServer,
    required this.onAddServer,
    this.showAddButton = true,
  });

  Future<void> _addServer(BuildContext context) async {
    ForumServer? selectedServer;
    await ForumCarreraPickerDialog.show(
      context,
      onServerSelected: (server) {
        selectedServer = server;
        onAddServer(server);
      },
    );
    if (selectedServer != null) onSelectServer(selectedServer!);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final railBackground =
        isDark ? const Color(0xFF111827) : ZanateColors.railBg;
    final borderColor =
        isDark ? const Color(0xFF1F2937) : ZanateColors.subtleBorder;

    final visibleServers = <ForumServer>[];
    for (final server in servers) {
      if (!server.isGroups &&
          !visibleServers.any((item) => item.id == server.id)) {
        visibleServers.add(server);
      }
    }

    return Container(
      width: 68,
      decoration: BoxDecoration(
        color: railBackground,
        border: Border(right: BorderSide(color: borderColor, width: 0.8)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  for (final server in visibleServers)
                    _ServerButton(
                      server: server,
                      isSelected: server.id == activeServer.id,
                      onTap: () => onSelectServer(server),
                    ),
                ],
              ),
            ),
            if (showAddButton)
              Padding(
                padding: const EdgeInsets.only(bottom: 14, top: 8),
                child: Tooltip(
                  message: 'Agregar servidor',
                  child: SizedBox(
                    width: 46,
                    height: 46,
                    child: Material(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: () => _addServer(context),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderColor, width: 0.8),
                          ),
                          child: PhosphorIcon(
                            PhosphorIconsRegular.plus,
                            size: 20,
                            color: isDark
                                ? Colors.white
                                : ZanateColors.zanateDark,
                          ),
                        ),
                      ),
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

class _ServerButton extends StatelessWidget {
  final ForumServer server;
  final bool isSelected;
  final VoidCallback onTap;

  const _ServerButton({
    required this.server,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeBg =
        isDark ? ZanateColors.zanateAccent : ZanateColors.zanateDark;
    final inactiveBg = Colors.transparent;
    final activeIconColor = Colors.white;
    final inactiveIconColor =
        isDark ? const Color(0xFF94A3B8) : Colors.blueGrey.shade600;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Tooltip(
        message: server.name.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim(),
        preferBelow: false,
        child: SizedBox(
          height: 48,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Píldora indicadora izquierda
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                width: isSelected ? 4 : 0,
                height: isSelected ? 28 : 0,
                decoration: BoxDecoration(
                  color: isDark
                      ? ZanateColors.zanateAccent
                      : ZanateColors.zanateDark,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(4),
                    bottomRight: Radius.circular(4),
                  ),
                ),
              ),
              Center(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: isSelected ? activeBg : inactiveBg,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: activeBg.withValues(alpha: 0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Icon(
                          server.icon,
                          size: 22,
                          color: isSelected
                              ? activeIconColor
                              : inactiveIconColor,
                        ),
                      ),
                    ),
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
