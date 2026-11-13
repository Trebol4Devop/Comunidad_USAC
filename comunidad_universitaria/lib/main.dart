import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'core/config/app_theme.dart';
import 'core/config/supabase_config.dart';
import 'core/services/local_storage_service.dart';
import 'features/construction/screens/under_construction_screen.dart';
import 'features/sso/screens/sso_authorize_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase client
  await SupabaseConfig.initialize();

  // Load preferences
  final initialAlias = await LocalStorageService.getOrGenerateAlias();
  final initialIsDarkMode = await LocalStorageService.isDarkMode();

  runApp(
    ComunidadUSACApp(
      initialAlias: initialAlias,
      initialIsDarkMode: initialIsDarkMode,
    ),
  );
}

class ComunidadUSACApp extends StatefulWidget {
  final String? initialAlias;
  final bool initialIsDarkMode;

  const ComunidadUSACApp({
    super.key,
    this.initialAlias,
    this.initialIsDarkMode = false,
  });

  @override
  State<ComunidadUSACApp> createState() => _ComunidadUSACAppState();
}

class _ComunidadUSACAppState extends State<ComunidadUSACApp> {
  late String _activeAlias;
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _activeAlias = widget.initialAlias ?? 'Estudiante';
    _themeMode = widget.initialIsDarkMode ? ThemeMode.dark : ThemeMode.light;
  }

  void _updateAlias(String newAlias) {
    setState(() {
      _activeAlias = newAlias;
    });
  }

  Future<void> _toggleTheme() async {
    final nextMode = _themeMode == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    setState(() => _themeMode = nextMode);
    await LocalStorageService.saveThemeMode(nextMode == ThemeMode.dark);
  }

  Route<dynamic> _onGenerateRoute(RouteSettings settings) {
    final rawName = settings.name ?? '';
    Uri? uri = Uri.tryParse(rawName);

    // En Flutter web, verificar Uri.base si settings.name está vacío o es '/'
    if ((uri == null ||
            (uri.path != '/auth/authorize' && uri.path != 'auth/authorize')) &&
        kIsWeb) {
      final base = Uri.base;
      if (base.path == '/auth/authorize' ||
          base.path == 'auth/authorize' ||
          base.fragment.contains('auth/authorize')) {
        if (base.fragment.contains('auth/authorize')) {
          final cleanFragment = base.fragment.startsWith('/')
              ? base.fragment
              : '/${base.fragment}';
          uri = Uri.tryParse(cleanFragment);
        } else {
          uri = base;
        }
      }
    }

    // Ruta SSO para PEMTREE: permite autenticar usuarios exclusivamente con Google y sin 2FA
    if (uri != null &&
        (uri.path == '/auth/authorize' ||
            uri.path == 'auth/authorize' ||
            uri.path.endsWith('/auth/authorize'))) {
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

    // Para cualquier otra ruta de la aplicación: muestra estrictamente el Sitio en Construcción
    return MaterialPageRoute(
      builder: (_) => UnderConstructionScreen(
        onToggleTheme: _toggleTheme,
        isDarkMode: _themeMode == ThemeMode.dark,
      ),
      settings: settings,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Comunidad Zanate - Sitio en Construcción',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      scrollBehavior: const AppScrollBehavior(),
      onGenerateRoute: _onGenerateRoute,
    );
  }
}

/// Permite scroll fluido con mouse (drag & wheel), touch, trackpad y stylus en todas las interfaces
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
  };
}
