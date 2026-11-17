import type { Env, DocumentType } from '../types';
import { createAnonClient, createServiceClient } from '../supabase';
import {
  detectImageType,
  evaluateApproval,
  validateCarne,
  validateDocumentType,
  validateQrUrl,
} from '../validators';
import { deleteVerificationDocument, uploadVerificationDocument } from '../r2';

export function mapRpcErrorCode(code?: string): { status: number; message: string } {
  switch (code) {
    case 'credential_unavailable':
      return {
        status: 409,
        message: 'Student credentials are unavailable or already claimed',
      };
    case 'rate_limited':
      return {
        status: 429,
        message: 'Too many verification attempts in the last 24 hours. Please wait.',
      };
    case 'invalid_carne':
      return {
        status: 422,
        message: 'Carne format is invalid or year out of range',
      };
    case 'invalid_document_type':
      return {
        status: 422,
        message: 'Invalid document type provided',
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

export async function handleVerifyDocument(
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

  // Las sesiones anónimas no pueden verificar identidad: se exige cuenta real (403 anonymous_not_allowed)
  if (user.is_anonymous === true) {
    return new Response(
      JSON.stringify({
        status: 'error',
        code: 'anonymous_not_allowed',
        message: 'Anonymous sessions cannot submit verification documents',
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

  const fileEntry = formData.get('file');
  const carneEntry = formData.get('carne');
  const docTypeEntry = formData.get('document_type');
  const clientOcrEntry = formData.get('client_ocr_text');
  const qrUrlEntry = formData.get('qr_url');

  if (
    !fileEntry ||
    typeof fileEntry === 'string' ||
    typeof fileEntry.arrayBuffer !== 'function' ||
    !carneEntry ||
    typeof carneEntry !== 'string' ||
    !docTypeEntry ||
    typeof docTypeEntry !== 'string'
  ) {
    return new Response(
      JSON.stringify({
        status: 'error',
        code: 'missing_fields',
        message: 'Missing required fields: file, carne, document_type',
      }),
      { status: 422, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  }

  const carne = carneEntry.trim();
  const documentTypeStr = docTypeEntry.trim();

  // 3. Validaciones de tamaño y formato
  const maxBytes = parseInt(env.MAX_FILE_BYTES || '10485760', 10);
  if (fileEntry.size > maxBytes) {
    return new Response(
      JSON.stringify({
        status: 'error',
        code: 'file_too_large',
        message: `File size exceeds maximum allowed size of ${maxBytes} bytes`,
      }),
      { status: 413, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  }

  const arrayBuffer = await fileEntry.arrayBuffer();
  const bytes = new Uint8Array(arrayBuffer);
  const detectedImage = detectImageType(bytes);

  if (!detectedImage) {
    return new Response(
      JSON.stringify({
        status: 'error',
        code: 'unsupported_media_type',
        message: 'Invalid image format: only JPEG, PNG, and WebP are allowed',
      }),
      { status: 415, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  }

  if (!validateCarne(carne)) {
    return new Response(
      JSON.stringify({
        status: 'error',
        code: 'invalid_carne',
        message: 'Carne must be 9 digits and correspond to a valid matriculation year',
      }),
      { status: 422, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  }

  if (!validateDocumentType(documentTypeStr)) {
    return new Response(
      JSON.stringify({
        status: 'error',
        code: 'invalid_document_type',
        message: 'Invalid document_type provided',
      }),
      { status: 422, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  }
  const documentType = documentTypeStr as DocumentType;

  let cleanQrUrl: string | null = null;
  if (qrUrlEntry != null && typeof qrUrlEntry === 'string' && qrUrlEntry.trim() !== '') {
    cleanQrUrl = qrUrlEntry.trim();
    if (!validateQrUrl(cleanQrUrl)) {
      return new Response(
        JSON.stringify({
          status: 'error',
          code: 'invalid_qr_host',
          message: 'QR URL must be https and belong to usac.edu.gt or its subdomains',
        }),
        { status: 422, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
      );
    }
  }

  // El texto OCR vive estrictamente en memoria: nunca se persiste ni se loguea
  const clientOcrText =
    clientOcrEntry != null && typeof clientOcrEntry === 'string'
      ? clientOcrEntry.slice(0, 20_000)
      : null;

  // 4 & 5. Evaluar reglas de aprobación automática y banderas en memoria
  const evalResult = evaluateApproval({
    ocrText: clientOcrText,
    carne,
    documentType,
    qrUrl: cleanQrUrl,
  });

  const supabaseService = createServiceClient(env);

  // 6. Caso Auto-Aprobado: No subir a R2, descartar imagen en memoria
  if (evalResult.approved) {
    const { data: rpcData, error: rpcErr } = await supabaseService.rpc(
      'admin_create_verification_request',
      {
        p_user_id: user.id,
        p_carne: carne,
        p_document_type: documentType,
        p_r2_object_key: null,
        p_qr_url: cleanQrUrl,
        p_matched_keywords: evalResult.matched_keywords,
        p_matched_carne: evalResult.matched_carne,
        p_matched_current_year: evalResult.matched_current_year,
        p_auto_approved: true,
      }
    );

    if (rpcErr) {
      console.error(`[verify-document] rpc error code=${rpcErr.code ?? 'unknown'}`);
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
      const mapped = mapRpcErrorCode(rpcData?.code);
      return new Response(
        JSON.stringify({
          status: 'error',
          code: rpcData?.code || 'verification_failed',
          message: mapped.message,
        }),
        { status: mapped.status, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
      );
    }

    return new Response(
      JSON.stringify({
        status: 'verified',
        request_id: rpcData.request_id,
      }),
      { status: 200, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  }

  // 7. Caso Revisión Manual (Dudoso):
  // Subir imagen a R2 con clave pending/<userId>/<requestId>.<ext>
  const requestId = crypto.randomUUID();
  const objectKey = `pending/${user.id}/${requestId}.${detectedImage.ext}`;

  try {
    await uploadVerificationDocument(
      env.VERIFICATION_BUCKET,
      objectKey,
      bytes,
      detectedImage.mime
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

  // Invocar RPC con la clave R2 ya generada y las 3 banderas calculadas
  const { data: rpcData, error: rpcErr } = await supabaseService.rpc(
    'admin_create_verification_request',
    {
      p_user_id: user.id,
      p_carne: carne,
      p_document_type: documentType,
      p_r2_object_key: objectKey,
      p_qr_url: cleanQrUrl,
      p_matched_keywords: evalResult.matched_keywords,
      p_matched_carne: evalResult.matched_carne,
      p_matched_current_year: evalResult.matched_current_year,
      p_auto_approved: false,
    }
  );

  // Si el RPC falla o devuelve ok:false -> Compensación: eliminar de R2 antes de responder
  if (rpcErr || !rpcData?.ok) {
    try {
      await deleteVerificationDocument(env.VERIFICATION_BUCKET, objectKey);
    } catch {
      console.error(`[verify-document] compensation delete failed for request: ${requestId}`);
    }

    if (rpcErr) {
      console.error(`[verify-document] rpc error code=${rpcErr.code ?? 'unknown'}`);
      return new Response(
        JSON.stringify({
          status: 'error',
          code: 'rpc_error',
          message: 'Verification service unavailable. Please retry.',
        }),
        { status: 500, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
      );
    }

    const mapped = mapRpcErrorCode(rpcData?.code);
    return new Response(
      JSON.stringify({
        status: 'error',
        code: rpcData?.code || 'verification_failed',
        message: mapped.message,
      }),
      { status: mapped.status, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  }

  return new Response(
    JSON.stringify({
      status: 'manual_review',
      request_id: rpcData.request_id || requestId,
    }),
    { status: 200, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
  );
}
