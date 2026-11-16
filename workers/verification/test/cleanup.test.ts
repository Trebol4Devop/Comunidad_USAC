import { describe, it, expect, vi } from 'vitest';
import { runCleanup } from '../src/handlers/cleanup';
import type { SupabaseClient } from '@supabase/supabase-js';

describe('runCleanup handler', () => {
  it('deletes objects from R2, nullifies keys in database, continues if one delete fails, and ignores rows without key', async () => {
    const deletedR2Keys: string[] = [];
    const updatedDbRows: Array<{ id: string; update: Record<string, unknown> }> = [];

    // Faux R2Bucket
    const fakeBucket: R2Bucket = {
      delete: vi.fn(async (key: string) => {
        if (key === 'pending/user-fail/fail-req.jpg') {
          throw new Error('R2 storage connection failure');
        }
        deletedR2Keys.push(key);
      }),
    } as unknown as R2Bucket;

    // Faux candidates returned by query
    const mockRows = [
      { id: 'req-1', r2_object_key: 'pending/user-1/req-1.jpg' },
      { id: 'req-2', r2_object_key: 'pending/user-fail/fail-req.jpg' }, // will fail delete
      { id: 'req-3', r2_object_key: 'pending/user-3/req-3.png' },
      { id: 'req-4', r2_object_key: null }, // no key, should be skipped
    ];

    // Faux Supabase Client
    const fakeSupabase = {
      from: vi.fn((table: string) => {
        expect(table).toBe('verification_requests');
        return {
          select: vi.fn(() => ({
            not: vi.fn(() => ({
              or: vi.fn(() => ({
                limit: vi.fn(async () => ({
                  data: mockRows,
                  error: null,
                })),
              })),
            })),
          })),
          update: vi.fn((updatePayload: Record<string, unknown>) => ({
            eq: vi.fn(async (col: string, val: string) => {
              expect(col).toBe('id');
              updatedDbRows.push({ id: val, update: updatePayload });
              return { error: null };
            }),
          })),
        };
      }),
    } as unknown as SupabaseClient;

    const stats = await runCleanup(fakeBucket, fakeSupabase);

    // Scanned count should be 4
    expect(stats.scanned).toBe(4);
    // Deleted count should be 2 (req-1 and req-3 succeeded)
    expect(stats.deleted).toBe(2);
    // Failed count should be 1 (req-2 threw in R2)
    expect(stats.failed).toBe(1);

    // Verify R2 delete calls
    expect(deletedR2Keys).toEqual([
      'pending/user-1/req-1.jpg',
      'pending/user-3/req-3.png',
    ]);

    // Verify DB update calls: only req-1 and req-3 should have had r2_object_key nullified
    expect(updatedDbRows).toHaveLength(2);
    expect(updatedDbRows[0].id).toBe('req-1');
    expect(updatedDbRows[0].update.r2_object_key).toBeNull();
    expect(updatedDbRows[1].id).toBe('req-3');
    expect(updatedDbRows[1].update.r2_object_key).toBeNull();

    // Verify that req-2 was NOT updated because delete failed
    const failedUpdate = updatedDbRows.find((r) => r.id === 'req-2');
    expect(failedUpdate).toBeUndefined();

    // Verify that req-4 (null r2_object_key) was NOT updated or deleted
    const nullKeyUpdate = updatedDbRows.find((r) => r.id === 'req-4');
    expect(nullKeyUpdate).toBeUndefined();
  });

  it('handles database query error gracefully', async () => {
    const fakeBucket: R2Bucket = {
      delete: vi.fn(),
    } as unknown as R2Bucket;

    const fakeSupabase = {
      from: vi.fn(() => ({
        select: vi.fn(() => ({
          not: vi.fn(() => ({
            or: vi.fn(() => ({
              limit: vi.fn(async () => ({
                data: null,
                error: { message: 'Database connection error' },
              })),
            })),
          })),
        })),
      })),
    } as unknown as SupabaseClient;

    const stats = await runCleanup(fakeBucket, fakeSupabase);
    expect(stats.scanned).toBe(0);
    expect(stats.deleted).toBe(0);
    expect(stats.failed).toBe(0);
    expect(fakeBucket.delete).not.toHaveBeenCalled();
  });
});
