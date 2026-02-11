// supabase/functions/admin-actions/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type"
};
serve(async (req)=>{
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: corsHeaders
    });
  }
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const authHeader = req.headers.get("Authorization");
    const supabase = createClient(supabaseUrl, supabaseKey, {
      global: {
        headers: {
          Authorization: authHeader
        }
      }
    });
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) {
      return new Response(JSON.stringify({
        error: "Unauthorized"
      }), {
        status: 401,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    }
    // Check if admin
    const { data: profile } = await supabase.from("profiles").select("role").eq("id", user.id).single();
    if (profile?.role !== "admin") {
      return new Response(JSON.stringify({
        error: "Admin access required"
      }), {
        status: 403,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    }
    const { action, target_user_id, post_id, reason } = await req.json();
    let result;
    switch(action){
      case "ban_user":
        const { data: banData } = await supabase.from("profiles").update({
          is_banned: true
        }).eq("id", target_user_id).select().single();
        result = {
          success: true,
          message: "User banned",
          user: banData
        };
        break;
      case "unban_user":
        const { data: unbanData } = await supabase.from("profiles").update({
          is_banned: false
        }).eq("id", target_user_id).select().single();
        result = {
          success: true,
          message: "User unbanned",
          user: unbanData
        };
        break;
      case "delete_post":
        await supabase.from("comments").delete().eq("post_id", post_id);
        await supabase.from("posts").delete().eq("id", post_id);
        result = {
          success: true,
          message: "Post and comments deleted"
        };
        break;
      default:
        return new Response(JSON.stringify({
          error: "Invalid action"
        }), {
          status: 400,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json"
          }
        });
    }
    // Log admin action
    await supabase.from("system_logs").insert({
      level: "info",
      message: `Admin action: ${action}`,
      user_id: user.id,
      metadata: {
        target_user_id,
        post_id,
        reason
      }
    });
    return new Response(JSON.stringify(result), {
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  } catch (error) {
    return new Response(JSON.stringify({
      error: error.message
    }), {
      status: 500,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  }
});
