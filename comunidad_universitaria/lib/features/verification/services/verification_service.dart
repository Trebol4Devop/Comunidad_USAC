import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/config/supabase_config.dart';
import '../../../core/constants/categories.dart';
import '../../../core/services/supabase_service.dart';
import '../models/verification_result.dart';
import '../models/verification_status.dart';
import '../utils/verification_validators.dart';

const String workerBaseUrl = String.fromEnvironment(
  'VERIFICATION_WORKER_URL',
  defaultValue: 'https://comunidad-usac-verification.carlosdelcidramirez.workers.dev',
);

/// Servicio de red y comunicación con la base de datos Supabase y el Worker
/// de verificación de documentos estudiantiles USAC.
class VerificationService {
  final http.Client _httpClient;
  final String _baseUrl;

  VerificationService({
    http.Client? httpClient,
    String? baseUrl,
  })  : _httpClient = httpClient ?? http.Client(),
        _baseUrl = baseUrl ?? workerBaseUrl;

  /// Indica si el endpoint del Worker está habilitado.
  bool get isWorkerConfigured => _baseUrl.trim().isNotEmpty;

  /// Consulta el estado de verificación actual y metadatos del perfil del usuario.
  Future<Map<String, dynamic>?> fetchVerificationStatus() async {
    if (!SupabaseConfig.isConfigured) return null;
    final uid = SupabaseService.currentUserId;
    if (uid == null) return null;

    try {
      final res = await SupabaseService.client
          .from('profiles')
          .select(
            'is_verified, verified_at, cui_hash, carne_hash, verification_status, verification_method, institutional_email_domain',
          )
          .eq('id', uid)
          .maybeSingle();

      if (res == null) return null;
      return Map<String, dynamic>.from(res);
    } catch (e) {
      debugPrint('[VerificationService] Error consultando verification_status: $e');
      return null;
    }
  }

  /// Reclama credenciales estudiantiles (carné y opcionalmente CUI) invocando
  /// la función RPC `claim_student_credentials` en PostgreSQL.
  Future<Map<String, dynamic>> claimCredentials({
    required String carne,
    String? cui,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      return {
        'ok': false,
        'code': 'offline',
        'message': 'Sin conexión al servidor Supabase.',
      };
    }

    final uid = SupabaseService.currentUserId;
    if (uid == null || !SupabaseService.isAuthenticated) {
      return {
        'ok': false,
        'code': 'not_authenticated',
        'message': VerificationValidators.mapErrorCode('not_authenticated'),
      };
    }

    try {
      final params = <String, dynamic>{
        'p_carne': carne.trim(),
      };
      if (cui != null && cui.trim().isNotEmpty) {
        params['p_cui'] = cui.trim();
      }

      final dynamic response = await SupabaseService.client.rpc(
        'claim_student_credentials',
        params: params,
      );

      if (response is Map) {
        final data = Map<String, dynamic>.from(response);
        if (data['ok'] != true) {
          final code = data['code']?.toString();
          data['message'] = VerificationValidators.mapErrorCode(code);
        }
        return data;
      }

      return {
        'ok': false,
        'code': 'unexpected_response',
        'message': 'Respuesta inesperada del servidor.',
      };
    } catch (e) {
      debugPrint('[VerificationService] Error en claim_student_credentials: $e');
      return {
        'ok': false,
        'code': 'network_error',
        'message': VerificationValidators.mapErrorCode('network_error'),
      };
    }
  }

  /// Envía un documento estudiantil al Cloudflare Worker para validación automática o manual.
  /// Contrato §6.1: POST /api/v1/verify-document con multipart/form-data.
  Future<VerificationResult> submitDocument({
    required Uint8List fileBytes,
    required String fileName,
    required String carne,
    required VerificationDocumentType documentType,
    String? cui,
    String? clientOcrText,
    String? qrUrl,
  }) async {
    if (!isWorkerConfigured) {
      return VerificationResult.error(
        code: 'worker_unconfigured',
        message:
            'El servicio de verificación de documentos no está disponible en este momento.',
      );
    }

    final session = SupabaseService.client.auth.currentSession;
    final token = session?.accessToken;
    if (token == null || session?.user.isAnonymous == true) {
      return VerificationResult.error(
        code: 'unauthorized',
        message: VerificationValidators.mapErrorCode('unauthorized'),
      );
    }

    final normalizedCarne = carne.trim();
    if (!VerificationValidators.isValidCarne(normalizedCarne)) {
      return VerificationResult.error(
        code: 'invalid_carne',
        message: VerificationValidators.mapErrorCode('invalid_carne'),
      );
    }

    try {
      final uri = Uri.parse('$_baseUrl/api/v1/verify-document');
      final request = http.MultipartRequest('POST', uri);

      request.headers['Authorization'] = 'Bearer $token';

      request.fields['carne'] = normalizedCarne;
      request.fields['document_type'] = documentType.toDb();

      if (cui != null && cui.trim().isNotEmpty) {
        request.fields['cui'] = cui.trim();
      }
      if (clientOcrText != null && clientOcrText.trim().isNotEmpty) {
        request.fields['client_ocr_text'] = clientOcrText.trim();
      }
      if (qrUrl != null && qrUrl.trim().isNotEmpty) {
        request.fields['qr_url'] = qrUrl.trim();
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: fileName,
        ),
      );

      final streamedResponse = await _httpClient
          .send(request)
          .timeout(const Duration(seconds: 45));

      final response = await http.Response.fromStream(streamedResponse);
      final statusCode = response.statusCode;

      Map<String, dynamic> body = {};
      try {
        if (response.body.isNotEmpty) {
          body = jsonDecode(response.body) as Map<String, dynamic>;
        }
      } catch (_) {
        // En caso de que no sea JSON válido
      }

      final statusStr = body['status']?.toString();
      final code = body['code']?.toString();

      if (statusCode == 200) {
        if (statusStr == 'verified') {
          return VerificationResult.verified(
            requestId: body['request_id']?.toString(),
          );
        } else if (statusStr == 'manual_review') {
          return VerificationResult.manualReview(
            requestId: body['request_id']?.toString(),
          );
        }
      }

      // Códigos de error específicos
      if (statusCode == 409 || code == 'credential_unavailable') {
        return VerificationResult.error(
          code: 'credential_unavailable',
          message: VerificationValidators.mapErrorCode('credential_unavailable'),
        );
      }

      if (statusCode == 429 || code == 'rate_limited') {
        return VerificationResult.error(
          code: 'rate_limited',
          message: 'Demasiados intentos. Espera 24 horas.',
        );
      }

      final effectiveCode = code ?? 'http_$statusCode';
      final message = body['message']?.toString() ??
          VerificationValidators.mapErrorCode(effectiveCode);

      return VerificationResult.error(
        code: effectiveCode,
        message: message,
      );
    } on TimeoutException {
      return VerificationResult.error(
        code: 'network_timeout',
        message:
            'Tiempo de espera agotado al conectar con el servidor de verificación. Por favor intenta de nuevo.',
      );
    } catch (e) {
      debugPrint('[VerificationService] Error enviando documento a Worker: $e');
      return VerificationResult.error(
        code: 'network_error',
        message: VerificationValidators.mapErrorCode('network_error'),
      );
    }
  }

  /// Carga el catálogo de carreras ordenadas alfabéticamente desde `public.carreras`,
  /// o recurre al catálogo estático seguro en caso de fallo.
  Future<List<Map<String, String>>> fetchCarreras() async {
    if (SupabaseConfig.isConfigured) {
      try {
        final res = await SupabaseService.client
            .from('carreras')
            .select('id, nombre, facultad_id')
            .order('nombre', ascending: true);

        if (res.isNotEmpty) {
          return res.map((item) {
            final map = Map<String, dynamic>.from(item as Map);
            return {
              'id': map['id']?.toString() ?? '',
              'nombre': map['nombre']?.toString() ?? '',
              'facultad_id': map['facultad_id']?.toString() ?? '',
            };
          }).toList();
        }
      } catch (e) {
        debugPrint('[VerificationService] Fallback catálogo carreras: $e');
      }
    }

    // Fallback con el catálogo existente en USACConstants
    final fallback = <Map<String, String>>[];
    for (final facultad in USACConstants.facultades) {
      final facId = facultad['id']?.toString() ?? '';
      final carrerasList = facultad['carreras'];
      if (carrerasList is List) {
        for (final item in carrerasList) {
          if (item is Map) {
            final id = item['id']?.toString() ?? '';
            final nombre = item['nombre']?.toString() ?? '';
            if (id.isNotEmpty && id != 'todas') {
              fallback.add({
                'id': id,
                'nombre': nombre,
                'facultad_id': facId,
              });
            }
          }
        }
      }
    }

    fallback.sort((a, b) => (a['nombre'] ?? '').compareTo(b['nombre'] ?? ''));
    return fallback;
  }
}
