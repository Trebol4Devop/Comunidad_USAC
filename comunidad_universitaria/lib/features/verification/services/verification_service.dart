import 'package:flutter/foundation.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/constants/categories.dart';
import '../../../core/services/supabase_service.dart';
import '../utils/verification_validators.dart';

const String workerBaseUrl = String.fromEnvironment(
  'VERIFICATION_WORKER_URL',
  defaultValue: 'https://comunidad-usac-verification.carlosdelcidramirez.workers.dev',
);

/// Servicio de red y comunicación con la base de datos Supabase y el Worker
/// de verificación de documentos estudiantiles USAC.
class VerificationService {
  /// Consulta el estado de verificación actual y metadatos del perfil del usuario.
  Future<Map<String, dynamic>?> fetchVerificationStatus() async {
    if (!SupabaseConfig.isConfigured) return null;
    final uid = SupabaseService.currentUserId;
    if (uid == null) return null;

    try {
      final res = await SupabaseService.client
          .from('profiles')
          .select(
            'is_verified, verified_at, carne_hash, verification_status, verification_method, institutional_email_domain, seller_verification_status',
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

  /// Reclama credenciales estudiantiles (carné) invocando la función RPC
  /// `claim_student_credentials` en PostgreSQL (Zero-PII: sin CUI).
  Future<Map<String, dynamic>> claimCredentials({
    required String carne,
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
