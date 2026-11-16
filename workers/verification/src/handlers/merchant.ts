import type { Env } from '../types';
import { createAnonClient, createServiceClient } from '../supabase';
import { detectImageType } from '../validators';
import {
  validateBusinessName,
  validateDpi,
  validateEstablishmentNote,
} from '../merchant-validators';
import { deleteVerificationDocument, uploadVerificationDocument } from '../r2';

export function mapMerchantRpcErrorCode(code?: string): { status: number; message: string } {
  switch (code) {
    case 'credential_unavailable':
      return {
        status: 409,
        message: 'DPI credentials are unavailable or already claimed',
      };
    case 'rate_limited':
      return {
        status: 429,
        message: 'Too many verification attempts in the last 24 hours. Please wait.',
      };
    case 'invalid_business_name':
      return {
        status: 422,
        message: 'Business name must be between 2 and 80 characters',
      };
    case 'invalid_dpi':
      return {
        status: 422,
        message: 'DPI format is invalid (13 digits, valid department code)',
      };
    case 'invalid_keys':
      return {
        status: 422,
        message: 'Invalid storage object keys',
      };
    case 'not_authorized':
      return {
        status: 403,
        message: 'Caller is not authorized to perform this operation',
      };
    default:
      if (code?.startsWith('invalid_')) {
        return { status: 422, message: `Validation error: ${code}` };
      }
      return { status: 500, message: code || 'Internal database error' };
  }
}

export async function handleVerifyMerchant(
  request: Request,
  env: Env,
  corsHeaders: Record<string, string>
): Promise<Response> {
  // 1. Validar JWT del usuario con cliente anon
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

  // Las sesiones anónimas no pueden verificar comerciantes: se exige cuenta real
  if (user.is_anonymous === true) {
    return new Response(
      JSON.stringify({
        status: 'error',
        code: 'anonymous_not_allowed',
        message: 'Anonymous sessions cannot submit merchant verification requests',
      }),
      { status: 403, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  }

  // 2. Extraer multipart formData
  let formData: FormData;
  try {
    formData = await request.formData();
  } catch {
    return new Response(
      JSON.stringify({
        status: 'error',
        code: 'missing_fields',
        message: 'Invalid multipart/form-data payload',
      }),
      { status: 422, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  }

  const dpiFrontEntry = formData.get('dpi_front');
  const dpiBackEntry = formData.get('dpi_back');
  const establishmentEntry = formData.get('establishment');
  const businessNameEntry = formData.get('business_name');
  const dpiNumberEntry = formData.get('dpi_number');
  const establishmentNoteEntry = formData.get('establishment_note');

  if (
    !dpiFrontEntry ||
    typeof dpiFrontEntry === 'string' ||
    typeof dpiFrontEntry.arrayBuffer !== 'function' ||
    !dpiBackEntry ||
    typeof dpiBackEntry === 'string' ||
    typeof dpiBackEntry.arrayBuffer !== 'function' ||
    !establishmentEntry ||
    typeof establishmentEntry === 'string' ||
    typeof establishmentEntry.arrayBuffer !== 'function' ||
    !businessNameEntry ||
    typeof businessNameEntry !== 'string' ||
    !dpiNumberEntry ||
    typeof dpiNumberEntry !== 'string'
  ) {
    return new Response(
      JSON.stringify({
        status: 'error',
        code: 'missing_fields',
        message:
          'Missing required fields: dpi_front, dpi_back, establishment, business_name, dpi_number',
      }),
      { status: 422, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  }

  // 3. Validar business_name
  const businessName = businessNameEntry.trim();
  if (!validateBusinessName(businessName)) {
    return new Response(
      JSON.stringify({
        status: 'error',
        code: 'invalid_business_name',
        message: 'Business name must be between 2 and 80 characters',
      }),
      { status: 422, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  }

  // 4. Validar dpi_number
  const dpiNumber = dpiNumberEntry.trim();
  if (!validateDpi(dpiNumber)) {
    return new Response(
      JSON.stringify({
        status: 'error',
        code: 'invalid_dpi',
        message:
          'DPI number must be 13 digits with a valid Guatemala department code (01-22)',
      }),
      { status: 422, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  }

  // Validar nota opcional
  let cleanEstablishmentNote: string | null = null;
  if (
    establishmentNoteEntry != null &&
    typeof establishmentNoteEntry === 'string' &&
    establishmentNoteEntry.trim() !== ''
  ) {
    const rawNote = establishmentNoteEntry.trim();
    if (!validateEstablishmentNote(rawNote)) {
      return new Response(
        JSON.stringify({
          status: 'error',
          code: 'invalid_establishment_note',
          message: 'Establishment note must not exceed 160 characters',
        }),
        { status: 422, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
      );
    }
    cleanEstablishmentNote = rawNote;
  }

  // 5. Validar tamaños de archivo
  const maxBytes = parseInt(env.MAX_FILE_BYTES || '10485760', 10);
  if (
    dpiFrontEntry.size > maxBytes ||
    dpiBackEntry.size > maxBytes ||
    establishmentEntry.size > maxBytes
  ) {
    return new Response(
      JSON.stringify({
        status: 'error',
        code: 'file_too_large',
        message: `File size exceeds maximum allowed size of ${maxBytes} bytes`,
      }),
      { status: 413, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  }

  // 6. Leer bytes y detectar tipo MIME por magic bytes
  const frontBuffer = await dpiFrontEntry.arrayBuffer();
  const backBuffer = await dpiBackEntry.arrayBuffer();
  const estBuffer = await establishmentEntry.arrayBuffer();

  const frontBytes = new Uint8Array(frontBuffer);
  const backBytes = new Uint8Array(backBuffer);
  const estBytes = new Uint8Array(estBuffer);

  const detectedFront = detectImageType(frontBytes);
  const detectedBack = detectImageType(backBytes);
  const detectedEst = detectImageType(estBytes);

  if (!detectedFront || !detectedBack || !detectedEst) {
    return new Response(
      JSON.stringify({
        status: 'error',
        code: 'unsupported_media_type',
        message: 'Invalid image format: only JPEG, PNG, and WebP are allowed',
      }),
      { status: 415, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  }

  // 7. Generar UUID y claves R2
  const requestId = crypto.randomUUID();
  const frontKey = `pending/merchant/${user.id}/${requestId}/dpi_front.${detectedFront.ext}`;
  const backKey = `pending/merchant/${user.id}/${requestId}/dpi_back.${detectedBack.ext}`;
  const estKey = `pending/merchant/${user.id}/${requestId}/establishment.${detectedEst.ext}`;

  // 8. Subir las 3 con contentType real; si una falla, compensar borrando las ya subidas
  const filesToUpload = [
    { key: frontKey, bytes: frontBytes, mime: detectedFront.mime },
    { key: backKey, bytes: backBytes, mime: detectedBack.mime },
    { key: estKey, bytes: estBytes, mime: detectedEst.mime },
  ];

  const uploadedKeys: string[] = [];
  let uploadFailed = false;

  for (const item of filesToUpload) {
    try {
      await uploadVerificationDocument(
        env.VERIFICATION_BUCKET,
        item.key,
        item.bytes,
        item.mime
      );
      uploadedKeys.push(item.key);
    } catch {
      uploadFailed = true;
      break;
    }
  }

  if (uploadFailed) {
    // Compensación: borrar las que se hayan alcanzado a subir
    await Promise.allSettled(
      uploadedKeys.map((key) => deleteVerificationDocument(env.VERIFICATION_BUCKET, key))
    );

    return new Response(
      JSON.stringify({
        status: 'error',
        code: 'upload_failed',
        message: 'Failed to upload document images to storage',
      }),
      { status: 500, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  }

  // 9. Invocar RPC administrativa con service_role
  const supabaseService = createServiceClient(env);
  const { data: rpcData, error: rpcErr } = await supabaseService.rpc(
    'admin_create_merchant_verification_request',
    {
      p_request_id: requestId,
      p_user_id: user.id,
      p_business_name: businessName,
      p_dpi_number: dpiNumber,
      p_dpi_front_key: frontKey,
      p_dpi_back_key: backKey,
      p_establishment_key: estKey,
      p_establishment_note: cleanEstablishmentNote,
    }
  );

  // 10. Si RPC falla o rpcData.ok es false: borrar las 3 claves y mapear error
  if (rpcErr || !rpcData?.ok) {
    await Promise.allSettled([
      deleteVerificationDocument(env.VERIFICATION_BUCKET, frontKey),
      deleteVerificationDocument(env.VERIFICATION_BUCKET, backKey),
      deleteVerificationDocument(env.VERIFICATION_BUCKET, estKey),
    ]);

    if (rpcErr) {
      console.error(`[verify-merchant] rpc error code=${rpcErr.code ?? 'unknown'}`);
      return new Response(
        JSON.stringify({
          status: 'error',
          code: 'rpc_error',
          message: 'Verification service unavailable. Please retry.',
        }),
        { status: 500, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
      );
    }

    const mapped = mapMerchantRpcErrorCode(rpcData?.code);
    return new Response(
      JSON.stringify({
        status: 'error',
        code: rpcData?.code || 'verification_failed',
        message: mapped.message,
      }),
      { status: mapped.status, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  }

  // 11. 200 OK con manual_review (nunca se auto-aprueba)
  return new Response(
    JSON.stringify({
      status: 'manual_review',
      request_id: requestId,
    }),
    { status: 200, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
  );
}
