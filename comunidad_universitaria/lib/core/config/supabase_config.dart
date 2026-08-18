import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl = 'https://hfvsstkfqszpjrsrwhql.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhmdnNzdGtmcXN6cGpyc3J3aHFsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM1NDQzOTgsImV4cCI6MjA5OTEyMDM5OH0.Ne5vvKXWsKSv_hbYMeV9NOpiOgIcsOzYjz8xKshhn60';

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      !supabaseUrl.contains('tu-proyecto');

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    if (!isConfigured) return;
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      debug: false,
    );
  }
}
