import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'core/config/app_theme.dart';
import 'core/config/supabase_config.dart';
import 'core/services/local_storage_service.dart';
import 'core/services/supabase_service.dart';
import 'features/navigation/app_shell.dart';
import 'features/sso/screens/sso_authorize_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase client
  await SupabaseConfig.initialize();

  // Ensure active session (anonymous or auth user)
  await SupabaseService.ensureSession();

  // Load or generate default student pseudonym
  final initialAlias = await LocalStorageService.getOrGenerateAlias();

  runApp(ComunidadUSACApp(initialAlias: initialAlias));
}

class ComunidadUSACApp extends StatefulWidget {
  final String initialAlias;

  const ComunidadUSACApp({super.key, required this.initialAlias});

  @override
  State<ComunidadUSACApp> createState() => _ComunidadUSACAppState();
}

class _ComunidadUSACAppState extends State<ComunidadUSACApp> {
  late String _activeAlias;
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _activeAlias = widget.initialAlias;
  }

  void _updateAlias(String newAlias) {
    setState(() {
      _activeAlias = newAlias;
    });
  }

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  Route<dynamic> _onGenerateRoute(RouteSettings settings) {
    final rawName = settings.name ?? '';
    Uri? uri = Uri.tryParse(rawName);

    // In Flutter web, check Uri.base if settings.name is empty or '/'
    if ((uri == null || (uri.path != '/auth/authorize' && uri.path != 'auth/authorize')) && kIsWeb) {
      final base = Uri.base;
      if (base.path == '/auth/authorize' || base.path == 'auth/authorize' || base.fragment.contains('auth/authorize')) {
        if (base.fragment.contains('auth/authorize')) {
          final cleanFragment = base.fragment.startsWith('/') ? base.fragment : '/${base.fragment}';
          uri = Uri.tryParse(cleanFragment);
        } else {
          uri = base;
        }
      }
    }

    if (uri != null && (uri.path == '/auth/authorize' || uri.path == 'auth/authorize' || uri.path.endsWith('/auth/authorize'))) {
      final params = Map<String, String>.from(uri.queryParameters);
      if (kIsWeb) {
        Uri.base.queryParameters.forEach((k, v) {
          params.putIfAbsent(k, () => v);
        });
        if (Uri.base.fragment.isNotEmpty) {
          final frag = Uri.tryParse(Uri.base.fragment);
          if (frag != null) {
            frag.queryParameters.forEach((k, v) {
              params.putIfAbsent(k, () => v);
            });
          }
        }
      }

      return MaterialPageRoute(
        builder: (_) => SsoAuthorizeScreen(
          clientId: params['client_id'],
          redirectUri: params['redirect_uri'],
          state: params['state'],
          activeAlias: _activeAlias,
          onAliasChanged: _updateAlias,
        ),
        settings: settings,
      );
    }

    return MaterialPageRoute(
      builder: (_) => AppShell(
        activeAlias: _activeAlias,
        onAliasChanged: _updateAlias,
        onToggleTheme: _toggleTheme,
        isDarkMode: _themeMode == ThemeMode.dark,
      ),
      settings: settings,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Comunidad USAC',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      onGenerateRoute: _onGenerateRoute,
    );
  }
}

