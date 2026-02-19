// supabase/functions/create-post/index.ts
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { getServiceClient } from "../_shared/supabase.ts";
import { json, handleCors } from "../_shared/helpers.ts";

serve(async (req: Request): Promise<Response> => {
  const cors = handleCors(req);
  if (cors) return cors;

  try {
    const supabase = getServiceClient();

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

    // ── IMAGE URL STRATEGY ──────────────────────────────────────────
    // Store just the storage path (e.g. "posts/uuid_123456.jpg")
    // instead of a full public URL. The Flutter client constructs
    // the correct URL using its own EnvConfig.supabaseUrl.
    // ────────────────────────────────────────────────────────────────
    const imageUrlToStore = imagePath || null;

    // Insert post
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
    console.error("❌ Error in create-post function:", error);
    return json(500, {
      error:
        error instanceof Error ? error.message : "Unknown error occurred",
    });
  }
});
