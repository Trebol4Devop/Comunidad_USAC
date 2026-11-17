import type { Env } from '../types';
import { createAnonClient, createServiceClient } from '../supabase';
import { detectImageType } from '../validators';
import {
  normalizeContactPhone,
  validateBusinessName,
  validateContactPhone,
  validateEstablishmentNote,
} from '../merchant-validators';
import { deleteVerificationDocument, uploadVerificationDocument } from '../r2';

export function mapMerchantRpcErrorCode(code?: string): { status: number; message: string } {
  switch (code) {
    case 'credential_unavailable':
      return {
        status: 409,
        message: 'Merchant credentials are unavailable or already claimed',
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
    case 'invalid_phone':
      return {
        status: 422,
        message: 'Contact phone must be an 8-digit Guatemala phone number',
      };
    case 'invalid_establishment_key':
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

  const businessNameEntry = formData.get('business_name');
  const contactPhoneEntry = formData.get('contact_phone');
  const establishmentPhotoEntry =
    formData.get('establishment_photo') || formData.get('establishment');
  const establishmentNoteEntry = formData.get('establishment_note');

  if (
    !businessNameEntry ||
    typeof businessNameEntry !== 'string' ||
    !contactPhoneEntry ||
    typeof contactPhoneEntry !== 'string' ||
    !establishmentPhotoEntry ||
    typeof establishmentPhotoEntry === 'string' ||
    typeof establishmentPhotoEntry.arrayBuffer !== 'function'
  ) {
    return new Response(
      JSON.stringify({
        status: 'error',
        code: 'missing_fields',
        message:
          'Missing required fields: business_name, contact_phone, establishment_photo',
      }),
      { status: 422, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  }

  // 3. Validar business_name (2-80 caracteres)
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

  // 4. Validar y normalizar contact_phone (8 dígitos de Guatemala)
  if (!validateContactPhone(contactPhoneEntry)) {
    return new Response(
      JSON.stringify({
        status: 'error',
        code: 'invalid_phone',
        message: 'Contact phone must be an 8-digit Guatemala phone number',
      }),
      { status: 422, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  }
  const normalizedPhone = normalizeContactPhone(contactPhoneEntry);

  // 5. Validar nota opcional (máx 160)
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

  // 6. Validar tamaño de archivo (< 10 MB)
  const maxBytes = parseInt(env.MAX_FILE_BYTES || '10485760', 10);
  if (establishmentPhotoEntry.size > maxBytes) {
    return new Response(
      JSON.stringify({
        status: 'error',
        code: 'file_too_large',
        message: `File size exceeds maximum allowed size of ${maxBytes} bytes`,
      }),
      { status: 413, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  }

  // 7. Leer bytes y detectar tipo MIME por magic bytes
  const estBuffer = await establishmentPhotoEntry.arrayBuffer();
  const estBytes = new Uint8Array(estBuffer);
  const detectedEst = detectImageType(estBytes);

  if (!detectedEst) {
    return new Response(
      JSON.stringify({
        status: 'error',
        code: 'unsupported_media_type',
        message: 'Invalid image format: only JPEG, PNG, and WebP are allowed',
      }),
      { status: 415, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  }

  // 8. Generar UUID y clave R2 para la foto del establecimiento
  const requestId = crypto.randomUUID();
  const establishmentKey = `pending/merchant/${user.id}/${requestId}/establishment.${detectedEst.ext}`;

  // 9. Subir a R2
  try {
    await uploadVerificationDocument(
      env.VERIFICATION_BUCKET,
      establishmentKey,
      estBytes,
      detectedEst.mime
    );
  } catch {
    return new Response(
      JSON.stringify({
        status: 'error',
        code: 'upload_failed',
        message: 'Failed to upload document image to storage',
      }),
      { status: 500, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  }

  // 10. Invocar RPC administrativa con service_role (el RPC realiza el hash del teléfono)
  const supabaseService = createServiceClient(env);
  const { data: rpcData, error: rpcErr } = await supabaseService.rpc(
    'admin_create_merchant_verification_request',
    {
      p_request_id: requestId,
      p_user_id: user.id,
      p_business_name: businessName,
      p_contact_phone: normalizedPhone,
      p_establishment_key: establishmentKey,
      p_establishment_note: cleanEstablishmentNote,
    }
  );

  // 11. Si RPC falla o rpcData.ok es false: compensar borrando de R2 y mapear error
  if (rpcErr || !rpcData?.ok) {
    try {
      await deleteVerificationDocument(env.VERIFICATION_BUCKET, establishmentKey);
    } catch {
      console.error(`[verify-merchant] compensation delete failed for request: ${requestId}`);
    }

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

  // 12. 200 OK con manual_review (nunca se auto-aprueba comerciante)
  return new Response(
    JSON.stringify({
      status: 'manual_review',
      request_id: requestId,
    }),
    { status: 200, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
  );
}
