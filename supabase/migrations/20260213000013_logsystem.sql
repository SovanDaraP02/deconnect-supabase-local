-- ============================================================
-- ENHANCED SYSTEM LOGGING
-- ============================================================

-- Drop and recreate system_logs table with more features
DROP TABLE IF EXISTS public.system_logs CASCADE;

CREATE TABLE public.system_logs (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at timestamptz NOT NULL DEFAULT now(),
  
  -- Log levels (like Winston)
  level text NOT NULL CHECK (level IN ('error', 'warn', 'info', 'http', 'debug', 'trace')),
  
  -- Core log data
  message text NOT NULL,
  
  -- Context
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  session_id text,
  
  -- Source info
  source text,           -- 'flutter', 'edge_function', 'database', 'webhook'
  feature text,          -- 'auth', 'chat', 'post', 'profile', 'notification', 'call'
  action text,           -- 'login', 'send_message', 'create_post', etc.
  
  -- Request context
  request_id text,
  http_method text,
  http_path text,
  http_status integer,
  duration_ms integer,
  
  -- Error details
  error_code text,
  error_stack text,
  
  -- Flexible metadata
  metadata jsonb DEFAULT '{}'::jsonb,
  
  -- Device/client info
  platform text,         -- 'android', 'ios', 'web', 'macos'
  app_version text,
  device_info jsonb DEFAULT '{}'::jsonb
);

-- Enable RLS
ALTER TABLE public.system_logs ENABLE ROW LEVEL SECURITY;

-- Indexes for fast querying
CREATE INDEX idx_system_logs_created_at ON public.system_logs(created_at DESC);
CREATE INDEX idx_system_logs_level ON public.system_logs(level);
CREATE INDEX idx_system_logs_user_id ON public.system_logs(user_id);
CREATE INDEX idx_system_logs_feature ON public.system_logs(feature);
CREATE INDEX idx_system_logs_action ON public.system_logs(action);
CREATE INDEX idx_system_logs_level_created ON public.system_logs(level, created_at DESC);
CREATE INDEX idx_system_logs_error ON public.system_logs(level, created_at DESC) WHERE level = 'error';

-- RLS Policies
CREATE POLICY "Users can insert their own logs"
  ON public.system_logs FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Users can view their own logs"
  ON public.system_logs FOR SELECT
  USING (user_id = auth.uid() OR auth.uid() IN (
    SELECT id FROM public.profiles WHERE role = 'admin'
  ));

CREATE POLICY "Admins can view all logs"
  ON public.system_logs FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'
  ));

-- ============================================================
-- RPC Functions for Logging
-- ============================================================

-- 1. Simple log function
CREATE OR REPLACE FUNCTION log_event(
  p_level text,
  p_message text,
  p_feature text DEFAULT NULL,
  p_action text DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_log_id uuid;
BEGIN
  INSERT INTO public.system_logs (level, message, user_id, feature, action, metadata, source)
  VALUES (p_level, p_message, auth.uid(), p_feature, p_action, p_metadata, 'flutter')
  RETURNING id INTO v_log_id;
  
  RETURN v_log_id;
END;
$$;

-- 2. Detailed log function
CREATE OR REPLACE FUNCTION log_detailed(
  p_level text,
  p_message text,
  p_feature text DEFAULT NULL,
  p_action text DEFAULT NULL,
  p_error_code text DEFAULT NULL,
  p_error_stack text DEFAULT NULL,
  p_duration_ms integer DEFAULT NULL,
  p_platform text DEFAULT NULL,
  p_app_version text DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}'::jsonb,
  p_device_info jsonb DEFAULT '{}'::jsonb
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
  )
  VALUES (
    p_level, p_message, auth.uid(), p_feature, p_action,
    p_error_code, p_error_stack, p_duration_ms,
    p_platform, p_app_version, p_metadata, p_device_info, 'flutter'
  )
  RETURNING id INTO v_log_id;
  
  RETURN v_log_id;
END;
$$;

-- 3. Log error with stack trace
CREATE OR REPLACE FUNCTION log_error(
  p_message text,
  p_feature text,
  p_action text,
  p_error_code text DEFAULT NULL,
  p_error_stack text DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN log_detailed(
    'error', p_message, p_feature, p_action,
    p_error_code, p_error_stack, NULL, NULL, NULL,
    p_metadata, '{}'::jsonb
  );
END;
$$;

-- 4. Get recent logs (for admin dashboard)
CREATE OR REPLACE FUNCTION get_recent_logs(
  p_limit integer DEFAULT 100,
  p_level text DEFAULT NULL,
  p_feature text DEFAULT NULL,
  p_user_id uuid DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  created_at timestamptz,
  level text,
  message text,
  user_id uuid,
  username text,
  feature text,
  action text,
  error_code text,
  platform text,
  metadata jsonb
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Only admins can query all logs
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin') THEN
    RAISE EXCEPTION 'Access denied: Admin only';
  END IF;

  RETURN QUERY
  SELECT 
    sl.id,
    sl.created_at,
    sl.level,
    sl.message,
    sl.user_id,
    p.username,
    sl.feature,
    sl.action,
    sl.error_code,
    sl.platform,
    sl.metadata
  FROM public.system_logs sl
  LEFT JOIN public.profiles p ON p.id = sl.user_id
  WHERE (p_level IS NULL OR sl.level = p_level)
    AND (p_feature IS NULL OR sl.feature = p_feature)
    AND (p_user_id IS NULL OR sl.user_id = p_user_id)
  ORDER BY sl.created_at DESC
  LIMIT p_limit;
END;
$$;

-- 5. Get error summary (for dashboard)
CREATE OR REPLACE FUNCTION get_error_summary(p_hours integer DEFAULT 24)
RETURNS TABLE (
  feature text,
  error_count bigint,
  last_error timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    sl.feature,
    COUNT(*)::bigint as error_count,
    MAX(sl.created_at) as last_error
  FROM public.system_logs sl
  WHERE sl.level = 'error'
    AND sl.created_at > now() - (p_hours || ' hours')::interval
  GROUP BY sl.feature
  ORDER BY error_count DESC;
END;
$$;

-- 6. Cleanup old logs (run periodically)
CREATE OR REPLACE FUNCTION cleanup_old_logs(p_days integer DEFAULT 30)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_count integer;
BEGIN
  DELETE FROM public.system_logs
  WHERE created_at < now() - (p_days || ' days')::interval
    AND level NOT IN ('error', 'warn');  -- Keep errors/warnings longer
  
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;



-- ============================================================
-- MIGRATION: Add Missing System Log Triggers
-- Features: CHAT, AUTH, FEED, COMMENT, NOTIFICATION
-- ============================================================

-- ============================================================
-- 1. CHAT LOGGING - Log message send, delete, edit
-- ============================================================

-- Log new messages sent
CREATE OR REPLACE FUNCTION public.log_message_sent()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    INSERT INTO public.system_logs (
        level, message, user_id, feature, action, metadata, source
    ) VALUES (
        'info',
        'Message sent',
        NEW.sender_id,
        'chat',
        'send_message',
        jsonb_build_object(
            'room_id', NEW.room_id,
            'message_id', NEW.id,
            'has_media', NEW.media_url IS NOT NULL,
            'media_type', NEW.media_type,
            'is_reply', NEW.reply_to_id IS NOT NULL,
            'content_length', char_length(NEW.content)
        ),
        'database'
    );
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS log_message_sent ON public.messages;
CREATE TRIGGER log_message_sent
    AFTER INSERT ON public.messages
    FOR EACH ROW
    EXECUTE FUNCTION public.log_message_sent();

-- Log message edits
CREATE OR REPLACE FUNCTION public.log_message_edited()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    IF NEW.is_edited = true AND OLD.is_edited = false THEN
        INSERT INTO public.system_logs (
            level, message, user_id, feature, action, metadata, source
        ) VALUES (
            'info',
            'Message edited',
            NEW.sender_id,
            'chat',
            'edit_message',
            jsonb_build_object(
                'room_id', NEW.room_id,
                'message_id', NEW.id
            ),
            'database'
        );
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS log_message_edited ON public.messages;
CREATE TRIGGER log_message_edited
    AFTER UPDATE ON public.messages
    FOR EACH ROW
    WHEN (NEW.is_edited IS DISTINCT FROM OLD.is_edited)
    EXECUTE FUNCTION public.log_message_edited();

-- Log message deletes
CREATE OR REPLACE FUNCTION public.log_message_deleted()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    IF NEW.is_deleted = true AND OLD.is_deleted = false THEN
        INSERT INTO public.system_logs (
            level, message, user_id, feature, action, metadata, source
        ) VALUES (
            'info',
            'Message deleted',
            auth.uid(),
            'chat',
            'delete_message',
            jsonb_build_object(
                'room_id', NEW.room_id,
                'message_id', NEW.id,
                'original_sender', NEW.sender_id
            ),
            'database'
        );
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS log_message_deleted ON public.messages;
CREATE TRIGGER log_message_deleted
    AFTER UPDATE ON public.messages
    FOR EACH ROW
    WHEN (NEW.is_deleted IS DISTINCT FROM OLD.is_deleted)
    EXECUTE FUNCTION public.log_message_deleted();

-- Log typing events (optional - can be high volume, comment out if too noisy)
CREATE OR REPLACE FUNCTION public.log_typing_event()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    IF NEW.is_typing = true THEN
        INSERT INTO public.system_logs (
            level, message, user_id, feature, action, metadata, source
        ) VALUES (
            'debug',
            'User started typing',
            NEW.user_id,
            'chat',
            'typing_start',
            jsonb_build_object('room_id', NEW.room_id),
            'database'
        );
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS log_typing_event ON public.typing_indicators;
CREATE TRIGGER log_typing_event
    AFTER INSERT ON public.typing_indicators
    FOR EACH ROW
    EXECUTE FUNCTION public.log_typing_event();

-- Log group join/leave
CREATE OR REPLACE FUNCTION public.log_member_joined()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    INSERT INTO public.system_logs (
        level, message, user_id, feature, action, metadata, source
    ) VALUES (
        'info',
        'User joined room',
        NEW.user_id,
        'chat',
        'join_room',
        jsonb_build_object(
            'room_id', NEW.room_id,
            'is_admin', NEW.is_admin
        ),
        'database'
    );
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS log_member_joined ON public.room_members;
CREATE TRIGGER log_member_joined
    AFTER INSERT ON public.room_members
    FOR EACH ROW
    EXECUTE FUNCTION public.log_member_joined();

CREATE OR REPLACE FUNCTION public.log_member_left()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    INSERT INTO public.system_logs (
        level, message, user_id, feature, action, metadata, source
    ) VALUES (
        'info',
        'User left room',
        OLD.user_id,
        'chat',
        'leave_room',
        jsonb_build_object(
            'room_id', OLD.room_id,
            'was_admin', OLD.is_admin
        ),
        'database'
    );
    RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS log_member_left ON public.room_members;
CREATE TRIGGER log_member_left
    AFTER DELETE ON public.room_members
    FOR EACH ROW
    EXECUTE FUNCTION public.log_member_left();


-- ============================================================
-- 2. AUTH LOGGING - Log registration, login, logout
-- ============================================================

-- Log new user registration (fires when auth.users gets a new row)
CREATE OR REPLACE FUNCTION public.log_user_registered()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    INSERT INTO public.system_logs (
        level, message, user_id, feature, action, metadata, source
    ) VALUES (
        'info',
        'New user registered',
        NEW.id,
        'auth',
        'register',
        jsonb_build_object(
            'email', NEW.email,
            'provider', COALESCE(NEW.raw_app_meta_data->>'provider', 'email')
        ),
        'database'
    );
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS log_user_registered ON auth.users;
CREATE TRIGGER log_user_registered
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.log_user_registered();

-- Log login (last_sign_in_at change on auth.users)
CREATE OR REPLACE FUNCTION public.log_user_login()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    IF NEW.last_sign_in_at IS DISTINCT FROM OLD.last_sign_in_at THEN
        INSERT INTO public.system_logs (
            level, message, user_id, feature, action, metadata, source
        ) VALUES (
            'info',
            'User logged in',
            NEW.id,
            'auth',
            'login',
            jsonb_build_object(
                'email', NEW.email,
                'login_at', NEW.last_sign_in_at
            ),
            'database'
        );
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS log_user_login ON auth.users;
CREATE TRIGGER log_user_login
    AFTER UPDATE ON auth.users
    FOR EACH ROW
    WHEN (NEW.last_sign_in_at IS DISTINCT FROM OLD.last_sign_in_at)
    EXECUTE FUNCTION public.log_user_login();

-- Log user going offline (proxy for logout)
CREATE OR REPLACE FUNCTION public.log_user_went_offline()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    IF NEW.is_online = false AND OLD.is_online = true THEN
        INSERT INTO public.system_logs (
            level, message, user_id, feature, action, metadata, source
        ) VALUES (
            'info',
            'User went offline',
            NEW.id,
            'auth',
            'logout',
            jsonb_build_object(
                'last_seen', NEW.last_seen
            ),
            'database'
        );
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS log_user_went_offline ON public.profiles;
CREATE TRIGGER log_user_went_offline
    AFTER UPDATE ON public.profiles
    FOR EACH ROW
    WHEN (NEW.is_online IS DISTINCT FROM OLD.is_online AND NEW.is_online = false)
    EXECUTE FUNCTION public.log_user_went_offline();


-- ============================================================
-- 3. FEED LOGGING - Log post views, feed refresh
-- ============================================================

-- Log feed refresh (when last_feed_check is updated)
CREATE OR REPLACE FUNCTION public.log_feed_refresh()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    IF NEW.last_feed_check IS DISTINCT FROM OLD.last_feed_check THEN
        INSERT INTO public.system_logs (
            level, message, user_id, feature, action, metadata, source
        ) VALUES (
            'debug',
            'Feed refreshed',
            NEW.id,
            'feed',
            'refresh_feed',
            jsonb_build_object(
                'checked_at', NEW.last_feed_check
            ),
            'database'
        );
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS log_feed_refresh ON public.profiles;
CREATE TRIGGER log_feed_refresh
    AFTER UPDATE ON public.profiles
    FOR EACH ROW
    WHEN (NEW.last_feed_check IS DISTINCT FROM OLD.last_feed_check)
    EXECUTE FUNCTION public.log_feed_refresh();

-- Log post likes (requires post_likes table - create if missing)
CREATE TABLE IF NOT EXISTS public.post_likes (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    post_id uuid NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE(post_id, user_id)
);
ALTER TABLE public.post_likes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can like posts"
    ON public.post_likes FOR INSERT
    WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can unlike posts"
    ON public.post_likes FOR DELETE
    USING (auth.uid() = user_id);
CREATE POLICY "Anyone can view likes"
    ON public.post_likes FOR SELECT
    USING (true);

CREATE OR REPLACE FUNCTION public.log_post_liked()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    INSERT INTO public.system_logs (
        level, message, user_id, feature, action, metadata, source
    ) VALUES (
        'info',
        'Post liked',
        NEW.user_id,
        'feed',
        'like_post',
        jsonb_build_object(
            'post_id', NEW.post_id
        ),
        'database'
    );
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS log_post_liked ON public.post_likes;
CREATE TRIGGER log_post_liked
    AFTER INSERT ON public.post_likes
    FOR EACH ROW
    EXECUTE FUNCTION public.log_post_liked();

CREATE OR REPLACE FUNCTION public.log_post_unliked()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    INSERT INTO public.system_logs (
        level, message, user_id, feature, action, metadata, source
    ) VALUES (
        'info',
        'Post unliked',
        OLD.user_id,
        'feed',
        'unlike_post',
        jsonb_build_object(
            'post_id', OLD.post_id
        ),
        'database'
    );
    RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS log_post_unliked ON public.post_likes;
CREATE TRIGGER log_post_unliked
    AFTER DELETE ON public.post_likes
    FOR EACH ROW
    EXECUTE FUNCTION public.log_post_unliked();


-- ============================================================
-- 4. COMMENT LOGGING - Log comment create, delete
-- ============================================================

-- Log new comments (the delete trigger already exists as log_comment_deletion)
CREATE OR REPLACE FUNCTION public.log_comment_created()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    INSERT INTO public.system_logs (
        level, message, user_id, feature, action, metadata, source
    ) VALUES (
        'info',
        'Comment added',
        NEW.user_id,
        'comment',
        'add_comment',
        jsonb_build_object(
            'comment_id', NEW.id,
            'post_id', NEW.post_id,
            'content_preview', LEFT(NEW.content, 50),
            'is_reply', NEW.parent_id IS NOT NULL,
            'parent_id', NEW.parent_id
        ),
        'database'
    );
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS log_comment_created ON public.comments;
CREATE TRIGGER log_comment_created
    AFTER INSERT ON public.comments
    FOR EACH ROW
    EXECUTE FUNCTION public.log_comment_created();

-- Update existing comment deletion logger to use enhanced format
CREATE OR REPLACE FUNCTION public.log_comment_deletion()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
BEGIN
    INSERT INTO public.system_logs (
        level, message, user_id, feature, action, metadata, source
    ) VALUES (
        'info',
        'Comment deleted',
        OLD.user_id,
        'comment',
        'delete_comment',
        jsonb_build_object(
            'comment_id', OLD.id,
            'post_id', OLD.post_id,
            'content_preview', LEFT(OLD.content, 50),
            'original_author', OLD.user_id,
            'deleted_by', auth.uid()
        ),
        'database'
    );
    RETURN OLD;
END;
$$;


-- ============================================================
-- 5. NOTIFICATION LOGGING - Log notification read, open
-- ============================================================

-- Log notification created
CREATE OR REPLACE FUNCTION public.log_notification_created()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    INSERT INTO public.system_logs (
        level, message, user_id, feature, action, metadata, source
    ) VALUES (
        'info',
        'Notification sent',
        NEW.user_id,
        'notification',
        'create_notification',
        jsonb_build_object(
            'notification_id', NEW.id,
            'channel', NEW.channel,
            'title', NEW.title,
            'sender_id', NEW.sender_id
        ),
        'database'
    );
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS log_notification_created ON public.notifications;
CREATE TRIGGER log_notification_created
    AFTER INSERT ON public.notifications
    FOR EACH ROW
    EXECUTE FUNCTION public.log_notification_created();

-- Log notification marked as read
CREATE OR REPLACE FUNCTION public.log_notification_read()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    IF NEW.is_read = true AND OLD.is_read = false THEN
        INSERT INTO public.system_logs (
            level, message, user_id, feature, action, metadata, source
        ) VALUES (
            'info',
            'Notification marked as read',
            NEW.user_id,
            'notification',
            'mark_read',
            jsonb_build_object(
                'notification_id', NEW.id,
                'channel', NEW.channel
            ),
            'database'
        );
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS log_notification_read ON public.notifications;
CREATE TRIGGER log_notification_read
    AFTER UPDATE ON public.notifications
    FOR EACH ROW
    WHEN (NEW.is_read IS DISTINCT FROM OLD.is_read)
    EXECUTE FUNCTION public.log_notification_read();

-- Log notification deleted
CREATE OR REPLACE FUNCTION public.log_notification_deleted()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    INSERT INTO public.system_logs (
        level, message, user_id, feature, action, metadata, source
    ) VALUES (
        'info',
        'Notification deleted',
        OLD.user_id,
        'notification',
        'delete_notification',
        jsonb_build_object(
            'notification_id', OLD.id,
            'channel', OLD.channel
        ),
        'database'
    );
    RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS log_notification_deleted ON public.notifications;
CREATE TRIGGER log_notification_deleted
    AFTER DELETE ON public.notifications
    FOR EACH ROW
    EXECUTE FUNCTION public.log_notification_deleted();


-- ============================================================
-- 6. Add parent_id to comments if missing (for reply tracking)
-- ============================================================
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'comments' AND column_name = 'parent_id'
    ) THEN
        ALTER TABLE public.comments 
        ADD COLUMN parent_id uuid REFERENCES public.comments(id) ON DELETE SET NULL;
        CREATE INDEX idx_comments_parent_id ON public.comments(parent_id) WHERE parent_id IS NOT NULL;
    END IF;
END $$;


-- ============================================================
-- VERIFY: Check all triggers are registered
-- ============================================================
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement
FROM information_schema.triggers
WHERE trigger_schema = 'public'
  AND trigger_name LIKE 'log_%'
ORDER BY event_object_table, trigger_name;




-- ============================================================
-- MIGRATION: Add REMAINING Missing Log Triggers
-- Features: CALLS, ADMIN, GROUP MANAGEMENT, POST CREATE
-- ============================================================

-- ============================================================
-- 1. CALL LOGGING
-- ============================================================

-- Log call initiated
CREATE OR REPLACE FUNCTION public.log_call_started()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    INSERT INTO public.system_logs (
        level, message, user_id, feature, action, metadata, source
    ) VALUES (
        'info',
        'Call started',
        NEW.caller_id,
        'call',
        'start_call',
        jsonb_build_object(
            'call_id', NEW.id,
            'room_id', NEW.room_id,
            'callee_id', NEW.callee_id,
            'call_type', NEW.call_type,
            'is_group_call', NEW.is_group_call
        ),
        'database'
    );
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS log_call_started ON public.calls;
CREATE TRIGGER log_call_started
    AFTER INSERT ON public.calls
    FOR EACH ROW
    EXECUTE FUNCTION public.log_call_started();

-- Log call status changes (answered, declined, ended, missed)
CREATE OR REPLACE FUNCTION public.log_call_status_change()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    IF NEW.status IS DISTINCT FROM OLD.status THEN
        INSERT INTO public.system_logs (
            level, message, user_id, feature, action, metadata, source
        ) VALUES (
            CASE WHEN NEW.status = 'missed' THEN 'warn' ELSE 'info' END,
            'Call ' || NEW.status,
            NEW.caller_id,
            'call',
            CASE 
                WHEN NEW.status = 'answered' THEN 'answer_call'
                WHEN NEW.status = 'ended' THEN 'end_call'
                WHEN NEW.status = 'declined' THEN 'decline_call'
                WHEN NEW.status = 'missed' THEN 'miss_call'
                ELSE 'update_call'
            END,
            jsonb_build_object(
                'call_id', NEW.id,
                'call_type', NEW.call_type,
                'old_status', OLD.status,
                'new_status', NEW.status,
                'duration', NEW.duration,
                'is_group_call', NEW.is_group_call
            ),
            'database'
        );
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS log_call_status_change ON public.calls;
CREATE TRIGGER log_call_status_change
    AFTER UPDATE ON public.calls
    FOR EACH ROW
    WHEN (NEW.status IS DISTINCT FROM OLD.status)
    EXECUTE FUNCTION public.log_call_status_change();

-- Log call participant joins
CREATE OR REPLACE FUNCTION public.log_call_participant_joined()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    INSERT INTO public.system_logs (
        level, message, user_id, feature, action, metadata, source
    ) VALUES (
        'info',
        'Participant joined call',
        NEW.user_id,
        'call',
        'join_call',
        jsonb_build_object(
            'call_id', NEW.call_id,
            'participant_id', NEW.id,
            'status', NEW.status
        ),
        'database'
    );
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS log_call_participant_joined ON public.call_participants;
CREATE TRIGGER log_call_participant_joined
    AFTER INSERT ON public.call_participants
    FOR EACH ROW
    EXECUTE FUNCTION public.log_call_participant_joined();

-- Log participant status changes (joined → left)
CREATE OR REPLACE FUNCTION public.log_call_participant_update()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    IF NEW.status IS DISTINCT FROM OLD.status THEN
        INSERT INTO public.system_logs (
            level, message, user_id, feature, action, metadata, source
        ) VALUES (
            'info',
            'Call participant ' || COALESCE(NEW.status, 'updated'),
            NEW.user_id,
            'call',
            'leave_call',
            jsonb_build_object(
                'call_id', NEW.call_id,
                'old_status', OLD.status,
                'new_status', NEW.status,
                'left_at', NEW.left_at
            ),
            'database'
        );
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS log_call_participant_update ON public.call_participants;
CREATE TRIGGER log_call_participant_update
    AFTER UPDATE ON public.call_participants
    FOR EACH ROW
    WHEN (NEW.status IS DISTINCT FROM OLD.status)
    EXECUTE FUNCTION public.log_call_participant_update();


-- ============================================================
-- 2. POST CREATION LOGGING (only deletion was logged before)
-- ============================================================

CREATE OR REPLACE FUNCTION public.log_post_created()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    INSERT INTO public.system_logs (
        level, message, user_id, feature, action, metadata, source
    ) VALUES (
        'info',
        'Post created',
        NEW.user_id,
        'post',
        'create_post',
        jsonb_build_object(
            'post_id', NEW.id,
            'title', LEFT(NEW.title, 50),
            'has_image', NEW.image_url IS NOT NULL,
            'tags', NEW.tags,
            'content_length', char_length(NEW.content)
        ),
        'database'
    );
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS log_post_created ON public.posts;
CREATE TRIGGER log_post_created
    AFTER INSERT ON public.posts
    FOR EACH ROW
    EXECUTE FUNCTION public.log_post_created();


-- ============================================================
-- 3. GROUP MANAGEMENT LOGGING
-- ============================================================

-- Log group created
CREATE OR REPLACE FUNCTION public.log_group_created()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    IF NEW.is_group = true THEN
        INSERT INTO public.system_logs (
            level, message, user_id, feature, action, metadata, source
        ) VALUES (
            'info',
            'Group created',
            NEW.created_by,
            'group',
            'create_group',
            jsonb_build_object(
                'room_id', NEW.id,
                'group_name', NEW.name,
                'max_members', NEW.max_members,
                'invite_code', NEW.invite_code
            ),
            'database'
        );
    END IF;
    RETURN NEW;
END;
$$;

DO $$ BEGIN DROP TRIGGER IF EXISTS log_group_created ON public.chat_rooms; EXCEPTION WHEN undefined_table THEN NULL; END $$;
CREATE TRIGGER log_group_created
    AFTER INSERT ON public.chat_rooms
    FOR EACH ROW
    WHEN (NEW.is_group = true)
    EXECUTE FUNCTION public.log_group_created();

-- Log group settings updated (name change, invite toggle, etc.)
CREATE OR REPLACE FUNCTION public.log_group_updated()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    IF NEW.is_group = true THEN
        INSERT INTO public.system_logs (
            level, message, user_id, feature, action, metadata, source
        ) VALUES (
            'info',
            'Group settings updated',
            auth.uid(),
            'group',
            'update_group_settings',
            jsonb_build_object(
                'room_id', NEW.id,
                'name_changed', NEW.name IS DISTINCT FROM OLD.name,
                'old_name', OLD.name,
                'new_name', NEW.name,
                'invite_toggled', NEW.invite_link_enabled IS DISTINCT FROM OLD.invite_link_enabled,
                'invite_code_changed', NEW.invite_code IS DISTINCT FROM OLD.invite_code,
                'owner_changed', NEW.created_by IS DISTINCT FROM OLD.created_by
            ),
            'database'
        );
    END IF;
    RETURN NEW;
END;
$$;

DO $$ BEGIN DROP TRIGGER IF EXISTS log_group_updated ON public.chat_rooms; EXCEPTION WHEN undefined_table THEN NULL; END $$;
CREATE TRIGGER log_group_updated
    AFTER UPDATE ON public.chat_rooms
    FOR EACH ROW
    WHEN (NEW.is_group = true AND (
        NEW.name IS DISTINCT FROM OLD.name OR
        NEW.invite_code IS DISTINCT FROM OLD.invite_code OR
        NEW.invite_link_enabled IS DISTINCT FROM OLD.invite_link_enabled OR
        NEW.created_by IS DISTINCT FROM OLD.created_by OR
        NEW.max_members IS DISTINCT FROM OLD.max_members
    ))
    EXECUTE FUNCTION public.log_group_updated();

-- Log group deleted
CREATE OR REPLACE FUNCTION public.log_group_deleted()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    IF OLD.is_group = true THEN
        INSERT INTO public.system_logs (
            level, message, user_id, feature, action, metadata, source
        ) VALUES (
            'warn',
            'Group deleted',
            auth.uid(),
            'group',
            'delete_group',
            jsonb_build_object(
                'room_id', OLD.id,
                'group_name', OLD.name,
                'created_by', OLD.created_by
            ),
            'database'
        );
    END IF;
    RETURN OLD;
END;
$$;

DO $$ BEGIN DROP TRIGGER IF EXISTS log_group_deleted ON public.chat_rooms; EXCEPTION WHEN undefined_table THEN NULL; END $$;
CREATE TRIGGER log_group_deleted
    BEFORE DELETE ON public.chat_rooms
    FOR EACH ROW
    WHEN (OLD.is_group = true)
    EXECUTE FUNCTION public.log_group_deleted();

-- Log admin promote/demote
CREATE OR REPLACE FUNCTION public.log_admin_role_change()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    IF NEW.is_admin IS DISTINCT FROM OLD.is_admin THEN
        INSERT INTO public.system_logs (
            level, message, user_id, feature, action, metadata, source
        ) VALUES (
            'info',
            CASE WHEN NEW.is_admin THEN 'User promoted to admin' ELSE 'User demoted from admin' END,
            NEW.user_id,
            'group',
            CASE WHEN NEW.is_admin THEN 'promote_admin' ELSE 'demote_admin' END,
            jsonb_build_object(
                'room_id', NEW.room_id,
                'target_user', NEW.user_id,
                'promoted_by', auth.uid()
            ),
            'database'
        );
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS log_admin_role_change ON public.room_members;
CREATE TRIGGER log_admin_role_change
    AFTER UPDATE ON public.room_members
    FOR EACH ROW
    WHEN (NEW.is_admin IS DISTINCT FROM OLD.is_admin)
    EXECUTE FUNCTION public.log_admin_role_change();


-- ============================================================
-- 4. ADMIN PANEL LOGGING
-- ============================================================

-- Log admin role changes (user → admin, admin → user)
CREATE OR REPLACE FUNCTION public.log_user_role_change()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    IF NEW.role IS DISTINCT FROM OLD.role THEN
        INSERT INTO public.system_logs (
            level, message, user_id, feature, action, metadata, source
        ) VALUES (
            'warn',
            'User role changed',
            NEW.id,
            'admin',
            'change_role',
            jsonb_build_object(
                'target_user', NEW.id,
                'old_role', OLD.role,
                'new_role', NEW.role,
                'changed_by', auth.uid()
            ),
            'database'
        );
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS log_user_role_change ON public.profiles;
CREATE TRIGGER log_user_role_change
    AFTER UPDATE ON public.profiles
    FOR EACH ROW
    WHEN (NEW.role IS DISTINCT FROM OLD.role)
    EXECUTE FUNCTION public.log_user_role_change();

-- Log account deletion
CREATE OR REPLACE FUNCTION public.log_user_deleted()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    INSERT INTO public.system_logs (
        level, message, feature, action, metadata, source
    ) VALUES (
        'warn',
        'User account deleted',
        'admin',
        'delete_user',
        jsonb_build_object(
            'deleted_user_id', OLD.id,
            'username', OLD.username,
            'deleted_by', auth.uid()
        ),
        'database'
    );
    RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS log_user_deleted ON public.profiles;
CREATE TRIGGER log_user_deleted
    BEFORE DELETE ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.log_user_deleted();

-- Log profile edits (username, bio, avatar changes)
CREATE OR REPLACE FUNCTION public.log_profile_updated()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    INSERT INTO public.system_logs (
        level, message, user_id, feature, action, metadata, source
    ) VALUES (
        'info',
        'Profile updated',
        NEW.id,
        'profile',
        'update_profile',
        jsonb_build_object(
            'username_changed', NEW.username IS DISTINCT FROM OLD.username,
            'avatar_changed', NEW.avatar_url IS DISTINCT FROM OLD.avatar_url,
            'bio_changed', NEW.bio IS DISTINCT FROM OLD.bio,
            'name_changed', (NEW.first_name IS DISTINCT FROM OLD.first_name OR NEW.last_name IS DISTINCT FROM OLD.last_name)
        ),
        'database'
    );
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS log_profile_updated ON public.profiles;
CREATE TRIGGER log_profile_updated
    AFTER UPDATE ON public.profiles
    FOR EACH ROW
    WHEN (
        NEW.username IS DISTINCT FROM OLD.username OR
        NEW.avatar_url IS DISTINCT FROM OLD.avatar_url OR
        NEW.bio IS DISTINCT FROM OLD.bio OR
        NEW.first_name IS DISTINCT FROM OLD.first_name OR
        NEW.last_name IS DISTINCT FROM OLD.last_name
    )
    EXECUTE FUNCTION public.log_profile_updated();


-- ============================================================
-- 5. INVITE LINK LOGGING
-- ============================================================

CREATE OR REPLACE FUNCTION public.log_invite_used()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    IF NEW.uses_count IS DISTINCT FROM OLD.uses_count THEN
        INSERT INTO public.system_logs (
            level, message, user_id, feature, action, metadata, source
        ) VALUES (
            'info',
            'Invite link used',
            auth.uid(),
            'group',
            'use_invite_link',
            jsonb_build_object(
                'room_id', NEW.room_id,
                'invite_code', NEW.invite_code,
                'uses_count', NEW.uses_count
            ),
            'database'
        );
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS log_invite_used ON public.group_invite_links;
CREATE TRIGGER log_invite_used
    AFTER UPDATE ON public.group_invite_links
    FOR EACH ROW
    WHEN (NEW.uses_count IS DISTINCT FROM OLD.uses_count)
    EXECUTE FUNCTION public.log_invite_used();


-- ============================================================


-- ============================================================
-- ANALYTICS: Feature & Action Usage Statistics
-- ============================================================

-- 1. Feature usage ranking (which feature is used most)
CREATE OR REPLACE FUNCTION get_feature_usage(
    p_days integer DEFAULT 7,
    p_source text DEFAULT NULL
)
RETURNS TABLE(
    feature text,
    total_actions bigint,
    unique_users bigint,
    last_used timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin') THEN
        RAISE EXCEPTION 'Access denied: Admin only';
    END IF;

    RETURN QUERY
    SELECT 
        sl.feature,
        COUNT(*)::bigint AS total_actions,
        COUNT(DISTINCT sl.user_id)::bigint AS unique_users,
        MAX(sl.created_at) AS last_used
    FROM public.system_logs sl
    WHERE sl.feature IS NOT NULL
      AND sl.created_at > now() - (p_days || ' days')::interval
      AND (p_source IS NULL OR sl.source = p_source)
    GROUP BY sl.feature
    ORDER BY total_actions DESC;
END;
$$;

-- 2. Action-level breakdown (which specific actions within each feature)
CREATE OR REPLACE FUNCTION get_action_usage(
    p_days integer DEFAULT 7,
    p_feature text DEFAULT NULL,
    p_source text DEFAULT NULL
)
RETURNS TABLE(
    feature text,
    action text,
    total_count bigint,
    unique_users bigint,
    last_used timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin') THEN
        RAISE EXCEPTION 'Access denied: Admin only';
    END IF;

    RETURN QUERY
    SELECT 
        sl.feature,
        sl.action,
        COUNT(*)::bigint AS total_count,
        COUNT(DISTINCT sl.user_id)::bigint AS unique_users,
        MAX(sl.created_at) AS last_used
    FROM public.system_logs sl
    WHERE sl.feature IS NOT NULL
      AND sl.action IS NOT NULL
      AND sl.created_at > now() - (p_days || ' days')::interval
      AND (p_feature IS NULL OR sl.feature = p_feature)
      AND (p_source IS NULL OR sl.source = p_source)
    GROUP BY sl.feature, sl.action
    ORDER BY total_count DESC;
END;
$$;

-- 3. Top active users (who uses the app most)
CREATE OR REPLACE FUNCTION get_top_users(
    p_days integer DEFAULT 7,
    p_limit integer DEFAULT 20
)
RETURNS TABLE(
    user_id uuid,
    username text,
    avatar_url text,
    total_actions bigint,
    features_used bigint,
    most_used_feature text,
    last_active timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin') THEN
        RAISE EXCEPTION 'Access denied: Admin only';
    END IF;

    RETURN QUERY
    SELECT 
        sl.user_id,
        p.username,
        p.avatar_url,
        COUNT(*)::bigint AS total_actions,
        COUNT(DISTINCT sl.feature)::bigint AS features_used,
        (SELECT sl2.feature FROM system_logs sl2 
         WHERE sl2.user_id = sl.user_id 
           AND sl2.created_at > now() - (p_days || ' days')::interval
         GROUP BY sl2.feature 
         ORDER BY COUNT(*) DESC LIMIT 1
        ) AS most_used_feature,
        MAX(sl.created_at) AS last_active
    FROM public.system_logs sl
    LEFT JOIN public.profiles p ON p.id = sl.user_id
    WHERE sl.user_id IS NOT NULL
      AND sl.created_at > now() - (p_days || ' days')::interval
    GROUP BY sl.user_id, p.username, p.avatar_url
    ORDER BY total_actions DESC
    LIMIT p_limit;
END;
$$;

-- 4. Hourly usage heatmap (when do users use the app most)
CREATE OR REPLACE FUNCTION get_usage_heatmap(
    p_days integer DEFAULT 7
)
RETURNS TABLE(
    hour_of_day integer,
    day_of_week integer,
    day_name text,
    action_count bigint
)
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin') THEN
        RAISE EXCEPTION 'Access denied: Admin only';
    END IF;

    RETURN QUERY
    SELECT 
        EXTRACT(HOUR FROM sl.created_at)::integer AS hour_of_day,
        EXTRACT(DOW FROM sl.created_at)::integer AS day_of_week,
        TO_CHAR(sl.created_at, 'Day') AS day_name,
        COUNT(*)::bigint AS action_count
    FROM public.system_logs sl
    WHERE sl.created_at > now() - (p_days || ' days')::interval
    GROUP BY hour_of_day, day_of_week, day_name
    ORDER BY day_of_week, hour_of_day;
END;
$$;

-- 5. Backend vs Frontend log comparison
CREATE OR REPLACE FUNCTION get_source_comparison(
    p_days integer DEFAULT 7
)
RETURNS TABLE(
    source text,
    feature text,
    total_logs bigint,
    unique_users bigint
)
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin') THEN
        RAISE EXCEPTION 'Access denied: Admin only';
    END IF;

    RETURN QUERY
    SELECT 
        COALESCE(sl.source, 'unknown') AS source,
        sl.feature,
        COUNT(*)::bigint AS total_logs,
        COUNT(DISTINCT sl.user_id)::bigint AS unique_users
    FROM public.system_logs sl
    WHERE sl.created_at > now() - (p_days || ' days')::interval
      AND sl.feature IS NOT NULL
    GROUP BY sl.source, sl.feature
    ORDER BY sl.source, total_logs DESC;
END;
$$;

-- 6. Full dashboard summary in one call
CREATE OR REPLACE FUNCTION get_log_dashboard(
    p_days integer DEFAULT 7
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_result jsonb;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin') THEN
        RAISE EXCEPTION 'Access denied: Admin only';
    END IF;

    SELECT jsonb_build_object(
        'period_days', p_days,
        'total_logs', (SELECT COUNT(*) FROM system_logs WHERE created_at > now() - (p_days || ' days')::interval),
        'total_errors', (SELECT COUNT(*) FROM system_logs WHERE level = 'error' AND created_at > now() - (p_days || ' days')::interval),
        'unique_users', (SELECT COUNT(DISTINCT user_id) FROM system_logs WHERE created_at > now() - (p_days || ' days')::interval),
        'backend_logs', (SELECT COUNT(*) FROM system_logs WHERE source = 'database' AND created_at > now() - (p_days || ' days')::interval),
        'frontend_logs', (SELECT COUNT(*) FROM system_logs WHERE source = 'flutter' AND created_at > now() - (p_days || ' days')::interval),
        'top_features', (
            SELECT jsonb_agg(jsonb_build_object(
                'feature', f.feature,
                'count', f.cnt,
                'users', f.users
            ))
            FROM (
                SELECT feature, COUNT(*) as cnt, COUNT(DISTINCT user_id) as users
                FROM system_logs
                WHERE feature IS NOT NULL AND created_at > now() - (p_days || ' days')::interval
                GROUP BY feature
                ORDER BY cnt DESC
                LIMIT 10
            ) f
        ),
        'top_actions', (
            SELECT jsonb_agg(jsonb_build_object(
                'feature', a.feature,
                'action', a.action,
                'count', a.cnt
            ))
            FROM (
                SELECT feature, action, COUNT(*) as cnt
                FROM system_logs
                WHERE action IS NOT NULL AND created_at > now() - (p_days || ' days')::interval
                GROUP BY feature, action
                ORDER BY cnt DESC
                LIMIT 15
            ) a
        ),
        'recent_errors', (
            SELECT jsonb_agg(jsonb_build_object(
                'message', e.message,
                'feature', e.feature,
                'action', e.action,
                'created_at', e.created_at,
                'error_code', e.error_code
            ))
            FROM (
                SELECT message, feature, action, created_at, error_code
                FROM system_logs
                WHERE level = 'error' AND created_at > now() - (p_days || ' days')::interval
                ORDER BY created_at DESC
                LIMIT 10
            ) e
        )
    ) INTO v_result;

    RETURN v_result;
END;
$$;
