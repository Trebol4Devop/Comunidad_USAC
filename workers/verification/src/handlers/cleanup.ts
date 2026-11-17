import type { SupabaseClient } from '@supabase/supabase-js';

export interface CleanupStats {
  scanned: number;
  deleted: number;
  failed: number;
}

interface StudentCleanupCandidate {
  id: string;
  r2_object_key: string | null;
}

interface MerchantCleanupCandidate {
  id: string;
  user_id: string | null;
  status: string;
  expires_at: string;
  establishment_key: string | null;
}

/**
 * Limpieza de solicitudes de verificación de estudiantes (Fase 1).
 */
export async function cleanStudentRequests(
  bucket: R2Bucket,
  supabase: SupabaseClient
): Promise<CleanupStats> {
  const stats: CleanupStats = {
    scanned: 0,
    deleted: 0,
    failed: 0,
  };

  const nowIso = new Date().toISOString();

  const { data, error } = await supabase
    .from('verification_requests')
    .select('id, r2_object_key')
    .not('r2_object_key', 'is', null)
    .or(`status.in.(approved,rejected),expires_at.lt.${nowIso}`)
    .limit(100);

  if (error) {
    console.error(`[cleanup] Error querying student cleanup candidates: ${error.message}`);
    return stats;
  }

  const rows = (data || []) as StudentCleanupCandidate[];
  stats.scanned = rows.length;

  if (rows.length === 0) {
    return stats;
  }

  const batchSize = 5;
  for (let i = 0; i < rows.length; i += batchSize) {
    const chunk = rows.slice(i, i + batchSize);

    await Promise.allSettled(
      chunk.map(async (row) => {
        if (!row.r2_object_key) {
          return;
        }

        try {
          await bucket.delete(row.r2_object_key);

          const { error: updateErr } = await supabase
            .from('verification_requests')
            .update({
              r2_object_key: null,
              updated_at: new Date().toISOString(),
            })
            .eq('id', row.id);

          if (updateErr) {
            stats.failed++;
            console.error(`[cleanup] Failed to nullify r2_object_key for request id: ${row.id}`);
          } else {
            stats.deleted++;
          }
        } catch {
          stats.failed++;
          console.error(`[cleanup] Failed to delete R2 object for request id: ${row.id}`);
        }
      })
    );
  }

  return stats;
}

/**
 * Limpieza de solicitudes de verificación de comerciantes (Zero-PII):
 * - Filas con establishment_key no nulo y (status in ('approved','rejected') o expires_at < now() o user_id IS NULL)
 * - Límite 100
 * - Expiración de pendientes: status='rejected', rejection_reason='expired', y seller_verification_status='rejected' en profiles
 * - Borrar establishment_key de R2; si OK -> admin_clear_merchant_keys
 * - Si falla R2 -> no limpiar clave en BD (el cron reintenta en la siguiente ejecución)
 * - Lotes de 5, idempotente, sin logging de claves (solo request_id)
 */
export async function cleanMerchantRequests(
  bucket: R2Bucket,
  supabase: SupabaseClient
): Promise<CleanupStats> {
  const stats: CleanupStats = {
    scanned: 0,
    deleted: 0,
    failed: 0,
  };

  const nowIso = new Date().toISOString();

  const { data, error } = await supabase
    .from('merchant_verification_requests')
    .select('id, user_id, status, expires_at, establishment_key')
    .not('establishment_key', 'is', null)
    .or(`status.in.(approved,rejected),expires_at.lt.${nowIso},user_id.is.null`)
    .limit(100);

  if (error) {
    console.error(`[cleanup-merchant] Error querying cleanup candidates: ${error.message}`);
    return stats;
  }

  const rows = (data || []) as MerchantCleanupCandidate[];
  stats.scanned = rows.length;

  if (rows.length === 0) {
    return stats;
  }

  const batchSize = 5;
  for (let i = 0; i < rows.length; i += batchSize) {
    const chunk = rows.slice(i, i + batchSize);

    await Promise.allSettled(
      chunk.map(async (row) => {
        // 1. Expiración de solicitudes pendientes si expires_at < now
        const isExpiredPending =
          row.status === 'pending' && new Date(row.expires_at).getTime() < Date.now();

        if (isExpiredPending) {
          const updateTimestamp = new Date().toISOString();

          await supabase
            .from('merchant_verification_requests')
            .update({
              status: 'rejected',
              rejection_reason: 'expired',
              updated_at: updateTimestamp,
            })
            .eq('id', row.id);

          if (row.user_id) {
            await supabase
              .from('profiles')
              .update({
                seller_verification_status: 'rejected',
                updated_at: updateTimestamp,
              })
              .eq('id', row.user_id)
              .eq('seller_verification_status', 'pending');
          }

          await supabase
            .from('moderation_jobs')
            .update({
              status: 'done',
              updated_at: updateTimestamp,
            })
            .match({
              entity_table: 'merchant_verification_requests',
              entity_id: row.id,
            });
        }

        // 2. Si no tiene clave, no hay nada que borrar en R2
        if (!row.establishment_key) {
          return;
        }

        // 3. Borrar la clave de R2
        try {
          await bucket.delete(row.establishment_key);
        } catch {
          stats.failed++;
          console.error(
            `[cleanup-merchant] Failed to delete R2 object for request id: ${row.id}`
          );
          return;
        }

        // 4. Si fue eliminada de R2 con éxito, limpiar clave en BD
        const { error: clearErr } = await supabase.rpc('admin_clear_merchant_keys', {
          p_request_id: row.id,
        });

        if (clearErr) {
          // Fallback con update directo si la RPC falla
          const { error: updateErr } = await supabase
            .from('merchant_verification_requests')
            .update({
              establishment_key: null,
              updated_at: new Date().toISOString(),
            })
            .eq('id', row.id);

          if (updateErr) {
            stats.failed++;
            console.error(
              `[cleanup-merchant] Failed to clear key for request id: ${row.id}`
            );
            return;
          }
        }

        stats.deleted++;
      })
    );
  }

  return stats;
}

/**
 * Tarea periódica de limpieza (cron cada 6 h):
 * Procesa ambas tablas: verification_requests y merchant_verification_requests.
 */
export async function runCleanup(
  bucket: R2Bucket,
  supabase: SupabaseClient
): Promise<CleanupStats> {
  const studentStats = await cleanStudentRequests(bucket, supabase);
  const merchantStats = await cleanMerchantRequests(bucket, supabase);

  const combinedStats: CleanupStats = {
    scanned: studentStats.scanned + merchantStats.scanned,
    deleted: studentStats.deleted + merchantStats.deleted,
    failed: studentStats.failed + merchantStats.failed,
  };

  console.log(
    `[cleanup] Run finished: scanned=${combinedStats.scanned}, deleted=${combinedStats.deleted}, failed=${combinedStats.failed}`
  );

  return combinedStats;
}
