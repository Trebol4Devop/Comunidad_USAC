import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import type { Env } from './types';

/**
 * Cliente Supabase anónimo para validar sesiones de usuario (auth.getUser).
 */
export function createAnonClient(env: Env): SupabaseClient {
  return createClient(env.SUPABASE_URL, env.SUPABASE_ANON_KEY, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });
}

/**
 * Cliente Supabase con privilegios service_role para operaciones administrativas y RPCs seguros.
 */
export function createServiceClient(env: Env): SupabaseClient {
  return createClient(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });
}
