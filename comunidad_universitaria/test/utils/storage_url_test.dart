import 'package:flutter_test/flutter_test.dart';
import 'package:comunidad_universitaria/core/services/storage_service.dart';

void main() {
  group('StorageService.convertSupabaseUrlToR2', () {
    test('devuelve null si la url es null o vacía', () {
      expect(StorageService.convertSupabaseUrlToR2(null), isNull);
      expect(StorageService.convertSupabaseUrlToR2(''), isNull);
    });

    test('devuelve la URL original sin modificar si ya es de R2 (.workers.dev o r2.cloudflarestorage.com)', () {
      const workerUrl = 'https://comunidad-usac-storage.carlosdelcidramirez.workers.dev/images/listings/foto.png';
      expect(StorageService.convertSupabaseUrlToR2(workerUrl), workerUrl);

      const r2DirectUrl = 'https://r2.cloudflarestorage.com/mi-bucket/foto.png';
      expect(StorageService.convertSupabaseUrlToR2(r2DirectUrl), r2DirectUrl);
    });

    test('convierte URL Supabase con bucket "marketplace/" a ruta relativa en R2', () {
      const supabaseUrl =
          'https://hfvsstkfqszpjrsrwhql.supabase.co/storage/v1/object/public/marketplace/listings/producto123.jpg';
      final r2Url = StorageService.convertSupabaseUrlToR2(supabaseUrl);

      expect(r2Url, isNotNull);
      expect(r2Url, endsWith('/images/listings/producto123.jpg'));
      expect(r2Url, contains('workers.dev'));
    });

    test('convierte URL Supabase con bucket "images/" a ruta relativa en R2', () {
      const supabaseUrl =
          'https://hfvsstkfqszpjrsrwhql.supabase.co/storage/v1/object/public/images/avatars/estudiante.webp';
      final r2Url = StorageService.convertSupabaseUrlToR2(supabaseUrl);

      expect(r2Url, isNotNull);
      expect(r2Url, endsWith('/images/avatars/estudiante.webp'));
    });

    test('convierte URL Supabase con bucket "PEMTREE/" a ruta relativa en R2', () {
      const supabaseUrl =
          'https://hfvsstkfqszpjrsrwhql.supabase.co/storage/v1/object/sign/PEMTREE/pensum/sistemas_2026.pdf?token=abc';
      final r2Url = StorageService.convertSupabaseUrlToR2(supabaseUrl);

      expect(r2Url, isNotNull);
      expect(r2Url, endsWith('/images/pensum/sistemas_2026.pdf'));
    });

    test('devuelve null si no contiene ninguno de los buckets soportados', () {
      const urlUnknownBucket =
          'https://hfvsstkfqszpjrsrwhql.supabase.co/storage/v1/object/public/documentos/archivo.pdf';
      expect(StorageService.convertSupabaseUrlToR2(urlUnknownBucket), isNull);
    });

    test('devuelve null si el bucket es el último segmento sin archivo relativo', () {
      const urlNoFile = 'https://hfvsstkfqszpjrsrwhql.supabase.co/storage/v1/object/public/marketplace';
      expect(StorageService.convertSupabaseUrlToR2(urlNoFile), isNull);
    });
  });
}
