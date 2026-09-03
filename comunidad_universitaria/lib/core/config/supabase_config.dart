import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl = 'https://hfvsstkfqszpjrsrwhql.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhmdnNzdGtmcXN6cGpyc3J3aHFsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM1NDQzOTgsImV4cCI6MjA5OTEyMDM5OH0.Ne5vvKXWsKSv_hbYMeV9NOpiOgIcsOzYjz8xKshhn60';

  static bool _isInitialized = false;

  static bool get hasCredentials =>
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      !supabaseUrl.contains('tu-proyecto');

  static bool get isConfigured => _isInitialized && hasCredentials;

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    if (!hasCredentials) return;
    try {
      try {
        // If Supabase was already initialized, accessing client won't throw
        final _ = Supabase.instance.client;
        _isInitialized = true;
        return;
      } catch (_) {
        // Supabase.instance not initialized yet, proceed
      }

      await Supabase.initialize(
        url: supabaseUrl,
        // ignore: deprecated_member_use
        anonKey: supabaseAnonKey,
        debug: false,
      );
      _isInitialized = true;
    } catch (e) {
      debugPrint('Aviso: No se pudo conectar con Supabase ($e). Modo local/demostración activado.');
      _isInitialized = false;
    }
  }
}

