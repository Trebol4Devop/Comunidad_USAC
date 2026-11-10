import 'package:flutter/material.dart';
import '../../../rules/screens/rules_screen.dart';
import '../../models/discord_forum_models.dart';
import 'forum_carrera_picker_dialog.dart';

/// Barra lateral de servidores (Discord Server Rail) con ancho fijo (76px),
/// íconos en formato squircle (48x48px), píldoras de estado reactivas,
/// botón de agregar servidores y acceso directo a normas y descargo legal.
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

  void _openRules(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RulesScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final railBackground = isDark
        ? const Color(0xFF1E1F22)
        : const Color(0xFFE3E5E8);
    final borderColor = isDark
        ? const Color(0xFF2B2D31)
        : const Color(0xFFD1D5DB);

    final visibleServers = <ForumServer>[];
    for (final server in servers) {
      if (!server.isGroups &&
          !visibleServers.any((item) => item.id == server.id)) {
        visibleServers.add(server);
      }
    }

    return Container(
      width: 76,
      decoration: BoxDecoration(
        color: railBackground,
        border: Border(right: BorderSide(color: borderColor)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Contenedor scrolleable vertical con íconos de servidor
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

            // Separador discreto antes de las acciones del riel
            Container(
              width: 36,
              height: 2,
              margin: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF35363C) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(1),
              ),
            ),

            // 1. Botón de Agregar Servidor (+)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Tooltip(
                message: 'Agregar servidor',
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Material(
                    color: isDark ? const Color(0xFF313338) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _addServer(context),
                      borderRadius: BorderRadius.circular(16),
                      child: Center(
                        child: Icon(
                          Icons.add,
                          size: 24,
                          color: isDark ? const Color(0xFF23A55A) : const Color(0xFF16A34A),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 2. Botón de Normas y Descargo Legal (abajo del botón de agregar servidores)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 12),
              child: Tooltip(
                message: 'Normas y descargo legal',
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Material(
                    color: isDark ? const Color(0xFF313338) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _openRules(context),
                      borderRadius: BorderRadius.circular(16),
                      child: Center(
                        child: Icon(
                          Icons.shield_outlined,
                          size: 22,
                          color: isDark ? const Color(0xFF5865F2) : const Color(0xFF004B87),
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
    final activeBg = const Color(0xFF004B87); // Azul oficial USAC
    final inactiveBg = isDark ? const Color(0xFF313338) : Colors.white;
    final activeFg = Colors.white;
    final inactiveFg = isDark ? const Color(0xFFDBDEE1) : const Color(0xFF313338);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Tooltip(
        message: server.name.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim(),
        preferBelow: false,
        child: SizedBox(
          height: 48,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Píldora indicadora vertical estilo Discord a la izquierda
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                left: 0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  width: isSelected ? 4 : 0,
                  height: isSelected ? 36 : 0,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.horizontal(
                      right: Radius.circular(4),
                    ),
                  ),
                ),
              ),

              // Ícono de servidor en formato squircle 48x48px
              Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isSelected ? activeBg : inactiveBg,
                    // Activo se expande a forma ligeramente más cuadrada (14px), inactivo más redondeado (20px)
                    borderRadius: BorderRadius.circular(isSelected ? 14 : 20),
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
                        child: Icon(
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
