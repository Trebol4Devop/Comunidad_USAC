import 'package:flutter/foundation.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/services/supabase_service.dart';

/// Consulta el historial de solicitudes de comerciante.
///
/// El alta de comercios ahora se gestiona por correo con soporte; esta clase
/// solo conserva la lectura del motivo de rechazo de solicitudes históricas.
class MerchantVerificationService {
  const MerchantVerificationService();

  /// Consulta la solicitud más reciente de comerciante para el usuario autenticado.
  /// Se utiliza para mostrar el motivo de rechazo histórico en el Marketplace.
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
      debugPrint(
        '[MerchantVerificationService] Error consultando solicitud reciente',
      );
      return null;
    }
  }
}
