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
    final inactiveBg = isDark ? const Color(0xFF313338) : Colors.white;
    final activeFg = Colors.white;
    final inactiveFg =
        isDark ? const Color(0xFFDBDEE1) : const Color(0xFF313338);
    final logoAsset = server.resolvedLogoAsset;
    final hasLogo = logoAsset != null && logoAsset.isNotEmpty;

    final containerBg = hasLogo
        ? (isDark ? const Color(0xFF26282B) : Colors.white)
        : (isSelected ? activeBg : inactiveBg);

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
              // Ícono o escudo de facultad en formato squircle 48x48px
              Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: containerBg,
                    // Activo se expande a forma ligeramente más cuadrada (14px), inactivo más redondeado (20px)
                    borderRadius: BorderRadius.circular(isSelected ? 14 : 20),
                    border: hasLogo
                        ? Border.all(
                            color: isSelected
                                ? activeBg
                                : (isDark
                                    ? const Color(0xFF383A40)
                                    : const Color(0xFFE2E8F0)),
                            width: isSelected ? 2 : 1,
                          )
                        : null,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: activeBg.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(isSelected ? 14 : 20),
                      child: Center(
                        child: hasLogo
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  isSelected ? 12 : 18,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Image.asset(
                                    logoAsset,
                                    width: 36,
                                    height: 36,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) => Icon(
                                      server.icon,
                                      size: 22,
                                      color: isSelected ? activeFg : inactiveFg,
                                    ),
                                  ),
                                ),
                              )
                            : Icon(
                                server.icon,
                                size: 22,
                                color: isSelected ? activeFg : inactiveFg,
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
