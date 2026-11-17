import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/config/supabase_config.dart';
import '../../../core/services/supabase_service.dart';
import '../models/merchant_verification_result.dart';
import 'verification_service.dart';

/// Servicio de verificación de comerciantes del campus USAC.
/// Conecta con el endpoint `POST /api/v1/verify-merchant` del Cloudflare Worker
/// y gestiona consultas a `merchant_verification_requests` en Supabase.
///
/// Especificación normativa: docs/verification/merchant-contract.md §3.1.
class MerchantVerificationService {
  final http.Client _httpClient;
  final String _baseUrl;
  late final String? Function()? _tokenProvider;
  late final bool Function()? _isAnonymousProvider;

  MerchantVerificationService({
    http.Client? httpClient,
    String? baseUrl,
    String? Function()? tokenProvider,
    bool Function()? isAnonymousProvider,
  })  : _httpClient = httpClient ?? http.Client(),
        _baseUrl = baseUrl ?? workerBaseUrl {
    _tokenProvider = tokenProvider;
    _isAnonymousProvider = isAnonymousProvider;
  }

  bool get isWorkerConfigured => _baseUrl.trim().isNotEmpty;

  /// Obtiene el token de acceso actual o inyectado para la petición.
  String? _resolveAccessToken() {
    final provider = _tokenProvider;
    if (provider != null) {
      return provider();
    }
    if (!SupabaseConfig.isConfigured) return null;
    return SupabaseService.client.auth.currentSession?.accessToken;
  }

  /// Indica si la sesión actual es anónima.
  bool _resolveIsAnonymous() {
    final anonProvider = _isAnonymousProvider;
    if (anonProvider != null) {
      return anonProvider();
    }
    if (!SupabaseConfig.isConfigured) return true;
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) return true;
    return user.isAnonymous;
  }

  /// Envía la fotografía del establecimiento y datos comerciales al Worker.
  /// Contrato: docs/verification/merchant-contract.md §3.1 (Zero-PII).
  /// Nunca loguea datos personales ni números de teléfono.
  Future<MerchantVerificationResult> submitMerchantVerification({
    required Uint8List establishmentPhoto,
    required String businessName,
    required String contactPhone,
    String? establishmentNote,
  }) async {
    // 1. Validar autenticación real sin tocar la red si es anónimo o no autenticado
    final token = _resolveAccessToken();
    final isAnon = _resolveIsAnonymous();

    if (token == null || token.trim().isEmpty || isAnon) {
      return const MerchantVerificationResult.error(
        code: 'unauthorized',
        message: 'Debes iniciar sesión con una cuenta real para verificar tu identidad.',
      );
    }

    if (!isWorkerConfigured) {
      return const MerchantVerificationResult.error(
        code: 'worker_unconfigured',
        message: 'El servicio de verificación de comerciantes no está disponible en este momento.',
      );
    }

    try {
      final uri = Uri.parse('$_baseUrl/api/v1/verify-merchant');
      final request = http.MultipartRequest('POST', uri);

      request.headers['Authorization'] = 'Bearer ${token.trim()}';

      // Campos de texto
      request.fields['business_name'] = businessName.trim();
      request.fields['contact_phone'] = contactPhone.trim();
      if (establishmentNote != null && establishmentNote.trim().isNotEmpty) {
        request.fields['establishment_note'] = establishmentNote.trim();
      }

      // Archivo binario (fotografía obligatoria del establecimiento)
      request.files.add(
        http.MultipartFile.fromBytes(
          'establishment_photo',
          establishmentPhoto,
          filename: 'establishment_photo.jpg',
        ),
      );

      final streamedResponse = await _httpClient
          .send(request)
          .timeout(const Duration(seconds: 60));

      final response = await http.Response.fromStream(streamedResponse);
      final statusCode = response.statusCode;

      Map<String, dynamic> body = {};
      try {
        if (response.body.isNotEmpty) {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            body = decoded;
          }
        }
      } catch (_) {
        // Respuesta no JSON (ej. error 502 de proxy Cloudflare)
      }

      final code = body['code']?.toString();

      // 200 OK: siempre manual_review para comerciantes
      if (statusCode == 200) {
        return MerchantVerificationResult.manualReview(
          requestId: body['request_id']?.toString(),
        );
      }

      // 409: Credencial no disponible (teléfono duplicado o en uso).
      // Mensaje genérico normativo sin confirmar existencia.
      if (statusCode == 409 || code == 'credential_unavailable') {
        return const MerchantVerificationResult.error(
          code: 'credential_unavailable',
          message: 'No pudimos registrar este teléfono de contacto. Si crees que es un error, contacta soporte.',
        );
      }

      // 429: Rate limit superado
      if (statusCode == 429 || code == 'rate_limited') {
        return const MerchantVerificationResult.error(
          code: 'rate_limited',
          message: 'Demasiados intentos. Espera 24 horas.',
        );
      }

      // 413: Archivo demasiado grande (> 10 MB)
      if (statusCode == 413 || code == 'file_too_large') {
        return const MerchantVerificationResult.error(
          code: 'file_too_large',
          message: 'El archivo supera el tamaño máximo permitido de 10 MB.',
        );
      }

      // 415: Tipo de medio no soportado
      if (statusCode == 415 || code == 'unsupported_media_type') {
        return const MerchantVerificationResult.error(
          code: 'unsupported_media_type',
          message: 'Formato de imagen inválido. Solo se admiten archivos JPEG, PNG y WebP.',
        );
      }

      // 422: Errores de validación de campos
      if (statusCode == 422) {
        String msg = 'Datos de verificación inválidos.';
        if (code == 'invalid_phone') {
          msg = 'El teléfono debe tener 8 dígitos (Guatemala).';
        } else if (code == 'invalid_business_name') {
          msg = 'El nombre del negocio debe tener entre 2 y 80 caracteres.';
        } else if (code == 'invalid_establishment_note') {
          msg = 'La nota de ubicación no debe superar los 160 caracteres.';
        } else if (code == 'missing_fields') {
          msg = 'Faltan campos obligatorios para procesar la verificación.';
        } else if (body['message'] != null) {
          msg = body['message'].toString();
        }
        return MerchantVerificationResult.error(
          code: code ?? 'validation_error',
          message: msg,
        );
      }

      // 401 / 403: No autorizado
      if (statusCode == 401 || statusCode == 403 || code == 'unauthorized' || code == 'anonymous_not_allowed') {
        return const MerchantVerificationResult.error(
          code: 'unauthorized',
          message: 'Debes iniciar sesión con una cuenta real para verificar tu identidad.',
        );
      }

      // 500 y otros códigos de servidor
      final effectiveCode = code ?? 'http_$statusCode';
      final message = body['message']?.toString() ??
          'Ocurrió un error al procesar tu solicitud. Por favor intenta más tarde.';

      return MerchantVerificationResult.error(
        code: effectiveCode,
        message: message,
      );
    } on TimeoutException {
      return const MerchantVerificationResult.error(
        code: 'network_timeout',
        message: 'Tiempo de espera agotado al conectar con el servidor de verificación. Por favor intenta de nuevo.',
      );
    } catch (e) {
      debugPrint('[MerchantVerificationService] Error de red en submitMerchantVerification');
      return const MerchantVerificationResult.error(
        code: 'network_error',
        message: 'No se pudo establecer conexión con el servidor de verificación. Revisa tu conexión a internet e inténtalo de nuevo.',
      );
    }
  }

  /// Consulta la solicitud más reciente de comerciante para el usuario autenticado.
  /// Se utiliza principalmente para extraer el motivo de rechazo en caso de status='rejected'.
  Future<Map<String, dynamic>?> fetchLatestMerchantRequest() async {
    if (!SupabaseConfig.isConfigured) return null;
    final uid = SupabaseService.currentUserId;
    if (uid == null) return null;

    try {
      final res = await SupabaseService.client
          .from('merchant_verification_requests')
          .select('status, rejection_reason, created_at')
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (res == null) return null;
      return Map<String, dynamic>.from(res);
    } catch (e) {
      debugPrint('[MerchantVerificationService] Error consultando solicitud reciente');
      return null;
    }
  }
}
