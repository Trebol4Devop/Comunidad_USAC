import 'package:flutter/material.dart';
import '../../models/discord_forum_models.dart';
import 'forum_carrera_picker_dialog.dart';

class ForumServerRail extends StatefulWidget {
  final List<ForumServer> servers;
  final ForumServer activeServer;
  final List<ForumFaculty>? faculties;
  final Function(ForumServer) onSelectServer;
  final Function(ForumServer) onAddServer;

  const ForumServerRail({
    super.key,
    required this.servers,
    required this.activeServer,
    this.faculties,
    required this.onSelectServer,
    required this.onAddServer,
  });

  @override
  State<ForumServerRail> createState() => _ForumServerRailState();
}

class _ForumServerRailState extends State<ForumServerRail> {
  final OverlayPortalController _overlayController = OverlayPortalController();
  ForumFaculty? _openFaculty;
  bool _isGroupsOpen = false;
  double _submenuLeft = 60.0;
  double _submenuTop = 0.0;

  @override
  void dispose() {
    if (_overlayController.isShowing) {
      _overlayController.hide();
    }
    super.dispose();
  }

  void _closeSubmenu() {
    if (_overlayController.isShowing) {
      _overlayController.hide();
    }
    if (mounted) {
      setState(() {
        _openFaculty = null;
        _isGroupsOpen = false;
      });
    } else {
      _openFaculty = null;
      _isGroupsOpen = false;
    }
  }

  void _toggleGroupsSubmenu(BuildContext itemContext) {
    if (_isGroupsOpen && _overlayController.isShowing) {
      _closeSubmenu();
      return;
    }

    final RenderBox? itemBox = itemContext.findRenderObject() as RenderBox?;
    final OverlayState? overlayState = Overlay.maybeOf(context);
    final RenderBox? overlayBox = overlayState?.context.findRenderObject() as RenderBox?;

    if (itemBox != null && overlayBox != null) {
      final mediaQuery = MediaQuery.of(context);
      final screenHeight = mediaQuery.size.height;
      final topPadding = mediaQuery.padding.top;
      final bottomPadding = mediaQuery.padding.bottom;

      final itemInOverlay = itemBox.localToGlobal(Offset.zero, ancestor: overlayBox);

      _submenuLeft = (itemInOverlay.dx + itemBox.size.width + 6)
          .clamp(0.0, overlayBox.size.width - 60.0);

      final estimatedContentHeight = 12.0 + (ForumServer.groupsSubservers.length * 42.0);
      final maxAvailableHeight = screenHeight - topPadding - bottomPadding - 24.0;
      final effectiveHeight = estimatedContentHeight > maxAvailableHeight
          ? maxAvailableHeight
          : estimatedContentHeight;

      double globalTop = itemInOverlay.dy - 4;

      if (globalTop + effectiveHeight > screenHeight - bottomPadding - 12) {
        globalTop = screenHeight - bottomPadding - 12 - effectiveHeight;
      }
      if (globalTop < topPadding + 12) {
        globalTop = topPadding + 12;
      }

      _submenuTop = globalTop;
    } else {
      _submenuLeft = 60.0;
      _submenuTop = 10.0;
    }

    setState(() {
      _openFaculty = null;
      _isGroupsOpen = true;
    });

    _overlayController.show();
  }

  void _toggleFacultySubmenu(ForumFaculty faculty, BuildContext itemContext) {
    // Al pulsar el servidor principal de la facultad, se abre el servidor de dicha facultad en general
    widget.onSelectServer(faculty.toGeneralServer());

    // Si la facultad solo tiene 1 carrera aparte de la general (o solo una carrera en total),
    // no tiene sentido desplegar submenú porque es una sola carrera.
    if (faculty.careers.length <= 1) {
      _closeSubmenu();
      return;
    }

    if (_openFaculty?.id == faculty.id && _overlayController.isShowing) {
      _closeSubmenu();
      return;
    }

    final RenderBox? itemBox = itemContext.findRenderObject() as RenderBox?;
    final OverlayState? overlayState = Overlay.maybeOf(context);
    final RenderBox? overlayBox = overlayState?.context.findRenderObject() as RenderBox?;

    if (itemBox != null && overlayBox != null) {
      final mediaQuery = MediaQuery.of(context);
      final screenHeight = mediaQuery.size.height;
      final topPadding = mediaQuery.padding.top;
      final bottomPadding = mediaQuery.padding.bottom;

      final itemInOverlay = itemBox.localToGlobal(Offset.zero, ancestor: overlayBox);

      _submenuLeft = (itemInOverlay.dx + itemBox.size.width + 6)
          .clamp(0.0, overlayBox.size.width - 60.0);

      // Altura exacta acoplada al contenido real:
      // Padding vertical (12) + (N carreras + opción general) * (38 + 4)
      final totalCount = faculty.careers.length + (faculty.id != 'todas' ? 1 : 0);
      final estimatedContentHeight = 12.0 + (totalCount * 42.0);
      final maxAvailableHeight = screenHeight - topPadding - bottomPadding - 24.0;
      final effectiveHeight = estimatedContentHeight > maxAvailableHeight
          ? maxAvailableHeight
          : estimatedContentHeight;

      // Alineamos verticalmente con la posición de la facultad seleccionada
      double globalTop = itemInOverlay.dy - 4;

      // Verificamos que no se salga por abajo
      if (globalTop + effectiveHeight > screenHeight - bottomPadding - 12) {
        globalTop = screenHeight - bottomPadding - 12 - effectiveHeight;
      }
      // Verificamos que no se salga por arriba
      if (globalTop < topPadding + 12) {
        globalTop = topPadding + 12;
      }

      _submenuTop = globalTop;
    } else {
      _submenuLeft = 60.0;
      _submenuTop = 10.0;
    }

    setState(() {
      _openFaculty = faculty;
      _isGroupsOpen = false;
    });

    _overlayController.show();
  }

  Widget _buildFloatingGroupsSubmenu({
    required ThemeData theme,
    required bool isDark,
    required double maxHeight,
  }) {
    final railBg = isDark ? const Color(0xFF1E1F22) : const Color(0xFFE3E5E8);
    final borderColor = isDark ? const Color(0xFF2B2D31) : const Color(0xFFCBD5E1);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 52,
        constraints: BoxConstraints(maxHeight: maxHeight),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: railBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.20),
              blurRadius: 16,
              spreadRadius: 1,
              offset: const Offset(4, 4),
            ),
          ],
        ),
        child: RawScrollbar(
          thumbVisibility: false,
          thickness: 2.0,
          radius: const Radius.circular(2),
          thumbColor: isDark
              ? Colors.white.withValues(alpha: 0.25)
              : Colors.black.withValues(alpha: 0.20),
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final subserver in ForumServer.groupsSubservers)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Tooltip(
                      message: subserver.name,
                      preferBelow: false,
                      child: _buildItemButton(
                        isActive: widget.activeServer.isGroups &&
                            widget.activeServer.id == subserver.id,
                        activeColor: subserver.color,
                        isDark: isDark,
                        onTap: () {
                          widget.onSelectServer(subserver);
                          _closeSubmenu();
                        },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              subserver.icon,
                              size: 15,
                              color: (widget.activeServer.isGroups &&
                                      widget.activeServer.id == subserver.id)
                                  ? Colors.white
                                  : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              subserver.shortCode,
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              style: TextStyle(
                                fontSize: 7.0,
                                fontWeight: FontWeight.bold,
                                color: (widget.activeServer.isGroups &&
                                        widget.activeServer.id == subserver.id)
                                    ? Colors.white
                                    : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingSubmenu({
    required ForumFaculty faculty,
    required ThemeData theme,
    required bool isDark,
    required double maxHeight,
  }) {
    final railBg = isDark ? const Color(0xFF1E1F22) : const Color(0xFFE3E5E8);
    final borderColor = isDark ? const Color(0xFF2B2D31) : const Color(0xFFCBD5E1);

    final isFacultyActive =
        widget.activeServer.facultadId == faculty.id && !widget.activeServer.isGroups;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 52,
        constraints: BoxConstraints(maxHeight: maxHeight),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: railBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.20),
              blurRadius: 16,
              spreadRadius: 1,
              offset: const Offset(4, 4),
            ),
          ],
        ),
        child: RawScrollbar(
          thumbVisibility: false,
          thickness: 2.0,
          radius: const Radius.circular(2),
          thumbColor: isDark
              ? Colors.white.withValues(alpha: 0.25)
              : Colors.black.withValues(alpha: 0.20),
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (faculty.id != 'todas')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Tooltip(
                      message: faculty.name.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim(),
                      preferBelow: false,
                      child: _buildItemButton(
                        isActive: isFacultyActive && widget.activeServer.carreraId == 'todas',
                        activeColor: faculty.color,
                        isDark: isDark,
                        onTap: () {
                          widget.onSelectServer(faculty.toGeneralServer());
                          _closeSubmenu();
                        },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              faculty.icon,
                              size: 15,
                              color: (isFacultyActive && widget.activeServer.carreraId == 'todas')
                                  ? Colors.white
                                  : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              faculty.shortCode,
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              style: TextStyle(
                                fontSize: 7.0,
                                fontWeight: FontWeight.bold,
                                color: (isFacultyActive && widget.activeServer.carreraId == 'todas')
                                    ? Colors.white
                                    : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                for (final career in faculty.careers)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Tooltip(
                      message: career.name.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim(),
                      preferBelow: false,
                      child: _buildItemButton(
                        isActive: isFacultyActive && widget.activeServer.carreraId == career.id,
                        activeColor: faculty.color,
                        isDark: isDark,
                        onTap: () {
                          widget.onSelectServer(career.toServer(facultyColor: faculty.color));
                          _closeSubmenu();
                        },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              career.icon,
                              size: 15,
                              color: (isFacultyActive && widget.activeServer.carreraId == career.id)
                                  ? Colors.white
                                  : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              career.shortCode,
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              style: TextStyle(
                                fontSize: 7.0,
                                fontWeight: FontWeight.bold,
                                color: (isFacultyActive && widget.activeServer.carreraId == career.id)
                                    ? Colors.white
                                    : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemButton({
    required bool isActive,
    required Color activeColor,
    required bool isDark,
    required VoidCallback onTap,
    required Widget child,
    bool isExpandedOpen = false,
  }) {
    return SizedBox(
      height: 38,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          // Discord Pill Indicator on the left side
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 3,
            height: isActive ? 24 : (isExpandedOpen ? 12 : 0),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0066CC) : const Color(0xFF004B87),
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(3)),
            ),
          ),

          // Icon button
          Center(
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(isActive ? 10 : 18),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isActive
                      ? activeColor
                      : (isDark ? const Color(0xFF313338) : Colors.white),
                  borderRadius: BorderRadius.circular(isActive ? 10 : (isExpandedOpen ? 12 : 18)),
                  border: isExpandedOpen && !isActive
                      ? Border.all(color: activeColor.withValues(alpha: 0.8), width: 1.5)
                      : null,
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: activeColor.withValues(alpha: 0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(child: child),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhatsAppSymbol({required bool isActive, required bool isDark}) {
    final iconColor = isActive ? Colors.white : const Color(0xFF25D366);
    final phoneColor = isActive ? const Color(0xFF25D366) : Colors.white;

    return SizedBox(
      width: 16,
      height: 14,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.chat_bubble,
            size: 14,
            color: iconColor,
          ),
          Positioned(
            top: 2.8,
            left: 3.8,
            child: Transform.rotate(
              angle: -0.3,
              child: Icon(
                Icons.phone,
                size: 7,
                color: phoneColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final railBg = isDark ? const Color(0xFF1E1F22) : const Color(0xFFE3E5E8);
    final faculties = widget.faculties ?? ForumFaculty.defaultFaculties;
    final homeFaculty = faculties.firstWhere(
      (f) => f.id == 'todas',
      orElse: () => faculties.first,
    );
    final otherFaculties = faculties.where((f) => f.id != homeFaculty.id).toList();

    final isHomeActive = widget.activeServer.facultadId == homeFaculty.id &&
        !widget.activeServer.isGroups;
    final isHomeOpen = _openFaculty?.id == homeFaculty.id && homeFaculty.careers.length > 1;

    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final topPadding = mediaQuery.padding.top;
    final bottomPadding = mediaQuery.padding.bottom;

    return OverlayPortal(
      controller: _overlayController,
      overlayChildBuilder: (BuildContext overlayContext) {
        if (_openFaculty == null && !_isGroupsOpen) return const SizedBox.shrink();

        final maxAvailableHeight =
            (screenHeight - topPadding - bottomPadding - 24.0).clamp(80.0, double.infinity);

        return Positioned(
          left: _submenuLeft,
          top: _submenuTop,
          child: TapRegion(
            groupId: 'forum_server_submenu',
            onTapOutside: (_) => _closeSubmenu(),
            child: _isGroupsOpen
                ? _buildFloatingGroupsSubmenu(
                    theme: theme,
                    isDark: isDark,
                    maxHeight: maxAvailableHeight,
                  )
                : _buildFloatingSubmenu(
                    faculty: _openFaculty!,
                    theme: theme,
                    isDark: isDark,
                    maxHeight: maxAvailableHeight,
                  ),
          ),
        );
      },
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          width: 52,
          margin: const EdgeInsets.only(left: 6, top: 10, right: 6),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: railBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF2B2D31) : const Color(0xFFCBD5E1),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. General USAC Home Server (Campus Central)
              Builder(
                builder: (itemCtx) => Tooltip(
                  message: homeFaculty.name.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim(),
                  preferBelow: false,
                  child: _buildItemButton(
                    isActive: isHomeActive,
                    activeColor: homeFaculty.color,
                    isDark: isDark,
                    isExpandedOpen: isHomeOpen,
                    onTap: () => _toggleFacultySubmenu(homeFaculty, itemCtx),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.school,
                          size: 15,
                          color: isHomeActive
                              ? Colors.white
                              : (isDark ? const Color(0xFFDBDEE1) : theme.colorScheme.primary),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'USAC',
                          style: TextStyle(
                            fontSize: 7.0,
                            fontWeight: FontWeight.bold,
                            color: isHomeActive
                                ? Colors.white
                                : (isDark ? const Color(0xFFDBDEE1) : theme.colorScheme.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // 2. Grupos de Estudio Server (WhatsApp) - Con submenú de subservidores (facultades y áreas)
              Builder(
                builder: (itemCtx) {
                  final isGroupsActive = widget.activeServer.isGroups;
                  return Tooltip(
                    message: 'Grupos de Estudio',
                    preferBelow: false,
                    child: _buildItemButton(
                      isActive: isGroupsActive,
                      activeColor: ForumServer.groupsServer.color,
                      isDark: isDark,
                      isExpandedOpen: _isGroupsOpen,
                      onTap: () => _toggleGroupsSubmenu(itemCtx),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildWhatsAppSymbol(isActive: isGroupsActive, isDark: isDark),
                          Text(
                            'GRUPOS',
                            style: TextStyle(
                              fontSize: 6.5,
                              height: 1.0,
                              fontWeight: FontWeight.bold,
                              color: isGroupsActive
                                  ? Colors.white
                                  : (isDark ? Colors.grey.shade300 : const Color(0xFF0F5132)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 6),

              // Separador Pill Discord
              Center(
                child: Container(
                  width: 22,
                  height: 2,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF35363C) : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // 2. Lista de Facultades Oficiales USAC
              Flexible(
                child: ListView.builder(
                  primary: false,
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: otherFaculties.length,
                  itemBuilder: (ctx, i) {
                    final faculty = otherFaculties[i];
                    final isActive = widget.activeServer.facultadId == faculty.id &&
                        !widget.activeServer.isGroups;
                    final isOpen = _openFaculty?.id == faculty.id && faculty.careers.length > 1;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Builder(
                        builder: (itemCtx) => Tooltip(
                          message: faculty.name.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim(),
                          preferBelow: false,
                          child: _buildItemButton(
                            isActive: isActive,
                            activeColor: faculty.color,
                            isDark: isDark,
                            isExpandedOpen: isOpen,
                            onTap: () => _toggleFacultySubmenu(faculty, itemCtx),
                            child: isActive
                                ? Icon(faculty.icon, color: Colors.white, size: 18)
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        faculty.icon,
                                        size: 15,
                                        color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        faculty.shortCode,
                                        style: TextStyle(
                                          fontSize: 7.0,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 4),

              // 3. Botón Explorar todas las Carreras USAC
              Tooltip(
                message: 'Explorar todas las Carreras USAC',
                preferBelow: false,
                child: InkWell(
                  onTap: () {
                    _closeSubmenu();
                    ForumCarreraPickerDialog.show(
                      context,
                      onServerSelected: (newServer) {
                        widget.onAddServer(newServer);
                        widget.onSelectServer(newServer);
                      },
                    );
                  },
                  borderRadius: BorderRadius.circular(18),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF313338) : Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        )
                      ],
                    ),
                    child: const Icon(
                      Icons.explore_outlined,
                      size: 18,
                      color: Color(0xFF10B981),
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
