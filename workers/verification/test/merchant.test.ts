import { describe, it, expect, vi, beforeEach } from 'vitest';
import { handleAdminReviewMerchant } from '../src/handlers/merchant-review';
import { handleGetMerchantDocument } from '../src/handlers/merchant-document';
import type { Env } from '../src/types';

// Mock state hoisted for Vitest
const { mockState } = vi.hoisted(() => ({
  mockState: {
    authUser: { id: 'user-merchant-uuid', is_anonymous: false } as {
      id: string;
      is_anonymous?: boolean;
    } | null,
    userRole: 'admin' as string | null,
    rpcCalls: [] as Array<{ name: string; params: Record<string, unknown> }>,
    rpcHandler: null as
      | null
      | ((name: string, params: Record<string, unknown>) => Promise<{ data: unknown; error: unknown }>),
    rpcResponse: {
      data: { ok: true, status: 'manual_review', request_id: 'uuid-123' },
      error: null,
    } as { data: unknown; error: unknown },
    merchantRecord: null as Record<string, unknown> | null,
  },
}));

vi.mock('../src/supabase', () => ({
  createAnonClient: () => ({
    auth: {
      getUser: vi.fn(async (token: string) => {
        if (token === 'invalid-token') {
          return { data: { user: null }, error: { message: 'Invalid token' } };
        }
        return { data: { user: mockState.authUser }, error: null };
      }),
    },
  }),
  createServiceClient: () => ({
    rpc: vi.fn(async (name: string, params: Record<string, unknown>) => {
      mockState.rpcCalls.push({ name, params });
      if (mockState.rpcHandler) {
        return mockState.rpcHandler(name, params);
      }
      return mockState.rpcResponse;
    }),
    from: vi.fn((table: string) => ({
      select: vi.fn(() => ({
        eq: vi.fn((col: string, id: string) => ({
          maybeSingle: vi.fn(async () => {
            if (table === 'user_roles') {
              return {
                data: mockState.userRole ? { role: mockState.userRole } : null,
                error: null,
              };
            }
            if (table === 'merchant_verification_requests') {
              if (mockState.merchantRecord) {
                return { data: mockState.merchantRecord, error: null };
              }
              return {
                data: {
                  establishment_key: 'pending/merchant/u1/r1/establishment.webp',
                },
                error: null,
              };
            }
            return { data: null, error: null };
          }),
        })),
      })),
    })),
  }),
}));

// Helper para crear archivos de prueba con magic bytes
function createFakeImage(type: 'jpg' | 'png' | 'webp' | 'fake', size = 64): File {
  let header: number[];
  let mime: string;
  let ext: string;

  if (type === 'jpg') {
    header = [0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10];
    mime = 'image/jpeg';
    ext = 'jpg';
  } else if (type === 'png') {
    header = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
    mime = 'image/png';
    ext = 'png';
  } else if (type === 'webp') {
    header = [
      0x52, 0x49, 0x46, 0x46,
      0x24, 0x00, 0x00, 0x00,
      0x57, 0x45, 0x42, 0x50,
      0x56, 0x50, 0x38, 0x20,
    ];
    mime = 'image/webp';
    ext = 'webp';
  } else {
    header = [0x00, 0x01, 0x02, 0x03];
    mime = 'text/plain';
    ext = 'txt';
  }

  const bytes = new Uint8Array(Math.max(header.length, size));
  bytes.set(header);
  return new File([bytes], `test.${ext}`, { type: mime });
}

describe('5. Handler review-merchant (POST /api/v1/admin/review-merchant)', () => {
  let fakeEnv: Env;
  let deletedKeys: string[];
  let clearedRpcId: string | null;
  let reviewRpcParams: Record<string, unknown> | null;

  beforeEach(() => {
    deletedKeys = [];
    clearedRpcId = null;
    reviewRpcParams = null;
    mockState.authUser = { id: 'staff-user-id', is_anonymous: false };
    mockState.userRole = 'admin';
    mockState.rpcCalls = [];
    mockState.merchantRecord = null;

    mockState.rpcHandler = async (name: string, params: Record<string, unknown>) => {
      if (name === 'admin_review_merchant_verification') {
        reviewRpcParams = params;
        return {
          data: {
            ok: true,
            status: params.p_decision,
            request_id: params.p_request_id,
          },
          error: null,
        };
      }
      if (name === 'admin_clear_merchant_keys') {
        clearedRpcId = params.p_request_id as string;
        return { data: null, error: null };
      }
      return { data: null, error: null };
    };

    fakeEnv = {
      VERIFICATION_BUCKET: {
        delete: vi.fn(async (key: string) => {
          if (key.includes('fail-delete')) {
            throw new Error('R2 delete error');
          }
          deletedKeys.push(key);
        }),
      } as unknown as R2Bucket,
      MAX_FILE_BYTES: '10485760',
      ALLOWED_ORIGINS: '*',
      SUPABASE_URL: 'https://test.supabase.co',
      SUPABASE_ANON_KEY: 'anon-key',
      SUPABASE_SERVICE_ROLE_KEY: 'service-role-key',
    };
  });

  it('deletes establishment_key from R2 and clears DB keys when approved by staff', async () => {
    const req = new Request('https://worker/api/v1/admin/review-merchant', {
      method: 'POST',
      headers: {
        Authorization: 'Bearer staff-jwt',
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        request_id: 'req-uuid-1',
        decision: 'approved',
      }),
    });

    const res = await handleAdminReviewMerchant(req, fakeEnv, {});
    expect(res.status).toBe(200);
    const body = (await res.json()) as { status: string; request_id: string };
    expect(body.status).toBe('approved');

    expect(reviewRpcParams?.p_decision).toBe('approved');
    expect(deletedKeys).toHaveLength(1);
    expect(deletedKeys[0]).toContain('establishment.webp');
    expect(clearedRpcId).toBe('req-uuid-1');
  });

  it('returns 200 (does not fail applied review) and lets cron retry if delete fails in R2', async () => {
    mockState.merchantRecord = {
      establishment_key: 'pending/merchant/u1/r1/fail-delete.webp',
    };

    const req = new Request('https://worker/api/v1/admin/review-merchant', {
      method: 'POST',
      headers: {
        Authorization: 'Bearer staff-jwt',
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        request_id: 'req-fail-delete',
        decision: 'rejected',
        reason: 'Foto ilegible',
      }),
    });

    const res = await handleAdminReviewMerchant(req, fakeEnv, {});
    expect(res.status).toBe(200);
    const body = (await res.json()) as { status: string; request_id: string };
    expect(body.status).toBe('rejected');

    // No debe haber limpiado claves en BD para que el cron reintente
    expect(clearedRpcId).toBeNull();
  });

  it('returns 403 when user is not staff (admin or moderator)', async () => {
    mockState.userRole = 'student';

    const req = new Request('https://worker/api/v1/admin/review-merchant', {
      method: 'POST',
      headers: {
        Authorization: 'Bearer user-jwt',
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        request_id: 'req-uuid-1',
        decision: 'approved',
      }),
    });

    const res = await handleAdminReviewMerchant(req, fakeEnv, {});
    expect(res.status).toBe(403);
    const body = (await res.json()) as { code: string };
    expect(body.code).toBe('not_authorized');
  });
});

describe('6. Handler merchant-document (GET /api/v1/admin/merchant-document)', () => {
  let fakeEnv: Env;

  beforeEach(() => {
    mockState.authUser = { id: 'staff-id', is_anonymous: false };
    mockState.userRole = 'admin';
    mockState.merchantRecord = null;

    fakeEnv = {
      VERIFICATION_BUCKET: {
        get: vi.fn(async (key: string) => {
          if (key === 'missing-in-r2') {
            return null;
          }
          return {
            body: new ReadableStream({
              start(ctrl) {
                ctrl.enqueue(new Uint8Array([0xff, 0xd8, 0xff]));
                ctrl.close();
              },
            }),
            httpMetadata: {
              contentType: 'image/jpeg',
            },
          };
        }),
      } as unknown as R2Bucket,
      MAX_FILE_BYTES: '10485760',
      ALLOWED_ORIGINS: '*',
      SUPABASE_URL: 'https://test.supabase.co',
      SUPABASE_ANON_KEY: 'anon-key',
      SUPABASE_SERVICE_ROLE_KEY: 'service-role-key',
    };
  });

  it('returns document bytes and Content-Type with request_id alone', async () => {
    const req = new Request(
      'https://worker/api/v1/admin/merchant-document?request_id=req-1',
      {
        method: 'GET',
        headers: { Authorization: 'Bearer staff-jwt' },
      }
    );

    const res = await handleGetMerchantDocument(req, fakeEnv, {});
    expect(res.status).toBe(200);
    expect(res.headers.get('Content-Type')).toBe('image/jpeg');
    expect(res.headers.get('Cache-Control')).toBe('no-store');
  });

  it('accepts doc=establishment and serves establishment_key', async () => {
    const req = new Request(
      'https://worker/api/v1/admin/merchant-document?request_id=req-1&doc=establishment',
      {
        method: 'GET',
        headers: { Authorization: 'Bearer staff-jwt' },
      }
    );

    const res = await handleGetMerchantDocument(req, fakeEnv, {});
    expect(res.status).toBe(200);
  });

  it('rejects legacy doc=front or doc=back with 422 invalid_doc', async () => {
    const reqFront = new Request(
      'https://worker/api/v1/admin/merchant-document?request_id=req-1&doc=front',
      {
        method: 'GET',
        headers: { Authorization: 'Bearer staff-jwt' },
      }
    );

    const resFront = await handleGetMerchantDocument(reqFront, fakeEnv, {});
    expect(resFront.status).toBe(422);
    const body = (await resFront.json()) as { code: string };
    expect(body.code).toBe('invalid_doc');

    const reqBack = new Request(
      'https://worker/api/v1/admin/merchant-document?request_id=req-1&doc=back',
      {
        method: 'GET',
        headers: { Authorization: 'Bearer staff-jwt' },
      }
    );

    const resBack = await handleGetMerchantDocument(reqBack, fakeEnv, {});
    expect(resBack.status).toBe(422);
  });

  it('returns 404 when key is null in database (already purged)', async () => {
    mockState.merchantRecord = {
      establishment_key: null,
    };

    const req = new Request(
      'https://worker/api/v1/admin/merchant-document?request_id=req-null-keys',
      {
        method: 'GET',
        headers: { Authorization: 'Bearer staff-jwt' },
      }
    );

    const res = await handleGetMerchantDocument(req, fakeEnv, {});
    expect(res.status).toBe(404);
  });

  it('returns 404 when object is missing in R2 bucket', async () => {
    mockState.merchantRecord = {
      establishment_key: 'missing-in-r2',
    };

    const req = new Request(
      'https://worker/api/v1/admin/merchant-document?request_id=req-missing-file',
      {
        method: 'GET',
        headers: { Authorization: 'Bearer staff-jwt' },
      }
    );

    const res = await handleGetMerchantDocument(req, fakeEnv, {});
    expect(res.status).toBe(404);
  });
});
