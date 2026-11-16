import type { Env } from '../types';
import { createAnonClient, createServiceClient } from '../supabase';
import { validateMerchantDoc } from '../merchant-validators';

export async function handleGetMerchantDocument(
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
        message: 'Only users with admin or moderator role can view merchant documents',
      }),
      { status: 403, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  }

  // 3. Validar query params
  const url = new URL(request.url);
  const requestId = url.searchParams.get('request_id');
  const doc = url.searchParams.get('doc');

  if (!requestId || !doc) {
    return new Response(
      JSON.stringify({
        status: 'error',
        code: 'missing_fields',
        message: 'Query parameters request_id and doc are required',
      }),
      { status: 422, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  }

  if (!validateMerchantDoc(doc)) {
    return new Response(
      JSON.stringify({
        status: 'error',
        code: 'invalid_doc',
        message: "Parameter doc must be 'front', 'back', or 'establishment'",
      }),
      { status: 422, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  }

  // 4. Mapear columna correspondiente
  let keyColumn: 'dpi_front_key' | 'dpi_back_key' | 'establishment_key';
  switch (doc) {
    case 'front':
      keyColumn = 'dpi_front_key';
      break;
    case 'back':
      keyColumn = 'dpi_back_key';
      break;
    case 'establishment':
      keyColumn = 'establishment_key';
      break;
  }

  const { data: record, error: dbErr } = await supabaseService
    .from('merchant_verification_requests')
    .select(keyColumn)
    .eq('id', requestId)
    .maybeSingle();

  if (dbErr) {
    return new Response(
      JSON.stringify({
        status: 'error',
        code: 'database_error',
        message: 'Failed to query merchant verification request',
      }),
      { status: 500, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  }

  if (!record) {
    return new Response(
      JSON.stringify({
        status: 'error',
        code: 'not_found',
        message: 'Merchant verification request not found',
      }),
      { status: 404, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  }

  const objectKey = (record as Record<string, string | null>)[keyColumn];
  if (!objectKey) {
    return new Response(
      JSON.stringify({
        status: 'error',
        code: 'not_found',
        message: 'Document already purged or unavailable',
      }),
      { status: 404, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  }

  // 5. Obtener objeto de R2
  const object = await env.VERIFICATION_BUCKET.get(objectKey);
  if (!object) {
    return new Response(
      JSON.stringify({
        status: 'error',
        code: 'not_found',
        message: 'Document file not found in storage',
      }),
      { status: 404, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  }

  // 6. Devolver respuesta con Content-Type y Cache-Control: no-store
  const headers = new Headers(corsHeaders);
  headers.set(
    'Content-Type',
    object.httpMetadata?.contentType || 'application/octet-stream'
  );
  headers.set('Cache-Control', 'no-store');

  return new Response(object.body, {
    status: 200,
    headers,
  });
}
