import 'package:flutter/material.dart';
import 'core/config/app_theme.dart';
import 'core/config/supabase_config.dart';
import 'core/services/local_storage_service.dart';
import 'core/services/supabase_service.dart';
import 'features/navigation/app_shell.dart';

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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Comunidad USAC',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      home: AppShell(
        activeAlias: _activeAlias,
        onAliasChanged: _updateAlias,
        onToggleTheme: _toggleTheme,
        isDarkMode: _themeMode == ThemeMode.dark,
      ),
    );
  }
}
