// supabase/functions/group-links/index.ts
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { getAuthClient, getServiceClient, getBearerToken } from "../_shared/supabase.ts";
import { json, handleCors } from "../_shared/helpers.ts";

serve(async (req) => {
  const cors = handleCors(req);
  if (cors) return cors;

  if (req.method !== "POST") return json(405, { error: "Method not allowed" });

  const jwt = getBearerToken(req);
  if (!jwt) return json(401, { error: "Missing Authorization Bearer token" });

  const supabase = getAuthClient(req);
  const admin = getServiceClient();

  const { data: userData, error: userErr } = await supabase.auth.getUser();
  if (userErr || !userData?.user) return json(401, { error: "Invalid token" });

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json(400, { error: "Invalid JSON" });
  }

  try {
    // ─── CREATE GROUP with invite link ─────────────────────────
    if (body.action === "create") {
      const { data, error } = await supabase.rpc("create_group_with_invite", {
        group_name: body.name,
        member_ids: [],
        max_members_limit: body.max_members ?? null,
        expires_in_hours: body.expires_hours ?? null,
        group_description: body.description ?? null,
      });
      if (error) return json(400, { error: error.message });

      // Log
      await admin.from("system_logs").insert({
        level: "info",
        message: `Group created: ${body.name}`,
        user_id: userData.user.id,
        feature: "group",
        action: "create_group",
        metadata: { room_id: data[0]?.room_id, group_name: body.name },
      });

      return json(200, { success: true, ...data[0] });
    }

    // ─── JOIN GROUP via invite code ────────────────────────────
    if (body.action === "join") {
      const { data, error } = await supabase.rpc("join_group_via_invite", {
        invite_code_input: body.code,
      });
      if (error) return json(400, { error: error.message });

      const result = data[0];

      // Log
      await admin.from("system_logs").insert({
        level: "info",
        message: `User joined group via invite: ${body.code}`,
        user_id: userData.user.id,
        feature: "group",
        action: "join_group",
        metadata: { invite_code: body.code, room_id: result?.room_id },
      });

      return json(200, result);
    }

    // ─── LEAVE GROUP (with auto admin transfer) ────────────────
    if (body.action === "leave") {
      const { data, error } = await supabase.rpc("leave_group", {
        target_room_id: body.room_id,
      });
      if (error) return json(400, { error: error.message });

      await admin.from("system_logs").insert({
        level: "info",
        message: `User left group`,
        user_id: userData.user.id,
        feature: "group",
        action: "leave_group",
        metadata: { room_id: body.room_id },
      });

      return json(200, data[0]);
    }

    // ─── REGENERATE invite link (admin only) ───────────────────
    if (body.action === "regenerate") {
      const { data, error } = await supabase.rpc("regenerate_invite_link", {
        target_room_id: body.room_id,
        expires_in_hours: body.expires_hours ?? null,
      });
      if (error) return json(400, { error: error.message });

      await admin.from("system_logs").insert({
        level: "info",
        message: `Invite link regenerated`,
        user_id: userData.user.id,
        feature: "group",
        action: "regenerate_invite",
        metadata: { room_id: body.room_id },
      });

      return json(200, { success: true, ...data[0] });
    }

    // ─── KICK MEMBER + REGENERATE CODE ─────────────────────────
    // Kicks a user and regenerates the invite code so they can't rejoin
    if (body.action === "kick_and_regenerate") {
      const roomId = body.room_id as string;
      const targetUserId = body.target_user_id as string;

      if (!roomId || !targetUserId) {
        return json(400, { error: "room_id and target_user_id are required" });
      }

      // Verify caller is admin
      const { data: callerMembership } = await admin
        .from("room_members")
        .select("is_admin")
        .eq("room_id", roomId)
        .eq("user_id", userData.user.id)
        .single();

      if (!callerMembership?.is_admin) {
        return json(403, { error: "Only admins can kick members" });
      }

      // Don't allow kicking yourself
      if (targetUserId === userData.user.id) {
        return json(400, { error: "Cannot kick yourself. Use leave instead." });
      }

      // Don't allow kicking other admins
      const { data: targetMembership } = await admin
        .from("room_members")
        .select("is_admin")
        .eq("room_id", roomId)
        .eq("user_id", targetUserId)
        .single();

      if (targetMembership?.is_admin) {
        return json(400, { error: "Cannot kick another admin" });
      }

      // Step 1: Remove the member
      const { error: removeErr } = await admin
        .from("room_members")
        .delete()
        .eq("room_id", roomId)
        .eq("user_id", targetUserId);

      if (removeErr) return json(500, { error: `Failed to remove member: ${removeErr.message}` });

      // Step 2: Regenerate the invite code
      const { data: newLink, error: regenErr } = await supabase.rpc("regenerate_invite_link", {
        target_room_id: roomId,
        expires_in_hours: body.expires_hours ?? null,
      });

      if (regenErr) {
        console.error("Failed to regenerate after kick:", regenErr.message);
        // The kick succeeded even if regeneration fails
      }

      // Step 3: Send system message
      await admin.from("messages").insert({
        room_id: roomId,
        sender_id: userData.user.id,
        content: `A member was removed and the invite link was regenerated`,
        is_system_message: true,
      });

      // Log
      await admin.from("system_logs").insert({
        level: "warning",
        message: `Member kicked and invite regenerated`,
        user_id: userData.user.id,
        feature: "group",
        action: "kick_and_regenerate",
        metadata: {
          room_id: roomId,
          kicked_user_id: targetUserId,
          new_invite_code: newLink?.[0]?.invite_code ?? null,
        },
      });

      return json(200, {
        success: true,
        kicked: true,
        regenerated: !regenErr,
        new_invite_code: newLink?.[0]?.invite_code ?? null,
        new_expires_at: newLink?.[0]?.expires_at ?? null,
      });
    }

    // ─── KICK MEMBER (without regenerating) ────────────────────
    if (body.action === "kick") {
      const roomId = body.room_id as string;
      const targetUserId = body.target_user_id as string;

      if (!roomId || !targetUserId) {
        return json(400, { error: "room_id and target_user_id are required" });
      }

      // Verify caller is admin
      const { data: callerMem } = await admin
        .from("room_members")
        .select("is_admin")
        .eq("room_id", roomId)
        .eq("user_id", userData.user.id)
        .single();

      if (!callerMem?.is_admin) {
        return json(403, { error: "Only admins can kick members" });
      }

      if (targetUserId === userData.user.id) {
        return json(400, { error: "Cannot kick yourself" });
      }

      const { error: kickErr } = await admin
        .from("room_members")
        .delete()
        .eq("room_id", roomId)
        .eq("user_id", targetUserId);

      if (kickErr) return json(500, { error: kickErr.message });

      await admin.from("system_logs").insert({
        level: "info",
        message: `Member kicked from group`,
        user_id: userData.user.id,
        feature: "group",
        action: "kick_member",
        metadata: { room_id: roomId, kicked_user_id: targetUserId },
      });

      return json(200, { success: true, kicked: true });
    }

    // ─── PREVIEW invite info (before joining) ──────────────────
    if (body.action === "preview") {
      const { data, error } = await supabase.rpc("get_invite_info", {
        invite_code_input: body.code,
      });
      if (error) return json(400, { error: error.message });
      return json(200, data[0] ?? { is_valid: false });
    }

    // ─── UPDATE group settings (admin only) ────────────────────
    if (body.action === "update") {
      const { data, error } = await supabase.rpc("update_group_settings", {
        target_room_id: body.room_id,
        new_name: body.name ?? null,
        new_max_members: body.max_members ?? null,
        enable_invite_link: body.enable_link ?? null,
        new_description: body.description ?? null,
      });
      if (error) return json(400, { error: error.message });
      return json(200, { success: data });
    }

    return json(400, { error: "Unknown action" });
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.error("group-links error:", msg);
    return json(500, { error: "Internal error", details: msg });
  }
});
