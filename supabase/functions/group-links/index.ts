// supabase/functions/group-links/index.ts
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type"
};
function json(status, data) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json"
    }
  });
}
function getBearerToken(req) {
  const auth = req.headers.get("authorization") ?? "";
  const m = auth.match(/^Bearer\s+(.+)$/i);
  return m?.[1] ?? null;
}
serve(async (req)=>{
  if (req.method === "OPTIONS") return new Response("ok", {
    headers: corsHeaders
  });
  if (req.method !== "POST") return json(405, {
    error: "Method not allowed"
  });
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) return json(500, {
    error: "Missing env vars"
  });
  const jwt = getBearerToken(req);
  if (!jwt) return json(401, {
    error: "Missing Authorization Bearer token"
  });
  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    global: {
      headers: {
        Authorization: `Bearer ${jwt}`
      }
    }
  });
  const { data: userData, error: userErr } = await supabase.auth.getUser();
  if (userErr || !userData?.user) return json(401, {
    error: "Invalid token"
  });
  let body;
  try {
    body = await req.json();
  } catch  {
    return json(400, {
      error: "Invalid JSON"
    });
  }
  try {
    // CREATE GROUP with invite link
    if (body.action === "create") {
      const { data, error } = await supabase.rpc("create_group_with_invite", {
        group_name: body.name,
        member_ids: [],
        max_members_limit: body.max_members ?? null,
        expires_in_hours: body.expires_hours ?? null
      });
      if (error) return json(400, {
        error: error.message
      });
      return json(200, {
        success: true,
        ...data[0]
      });
    }
    // JOIN GROUP via invite code
    if (body.action === "join") {
      const { data, error } = await supabase.rpc("join_group_via_invite", {
        invite_code_input: body.code
      });
      if (error) return json(400, {
        error: error.message
      });
      return json(200, data[0]);
    }
    // LEAVE GROUP (with auto admin transfer)
    if (body.action === "leave") {
      const { data, error } = await supabase.rpc("leave_group", {
        target_room_id: body.room_id
      });
      if (error) return json(400, {
        error: error.message
      });
      return json(200, data[0]);
    }
    // REGENERATE invite link (admin only)
    if (body.action === "regenerate") {
      const { data, error } = await supabase.rpc("regenerate_invite_link", {
        target_room_id: body.room_id,
        expires_in_hours: body.expires_hours ?? null
      });
      if (error) return json(400, {
        error: error.message
      });
      return json(200, {
        success: true,
        ...data[0]
      });
    }
    // PREVIEW invite info (before joining)
    if (body.action === "preview") {
      const { data, error } = await supabase.rpc("get_invite_info", {
        invite_code_input: body.code
      });
      if (error) return json(400, {
        error: error.message
      });
      return json(200, data[0] ?? {
        is_valid: false
      });
    }
    // UPDATE group settings (admin only)
    if (body.action === "update") {
      const { data, error } = await supabase.rpc("update_group_settings", {
        target_room_id: body.room_id,
        new_name: body.name ?? null,
        new_max_members: body.max_members ?? null,
        enable_invite_link: body.enable_link ?? null
      });
      if (error) return json(400, {
        error: error.message
      });
      return json(200, {
        success: data
      });
    }
    return json(400, {
      error: "Unknown action"
    });
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return json(500, {
      error: "Internal error",
      details: msg
    });
  }
});
