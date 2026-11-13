import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../core/constants/zanate_colors.dart';
import '../../core/utils/responsive.dart';
import '../forum/screens/forum_screen.dart';
import '../groups/screens/groups_screen.dart';
import '../marketplace/screens/marketplace_screen.dart';
import '../map/screens/campus_map_screen.dart';
import '../rules/screens/rules_screen.dart';

class AppShell extends StatefulWidget {
  final String activeAlias;
  final Function(String newAlias) onAliasChanged;
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  const AppShell({
    super.key,
    required this.activeAlias,
    required this.onAliasChanged,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;
  bool _showMobileTopBar = true;
  final Set<int> _visitedTabs = {0};
  final GlobalKey<GroupsScreenState> _groupsScreenKey =
      GlobalKey<GroupsScreenState>();
  final List<FocusNode> _desktopTabFocusNodes = List.generate(
    4,
    (index) => FocusNode(debugLabel: 'Desktop tab $index'),
  );

  @override
  void dispose() {
    for (final focusNode in _desktopTabFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _selectDesktopTab(int index) {
    if (_currentIndex != index || !_visitedTabs.contains(index)) {
      setState(() {
        _currentIndex = index;
        _visitedTabs.add(index);
      });
    }
    _desktopTabFocusNodes[index].requestFocus();
  }

  KeyEventResult _handleDesktopTabKey(int index, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final nextIndex = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowRight =>
        (index + 1) % _desktopTabFocusNodes.length,
      LogicalKeyboardKey.arrowLeft =>
        (index - 1 + _desktopTabFocusNodes.length) %
            _desktopTabFocusNodes.length,
      LogicalKeyboardKey.home => 0,
      LogicalKeyboardKey.end => _desktopTabFocusNodes.length - 1,
      LogicalKeyboardKey.enter || LogicalKeyboardKey.space => index,
      _ => null,
    };

    if (nextIndex == null) return KeyEventResult.ignored;

    _selectDesktopTab(nextIndex);
    return KeyEventResult.handled;
  }

  void _navigateToRules() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const RulesScreen()));
  }

  void _showDisclaimerModal() {
    showDialog(
      context: context,
      requestFocus: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.info_outline, color: Color(0xFF004B87)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Aviso Comunitario',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Text(
          'Comunidad Zanate es una plataforma estudiantil colaborativa, autónoma y sin fines de lucro. No representa formalmente a la administración ni a las autoridades de la Universidad de San Carlos de Guatemala. Los datos académicos, pensums y directorios son informativos y compartidos entre compañeros.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _navigateToRules();
            },
            child: const Text('Ver Normas Completas'),
          ),
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      appBar: isMobile
          ? null
          : AppBar(
              toolbarHeight: 60,
              elevation: 0,
              backgroundColor: widget.isDarkMode
                  ? const Color(0xFF1E293B)
                  : Colors.white,
              shape: Border(
                bottom: BorderSide(
                  color: widget.isDarkMode
                      ? const Color(0xFF334155)
                      : ZanateColors.subtleBorder,
                  width: 0.8,
                ),
              ),
              centerTitle: false,
              titleSpacing: 16,
              title: Row(
                children: [
                  _buildBrandMark(),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: _showDisclaimerModal,
                      borderRadius: BorderRadius.circular(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Zanate',
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.croissantOne(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                  color: widget.isDarkMode
                                      ? Colors.white
                                      : ZanateColors.zanateDark,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Comunidad Universitaria',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: widget.isDarkMode
                                  ? const Color(0xFF94A3B8)
                                  : Colors.blueGrey.shade400,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: PhosphorIcon(
                    widget.isDarkMode
                        ? PhosphorIconsRegular.sun
                        : PhosphorIconsRegular.moon,
                    size: 20,
                  ),
                  tooltip: 'Cambiar tema',
                  onPressed: widget.onToggleTheme,
                ),
                const SizedBox(width: 8),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  decoration: BoxDecoration(
                    color: widget.isDarkMode
                        ? const Color(0xFF1C1C1C)
                        : Colors.white,
                    border: Border(
                      bottom: BorderSide(
                        color: widget.isDarkMode
                            ? const Color(0xFF303030)
                            : const Color(0xFFE2E8F0),
                        width: 1.5,
                      ),
                    ),
                  ),
                  child: MaxWidthContainer(
                    maxWidth: 1200,
                    padding: EdgeInsets.zero,
                    child: FocusTraversalGroup(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Semantics(
                          container: true,
                          explicitChildNodes: true,
                          role: SemanticsRole.tabBar,
                          child: Row(
                            children: [
                              _buildNavTab(
                                index: 0,
                                label: 'Foro Estudiantil',
                                icon: Icons.forum_outlined,
                              ),
                              _buildNavTab(
                                index: 1,
                                label: 'Marketplace & Tutorías',
                                icon: Icons.storefront_outlined,
                              ),
                              _buildNavTab(
                                index: 2,
                                label: 'Grupos de Estudio',
                                icon: Icons.groups_outlined,
                              ),
                              _buildNavTab(
                                index: 3,
                                label: 'Mapa',
                                icon: Icons.map_outlined,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (!isMobile) return false;
          if (notification.metrics.axis != Axis.vertical) return false;

          if (notification is ScrollUpdateNotification) {
            final dy = notification.scrollDelta ?? 0;
            if (dy > 2 && notification.metrics.pixels > 20) {
              if (_showMobileTopBar) {
                setState(() => _showMobileTopBar = false);
              }
            } else if (dy < -2) {
              if (!_showMobileTopBar) {
                setState(() => _showMobileTopBar = true);
              }
            }
            if (notification.metrics.pixels <= 10 && !_showMobileTopBar) {
              setState(() => _showMobileTopBar = true);
            }
          } else if (notification is UserScrollNotification) {
            if (notification.direction == ScrollDirection.reverse &&
                _showMobileTopBar &&
                notification.metrics.pixels > 20) {
              setState(() => _showMobileTopBar = false);
            } else if (notification.direction == ScrollDirection.forward &&
                !_showMobileTopBar) {
              setState(() => _showMobileTopBar = true);
            }
          }
          return false;
        },
        child: isMobile
            ? Column(
                children: [
                  ColoredBox(
                    color:
                        theme.appBarTheme.backgroundColor ??
                        const Color(0xFF1C1C1C),
                    child: SafeArea(
                      bottom: false,
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        alignment: Alignment.topCenter,
                        child: ClipRect(
                          child: _showMobileTopBar
                              ? _buildMobileHeader(theme)
                              : const SizedBox(
                                  width: double.infinity,
                                  height: 0,
                                ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(child: _buildIndexedStack(isMobile)),
                ],
              )
            : _buildIndexedStack(isMobile),
      ),
      floatingActionButton: (isMobile && _showMobileTopBar)
          ? _buildContextualFloatingActionButton()
          : null,
      bottomNavigationBar: !isMobile
          ? null
          : AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: ClipRect(
                child: _showMobileTopBar
                    ? Container(
                        height: 60,
                        decoration: BoxDecoration(
                          color: widget.isDarkMode
                              ? const Color(0xFF1E293B)
                              : Colors.white,
                          border: Border(
                            top: BorderSide(
                              color: widget.isDarkMode
                                  ? const Color(0xFF334155)
                                  : ZanateColors.subtleBorder,
                              width: 0.8,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildBottomNavItem(
                              navIndex: 0,
                              label: 'Foro',
                              activeIcon: PhosphorIconsFill.chatsCircle,
                              inactiveIcon: PhosphorIconsRegular.chatsCircle,
                            ),
                            _buildBottomNavItem(
                              navIndex: 1,
                              label: 'Grupos',
                              activeIcon: PhosphorIconsFill.usersThree,
                              inactiveIcon: PhosphorIconsRegular.usersThree,
                            ),
                            _buildBottomNavItem(
                              navIndex: 2,
                              label: 'Mapa',
                              activeIcon: PhosphorIconsFill.mapTrifold,
                              inactiveIcon: PhosphorIconsRegular.mapTrifold,
                            ),
                            _buildBottomNavItem(
                              navIndex: 3,
                              label: 'Marketplace',
                              activeIcon: PhosphorIconsFill.shoppingBag,
                              inactiveIcon: PhosphorIconsRegular.shoppingBag,
                            ),
                          ],
                        ),
                      )
                    : const SizedBox(width: double.infinity, height: 0),
              ),
            ),
    );
  }

  Widget _buildBottomNavItem({
    required int navIndex,
    required String label,
    required IconData activeIcon,
    required IconData inactiveIcon,
  }) {
    final currentNavIndex = _navigationIndexForScreen(_currentIndex);
    final isSelected = currentNavIndex == navIndex;
    final isDark = widget.isDarkMode;

    final activeColor = isDark ? Colors.white : ZanateColors.zanateDark;
    final inactiveColor = isDark
        ? const Color(0xFF64748B)
        : Colors.blueGrey.shade400;

    return Semantics(
      label: label,
      selected: isSelected,
      button: true,
      child: InkWell(
        onTap: () {
          final screenIndex = _screenIndexForNavigation(navIndex);
          setState(() {
            _currentIndex = screenIndex;
            _visitedTabs.add(screenIndex);
            _showMobileTopBar = true;
          });
        },
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark
                      ? ZanateColors.zanateAccent.withValues(alpha: 0.22)
                      : ZanateColors.zanateDark.withValues(alpha: 0.08))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: PhosphorIcon(
            isSelected ? activeIcon : inactiveIcon,
            size: 24,
            color: isSelected ? activeColor : inactiveColor,
          ),
        ),
      ),
    );
  }

  int _screenIndexForNavigation(int navigationIndex) {
    return const [0, 2, 3, 1][navigationIndex];
  }

  int _navigationIndexForScreen(int screenIndex) {
    return switch (screenIndex) {
      0 => 0,
      2 => 1,
      3 => 2,
      1 => 3,
      _ => 0,
    };
  }

  Widget _buildMobileHeader(ThemeData theme) {
    final isDark = widget.isDarkMode;
    return Container(
      height: 60,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : ZanateColors.subtleBorder,
            width: 0.8,
          ),
        ),
      ),
      child: InkWell(
        onTap: _showDisclaimerModal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildBrandMark(),
            const SizedBox(width: 8),
            Text(
              'Zanate',
              style: GoogleFonts.croissantOne(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: isDark ? Colors.white : ZanateColors.zanateDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndexedStack(bool isMobile) {
    return IndexedStack(
      index: _currentIndex,
      children: [
        _visitedTabs.contains(0)
            ? ExcludeSemantics(
                excluding: _currentIndex != 0,
                child: ForumScreen(
                  activeAlias: widget.activeAlias,
                  onAliasChanged: widget.onAliasChanged,
                  onToggleTheme: widget.onToggleTheme,
                  isDarkMode: widget.isDarkMode,
                ),
              )
            : const SizedBox.shrink(),
        _visitedTabs.contains(1)
            ? ExcludeSemantics(
                excluding: _currentIndex != 1,
                child: MarketplaceScreen(
                  activeAlias: widget.activeAlias,
                  onAliasChanged: widget.onAliasChanged,
                  onToggleTheme: widget.onToggleTheme,
                  showFloatingActionButton: !isMobile,
                ),
              )
            : const SizedBox.shrink(),
        _visitedTabs.contains(2)
            ? ExcludeSemantics(
                excluding: _currentIndex != 2,
                child: GroupsScreen(
                  key: _groupsScreenKey,
                  activeAlias: widget.activeAlias,
                  onAliasChanged: widget.onAliasChanged,
                  onToggleTheme: widget.onToggleTheme,
                  showFloatingActionButton: false,
                  floatingActionButtonHeroTag: 'shell_groups_screen_fab',
                ),
              )
            : const SizedBox.shrink(),
        _visitedTabs.contains(3)
            ? ExcludeSemantics(
                excluding: _currentIndex != 3,
                child: const CampusMapScreen(),
              )
            : const SizedBox.shrink(),
      ],
    );
  }

  Widget _buildBrandMark() {
    return SizedBox(
      width: 48,
      height: 48,
      child: Image.asset(
        'assets/images/zanate_logo.png',
        fit: BoxFit.contain,
        semanticLabel: 'Logo de Zanate',
      ),
    );
  }

  Widget _buildNavTab({
    required int index,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _currentIndex == index;
    final theme = Theme.of(context);
    final activeColor = widget.isDarkMode
        ? Colors.white
        : theme.colorScheme.primary;
    final inactiveColor = widget.isDarkMode
        ? const Color(0xFFAAAAAA)
        : Colors.grey.shade600;

    return Semantics(
      container: true,
      label: label,
      selected: isSelected,
      role: SemanticsRole.tab,
      onTap: () => _selectDesktopTab(index),
      child: ExcludeSemantics(
        child: Focus(
          focusNode: _desktopTabFocusNodes[index],
          skipTraversal: !isSelected,
          onKeyEvent: (_, event) => _handleDesktopTabKey(index, event),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: InkWell(
              canRequestFocus: false,
              onTap: () => _selectDesktopTab(index),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 18,
                      color: isSelected ? activeColor : inactiveColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isSelected ? activeColor : inactiveColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget? _buildContextualFloatingActionButton() {
    return null;
  }
}
