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

alter table "public"."call_participants" enable row level security;

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

alter table "public"."typing_indicators" add constraint "typing_indicators_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE not valid;

-- Enable realtime for messages table
-- Messages (critical for real-time chat)
ALTER PUBLICATION supabase_realtime ADD TABLE messages;
ALTER TABLE messages REPLICA IDENTITY FULL;

-- Typing indicators (for "user is typing..." feature)
ALTER PUBLICATION supabase_realtime ADD TABLE typing_indicators;
ALTER TABLE typing_indicators REPLICA IDENTITY FULL;

-- Chat rooms (for real-time room list updates)
ALTER PUBLICATION supabase_realtime ADD TABLE chat_rooms;
ALTER TABLE chat_rooms REPLICA IDENTITY FULL;

-- Room members (for member join/leave notifications)
ALTER PUBLICATION supabase_realtime ADD TABLE room_members;
ALTER TABLE room_members REPLICA IDENTITY FULL;

-- Posts (optional: for real-time feed updates)
ALTER PUBLICATION supabase_realtime ADD TABLE posts;
ALTER TABLE posts REPLICA IDENTITY FULL;

-- Comments (optional: for real-time comment updates)
ALTER PUBLICATION supabase_realtime ADD TABLE comments;
ALTER TABLE comments REPLICA IDENTITY FULL;

ALTER TABLE public.profiles
ADD CONSTRAINT profiles_email_key UNIQUE (email);


UPDATE public.posts
SET image_url = substring(image_url from '/post-images/(.*)$')
WHERE image_url IS NOT NULL
  AND image_url LIKE '%/post-images/%';












