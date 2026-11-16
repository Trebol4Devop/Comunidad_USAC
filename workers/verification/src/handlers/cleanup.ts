import type { SupabaseClient } from '@supabase/supabase-js';

export interface CleanupStats {
  scanned: number;
  deleted: number;
  failed: number;
}

interface CleanupCandidate {
  id: string;
  r2_object_key: string | null;
}

/**
 * Tarea periódica de limpieza (cron cada 6 h):
 * - Selecciona hasta 100 filas con r2_object_key IS NOT NULL y (status in ('approved','rejected') o expires_at < now())
 * - Procesa en lotes de 5 con Promise.allSettled
 * - Por fila: bucket.delete(key); si OK, r2_object_key = NULL y updated_at
 * - Idempotente, sin logging de PII (carné, email, CUI o texto OCR).
 */
export async function runCleanup(
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
    console.error(`[cleanup] Error querying cleanup candidates: ${error.message}`);
    return stats;
  }

  const rows = (data || []) as CleanupCandidate[];
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

  console.log(
    `[cleanup] Run finished: scanned=${stats.scanned}, deleted=${stats.deleted}, failed=${stats.failed}`
  );
  return stats;
}
