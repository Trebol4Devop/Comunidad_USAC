import 'package:flutter/material.dart';
import '../../models/discord_forum_models.dart';
import 'forum_carrera_picker_dialog.dart';

class ForumServerRail extends StatelessWidget {
  final List<ForumServer> servers;
  final ForumServer activeServer;
  final Function(ForumServer) onSelectServer;
  final Function(ForumServer) onAddServer;

  const ForumServerRail({
    super.key,
    required this.servers,
    required this.activeServer,
    required this.onSelectServer,
    required this.onAddServer,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Discord dark server rail: #1E1F22, light rail: #E3E5E8
    final railBg = isDark ? const Color(0xFF1E1F22) : const Color(0xFFE3E5E8);

    return Container(
      width: 72,
      color: railBg,
      child: Column(
        children: [
          const SizedBox(height: 12),

          // 1. General USAC Home Server (first item)
          if (servers.isNotEmpty) ...[
            _buildServerIcon(
              server: servers.first,
              isActive: activeServer.id == servers.first.id,
              theme: theme,
              isDark: isDark,
              isHome: true,
            ),
            const SizedBox(height: 8),
            // Discord Separator Pill
            Center(
              child: Container(
                width: 32,
                height: 2,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF35363C) : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // 2. Scrollable list of Carrera Servers
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: servers.length > 1 ? servers.length - 1 : 0,
              itemBuilder: (ctx, i) {
                final s = servers[i + 1];
                final isActive = s.id == activeServer.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildServerIcon(
                    server: s,
                    isActive: isActive,
                    theme: theme,
                    isDark: isDark,
                  ),
                );
              },
            ),
          ),

          // 3. Add / Explore More Carreras Button
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Tooltip(
              message: 'Explorar todas las Carreras USAC',
              preferBelow: false,
              child: InkWell(
                onTap: () {
                  ForumCarreraPickerDialog.show(
                    context,
                    onServerSelected: (newServer) {
                      onAddServer(newServer);
                      onSelectServer(newServer);
                    },
                  );
                },
                borderRadius: BorderRadius.circular(24),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF313338) : Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: Icon(
                    Icons.explore_outlined,
                    size: 22,
                    color: const Color(0xFF10B981),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServerIcon({
    required ForumServer server,
    required bool isActive,
    required ThemeData theme,
    required bool isDark,
    bool isHome = false,
  }) {
    return Tooltip(
      message: server.name,
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 300),
      child: SizedBox(
        height: 50,
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            // Discord Pill Indicator on the left side
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 4,
              height: isActive ? 40 : 0,
              decoration: BoxDecoration(
                color: isDark ? Colors.white : const Color(0xFF004B87),
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
              ),
            ),

            // Server Icon
            Center(
              child: InkWell(
                onTap: () => onSelectServer(server),
                borderRadius: BorderRadius.circular(isActive ? 16 : 24),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isActive
                        ? server.color
                        : (isDark ? const Color(0xFF313338) : Colors.white),
                    borderRadius: BorderRadius.circular(isActive ? 16 : 24),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: server.color.withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: isHome
                        ? Icon(
                            server.icon,
                            color: isActive ? Colors.white : theme.colorScheme.primary,
                            size: 24,
                          )
                        : (isActive
                            ? Icon(server.icon, color: Colors.white, size: 24)
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    server.icon,
                                    size: 18,
                                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    server.shortCode,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              )),
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
