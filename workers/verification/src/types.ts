export interface Env {
  VERIFICATION_BUCKET: R2Bucket;
  MAX_FILE_BYTES: string;
  ALLOWED_ORIGINS: string;
  SUPABASE_URL: string;
  SUPABASE_ANON_KEY: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
}

export type ReviewDecision = 'approved' | 'rejected';

export interface ApiErrorResponse {
  status: 'error';
  code: string;
  message: string;
}

export interface AdminReviewPayload {
  request_id: string;
  decision: ReviewDecision;
  reason?: string;
}

export interface AdminReviewSuccessResponse {
  status: ReviewDecision;
  request_id: string;
}

export interface ImageTypeResult {
  mime: 'image/jpeg' | 'image/png' | 'image/webp';
  ext: 'jpg' | 'png' | 'webp';
}

export interface AdminReviewVerificationRpcResult {
  ok: boolean;
  status?: ReviewDecision;
  request_id?: string;
  code?: string;
}

export type MerchantVerificationStatus = 'pending' | 'approved' | 'rejected';

export type MerchantDocType = 'establishment';

export interface VerifyMerchantSuccessResponse {
  status: 'manual_review';
  request_id: string;
}

export interface AdminMerchantReviewPayload {
  request_id: string;
  decision: ReviewDecision;
  reason?: string;
}

export interface AdminMerchantReviewSuccessResponse {
  status: ReviewDecision;
  request_id: string;
}

export interface MerchantVerificationRequestRow {
  id: string;
  user_id: string | null;
  business_name: string;
  contact_phone_hash: string;
  campus_zone?: string | null;
  establishment_key: string | null;
  establishment_note: string | null;
  status: MerchantVerificationStatus;
  rejection_reason: string | null;
  reviewed_by: string | null;
  reviewed_at: string | null;
  expires_at: string;
  created_at: string;
  updated_at: string;
}
