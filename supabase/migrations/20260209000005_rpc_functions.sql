-- ============================================================================
-- RPC FUNCTIONS (BUSINESS LOGIC)
-- ============================================================================
--
-- Application-callable business logic functions
-- Part of DeConnect Database Schema
-- ============================================================================

CREATE OR REPLACE FUNCTION public.add_member_to_room(target_room_id uuid, new_member_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  room_creator UUID;
  is_group_chat BOOLEAN;
BEGIN
  -- Get room info
  SELECT created_by, is_group INTO room_creator, is_group_chat
  FROM public.chat_rooms
  WHERE id = target_room_id;
  
  IF room_creator IS NULL THEN
    RAISE EXCEPTION 'Room does not exist';
  END IF;
  
  IF NOT is_group_chat THEN
    RAISE EXCEPTION 'Cannot add members to private chats';
  END IF;
  
  -- Security Boundary: Only creator or admin
  IF auth.uid() != room_creator AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Only room creator or admin can add members';
  END IF;
  
  -- Validate member exists
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = new_member_id) THEN
    RAISE EXCEPTION 'User does not exist';
  END IF;
  
  -- Add member
  INSERT INTO public.room_members (room_id, user_id)
  VALUES (target_room_id, new_member_id)
  ON CONFLICT DO NOTHING;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_delete_group(room_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$BEGIN
  -- Check if caller is GLOBAL ADMIN or GROUP ADMIN
  IF NOT EXISTS (
    SELECT 1 FROM profiles 
    WHERE profiles.id = auth.uid() 
    AND profiles.role = 'admin'
  ) AND NOT EXISTS (
    SELECT 1 FROM room_members 
    WHERE room_members.room_id = admin_delete_group.room_id 
    AND room_members.user_id = auth.uid()
    AND room_members.is_admin = true
  ) THEN
    RAISE EXCEPTION 'Access denied: Global admin or group admin only';
  END IF;

  -- Delete related data first
  DELETE FROM typing_indicators WHERE typing_indicators.room_id = admin_delete_group.room_id;
  DELETE FROM messages WHERE messages.room_id = admin_delete_group.room_id;
  DELETE FROM room_members WHERE room_members.room_id = admin_delete_group.room_id;
  
  -- Delete the group
  DELETE FROM chat_rooms WHERE id = admin_delete_group.room_id;
  
  RETURN TRUE;
END;$function$
;

CREATE OR REPLACE FUNCTION public.admin_get_all_users(page_number integer DEFAULT 0, page_size integer DEFAULT 20)
 RETURNS TABLE(id uuid, username text, email text, first_name text, last_name text, avatar_url text, role text, is_banned boolean, created_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  -- Check if caller is admin
  IF NOT EXISTS (
    SELECT 1 FROM profiles 
    WHERE profiles.id = auth.uid() 
    AND profiles.role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Access denied: Admin only';
  END IF;
  
  RETURN QUERY
  SELECT 
    p.id,
    p.username,
    u.email,
    p.first_name,
    p.last_name,
    p.avatar_url,
    p.role,
    p.is_banned,
    p.created_at
  FROM profiles p
  LEFT JOIN auth.users u ON u.id = p.id
  ORDER BY p.created_at DESC
  LIMIT page_size
  OFFSET page_number * page_size;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_get_statistics()
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  stats JSON;
BEGIN
  -- Check if caller is admin
  IF NOT EXISTS (
    SELECT 1 FROM profiles 
    WHERE profiles.id = auth.uid() 
    AND profiles.role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Access denied: Admin only';
  END IF;
  
  SELECT json_build_object(
    'total_users', (SELECT COUNT(*) FROM profiles),
    'active_users', (SELECT COUNT(*) FROM profiles WHERE is_banned = false),
    'banned_users', (SELECT COUNT(*) FROM profiles WHERE is_banned = true),
    'admin_users', (SELECT COUNT(*) FROM profiles WHERE role = 'admin'),
    'total_groups', (SELECT COUNT(*) FROM chatrooms WHERE room_type = 'group'),
    'total_private_chats', (SELECT COUNT(*) FROM chatrooms WHERE room_type = 'private'),
    'total_messages', (SELECT COUNT(*) FROM messages),
    'messages_today', (SELECT COUNT(*) FROM messages WHERE created_at >= CURRENT_DATE),
    'new_users_today', (SELECT COUNT(*) FROM profiles WHERE created_at >= CURRENT_DATE)
  ) INTO stats;
  
  RETURN stats;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_set_user_ban(target_user_id uuid, banned boolean)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  -- Check if caller is admin
  IF NOT EXISTS (
    SELECT 1 FROM profiles 
    WHERE profiles.id = auth.uid() 
    AND profiles.role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Access denied: Admin only';
  END IF;
  
  -- Cannot ban yourself
  IF target_user_id = auth.uid() THEN
    RAISE EXCEPTION 'Cannot ban yourself';
  END IF;
  
  -- Update ban status
  UPDATE profiles 
  SET is_banned = banned, updated_at = NOW()
  WHERE id = target_user_id;
  
  RETURN TRUE;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.admin_set_user_role(target_user_id uuid, new_role text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  -- Check if caller is admin
  IF NOT EXISTS (
    SELECT 1 FROM profiles 
    WHERE profiles.id = auth.uid() 
    AND profiles.role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Access denied: Admin only';
  END IF;
  
  -- Validate role
  IF new_role NOT IN ('admin', 'user') THEN
    RAISE EXCEPTION 'Invalid role. Must be admin or user';
  END IF;
  
  -- Cannot change your own role
  IF target_user_id = auth.uid() THEN
    RAISE EXCEPTION 'Cannot change your own role';
  END IF;
  
  -- Update role
  UPDATE profiles 
  SET role = new_role, updated_at = NOW()
  WHERE id = target_user_id;
  
  RETURN TRUE;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.ban_user(p_user_id uuid)
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
    RAISE EXCEPTION 'Only admins can ban users. Your role: %', COALESCE(caller_role, 'not found');
  END IF;
  
  -- Prevent banning yourself
  IF p_user_id = auth.uid() THEN
    RAISE EXCEPTION 'Cannot ban yourself';
  END IF;
  
  -- Ban the user
  UPDATE profiles SET is_banned = TRUE WHERE id = p_user_id;
  RETURN TRUE;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.cleanup_old_logs()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_deleted_count INT;
BEGIN
    DELETE FROM public.system_logs
    WHERE created_at < NOW() - INTERVAL '7 days';
    
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    
    -- Log the cleanup
    INSERT INTO public.system_logs (level, message, metadata)
    VALUES (
        'info',
        'Log cleanup completed',
        jsonb_build_object(
            'deleted_count', v_deleted_count,
            'cleanup_date', NOW()
        )
    );
    
    RETURN jsonb_build_object(
        'success', true,
        'deleted_logs', v_deleted_count,
        'message', 'Deleted logs older than 7 days'
    );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.cleanup_stale_typing_indicators()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  DELETE FROM public.typing_indicators
  WHERE started_at < NOW() - INTERVAL '10 seconds';
END;
$function$
;

CREATE OR REPLACE FUNCTION public.create_group_chat(group_name text, member_ids uuid[])
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_room_id UUID;
  v_creator_id UUID;
  v_member_id UUID;
BEGIN
  v_creator_id := auth.uid();
  
  IF v_creator_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  
  IF array_length(member_ids, 1) < 2 THEN
    RAISE EXCEPTION 'Group chat requires at least 2 other members';
  END IF;
  
  -- Use is_group = TRUE (not room_type)
  INSERT INTO chat_rooms (name, is_group, created_by)
  VALUES (group_name, TRUE, v_creator_id)
  RETURNING id INTO v_room_id;
  
  -- Add creator as admin
  INSERT INTO room_members (room_id, user_id, is_admin, admin_order)
  VALUES (v_room_id, v_creator_id, TRUE, 1);
  
  -- Add other members
  FOREACH v_member_id IN ARRAY member_ids
  LOOP
    IF v_member_id != v_creator_id THEN
      INSERT INTO room_members (room_id, user_id, is_admin, admin_order)
      VALUES (v_room_id, v_member_id, FALSE, 999999)
      ON CONFLICT DO NOTHING;
    END IF;
  END LOOP;
  
  RETURN v_room_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.create_group_chat(p_name text, p_description text DEFAULT NULL::text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_room_id UUID;
  v_invite_code TEXT;
  v_user_id UUID;
BEGIN
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Generate unique invite code
  LOOP
    v_invite_code := upper(substring(md5(random()::text || clock_timestamp()::text) from 1 for 6));
    EXIT WHEN NOT EXISTS (SELECT 1 FROM chat_rooms WHERE invite_code = v_invite_code);
  END LOOP;

  -- Create room
  INSERT INTO chat_rooms (name, description, is_group, invite_code, created_by)
  VALUES (p_name, p_description, true, v_invite_code, v_user_id)
  RETURNING id INTO v_room_id;

  -- Add creator as admin
  INSERT INTO room_members (room_id, user_id, role)
  VALUES (v_room_id, v_user_id, 'admin');

  RETURN json_build_object(
    'room_id', v_room_id,
    'invite_code', v_invite_code
  );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.create_group_with_invite(group_name text, member_ids uuid[] DEFAULT ARRAY[]::uuid[], max_members_limit integer DEFAULT NULL::integer, expires_in_hours integer DEFAULT NULL::integer)
 RETURNS TABLE(room_id uuid, invite_code text, invite_url text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  new_room_id UUID;
  new_invite_code TEXT;
  current_user_id UUID;
  member_id UUID;
  member_count INT := 1; -- Creator counts as 1
  expires_at TIMESTAMP WITH TIME ZONE;
BEGIN
  current_user_id := auth.uid();
  
  IF current_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  
  -- Validate member limit
  IF max_members_limit IS NOT NULL AND max_members_limit < 2 THEN
    RAISE EXCEPTION 'Group must allow at least 2 members';
  END IF;
  
  -- Generate unique invite code
  new_invite_code := public.generate_invite_code();
  
  -- Calculate expiration
  IF expires_in_hours IS NOT NULL THEN
    expires_at := NOW() + (expires_in_hours || ' hours')::INTERVAL;
  END IF;
  
  -- Create group room
  INSERT INTO public.chat_rooms (name, is_group, created_by, invite_code, max_members, invite_link_enabled)
  VALUES (group_name, true, current_user_id, new_invite_code, max_members_limit, true)
  RETURNING id INTO new_room_id;
  
  -- Add creator as admin (admin_order = 1, first admin)
  INSERT INTO public.room_members (room_id, user_id, is_admin, admin_order)
  VALUES (new_room_id, current_user_id, true, 1);
  
  -- Add other members (if any)
  FOREACH member_id IN ARRAY member_ids
  LOOP
    IF member_id != current_user_id AND member_count < COALESCE(max_members_limit, 999999) THEN
      IF EXISTS (SELECT 1 FROM public.profiles WHERE id = member_id) THEN
        member_count := member_count + 1;
        
        INSERT INTO public.room_members (room_id, user_id, is_admin, admin_order)
        VALUES (new_room_id, member_id, false, member_count)
        ON CONFLICT DO NOTHING;
      END IF;
    END IF;
  END LOOP;
  
  -- Create invite link record
  INSERT INTO public.group_invite_links (room_id, invite_code, created_by, expires_at)
  VALUES (new_room_id, new_invite_code, current_user_id, expires_at);
  
  -- Return room info with invite link
  RETURN QUERY
  SELECT 
    new_room_id,
    new_invite_code,
    'https://deconnect.app/join/' || new_invite_code AS invite_url;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.create_private_chat(other_user_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  current_user_id UUID := auth.uid();
  existing_room_id UUID;
  new_room_id UUID;
BEGIN
  -- Security check: Must be authenticated
  IF current_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  
  -- Security check: Cannot chat with yourself
  IF current_user_id = other_user_id THEN
    RAISE EXCEPTION 'Cannot create chat with yourself';
  END IF;
  
  -- Security check: Other user must exist
  IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = other_user_id) THEN
    RAISE EXCEPTION 'User not found';
  END IF;
  
  -- Security check: Current user must exist and not be banned
  IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = current_user_id AND NOT is_banned) THEN
    RAISE EXCEPTION 'You are banned or your profile does not exist';
  END IF;
  
  -- Check if private chat already exists
  SELECT cr.id INTO existing_room_id
  FROM chat_rooms cr
  WHERE cr.is_group = false
  AND EXISTS (SELECT 1 FROM room_members rm WHERE rm.room_id = cr.id AND rm.user_id = current_user_id)
  AND EXISTS (SELECT 1 FROM room_members rm WHERE rm.room_id = cr.id AND rm.user_id = other_user_id)
  LIMIT 1;
  
  IF existing_room_id IS NOT NULL THEN
    RETURN existing_room_id;
  END IF;
  
  -- Create new private room
  INSERT INTO chat_rooms (is_group, created_by)
  VALUES (false, current_user_id)
  RETURNING id INTO new_room_id;
  
  -- Add both members
  INSERT INTO room_members (room_id, user_id, is_admin, admin_order)
  VALUES 
    (new_room_id, current_user_id, false, 999999),
    (new_room_id, other_user_id, false, 999999);
  
  RETURN new_room_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.delete_group_as_room_admin(target_room_id uuid)
 RETURNS TABLE(success boolean, message text)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_is_group BOOLEAN;
  v_room_name TEXT;
BEGIN
  -- Check if room exists and is a group
  SELECT is_group, name INTO v_is_group, v_room_name
  FROM public.chat_rooms
  WHERE id = target_room_id;
  
  IF v_is_group IS NULL THEN
    RETURN QUERY SELECT false, 'Room not found'::text;
    RETURN;
  END IF;
  
  IF NOT v_is_group THEN
    RETURN QUERY SELECT false, 'Cannot delete private chats with this function'::text;
    RETURN;
  END IF;
  
  -- Check if current user is ROOM ADMIN (not global admin!)
  IF NOT is_room_admin(target_room_id) THEN
    RETURN QUERY SELECT false, 'You are not an admin of this group'::text;
    RETURN;
  END IF;
  
  -- User IS room admin - proceed with deletion
  DELETE FROM public.typing_indicators WHERE room_id = target_room_id;
  DELETE FROM public.messages WHERE room_id = target_room_id;
  DELETE FROM public.room_members WHERE room_id = target_room_id;
  DELETE FROM public.chat_rooms WHERE id = target_room_id;
  
  RETURN QUERY SELECT true, ('Group deleted successfully!')::text;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.delete_message(message_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  msg_sender_id UUID;
  msg_room_id UUID;
  is_user_admin BOOLEAN;
BEGIN
  SELECT sender_id, room_id INTO msg_sender_id, msg_room_id FROM public.messages WHERE id = message_id AND deleted_at IS NULL;
  SELECT is_admin INTO is_user_admin FROM public.room_members WHERE room_id = msg_room_id AND user_id = auth.uid();
  IF msg_sender_id != auth.uid() AND NOT COALESCE(is_user_admin, false) THEN
    RAISE EXCEPTION 'You can only delete your own messages';
  END IF;
  UPDATE public.messages SET deleted_at = NOW(), content = '[Message deleted]' WHERE id = message_id;
  RETURN true;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.delete_my_account()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  current_user_id UUID;
BEGIN
  current_user_id := auth.uid();
  
  -- Log before deletion
  INSERT INTO public.system_logs (level, message, metadata)
  VALUES (
    'info',
    'User account deleted',
    jsonb_build_object('user_id', current_user_id)
  );
  
  -- Delete profile (CASCADE handles Posts + Comments + Messages)
  DELETE FROM public.profiles WHERE id = current_user_id;
  
  -- Note: Storage files must be deleted by client or separate trigger
END;
$function$
;

CREATE OR REPLACE FUNCTION public.delete_user_completely(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_deleted_posts INT;
    v_deleted_comments INT;
    v_deleted_messages INT;
BEGIN
    -- Check permissions
    IF auth.uid() != p_user_id AND 
       (SELECT role FROM public.profiles WHERE id = auth.uid()) != 'admin' THEN
        RAISE EXCEPTION 'Unauthorized: Can only delete your own account or be admin';
    END IF;
    
    -- Log start of deletion
    INSERT INTO public.system_logs (level, message, metadata, user_id)
    VALUES (
        'warning',
        'User deletion started',
        jsonb_build_object(
            'user_id', p_user_id,
            'initiated_by', auth.uid()
        ),
        p_user_id
    );
    
    -- Delete in order (foreign key constraints)
    DELETE FROM public.comments WHERE user_id = p_user_id;
    GET DIAGNOSTICS v_deleted_comments = ROW_COUNT;
    
    DELETE FROM public.messages WHERE sender_id = p_user_id;
    GET DIAGNOSTICS v_deleted_messages = ROW_COUNT;
    
    DELETE FROM public.room_members WHERE user_id = p_user_id;
    
    DELETE FROM public.posts WHERE user_id = p_user_id;
    GET DIAGNOSTICS v_deleted_posts = ROW_COUNT;
    
    DELETE FROM public.profiles WHERE id = p_user_id;
    
    -- Log completion
    INSERT INTO public.system_logs (level, message, metadata)
    VALUES (
        'critical',
        'User completely deleted',
        jsonb_build_object(
            'user_id', p_user_id,
            'deleted_posts', v_deleted_posts,
            'deleted_comments', v_deleted_comments,
            'deleted_messages', v_deleted_messages,
            'initiated_by', auth.uid(),
            'completed_at', NOW()
        )
    );
    
    RETURN jsonb_build_object(
        'success', true,
        'deleted_posts', v_deleted_posts,
        'deleted_comments', v_deleted_comments,
        'deleted_messages', v_deleted_messages
    );
    
EXCEPTION
    WHEN OTHERS THEN
        -- Log the error
        INSERT INTO public.system_logs (level, message, metadata, user_id)
        VALUES (
            'error',
            'User deletion failed',
            jsonb_build_object(
                'user_id', p_user_id,
                'error_message', SQLERRM,
                'error_detail', SQLSTATE
            ),
            p_user_id
        );
        
        RAISE;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.demote_from_admin(target_room_id uuid, target_user_id uuid)
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
    RAISE EXCEPTION 'Cannot demote in private chats';
  END IF;
  
  -- Security: Only room creator or system admin can demote
  IF auth.uid() != room_creator AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Only room creator or system admin can demote members';
  END IF;
  
  -- Cannot demote the room creator
  IF target_user_id = room_creator THEN
    RAISE EXCEPTION 'Cannot demote the room creator';
  END IF;
  
  -- Demote from admin
  UPDATE public.room_members
  SET is_admin = false
  WHERE room_id = target_room_id AND user_id = target_user_id;
  
  RETURN true;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.demote_room_admin(room_uuid uuid, target_user uuid)
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
    RAISE EXCEPTION 'Only room admins can demote members';
  END IF;
  
  -- Cannot demote the original creator (admin_order = 1)
  IF EXISTS (
    SELECT 1 FROM room_members 
    WHERE room_id = room_uuid 
    AND user_id = target_user 
    AND admin_order = 1
  ) THEN
    RAISE EXCEPTION 'Cannot demote the group creator';
  END IF;
  
  -- Demote the target user
  UPDATE room_members 
  SET is_admin = false, admin_order = 999999
  WHERE room_id = room_uuid AND user_id = target_user;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.edit_message(message_id uuid, new_content text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE msg_sender_id UUID;
BEGIN
  SELECT sender_id INTO msg_sender_id FROM public.messages WHERE id = message_id AND deleted_at IS NULL;
  IF msg_sender_id != auth.uid() THEN RAISE EXCEPTION 'You can only edit your own messages'; END IF;
  UPDATE public.messages SET content = new_content, edited_at = NOW() WHERE id = message_id;
  RETURN true;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.find_direct_chat(user1_id uuid, user2_id uuid)
 RETURNS TABLE(room_id uuid)
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN QUERY
  SELECT rm1.room_id
  FROM room_members rm1
  JOIN room_members rm2 ON rm1.room_id = rm2.room_id
  JOIN chat_rooms cr ON cr.id = rm1.room_id
  WHERE rm1.user_id = user1_id
    AND rm2.user_id = user2_id
    AND cr.is_group = false
  LIMIT 1;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.generate_invite_code()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
  chars TEXT := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  result TEXT := '';
BEGIN
  FOR i IN 1..8 LOOP
    result := result || substr(chars, floor(random() * 36 + 1)::int, 1);
  END LOOP;
  RETURN result;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_feed(page_size integer DEFAULT 20, page_offset integer DEFAULT 0, filter_tag text DEFAULT NULL::text)
 RETURNS TABLE(post_id uuid, title text, content text, image_url text, tags text[], created_at timestamp with time zone, user_id uuid, username text, avatar_url text, first_name text, last_name text, comment_count bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    RETURN QUERY
    SELECT
        p.id AS post_id,
        p.title,
        p.content,
        p.image_url,
        p.tags,
        p.created_at,
        p.user_id,
        pr.username,
        pr.avatar_url,
        pr.first_name,
        pr.last_name,
        (SELECT COUNT(*) FROM public.comments c WHERE c.post_id = p.id) AS comment_count
    FROM public.posts p
    JOIN public.profiles pr ON p.user_id = pr.id
    WHERE pr.is_banned = false
    AND (filter_tag IS NULL OR filter_tag = ANY(p.tags))
    ORDER BY p.created_at DESC
    LIMIT page_size
    OFFSET page_offset;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_invite_info(invite_code_input text)
 RETURNS TABLE(is_valid boolean, group_name text, member_count integer, max_members integer, creator_username text, expires_at timestamp with time zone, is_expired boolean, is_full boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_room_id UUID;
BEGIN
  SELECT gil.room_id INTO v_room_id
  FROM group_invite_links gil
  JOIN chat_rooms cr ON gil.room_id = cr.id
  WHERE UPPER(gil.invite_code) = UPPER(invite_code_input)
    AND gil.is_active = true
    AND cr.invite_link_enabled = true;

  IF v_room_id IS NULL THEN
    RETURN QUERY SELECT 
      false::BOOLEAN, NULL::TEXT, NULL::INTEGER, NULL::INTEGER,
      NULL::TEXT, NULL::TIMESTAMPTZ, NULL::BOOLEAN, NULL::BOOLEAN;
    RETURN;
  END IF;

  RETURN QUERY
  SELECT 
    true::BOOLEAN,
    cr.name::TEXT,
    (SELECT COUNT(*)::INTEGER FROM room_members rm WHERE rm.room_id = v_room_id),
    cr.max_members::INTEGER,
    p.username::TEXT,
    gil.expires_at,
    (gil.expires_at IS NOT NULL AND NOW() > gil.expires_at)::BOOLEAN,
    (cr.max_members IS NOT NULL AND (SELECT COUNT(*) FROM room_members rm WHERE rm.room_id = v_room_id) >= cr.max_members)::BOOLEAN
  FROM group_invite_links gil
  JOIN chat_rooms cr ON gil.room_id = cr.id
  LEFT JOIN profiles p ON gil.created_by = p.id
  WHERE gil.room_id = v_room_id
    AND UPPER(gil.invite_code) = UPPER(invite_code_input);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_last_messages(room_ids uuid[])
 RETURNS TABLE(room_id uuid, content text, media_url text, media_type text, created_at timestamp with time zone)
 LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN QUERY
  SELECT DISTINCT ON (m.room_id)
    m.room_id,
    m.content,
    m.media_url,
    m.media_type,
    m.created_at
  FROM messages m
  WHERE m.room_id = ANY(room_ids)
  ORDER BY m.room_id, m.created_at DESC;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_my_groups()
 RETURNS TABLE(room_id uuid, room_name text, description text, avatar_url text, invite_code text, member_count bigint, is_admin boolean, created_at timestamp with time zone, created_by uuid, last_message text, last_message_time timestamp with time zone, unread_count bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  RETURN QUERY
  SELECT
    cr.id, 
    cr.name, 
    cr.description, 
    cr.avatar_url,
    CASE WHEN rm.role = 'admin' THEN cr.invite_code ELSE NULL END,
    (SELECT COUNT(*) FROM room_members WHERE room_members.room_id = cr.id),
    rm.role = 'admin',
    cr.created_at,
    cr.created_by,
    (SELECT m.content FROM messages m WHERE m.room_id = cr.id AND m.is_deleted = FALSE ORDER BY m.created_at DESC LIMIT 1),
    (SELECT m.created_at FROM messages m WHERE m.room_id = cr.id AND m.is_deleted = FALSE ORDER BY m.created_at DESC LIMIT 1),
    (SELECT COUNT(*) FROM messages m WHERE m.room_id = cr.id AND m.sender_id != auth.uid() AND m.is_read = FALSE AND m.is_deleted = FALSE)
  FROM chat_rooms cr
  JOIN room_members rm ON rm.room_id = cr.id
  WHERE rm.user_id = auth.uid() AND cr.is_group = TRUE
  ORDER BY last_message_time DESC NULLS LAST;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_my_room_ids()
 RETURNS SETOF uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  SELECT room_id FROM public.room_members WHERE user_id = auth.uid();
$function$
;

CREATE OR REPLACE FUNCTION public.get_post_comments(target_post_id uuid)
 RETURNS TABLE(comment_id uuid, content text, created_at timestamp with time zone, user_id uuid, username text, avatar_url text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  RETURN QUERY
  SELECT 
    c.id AS comment_id,
    c.content,
    c.created_at,
    c.user_id,
    prof.username,
    prof.avatar_url
  FROM public.comments c
  JOIN public.profiles prof ON c.user_id = prof.id
  WHERE c.post_id = target_post_id
  ORDER BY c.created_at ASC;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_private_chat_id(user1 uuid, user2 uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  existing_room_id UUID;
BEGIN
  -- Look for existing private chat between these two users
  SELECT cr.id INTO existing_room_id
  FROM public.chat_rooms cr
  WHERE cr.is_group = false
    AND EXISTS (
      SELECT 1 FROM public.room_members rm1
      WHERE rm1.room_id = cr.id AND rm1.user_id = user1
    )
    AND EXISTS (
      SELECT 1 FROM public.room_members rm2
      WHERE rm2.room_id = cr.id AND rm2.user_id = user2
    )
    AND (
      SELECT COUNT(*) FROM public.room_members
      WHERE room_id = cr.id
    ) = 2
  LIMIT 1;
  
  RETURN existing_room_id;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_room_members(target_room_id uuid)
 RETURNS TABLE(user_id uuid, username text, avatar_url text, is_admin boolean, joined_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  -- Must be logged in
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Must be a member of the room
  IF NOT EXISTS (
    SELECT 1 FROM public.room_members rm
    WHERE rm.room_id = target_room_id
      AND rm.user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'You are not a member of this room';
  END IF;

  RETURN QUERY
  SELECT
    rm.user_id,
    p.username,
    p.avatar_url,
    rm.is_admin,
    rm.joined_at
  FROM public.room_members rm
  JOIN public.profiles p ON p.id = rm.user_id
  WHERE rm.room_id = target_room_id
  ORDER BY rm.is_admin DESC, rm.joined_at ASC;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_user_chat_rooms()
 RETURNS TABLE(room_id uuid, room_name text, is_group boolean, last_message text, last_message_time timestamp with time zone, last_message_sender text, unread_count bigint, room_avatar text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  RETURN QUERY
  SELECT
    cr.id AS room_id,
    CASE 
      WHEN cr.is_group THEN cr.name
      ELSE (
        SELECT pr.username FROM public.profiles pr
        JOIN public.room_members rm2 ON pr.id = rm2.user_id
        WHERE rm2.room_id = cr.id AND rm2.user_id != auth.uid()
        LIMIT 1
      )
    END AS room_name,
    cr.is_group,
    (SELECT m.content FROM public.messages m WHERE m.room_id = cr.id AND m.deleted_at IS NULL ORDER BY m.created_at DESC LIMIT 1) AS last_message,
    (SELECT m.created_at FROM public.messages m WHERE m.room_id = cr.id AND m.deleted_at IS NULL ORDER BY m.created_at DESC LIMIT 1) AS last_message_time,
    (SELECT pr.username FROM public.messages m JOIN public.profiles pr ON m.sender_id = pr.id WHERE m.room_id = cr.id AND m.deleted_at IS NULL ORDER BY m.created_at DESC LIMIT 1) AS last_message_sender,
    (SELECT COUNT(*) FROM public.messages m WHERE m.room_id = cr.id AND m.sender_id != auth.uid() AND m.deleted_at IS NULL AND m.status != 'read') AS unread_count,
    CASE WHEN cr.is_group THEN NULL
    ELSE (SELECT pr.avatar_url FROM public.profiles pr JOIN public.room_members rm2 ON pr.id = rm2.user_id WHERE rm2.room_id = cr.id AND rm2.user_id != auth.uid() LIMIT 1)
    END AS room_avatar
  FROM public.chat_rooms cr
  JOIN public.room_members rm ON cr.id = rm.room_id
  WHERE rm.user_id = auth.uid()
  ORDER BY last_message_time DESC NULLS LAST;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_user_comment_count(target_user_id uuid)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  RETURN (
    SELECT COUNT(*)
    FROM public.comments
    WHERE user_id = target_user_id
  );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_user_post_count(target_user_id uuid)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  RETURN (
    SELECT COUNT(*)
    FROM public.posts
    WHERE user_id = target_user_id
  );
END;
$function$
;


grant insert on table "public"."call_participants" to "anon";

grant references on table "public"."call_participants" to "anon";

grant select on table "public"."call_participants" to "anon";

grant trigger on table "public"."call_participants" to "anon";

grant truncate on table "public"."call_participants" to "anon";

grant update on table "public"."call_participants" to "anon";

grant delete on table "public"."call_participants" to "authenticated";

grant insert on table "public"."call_participants" to "authenticated";

grant references on table "public"."call_participants" to "authenticated";

grant select on table "public"."call_participants" to "authenticated";

grant trigger on table "public"."call_participants" to "authenticated";

grant truncate on table "public"."call_participants" to "authenticated";

grant update on table "public"."call_participants" to "authenticated";

grant delete on table "public"."call_participants" to "service_role";

grant insert on table "public"."call_participants" to "service_role";

grant references on table "public"."call_participants" to "service_role";

grant select on table "public"."call_participants" to "service_role";

grant trigger on table "public"."call_participants" to "service_role";

grant truncate on table "public"."call_participants" to "service_role";

grant update on table "public"."call_participants" to "service_role";

grant delete on table "public"."calls" to "anon";

grant insert on table "public"."calls" to "anon";

grant references on table "public"."calls" to "anon";

grant select on table "public"."calls" to "anon";

grant trigger on table "public"."calls" to "anon";

grant truncate on table "public"."calls" to "anon";

grant update on table "public"."calls" to "anon";

grant delete on table "public"."calls" to "authenticated";

grant insert on table "public"."calls" to "authenticated";
