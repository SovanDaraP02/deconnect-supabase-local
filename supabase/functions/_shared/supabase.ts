// supabase/functions/_shared/supabase.ts
import { createClient, type SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

/**
 * Service-role Supabase client (bypasses RLS).
 * Use for server-side operations: triggers, background jobs, admin tasks.
 */
export function getServiceClient(): SupabaseClient {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) {
    throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
  }
  return createClient(url, key);
}

/**
 * Creates a Supabase client that inherits the caller's auth context.
 * Use when you need to respect RLS for the requesting user.
 */
export function getAuthClient(req: Request): SupabaseClient {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) {
    throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
  }
  const authHeader = req.headers.get("Authorization") ?? "";
  return createClient(url, key, {
    global: { headers: { Authorization: authHeader } },
  });
}

/**
 * Extracts the Bearer token string from the Authorization header.
 * Returns null if missing or malformed.
 */
export function getBearerToken(req: Request): string | null {
  const auth = req.headers.get("authorization") ?? "";
  const match = auth.match(/^Bearer\s+(.+)$/i);
  return match?.[1] ?? null;
}
