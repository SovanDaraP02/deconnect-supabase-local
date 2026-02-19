// supabase/functions/send-message/index.ts
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { getAuthClient, getServiceClient } from "../_shared/supabase.ts";
import { json, handleCors } from "../_shared/helpers.ts";

serve(async (req) => {
  const cors = handleCors(req);
  if (cors) return cors;

  try {
    const supabaseAuth = getAuthClient(req);
    const supabaseAdmin = getServiceClient();

    const {
      data: { user },
    } = await supabaseAuth.auth.getUser();
    if (!user) {
      return json(401, { error: "Unauthorized" });
    }

    const { room_id, content, media_url } = await req.json();

    // Verify membership
    const { data: membership } = await supabaseAdmin
      .from("room_members")
      .select("room_id")
      .eq("room_id", room_id)
      .eq("user_id", user.id)
      .single();

    if (!membership) {
      return json(403, { error: "Not a member of this room" });
    }

    // Insert message
    const { data: message, error } = await supabaseAdmin
      .from("messages")
      .insert({
        room_id,
        sender_id: user.id,
        content,
        media_url,
      })
      .select()
      .single();

    if (error) throw error;

    return json(200, { success: true, message });
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error);
    return json(500, { error: msg });
  }
});
