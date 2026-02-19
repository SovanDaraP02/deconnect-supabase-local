// supabase/functions/admin-actions/index.ts
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { corsHeaders } from "../_shared/cors.ts";
import { getAuthClient, getServiceClient } from "../_shared/supabase.ts";
import { json, handleCors } from "../_shared/helpers.ts";

serve(async (req) => {
  const cors = handleCors(req);
  if (cors) return cors;

  try {
    const supabase = getAuthClient(req);

    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      return json(401, { error: "Unauthorized" });
    }

    // Check if admin
    const { data: profile } = await supabase
      .from("profiles")
      .select("role")
      .eq("id", user.id)
      .single();

    if (profile?.role !== "admin") {
      return json(403, { error: "Admin access required" });
    }

    const { action, target_user_id, post_id, reason } = await req.json();
    let result: Record<string, unknown>;

    switch (action) {
      case "ban_user": {
        const { data: banData } = await supabase
          .from("profiles")
          .update({ is_banned: true })
          .eq("id", target_user_id)
          .select()
          .single();
        result = { success: true, message: "User banned", user: banData };
        break;
      }
      case "unban_user": {
        const { data: unbanData } = await supabase
          .from("profiles")
          .update({ is_banned: false })
          .eq("id", target_user_id)
          .select()
          .single();
        result = { success: true, message: "User unbanned", user: unbanData };
        break;
      }
      case "delete_post": {
        await supabase.from("comments").delete().eq("post_id", post_id);
        await supabase.from("posts").delete().eq("id", post_id);
        result = { success: true, message: "Post and comments deleted" };
        break;
      }
      default:
        return json(400, { error: "Invalid action" });
    }

    // Log admin action
    const admin = getServiceClient();
    await admin.from("system_logs").insert({
      level: "info",
      message: `Admin action: ${action}`,
      user_id: user.id,
      metadata: { target_user_id, post_id, reason },
    });

    return json(200, result);
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error);
    return json(500, { error: msg });
  }
});
