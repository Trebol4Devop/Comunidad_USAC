import { describe, it, expect, vi, beforeEach } from 'vitest';
import { handleVerifyDocument } from '../src/handlers/verify-document';
import { handleAdminReview } from '../src/handlers/admin-review';
import type { Env } from '../src/types';

// Mock state hoisted for Vitest
const { mockState } = vi.hoisted(() => ({
  mockState: {
    authUser: { id: 'user-student-uuid', is_anonymous: false } as {
      id: string;
      is_anonymous?: boolean;
    } | null,
    userRole: 'admin' as string | null,
    rpcCalls: [] as Array<{ name: string; params: Record<string, unknown> }>,
    rpcHandler: null as
      | null
      | ((name: string, params: Record<string, unknown>) => Promise<{ data: unknown; error: unknown }>),
    rpcResponse: {
      data: { ok: true, status: 'verified', request_id: 'req-student-123' },
      error: null,
    } as { data: unknown; error: unknown },
    verificationRecord: null as Record<string, unknown> | null,
    dbUpdates: [] as Array<{ table: string; id: string; payload: Record<string, unknown> }>,
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
            if (table === 'verification_requests') {
              if (mockState.verificationRecord) {
                return { data: mockState.verificationRecord, error: null };
              }
              return {
                data: {
                  r2_object_key: 'pending/u-1/r-1.jpg',
                },
                error: null,
              };
            }
            return { data: null, error: null };
          }),
        })),
      })),
      update: vi.fn((payload: Record<string, unknown>) => ({
        eq: vi.fn(async (col: string, id: string) => {
          mockState.dbUpdates.push({ table, id, payload });
          return { error: null };
        }),
      })),
    })),
  }),
}));

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

describe('POST /api/v1/verify-document (Student Verification)', () => {
  let fakeEnv: Env;
  let putCalls: Array<{ key: string; contentType?: string }>;
  let deleteCalls: string[];

  const currentYear = new Date().getUTCFullYear();
  const validCarne = '201912345';

  beforeEach(() => {
    putCalls = [];
    deleteCalls = [];
    mockState.authUser = { id: 'user-student-uuid', is_anonymous: false };
    mockState.userRole = 'admin';
    mockState.rpcCalls = [];
    mockState.rpcHandler = null;
    mockState.rpcResponse = {
      data: { ok: true, status: 'verified', request_id: 'req-student-123' },
      error: null,
    };
    mockState.verificationRecord = null;
    mockState.dbUpdates = [];

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

  function createValidFormData(options?: {
    ocrText?: string;
    carne?: string;
    documentType?: string;
    qrUrl?: string;
    cui?: string;
  }): FormData {
    const fd = new FormData();
    fd.append('file', createFakeImage('jpg'));
    fd.append('carne', options?.carne ?? validCarne);
    fd.append('document_type', options?.documentType ?? 'constancia_inscripcion');

    const defaultOcr = `
      UNIVERSIDAD DE SAN CARLOS DE GUATEMALA
      REGISTRO Y ESTADISTICA
      CONSTANCIA DE INSCRIPCION CICLO ${currentYear}
      CARNE: ${options?.carne ?? validCarne}
    `;
    fd.append('client_ocr_text', options?.ocrText ?? defaultOcr);

    if (options?.qrUrl) {
      fd.append('qr_url', options.qrUrl);
    }
    if (options?.cui) {
      fd.append('cui', options.cui);
    }

    return fd;
  }

  it('auto-approves with correct flags and does NOT upload to R2', async () => {
    const formData = createValidFormData();
    const req = new Request('https://worker/api/v1/verify-document', {
      method: 'POST',
      headers: { Authorization: 'Bearer valid-jwt' },
      body: formData,
    });

    const res = await handleVerifyDocument(req, fakeEnv, {});
    expect(res.status).toBe(200);

    const body = (await res.json()) as { status: string; request_id: string };
    expect(body.status).toBe('verified');
    expect(body.request_id).toBe('req-student-123');

    // Cero subidas a R2 en auto-aprobación
    expect(putCalls).toHaveLength(0);

    // RPC llamado con las 3 banderas y SIN p_cui, p_ocr_text, p_ocr_confidence
    expect(mockState.rpcCalls).toHaveLength(1);
    const rpcCall = mockState.rpcCalls[0];
    expect(rpcCall.name).toBe('admin_create_verification_request');
    expect(rpcCall.params.p_user_id).toBe('user-student-uuid');
    expect(rpcCall.params.p_carne).toBe(validCarne);
    expect(rpcCall.params.p_document_type).toBe('constancia_inscripcion');
    expect(rpcCall.params.p_r2_object_key).toBeNull();
    expect(rpcCall.params.p_auto_approved).toBe(true);
    expect(rpcCall.params.p_matched_keywords).toBe(true);
    expect(rpcCall.params.p_matched_carne).toBe(true);
    expect(rpcCall.params.p_matched_current_year).toBe(true);

    // Verificamos que NO se pasen campos prohibidos de PII
    expect(rpcCall.params.p_cui).toBeUndefined();
    expect(rpcCall.params.p_ocr_text).toBeUndefined();
    expect(rpcCall.params.p_ocr_confidence).toBeUndefined();
  });

  it('sends to manual_review and uploads to R2 when flags do not meet auto-approval', async () => {
    mockState.rpcResponse = {
      data: { ok: true, status: 'manual_review', request_id: 'manual-req-456' },
      error: null,
    };

    // OCR con año antiguo -> no auto-aprueba
    const oldYearOcr = `
      UNIVERSIDAD DE SAN CARLOS
      CONSTANCIA DE INSCRIPCION CICLO 2018
      CARNE: ${validCarne}
    `;
    const formData = createValidFormData({ ocrText: oldYearOcr });
    const req = new Request('https://worker/api/v1/verify-document', {
      method: 'POST',
      headers: { Authorization: 'Bearer valid-jwt' },
      body: formData,
    });

    const res = await handleVerifyDocument(req, fakeEnv, {});
    expect(res.status).toBe(200);

    const body = (await res.json()) as { status: string; request_id: string };
    expect(body.status).toBe('manual_review');
    expect(body.request_id).toBe('manual-req-456');

    // Subida a R2 en revisión manual
    expect(putCalls).toHaveLength(1);
    expect(putCalls[0].key).toMatch(/^pending\/user-student-uuid\/[a-f0-9-]+\.jpg$/);

    // RPC con las 3 banderas y clave R2
    expect(mockState.rpcCalls).toHaveLength(1);
    const rpcCall = mockState.rpcCalls[0];
    expect(rpcCall.params.p_auto_approved).toBe(false);
    expect(rpcCall.params.p_r2_object_key).toBe(putCalls[0].key);
    expect(rpcCall.params.p_matched_keywords).toBe(true);
    expect(rpcCall.params.p_matched_carne).toBe(true);
    expect(rpcCall.params.p_matched_current_year).toBe(false);
  });

  it('compensates by deleting R2 object when RPC fails during manual_review', async () => {
    mockState.rpcResponse = {
      data: { ok: false, code: 'rate_limited' },
      error: null,
    };

    const incompleteOcr = `DOCUMENTO DESCONOCIDO`;
    const formData = createValidFormData({ ocrText: incompleteOcr });
    const req = new Request('https://worker/api/v1/verify-document', {
      method: 'POST',
      headers: { Authorization: 'Bearer valid-jwt' },
      body: formData,
    });

    const res = await handleVerifyDocument(req, fakeEnv, {});
    expect(res.status).toBe(429);

    const body = (await res.json()) as { status: string; code: string };
    expect(body.code).toBe('rate_limited');

    // Subió el archivo a R2 y luego lo borró como compensación
    expect(putCalls).toHaveLength(1);
    expect(deleteCalls).toHaveLength(1);
    expect(deleteCalls[0]).toBe(putCalls[0].key);
  });

  it('rejects anonymous sessions with 403 anonymous_not_allowed', async () => {
    mockState.authUser = { id: 'anon-user', is_anonymous: true };

    const formData = createValidFormData();
    const req = new Request('https://worker/api/v1/verify-document', {
      method: 'POST',
      headers: { Authorization: 'Bearer anon-jwt' },
      body: formData,
    });

    const res = await handleVerifyDocument(req, fakeEnv, {});
    expect(res.status).toBe(403);

    const body = (await res.json()) as { status: string; code: string };
    expect(body.code).toBe('anonymous_not_allowed');
    expect(putCalls).toHaveLength(0);
    expect(mockState.rpcCalls).toHaveLength(0);
  });

  it('rejects files with invalid magic bytes with 415 unsupported_media_type', async () => {
    const fd = new FormData();
    fd.append('file', createFakeImage('fake'));
    fd.append('carne', validCarne);
    fd.append('document_type', 'constancia_inscripcion');

    const req = new Request('https://worker/api/v1/verify-document', {
      method: 'POST',
      headers: { Authorization: 'Bearer valid-jwt' },
      body: fd,
    });

    const res = await handleVerifyDocument(req, fakeEnv, {});
    expect(res.status).toBe(415);
    expect(putCalls).toHaveLength(0);
  });

  it('rejects invalid carne format with 422 invalid_carne', async () => {
    const formData = createValidFormData({ carne: '123' });
    const req = new Request('https://worker/api/v1/verify-document', {
      method: 'POST',
      headers: { Authorization: 'Bearer valid-jwt' },
      body: formData,
    });

    const res = await handleVerifyDocument(req, fakeEnv, {});
    expect(res.status).toBe(422);
    const body = (await res.json()) as { code: string };
    expect(body.code).toBe('invalid_carne');
  });

  it('rejects invalid qr_url host with 422 invalid_qr_host', async () => {
    const formData = createValidFormData({ qrUrl: 'https://evil.usac.edu.gt.fake.com' });
    const req = new Request('https://worker/api/v1/verify-document', {
      method: 'POST',
      headers: { Authorization: 'Bearer valid-jwt' },
      body: formData,
    });

    const res = await handleVerifyDocument(req, fakeEnv, {});
    expect(res.status).toBe(422);
    const body = (await res.json()) as { code: string };
    expect(body.code).toBe('invalid_qr_host');
  });
});

describe('POST /api/v1/admin/review-verification (Student Review)', () => {
  let fakeEnv: Env;
  let deletedKeys: string[];

  beforeEach(() => {
    deletedKeys = [];
    mockState.authUser = { id: 'staff-user-id', is_anonymous: false };
    mockState.userRole = 'admin';
    mockState.rpcCalls = [];
    mockState.verificationRecord = { r2_object_key: 'pending/u1/req1.jpg' };
    mockState.dbUpdates = [];

    mockState.rpcHandler = async (name: string, params: Record<string, unknown>) => {
      if (name === 'admin_review_verification') {
        return {
          data: {
            ok: true,
            status: params.p_decision,
            request_id: params.p_request_id,
          },
          error: null,
        };
      }
      return { data: null, error: null };
    };

    fakeEnv = {
      VERIFICATION_BUCKET: {
        delete: vi.fn(async (key: string) => {
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

  it('deletes R2 object and sets r2_object_key to null on staff approval', async () => {
    const req = new Request('https://worker/api/v1/admin/review-verification', {
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

    const res = await handleAdminReview(req, fakeEnv, {});
    expect(res.status).toBe(200);

    const body = (await res.json()) as { status: string; request_id: string };
    expect(body.status).toBe('approved');

    // Se borró de R2
    expect(deletedKeys).toEqual(['pending/u1/req1.jpg']);

    // Se nuleó la clave en Postgres
    expect(mockState.dbUpdates).toHaveLength(1);
    expect(mockState.dbUpdates[0].table).toBe('verification_requests');
    expect(mockState.dbUpdates[0].payload.r2_object_key).toBeNull();
  });

  it('returns 403 when caller is not staff', async () => {
    mockState.userRole = 'student';

    const req = new Request('https://worker/api/v1/admin/review-verification', {
      method: 'POST',
      headers: {
        Authorization: 'Bearer student-jwt',
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        request_id: 'req-uuid-1',
        decision: 'approved',
      }),
    });

    const res = await handleAdminReview(req, fakeEnv, {});
    expect(res.status).toBe(403);
    const body = (await res.json()) as { code: string };
    expect(body.code).toBe('not_authorized');
  });
});
