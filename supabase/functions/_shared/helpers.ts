// supabase/functions/_shared/helpers.ts
import { corsHeaders } from "./cors.ts";

/**
 * Returns a JSON Response with CORS + Content-Type headers.
 */
export function json(
  status: number,
  data: Record<string, unknown>,
): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

/**
 * Handles CORS preflight. Returns a Response for OPTIONS, or null to continue.
 *
 * Usage:
 *   const cors = handleCors(req);
 *   if (cors) return cors;
 */
export function handleCors(req: Request): Response | null {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  return null;
}
