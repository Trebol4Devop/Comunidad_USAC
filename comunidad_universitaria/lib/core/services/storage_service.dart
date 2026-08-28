import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import 'supabase_service.dart';

class StorageService {
  static final ImagePicker _picker = ImagePicker();

  static Future<XFile?> pickSingleImage() async {
    try {
      return await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
    } catch (e) {
      debugPrint('Error seleccionando imagen: $e');
      return null;
    }
  }

  static Future<List<XFile>> pickMultipleImages({int maxImages = 3}) async {
    try {
      final picked = await _picker.pickMultiImage(
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (picked.length > maxImages) {
        return picked.sublist(0, maxImages);
      }
      return picked;
    } catch (e) {
      debugPrint('Error seleccionando múltiples imágenes: $e');
      return [];
    }
  }

  static Future<String?> uploadImageFile(XFile file, {String folder = 'listings'}) async {
    if (!SupabaseConfig.isConfigured) return null;

    try {
      final bytes = await file.readAsBytes();
      final ext = file.name.split('.').last;
      final userId = SupabaseService.currentUserId ?? 'anon';
      final fileName = '$folder/${userId}_${DateTime.now().millisecondsSinceEpoch}_${file.name.replaceAll(RegExp(r'[^a-zA-Z0-9.]'), '_')}';

      await SupabaseConfig.client.storage
          .from('marketplace')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(
              contentType: ext == 'png' ? 'image/png' : (ext == 'webp' ? 'image/webp' : 'image/jpeg'),
              upsert: true,
            ),
          );

      final publicUrl = SupabaseConfig.client.storage
          .from('marketplace')
          .getPublicUrl(fileName);

      return publicUrl;
    } catch (e) {
      debugPrint('Error subiendo imagen a Supabase Storage: $e');
      return null;
    }
  }
}
