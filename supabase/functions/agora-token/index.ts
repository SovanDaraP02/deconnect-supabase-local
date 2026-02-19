// supabase/functions/agora-token/index.ts
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { RtcTokenBuilder, RtcRole } from "npm:agora-token@2.0.5";
import { json, handleCors } from "../_shared/helpers.ts";

serve(async (req) => {
  const cors = handleCors(req);
  if (cors) return cors;

  try {
    const { channelName, uid, role, expirationTimeInSeconds } =
      await req.json();

    if (!channelName) {
      return json(400, { error: "channelName is required" });
    }

    const appId = Deno.env.get("AGORA_APP_ID");
    const appCertificate = Deno.env.get("AGORA_APP_CERTIFICATE");

    if (!appId || !appCertificate) {
      console.error("Missing Agora credentials");
      return json(500, { error: "Agora credentials not configured" });
    }

    const currentTimestamp = Math.floor(Date.now() / 1000);
    const privilegeExpiredTs =
      currentTimestamp + (expirationTimeInSeconds || 3600);
    const userUid = uid || 0;
    const rtcRole =
      role === 2 ? RtcRole.SUBSCRIBER : RtcRole.PUBLISHER;

    console.log(
      `Generating token for channel: ${channelName}, uid: ${userUid}, role: ${rtcRole}`,
    );

    const token = RtcTokenBuilder.buildTokenWithUid(
      appId,
      appCertificate,
      channelName,
      userUid,
      rtcRole,
      privilegeExpiredTs,
      privilegeExpiredTs,
    );

    console.log(
      `Token generated successfully, expires at: ${privilegeExpiredTs}`,
    );

    return json(200, {
      token,
      appId,
      channelName,
      uid: userUid,
      expiresAt: privilegeExpiredTs,
    });
  } catch (error) {
    const msg = error instanceof Error ? error.message : "Unknown error";
    console.error("Error:", msg);
    return json(500, { error: msg });
  }
});
