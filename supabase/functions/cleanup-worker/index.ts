// supabase/functions/cleanup-worker/index.ts
// Purpose: Background cleanup tasks (can be triggered by cron or manually)
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
serve(async (req)=>{
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: corsHeaders
    });
  }
  if (req.method !== "POST") {
    return json(405, {
      error: "Method not allowed"
    });
  }
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    return json(500, {
      error: "Missing environment variables"
    });
  }
  const supabase = createClient(supabaseUrl, serviceRoleKey);
  let payload;
  try {
    payload = await req.json();
  } catch  {
    // Default to cleaning all if no payload
    payload = {
      task: "all",
      days_old: 7
    };
  }
  const { task, days_old = 7 } = payload;
  const results = [];
  const cutoffDate = new Date();
  cutoffDate.setDate(cutoffDate.getDate() - days_old);
  const cutoffISO = cutoffDate.toISOString();
  try {
    // Task 1: Clean old system logs
    if (task === "logs" || task === "all") {
      const { data, error } = await supabase.from("system_logs").delete().lt("created_at", cutoffISO).select("id");
      results.push({
        task: "system_logs",
        deleted_count: error ? 0 : data?.length || 0,
        success: !error
      });
      if (error) console.error("Logs cleanup error:", error);
    }
    // Task 2: Clean inactive devices (not active for 30+ days)
    if (task === "devices" || task === "all") {
      const deviceCutoff = new Date();
      deviceCutoff.setDate(deviceCutoff.getDate() - 30);
      const { data, error } = await supabase.from("user_devices").delete().eq("is_active", false).lt("last_active_at", deviceCutoff.toISOString()).select("id");
      results.push({
        task: "inactive_devices",
        deleted_count: error ? 0 : data?.length || 0,
        success: !error
      });
      if (error) console.error("Devices cleanup error:", error);
    }
    // Task 3: Deactivate expired invite links
    if (task === "invites" || task === "all") {
      const { data, error } = await supabase.from("group_invite_links").update({
        is_active: false
      }).lt("expires_at", new Date().toISOString()).eq("is_active", true).select("id");
      results.push({
        task: "expired_invites",
        deleted_count: error ? 0 : data?.length || 0,
        success: !error
      });
      if (error) console.error("Invites cleanup error:", error);
    }
    // Task 4: Delete enqueued post images
    if (task === "post_images" || task === "all") {
      try {
        const { data: deletions, error: delErr } = await supabase
          .from('post_image_deletions')
          .select('*')
          .eq('processed', false)
          .limit(100);

        if (delErr) {
          console.error('Failed to fetch post_image_deletions:', delErr);
        } else if (deletions && deletions.length > 0) {
          for (const d of deletions) {
            try {
              if (!d.object_path || d.object_path === '') {
                // Nothing to delete, mark processed
                await supabase.from('post_image_deletions').update({ processed: true, processed_at: new Date().toISOString() }).eq('id', d.id);
                continue;
              }

              const removeRes = await supabase.storage.from(d.bucket_id).remove([d.object_path]);
              if (removeRes?.error) {
                console.error('Failed to remove object', d.object_path, removeRes.error);
              } else {
                await supabase.from('post_image_deletions').update({ processed: true, processed_at: new Date().toISOString() }).eq('id', d.id);
              }
            } catch (innerErr) {
              console.error('Error processing deletion row', d.id, innerErr);
            }
          }
        }
      } catch (e) {
        console.error('Post images cleanup failed:', e);
      }
    }
    // Task 4: Clean old analytics events (30+ days)
    if (task === "all") {
      const analyticsCutoff = new Date();
      analyticsCutoff.setDate(analyticsCutoff.getDate() - 30);
      const { data, error } = await supabase.from("analytics_events").delete().lt("created_at", analyticsCutoff.toISOString()).select("id");
      results.push({
        task: "analytics_events",
        deleted_count: error ? 0 : data?.length || 0,
        success: !error
      });
      if (error) console.error("Analytics cleanup error:", error);
    }
    // Log cleanup summary
    const totalDeleted = results.reduce((sum, r)=>sum + r.deleted_count, 0);
    await supabase.from("system_logs").insert({
      level: "info",
      message: "Cleanup worker completed",
      metadata: {
        task,
        days_old,
        results,
        total_deleted: totalDeleted
      }
    });
    return json(200, {
      success: true,
      task,
      days_old,
      results,
      total_deleted: totalDeleted
    });
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error);
    console.error("Cleanup worker error:", msg);
    return json(500, {
      error: "Cleanup failed",
      details: msg
    });
  }
});
