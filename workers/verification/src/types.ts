export interface Env {
  VERIFICATION_BUCKET: R2Bucket;
  MAX_FILE_BYTES: string;
  ALLOWED_ORIGINS: string;
  SUPABASE_URL: string;
  SUPABASE_ANON_KEY: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
}

export type ReviewDecision = 'approved' | 'rejected';

export interface AdminReviewPayload {
  request_id: string;
  decision: ReviewDecision;
  reason?: string;
}

export interface AdminReviewSuccessResponse {
  status: ReviewDecision;
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
