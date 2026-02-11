import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { RtcTokenBuilder, RtcRole } from "npm:agora-token@2.0.5";
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
    const { channelName, uid, role, expirationTimeInSeconds } = await req.json();
    if (!channelName) {
      return new Response(JSON.stringify({
        error: "channelName is required"
      }), {
        status: 400,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    }
    const appId = Deno.env.get("AGORA_APP_ID");
    const appCertificate = Deno.env.get("AGORA_APP_CERTIFICATE");
    if (!appId || !appCertificate) {
      console.error("Missing Agora credentials");
      return new Response(JSON.stringify({
        error: "Agora credentials not configured"
      }), {
        status: 500,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    }
    const currentTimestamp = Math.floor(Date.now() / 1000);
    const privilegeExpiredTs = currentTimestamp + (expirationTimeInSeconds || 3600);
    const userUid = uid || 0;
    const rtcRole = role === 2 ? RtcRole.SUBSCRIBER : RtcRole.PUBLISHER;
    console.log(`Generating token for channel: ${channelName}, uid: ${userUid}, role: ${rtcRole}`);
    const token = RtcTokenBuilder.buildTokenWithUid(appId, appCertificate, channelName, userUid, rtcRole, privilegeExpiredTs, privilegeExpiredTs);
    console.log(`Token generated successfully, expires at: ${privilegeExpiredTs}`);
    return new Response(JSON.stringify({
      token,
      appId,
      channelName,
      uid: userUid,
      expiresAt: privilegeExpiredTs
    }), {
      status: 200,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : "Unknown error";
    console.error("Error:", errorMessage);
    return new Response(JSON.stringify({
      error: errorMessage
    }), {
      status: 500,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  }
});
