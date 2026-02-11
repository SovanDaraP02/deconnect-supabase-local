-- ============================================================================
-- HELPER FUNCTIONS & TRIGGERS
-- ============================================================================
--
-- Internal automation functions and database triggers
-- Part of DeConnect Database Schema
-- ============================================================================

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  INSERT INTO public.profiles (
    id,
    email,
    username,
    first_name,
    last_name,
    gender,
    avatar_url,
    role,
    is_banned,
    push_enabled,
    created_at,
    updated_at
  )
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(
      NEW.raw_user_meta_data->>'username',
      split_part(NEW.email, '@', 1)
    ),
    NEW.raw_user_meta_data->>'first_name',
    NEW.raw_user_meta_data->>'last_name',
    NEW.raw_user_meta_data->>'gender',
    NEW.raw_user_meta_data->>'avatar_url',
    'user',
    false,
    true,
    NOW(),
    NOW()
  );
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.handle_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.handle_user_delete()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  -- Delete all user data when auth user is deleted
  DELETE FROM public.messages WHERE sender_id = OLD.id;
  DELETE FROM public.room_members WHERE user_id = OLD.id;
  DELETE FROM public.comments WHERE user_id = OLD.id;
  DELETE FROM public.posts WHERE user_id = OLD.id;
  DELETE FROM public.profiles WHERE id = OLD.id;
  RETURN OLD;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.handle_user_update()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  -- Update profile email if auth email changed
  IF NEW.email != OLD.email THEN
    UPDATE public.profiles 
    SET email = NEW.email, updated_at = NOW()
    WHERE id = NEW.id;
  END IF;
  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.heartbeat()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  UPDATE profiles
  SET 
    is_online = true,
    last_seen = now()
  WHERE id = auth.uid();
END;
$function$
;

CREATE OR REPLACE FUNCTION public.is_admin()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM profiles 
    WHERE id = auth.uid() AND role = 'admin'
  );
$function$
;

CREATE OR REPLACE FUNCTION public.is_room_admin(check_room_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM room_members
    WHERE room_id = check_room_id
    AND user_id = auth.uid()
    AND is_admin = TRUE
  );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.is_username_available(check_username text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  RETURN NOT EXISTS (
    SELECT 1
    FROM public.profiles
    WHERE username = check_username
      AND id != COALESCE(auth.uid(), '00000000-0000-0000-0000-000000000000'::uuid)
  );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.join_group_by_code(p_code text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_room_id UUID;
  v_room_name TEXT;
  v_user_id UUID;
  v_existing_member UUID;
BEGIN
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Not authenticated');
  END IF;

  -- Find room by invite code (case-insensitive)
  SELECT id, name INTO v_room_id, v_room_name
  FROM chat_rooms
  WHERE UPPER(TRIM(invite_code)) = UPPER(TRIM(p_code))
    AND is_group = true
  LIMIT 1;  -- Important: LIMIT 1 to avoid multiple rows error

  IF v_room_id IS NULL THEN
    RETURN json_build_object('success', false, 'message', 'Invalid invite code');
  END IF;

  -- Check if already member
  SELECT rm.user_id INTO v_existing_member
  FROM room_members rm
  WHERE rm.room_id = v_room_id
    AND rm.user_id = v_user_id;

  IF v_existing_member IS NOT NULL THEN
    RETURN json_build_object(
      'success', true, 
      'message', 'You are already a member',
      'room_id', v_room_id,
      'room_name', v_room_name
    );
  END IF;

  -- Join as member
  INSERT INTO room_members (room_id, user_id, role)
  VALUES (v_room_id, v_user_id, 'member');

  RETURN json_build_object(
    'success', true,
    'message', 'Successfully joined the group!',
    'room_id', v_room_id,
    'room_name', v_room_name
  );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.join_group_by_code(p_invite_code character varying)
 RETURNS TABLE(success boolean, room_id uuid, room_name text, message text)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_room_id UUID;
  v_room_name TEXT;
  v_is_member BOOLEAN;
BEGIN
  -- Find the room by invite code
  SELECT id, name INTO v_room_id, v_room_name
  FROM chat_rooms
  WHERE invite_code = UPPER(p_invite_code)
  AND is_group = TRUE;

  -- Check if room exists
  IF v_room_id IS NULL THEN
    RETURN QUERY SELECT FALSE, NULL::UUID, NULL::TEXT, 'Invalid invite code'::TEXT;
    RETURN;
  END IF;

  -- Check if user is already a member
  SELECT EXISTS (
    SELECT 1 FROM room_members rm
    WHERE rm.room_id = v_room_id
    AND rm.user_id = auth.uid()
  ) INTO v_is_member;

  IF v_is_member THEN
    RETURN QUERY SELECT TRUE, v_room_id, v_room_name, 'Already a member'::TEXT;
    RETURN;
  END IF;

  -- Add user as member
  INSERT INTO room_members (room_id, user_id, role, joined_at)
  VALUES (v_room_id, auth.uid(), 'member', NOW());

  RETURN QUERY SELECT TRUE, v_room_id, v_room_name, 'Successfully joined'::TEXT;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.join_group_via_invite(invite_code_input text)
 RETURNS TABLE(success boolean, message text, joined_room_id uuid, room_name text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_room_id UUID;
  v_room_name TEXT;
  v_max_members INTEGER;
  v_current_members INTEGER;
  v_expires_at TIMESTAMPTZ;
  v_is_active BOOLEAN;
  v_invite_link_enabled BOOLEAN;
  current_user_id UUID;
BEGIN
  current_user_id := auth.uid();
  IF current_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT gil.room_id, cr.name, cr.max_members, gil.expires_at, gil.is_active, cr.invite_link_enabled
  INTO v_room_id, v_room_name, v_max_members, v_expires_at, v_is_active, v_invite_link_enabled
  FROM group_invite_links gil
  JOIN chat_rooms cr ON gil.room_id = cr.id
  WHERE UPPER(gil.invite_code) = UPPER(invite_code_input);

  IF v_room_id IS NULL THEN
    RETURN QUERY SELECT false, 'Invalid invite code'::TEXT, NULL::UUID, NULL::TEXT;
    RETURN;
  END IF;

  IF NOT v_is_active OR NOT v_invite_link_enabled THEN
    RETURN QUERY SELECT false, 'This invite link is no longer active'::TEXT, NULL::UUID, NULL::TEXT;
    RETURN;
  END IF;

  IF v_expires_at IS NOT NULL AND NOW() > v_expires_at THEN
    RETURN QUERY SELECT false, 'This invite link has expired'::TEXT, NULL::UUID, NULL::TEXT;
    RETURN;
  END IF;

  IF EXISTS (SELECT 1 FROM room_members rm WHERE rm.room_id = v_room_id AND rm.user_id = current_user_id) THEN
    RETURN QUERY SELECT true, 'Already a member'::TEXT, v_room_id, v_room_name;
    RETURN;
  END IF;

  SELECT COUNT(*) INTO v_current_members FROM room_members rm WHERE rm.room_id = v_room_id;
  IF v_max_members IS NOT NULL AND v_current_members >= v_max_members THEN
    RETURN QUERY SELECT false, 'Group is full'::TEXT, NULL::UUID, NULL::TEXT;
    RETURN;
  END IF;

  INSERT INTO room_members (room_id, user_id, is_admin)
  VALUES (v_room_id, current_user_id, false);

  UPDATE group_invite_links
  SET uses_count = uses_count + 1, last_used_at = NOW()
  WHERE UPPER(invite_code) = UPPER(invite_code_input);

  RETURN QUERY SELECT true, 'Successfully joined group'::TEXT, v_room_id, v_room_name;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.leave_group(target_room_id uuid)
 RETURNS TABLE(success boolean, message text, new_admin_id uuid)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  current_user_id UUID;
  was_admin BOOLEAN;
  next_admin_id UUID;
  remaining_members INT;
BEGIN
  current_user_id := auth.uid();
  
  IF current_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  
  -- Check if user is in the room
  SELECT is_admin INTO was_admin
  FROM public.room_members
  WHERE room_id = target_room_id AND user_id = current_user_id;
  
  IF was_admin IS NULL THEN
    RETURN QUERY SELECT false, 'You are not a member of this group', NULL::UUID;
    RETURN;
  END IF;
  
  -- Remove user from room
  DELETE FROM public.room_members
  WHERE room_id = target_room_id AND user_id = current_user_id;
  
  -- Count remaining members
  SELECT COUNT(*) INTO remaining_members
  FROM public.room_members
  WHERE room_id = target_room_id;
  
  -- If no members left, delete the room
  IF remaining_members = 0 THEN
    DELETE FROM public.chat_rooms WHERE id = target_room_id;
    RETURN QUERY SELECT true, 'Group deleted (no members remaining)', NULL::UUID;
    RETURN;
  END IF;
  
  -- If leaving user was admin, transfer admin to next person
  IF was_admin THEN
    -- Find next admin (lowest admin_order who is not admin yet)
    SELECT user_id INTO next_admin_id
    FROM public.room_members
    WHERE room_id = target_room_id
    ORDER BY admin_order ASC
    LIMIT 1;
    
    IF next_admin_id IS NOT NULL THEN
      UPDATE public.room_members
      SET is_admin = true
      WHERE room_id = target_room_id AND user_id = next_admin_id;
      
      -- Log admin transfer
      INSERT INTO public.system_logs (level, message, metadata)
      VALUES (
        'info',
        'Admin transferred in group',
        jsonb_build_object(
          'room_id', target_room_id,
          'old_admin', current_user_id,
          'new_admin', next_admin_id
        )
      );
      
      RETURN QUERY SELECT true, 'Left group. Admin transferred to next member.', next_admin_id;
      RETURN;
    END IF;
  END IF;
  
  RETURN QUERY SELECT true, 'Successfully left group', NULL::UUID;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.log_comment_deletion()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
    INSERT INTO public.system_logs (level, message, metadata, user_id)
    VALUES (
        'info',
        'Comment deleted',
        jsonb_build_object(
            'comment_id', OLD.id,
            'post_id', OLD.post_id,
            'content_preview', LEFT(OLD.content, 50),
            'original_author', OLD.user_id,
            'deleted_by', auth.uid()
        ),
        OLD.user_id
    );
    
    RETURN OLD;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.log_error(p_level text, p_message text, p_metadata jsonb DEFAULT '{}'::jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_log_id UUID;
BEGIN
    -- Validate log level
    IF p_level NOT IN ('info', 'warning', 'error', 'critical') THEN
        RAISE EXCEPTION 'Invalid log level: %. Must be info, warning, error, or critical', p_level;
    END IF;

    -- Insert log entry
    INSERT INTO public.system_logs (level, message, metadata, user_id)
    VALUES (
        p_level,
        p_message,
        p_metadata,
        auth.uid() -- Automatically captures current user
    )
    RETURNING id INTO v_log_id;

    RETURN v_log_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.log_post_deletion_attempt()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
    -- Log the deletion attempt
    INSERT INTO public.system_logs (level, message, metadata, user_id)
    VALUES (
        'info',
        'Post deleted',
        jsonb_build_object(
            'post_id', OLD.id,
            'content_preview', LEFT(OLD.content, 50),
            'had_image', (OLD.image_url IS NOT NULL)
        ),
        auth.uid()
    );
    
    RETURN OLD;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.log_user_ban_action()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
    -- Only log if is_banned status changed to TRUE
    IF NEW.is_banned = TRUE AND OLD.is_banned = FALSE THEN
        INSERT INTO public.system_logs (level, message, metadata, user_id)
        VALUES (
            'warning',
            'User banned',
            jsonb_build_object(
                'banned_user_id', NEW.id,
                'banned_username', NEW.username,
                'banned_by', auth.uid()
            ),
            NEW.id
        );
    END IF;
    
    -- Log if user was unbanned
    IF NEW.is_banned = FALSE AND OLD.is_banned = TRUE THEN
        INSERT INTO public.system_logs (level, message, metadata, user_id)
        VALUES (
            'info',
            'User unbanned',
            jsonb_build_object(
                'unbanned_user_id', NEW.id,
                'unbanned_username', NEW.username,
                'unbanned_by', auth.uid()
            ),
            NEW.id
        );
    END IF;
    
    RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.mark_messages_as_read(p_room_id uuid, p_user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  UPDATE public.messages
  SET 
    is_read = TRUE,
    read_at = NOW()
  WHERE room_id = p_room_id
    AND sender_id != p_user_id
    AND is_read = FALSE;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.mark_messages_read(target_room_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  -- Update messages to read
  UPDATE public.messages
  SET status = 'read', is_read = true
  WHERE room_id = target_room_id
    AND sender_id != auth.uid()
    AND status != 'read';
  
  -- Update last_read_at in room_members
  UPDATE public.room_members
  SET last_read_at = NOW()
  WHERE room_id = target_room_id
    AND user_id = auth.uid();
END;
$function$
;

CREATE OR REPLACE FUNCTION public.mark_stale_users_offline()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  UPDATE profiles
  SET is_online = false
  WHERE is_online = true
    AND last_seen < now() - INTERVAL '5 minutes';  -- Changed to 5 minutes
END;
$function$
;

CREATE OR REPLACE FUNCTION public.promote_to_admin(target_room_id uuid, target_user_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  room_creator UUID;
  is_group_chat BOOLEAN;
BEGIN
  -- Get room info
  SELECT created_by, is_group INTO room_creator, is_group_chat
  FROM public.chat_rooms
  WHERE id = target_room_id;
  
  -- Validate room exists
  IF room_creator IS NULL THEN
    RAISE EXCEPTION 'Room does not exist';
  END IF;
  
  -- Only group chats can have admins
  IF NOT is_group_chat THEN
    RAISE EXCEPTION 'Cannot promote admins in private chats';
  END IF;
  
  -- Security: Only room creator or system admin can promote
  IF auth.uid() != room_creator AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Only room creator or system admin can promote members';
  END IF;
  
  -- Check target user is a member
  IF NOT EXISTS (
    SELECT 1 FROM public.room_members 
    WHERE room_id = target_room_id AND user_id = target_user_id
  ) THEN
    RAISE EXCEPTION 'User is not a member of this room';
  END IF;
  
  -- Promote to admin
  UPDATE public.room_members
  SET is_admin = true
  WHERE room_id = target_room_id AND user_id = target_user_id;
  
  RETURN true;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.promote_to_room_admin(room_uuid uuid, target_user uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  -- Check if current user is room admin
  IF NOT EXISTS (
    SELECT 1 FROM room_members 
    WHERE room_id = room_uuid 
    AND user_id = auth.uid() 
    AND is_admin = true
  ) THEN
    RAISE EXCEPTION 'Only room admins can promote members';
  END IF;
  
  -- Check if target is a member
  IF NOT EXISTS (
    SELECT 1 FROM room_members 
    WHERE room_id = room_uuid AND user_id = target_user
  ) THEN
    RAISE EXCEPTION 'User is not a member of this room';
  END IF;
  
  -- Promote the target user
  UPDATE room_members 
  SET is_admin = true,
      admin_order = (SELECT COALESCE(MAX(admin_order), 0) + 1 
                     FROM room_members 
                     WHERE room_id = room_uuid AND is_admin = true)
  WHERE room_id = room_uuid AND user_id = target_user;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.regenerate_invite_code(p_room_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_new_code TEXT;
  v_user_id UUID;
  v_is_admin BOOLEAN;
BEGIN
  v_user_id := auth.uid();

  -- Check if user is admin (FIX: use table alias)
  SELECT (rm.role = 'admin') INTO v_is_admin
  FROM room_members rm
  WHERE rm.room_id = p_room_id
    AND rm.user_id = v_user_id;

  IF v_is_admin IS NOT TRUE THEN
    RAISE EXCEPTION 'Only admins can regenerate invite code';
  END IF;

  -- Generate new code
  v_new_code := upper(substring(md5(random()::text) from 1 for 6));

  -- Update room
  UPDATE chat_rooms
  SET invite_code = v_new_code
  WHERE id = p_room_id;

  RETURN v_new_code;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.regenerate_invite_link(target_room_id uuid, expires_in_hours integer DEFAULT NULL::integer)
 RETURNS TABLE(invite_code text, invite_url text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  current_user_id UUID;
  new_invite_code TEXT;
  is_user_admin BOOLEAN;
  expires_at TIMESTAMP WITH TIME ZONE;
BEGIN
  current_user_id := auth.uid();
  
  -- Check if user is admin of this room
  SELECT is_admin INTO is_user_admin
  FROM public.room_members
  WHERE room_id = target_room_id AND user_id = current_user_id;
  
  IF NOT COALESCE(is_user_admin, false) THEN
    RAISE EXCEPTION 'Only admins can regenerate invite links';
  END IF;
  
  -- Generate new code
  new_invite_code := public.generate_invite_code();
  
  -- Calculate expiration
  IF expires_in_hours IS NOT NULL THEN
    expires_at := NOW() + (expires_in_hours || ' hours')::INTERVAL;
  END IF;
  
  -- Update room's invite code
  UPDATE public.chat_rooms
  SET invite_code = new_invite_code
  WHERE id = target_room_id;
  
  -- Deactivate old invite links
  UPDATE public.group_invite_links
  SET is_active = false
  WHERE room_id = target_room_id;
  
  -- Create new invite link
  INSERT INTO public.group_invite_links (room_id, invite_code, created_by, expires_at)
  VALUES (target_room_id, new_invite_code, current_user_id, expires_at);
  
  RETURN QUERY
  SELECT 
    new_invite_code,
    'https://deconnect.app/join/' || new_invite_code AS invite_url;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.remove_member_from_group(target_room_id uuid, target_user_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  room_is_group BOOLEAN;
  caller_is_admin BOOLEAN;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Must be a group room
  SELECT cr.is_group INTO room_is_group
  FROM public.chat_rooms cr
  WHERE cr.id = target_room_id;

  IF room_is_group IS DISTINCT FROM TRUE THEN
    RAISE EXCEPTION 'This is not a group room';
  END IF;

  -- Caller must be admin of the room
  SELECT COALESCE(rm.is_admin, FALSE) INTO caller_is_admin
  FROM public.room_members rm
  WHERE rm.room_id = target_room_id
    AND rm.user_id = auth.uid();

  IF caller_is_admin IS NOT TRUE THEN
    RAISE EXCEPTION 'Only admins can remove members';
  END IF;

  -- Prevent removing yourself (use leave_group)
  IF target_user_id = auth.uid() THEN
    RAISE EXCEPTION 'Use leave_group to leave the group';
  END IF;

  -- Remove member
  DELETE FROM public.room_members
  WHERE room_id = target_room_id
    AND user_id = target_user_id;

  RETURN TRUE;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.search_users(search_query text)
 RETURNS TABLE(id uuid, username text, first_name text, last_name text, avatar_url text, bio text, gender text)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    p.username,
    p.first_name,
    p.last_name,
    p.avatar_url,
    p.bio,
    p.gender
  FROM profiles p
  WHERE 
    p.id != auth.uid()
    AND p.is_banned = false
    AND (
      p.username ILIKE '%' || search_query || '%'
      OR p.first_name ILIKE '%' || search_query || '%'
      OR p.last_name ILIKE '%' || search_query || '%'
    )
  LIMIT 20;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.set_offline()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  UPDATE profiles
  SET 
    is_online = false,
    last_seen = now()
  WHERE id = auth.uid();
END;
$function$
;

CREATE OR REPLACE FUNCTION public.set_room_creator_as_admin()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  -- Check if this user is the room creator
  IF NEW.user_id = (SELECT created_by FROM public.chat_rooms WHERE id = NEW.room_id) THEN
    NEW.is_admin := true;
    NEW.admin_order := 1;
  END IF;
  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.set_typing_indicator(p_room_id uuid, p_is_typing boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  INSERT INTO public.typing_indicators (room_id, user_id, is_typing, started_at)
  VALUES (p_room_id, auth.uid(), p_is_typing, NOW())
  ON CONFLICT (room_id, user_id) 
  DO UPDATE SET 
    is_typing = p_is_typing,
    started_at = NOW();
    
  -- Auto-cleanup: Remove typing indicator after setting to false
  IF NOT p_is_typing THEN
    DELETE FROM public.typing_indicators 
    WHERE room_id = p_room_id AND user_id = auth.uid();
  END IF;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.set_typing_status(p_room_id uuid, p_is_typing boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  INSERT INTO public.typing_indicators (room_id, user_id, is_typing, started_at)
  VALUES (p_room_id, auth.uid(), p_is_typing, NOW())
  ON CONFLICT (room_id, user_id) 
  DO UPDATE SET 
    is_typing = p_is_typing,
    started_at = NOW();
    
  -- Auto-cleanup: Remove typing indicator after setting to false
  IF NOT p_is_typing THEN
    DELETE FROM public.typing_indicators 
    WHERE room_id = p_room_id AND user_id = auth.uid();
  END IF;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.transfer_admin_on_leave()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
  next_user_id UUID;
BEGIN
  -- If leaving user was a group admin
  IF OLD.is_admin = true THEN
    -- Find next member by join date
    SELECT user_id INTO next_user_id
    FROM room_members
    WHERE room_id = OLD.room_id
    AND user_id != OLD.user_id
    ORDER BY joined_at ASC
    LIMIT 1;
    
    -- If there's another member, promote them
    IF next_user_id IS NOT NULL THEN
      UPDATE room_members
      SET is_admin = true, admin_order = OLD.admin_order
      WHERE room_id = OLD.room_id
      AND user_id = next_user_id;
    END IF;
  END IF;
  
  RETURN OLD;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.transfer_ownership(target_room_id uuid, new_owner_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  current_owner UUID;
  is_group_chat BOOLEAN;
BEGIN
  -- Get room info
  SELECT created_by, is_group INTO current_owner, is_group_chat
  FROM public.chat_rooms
  WHERE id = target_room_id;
  
  -- Validate room exists
  IF current_owner IS NULL THEN
    RAISE EXCEPTION 'Room does not exist';
  END IF;
  
  -- Only group chats can transfer ownership
  IF NOT is_group_chat THEN
    RAISE EXCEPTION 'Cannot transfer ownership of private chats';
  END IF;
  
  -- Security: Only current owner can transfer
  IF auth.uid() != current_owner THEN
    RAISE EXCEPTION 'Only the room owner can transfer ownership';
  END IF;
  
  -- Check new owner is a member
  IF NOT EXISTS (
    SELECT 1 FROM public.room_members 
    WHERE room_id = target_room_id AND user_id = new_owner_id
  ) THEN
    RAISE EXCEPTION 'New owner must be a member of the room';
  END IF;
  
  -- Transfer ownership
  UPDATE public.chat_rooms
  SET created_by = new_owner_id
  WHERE id = target_room_id;
  
  -- Make new owner an admin too
  UPDATE public.room_members
  SET is_admin = true
  WHERE room_id = target_room_id AND user_id = new_owner_id;
  
  RETURN true;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.unban_user(p_user_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
DECLARE
  caller_role TEXT;
BEGIN
  -- Get caller's role
  SELECT role INTO caller_role 
  FROM profiles 
  WHERE id = auth.uid();
  
  -- Check if caller is admin
  IF caller_role IS NULL OR caller_role != 'admin' THEN
    RAISE EXCEPTION 'Only admins can unban users. Your role: %', COALESCE(caller_role, 'not found');
  END IF;
  
  -- Unban the user
  UPDATE profiles SET is_banned = FALSE WHERE id = p_user_id;
  RETURN TRUE;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.update_group_settings(target_room_id uuid, new_name text DEFAULT NULL::text, new_max_members integer DEFAULT NULL::integer, enable_invite_link boolean DEFAULT NULL::boolean)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  current_user_id UUID;
  is_user_admin BOOLEAN;
BEGIN
  current_user_id := auth.uid();
  
  -- Check if user is admin
  SELECT is_admin INTO is_user_admin
  FROM public.room_members
  WHERE room_id = target_room_id AND user_id = current_user_id;
  
  IF NOT COALESCE(is_user_admin, false) THEN
    RAISE EXCEPTION 'Only admins can update group settings';
  END IF;
  
  -- Update room settings (only non-null values)
  UPDATE public.chat_rooms
  SET 
    name = COALESCE(new_name, name),
    max_members = COALESCE(new_max_members, max_members),
    invite_link_enabled = COALESCE(enable_invite_link, invite_link_enabled)
  WHERE id = target_room_id;
  
  RETURN true;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.update_last_seen()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  UPDATE profiles SET last_seen = NOW(), is_online = TRUE WHERE id = NEW.sender_id;
  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.update_online_status(p_is_online boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  UPDATE profiles
  SET 
    is_online = p_is_online,
    last_seen = now()
  WHERE id = auth.uid();
END;
$function$
;

CREATE OR REPLACE FUNCTION public.update_presence()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  UPDATE profiles
  SET 
    is_online = true,
    last_seen = now()
  WHERE id = auth.uid();
END;
$function$
;

CREATE OR REPLACE FUNCTION public.update_room_on_message()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  UPDATE public.chat_rooms SET updated_at = NOW() WHERE id = NEW.room_id;
  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.update_typing_status(target_room_id uuid, typing boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  INSERT INTO public.typing_indicators (room_id, user_id, is_typing, updated_at)
  VALUES (target_room_id, auth.uid(), typing, NOW())
  ON CONFLICT (room_id, user_id) DO UPDATE SET is_typing = typing, updated_at = NOW();
END;
$function$
;

-- ============================================================================
-- BROADCAST FUNCTIONS FOR REAL-TIME UPDATES
-- ============================================================================

CREATE OR REPLACE FUNCTION public.broadcast_message_change()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  PERFORM pg_notify(
    'messages:' || NEW.room_id::text,
    json_build_object(
      'event', TG_OP,
      'message_id', NEW.id,
      'room_id', NEW.room_id,
      'sender_id', NEW.sender_id,
      'content', NEW.content,
      'media_url', NEW.media_url,
      'media_type', NEW.media_type,
      'is_read', NEW.is_read,
      'created_at', NEW.created_at
    )::text
  );
  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.broadcast_room_change()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  PERFORM pg_notify(
    'room_members:' || NEW.room_id::text,
    json_build_object(
      'event', TG_OP,
      'room_id', NEW.room_id,
      'user_id', NEW.user_id,
      'is_admin', NEW.is_admin,
      'joined_at', NEW.joined_at
    )::text
  );
  RETURN NEW;
END;
$function$
;

grant delete on table "public"."call_participants" to "anon";

-- ============================================================================
-- TRIGGERS
-- ============================================================================



CREATE TRIGGER handle_chat_rooms_updated_at BEFORE UPDATE ON public.chat_rooms FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER handle_comments_updated_at BEFORE UPDATE ON public.comments FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER log_comment_deletion BEFORE DELETE ON public.comments FOR EACH ROW EXECUTE FUNCTION public.log_comment_deletion();

CREATE TRIGGER on_message_update_last_seen AFTER INSERT ON public.messages FOR EACH ROW EXECUTE FUNCTION public.update_last_seen();

CREATE TRIGGER update_room_on_new_message AFTER INSERT ON public.messages FOR EACH ROW EXECUTE FUNCTION public.update_room_on_message();

CREATE TRIGGER broadcast_message_insert AFTER INSERT ON public.messages FOR EACH ROW EXECUTE FUNCTION public.broadcast_message_change();

CREATE TRIGGER broadcast_message_update AFTER UPDATE ON public.messages FOR EACH ROW EXECUTE FUNCTION public.broadcast_message_change();

CREATE TRIGGER handle_posts_updated_at BEFORE UPDATE ON public.posts FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER log_post_deletion BEFORE DELETE ON public.posts FOR EACH ROW EXECUTE FUNCTION public.log_post_deletion_attempt();

CREATE TRIGGER handle_profiles_updated_at BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER log_user_ban AFTER UPDATE OF is_banned ON public.profiles FOR EACH ROW WHEN ((old.is_banned IS DISTINCT FROM new.is_banned)) EXECUTE FUNCTION public.log_user_ban_action();

CREATE TRIGGER auto_admin_room_creator BEFORE INSERT ON public.room_members FOR EACH ROW EXECUTE FUNCTION public.set_room_creator_as_admin();

CREATE TRIGGER broadcast_room_member_insert AFTER INSERT ON public.room_members FOR EACH ROW EXECUTE FUNCTION public.broadcast_room_change();

CREATE TRIGGER broadcast_room_member_update AFTER UPDATE ON public.room_members FOR EACH ROW EXECUTE FUNCTION public.broadcast_room_change();

CREATE TRIGGER on_admin_leave BEFORE DELETE ON public.room_members FOR EACH ROW EXECUTE FUNCTION public.transfer_admin_on_leave();

CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

CREATE TRIGGER on_auth_user_deleted BEFORE DELETE ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_user_delete();

CREATE TRIGGER on_auth_user_updated AFTER UPDATE ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_user_update();


