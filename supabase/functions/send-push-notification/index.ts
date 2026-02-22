// supabase/functions/send-push-notification/index.ts

// Unified push notification sender.
// Expected payload (Supabase DB webhook):
// {
//   "type": "INSERT",
//   "table": "notifications",
//   "schema": "public",
//   "record": {
//      id, user_id, title, body, type, channel, room_id, post_id, sender_id, message_id, data
//   }
// }

import { JWT } from "npm:google-auth-library@9";
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { getServiceClient } from "../_shared/supabase.ts";

// ─── Firebase credentials from env ──────────────────────────────

const FCM_SERVICE_ACCOUNT_JSON = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON") ?? "";

function getServiceAccount(): {
  project_id: string;
  client_email: string;
  private_key: string;
} {
  if (!FCM_SERVICE_ACCOUNT_JSON) {
    throw new Error("FCM_SERVICE_ACCOUNT_JSON env var is not set");
  }

  // Strip control chars that can break JSON.parse
  const cleaned = FCM_SERVICE_ACCOUNT_JSON.replace(
    /[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g,
    "",
  );

  const sa = JSON.parse(cleaned);

  // Ensure private_key newlines are real newlines
  sa.private_key = sa.private_key.replace(/\\n/g, "\n");

  return sa;
}

// ─── Types ──────────────────────────────────────────────────────

interface NotificationRecord {
  id?: string;
  user_id: string;
  title?: string;
  body: string;
  type?: string;
  channel: string;
  room_id?: string;
  post_id?: string;
  sender_id?: string;
  message_id?: string;
  data?: Record<string, unknown>;
}

interface WebhookPayload {
  type: string;
  table: string;
  schema: string;
  record?: NotificationRecord;
  [key: string]: unknown;
}

interface DeviceRow {
  id: string;
  user_id: string;
  device_id: string;
  fcm_token: string | null;
  push_enabled: boolean;
  current_room_id: string | null;
  platform: string | null;
}

// ─── Helpers ────────────────────────────────────────────────────

// Remove control characters etc. from strings used in FCM payload
function sanitize(s: string | null | undefined): string {
  if (!s) return "";
  return s
    .replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g, "")
    .replace(/\r\n/g, " ")
    .replace(/\r/g, " ")
    .replace(/\n/g, " ")
    .replace(/\t/g, " ")
    .trim();
}

// Robust JSON parser for weird webhook bodies
function safeParseJson(raw: string): Record<string, unknown> | null {
  // 1) direct
  try {
    return JSON.parse(raw);
  } catch {
    // ignore
  }

  // 2) strip control chars + tabs
  try {
    const sanitized = raw
      .replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g, "")
      .replace(/\t/g, " ");
    return JSON.parse(sanitized);
  } catch {
    // ignore
  }

  // 3) fallback: try substring between first { and last }
  const start = raw.indexOf("{");
  const end = raw.lastIndexOf("}");
  if (start !== -1 && end > start) {
    const slice = raw.slice(start, end + 1);
    try {
      return JSON.parse(slice);
    } catch {
      console.error(
        "safeParseJson slice still invalid:",
        slice.substring(0, 300),
      );
    }
  }

  console.error("safeParseJson RAW body:", raw.substring(0, 300));
  return null;
}

// Channel → Android notification channel mapping
const CHANNEL_CONFIG: Record<string, { android_channel_id: string }> = {
  direct_message: { android_channel_id: "dm_channel" },
  group_message: { android_channel_id: "group_channel" },
  post: { android_channel_id: "post_channel" },
  comment: { android_channel_id: "comment_channel" },
  comment_reply: { android_channel_id: "comment_channel" },
  comment_mention: { android_channel_id: "comment_channel" },
  chat_mention: { android_channel_id: "group_channel" },
  like: { android_channel_id: "general_channel" },
  feed: { android_channel_id: "general_channel" },
  general: { android_channel_id: "general_channel" },
};

// Default titles based on channel/type
function getDefaultTitle(
  channel: string,
  type: string | undefined,
  senderName: string,
): string {
  switch (type) {
    case "comment_reply":
      return `${senderName} replied to your comment`;
    case "comment_mention":
      return `${senderName} mentioned you in a comment`;
    case "chat_mention":
      return `${senderName} mentioned you`;
    case "new_post":
      return `${senderName} posted something new`;
  }

  switch (channel) {
    case "direct_message":
      return senderName;
    case "group_message":
      return `${senderName} in group`;
    case "post":
      return `${senderName} posted`;
    case "comment":
      return `${senderName} commented`;
    case "like":
      return `${senderName} liked your post`;
    case "feed":
      return senderName;
    default:
      return "DeConnect";
  }
}

const getAccessToken = ({
  clientEmail,
  privateKey,
}: {
  clientEmail: string;
  privateKey: string;
}): Promise<string> => {
  return new Promise((resolve, reject) => {
    const jwtClient = new JWT({
      email: clientEmail,
      key: privateKey,
      scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
    });
    jwtClient.authorize((err, tokens) => {
      if (err) {
        reject(err);
        return;
      }
      resolve(tokens!.access_token!);
    });
  });
};

// ─── Main handler ───────────────────────────────────────────────

serve(async (req) => {
  // Basic CORS
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers":
          "authorization, x-client-info, apikey, content-type",
      },
    });
  }

  try {
    const serviceAccount = getServiceAccount();
    const supabase = getServiceClient();

    // Read body safely
    const rawBody = await req.text();
    const parsed = safeParseJson(rawBody);
    if (!parsed) {
      return new Response(
        JSON.stringify({
          success: false,
          error: "Malformed JSON in webhook payload",
        }),
        {
          status: 400,
          headers: { "Content-Type": "application/json" },
        },
      );
    }

    const payload = parsed as WebhookPayload;

    // Standard Supabase webhook: payload.record holds the notification
    let record: NotificationRecord | undefined = payload.record;

    // Allow direct calls with the notification object as body
    if (!record && (parsed as any).user_id) {
      record = parsed as unknown as NotificationRecord;
    }

    if (!record || !record.user_id) {
      return new Response(
        JSON.stringify({
          success: false,
          error: "Invalid payload: missing record.user_id",
        }),
        {
          status: 400,
          headers: { "Content-Type": "application/json" },
        },
      );
    }

    console.log(
      `Processing push for user=${record.user_id}, channel=${record.channel}, type=${record.type ?? "n/a"}`,
    );

    // ── Fetch devices for user ──────────────────────────────────

    let devices: DeviceRow[] = [];

    let query = supabase
      .from("user_devices")
      .select(
        "id, user_id, device_id, fcm_token, push_enabled, current_room_id, platform",
      )
      .eq("user_id", record.user_id)
      .eq("push_enabled", true)
      .not("fcm_token", "is", null);

    // If room_id present, skip devices that are actively in that room
    if (record.room_id) {
      query = query.or(
        `current_room_id.neq.${record.room_id},current_room_id.is.null`,
      );
    }

    const { data: udDevices, error: udError } = await query;
    if (udError) {
      console.error("user_devices fetch error:", udError.message);
    }

    if (udDevices && udDevices.length > 0) {
      devices = udDevices as DeviceRow[];
    } else {
      // Legacy fallback: profiles.fcm_token
      const { data: profile, error: profError } = await supabase
        .from("profiles")
        .select("id, fcm_token, push_enabled")
        .eq("id", record.user_id)
        .maybeSingle();

      if (!profError && profile?.fcm_token && profile.push_enabled !== false) {
        devices = [
          {
            id: profile.id,
            user_id: profile.id,
            device_id: "legacy_profile",
            fcm_token: profile.fcm_token,
            push_enabled: true,
            current_room_id: null,
            platform: null,
          } as DeviceRow,
        ];
        console.log(
          "Using legacy profiles.fcm_token fallback for",
          record.user_id,
        );
      }
    }

    if (devices.length === 0) {
      console.log(`No eligible devices for ${record.user_id}, skipping`);
      return new Response(
        JSON.stringify({
          success: true,
          skipped: true,
          reason: "no_devices",
        }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      );
    }

    console.log(
      `Found ${devices.length} device(s) for user ${record.user_id}`,
    );

    // ── Resolve sender name (for title) ─────────────────────────

    let senderName = "DeConnect";
    if (record.sender_id) {
      const { data: sender } = await supabase
        .from("profiles")
        .select("username, first_name, last_name")
        .eq("id", record.sender_id)
        .single();

      if (sender) {
        senderName =
          [sender.first_name, sender.last_name].filter(Boolean).join(" ") ||
          sender.username ||
          "DeConnect";
      }
    }

    const channelConfig =
      CHANNEL_CONFIG[record.channel] || CHANNEL_CONFIG.general;

    const title =
      sanitize(record.title) ||
      getDefaultTitle(record.channel, record.type, senderName);
    const body = sanitize(record.body);

    // Deep link data
    const deepLinkData: Record<string, string> = {
      channel: record.channel ?? "general",
      type: record.type ?? record.channel ?? "general",
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    };
    if (record.room_id) deepLinkData.room_id = record.room_id;
    if (record.post_id) deepLinkData.post_id = record.post_id;
    if (record.sender_id) deepLinkData.sender_id = record.sender_id;
    if (record.message_id) deepLinkData.message_id = record.message_id;
    if (record.id) deepLinkData.notification_id = record.id;

    const accessToken = await getAccessToken({
      clientEmail: serviceAccount.client_email,
      privateKey: serviceAccount.private_key,
    });

    const results: Array<{
      device_id: string;
      platform: string | null;
      status: number;
      success: boolean;
      error?: string;
    }> = [];

    for (const device of devices) {
      if (!device.fcm_token) continue;

      try {
        const fcmMessage = {
          message: {
            token: device.fcm_token,
            notification: { title, body },
            android: {
              priority: "high" as const,
              notification: {
                channel_id: channelConfig.android_channel_id,
                tag: record.room_id ?? record.post_id ?? record.channel,
                click_action: "FLUTTER_NOTIFICATION_CLICK",
                default_sound: true,
              },
            },
            apns: {
              headers: { "apns-priority": "10" },
              payload: {
                aps: {
                  "thread-id":
                    record.room_id ?? record.post_id ?? record.channel,
                  sound: "default",
                  badge: 1,
                  "mutable-content": 1,
                },
              },
            },
            data: deepLinkData,
          },
        };

        const fcmRes = await fetch(
          `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              Authorization: `Bearer ${accessToken}`,
            },
            body: JSON.stringify(fcmMessage),
          },
        );

        const fcmData = await fcmRes.json();

        if (fcmRes.status >= 200 && fcmRes.status < 300) {
          console.log(
            `Push OK ${device.device_id ?? device.id} [${device.platform ?? "?"}]`,
          );
          results.push({
            device_id: device.device_id ?? device.id,
            platform: device.platform,
            status: fcmRes.status,
            success: true,
          });
        } else {
          console.error(
            `FCM error ${device.device_id ?? device.id}:`,
            JSON.stringify(fcmData),
          );
          results.push({
            device_id: device.device_id ?? device.id,
            platform: device.platform,
            status: fcmRes.status,
            success: false,
            error: fcmData?.error?.message,
          });

          // Clear stale / invalid tokens
          if (
            fcmData?.error?.details?.some(
              (d: { errorCode?: string }) =>
                d.errorCode === "UNREGISTERED" ||
                d.errorCode === "INVALID_ARGUMENT",
            )
          ) {
            await supabase
              .from("user_devices")
              .update({ fcm_token: null, push_enabled: false })
              .eq("id", device.id);
            console.log(
              `Cleared stale token for ${device.device_id ?? device.id}`,
            );
          }
        }
      } catch (deviceError) {
        const msg =
          deviceError instanceof Error
            ? deviceError.message
            : String(deviceError);
        console.error(`Device ${device.device_id ?? device.id}: ${msg}`);
        results.push({
          device_id: device.device_id ?? device.id,
          platform: device.platform,
          status: 0,
          success: false,
          error: msg,
        });
      }
    }

    const sent = results.filter((r) => r.success).length;
    const failed = results.filter((r) => !r.success).length;

    console.log(
      `Push summary: ${sent} sent, ${failed} failed for ${record.user_id}`,
    );

    // Best‑effort logging
    try {
      await supabase.from("system_logs").insert({
        level: failed > 0 && sent === 0 ? "warning" : "info",
        message:
          `Push: ${record.channel} -> ${record.user_id} (${sent}/${devices.length} devices)`,
        feature: "notification",
        action: "send_push",
        metadata: {
          channel: record.channel,
          type: record.type,
          sent,
          failed,
          total_devices: devices.length,
        },
        source: "edge_function",
      });
    } catch {
      // ignore
    }

    return new Response(
      JSON.stringify({ success: true, sent, failed, results }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error);
    console.error("Push error:", msg);

    // Always return valid JSON for your worker
    return new Response(JSON.stringify({ success: false, error: msg }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
