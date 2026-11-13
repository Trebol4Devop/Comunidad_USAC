import 'dart:ui';

import 'package:flutter/material.dart';
import 'core/config/app_theme.dart';
import 'core/config/supabase_config.dart';
import 'core/services/local_storage_service.dart';
import 'features/construction/screens/under_construction_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase client
  await SupabaseConfig.initialize();

  // Load theme preference
  final initialIsDarkMode = await LocalStorageService.isDarkMode();

  runApp(
    ComunidadUSACApp(
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
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.initialIsDarkMode ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> _toggleTheme() async {
    final nextMode = _themeMode == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    setState(() => _themeMode = nextMode);
    await LocalStorageService.saveThemeMode(nextMode == ThemeMode.dark);
  }

  Route<dynamic> _onGenerateRoute(RouteSettings settings) {
    // Rama provisional para pre-despliegue:
    // Todas las rutas redirigen estrictamente a UnderConstructionScreen.
    // No se expone ninguna función implementada de la aplicación y la
    // verificación en 2 pasos de la app se encuentra retirada.
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
      title: 'Comunidad Universitaria - Sitio en Construcción',
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
