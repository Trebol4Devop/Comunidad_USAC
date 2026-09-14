import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../config/supabase_config.dart';
import 'supabase_service.dart';

class StorageService {
  static final ImagePicker _picker = ImagePicker();

  /// Cloudflare Worker URL for R2 storage operations.
  /// Replace with your deployed Worker URL.
  static const String _workerUrl = String.fromEnvironment(
    'R2_WORKER_URL',
    defaultValue: 'https://comunidad-usac-storage.carlosdelcidramirez.workers.dev',
  );

  static Future<XFile?> pickSingleImage() async {
    try {
      return await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 75,
      );
    } catch (e) {
      debugPrint('Error seleccionando imagen: $e');
      return null;
    }
  }

  static Future<List<XFile>> pickMultipleImages({int maxImages = 3}) async {
    try {
      final picked = await _picker.pickMultiImage(
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 75,
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

  /// Uploads an image file to Cloudflare R2 via the Worker.
  ///
  /// Returns the public URL of the uploaded image.
  static Future<String?> uploadImageFile(XFile file, {String folder = 'listings'}) async {
    if (!SupabaseConfig.isConfigured) return null;

    try {
      final bytes = await file.readAsBytes();
      final ext = file.name.split('.').last;
      final userId = SupabaseService.currentUserId ?? 'anon';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final safeName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9.]'), '_');
      final filename = '${userId}_${timestamp}_$safeName';

      // Determine content type
      final contentType = ext == 'png'
          ? 'image/png'
          : (ext == 'webp' ? 'image/webp' : 'image/jpeg');

      // Step 1: Get presigned upload URL from Worker
      final uploadResponse = await http.post(
        Uri.parse('$_workerUrl/upload'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'folder': folder,
          'filename': filename,
          'contentType': contentType,
        }),
      );

      if (uploadResponse.statusCode != 200) {
        debugPrint('Error getting upload URL: ${uploadResponse.statusCode}');
        return null;
      }

      final uploadData = jsonDecode(uploadResponse.body);
      final uploadUrl = uploadData['uploadUrl'] as String;

      // Step 2: Upload file directly to R2 using presigned URL
      final putResponse = await http.put(
        Uri.parse(uploadUrl),
        headers: {'Content-Type': contentType},
        body: bytes,
      );

      if (putResponse.statusCode != 200) {
        debugPrint('Error uploading to R2: ${putResponse.statusCode}');
        return null;
      }

      // Step 3: Return public URL via Worker
      final publicUrl = '$_workerUrl/images/$folder/$filename';
      return publicUrl;
    } catch (e) {
      debugPrint('Error subiendo imagen a R2: $e');
      return null;
    }
  }

  /// Converts a Supabase Storage URL to an R2 Worker URL.
  ///
  /// Supabase URL format:
  ///   https://hfvsstkfqszpjrsrwhql.supabase.co/storage/v1/object/public/marketplace/forum/file.jpg
  ///   or: https://hfvsstkfqszpjrsrwhql.supabase.co/storage/v1/object/sign/marketplace/forum/file.jpg?token=...
  ///
  /// R2 URL format:
  ///   https://worker-url/images/forum/file.jpg
  static String? convertSupabaseUrlToR2(String? supabaseUrl) {
    if (supabaseUrl == null || supabaseUrl.isEmpty) return null;

    // If already an R2 URL, return as-is
    if (supabaseUrl.contains('.workers.dev') || supabaseUrl.contains('r2.cloudflarestorage.com')) {
      return supabaseUrl;
    }

    try {
      final uri = Uri.parse(supabaseUrl);

      // Extract path after 'marketplace/' or 'images/' or 'PEMTREE/'
      final pathSegments = uri.pathSegments;
      int bucketIndex = -1;

      for (int i = 0; i < pathSegments.length; i++) {
        final seg = pathSegments[i];
        if (seg == 'marketplace' || seg == 'images' || seg == 'PEMTREE') {
          bucketIndex = i;
          break;
        }
      }

      if (bucketIndex == -1 || bucketIndex + 1 >= pathSegments.length) {
        return null;
      }

      // Get the relative path after the bucket name
      final relativePath = pathSegments.sublist(bucketIndex + 1).join('/');
      return '$_workerUrl/images/$relativePath';
    } catch (e) {
      debugPrint('Error converting Supabase URL to R2: $e');
      return null;
    }
  }
}
