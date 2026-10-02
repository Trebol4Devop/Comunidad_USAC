// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:comunidad_universitaria/core/config/supabase_config.dart';
import 'package:comunidad_universitaria/core/services/supabase_service.dart';
import 'package:comunidad_universitaria/main.dart';

/// Detecta si se pasaron credenciales que apunten al Supabase local
/// mediante --dart-define=SUPABASE_URL=... o variables de entorno.
bool get isLocalSupabaseConfigured {
  const dartDefineUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  const dartDefineKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
  final envUrl = Platform.environment['SUPABASE_URL'] ?? '';
  final envKey = Platform.environment['SUPABASE_ANON_KEY'] ?? '';

  final activeUrl = dartDefineUrl.isNotEmpty ? dartDefineUrl : envUrl;
  final activeKey = dartDefineKey.isNotEmpty ? dartDefineKey : envKey;

  if (activeUrl.isEmpty || activeKey.isEmpty) return false;

  final uri = Uri.tryParse(activeUrl);
  if (uri == null) return false;

  final host = uri.host.toLowerCase();
  return host == '127.0.0.1' ||
      host == 'localhost' ||
      host == '10.0.2.2' ||
      host == '0.0.0.0' ||
      host == 'supabase' ||
      host.endsWith('.internal');
}

String get localSupabaseUrl {
  const dartDefineUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  return dartDefineUrl.isNotEmpty ? dartDefineUrl : (Platform.environment['SUPABASE_URL'] ?? '');
}

String get localSupabaseAnonKey {
  const dartDefineKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
  return dartDefineKey.isNotEmpty ? dartDefineKey : (Platform.environment['SUPABASE_ANON_KEY'] ?? '');
}

const String backendSkipReason =
    'Omitido: Flujo E2E real requiere backend local Supabase configurado vía --dart-define=SUPABASE_URL=http://127.0.0.1:54321 y SUPABASE_ANON_KEY=...';

/// Helper para inicializar el entorno y montar la aplicación en los tests E2E.
Future<void> launchApp(
  WidgetTester tester, {
  String initialAlias = 'Estudiante USAC #42',
  String? initialRoute,
  Size? surfaceSize,
}) async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  if (surfaceSize != null) {
    tester.view.physicalSize = surfaceSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  SharedPreferences.setMockInitialValues({
    'student_alias': initialAlias,
  });

  if (isLocalSupabaseConfigured) {
    try {
      final client = SupabaseClient(localSupabaseUrl, localSupabaseAnonKey);

      // Autenticar el usuario E2E sembrado en supabase/seed.sql. Sin sesión, las
      // escrituras llegan como rol anon y chocan con las políticas RLS
      // (auth.uid() = user_id). El usuario sembrado tiene un perfil creado por
      // el trigger on_auth_user_created.
      if (client.auth.currentSession == null) {
        await client.auth.signInWithPassword(
          email: 'e2e@test.com',
          password: 'password123',
        );
      }

      SupabaseService.debugClient = client;
      SupabaseService.debugUserId =
          client.auth.currentUser?.id ?? '00000000-0000-0000-0000-000000000001';
      SupabaseConfig.debugOverrideConfigured = true;
    } catch (e) {
      debugPrint('E2E: no se pudo autenticar el usuario local de prueba: $e');
      SupabaseConfig.debugOverrideConfigured = false;
    }
  } else {
    // Modo invitado / sin backend para tests offline
    SupabaseConfig.debugOverrideConfigured = false;
  }

  final app = ComunidadUSACApp(initialAlias: initialAlias);

  await tester.pumpWidget(app);
  await tester.pumpAndSettle();

  if (initialRoute != null && initialRoute.isNotEmpty) {
    final navState = tester.state<NavigatorState>(find.byType(Navigator).first);
    navState.pushNamed(initialRoute);
    await tester.pumpAndSettle();
  }
}
