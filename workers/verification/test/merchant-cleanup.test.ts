import { describe, it, expect, vi } from 'vitest';
import { runCleanup } from '../src/handlers/cleanup';
import type { SupabaseClient } from '@supabase/supabase-js';

describe('Merchant Cleanup (runCleanup handler)', () => {
  it('processes both tables, deletes 3 keys, clears DB keys, continues if one fails, and ignores rows without keys', async () => {
    const deletedR2Keys: string[] = [];
    const clearedMerchantReqIds: string[] = [];
    const updatedStudentReqIds: string[] = [];
    const updatedMerchantRows: Array<{ id: string; update: Record<string, unknown> }> = [];
    const updatedProfiles: Array<{ id: string; update: Record<string, unknown> }> = [];
    const updatedJobs: Array<{ id: string; update: Record<string, unknown> }> = [];

    const fakeBucket: R2Bucket = {
      delete: vi.fn(async (key: string) => {
        if (key.includes('fail-delete')) {
          throw new Error('R2 storage connection error');
        }
        deletedR2Keys.push(key);
      }),
    } as unknown as R2Bucket;

    // Candidatos de estudiantes (tabla verification_requests)
    const studentCandidates = [
      { id: 'student-req-1', r2_object_key: 'pending/user-s1/student-1.jpg' },
    ];

    // Candidatos de comerciantes (tabla merchant_verification_requests)
    const pastDate = new Date(Date.now() - 3600 * 1000).toISOString(); // 1 hora atrás
    const futureDate = new Date(Date.now() + 3600 * 1000).toISOString();

    const merchantCandidates = [
      // 1. Solicitud aprobada con 3 claves -> debe borrar 3 y limpiar
      {
        id: 'merchant-req-1',
        user_id: 'user-m1',
        status: 'approved',
        expires_at: futureDate,
        dpi_front_key: 'pending/merchant/user-m1/req-1/dpi_front.jpg',
        dpi_back_key: 'pending/merchant/user-m1/req-1/dpi_back.png',
        establishment_key: 'pending/merchant/user-m1/req-1/establishment.webp',
      },
      // 2. Solicitud con fallo en borrado de 1 clave -> no debe limpiar claves
      {
        id: 'merchant-req-fail',
        user_id: 'user-m2',
        status: 'rejected',
        expires_at: futureDate,
        dpi_front_key: 'pending/merchant/user-m2/req-fail/dpi_front.jpg',
        dpi_back_key: 'pending/merchant/user-m2/req-fail/fail-delete.png', // falla
        establishment_key: 'pending/merchant/user-m2/req-fail/establishment.webp',
      },
      // 3. Solicitud expirada en pending -> debe expirar a rejected, actualizar profiles/moderation_jobs y borrar claves
      {
        id: 'merchant-req-expired',
        user_id: 'user-m3',
        status: 'pending',
        expires_at: pastDate,
        dpi_front_key: 'pending/merchant/user-m3/req-exp/dpi_front.jpg',
        dpi_back_key: 'pending/merchant/user-m3/req-exp/dpi_back.png',
        establishment_key: 'pending/merchant/user-m3/req-exp/establishment.webp',
      },
      // 4. Solicitud sin claves (todas null) -> debe ser ignorada sin errores
      {
        id: 'merchant-req-no-keys',
        user_id: 'user-m4',
        status: 'approved',
        expires_at: futureDate,
        dpi_front_key: null,
        dpi_back_key: null,
        establishment_key: null,
      },
    ];

    const fakeSupabase = {
      from: vi.fn((table: string) => {
        if (table === 'verification_requests') {
          return {
            select: vi.fn(() => ({
              not: vi.fn(() => ({
                or: vi.fn(() => ({
                  limit: vi.fn(async () => ({
                    data: studentCandidates,
                    error: null,
                  })),
                })),
              })),
            })),
            update: vi.fn((updatePayload: Record<string, unknown>) => ({
              eq: vi.fn(async (col: string, val: string) => {
                if (col === 'id') updatedStudentReqIds.push(val);
                return { error: null };
              }),
            })),
          };
        }

        if (table === 'merchant_verification_requests') {
          return {
            select: vi.fn(() => ({
              or: vi.fn(() => ({
                or: vi.fn(() => ({
                  limit: vi.fn(async () => ({
                    data: merchantCandidates,
                    error: null,
                  })),
                })),
              })),
            })),
            update: vi.fn((updatePayload: Record<string, unknown>) => ({
              eq: vi.fn(async (col: string, val: string) => {
                if (col === 'id') {
                  updatedMerchantRows.push({ id: val, update: updatePayload });
                }
                return { error: null };
              }),
            })),
          };
        }

        if (table === 'profiles') {
          return {
            update: vi.fn((updatePayload: Record<string, unknown>) => ({
              eq: vi.fn((col1: string, val1: string) => ({
                eq: vi.fn(async (col2: string, val2: string) => {
                  updatedProfiles.push({
                    id: val1,
                    update: updatePayload,
                  });
                  return { error: null };
                }),
              })),
            })),
          };
        }

        if (table === 'moderation_jobs') {
          return {
            update: vi.fn((updatePayload: Record<string, unknown>) => ({
              match: vi.fn(async (matchPayload: Record<string, unknown>) => {
                updatedJobs.push({
                  id: matchPayload.entity_id as string,
                  update: updatePayload,
                });
                return { error: null };
              }),
            })),
          };
        }

        throw new Error(`Unexpected table: ${table}`);
      }),
      rpc: vi.fn(async (name: string, params: { p_request_id: string }) => {
        if (name === 'admin_clear_merchant_keys') {
          clearedMerchantReqIds.push(params.p_request_id);
          return { error: null };
        }
        return { error: null };
      }),
    } as unknown as SupabaseClient;

    const stats = await runCleanup(fakeBucket, fakeSupabase);

    // 1 estudiante + 4 comerciantes = 5 candidatos escaneados
    expect(stats.scanned).toBe(5);
    // 1 estudiante exitoso + 2 comerciantes exitosos (req-1 y req-expired) = 3
    expect(stats.deleted).toBe(3);
    // 1 comerciante falló (req-fail) = 1
    expect(stats.failed).toBe(1);

    // Verificamos que se borraron las claves en R2
    // Estudiante: 1 clave
    expect(deletedR2Keys).toContain('pending/user-s1/student-1.jpg');
    // Merchant 1: 3 claves
    expect(deletedR2Keys).toContain('pending/merchant/user-m1/req-1/dpi_front.jpg');
    expect(deletedR2Keys).toContain('pending/merchant/user-m1/req-1/dpi_back.png');
    expect(deletedR2Keys).toContain('pending/merchant/user-m1/req-1/establishment.webp');
    // Merchant Expired: 3 claves
    expect(deletedR2Keys).toContain('pending/merchant/user-m3/req-exp/dpi_front.jpg');
    expect(deletedR2Keys).toContain('pending/merchant/user-m3/req-exp/dpi_back.png');
    expect(deletedR2Keys).toContain('pending/merchant/user-m3/req-exp/establishment.webp');

    // Verificamos llamadas a admin_clear_merchant_keys
    expect(clearedMerchantReqIds).toContain('merchant-req-1');
    expect(clearedMerchantReqIds).toContain('merchant-req-expired');
    // La que falló NO debe haber llamado a admin_clear_merchant_keys
    expect(clearedMerchantReqIds).not.toContain('merchant-req-fail');
    // La que no tenía claves NO debe haber llamado a admin_clear_merchant_keys
    expect(clearedMerchantReqIds).not.toContain('merchant-req-no-keys');

    // Verificamos expiración de la solicitud pendiente
    const expiredReqUpdate = updatedMerchantRows.find(
      (r) => r.id === 'merchant-req-expired'
    );
    expect(expiredReqUpdate).toBeDefined();
    expect(expiredReqUpdate?.update.status).toBe('rejected');
    expect(expiredReqUpdate?.update.rejection_reason).toBe('expired');

    // Verificamos actualización de profiles para el usuario expirado
    const profileUpdate = updatedProfiles.find((p) => p.id === 'user-m3');
    expect(profileUpdate).toBeDefined();
    expect(profileUpdate?.update.seller_verification_status).toBe('rejected');

    // Verificamos cierre del moderation_job para la solicitud expirada
    const jobUpdate = updatedJobs.find((j) => j.id === 'merchant-req-expired');
    expect(jobUpdate).toBeDefined();
    expect(jobUpdate?.update.status).toBe('done');
  });
});
