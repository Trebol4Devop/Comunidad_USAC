import type { Env, AdminMerchantReviewPayload } from '../types';
import { createAnonClient, createServiceClient } from '../supabase';
import { deleteVerificationDocument } from '../r2';

export async function handleAdminReviewMerchant(
  request: Request,
  env: Env,
  corsHeaders: Record<string, string>
): Promise<Response> {
  // 1. Validar JWT de usuario
  const authHeader = request.headers.get('authorization') || '';
  if (!authHeader.toLowerCase().startsWith('bearer ')) {
    return new Response(
      JSON.stringify({
        status: 'error',
        code: 'unauthorized',
        message: 'Missing or invalid Authorization header',
      }),
      { status: 401, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  }

  const token = authHeader.slice(7).trim();
  if (!token) {
    return new Response(
      JSON.stringify({
        status: 'error',
        code: 'unauthorized',
        message: 'Bearer token cannot be empty',
      }),
      { status: 401, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  }

  const supabaseAnon = createAnonClient(env);
  const { data: authData, error: authErr } = await supabaseAnon.auth.getUser(token);
  if (authErr || !authData?.user) {
    return new Response(
      JSON.stringify({
        status: 'error',
        code: 'unauthorized',
        message: 'Invalid or expired authentication session',
      }),
      { status: 401, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  }

  const user = authData.user;
  const supabaseService = createServiceClient(env);

  // 2. Verificar rol en user_roles (solo admin o moderator)
  const { data: roleData, error: roleErr } = await supabaseService
    .from('user_roles')
    .select('role')
    .eq('user_id', user.id)
    .maybeSingle();

  if (roleErr) {
    return new Response(
      JSON.stringify({
        status: 'error',
        code: 'role_check_failed',
        message: 'Failed to verify staff permissions',
      }),
      { status: 500, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  }

  const userRole = roleData?.role;
  if (!userRole || (userRole !== 'admin' && userRole !== 'moderator')) {
    return new Response(
      JSON.stringify({
        status: 'error',
        code: 'not_authorized',
        message: 'Only users with admin or moderator role can review merchant verifications',
      }),
      { status: 403, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  }

  // 3. Parsear y validar payload JSON
  let body: AdminMerchantReviewPayload;
  try {
    body = (await request.json()) as AdminMerchantReviewPayload;
  } catch {
    return new Response(
      JSON.stringify({
        status: 'error',
        code: 'invalid_payload',
        message: 'Invalid or malformed JSON payload',
      }),
      { status: 422, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  }

  const { request_id, decision, reason } = body;
  if (!request_id || typeof request_id !== 'string') {
    return new Response(
      JSON.stringify({
        status: 'error',
        code: 'missing_fields',
        message: 'Field request_id is required and must be a UUID string',
      }),
      { status: 422, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  }

  if (decision !== 'approved' && decision !== 'rejected') {
    return new Response(
      JSON.stringify({
        status: 'error',
        code: 'invalid_decision',
        message: "Decision must be either 'approved' or 'rejected'",
      }),
      { status: 422, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  }

  // 4. Ejecutar RPC admin_review_merchant_verification
  const { data: rpcData, error: rpcErr } = await supabaseService.rpc(
    'admin_review_merchant_verification',
    {
      p_reviewer_id: user.id,
      p_request_id: request_id,
      p_decision: decision,
      p_reason: reason || null,
    }
  );

  if (rpcErr) {
    console.error(`[merchant-review] rpc error code=${rpcErr.code ?? 'unknown'}`);
    return new Response(
      JSON.stringify({
        status: 'error',
        code: 'rpc_error',
        message: 'Verification service unavailable. Please retry.',
      }),
      { status: 500, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  }

  if (!rpcData?.ok) {
    let httpStatus = 500;
    if (rpcData?.code === 'not_authorized') httpStatus = 403;
    else if (rpcData?.code === 'not_found') httpStatus = 404;
    else if (rpcData?.code === 'invalid_decision') httpStatus = 422;

    return new Response(
      JSON.stringify({
        status: 'error',
        code: rpcData?.code || 'review_failed',
        message: `Admin review rejected: ${rpcData?.code}`,
      }),
      { status: httpStatus, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  }

  // 5. Si ok: leer las 3 claves de la solicitud
  const { data: reqRecord, error: fetchErr } = await supabaseService
    .from('merchant_verification_requests')
    .select('dpi_front_key, dpi_back_key, establishment_key')
    .eq('id', request_id)
    .maybeSingle();

  if (fetchErr) {
    console.error(`[merchant-review] error reading merchant keys for request id: ${request_id}`);
  }

  const keysToDelete = [
    reqRecord?.dpi_front_key,
    reqRecord?.dpi_back_key,
    reqRecord?.establishment_key,
  ].filter((key): key is string => Boolean(key));

  let deleteFailed = false;
  for (const key of keysToDelete) {
    try {
      await deleteVerificationDocument(env.VERIFICATION_BUCKET, key);
    } catch {
      deleteFailed = true;
      console.error(
        `[merchant-review] Failed to delete R2 object for request id: ${request_id}`
      );
    }
  }

  // Si alguna falló: no limpiar y responder 502 r2_delete_failed (cron reintentará)
  if (deleteFailed) {
    return new Response(
      JSON.stringify({
        status: 'error',
        code: 'r2_delete_failed',
        message: 'Merchant verification reviewed but failed to delete files from storage',
      }),
      { status: 502, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  }

  // Solo si todas las operaciones de borrado tuvieron éxito:
  if (keysToDelete.length > 0) {
    const { error: clearErr } = await supabaseService.rpc('admin_clear_merchant_keys', {
      p_request_id: request_id,
    });
    if (clearErr) {
      console.error(
        `[merchant-review] error calling admin_clear_merchant_keys for request id: ${request_id}`
      );
    }
  }

  // 6. Respuesta 200
  return new Response(
    JSON.stringify({
      status: decision,
      request_id,
    }),
    { status: 200, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
  );
}
