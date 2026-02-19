// supabase/functions/moderate-content/index.ts
// Purpose: Basic content moderation for posts, comments, messages
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { getServiceClient } from "../_shared/supabase.ts";
import { json, handleCors } from "../_shared/helpers.ts";

// Simple bad word filter (expand as needed)
const BLOCKED_PATTERNS = [/\b(spam|scam|hack)\b/gi];
const SUSPICIOUS_PATTERNS = [/https?:\/\/[^\s]+/gi, /\b\d{10,}\b/g];

function moderateContent(content: string) {
  const reasons: string[] = [];
  let severity = "low";
  let flagged = false;
  let approved = true;

  for (const pattern of BLOCKED_PATTERNS) {
    if (pattern.test(content)) {
      flagged = true;
      severity = "high";
      reasons.push("Contains blocked content");
      approved = false;
      break;
    }
  }

  for (const pattern of SUSPICIOUS_PATTERNS) {
    if (pattern.test(content)) {
      flagged = true;
      if (severity === "low") severity = "medium";
      reasons.push("Contains suspicious content for review");
    }
  }

  if (content.length > 5000) {
    flagged = true;
    reasons.push("Content exceeds maximum length");
    severity = "medium";
  }

  const capsRatio =
    (content.match(/[A-Z]/g) || []).length / content.length;
  if (capsRatio > 0.7 && content.length > 20) {
    flagged = true;
    reasons.push("Excessive capitalization");
    if (severity === "low") severity = "medium";
  }

  return { approved, flagged, severity, reasons };
}

serve(async (req) => {
  const cors = handleCors(req);
  if (cors) return cors;

  if (req.method !== "POST") {
    return json(405, { error: "Method not allowed" });
  }

  const supabase = getServiceClient();

  let payload: Record<string, unknown>;
  try {
    payload = await req.json();
  } catch {
    return json(400, { error: "Invalid JSON" });
  }

  const { content, content_type, content_id, user_id } = payload as {
    content?: string;
    content_type?: string;
    content_id?: string;
    user_id?: string;
  };

  if (!content || !content_type || !user_id) {
    return json(400, {
      error: "Missing required fields: content, content_type, user_id",
    });
  }

  try {
    const result = moderateContent(content);

    // Log to moderation table
    await supabase.from("content_moderation_log").insert({
      content_type,
      content_id: content_id || null,
      user_id,
      flagged: result.flagged,
      approved: result.approved,
      severity: result.severity,
      reasons: result.reasons,
      auto_moderated: true,
      content_preview: content.substring(0, 200),
      metadata: { content_length: content.length, moderation_version: "1.0" },
    });

    if (!result.approved) {
      await supabase.from("system_logs").insert({
        level: "warning",
        message: "Content blocked by auto-moderation",
        metadata: { content_type, content_id, user_id, reasons: result.reasons },
        user_id,
      });
    }

    return json(200, {
      ...result,
      message: result.approved ? "Content approved" : "Content blocked",
    });
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error);
    console.error("Moderation error:", msg);
    return json(500, { error: "Moderation failed", details: msg });
  }
});
