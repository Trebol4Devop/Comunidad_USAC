import { describe, it, expect, vi, beforeEach } from 'vitest';
import {
  validateDpi,
  validateBusinessName,
  validateMerchantKeys,
  validateMerchantDoc,
} from '../src/merchant-validators';
import { handleVerifyMerchant } from '../src/handlers/merchant';
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
                  dpi_front_key: 'pending/merchant/u1/r1/dpi_front.jpg',
                  dpi_back_key: 'pending/merchant/u1/r1/dpi_back.png',
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

describe('1. validateDpi', () => {
  it('accepts valid 13-digit DPI with department codes 01 to 22', () => {
    // Guatemala (01)
    expect(validateDpi('1234567890101')).toBe(true);
    // Quetzaltenango (09)
    expect(validateDpi('2589631470901')).toBe(true);
    // Jalapa (21), Jutiapa (22)
    expect(validateDpi('9876543212101')).toBe(true);
    expect(validateDpi('9876543212201')).toBe(true);
  });

  it('rejects DPI with department code 00 or 23+', () => {
    expect(validateDpi('1234567890001')).toBe(false);
    expect(validateDpi('1234567892301')).toBe(false);
    expect(validateDpi('1234567899901')).toBe(false);
  });

  it('rejects DPI by length', () => {
    expect(validateDpi('123456789010')).toBe(false); // 12 dígitos
    expect(validateDpi('12345678901011')).toBe(false); // 14 dígitos
    expect(validateDpi('')).toBe(false);
  });

  it('rejects DPI containing letters or special characters', () => {
    expect(validateDpi('12345678901A1')).toBe(false);
    expect(validateDpi('123456789-0101')).toBe(false);
    expect(validateDpi('123456789 0101')).toBe(false);
  });
});

describe('2. validateBusinessName', () => {
  it('rejects 1-character names and names longer than 80 characters', () => {
    expect(validateBusinessName('A')).toBe(false);
    expect(validateBusinessName('A'.repeat(81))).toBe(false);
    expect(validateBusinessName('')).toBe(false);
    expect(validateBusinessName('   ')).toBe(false);
  });

  it('accepts 2-character and 80-character boundary names', () => {
    expect(validateBusinessName('AB')).toBe(true);
    expect(validateBusinessName('A'.repeat(80))).toBe(true);
  });

  it('trims whitespace before checking length', () => {
    expect(validateBusinessName('  Tienda La Esperanza  ')).toBe(true);
    expect(validateBusinessName('   X   ')).toBe(false);
  });
});

describe('3. validateMerchantKeys', () => {
  const userId = 'user-123';
  const requestId = 'req-456';
  const prefix = `pending/merchant/${userId}/${requestId}/`;

  it('accepts 3 distinct non-null keys starting with prefix', () => {
    const keys = {
      dpiFrontKey: `${prefix}dpi_front.jpg`,
      dpiBackKey: `${prefix}dpi_back.png`,
      establishmentKey: `${prefix}establishment.webp`,
    };
    expect(validateMerchantKeys(keys, userId, requestId)).toBe(true);
  });

  it('rejects if keys are identical or duplicated', () => {
    const keys = {
      dpiFrontKey: `${prefix}dpi_front.jpg`,
      dpiBackKey: `${prefix}dpi_front.jpg`,
      establishmentKey: `${prefix}establishment.webp`,
    };
    expect(validateMerchantKeys(keys, userId, requestId)).toBe(false);
  });

  it('rejects if any key is null, empty or does not have prefix', () => {
    expect(
      validateMerchantKeys(
        {
          dpiFrontKey: null,
          dpiBackKey: `${prefix}dpi_back.png`,
          establishmentKey: `${prefix}establishment.webp`,
        },
        userId,
        requestId
      )
    ).toBe(false);

    expect(
      validateMerchantKeys(
        {
          dpiFrontKey: `wrong/path/dpi_front.jpg`,
          dpiBackKey: `${prefix}dpi_back.png`,
          establishmentKey: `${prefix}establishment.webp`,
        },
        userId,
        requestId
      )
    ).toBe(false);
  });

  it('validates document types with validateMerchantDoc', () => {
    expect(validateMerchantDoc('front')).toBe(true);
    expect(validateMerchantDoc('back')).toBe(true);
    expect(validateMerchantDoc('establishment')).toBe(true);
    expect(validateMerchantDoc('other')).toBe(false);
    expect(validateMerchantDoc('')).toBe(false);
  });
});

describe('4. Handler verify-merchant (POST /api/v1/verify-merchant)', () => {
  let fakeEnv: Env;
  let putCalls: Array<{ key: string; contentType?: string }>;
  let deleteCalls: string[];

  beforeEach(() => {
    putCalls = [];
    deleteCalls = [];
    mockState.authUser = { id: 'user-merchant-uuid', is_anonymous: false };
    mockState.userRole = 'admin';
    mockState.rpcCalls = [];
    mockState.rpcHandler = null;
    mockState.rpcResponse = {
      data: { ok: true, status: 'manual_review', request_id: 'uuid-123' },
      error: null,
    };
    mockState.merchantRecord = null;

    fakeEnv = {
      VERIFICATION_BUCKET: {
        put: vi.fn(async (key: string, data: unknown, opts: { httpMetadata?: { contentType?: string } }) => {
          putCalls.push({ key, contentType: opts?.httpMetadata?.contentType });
          return { key } as R2Object;
        }),
        delete: vi.fn(async (key: string) => {
          deleteCalls.push(key);
        }),
        get: vi.fn(),
      } as unknown as R2Bucket,
      MAX_FILE_BYTES: '10485760',
      ALLOWED_ORIGINS: '*',
      SUPABASE_URL: 'https://test.supabase.co',
      SUPABASE_ANON_KEY: 'anon-key',
      SUPABASE_SERVICE_ROLE_KEY: 'service-role-key',
    };
  });

  function createValidFormData(): FormData {
    const fd = new FormData();
    fd.append('dpi_front', createFakeImage('jpg'));
    fd.append('dpi_back', createFakeImage('png'));
    fd.append('establishment', createFakeImage('webp'));
    fd.append('business_name', 'Librería Universitaria');
    fd.append('dpi_number', '1234567890101');
    fd.append('establishment_note', 'Edificio T-1, nivel 2');
    return fd;
  }

  it('exits with manual_review and 3 put calls on success', async () => {
    const formData = createValidFormData();
    const req = new Request('https://worker/api/v1/verify-merchant', {
      method: 'POST',
      headers: { Authorization: 'Bearer valid-jwt' },
      body: formData,
    });

    const res = await handleVerifyMerchant(req, fakeEnv, {});
    expect(res.status).toBe(200);

    const body = (await res.json()) as { status: string; request_id: string };
    expect(body.status).toBe('manual_review');
    expect(body.request_id).toBeDefined();

    // 3 subidas a R2
    expect(putCalls).toHaveLength(3);
    expect(putCalls[0].key).toContain('dpi_front.jpg');
    expect(putCalls[1].key).toContain('dpi_back.png');
    expect(putCalls[2].key).toContain('establishment.webp');

    // 1 llamada RPC con service_role
    expect(mockState.rpcCalls).toHaveLength(1);
    expect(mockState.rpcCalls[0].name).toBe('admin_create_merchant_verification_request');
    expect(mockState.rpcCalls[0].params.p_business_name).toBe('Librería Universitaria');
    expect(mockState.rpcCalls[0].params.p_dpi_number).toBe('1234567890101');
  });

  it('returns 409 and deletes 3 keys when RPC returns credential_unavailable', async () => {
    mockState.rpcResponse = {
      data: { ok: false, code: 'credential_unavailable' },
      error: null,
    };

    const formData = createValidFormData();
    const req = new Request('https://worker/api/v1/verify-merchant', {
      method: 'POST',
      headers: { Authorization: 'Bearer valid-jwt' },
      body: formData,
    });

    const res = await handleVerifyMerchant(req, fakeEnv, {});
    expect(res.status).toBe(409);

    const body = (await res.json()) as { status: string; code: string };
    expect(body.code).toBe('credential_unavailable');

    // Se subieron las 3 y luego se borraron las 3 al fallar la RPC
    expect(putCalls).toHaveLength(3);
    expect(deleteCalls).toHaveLength(3);
  });

  it('returns 429 when RPC returns rate_limited', async () => {
    mockState.rpcResponse = {
      data: { ok: false, code: 'rate_limited' },
      error: null,
    };

    const formData = createValidFormData();
    const req = new Request('https://worker/api/v1/verify-merchant', {
      method: 'POST',
      headers: { Authorization: 'Bearer valid-jwt' },
      body: formData,
    });

    const res = await handleVerifyMerchant(req, fakeEnv, {});
    expect(res.status).toBe(429);
    expect(deleteCalls).toHaveLength(3);
  });

  it('returns 415 without uploading to R2 when an image has invalid MIME bytes', async () => {
    const formData = new FormData();
    formData.append('dpi_front', createFakeImage('fake'));
    formData.append('dpi_back', createFakeImage('png'));
    formData.append('establishment', createFakeImage('webp'));
    formData.append('business_name', 'Tienda');
    formData.append('dpi_number', '1234567890101');

    const req = new Request('https://worker/api/v1/verify-merchant', {
      method: 'POST',
      headers: { Authorization: 'Bearer valid-jwt' },
      body: formData,
    });

    const res = await handleVerifyMerchant(req, fakeEnv, {});
    expect(res.status).toBe(415);
    expect(putCalls).toHaveLength(0);
  });

  it('returns 403 anonymous_not_allowed for anonymous sessions', async () => {
    mockState.authUser = { id: 'anon-user', is_anonymous: true };

    const formData = createValidFormData();
    const req = new Request('https://worker/api/v1/verify-merchant', {
      method: 'POST',
      headers: { Authorization: 'Bearer anon-jwt' },
      body: formData,
    });

    const res = await handleVerifyMerchant(req, fakeEnv, {});
    expect(res.status).toBe(403);
    const body = (await res.json()) as { code: string };
    expect(body.code).toBe('anonymous_not_allowed');
    expect(putCalls).toHaveLength(0);
  });

  it('returns 500 upload_failed and compensates by deleting already uploaded files if one upload fails', async () => {
    let callCount = 0;
    fakeEnv.VERIFICATION_BUCKET.put = vi.fn(async (key: string) => {
      callCount++;
      if (callCount === 2) {
        throw new Error('R2 Network Failure on 2nd upload');
      }
      putCalls.push({ key });
      return { key } as R2Object;
    });

    const formData = createValidFormData();
    const req = new Request('https://worker/api/v1/verify-merchant', {
      method: 'POST',
      headers: { Authorization: 'Bearer valid-jwt' },
      body: formData,
    });

    const res = await handleVerifyMerchant(req, fakeEnv, {});
    expect(res.status).toBe(500);
    const body = (await res.json()) as { code: string };
    expect(body.code).toBe('upload_failed');

    expect(deleteCalls).toHaveLength(1);
    expect(deleteCalls[0]).toContain('dpi_front.jpg');
    expect(mockState.rpcCalls).toHaveLength(0);
  });
});

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

  it('deletes 3 R2 keys and clears DB keys when approved by staff', async () => {
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
    expect(deletedKeys).toHaveLength(3);
    expect(clearedRpcId).toBe('req-uuid-1');
  });

  it('returns 502 and does NOT clear keys if a delete fails in R2', async () => {
    mockState.merchantRecord = {
      dpi_front_key: 'pending/merchant/u1/r1/dpi_front.jpg',
      dpi_back_key: 'pending/merchant/u1/r1/fail-delete.png',
      establishment_key: 'pending/merchant/u1/r1/establishment.webp',
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
        reason: 'Fotos ilegibles',
      }),
    });

    const res = await handleAdminReviewMerchant(req, fakeEnv, {});
    expect(res.status).toBe(502);
    const body = (await res.json()) as { code: string };
    expect(body.code).toBe('r2_delete_failed');

    // No debe haber limpiado claves en BD
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

  it('returns document bytes and Content-Type with Cache-Control: no-store', async () => {
    const req = new Request(
      'https://worker/api/v1/admin/merchant-document?request_id=req-1&doc=front',
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

  it('returns 404 when key is null in database (already purged)', async () => {
    mockState.merchantRecord = {
      dpi_front_key: null,
      dpi_back_key: null,
      establishment_key: null,
    };

    const req = new Request(
      'https://worker/api/v1/admin/merchant-document?request_id=req-null-keys&doc=front',
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
      dpi_front_key: 'missing-in-r2',
      dpi_back_key: 'valid-key',
      establishment_key: 'valid-key',
    };

    const req = new Request(
      'https://worker/api/v1/admin/merchant-document?request_id=req-missing-file&doc=front',
      {
        method: 'GET',
        headers: { Authorization: 'Bearer staff-jwt' },
      }
    );

    const res = await handleGetMerchantDocument(req, fakeEnv, {});
    expect(res.status).toBe(404);
  });
});
