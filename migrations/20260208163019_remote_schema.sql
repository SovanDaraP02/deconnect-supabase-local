-- ============================================================================
-- EXTENSIONS AND SETUP
-- ============================================================================
--
-- PostgreSQL extensions required for DeConnect
--
-- Part of DeConnect Database Schema
-- Apply migrations in numerical order
--
-- ============================================================================

create extension if not exists "pg_cron" with schema "pg_catalog";

drop extension if exists "pg_net";



-- ============================================================================
-- DATABASE TABLES
-- ============================================================================
--
-- All table definitions, constraints, and RLS enablement
--
-- Part of DeConnect Database Schema
-- Apply migrations in numerical order
--
-- ============================================================================

  create table "public"."call_participants" (
    "id" uuid not null default gen_random_uuid(),
    "call_id" uuid,
    "user_id" uuid,
    "status" text default 'ringing'::text,
    "joined_at" timestamp with time zone,
    "left_at" timestamp with time zone,
    "created_at" timestamp with time zone default now()
      );

  create table "public"."calls" (
    "id" uuid not null default gen_random_uuid(),
    "room_id" uuid,
    "caller_id" uuid,
    "callee_id" uuid,
    "call_type" character varying(10),
    "status" character varying(20),
    "started_at" timestamp with time zone default now(),
    "answered_at" timestamp with time zone,
    "ended_at" timestamp with time zone,
    "duration" integer,
    "channel_name" character varying(255),
    "created_at" timestamp with time zone default now(),
    "caller_username" text,
    "caller_avatar" text,
    "is_group_call" boolean default false,
    "room_name" text,
    "group_name" text
      );

alter table "public"."calls" enable row level security;

  create table "public"."chat_rooms" (
    "id" uuid not null default gen_random_uuid(),
    "name" text,
    "is_group" boolean not null default false,
    "created_by" uuid,
    "created_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now(),
    "invite_code" text,
    "max_members" integer,
    "invite_link_enabled" boolean not null default true,
    "invite_expires_at" timestamp with time zone,
    "description" text,
    "avatar_url" text
      );

alter table "public"."chat_rooms" enable row level security;

  create table "public"."comments" (
    "id" uuid not null default gen_random_uuid(),
    "post_id" uuid not null,
    "user_id" uuid not null,
    "content" text not null,
    "created_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now()
      );

alter table "public"."comments" enable row level security;

  create table "public"."group_invite_links" (
    "id" uuid not null default gen_random_uuid(),
    "room_id" uuid not null,
    "invite_code" text not null,
    "created_by" uuid,
    "uses_count" integer not null default 0,
    "max_uses" integer,
    "expires_at" timestamp with time zone,
    "is_active" boolean not null default true,
    "created_at" timestamp with time zone default now(),
    "last_used_at" timestamp with time zone
      );

alter table "public"."group_invite_links" enable row level security;

  create table "public"."messages" (
    "id" uuid not null default gen_random_uuid(),
    "room_id" uuid not null,
    "sender_id" uuid not null,
    "content" text not null,
    "media_url" text,
    "is_read" boolean not null default false,
    "created_at" timestamp with time zone default now(),
    "status" text default 'sent'::text,
    "edited_at" timestamp with time zone,
    "deleted_at" timestamp with time zone,
    "reply_to_id" uuid,
    "media_type" text,
    "file_name" text,
    "read_at" timestamp with time zone,
    "is_edited" boolean default false,
    "is_deleted" boolean default false,
    "is_system_message" boolean default false,
    "audio_duration" integer
      );

alter table "public"."messages" enable row level security;

  create table "public"."posts" (
    "id" uuid not null default gen_random_uuid(),
    "user_id" uuid not null,
    "content" text not null,
    "image_url" text,
    "created_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now(),
    "tags" text[] default ARRAY[]::text[],
    "title" text not null default 'Untitled Post'::text
      );

alter table "public"."posts" enable row level security;

  create table "public"."profiles" (
    "id" uuid not null,
    "username" text not null,
    "avatar_url" text,
    "role" text default 'user'::text,
    "is_banned" boolean not null default false,
    "created_at" timestamp with time zone default now(),
    "updated_at" timestamp with time zone default now(),
    "push_enabled" boolean not null default true,
    "bio" text default ''::text,
    "email" text,
    "first_name" text,
    "last_name" text,
    "gender" text,
    "mobile_number" text,
    "last_login_at" timestamp with time zone,
    "last_seen" timestamp with time zone default now(),
    "is_online" boolean default false,
    "last_feed_check" timestamp with time zone
      );

alter table "public"."profiles" enable row level security;

  create table "public"."room_members" (
    "room_id" uuid not null,
    "user_id" uuid not null,
    "joined_at" timestamp with time zone default now(),
    "last_read_at" timestamp with time zone default now(),
    "is_admin" boolean not null default false,
    "admin_order" integer default 999999,
    "role" character varying(20) default 'member'::character varying
      );

alter table "public"."room_members" enable row level security;

  create table "public"."system_logs" (
    "id" uuid not null default gen_random_uuid(),
    "level" text not null,
    "message" text not null,
    "metadata" jsonb default '{}'::jsonb,
    "user_id" uuid,
    "created_at" timestamp with time zone default now()
      );

alter table "public"."system_logs" enable row level security;

  create table "public"."typing_indicators" (
    "id" uuid not null default gen_random_uuid(),
    "room_id" uuid not null,
    "user_id" uuid not null,
    "is_typing" boolean default true,
    "started_at" timestamp with time zone default now()
      );

alter table "public"."typing_indicators" enable row level security;

alter table "public"."call_participants" add constraint "call_participants_pkey" PRIMARY KEY ("id");

alter table "public"."calls" add constraint "calls_pkey" PRIMARY KEY ("id");

alter table "public"."chat_rooms" add constraint "chat_rooms_pkey" PRIMARY KEY ("id");

alter table "public"."comments" add constraint "comments_pkey" PRIMARY KEY ("id");

alter table "public"."group_invite_links" add constraint "group_invite_links_pkey" PRIMARY KEY ("id");

alter table "public"."messages" add constraint "messages_pkey" PRIMARY KEY ("id");

alter table "public"."posts" add constraint "posts_pkey" PRIMARY KEY ("id");

alter table "public"."profiles" add constraint "profiles_pkey" PRIMARY KEY ("id");

alter table "public"."room_members" add constraint "room_members_pkey" PRIMARY KEY ("room_id", "user_id");

alter table "public"."system_logs" add constraint "system_logs_pkey" PRIMARY KEY ("id");

alter table "public"."typing_indicators" add constraint "typing_indicators_pkey" PRIMARY KEY ("id");

alter table "public"."call_participants" add constraint "call_participants_call_id_fkey" FOREIGN KEY (call_id) REFERENCES public.calls(id) ON DELETE CASCADE not valid;

alter table "public"."call_participants" add constraint "call_participants_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE not valid;

alter table "public"."calls" add constraint "calls_call_type_check" CHECK (((call_type)::text = ANY ((ARRAY['voice'::character varying, 'video'::character varying])::text[]))) not valid;

alter table "public"."calls" add constraint "calls_callee_id_fkey" FOREIGN KEY (callee_id) REFERENCES public.profiles(id) ON DELETE CASCADE not valid;

alter table "public"."calls" add constraint "calls_caller_id_fkey" FOREIGN KEY (caller_id) REFERENCES public.profiles(id) ON DELETE CASCADE not valid;

alter table "public"."calls" add constraint "calls_room_id_fkey" FOREIGN KEY (room_id) REFERENCES public.chat_rooms(id) ON DELETE CASCADE not valid;

alter table "public"."calls" add constraint "calls_status_check" CHECK (((status)::text = ANY ((ARRAY['ringing'::character varying, 'answered'::character varying, 'declined'::character varying, 'missed'::character varying, 'ended'::character varying])::text[]))) not valid;

alter table "public"."chat_rooms" add constraint "chat_rooms_created_by_fkey" FOREIGN KEY (created_by) REFERENCES public.profiles(id) ON DELETE SET NULL not valid;

alter table "public"."chat_rooms" add constraint "chat_rooms_invite_code_key" UNIQUE ("invite_code");

alter table "public"."comments" add constraint "comments_content_check" CHECK (((char_length(content) > 0) AND (char_length(content) <= 1000))) not valid;

alter table "public"."comments" add constraint "comments_content_not_empty" CHECK ((TRIM(BOTH FROM content) <> ''::text)) not valid;

alter table "public"."comments" add constraint "comments_post_id_fkey" FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE not valid;

alter table "public"."comments" add constraint "comments_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE not valid;

alter table "public"."group_invite_links" add constraint "group_invite_links_created_by_fkey" FOREIGN KEY (created_by) REFERENCES public.profiles(id) ON DELETE SET NULL not valid;

alter table "public"."group_invite_links" add constraint "group_invite_links_invite_code_key" UNIQUE ("invite_code");

alter table "public"."group_invite_links" add constraint "group_invite_links_room_id_fkey" FOREIGN KEY (room_id) REFERENCES public.chat_rooms(id) ON DELETE CASCADE not valid;

alter table "public"."messages" add constraint "messages_reply_to_id_fkey" FOREIGN KEY (reply_to_id) REFERENCES public.messages(id) not valid;

alter table "public"."messages" add constraint "messages_room_id_fkey" FOREIGN KEY (room_id) REFERENCES public.chat_rooms(id) ON DELETE CASCADE not valid;

alter table "public"."messages" add constraint "messages_sender_id_fkey" FOREIGN KEY (sender_id) REFERENCES public.profiles(id) ON DELETE CASCADE not valid;

alter table "public"."messages" add constraint "messages_status_check" CHECK ((status = ANY (ARRAY['sending'::text, 'sent'::text, 'delivered'::text, 'read'::text, 'failed'::text]))) not valid;

alter table "public"."posts" add constraint "posts_content_check" CHECK (((char_length(content) > 0) AND (char_length(content) <= 5000))) not valid;

alter table "public"."posts" add constraint "posts_content_not_empty" CHECK ((TRIM(BOTH FROM content) <> ''::text)) not valid;

alter table "public"."posts" add constraint "posts_title_check" CHECK (((char_length(title) > 0) AND (char_length(title) <= 200))) not valid;

alter table "public"."posts" add constraint "posts_title_not_empty" CHECK ((TRIM(BOTH FROM title) <> ''::text)) not valid;

alter table "public"."posts" add constraint "posts_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE not valid;

alter table "public"."profiles" add constraint "profiles_bio_check" CHECK ((char_length(bio) <= 500)) not valid;

alter table "public"."profiles" add constraint "profiles_gender_check" CHECK ((gender = ANY (ARRAY['male'::text, 'female'::text, 'other'::text, NULL::text]))) not valid;

alter table "public"."profiles" add constraint "profiles_id_fkey" FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."profiles" add constraint "profiles_role_check" CHECK ((role = ANY (ARRAY['user'::text, 'admin'::text]))) not valid;

alter table "public"."profiles" add constraint "profiles_username_key" UNIQUE ("username");

alter table "public"."room_members" add constraint "room_members_room_id_fkey" FOREIGN KEY (room_id) REFERENCES public.chat_rooms(id) ON DELETE CASCADE not valid;

alter table "public"."room_members" add constraint "room_members_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE not valid;

alter table "public"."system_logs" add constraint "system_logs_level_check" CHECK ((level = ANY (ARRAY['info'::text, 'warning'::text, 'error'::text, 'critical'::text]))) not valid;

alter table "public"."system_logs" add constraint "system_logs_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE SET NULL not valid;

alter table "public"."typing_indicators" add constraint "typing_indicators_room_id_fkey" FOREIGN KEY (room_id) REFERENCES public.chat_rooms(id) ON DELETE CASCADE not valid;

alter table "public"."typing_indicators" add constraint "typing_indicators_room_id_user_id_key" UNIQUE ("room_id", "user_id");
public"."profiles" add constraint "profiles_username_key" UNIQUE ("username");

alter table "public"."typing_indicators" add constraint "typing_indicators_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE not valid;



-- ============================================================================
-- DATABASE INDEXES
-- ============================================================================
--
-- Performance indexes for all tables
--
-- Part of DeConnect Database Schema
-- Apply migrations in numerical order
--
-- ============================================================================

CREATE INDEX chat_rooms_created_by_idx ON public.chat_rooms USING btree (created_by);
CREATE INDEX chat_rooms_invite_code_idx ON public.chat_rooms USING btree (invite_code);
CREATE INDEX chat_rooms_is_group_idx ON public.chat_rooms USING btree (is_group);
CREATE INDEX comments_created_at_idx ON public.comments USING btree (created_at DESC);
CREATE INDEX comments_post_id_created_at_idx ON public.comments USING btree (post_id, created_at DESC);
CREATE INDEX comments_post_id_idx ON public.comments USING btree (post_id);
CREATE INDEX comments_user_id_idx ON public.comments USING btree (user_id);
CREATE INDEX group_invite_links_invite_code_idx ON public.group_invite_links USING btree (invite_code);
CREATE INDEX group_invite_links_is_active_idx ON public.group_invite_links USING btree (is_active);
CREATE INDEX group_invite_links_room_id_idx ON public.group_invite_links USING btree (room_id);
CREATE INDEX idx_calls_callee_id ON public.calls USING btree (callee_id);
CREATE INDEX idx_calls_caller_id ON public.calls USING btree (caller_id);
CREATE INDEX idx_calls_room_id ON public.calls USING btree (room_id);
CREATE INDEX idx_chat_rooms_invite_code ON public.chat_rooms USING btree (invite_code);
CREATE INDEX idx_chat_rooms_is_group ON public.chat_rooms USING btree (is_group);
CREATE INDEX idx_messages_system ON public.messages USING btree (room_id, is_system_message);
CREATE INDEX idx_profiles_is_online ON public.profiles USING btree (is_online);
CREATE INDEX idx_profiles_last_seen ON public.profiles USING btree (last_seen);
CREATE INDEX idx_room_members_role ON public.room_members USING btree (role);
CREATE UNIQUE INDEX idx_unique_group_name_per_user ON public.chat_rooms USING btree (created_by, name) WHERE ((is_group = true) AND (name IS NOT NULL));
CREATE INDEX messages_created_at_idx ON public.messages USING btree (created_at DESC);
CREATE INDEX messages_deleted_at_idx ON public.messages USING btree (deleted_at);
CREATE INDEX messages_is_read_idx ON public.messages USING btree (is_read);
CREATE INDEX messages_room_id_created_at_idx ON public.messages USING btree (room_id, created_at DESC);
CREATE INDEX messages_room_id_idx ON public.messages USING btree (room_id);
CREATE INDEX messages_sender_id_idx ON public.messages USING btree (sender_id);
CREATE INDEX messages_status_idx ON public.messages USING btree (status);
CREATE INDEX posts_created_at_idx ON public.posts USING btree (created_at DESC);
CREATE INDEX posts_created_at_user_id_idx ON public.posts USING btree (created_at DESC, user_id);
CREATE INDEX posts_tags_idx ON public.posts USING gin (tags);
CREATE INDEX posts_user_id_idx ON public.posts USING btree (user_id);
CREATE INDEX profiles_email_idx ON public.profiles USING btree (email);
CREATE INDEX profiles_is_banned_idx ON public.profiles USING btree (is_banned);
CREATE INDEX profiles_role_idx ON public.profiles USING btree (role);
CREATE INDEX profiles_username_idx ON public.profiles USING btree (username);
CREATE INDEX room_members_admin_order_idx ON public.room_members USING btree (admin_order);
CREATE INDEX room_members_is_admin_idx ON public.room_members USING btree (is_admin);
CREATE INDEX room_members_room_id_idx ON public.room_members USING btree (room_id);
CREATE INDEX room_members_user_id_idx ON public.room_members USING btree (user_id);
CREATE INDEX room_members_user_id_room_id_idx ON public.room_members USING btree (user_id, room_id);
CREATE INDEX system_logs_created_at_idx ON public.system_logs USING btree (created_at DESC);
CREATE INDEX system_logs_level_created_at_idx ON public.system_logs USING btree (level, created_at DESC);
CREATE INDEX system_logs_level_idx ON public.system_logs USING btree (level);
CREATE INDEX system_logs_user_id_idx ON public.system_logs USING btree (user_id);

-- ============================================================================
-- RPC FUNCTIONS (BUSINESS LOGIC)
-- ============================================================================
--
-- Application-callable business logic functions
--
-- Part of DeConnect Database Schema
-- Apply migrations in numerical order
--
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

grant delete on table "public"."call_participants" to "anon";

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

grant references on table "public"."calls" to "authenticated";

grant select on table "public"."calls" to "authenticated";

grant trigger on table "public"."calls" to "authenticated";

grant truncate on table "public"."calls" to "authenticated";

grant update on table "public"."calls" to "authenticated";

grant delete on table "public"."calls" to "service_role";

grant insert on table "public"."calls" to "service_role";

grant references on table "public"."calls" to "service_role";

grant select on table "public"."calls" to "service_role";

grant trigger on table "public"."calls" to "service_role";

grant truncate on table "public"."calls" to "service_role";

grant update on table "public"."calls" to "service_role";

grant delete on table "public"."chat_rooms" to "anon";

grant insert on table "public"."chat_rooms" to "anon";

grant references on table "public"."chat_rooms" to "anon";

grant select on table "public"."chat_rooms" to "anon";

grant trigger on table "public"."chat_rooms" to "anon";

grant truncate on table "public"."chat_rooms" to "anon";

grant update on table "public"."chat_rooms" to "anon";

grant delete on table "public"."chat_rooms" to "authenticated";

grant insert on table "public"."chat_rooms" to "authenticated";

grant references on table "public"."chat_rooms" to "authenticated";

grant select on table "public"."chat_rooms" to "authenticated";

grant trigger on table "public"."chat_rooms" to "authenticated";

grant truncate on table "public"."chat_rooms" to "authenticated";

grant update on table "public"."chat_rooms" to "authenticated";

grant delete on table "public"."chat_rooms" to "service_role";

grant insert on table "public"."chat_rooms" to "service_role";

grant references on table "public"."chat_rooms" to "service_role";

grant select on table "public"."chat_rooms" to "service_role";

grant trigger on table "public"."chat_rooms" to "service_role";

grant truncate on table "public"."chat_rooms" to "service_role";

grant update on table "public"."chat_rooms" to "service_role";

grant delete on table "public"."comments" to "anon";

grant insert on table "public"."comments" to "anon";

grant references on table "public"."comments" to "anon";

grant select on table "public"."comments" to "anon";

grant trigger on table "public"."comments" to "anon";

grant truncate on table "public"."comments" to "anon";

grant update on table "public"."comments" to "anon";

grant delete on table "public"."comments" to "authenticated";

grant insert on table "public"."comments" to "authenticated";

grant references on table "public"."comments" to "authenticated";

grant select on table "public"."comments" to "authenticated";

grant trigger on table "public"."comments" to "authenticated";

grant truncate on table "public"."comments" to "authenticated";

grant update on table "public"."comments" to "authenticated";

grant delete on table "public"."comments" to "service_role";

grant insert on table "public"."comments" to "service_role";

grant references on table "public"."comments" to "service_role";

grant select on table "public"."comments" to "service_role";

grant trigger on table "public"."comments" to "service_role";

grant truncate on table "public"."comments" to "service_role";

grant update on table "public"."comments" to "service_role";

grant delete on table "public"."group_invite_links" to "anon";

grant insert on table "public"."group_invite_links" to "anon";

grant references on table "public"."group_invite_links" to "anon";

grant select on table "public"."group_invite_links" to "anon";

grant trigger on table "public"."group_invite_links" to "anon";

grant truncate on table "public"."group_invite_links" to "anon";

grant update on table "public"."group_invite_links" to "anon";

grant delete on table "public"."group_invite_links" to "authenticated";

grant insert on table "public"."group_invite_links" to "authenticated";

grant references on table "public"."group_invite_links" to "authenticated";

grant select on table "public"."group_invite_links" to "authenticated";

grant trigger on table "public"."group_invite_links" to "authenticated";

grant truncate on table "public"."group_invite_links" to "authenticated";

grant update on table "public"."group_invite_links" to "authenticated";

grant delete on table "public"."group_invite_links" to "service_role";

grant insert on table "public"."group_invite_links" to "service_role";

grant references on table "public"."group_invite_links" to "service_role";

grant select on table "public"."group_invite_links" to "service_role";

grant trigger on table "public"."group_invite_links" to "service_role";

grant truncate on table "public"."group_invite_links" to "service_role";

grant update on table "public"."group_invite_links" to "service_role";

grant delete on table "public"."messages" to "anon";

grant insert on table "public"."messages" to "anon";

grant references on table "public"."messages" to "anon";

grant select on table "public"."messages" to "anon";

grant trigger on table "public"."messages" to "anon";

grant truncate on table "public"."messages" to "anon";

grant update on table "public"."messages" to "anon";

grant delete on table "public"."messages" to "authenticated";

grant insert on table "public"."messages" to "authenticated";

grant references on table "public"."messages" to "authenticated";

grant select on table "public"."messages" to "authenticated";

grant trigger on table "public"."messages" to "authenticated";

grant truncate on table "public"."messages" to "authenticated";

grant update on table "public"."messages" to "authenticated";

grant delete on table "public"."messages" to "service_role";

grant insert on table "public"."messages" to "service_role";

grant references on table "public"."messages" to "service_role";

grant select on table "public"."messages" to "service_role";

grant trigger on table "public"."messages" to "service_role";

grant truncate on table "public"."messages" to "service_role";

grant update on table "public"."messages" to "service_role";

grant delete on table "public"."posts" to "anon";

grant insert on table "public"."posts" to "anon";

grant references on table "public"."posts" to "anon";

grant select on table "public"."posts" to "anon";

grant trigger on table "public"."posts" to "anon";

grant truncate on table "public"."posts" to "anon";

grant update on table "public"."posts" to "anon";

grant delete on table "public"."posts" to "authenticated";

grant insert on table "public"."posts" to "authenticated";

grant references on table "public"."posts" to "authenticated";

grant select on table "public"."posts" to "authenticated";

grant trigger on table "public"."posts" to "authenticated";

grant truncate on table "public"."posts" to "authenticated";

grant update on table "public"."posts" to "authenticated";

grant delete on table "public"."posts" to "service_role";

grant insert on table "public"."posts" to "service_role";

grant references on table "public"."posts" to "service_role";

grant select on table "public"."posts" to "service_role";

grant trigger on table "public"."posts" to "service_role";

grant truncate on table "public"."posts" to "service_role";

grant update on table "public"."posts" to "service_role";

grant delete on table "public"."profiles" to "anon";

grant insert on table "public"."profiles" to "anon";

grant references on table "public"."profiles" to "anon";

grant select on table "public"."profiles" to "anon";

grant trigger on table "public"."profiles" to "anon";

grant truncate on table "public"."profiles" to "anon";

grant update on table "public"."profiles" to "anon";

grant delete on table "public"."profiles" to "authenticated";

grant insert on table "public"."profiles" to "authenticated";

grant references on table "public"."profiles" to "authenticated";

grant select on table "public"."profiles" to "authenticated";

grant trigger on table "public"."profiles" to "authenticated";

grant truncate on table "public"."profiles" to "authenticated";

grant update on table "public"."profiles" to "authenticated";

grant delete on table "public"."profiles" to "service_role";

grant insert on table "public"."profiles" to "service_role";

grant references on table "public"."profiles" to "service_role";

grant select on table "public"."profiles" to "service_role";

grant trigger on table "public"."profiles" to "service_role";

grant truncate on table "public"."profiles" to "service_role";

grant update on table "public"."profiles" to "service_role";

grant delete on table "public"."room_members" to "anon";

grant insert on table "public"."room_members" to "anon";

grant references on table "public"."room_members" to "anon";

grant select on table "public"."room_members" to "anon";

grant trigger on table "public"."room_members" to "anon";

grant truncate on table "public"."room_members" to "anon";

grant update on table "public"."room_members" to "anon";

grant delete on table "public"."room_members" to "authenticated";

grant insert on table "public"."room_members" to "authenticated";

grant references on table "public"."room_members" to "authenticated";

grant select on table "public"."room_members" to "authenticated";

grant trigger on table "public"."room_members" to "authenticated";

grant truncate on table "public"."room_members" to "authenticated";

grant update on table "public"."room_members" to "authenticated";

grant delete on table "public"."room_members" to "service_role";

grant insert on table "public"."room_members" to "service_role";

grant references on table "public"."room_members" to "service_role";

grant select on table "public"."room_members" to "service_role";

grant trigger on table "public"."room_members" to "service_role";

grant truncate on table "public"."room_members" to "service_role";

grant update on table "public"."room_members" to "service_role";

grant delete on table "public"."system_logs" to "anon";

grant insert on table "public"."system_logs" to "anon";

grant references on table "public"."system_logs" to "anon";

grant select on table "public"."system_logs" to "anon";

grant trigger on table "public"."system_logs" to "anon";

grant truncate on table "public"."system_logs" to "anon";

grant update on table "public"."system_logs" to "anon";

grant delete on table "public"."system_logs" to "authenticated";

grant insert on table "public"."system_logs" to "authenticated";

grant references on table "public"."system_logs" to "authenticated";

grant select on table "public"."system_logs" to "authenticated";

grant trigger on table "public"."system_logs" to "authenticated";

grant truncate on table "public"."system_logs" to "authenticated";

grant update on table "public"."system_logs" to "authenticated";

grant delete on table "public"."system_logs" to "service_role";

grant insert on table "public"."system_logs" to "service_role";

grant references on table "public"."system_logs" to "service_role";

grant select on table "public"."system_logs" to "service_role";

grant trigger on table "public"."system_logs" to "service_role";

grant truncate on table "public"."system_logs" to "service_role";

grant update on table "public"."system_logs" to "service_role";

grant delete on table "public"."typing_indicators" to "anon";

grant insert on table "public"."typing_indicators" to "anon";

grant references on table "public"."typing_indicators" to "anon";

grant select on table "public"."typing_indicators" to "anon";

grant trigger on table "public"."typing_indicators" to "anon";

grant truncate on table "public"."typing_indicators" to "anon";

grant update on table "public"."typing_indicators" to "anon";

grant delete on table "public"."typing_indicators" to "authenticated";

grant insert on table "public"."typing_indicators" to "authenticated";

grant references on table "public"."typing_indicators" to "authenticated";

grant select on table "public"."typing_indicators" to "authenticated";

grant trigger on table "public"."typing_indicators" to "authenticated";

grant truncate on table "public"."typing_indicators" to "authenticated";

grant update on table "public"."typing_indicators" to "authenticated";

grant delete on table "public"."typing_indicators" to "service_role";

grant insert on table "public"."typing_indicators" to "service_role";

grant references on table "public"."typing_indicators" to "service_role";

grant select on table "public"."typing_indicators" to "service_role";

grant trigger on table "public"."typing_indicators" to "service_role";

grant truncate on table "public"."typing_indicators" to "service_role";

grant update on table "public"."typing_indicators" to "service_role";


  create policy "Users can create calls"
  on "public"."calls"
  as permissive
  for insert
  to public
with check ((auth.uid() = caller_id));



  create policy "Users can insert calls"
  on "public"."calls"
  as permissive
  for insert
  to public
with check ((auth.uid() = caller_id));



  create policy "Users can see their own calls"
  on "public"."calls"
  as permissive
  for select
  to public
using (((auth.uid() = caller_id) OR (auth.uid() = callee_id)));



  create policy "Users can update their calls"
  on "public"."calls"
  as permissive
  for update
  to public
using (((auth.uid() = caller_id) OR (auth.uid() = callee_id)));



  create policy "Users can update their own calls"
  on "public"."calls"
  as permissive
  for update
  to public
using (((auth.uid() = caller_id) OR (auth.uid() = callee_id)));



  create policy "Users can view their own calls"
  on "public"."calls"
  as permissive
  for select
  to public
using (((auth.uid() = caller_id) OR (auth.uid() = callee_id)));



  create policy "chat_rooms_insert"
  on "public"."chat_rooms"
  as permissive
  for insert
  to authenticated
with check ((created_by = auth.uid()));



  create policy "chat_rooms_select"
  on "public"."chat_rooms"
  as permissive
  for select
  to authenticated
using (((id IN ( SELECT public.get_my_room_ids() AS get_my_room_ids)) OR (created_by = auth.uid())));



  create policy "chat_rooms_update"
  on "public"."chat_rooms"
  as permissive
  for update
  to authenticated
using (((created_by = auth.uid()) OR (EXISTS ( SELECT 1
   FROM public.room_members
  WHERE ((room_members.room_id = chat_rooms.id) AND (room_members.user_id = auth.uid()) AND ((room_members.role)::text = 'admin'::text))))));



  create policy "comments_delete"
  on "public"."comments"
  as permissive
  for delete
  to authenticated
using (((user_id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.role = 'admin'::text))))));



  create policy "comments_delete_own_or_admin"
  on "public"."comments"
  as permissive
  for delete
  to authenticated
using (((user_id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.role = 'admin'::text))))));



  create policy "comments_insert_own"
  on "public"."comments"
  as permissive
  for insert
  to authenticated
with check ((user_id = auth.uid()));



  create policy "comments_select_all"
  on "public"."comments"
  as permissive
  for select
  to authenticated
using (true);



  create policy "comments_update"
  on "public"."comments"
  as permissive
  for update
  to authenticated
using ((user_id = auth.uid()))
with check ((user_id = auth.uid()));



  create policy "comments_update_own"
  on "public"."comments"
  as permissive
  for update
  to authenticated
using ((user_id = auth.uid()))
with check ((user_id = auth.uid()));



  create policy "Active invite links are viewable by everyone"
  on "public"."group_invite_links"
  as permissive
  for select
  to public
using ((is_active = true));



  create policy "Room admins can manage invite links"
  on "public"."group_invite_links"
  as permissive
  for all
  to public
using ((EXISTS ( SELECT 1
   FROM public.room_members rm
  WHERE ((rm.room_id = group_invite_links.room_id) AND (rm.user_id = auth.uid()) AND (rm.is_admin = true)))))
with check ((EXISTS ( SELECT 1
   FROM public.room_members rm
  WHERE ((rm.room_id = group_invite_links.room_id) AND (rm.user_id = auth.uid()) AND (rm.is_admin = true)))));



  create policy "Room members can update messages"
  on "public"."messages"
  as permissive
  for update
  to public
using ((room_id IN ( SELECT room_members.room_id
   FROM public.room_members
  WHERE (room_members.user_id = auth.uid()))))
with check ((room_id IN ( SELECT room_members.room_id
   FROM public.room_members
  WHERE (room_members.user_id = auth.uid()))));



  create policy "Users can delete their messages"
  on "public"."messages"
  as permissive
  for delete
  to authenticated
using ((sender_id = auth.uid()));



  create policy "Users can delete their own messages"
  on "public"."messages"
  as permissive
  for delete
  to public
using (((sender_id = auth.uid()) OR (auth.uid() IN ( SELECT profiles.id
   FROM public.profiles
  WHERE (profiles.role = 'admin'::text)))));



  create policy "Users can insert messages in their rooms"
  on "public"."messages"
  as permissive
  for insert
  to public
with check (((sender_id = auth.uid()) AND (room_id IN ( SELECT room_members.room_id
   FROM public.room_members
  WHERE (room_members.user_id = auth.uid())))));



  create policy "Users can read messages in their rooms"
  on "public"."messages"
  as permissive
  for select
  to public
using ((EXISTS ( SELECT 1
   FROM public.room_members rm
  WHERE ((rm.room_id = messages.room_id) AND (rm.user_id = auth.uid())))));



  create policy "Users can send messages to their rooms"
  on "public"."messages"
  as permissive
  for insert
  to public
with check (((auth.uid() = sender_id) AND (EXISTS ( SELECT 1
   FROM public.room_members rm
  WHERE ((rm.room_id = messages.room_id) AND (rm.user_id = auth.uid()))))));



  create policy "Users can update own messages"
  on "public"."messages"
  as permissive
  for update
  to authenticated
using ((sender_id = auth.uid()));



  create policy "Users can update their messages"
  on "public"."messages"
  as permissive
  for update
  to authenticated
using ((sender_id = auth.uid()));



  create policy "Users can update their own messages"
  on "public"."messages"
  as permissive
  for update
  to public
using ((sender_id = auth.uid()))
with check ((sender_id = auth.uid()));



  create policy "Validate sender exists"
  on "public"."messages"
  as permissive
  for insert
  to public
with check (((auth.uid() IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM public.profiles
  WHERE (profiles.id = auth.uid())))));



  create policy "messages_delete"
  on "public"."messages"
  as permissive
  for delete
  to authenticated
using (((sender_id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.role = 'admin'::text))))));



  create policy "messages_delete_own"
  on "public"."messages"
  as permissive
  for delete
  to authenticated
using (((auth.uid() IS NOT NULL) AND (auth.uid() = sender_id)));



  create policy "messages_insert"
  on "public"."messages"
  as permissive
  for insert
  to authenticated
with check (((sender_id = auth.uid()) AND (room_id IN ( SELECT public.get_my_room_ids() AS get_my_room_ids))));



  create policy "messages_insert_validated"
  on "public"."messages"
  as permissive
  for insert
  to authenticated
with check (((auth.uid() IS NOT NULL) AND (auth.uid() = sender_id) AND (EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (NOT profiles.is_banned)))) AND (EXISTS ( SELECT 1
   FROM public.chat_rooms
  WHERE (chat_rooms.id = messages.room_id))) AND (EXISTS ( SELECT 1
   FROM public.room_members
  WHERE ((room_members.room_id = messages.room_id) AND (room_members.user_id = auth.uid()))))));



  create policy "messages_select"
  on "public"."messages"
  as permissive
  for select
  to authenticated
using ((room_id IN ( SELECT public.get_my_room_ids() AS get_my_room_ids)));



  create policy "messages_select_member"
  on "public"."messages"
  as permissive
  for select
  to authenticated
using (((auth.uid() IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM public.room_members
  WHERE ((room_members.room_id = messages.room_id) AND (room_members.user_id = auth.uid()))))));



  create policy "messages_update"
  on "public"."messages"
  as permissive
  for update
  to authenticated
using ((sender_id = auth.uid()))
with check ((sender_id = auth.uid()));



  create policy "Authenticated users can create posts"
  on "public"."posts"
  as permissive
  for insert
  to public
with check ((auth.role() = 'authenticated'::text));



  create policy "Posts are viewable by everyone"
  on "public"."posts"
  as permissive
  for select
  to public
using (true);



  create policy "Users can delete own posts"
  on "public"."posts"
  as permissive
  for delete
  to authenticated
using ((user_id = auth.uid()));



  create policy "Users can update own posts"
  on "public"."posts"
  as permissive
  for update
  to authenticated
using ((user_id = auth.uid()))
with check ((user_id = auth.uid()));



  create policy "posts_select"
  on "public"."posts"
  as permissive
  for select
  to authenticated
using (true);



  create policy "posts_update_own"
  on "public"."posts"
  as permissive
  for update
  to authenticated
using (((auth.uid() IS NOT NULL) AND (auth.uid() = user_id)))
with check ((auth.uid() = user_id));



  create policy "Admins can update any profile"
  on "public"."profiles"
  as permissive
  for update
  to authenticated
using ((EXISTS ( SELECT 1
   FROM public.profiles profiles_1
  WHERE ((profiles_1.id = auth.uid()) AND (profiles_1.role = 'admin'::text)))));



  create policy "Enable insert for auth trigger"
  on "public"."profiles"
  as permissive
  for insert
  to public
with check (true);



  create policy "Profiles are viewable by everyone"
  on "public"."profiles"
  as permissive
  for select
  to public
using (true);



  create policy "Users can insert own profile"
  on "public"."profiles"
  as permissive
  for insert
  to public
with check ((auth.uid() = id));



  create policy "Users can update own profile"
  on "public"."profiles"
  as permissive
  for update
  to public
using ((auth.uid() = id))
with check ((auth.uid() = id));



  create policy "profiles_delete_own"
  on "public"."profiles"
  as permissive
  for delete
  to authenticated
using (((auth.uid() IS NOT NULL) AND (auth.uid() = id)));



  create policy "profiles_insert_own"
  on "public"."profiles"
  as permissive
  for insert
  to authenticated
with check (((auth.uid() IS NOT NULL) AND (auth.uid() = id)));



  create policy "profiles_select"
  on "public"."profiles"
  as permissive
  for select
  to authenticated
using (true);



  create policy "profiles_select_authenticated"
  on "public"."profiles"
  as permissive
  for select
  to authenticated
using (true);



  create policy "profiles_select_policy"
  on "public"."profiles"
  as permissive
  for select
  to authenticated
using (true);



  create policy "profiles_update_own"
  on "public"."profiles"
  as permissive
  for update
  to authenticated
using ((auth.uid() = id))
with check ((auth.uid() = id));



  create policy "room_members_delete"
  on "public"."room_members"
  as permissive
  for delete
  to public
using (((user_id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM public.chat_rooms
  WHERE ((chat_rooms.id = room_members.room_id) AND (chat_rooms.created_by = auth.uid()))))));



  create policy "room_members_insert"
  on "public"."room_members"
  as permissive
  for insert
  to authenticated
with check (((EXISTS ( SELECT 1
   FROM public.chat_rooms cr
  WHERE ((cr.id = room_members.room_id) AND (cr.created_by = auth.uid())))) OR (user_id = auth.uid())));



  create policy "room_members_select"
  on "public"."room_members"
  as permissive
  for select
  to authenticated
using ((room_id IN ( SELECT public.get_my_room_ids() AS get_my_room_ids)));



  create policy "room_members_update"
  on "public"."room_members"
  as permissive
  for update
  to public
using ((EXISTS ( SELECT 1
   FROM public.chat_rooms
  WHERE ((chat_rooms.id = room_members.room_id) AND (chat_rooms.created_by = auth.uid())))));



  create policy "Authenticated users can insert logs"
  on "public"."system_logs"
  as permissive
  for insert
  to public
with check (((auth.uid() IS NOT NULL) AND (auth.role() = 'authenticated'::text)));



  create policy "Users can delete their own typing"
  on "public"."typing_indicators"
  as permissive
  for delete
  to public
using ((user_id = auth.uid()));



  create policy "Users can insert their own typing"
  on "public"."typing_indicators"
  as permissive
  for insert
  to public
with check ((user_id = auth.uid()));



  create policy "Users can see typing in their rooms"
  on "public"."typing_indicators"
  as permissive
  for select
  to public
using ((room_id IN ( SELECT room_members.room_id
   FROM public.room_members
  WHERE (room_members.user_id = auth.uid()))));



  create policy "Users can update their own typing"
  on "public"."typing_indicators"
  as permissive
  for update
  to public
using ((user_id = auth.uid()));



  create policy "typing_delete"
  on "public"."typing_indicators"
  as permissive
  for delete
  to authenticated
using ((user_id = auth.uid()));



  create policy "typing_insert"
  on "public"."typing_indicators"
  as permissive
  for insert
  to authenticated
with check ((user_id = auth.uid()));



  create policy "typing_select"
  on "public"."typing_indicators"
  as permissive
  for select
  to authenticated
using (true);



  create policy "typing_update"
  on "public"."typing_indicators"
  as permissive
  for update
  to authenticated
using ((user_id = auth.uid()));


CREATE TRIGGER handle_chat_rooms_updated_at BEFORE UPDATE ON public.chat_rooms FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER handle_comments_updated_at BEFORE UPDATE ON public.comments FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER log_comment_deletion BEFORE DELETE ON public.comments FOR EACH ROW EXECUTE FUNCTION public.log_comment_deletion();

CREATE TRIGGER on_message_update_last_seen AFTER INSERT ON public.messages FOR EACH ROW EXECUTE FUNCTION public.update_last_seen();

CREATE TRIGGER update_room_on_new_message AFTER INSERT ON public.messages FOR EACH ROW EXECUTE FUNCTION public.update_room_on_message();

CREATE TRIGGER handle_posts_updated_at BEFORE UPDATE ON public.posts FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER log_post_deletion BEFORE DELETE ON public.posts FOR EACH ROW EXECUTE FUNCTION public.log_post_deletion_attempt();

CREATE TRIGGER handle_profiles_updated_at BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER log_user_ban AFTER UPDATE OF is_banned ON public.profiles FOR EACH ROW WHEN ((old.is_banned IS DISTINCT FROM new.is_banned)) EXECUTE FUNCTION public.log_user_ban_action();

CREATE TRIGGER auto_admin_room_creator BEFORE INSERT ON public.room_members FOR EACH ROW EXECUTE FUNCTION public.set_room_creator_as_admin();

CREATE TRIGGER on_admin_leave BEFORE DELETE ON public.room_members FOR EACH ROW EXECUTE FUNCTION public.transfer_admin_on_leave();

CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

CREATE TRIGGER on_auth_user_deleted BEFORE DELETE ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_user_delete();

CREATE TRIGGER on_auth_user_updated AFTER UPDATE ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_user_update();


  create policy "Anyone can view avatars"
  on "storage"."objects"
  as permissive
  for select
  to public
using ((bucket_id = 'avatars'::text));



  create policy "Anyone can view post images"
  on "storage"."objects"
  as permissive
  for select
  to public
using ((bucket_id = 'post-images'::text));



  create policy "Authenticated users can upload post images"
  on "storage"."objects"
  as permissive
  for insert
  to public
with check (((bucket_id = 'post-images'::text) AND (auth.role() = 'authenticated'::text)));



  create policy "Authenticated users can view chat images"
  on "storage"."objects"
  as permissive
  for select
  to public
using (((bucket_id = 'chat-images'::text) AND (auth.role() = 'authenticated'::text)));



  create policy "Members can upload chat media"
  on "storage"."objects"
  as permissive
  for insert
  to public
with check (((bucket_id = 'chat-media'::text) AND (auth.role() = 'authenticated'::text)));



  create policy "Members can view chat media"
  on "storage"."objects"
  as permissive
  for select
  to public
using (((bucket_id = 'chat-media'::text) AND (auth.role() = 'authenticated'::text)));



  create policy "Room members can upload chat images"
  on "storage"."objects"
  as permissive
  for insert
  to public
with check (((bucket_id = 'chat-images'::text) AND (auth.role() = 'authenticated'::text)));



  create policy "Users can delete own chat images"
  on "storage"."objects"
  as permissive
  for delete
  to public
using (((bucket_id = 'chat-images'::text) AND (auth.role() = 'authenticated'::text)));



  create policy "Users can delete own chat media"
  on "storage"."objects"
  as permissive
  for delete
  to public
using (((bucket_id = 'chat-media'::text) AND (auth.role() = 'authenticated'::text)));



  create policy "Users can delete their own avatar"
  on "storage"."objects"
  as permissive
  for delete
  to public
using (((bucket_id = 'avatars'::text) AND (auth.role() = 'authenticated'::text)));



  create policy "Users can delete their own post images"
  on "storage"."objects"
  as permissive
  for delete
  to public
using (((bucket_id = 'post-images'::text) AND (auth.role() = 'authenticated'::text)));



  create policy "Users can update own chat media"
  on "storage"."objects"
  as permissive
  for update
  to public
using (((bucket_id = 'chat-media'::text) AND (auth.role() = 'authenticated'::text)));



  create policy "Users can update their own avatar"
  on "storage"."objects"
  as permissive
  for update
  to public
using (((bucket_id = 'avatars'::text) AND (auth.role() = 'authenticated'::text)));



  create policy "Users can update their own post images"
  on "storage"."objects"
  as permissive
  for update
  to public
using (((bucket_id = 'post-images'::text) AND (auth.role() = 'authenticated'::text)));



  create policy "Users can upload their own avatar"
  on "storage"."objects"
  as permissive
  for insert
  to public
with check (((bucket_id = 'avatars'::text) AND (auth.role() = 'authenticated'::text)));



  create policy "chat_images_delete"
  on "storage"."objects"
  as permissive
  for delete
  to authenticated
using (((bucket_id = 'chat-images'::text) AND ((auth.uid())::text = (string_to_array(name, '/'::text))[2])));



  create policy "chat_images_upload"
  on "storage"."objects"
  as permissive
  for insert
  to authenticated
with check ((bucket_id = 'chat-images'::text));



  create policy "chat_images_view"
  on "storage"."objects"
  as permissive
  for select
  to authenticated
using ((bucket_id = 'chat-images'::text));









-- ============================================================================
-- HELPER FUNCTIONS & TRIGGERS
-- ============================================================================
--
-- Internal automation functions and database triggers
-- These handle automatic updates, logging, and data integrity
--
-- Part of DeConnect Database Schema
-- Apply migrations in numerical order
--
-- ============================================================================

set check_function_bodies = off;

CREATE TRIGGER handle_chat_rooms_updated_at BEFORE UPDATE ON public.chat_rooms FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER handle_comments_updated_at BEFORE UPDATE ON public.comments FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER log_comment_deletion BEFORE DELETE ON public.comments FOR EACH ROW EXECUTE FUNCTION public.log_comment_deletion();

CREATE TRIGGER on_message_update_last_seen AFTER INSERT ON public.messages FOR EACH ROW EXECUTE FUNCTION public.update_last_seen();

CREATE TRIGGER update_room_on_new_message AFTER INSERT ON public.messages FOR EACH ROW EXECUTE FUNCTION public.update_room_on_message();

CREATE TRIGGER handle_posts_updated_at BEFORE UPDATE ON public.posts FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER log_post_deletion BEFORE DELETE ON public.posts FOR EACH ROW EXECUTE FUNCTION public.log_post_deletion_attempt();

CREATE TRIGGER handle_profiles_updated_at BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER log_user_ban AFTER UPDATE OF is_banned ON public.profiles FOR EACH ROW WHEN ((old.is_banned IS DISTINCT FROM new.is_banned)) EXECUTE FUNCTION public.log_user_ban_action();

CREATE TRIGGER auto_admin_room_creator BEFORE INSERT ON public.room_members FOR EACH ROW EXECUTE FUNCTION public.set_room_creator_as_admin();

CREATE TRIGGER on_admin_leave BEFORE DELETE ON public.room_members FOR EACH ROW EXECUTE FUNCTION public.transfer_admin_on_leave();

CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

CREATE TRIGGER on_auth_user_deleted BEFORE DELETE ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_user_delete();

CREATE TRIGGER on_auth_user_updated AFTER UPDATE ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_user_update();






-- ============================================================================
-- ROW LEVEL SECURITY POLICIES
-- ============================================================================
--
-- Security policies for all database tables
-- These policies control who can access which rows
--
-- Part of DeConnect Database Schema
-- Apply in order: 06_rls_policies.sql
--
-- ============================================================================

  create policy "Users can create calls"
  on "public"."calls"
  as permissive
  for insert
  to public
with check ((auth.uid() = caller_id));


  create policy "Users can insert calls"
  on "public"."calls"
  as permissive
  for insert
  to public
with check ((auth.uid() = caller_id));


  create policy "Users can see their own calls"
  on "public"."calls"
  as permissive
  for select
  to public
using (((auth.uid() = caller_id) OR (auth.uid() = callee_id)));


  create policy "Users can update their calls"
  on "public"."calls"
  as permissive
  for update
  to public
using (((auth.uid() = caller_id) OR (auth.uid() = callee_id)));


  create policy "Users can update their own calls"
  on "public"."calls"
  as permissive
  for update
  to public
using (((auth.uid() = caller_id) OR (auth.uid() = callee_id)));


  create policy "Users can view their own calls"
  on "public"."calls"
  as permissive
  for select
  to public
using (((auth.uid() = caller_id) OR (auth.uid() = callee_id)));


  create policy "chat_rooms_insert"
  on "public"."chat_rooms"
  as permissive
  for insert
  to authenticated
with check ((created_by = auth.uid()));


  create policy "chat_rooms_select"
  on "public"."chat_rooms"
  as permissive
  for select
  to authenticated
using (((id IN ( SELECT public.get_my_room_ids() AS get_my_room_ids)) OR (created_by = auth.uid())));


  create policy "chat_rooms_update"
  on "public"."chat_rooms"
  as permissive
  for update
  to authenticated
using (((created_by = auth.uid()) OR (EXISTS ( SELECT 1
   FROM public.room_members
  WHERE ((room_members.room_id = chat_rooms.id) AND (room_members.user_id = auth.uid()) AND ((room_members.role)::text = 'admin'::text))))));


  create policy "comments_delete"
  on "public"."comments"
  as permissive
  for delete
  to authenticated
using (((user_id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.role = 'admin'::text))))));


  create policy "comments_delete_own_or_admin"
  on "public"."comments"
  as permissive
  for delete
  to authenticated
using (((user_id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.role = 'admin'::text))))));


  create policy "comments_insert_own"
  on "public"."comments"
  as permissive
  for insert
  to authenticated
with check ((user_id = auth.uid()));


  create policy "comments_select_all"
  on "public"."comments"
  as permissive
  for select
  to authenticated
using (true);


  create policy "comments_update"
  on "public"."comments"
  as permissive
  for update
  to authenticated
using ((user_id = auth.uid()))
with check ((user_id = auth.uid()));


  create policy "comments_update_own"
  on "public"."comments"
  as permissive
  for update
  to authenticated
using ((user_id = auth.uid()))
with check ((user_id = auth.uid()));


  create policy "Active invite links are viewable by everyone"
  on "public"."group_invite_links"
  as permissive
  for select
  to public
using ((is_active = true));


  create policy "Room admins can manage invite links"
  on "public"."group_invite_links"
  as permissive
  for all
  to public
using ((EXISTS ( SELECT 1
   FROM public.room_members rm
  WHERE ((rm.room_id = group_invite_links.room_id) AND (rm.user_id = auth.uid()) AND (rm.is_admin = true)))))
with check ((EXISTS ( SELECT 1
   FROM public.room_members rm
  WHERE ((rm.room_id = group_invite_links.room_id) AND (rm.user_id = auth.uid()) AND (rm.is_admin = true)))));


  create policy "Room members can update messages"
  on "public"."messages"
  as permissive
  for update
  to public
using ((room_id IN ( SELECT room_members.room_id
   FROM public.room_members
  WHERE (room_members.user_id = auth.uid()))))
with check ((room_id IN ( SELECT room_members.room_id
   FROM public.room_members
  WHERE (room_members.user_id = auth.uid()))));


  create policy "Users can delete their messages"
  on "public"."messages"
  as permissive
  for delete
  to authenticated
using ((sender_id = auth.uid()));


  create policy "Users can delete their own messages"
  on "public"."messages"
  as permissive
  for delete
  to public
using (((sender_id = auth.uid()) OR (auth.uid() IN ( SELECT profiles.id
   FROM public.profiles
  WHERE (profiles.role = 'admin'::text)))));


  create policy "Users can insert messages in their rooms"
  on "public"."messages"
  as permissive
  for insert
  to public
with check (((sender_id = auth.uid()) AND (room_id IN ( SELECT room_members.room_id
   FROM public.room_members
  WHERE (room_members.user_id = auth.uid())))));


  create policy "Users can read messages in their rooms"
  on "public"."messages"
  as permissive
  for select
  to public
using ((EXISTS ( SELECT 1
   FROM public.room_members rm
  WHERE ((rm.room_id = messages.room_id) AND (rm.user_id = auth.uid())))));


  create policy "Users can send messages to their rooms"
  on "public"."messages"
  as permissive
  for insert
  to public
with check (((auth.uid() = sender_id) AND (EXISTS ( SELECT 1
   FROM public.room_members rm
  WHERE ((rm.room_id = messages.room_id) AND (rm.user_id = auth.uid()))))));


  create policy "Users can update own messages"
  on "public"."messages"
  as permissive
  for update
  to authenticated
using ((sender_id = auth.uid()));


  create policy "Users can update their messages"
  on "public"."messages"
  as permissive
  for update
  to authenticated
using ((sender_id = auth.uid()));


  create policy "Users can update their own messages"
  on "public"."messages"
  as permissive
  for update
  to public
using ((sender_id = auth.uid()))
with check ((sender_id = auth.uid()));


  create policy "Validate sender exists"
  on "public"."messages"
  as permissive
  for insert
  to public
with check (((auth.uid() IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM public.profiles
  WHERE (profiles.id = auth.uid())))));


  create policy "messages_delete"
  on "public"."messages"
  as permissive
  for delete
  to authenticated
using (((sender_id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.role = 'admin'::text))))));


  create policy "messages_delete_own"
  on "public"."messages"
  as permissive
  for delete
  to authenticated
using (((auth.uid() IS NOT NULL) AND (auth.uid() = sender_id)));


  create policy "messages_insert"
  on "public"."messages"
  as permissive
  for insert
  to authenticated
with check (((sender_id = auth.uid()) AND (room_id IN ( SELECT public.get_my_room_ids() AS get_my_room_ids))));


  create policy "messages_insert_validated"
  on "public"."messages"
  as permissive
  for insert
  to authenticated
with check (((auth.uid() IS NOT NULL) AND (auth.uid() = sender_id) AND (EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (NOT profiles.is_banned)))) AND (EXISTS ( SELECT 1
   FROM public.chat_rooms
  WHERE (chat_rooms.id = messages.room_id))) AND (EXISTS ( SELECT 1
   FROM public.room_members
  WHERE ((room_members.room_id = messages.room_id) AND (room_members.user_id = auth.uid()))))));


  create policy "messages_select"
  on "public"."messages"
  as permissive
  for select
  to authenticated
using ((room_id IN ( SELECT public.get_my_room_ids() AS get_my_room_ids)));


  create policy "messages_select_member"
  on "public"."messages"
  as permissive
  for select
  to authenticated
using (((auth.uid() IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM public.room_members
  WHERE ((room_members.room_id = messages.room_id) AND (room_members.user_id = auth.uid()))))));


  create policy "messages_update"
  on "public"."messages"
  as permissive
  for update
  to authenticated
using ((sender_id = auth.uid()))
with check ((sender_id = auth.uid()));


  create policy "Authenticated users can create posts"
  on "public"."posts"
  as permissive
  for insert
  to public
with check ((auth.role() = 'authenticated'::text));


  create policy "Posts are viewable by everyone"
  on "public"."posts"
  as permissive
  for select
  to public
using (true);


  create policy "Users can delete own posts"
  on "public"."posts"
  as permissive
  for delete
  to authenticated
using ((user_id = auth.uid()));


  create policy "Users can update own posts"
  on "public"."posts"
  as permissive
  for update
  to authenticated
using ((user_id = auth.uid()))
with check ((user_id = auth.uid()));


  create policy "posts_select"
  on "public"."posts"
  as permissive
  for select
  to authenticated
using (true);


  create policy "posts_update_own"
  on "public"."posts"
  as permissive
  for update
  to authenticated
using (((auth.uid() IS NOT NULL) AND (auth.uid() = user_id)))
with check ((auth.uid() = user_id));


  create policy "Admins can update any profile"
  on "public"."profiles"
  as permissive
  for update
  to authenticated
using ((EXISTS ( SELECT 1
   FROM public.profiles profiles_1
  WHERE ((profiles_1.id = auth.uid()) AND (profiles_1.role = 'admin'::text)))));


  create policy "Enable insert for auth trigger"
  on "public"."profiles"
  as permissive
  for insert
  to public
with check (true);


  create policy "Profiles are viewable by everyone"
  on "public"."profiles"
  as permissive
  for select
  to public
using (true);


  create policy "Users can insert own profile"
  on "public"."profiles"
  as permissive
  for insert
  to public
with check ((auth.uid() = id));


  create policy "Users can update own profile"
  on "public"."profiles"
  as permissive
  for update
  to public
using ((auth.uid() = id))
with check ((auth.uid() = id));


  create policy "profiles_delete_own"
  on "public"."profiles"
  as permissive
  for delete
  to authenticated
using (((auth.uid() IS NOT NULL) AND (auth.uid() = id)));


  create policy "profiles_insert_own"
  on "public"."profiles"
  as permissive
  for insert
  to authenticated
with check (((auth.uid() IS NOT NULL) AND (auth.uid() = id)));


  create policy "profiles_select"
  on "public"."profiles"
  as permissive
  for select
  to authenticated
using (true);


  create policy "profiles_select_authenticated"
  on "public"."profiles"
  as permissive
  for select
  to authenticated
using (true);


  create policy "profiles_select_policy"
  on "public"."profiles"
  as permissive
  for select
  to authenticated
using (true);


  create policy "profiles_update_own"
  on "public"."profiles"
  as permissive
  for update
  to authenticated
using ((auth.uid() = id))
with check ((auth.uid() = id));


  create policy "room_members_delete"
  on "public"."room_members"
  as permissive
  for delete
  to public
using (((user_id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM public.chat_rooms
  WHERE ((chat_rooms.id = room_members.room_id) AND (chat_rooms.created_by = auth.uid()))))));


  create policy "room_members_insert"
  on "public"."room_members"
  as permissive
  for insert
  to authenticated
with check (((EXISTS ( SELECT 1
   FROM public.chat_rooms cr
  WHERE ((cr.id = room_members.room_id) AND (cr.created_by = auth.uid())))) OR (user_id = auth.uid())));


  create policy "room_members_select"
  on "public"."room_members"
  as permissive
  for select
  to authenticated
using ((room_id IN ( SELECT public.get_my_room_ids() AS get_my_room_ids)));


  create policy "room_members_update"
  on "public"."room_members"
  as permissive
  for update
  to public
using ((EXISTS ( SELECT 1
   FROM public.chat_rooms
  WHERE ((chat_rooms.id = room_members.room_id) AND (chat_rooms.created_by = auth.uid())))));


  create policy "Authenticated users can insert logs"
  on "public"."system_logs"
  as permissive
  for insert
  to public
with check (((auth.uid() IS NOT NULL) AND (auth.role() = 'authenticated'::text)));


  create policy "Users can delete their own typing"
  on "public"."typing_indicators"
  as permissive
  for delete
  to public
using ((user_id = auth.uid()));


  create policy "Users can insert their own typing"
  on "public"."typing_indicators"
  as permissive
  for insert
  to public
with check ((user_id = auth.uid()));


  create policy "Users can see typing in their rooms"
  on "public"."typing_indicators"
  as permissive
  for select
  to public
using ((room_id IN ( SELECT room_members.room_id
   FROM public.room_members
  WHERE (room_members.user_id = auth.uid()))));


  create policy "Users can update their own typing"
  on "public"."typing_indicators"
  as permissive
  for update
  to public
using ((user_id = auth.uid()));


  create policy "typing_delete"
  on "public"."typing_indicators"
  as permissive
  for delete
  to authenticated
using ((user_id = auth.uid()));


  create policy "typing_insert"
  on "public"."typing_indicators"
  as permissive
  for insert
  to authenticated
with check ((user_id = auth.uid()));


  create policy "typing_select"
  on "public"."typing_indicators"
  as permissive
  for select
  to authenticated
using (true);


  create policy "typing_update"
  on "public"."typing_indicators"
  as permissive
  for update
  to authenticated
using ((user_id = auth.uid()));




-- ============================================================================
-- STORAGE POLICIES
-- ============================================================================
--
-- File upload and storage bucket security policies
-- Controls access to avatars, images, and media files
--
-- Part of DeConnect Database Schema
-- Apply in order: 07_storage_policies.sql
--
-- ============================================================================

  create policy "Anyone can view avatars"
  on "storage"."objects"
  as permissive
  for select
  to public
using ((bucket_id = 'avatars'::text));


  create policy "Anyone can view post images"
  on "storage"."objects"
  as permissive
  for select
  to public
using ((bucket_id = 'post-images'::text));


  create policy "Authenticated users can upload post images"
  on "storage"."objects"
  as permissive
  for insert
  to public
with check (((bucket_id = 'post-images'::text) AND (auth.role() = 'authenticated'::text)));


  create policy "Authenticated users can view chat images"
  on "storage"."objects"
  as permissive
  for select
  to public
using (((bucket_id = 'chat-images'::text) AND (auth.role() = 'authenticated'::text)));


  create policy "Members can upload chat media"
  on "storage"."objects"
  as permissive
  for insert
  to public
with check (((bucket_id = 'chat-media'::text) AND (auth.role() = 'authenticated'::text)));


  create policy "Members can view chat media"
  on "storage"."objects"
  as permissive
  for select
  to public
using (((bucket_id = 'chat-media'::text) AND (auth.role() = 'authenticated'::text)));


  create policy "Room members can upload chat images"
  on "storage"."objects"
  as permissive
  for insert
  to public
with check (((bucket_id = 'chat-images'::text) AND (auth.role() = 'authenticated'::text)));


  create policy "Users can delete own chat images"
  on "storage"."objects"
  as permissive
  for delete
  to public
using (((bucket_id = 'chat-images'::text) AND (auth.role() = 'authenticated'::text)));


  create policy "Users can delete own chat media"
  on "storage"."objects"
  as permissive
  for delete
  to public
using (((bucket_id = 'chat-media'::text) AND (auth.role() = 'authenticated'::text)));


  create policy "Users can delete their own avatar"
  on "storage"."objects"
  as permissive
  for delete
  to public
using (((bucket_id = 'avatars'::text) AND (auth.role() = 'authenticated'::text)));


  create policy "Users can delete their own post images"
  on "storage"."objects"
  as permissive
  for delete
  to public
using (((bucket_id = 'post-images'::text) AND (auth.role() = 'authenticated'::text)));


  create policy "Users can update own chat media"
  on "storage"."objects"
  as permissive
  for update
  to public
using (((bucket_id = 'chat-media'::text) AND (auth.role() = 'authenticated'::text)));


  create policy "Users can update their own avatar"
  on "storage"."objects"
  as permissive
  for update
  to public
using (((bucket_id = 'avatars'::text) AND (auth.role() = 'authenticated'::text)));


  create policy "Users can update their own post images"
  on "storage"."objects"
  as permissive
  for update
  to public
using (((bucket_id = 'post-images'::text) AND (auth.role() = 'authenticated'::text)));


  create policy "Users can upload their own avatar"
  on "storage"."objects"
  as permissive
  for insert
  to public
with check (((bucket_id = 'avatars'::text) AND (auth.role() = 'authenticated'::text)));


  create policy "chat_images_delete"
  on "storage"."objects"
  as permissive
  for delete
  to authenticated
using (((bucket_id = 'chat-images'::text) AND ((auth.uid())::text = (string_to_array(name, '/'::text))[2])));


  create policy "chat_images_upload"
  on "storage"."objects"
  as permissive
  for insert
  to authenticated
with check ((bucket_id = 'chat-images'::text));


  create policy "chat_images_view"
  on "storage"."objects"
  as permissive
  for select
  to authenticated
using ((bucket_id = 'chat-images'::text));

