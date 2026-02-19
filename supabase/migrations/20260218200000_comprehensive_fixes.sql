-- ═══════════════════════════════════════════════════════════════════
-- Migration: Comprehensive Fixes
-- Date: 2026-02-18
-- Fixes: Invite code expiry, log levels, action analytics
-- ═══════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════
-- 1. INVITE CODE EXPIRY (48h default)
-- ═══════════════════════════════════════════════════════════════════

-- Add invite_expires_at column if missing
ALTER TABLE public.chat_rooms
  ADD COLUMN IF NOT EXISTS invite_expires_at timestamptz;

-- Update regenerate_invite_code to set 48h expiry by default
CREATE OR REPLACE FUNCTION public.regenerate_invite_code(p_room_id uuid, p_expires_hours integer DEFAULT 48)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_new_code TEXT;
  v_user_id UUID;
  v_is_admin BOOLEAN;
  v_expires_at TIMESTAMPTZ;
BEGIN
  v_user_id := auth.uid();

  SELECT (rm.role = 'admin' OR rm.is_admin = true) INTO v_is_admin
  FROM room_members rm
  WHERE rm.room_id = p_room_id
    AND rm.user_id = v_user_id;

  IF v_is_admin IS NOT TRUE THEN
    RAISE EXCEPTION 'Only admins can regenerate invite code';
  END IF;

  -- Generate new code
  v_new_code := upper(substring(md5(random()::text || clock_timestamp()::text) from 1 for 6));

  -- Calculate expiry
  v_expires_at := NOW() + (p_expires_hours || ' hours')::INTERVAL;

  -- Update room
  UPDATE chat_rooms
  SET invite_code = v_new_code,
      invite_expires_at = v_expires_at
  WHERE id = p_room_id;

  -- Deactivate old invite links
  UPDATE public.group_invite_links
  SET is_active = false
  WHERE room_id = p_room_id;

  -- Create new invite link entry
  INSERT INTO public.group_invite_links (room_id, invite_code, created_by, expires_at)
  VALUES (p_room_id, v_new_code, v_user_id, v_expires_at);

  RETURN v_new_code;
END;
$$;

-- Update regenerate_invite_link to default 48h
CREATE OR REPLACE FUNCTION public.regenerate_invite_link(
  target_room_id uuid,
  expires_in_hours integer DEFAULT 48
)
RETURNS TABLE(invite_code text, expires_at timestamptz, invite_url text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  current_user_id UUID;
  new_invite_code TEXT;
  is_user_admin BOOLEAN;
  v_expires_at TIMESTAMPTZ;
BEGIN
  current_user_id := auth.uid();

  SELECT (rm.is_admin = true) INTO is_user_admin
  FROM public.room_members rm
  WHERE rm.room_id = target_room_id AND rm.user_id = current_user_id;

  IF NOT COALESCE(is_user_admin, false) THEN
    RAISE EXCEPTION 'Only admins can regenerate invite links';
  END IF;

  new_invite_code := public.generate_invite_code();
  v_expires_at := NOW() + (expires_in_hours || ' hours')::INTERVAL;

  -- Update room
  UPDATE public.chat_rooms
  SET invite_code = new_invite_code,
      invite_expires_at = v_expires_at
  WHERE id = target_room_id;

  -- Deactivate old links
  UPDATE public.group_invite_links
  SET is_active = false
  WHERE room_id = target_room_id;

  -- Create new link
  INSERT INTO public.group_invite_links (room_id, invite_code, created_by, expires_at)
  VALUES (target_room_id, new_invite_code, current_user_id, v_expires_at);

  RETURN QUERY
  SELECT
    new_invite_code,
    v_expires_at,
    'https://deconnect.app/join/' || new_invite_code;
END;
$$;

-- Update get_invite_info to check expiry
CREATE OR REPLACE FUNCTION public.get_invite_info(invite_code_input text)
RETURNS TABLE(
  room_id uuid,
  room_name text,
  member_count bigint,
  is_active boolean,
  is_expired boolean,
  expires_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    cr.id AS room_id,
    cr.name AS room_name,
    (SELECT COUNT(*) FROM room_members rm WHERE rm.room_id = cr.id) AS member_count,
    COALESCE(gil.is_active, true) AS is_active,
    CASE
      WHEN cr.invite_expires_at IS NOT NULL AND cr.invite_expires_at < NOW() THEN true
      WHEN gil.expires_at IS NOT NULL AND gil.expires_at < NOW() THEN true
      ELSE false
    END AS is_expired,
    COALESCE(cr.invite_expires_at, gil.expires_at) AS expires_at
  FROM public.chat_rooms cr
  LEFT JOIN public.group_invite_links gil
    ON cr.id = gil.room_id
    AND UPPER(gil.invite_code) = UPPER(invite_code_input)
    AND gil.is_active = true
  WHERE UPPER(cr.invite_code) = UPPER(invite_code_input)
  LIMIT 1;
END;
$$;


-- ═══════════════════════════════════════════════════════════════════
-- 2. LOG SYSTEM: Add 7th level 'success' + action counting
-- ═══════════════════════════════════════════════════════════════════

-- Update level constraint to include all 7 levels
ALTER TABLE public.system_logs DROP CONSTRAINT IF EXISTS system_logs_level_check;
ALTER TABLE public.system_logs ADD CONSTRAINT system_logs_level_check
  CHECK (level = ANY (ARRAY['error','warn','success','info','http','verbose','debug','trace']));

-- Create action_analytics materialized view for tracking feature usage
CREATE TABLE IF NOT EXISTS public.action_analytics (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  date date NOT NULL DEFAULT CURRENT_DATE,
  feature text NOT NULL,
  action text NOT NULL,
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  count integer NOT NULL DEFAULT 1,
  last_used_at timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT action_analytics_unique UNIQUE (date, feature, action, user_id)
);

ALTER TABLE public.action_analytics ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own analytics"
  ON public.action_analytics FOR SELECT
  USING (user_id = auth.uid() OR EXISTS (
    SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'
  ));

CREATE POLICY "System can insert analytics"
  ON public.action_analytics FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

-- Auto-increment action counter (called from log_detailed)
CREATE OR REPLACE FUNCTION public.track_action(
  p_feature text,
  p_action text,
  p_user_id uuid DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO public.action_analytics (date, feature, action, user_id, count, last_used_at)
  VALUES (CURRENT_DATE, p_feature, p_action, COALESCE(p_user_id, auth.uid()), 1, NOW())
  ON CONFLICT (date, feature, action, user_id)
  DO UPDATE SET
    count = action_analytics.count + 1,
    last_used_at = NOW();
END;
$$;

-- Update log_detailed to also track actions
CREATE OR REPLACE FUNCTION public.log_detailed(
  p_level text DEFAULT 'info',
  p_message text DEFAULT '',
  p_feature text DEFAULT NULL,
  p_action text DEFAULT NULL,
  p_error_code text DEFAULT NULL,
  p_error_stack text DEFAULT NULL,
  p_duration_ms integer DEFAULT NULL,
  p_platform text DEFAULT NULL,
  p_app_version text DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}',
  p_device_info jsonb DEFAULT '{}'
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_log_id uuid;
BEGIN
  INSERT INTO public.system_logs (
    level, message, user_id, feature, action,
    error_code, error_stack, duration_ms,
    platform, app_version, metadata, device_info, source
  ) VALUES (
    p_level, p_message, auth.uid(), p_feature, p_action,
    p_error_code, p_error_stack, p_duration_ms,
    p_platform, p_app_version, p_metadata, p_device_info, 'flutter'
  )
  RETURNING id INTO v_log_id;

  -- Auto-track action analytics for info+ levels
  IF p_feature IS NOT NULL AND p_action IS NOT NULL
     AND p_level IN ('info', 'success', 'warn', 'error') THEN
    PERFORM public.track_action(p_feature, p_action);
  END IF;

  RETURN v_log_id;
END;
$$;

-- RPC to get feature usage stats (for admin dashboard)
CREATE OR REPLACE FUNCTION public.get_feature_usage_stats(
  p_days integer DEFAULT 7
)
RETURNS TABLE(
  feature text,
  action text,
  total_count bigint,
  unique_users bigint,
  last_used timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    aa.feature,
    aa.action,
    SUM(aa.count)::bigint AS total_count,
    COUNT(DISTINCT aa.user_id)::bigint AS unique_users,
    MAX(aa.last_used_at) AS last_used
  FROM public.action_analytics aa
  WHERE aa.date >= CURRENT_DATE - p_days
  GROUP BY aa.feature, aa.action
  ORDER BY SUM(aa.count) DESC;
END;
$$;

-- Indexes for analytics
CREATE INDEX IF NOT EXISTS idx_action_analytics_date ON public.action_analytics(date DESC);
CREATE INDEX IF NOT EXISTS idx_action_analytics_feature ON public.action_analytics(feature, action);


-- ═══════════════════════════════════════════════════════════════════
-- 3. PROFILE: Ensure username is always returned in key queries
-- ═══════════════════════════════════════════════════════════════════

-- Update notification triggers to use username (not first_name)
CREATE OR REPLACE FUNCTION notify_on_new_comment()
RETURNS TRIGGER AS $$
DECLARE
  post_owner_id UUID;
  post_title TEXT;
  commenter_name TEXT;
  parent_comment_author_id UUID;
BEGIN
  SELECT user_id, COALESCE(title, 'your post')
  INTO post_owner_id, post_title
  FROM posts WHERE id = NEW.post_id;

  -- Use username first, then first_name as fallback
  SELECT COALESCE(username, first_name, 'Someone')
  INTO commenter_name
  FROM profiles WHERE id = NEW.user_id;

  IF post_owner_id IS NOT NULL AND post_owner_id != NEW.user_id THEN
    INSERT INTO notifications (
      user_id, title, body, channel, post_id, sender_id, is_read
    ) VALUES (
      post_owner_id,
      commenter_name || ' commented on "' || LEFT(post_title, 30) || '"',
      LEFT(COALESCE(NEW.content, ''), 100),
      'comment',
      NEW.post_id,
      NEW.user_id,
      false
    );
  END IF;

  IF NEW.parent_id IS NOT NULL THEN
    SELECT user_id INTO parent_comment_author_id
    FROM comments WHERE id = NEW.parent_id;

    IF parent_comment_author_id IS NOT NULL
       AND parent_comment_author_id != NEW.user_id
       AND parent_comment_author_id != COALESCE(post_owner_id, '00000000-0000-0000-0000-000000000000'::uuid) THEN
      INSERT INTO notifications (
        user_id, title, body, channel, post_id, sender_id, is_read
      ) VALUES (
        parent_comment_author_id,
        commenter_name || ' replied to your comment',
        LEFT(COALESCE(NEW.content, ''), 100),
        'comment',
        NEW.post_id,
        NEW.user_id,
        false
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update post notification to use username
CREATE OR REPLACE FUNCTION trigger_notify_on_post()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  author_name TEXT;
BEGIN
  SELECT COALESCE(username, first_name, 'Someone') INTO author_name
  FROM public.profiles
  WHERE id = NEW.user_id;

  INSERT INTO public.notifications (user_id, title, body, channel, post_id, sender_id)
  SELECT
    p.id,
    author_name || ' posted something new',
    COALESCE(LEFT(NEW.title, 100), LEFT(NEW.content, 100), 'Check it out!'),
    'post',
    NEW.id,
    NEW.user_id
  FROM public.profiles p
  WHERE p.id != NEW.user_id
  AND p.is_banned = false;

  RETURN NEW;
END;
$$;

-- Update message notification to use username
CREATE OR REPLACE FUNCTION notify_on_new_message()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  room_rec RECORD;
  sender_name TEXT;
  notif_channel TEXT;
  notif_title TEXT;
BEGIN
  SELECT name, is_group INTO room_rec
  FROM public.chat_rooms
  WHERE id = NEW.room_id;

  SELECT COALESCE(username, first_name, 'Someone') INTO sender_name
  FROM public.profiles
  WHERE id = NEW.sender_id;

  IF room_rec.is_group THEN
    notif_channel := 'group_message';
    notif_title := COALESCE(room_rec.name, 'Group Chat');
  ELSE
    notif_channel := 'direct_message';
    notif_title := sender_name;
  END IF;

  INSERT INTO public.notifications (user_id, title, body, channel, room_id, sender_id)
  SELECT
    rm.user_id,
    notif_title,
    CASE
      WHEN NEW.media_type = 'voice' OR NEW.media_type = 'audio' THEN '🎤 Voice message'
      WHEN NEW.media_type = 'video' THEN '🎬 Video'
      WHEN NEW.media_type = 'image' THEN '📷 Image'
      WHEN NEW.media_type IN ('file', 'pdf', 'document') THEN '📎 File'
      WHEN NEW.content IS NOT NULL AND NEW.content != '' THEN LEFT(NEW.content, 100)
      ELSE 'New message'
    END,
    notif_channel,
    NEW.room_id,
    NEW.sender_id
  FROM public.room_members rm
  WHERE rm.room_id = NEW.room_id
    AND rm.user_id != NEW.sender_id;

  RETURN NEW;
END;
$$;


-- ═══════════════════════════════════════════════════════════════════
-- 4. Recreate triggers cleanly (idempotent)
-- ═══════════════════════════════════════════════════════════════════

DROP TRIGGER IF EXISTS on_new_message_notify ON public.messages;
CREATE TRIGGER on_new_message_notify
  AFTER INSERT ON public.messages
  FOR EACH ROW
  EXECUTE FUNCTION notify_on_new_message();

DROP TRIGGER IF EXISTS on_post_notify ON public.posts;
DROP TRIGGER IF EXISTS trigger_notify_on_new_post ON public.posts;
CREATE TRIGGER on_post_notify
  AFTER INSERT ON public.posts
  FOR EACH ROW
  EXECUTE FUNCTION trigger_notify_on_post();

DROP TRIGGER IF EXISTS trigger_notify_on_comment ON public.comments;
CREATE TRIGGER trigger_notify_on_comment
  AFTER INSERT ON public.comments
  FOR EACH ROW
  EXECUTE FUNCTION notify_on_new_comment();


-- ═══════════════════════════════════════════════════════════════════
-- 5. Ensure essential triggers on messages/posts still exist
-- ═══════════════════════════════════════════════════════════════════
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 'on_message_update_last_seen'
    AND tgrelid = 'public.messages'::regclass
  ) THEN
    CREATE TRIGGER on_message_update_last_seen
      AFTER INSERT ON public.messages
      FOR EACH ROW
      EXECUTE FUNCTION public.update_last_seen();
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 'update_room_on_new_message'
    AND tgrelid = 'public.messages'::regclass
  ) THEN
    CREATE TRIGGER update_room_on_new_message
      AFTER INSERT ON public.messages
      FOR EACH ROW
      EXECUTE FUNCTION public.update_room_on_message();
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 'broadcast_message_insert'
    AND tgrelid = 'public.messages'::regclass
  ) THEN
    CREATE TRIGGER broadcast_message_insert
      AFTER INSERT ON public.messages
      FOR EACH ROW
      EXECUTE FUNCTION public.broadcast_message_change();
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = 'broadcast_message_update'
    AND tgrelid = 'public.messages'::regclass
  ) THEN
    CREATE TRIGGER broadcast_message_update
      AFTER UPDATE ON public.messages
      FOR EACH ROW
      EXECUTE FUNCTION public.broadcast_message_change();
  END IF;
END $$;
