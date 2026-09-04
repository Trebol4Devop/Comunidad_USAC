import 'package:flutter/material.dart';
import '../forum/models/discord_forum_models.dart';
import '../forum/screens/forum_screen.dart';
import '../forum/widgets/create_post_dialog.dart';
import '../forum/widgets/digg/digg_header.dart';
import '../forum/widgets/digg/digg_sidebar_left.dart';
import '../forum/widgets/discord/forum_carrera_picker_dialog.dart';
import '../groups/screens/groups_screen.dart';
import '../marketplace/screens/marketplace_screen.dart';
import '../profile/screens/profile_screen.dart';
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

  // Discord Forum Models State
  late List<ForumServer> _servers;
  late ForumServer _activeServer;
  late List<ForumChannel> _channels;
  late ForumChannel _activeChannel;

  // Search & Filters State
  DiggFeedFilter _activeFeedFilter = DiggFeedFilter.myFeed;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _servers = List.from(ForumServer.defaultServers);
    _activeServer = _servers.length > 2 ? _servers[2] : _servers.first; // Default to Sistemas or first
    _channels = [
      ...ForumChannel.defaultChannels,
      ForumChannel.bookmarksChannel,
    ];
    _activeChannel = _channels.first;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSelectChannel(ForumChannel channel) {
    setState(() {
      _currentIndex = 0; // Switch to Forum
      _activeChannel = channel;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  void _onSelectServer(ForumServer server) {
    setState(() {
      _currentIndex = 0; // Switch to Forum
      _activeServer = server;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  void _onTapAvatar() {
    setState(() => _currentIndex = 3); // Switch to Mi Perfil
  }

  void _onOpenSettings() {
    setState(() => _currentIndex = 3); // Switch to Mi Perfil / Ajustes
  }

  void _openCreatePost() {
    CreatePostDialog.show(
      context,
      activeAlias: widget.activeAlias,
      serverName: _activeServer.name,
      channelName: _activeChannel.name,
      initialCategory: _activeChannel.categoryId,
      initialFacultad: _activeServer.facultadId,
      initialCarrera: _activeServer.carreraId,
      onAliasChanged: widget.onAliasChanged,
      onPostCreated: (newPost) {
        setState(() {});
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktopOrTablet = width >= 768;
    final isDark = widget.isDarkMode;
    final feedBg = isDark ? const Color(0xFF18181B) : const Color(0xFFF4F4F5);

    if (isDesktopOrTablet) {
      return Scaffold(
        backgroundColor: feedBg,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Left Rail (USAC Faculty Servers, user avatar, settings, normas)
            DiggSidebarLeft(
              activeServer: _activeServer,
              onSelectServer: _onSelectServer,
              servers: _servers,
              activeChannel: _activeChannel,
              onSelectChannel: _onSelectChannel,
              activeAlias: widget.activeAlias,
              onTapAvatar: _onTapAvatar,
              onOpenSettings: _onOpenSettings,
              onOpenMoreCommunities: () {
                ForumCarreraPickerDialog.show(
                  context,
                  onServerSelected: _onSelectServer,
                );
              },
              onOpenRules: () {
                setState(() => _currentIndex = 4); // Switch to Normas Screen
              },
            ),

            // 2. Central Area (Header with Screen Navigation, Search Bar & Active Screen)
            Expanded(
              child: Column(
                children: [
                  // Integrated Top Header with Screen Navigation, Channel Selector & Search Bar
                  DiggHeader(
                    currentIndex: _currentIndex,
                    onSelectTab: (index) {
                      setState(() => _currentIndex = index);
                    },
                    activeChannel: _activeChannel,
                    onChannelChanged: _onSelectChannel,
                    channels: _channels,
                    activeServer: _activeServer,
                    onServerChanged: _onSelectServer,
                    servers: _servers,
                    activeFilter: _activeFeedFilter,
                    onFilterChanged: (filter) {
                      setState(() => _activeFeedFilter = filter);
                    },
                    searchController: _searchController,
                    onSearchSubmitted: (val) {
                      setState(() => _searchQuery = val);
                    },
                    onClearSearch: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    activeAlias: widget.activeAlias,
                    onAliasChanged: widget.onAliasChanged,
                    onOpenCreatePost: _currentIndex == 0 ? _openCreatePost : null,
                    onToggleTheme: widget.onToggleTheme,
                    isDarkMode: widget.isDarkMode,
                  ),

                  // Active Screen Content
                  Expanded(
                    child: IndexedStack(
                      index: _currentIndex,
                      children: [
                        ForumScreen(
                          activeAlias: widget.activeAlias,
                          onAliasChanged: widget.onAliasChanged,
                          onToggleTheme: widget.onToggleTheme,
                          isDarkMode: widget.isDarkMode,
                          activeChannel: _activeChannel,
                          activeServer: _activeServer,
                          onChannelChanged: _onSelectChannel,
                          activeFeedFilter: _activeFeedFilter,
                          searchQuery: _searchQuery,
                          isEmbeddedInShell: true,
                        ),
                        GroupsScreen(
                          activeAlias: widget.activeAlias,
                          onAliasChanged: widget.onAliasChanged,
                        ),
                        MarketplaceScreen(
                          activeAlias: widget.activeAlias,
                          onAliasChanged: widget.onAliasChanged,
                        ),
                        ProfileScreen(
                          activeAlias: widget.activeAlias,
                          onAliasChanged: widget.onAliasChanged,
                          onToggleTheme: widget.onToggleTheme,
                          isDarkMode: widget.isDarkMode,
                        ),
                        const RulesScreen(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Mobile layout (screens < 768px): clean body with bottom NavigationBar
    return Scaffold(
      backgroundColor: feedBg,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          ForumScreen(
            activeAlias: widget.activeAlias,
            onAliasChanged: widget.onAliasChanged,
            onToggleTheme: widget.onToggleTheme,
            isDarkMode: widget.isDarkMode,
            activeChannel: _activeChannel,
            activeServer: _activeServer,
            onChannelChanged: _onSelectChannel,
            activeFeedFilter: _activeFeedFilter,
            searchQuery: _searchQuery,
            isEmbeddedInShell: false,
          ),
          GroupsScreen(
            activeAlias: widget.activeAlias,
            onAliasChanged: widget.onAliasChanged,
          ),
          MarketplaceScreen(
            activeAlias: widget.activeAlias,
            onAliasChanged: widget.onAliasChanged,
          ),
          ProfileScreen(
            activeAlias: widget.activeAlias,
            onAliasChanged: widget.onAliasChanged,
            onToggleTheme: widget.onToggleTheme,
            isDarkMode: widget.isDarkMode,
          ),
          const RulesScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.forum_outlined),
            selectedIcon: Icon(Icons.forum),
            label: 'Foro',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Grupos',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Marketplace',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
          NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            selectedIcon: Icon(Icons.shield),
            label: 'Normas',
          ),
        ],
      ),
    );
  }
}
