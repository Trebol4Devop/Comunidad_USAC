import type { Env } from './types';
import { handleVerifyDocument } from './handlers/verify-document';
import { handleAdminReview } from './handlers/admin-review';
import { handleVerifyMerchant } from './handlers/merchant';
import { handleAdminReviewMerchant } from './handlers/merchant-review';
import { handleGetMerchantDocument } from './handlers/merchant-document';
import { runCleanup } from './handlers/cleanup';
import { createServiceClient } from './supabase';

export function getCorsHeaders(
  request: Request,
  allowedOriginsConfig?: string
): Record<string, string> {
  const origin = request.headers.get('Origin');
  const allowed = (allowedOriginsConfig || '*').split(',').map((s) => s.trim());

  let allowOrigin = '';
  if (allowed.includes('*')) {
    allowOrigin = origin || '*';
  } else if (origin && allowed.includes(origin)) {
    allowOrigin = origin;
  }

  if (!allowOrigin) {
    return {};
  }

  return {
    'Access-Control-Allow-Origin': allowOrigin,
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'authorization, content-type',
    'Access-Control-Max-Age': '86400',
    ...(allowOrigin !== '*' ? { Vary: 'Origin' } : {}),
  };
}

export default {
  async fetch(request: Request, env: Env, _ctx: ExecutionContext): Promise<Response> {
    const corsHeaders = getCorsHeaders(request, env.ALLOWED_ORIGINS);

    // Manejo de preflight CORS
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        status: 204,
        headers: corsHeaders,
      });
    }

    const url = new URL(request.url);
    const pathname = url.pathname;

    try {
      if (pathname === '/api/v1/verify-document' && request.method === 'POST') {
        return await handleVerifyDocument(request, env, corsHeaders);
      }

      if (pathname === '/api/v1/verify-merchant' && request.method === 'POST') {
        return await handleVerifyMerchant(request, env, corsHeaders);
      }

      if (pathname === '/api/v1/admin/review-verification' && request.method === 'POST') {
        return await handleAdminReview(request, env, corsHeaders);
      }

      if (pathname === '/api/v1/admin/review-merchant' && request.method === 'POST') {
        return await handleAdminReviewMerchant(request, env, corsHeaders);
      }

      if (pathname === '/api/v1/admin/merchant-document' && request.method === 'GET') {
        return await handleGetMerchantDocument(request, env, corsHeaders);
      }

      if (pathname === '/api/v1/health' && request.method === 'GET') {
        return new Response(
          JSON.stringify({ status: 'ok', service: 'comunidad-usac-verification' }),
          { status: 200, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
        );
      }

      return new Response(
        JSON.stringify({
          status: 'error',
          code: 'not_found',
          message: `Endpoint ${request.method} ${pathname} not found`,
        }),
        { status: 404, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
      );
    } catch (err) {
      console.error('[worker-error] Unhandled error during request:', err);
      return new Response(
        JSON.stringify({
          status: 'error',
          code: 'internal_server_error',
          message: 'An unexpected internal error occurred',
        }),
        { status: 500, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
      );
    }
  },

  async scheduled(
    _controller: ScheduledController,
    env: Env,
    ctx: ExecutionContext
  ): Promise<void> {
    const supabase = createServiceClient(env);
    ctx.waitUntil(runCleanup(env.VERIFICATION_BUCKET, supabase));
  },
};
