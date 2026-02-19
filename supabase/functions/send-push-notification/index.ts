// supabase/functions/send-push-notification/index.ts
//
// Unified push notification sender.
// Triggered by DB webhook (notifications table INSERT) or direct invocation.
// Handles: direct_message, group_message, post, comment, comment_reply,
//          comment_mention, chat_mention, like, feed, general
//
import { JWT } from "npm:google-auth-library@9";
import { getServiceClient } from "../_shared/supabase.ts";
import { corsHeaders } from "../_shared/cors.ts";
import { json, handleCors } from "../_shared/helpers.ts";

// ─── Firebase credentials from env ───────────────────────────────────
const FCM_SERVICE_ACCOUNT_JSON = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON");
if (!FCM_SERVICE_ACCOUNT_JSON) {
  console.error("FATAL: FCM_SERVICE_ACCOUNT_JSON env var is not set");
}

function getServiceAccount(): {
  project_id: string;
  client_email: string;
  private_key: string;
} {
  if (!FCM_SERVICE_ACCOUNT_JSON) {
    throw new Error("FCM_SERVICE_ACCOUNT_JSON env var is not set");
  }
  // Fix: env vars may contain literal \n that breaks JSON.parse
  const cleaned = FCM_SERVICE_ACCOUNT_JSON.replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g, "");
  const sa = JSON.parse(cleaned);
  // Ensure private_key newlines are real newlines
  sa.private_key = sa.private_key.replace(/\\n/g, "\n");
  return sa;
}


// ─── Types ───────────────────────────────────────────────────────────
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

interface DeviceRow {
  id: string;
  user_id: string;
  device_id: string;
  fcm_token: string | null;
  push_enabled: boolean;
  current_room_id: string | null;
  platform: string | null;
}

// ─── Channel → Android notification channel mapping ──────────────────
const CHANNEL_CONFIG: Record<string, { android_channel_id: string }> = {
  direct_message:  { android_channel_id: "dm_channel" },
  group_message:   { android_channel_id: "group_channel" },
  post:            { android_channel_id: "post_channel" },
  comment:         { android_channel_id: "comment_channel" },
  comment_reply:   { android_channel_id: "comment_channel" },
  comment_mention: { android_channel_id: "comment_channel" },
  chat_mention:    { android_channel_id: "group_channel" },
  like:            { android_channel_id: "general_channel" },
  feed:            { android_channel_id: "general_channel" },
  general:         { android_channel_id: "general_channel" },
};

// ─── Main handler ────────────────────────────────────────────────────
Deno.serve(async (req) => {
  const cors = handleCors(req);
  if (cors) return cors;

  try {
    const supabase = getServiceClient();
    const serviceAccount = getServiceAccount();
    const payload = await req.json();

    // Support BOTH webhook format (from DB trigger) AND direct invocation
    let record: NotificationRecord;
    if (payload.record) {
      record = payload.record;
    } else if (payload.user_id) {
      record = payload as NotificationRecord;
    } else {
      return json(400, { success: false, error: "Invalid payload: missing user_id or record" });
    }

    console.log(
      `📬 Processing push → user: ${record.user_id}, channel: ${record.channel}, type: ${record.type ?? "n/a"}`,
    );

    // ── Fetch devices for this user ────────────────────────────────
    let query = supabase
      .from("user_devices")
      .select("id, user_id, device_id, fcm_token, push_enabled, current_room_id, platform")
      .eq("user_id", record.user_id)
      .eq("push_enabled", true)
      .not("fcm_token", "is", null);

    // If notification is for a specific room, exclude devices currently viewing it
    if (record.room_id) {
      query = query.or(
        `current_room_id.neq.${record.room_id},current_room_id.is.null`
      );
    }

    const { data: devices, error: devError } = await query;

    if (devError) {
      console.error("❌ Device fetch error:", devError.message);
      return json(500, { success: false, error: devError.message });
    }

    if (!devices || devices.length === 0) {
      console.log(`⏭️ No eligible devices for ${record.user_id}, skipping`);
      return json(200, { success: true, skipped: true, reason: "no_devices" });
    }

    console.log(`📱 Found ${devices.length} device(s) for user ${record.user_id}`);

    // ── Resolve sender name ────────────────────────────────────────
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

    const channelConfig = CHANNEL_CONFIG[record.channel] || CHANNEL_CONFIG.general;
    const title = record.title ?? getDefaultTitle(record.channel, record.type, senderName);

    // ── Build deep link data ───────────────────────────────────────
    const deepLinkData: Record<string, string> = {
      channel: record.channel ?? "general",
      type: record.type ?? record.channel ?? "general",
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    };

    // Add navigation targets
    if (record.room_id) deepLinkData.room_id = record.room_id;
    if (record.post_id) deepLinkData.post_id = record.post_id;
    if (record.sender_id) deepLinkData.sender_id = record.sender_id;
    if (record.message_id) deepLinkData.message_id = record.message_id;
    if (record.id) deepLinkData.notification_id = record.id;

    // ── Get FCM access token ───────────────────────────────────────
    const accessToken = await getAccessToken({
      clientEmail: serviceAccount.client_email,
      privateKey: serviceAccount.private_key,
    });

    // ── Send to each device ────────────────────────────────────────
    const results: Array<{
      device_id: string;
      platform: string | null;
      status: number;
      success: boolean;
      error?: string;
    }> = [];

    for (const device of devices as DeviceRow[]) {
      if (!device.fcm_token) continue;

      try {
        const fcmMessage = {
          message: {
            token: device.fcm_token,
            notification: { title, body: record.body },
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
                  "thread-id": record.room_id ?? record.post_id ?? record.channel,
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
          console.log(`✅ Push → ${device.device_id ?? device.id} [${device.platform ?? "?"}]`);
          results.push({
            device_id: device.device_id ?? device.id,
            platform: device.platform,
            status: fcmRes.status,
            success: true,
          });
        } else {
          console.error(`❌ FCM error ${device.device_id ?? device.id}:`, JSON.stringify(fcmData));
          results.push({
            device_id: device.device_id ?? device.id,
            platform: device.platform,
            status: fcmRes.status,
            success: false,
            error: fcmData?.error?.message,
          });

          // Clear stale/invalid tokens
          if (
            fcmData?.error?.details?.some(
              (d: { errorCode: string }) =>
                d.errorCode === "UNREGISTERED" || d.errorCode === "INVALID_ARGUMENT",
            )
          ) {
            await supabase
              .from("user_devices")
              .update({ fcm_token: null, push_enabled: false })
              .eq("id", device.id);
            console.log(`🗑️ Cleared stale token for ${device.device_id ?? device.id}`);
          }
        }
      } catch (deviceError) {
        const msg = deviceError instanceof Error ? deviceError.message : String(deviceError);
        console.error(`❌ Device ${device.device_id ?? device.id}: ${msg}`);
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
    console.log(`📊 Push summary: ${sent} sent, ${failed} failed for ${record.user_id}`);

    // ── Log to system_logs ─────────────────────────────────────────
    try {
      await supabase.from("system_logs").insert({
        level: failed > 0 && sent === 0 ? "warning" : "info",
        message: `Push: ${record.channel} → ${record.user_id} (${sent}/${devices.length} devices)`,
        feature: "notification",
        action: "send_push",
        metadata: {
          channel: record.channel,
          type: record.type,
          sent,
          failed,
          total_devices: devices.length,
        },
      });
    } catch (_logErr) {
      // Don't fail the request over logging
    }

    return json(200, { success: true, sent, failed, results });
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error);
    console.error("❌ Push error:", msg);
    return json(500, { success: false, error: msg });
  }
});

// ─── Helpers ─────────────────────────────────────────────────────────

function getDefaultTitle(
  channel: string,
  type: string | undefined,
  senderName: string,
): string {
  // Use type for more specific titles
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

  // Fallback to channel
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
