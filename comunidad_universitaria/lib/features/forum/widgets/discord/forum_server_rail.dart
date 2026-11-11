import 'package:flutter/material.dart';
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
    final railBackground = isDark
        ? const Color(0xFF171717)
        : const Color(0xFFF7F7F7);
    final borderColor = isDark
        ? const Color(0xFF303030)
        : const Color(0xFFE5E5E5);
    final visibleServers = <ForumServer>[];
    for (final server in servers) {
      if (!server.isGroups &&
          !visibleServers.any((item) => item.id == server.id)) {
        visibleServers.add(server);
      }
    }

    return Container(
      width: 64,
      decoration: BoxDecoration(
        color: railBackground,
        border: Border(right: BorderSide(color: borderColor)),
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
                padding: const EdgeInsets.only(bottom: 12, top: 8),
                child: Tooltip(
                  message: 'Agregar servidor',
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: OutlinedButton(
                      onPressed: () => _addServer(context),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        foregroundColor: isDark
                            ? Colors.white
                            : const Color(0xFF202020),
                        side: BorderSide(color: borderColor),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                      ),
                      child: const Icon(Icons.add, size: 21),
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
    final foreground = isDark ? Colors.white : const Color(0xFF202020);
    final muted = isDark ? const Color(0xFFB3B3B3) : const Color(0xFF555555);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Tooltip(
        message: server.name.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim(),
        preferBelow: false,
        child: SizedBox(
          height: 48,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              if (isSelected)
                Container(width: 3, height: 28, color: foreground),
              Center(
                child: InkWell(
                  onTap: onTap,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDark
                                ? const Color(0xFF333333)
                                : const Color(0xFFE8E8E8))
                          : Colors.transparent,
                      border: Border.all(
                        color: isSelected ? foreground : Colors.transparent,
                      ),
                    ),
                    child: Icon(
                      server.icon,
                      size: 19,
                      color: isSelected ? foreground : muted,
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
