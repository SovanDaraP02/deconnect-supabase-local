// supabase/functions/create-post/index.ts
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, PUT, DELETE, GET, OPTIONS",
};

/** Helper – returns a JSON Response with CORS + Content-Type headers */
function json(status: number, data: Record<string, unknown>): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

serve(async (req: Request): Promise<Response> => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Initialize Supabase client
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !supabaseServiceKey) {
      return json(500, { error: "Missing Supabase environment variables" });
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Parse request body
    let body: Record<string, unknown>;
    try {
      body = await req.json();
    } catch {
      return json(400, { error: "Invalid JSON body" });
    }

    const {
      title,
      content,
      tags,
      image_url: imagePath,
      user_id,
    } = body as {
      title?: string;
      content?: string;
      tags?: string[];
      image_url?: string;
      user_id?: string;
    };

    // Validate required fields
    if (!title || !content || !user_id) {
      return json(400, {
        error: "Missing required fields: title, content, user_id",
      });
    }

    console.log("createPost invoked with:", {
      title,
      content,
      tags,
      imagePath,
      user_id,
    });

    // ── IMAGE URL STRATEGY ──────────────────────────────────────────────
    // Store just the storage path (e.g. "posts/uuid_123456.jpg") in the
    // image_url column instead of a full public URL.
    //
    // Why?  The edge function's SUPABASE_URL is an internal Docker address
    // (e.g. http://kong:8000 or http://127.0.0.1:54321) which is NOT
    // reachable from the Android emulator or from other devices.  By
    // storing only the path, the Flutter client can construct the correct
    // public URL using its own EnvConfig.supabaseUrl (which already
    // handles the 10.0.2.2 ↔ 127.0.0.1 platform swap).
    // ────────────────────────────────────────────────────────────────────
    const imageUrlToStore = imagePath || null;

    // Insert post into database
    const { data: post, error: insertError } = await supabase
      .from("posts")
      .insert([
        {
          user_id,
          title,
          content,
          image_url: imageUrlToStore,
          tags: tags && tags.length > 0 ? tags : [],
        },
      ])
      .select()
      .single();

    if (insertError) {
      console.error(`❌ Database insert error: ${insertError.message}`);
      return json(500, {
        error: `Failed to create post: ${insertError.message}`,
      });
    }

    console.log(`✅ Post created successfully with ID: ${post.id}`);

    return json(200, {
      success: true,
      post,
      message: "Post created successfully",
    });
  } catch (error) {
    console.error(`❌ Error in create-post function:`, error);

    return json(500, {
      error:
        error instanceof Error ? error.message : "Unknown error occurred",
    });
  }
});