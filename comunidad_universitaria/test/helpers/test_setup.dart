import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:comunidad_universitaria/core/services/cache_service.dart';
import 'package:comunidad_universitaria/core/services/supabase_service.dart';

/// Namespaces conocidos de CacheService utilizados en la aplicación.
const List<String> kAppCacheNamespaces = [
  'forum_posts',
  'student_groups',
  'marketplace_items',
];

/// Limpia el estado global entre ejecuciones de tests:
/// 1. Resetea SharedPreferences con valores iniciales limpios (o los provistos).
/// 2. Invalida memoria y persistencia de todos los namespaces de CacheService.
/// 3. Resetea las costuras de prueba en SupabaseService y SupabaseConfig.
Future<void> resetTestState({Map<String, Object> initialPrefs = const {}}) async {
  SharedPreferences.setMockInitialValues(Map<String, Object>.from(initialPrefs));
  for (final ns in kAppCacheNamespaces) {
    CacheService.invalidate(ns);
    await CacheService.invalidateAll(ns);
  }
  SupabaseService.resetForTests();
}

/// Helper para configurar el ciclo de vida de un grupo de tests con limpieza
/// en setUp y tearDown.
void setupTestLifecycle({Map<String, Object> initialPrefs = const {}}) {
  setUp(() async {
    await resetTestState(initialPrefs: initialPrefs);
  });

  tearDown(() async {
    await resetTestState();
  });
}
