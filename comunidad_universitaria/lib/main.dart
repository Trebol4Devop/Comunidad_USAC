import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'core/config/app_theme.dart';
import 'core/config/supabase_config.dart';
import 'core/services/local_storage_service.dart';
import 'features/navigation/app_shell.dart';
import 'features/onboarding/state/session_controller.dart';
import 'features/onboarding/widgets/auth_gate.dart';
import 'features/sso/screens/sso_authorize_screen.dart';
import 'features/verification/state/verification_controller.dart';
import 'features/verification/widgets/verification_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase client
  await SupabaseConfig.initialize();

  // Load or generate default student pseudonym
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
  final String initialAlias;
  final bool initialIsDarkMode;

  const ComunidadUSACApp({
    super.key,
    required this.initialAlias,
    this.initialIsDarkMode = false,
  });

  @override
  State<ComunidadUSACApp> createState() => _ComunidadUSACAppState();
}

class _ComunidadUSACAppState extends State<ComunidadUSACApp> {
  late String _activeAlias;
  late ThemeMode _themeMode;
  late final SessionController _sessionController;
  late final VerificationController _verificationController;

  @override
  void initState() {
    super.initState();
    _activeAlias = widget.initialAlias;
    _themeMode = widget.initialIsDarkMode ? ThemeMode.dark : ThemeMode.light;
    _sessionController = SessionController()..bootstrap();
    _verificationController = VerificationController()..loadStatus();
  }

  @override
  void dispose() {
    _sessionController.dispose();
    _verificationController.dispose();
    super.dispose();
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

    // In Flutter web, check Uri.base if settings.name is empty or '/'
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

    return MaterialPageRoute(
      builder: (_) => AuthGate(
        sessionController: _sessionController,
        verificationController: _verificationController,
        child: VerificationGate(
          controller: _verificationController,
          child: AppShell(
            activeAlias: _activeAlias,
            onAliasChanged: _updateAlias,
            onToggleTheme: _toggleTheme,
            isDarkMode: _themeMode == ThemeMode.dark,
          ),
        ),
      ),
      settings: settings,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Comunidad Universitaria',
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
