-- ============================================================
-- Migration 011: Push Notification RPC Functions
-- ============================================================

-- 1. Update FCM token for current user
CREATE OR REPLACE FUNCTION update_fcm_token(p_token text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.profiles
  SET fcm_token = p_token
  WHERE id = auth.uid();
END;
$$;

-- 2. Remove FCM token (on logout)
CREATE OR REPLACE FUNCTION remove_fcm_token()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.profiles
  SET fcm_token = NULL
  WHERE id = auth.uid();
END;
$$;

-- 3. Send notification to a specific user (inserts into notifications table → triggers webhook)
CREATE OR REPLACE FUNCTION notify_user(
  p_user_id uuid,
  p_title text,
  p_body text,
  p_channel text DEFAULT 'general',
  p_room_id uuid DEFAULT NULL,
  p_data jsonb DEFAULT '{}'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_notification_id uuid;
BEGIN
  INSERT INTO public.notifications (user_id, title, body, channel, room_id, sender_id, data)
  VALUES (p_user_id, p_title, p_body, p_channel, p_room_id, auth.uid(), p_data)
  RETURNING id INTO v_notification_id;

  RETURN v_notification_id;
END;
$$;

-- 4. Notify all members in a room (for group messages)
CREATE OR REPLACE FUNCTION notify_room_members(
  p_room_id uuid,
  p_title text,
  p_body text,
  p_channel text DEFAULT 'group_message',
  p_data jsonb DEFAULT '{}'::jsonb
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_count integer := 0;
BEGIN
  INSERT INTO public.notifications (user_id, title, body, channel, room_id, sender_id, data)
  SELECT rm.user_id, p_title, p_body, p_channel, p_room_id, auth.uid(), p_data
  FROM public.room_members rm
  WHERE rm.room_id = p_room_id
    AND rm.user_id != auth.uid();  -- Don't notify yourself

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

-- 5. Get unread notifications for current user
CREATE OR REPLACE FUNCTION get_my_notifications(
  p_limit integer DEFAULT 50,
  p_offset integer DEFAULT 0
)
RETURNS TABLE (
  id uuid,
  title text,
  body text,
  channel text,
  room_id uuid,
  sender_id uuid,
  sender_username text,
  sender_avatar text,
  data jsonb,
  is_read boolean,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    n.id,
    n.title,
    n.body,
    n.channel,
    n.room_id,
    n.sender_id,
    p.username AS sender_username,
    p.avatar_url AS sender_avatar,
    n.data,
    n.is_read,
    n.created_at
  FROM public.notifications n
  LEFT JOIN public.profiles p ON p.id = n.sender_id
  WHERE n.user_id = auth.uid()
  ORDER BY n.created_at DESC
  LIMIT p_limit OFFSET p_offset;
END;
$$;

-- 6. Mark notifications as read
CREATE OR REPLACE FUNCTION mark_notifications_read(p_notification_ids uuid[])
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.notifications
  SET is_read = true
  WHERE id = ANY(p_notification_ids)
    AND user_id = auth.uid();
END;
$$;

-- 7. Get unread count
CREATE OR REPLACE FUNCTION get_unread_notification_count()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_count integer;
BEGIN
  SELECT COUNT(*)::integer INTO v_count
  FROM public.notifications
  WHERE user_id = auth.uid()
    AND is_read = false;
  RETURN v_count;
END;
$$;

-- ============================================================
-- 1. Create notifications table (if not exists)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.notifications (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  title text,
  body text NOT NULL,
  channel text NOT NULL DEFAULT 'general'
    CHECK (channel IN ('direct_message', 'group_message', 'feed', 'general')),
  room_id uuid,
  sender_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  data jsonb DEFAULT '{}'::jsonb,
  is_read boolean NOT NULL DEFAULT false
);

-- 2. Add fcm_token to profiles
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS fcm_token text;

-- 3. Enable RLS
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- 4. RLS Policies (drop first to avoid duplicates)
DROP POLICY IF EXISTS "Users can view own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Authenticated users can insert notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can update own notifications" ON public.notifications;
DROP POLICY IF EXISTS "Service role full access" ON public.notifications;

CREATE POLICY "Users can view own notifications"
  ON public.notifications FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Authenticated users can insert notifications"
  ON public.notifications FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Users can update own notifications"
  ON public.notifications FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Service role full access"
  ON public.notifications FOR ALL
  USING (auth.role() = 'service_role');

-- 5. Indexes
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON public.notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_profiles_fcm_token ON public.profiles(fcm_token) WHERE fcm_token IS NOT NULL;

-- 6. RPC Functions
CREATE OR REPLACE FUNCTION update_fcm_token(p_token text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.profiles
  SET fcm_token = p_token
  WHERE id = auth.uid();
END;
$$;

CREATE OR REPLACE FUNCTION remove_fcm_token()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.profiles
  SET fcm_token = NULL
  WHERE id = auth.uid();
END;
$$;





---- =======
-- Create trigger function for message notifications
CREATE OR REPLACE FUNCTION trigger_notify_on_message()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $func$
DECLARE
  v_room RECORD;
  v_sender RECORD;
  v_channel TEXT;
  v_title TEXT;
BEGIN
  -- Get room info
  SELECT id, name, is_group INTO v_room
  FROM public.chat_rooms
  WHERE id = NEW.room_id;

  -- Get sender info
  SELECT username INTO v_sender
  FROM public.profiles 
  WHERE id = NEW.sender_id;

  -- Determine channel
  IF v_room.is_group THEN
    v_channel := 'group_message';
    v_title := COALESCE(v_room.name, 'Group Chat');
  ELSE
    v_channel := 'direct_message';
    v_title := COALESCE(v_sender.username, 'Someone');
  END IF;

  -- Insert notifications for all room members except sender
  INSERT INTO public.notifications (user_id, title, body, channel, room_id, sender_id)
  SELECT 
    rm.user_id,
    v_title,
    LEFT(COALESCE(NEW.content, 'Sent a file'), 100),
    v_channel,
    NEW.room_id,
    NEW.sender_id
  FROM public.room_members rm
  WHERE rm.room_id = NEW.room_id
    AND rm.user_id != NEW.sender_id;

  RETURN NEW;
END;
$func$;

-- Drop and recreate trigger
DROP TRIGGER IF EXISTS on_message_notify ON public.messages;
CREATE TRIGGER on_message_notify
  AFTER INSERT ON public.messages
  FOR EACH ROW
  EXECUTE FUNCTION trigger_notify_on_message();










  -- Create a trigger that uses pg_notify instead of pg_net
CREATE OR REPLACE FUNCTION notify_push_on_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Use pg_notify to signal, your app listens via Realtime
  PERFORM pg_notify(
    'push_notification',
    json_build_object(
      'notification_id', NEW.id,
      'user_id', NEW.user_id,
      'title', NEW.title,
      'body', NEW.body,
      'channel', NEW.channel,
      'room_id', NEW.room_id,
      'sender_id', NEW.sender_id
    )::text
  );
  RETURN NEW;
END;
$$;

CREATE TRIGGER push_notify_trigger
  AFTER INSERT ON public.notifications
  FOR EACH ROW
  EXECUTE FUNCTION notify_push_on_notification();



-- Step 1: Find and remove ALL triggers on messages table
DO $$
DECLARE
    trigger_record RECORD;
BEGIN
    FOR trigger_record IN 
        SELECT tgname FROM pg_trigger 
        WHERE tgrelid = 'public.messages'::regclass 
        AND tgname NOT LIKE 'RI_%'
    LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS %I ON public.messages', trigger_record.tgname);
        RAISE NOTICE 'Dropped trigger: %', trigger_record.tgname;
    END LOOP;
END $$;

-- Step 2: Drop ALL related functions
DROP FUNCTION IF EXISTS trigger_notify_on_message() CASCADE;
DROP FUNCTION IF EXISTS notify_on_new_message() CASCADE;
DROP FUNCTION IF EXISTS handle_new_message() CASCADE;
DROP FUNCTION IF EXISTS send_push_notification() CASCADE;

-- Step 3: Create a CLEAN trigger (no pg_net, just inserts into notifications)
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
  FROM public.chat_rooms WHERE id = NEW.room_id;

  SELECT username INTO sender_name
  FROM public.profiles WHERE id = NEW.sender_id;

  IF room_rec.is_group THEN
    notif_channel := 'group_message';
    notif_title := COALESCE(room_rec.name, 'Group Chat');
  ELSE
    notif_channel := 'direct_message';
    notif_title := COALESCE(sender_name, 'Someone');
  END IF;

  INSERT INTO public.notifications (user_id, title, body, channel, room_id, sender_id)
  SELECT 
    rm.user_id, notif_title,
    COALESCE(LEFT(NEW.content, 100), 'Sent a file'),
    notif_channel, NEW.room_id, NEW.sender_id
  FROM public.room_members rm
  WHERE rm.room_id = NEW.room_id
    AND rm.user_id != NEW.sender_id;

  RETURN NEW;
END;
$$;

-- Step 4: Create the trigger
CREATE TRIGGER on_new_message_notify
  AFTER INSERT ON public.messages
  FOR EACH ROW
  EXECUTE FUNCTION notify_on_new_message();

-- Step 5: Verify
SELECT tgname FROM pg_trigger 
WHERE tgrelid = 'public.messages'::regclass 
AND tgname NOT LIKE 'RI_%';


-- Re-create the other message triggers that were removed
CREATE TRIGGER on_message_update_last_seen 
  AFTER INSERT ON public.messages 
  FOR EACH ROW EXECUTE FUNCTION public.update_last_seen();

CREATE TRIGGER update_room_on_new_message 
  AFTER INSERT ON public.messages 
  FOR EACH ROW EXECUTE FUNCTION public.update_room_on_message();

CREATE TRIGGER broadcast_message_insert 
  AFTER INSERT ON public.messages 
  FOR EACH ROW EXECUTE FUNCTION public.broadcast_message_change();

CREATE TRIGGER broadcast_message_update 
  AFTER UPDATE ON public.messages 
  FOR EACH ROW EXECUTE FUNCTION public.broadcast_message_change();


-- ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
ALTER TABLE notifications REPLICA IDENTITY FULL;




-- 
-- Enable Realtime on notifications table
-- ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
ALTER TABLE notifications REPLICA IDENTITY FULL;

-- Add 'feed' channel to constraint if needed
ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_channel_check;
ALTER TABLE public.notifications ADD CONSTRAINT notifications_channel_check
  CHECK (channel IN ('direct_message', 'group_message', 'feed', 'buy_channel', 'general'));

-- Trigger: Notify post author's followers when someone comments on their post
CREATE OR REPLACE FUNCTION trigger_notify_on_comment()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $func$
DECLARE
  v_post RECORD;
  v_commenter RECORD;
BEGIN
  -- Get post info
  SELECT id, user_id, title INTO v_post
  FROM public.posts
  WHERE id = NEW.post_id;

  -- Don't notify if commenting on your own post
  IF v_post.user_id = NEW.user_id THEN
    RETURN NEW;
  END IF;

  -- Get commenter info
  SELECT username INTO v_commenter
  FROM public.profiles
  WHERE id = NEW.user_id;

  -- Notify the post author
  INSERT INTO public.notifications (user_id, title, body, channel, sender_id, data)
  VALUES (
    v_post.user_id,
    COALESCE(v_commenter.username, 'Someone') || ' commented on your post',
    LEFT(NEW.content, 100),
    'feed',
    NEW.user_id,
    jsonb_build_object('post_id', NEW.post_id)
  );

  RETURN NEW;
END;
$func$;

DROP TRIGGER IF EXISTS on_comment_notify ON public.comments;
CREATE TRIGGER on_comment_notify
  AFTER INSERT ON public.comments
  FOR EACH ROW
  EXECUTE FUNCTION trigger_notify_on_comment();

-- Trigger: Notify when a new post is created (notify all users — like Facebook feed)
CREATE OR REPLACE FUNCTION trigger_notify_on_post()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $func$
DECLARE
  v_author RECORD;
BEGIN
  -- Get author info
  SELECT username INTO v_author
  FROM public.profiles
  WHERE id = NEW.user_id;

  -- Notify all other users about the new post
  INSERT INTO public.notifications (user_id, title, body, channel, sender_id, data)
  SELECT
    p.id,
    COALESCE(v_author.username, 'Someone') || ' posted something new',
    LEFT(COALESCE(NEW.title, NEW.content), 100),
    'feed',
    NEW.user_id,
    jsonb_build_object('post_id', NEW.id)
  FROM public.profiles p
  WHERE p.id != NEW.user_id
  AND p.is_banned = false;

  RETURN NEW;
END;
$func$;

DROP TRIGGER IF EXISTS on_post_notify ON public.posts;
CREATE TRIGGER on_post_notify
  AFTER INSERT ON public.posts
  FOR EACH ROW
  EXECUTE FUNCTION trigger_notify_on_post();



CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;


-- Auto-call Edge Function when notification is inserted
CREATE OR REPLACE FUNCTION trigger_send_push_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  PERFORM extensions.http_post(
    url := 'http://host.docker.internal:54321/functions/v1/send-push-notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU'
    ),
    body := jsonb_build_object(
      'user_id', NEW.user_id,
      'title', NEW.title,
      'body', NEW.body,
      'channel', NEW.channel,
      'room_id', NEW.room_id,
      'sender_id', NEW.sender_id,
      'id', NEW.id
    )
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS send_push_on_notification ON public.notifications;
CREATE TRIGGER send_push_on_notification
  AFTER INSERT ON public.notifications
  FOR EACH ROW
  EXECUTE FUNCTION trigger_send_push_notification();





-- here
-- Step 1: Find and remove ALL triggers on messages table
DO $$
DECLARE
    trigger_record RECORD;
BEGIN
    FOR trigger_record IN 
        SELECT tgname FROM pg_trigger 
        WHERE tgrelid = 'public.messages'::regclass 
        AND tgname NOT LIKE 'RI_%'
    LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS %I ON public.messages', trigger_record.tgname);
        RAISE NOTICE 'Dropped trigger: %', trigger_record.tgname;
    END LOOP;
END $$;

-- Step 2: Drop ALL related functions
DROP FUNCTION IF EXISTS trigger_notify_on_message() CASCADE;
DROP FUNCTION IF EXISTS notify_on_new_message() CASCADE;
DROP FUNCTION IF EXISTS handle_new_message() CASCADE;
DROP FUNCTION IF EXISTS send_push_notification() CASCADE;

-- Step 3: Create a CLEAN trigger (no pg_net, just inserts into notifications)
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
  -- Get room info
  SELECT name, is_group INTO room_rec
  FROM public.chat_rooms
  WHERE id = NEW.room_id;

  -- Get sender username
  SELECT username INTO sender_name
  FROM public.profiles 
  WHERE id = NEW.sender_id;

  -- Set channel and title
  IF room_rec.is_group THEN
    notif_channel := 'group_message';
    notif_title := COALESCE(room_rec.name, 'Group Chat');
  ELSE
    notif_channel := 'direct_message';
    notif_title := COALESCE(sender_name, 'Someone');
  END IF;

  -- Insert notification for each member except sender
  INSERT INTO public.notifications (user_id, title, body, channel, room_id, sender_id)
  SELECT 
    rm.user_id,
    notif_title,
    COALESCE(LEFT(NEW.content, 100), 'Sent a file'),
    notif_channel,
    NEW.room_id,
    NEW.sender_id
  FROM public.room_members rm
  WHERE rm.room_id = NEW.room_id
    AND rm.user_id != NEW.sender_id;

  RETURN NEW;
END;
$$;

-- Step 4: Create the trigger
CREATE TRIGGER on_new_message_notify
  AFTER INSERT ON public.messages
  FOR EACH ROW
  EXECUTE FUNCTION notify_on_new_message();

-- Step 5: Verify - should show only "on_new_message_notify"
SELECT tgname FROM pg_trigger WHERE tgrelid = 'public.messages'::regclass AND tgname NOT LIKE 'RI_%';



UPDATE public.notifications
SET is_read = true
WHERE is_read = false
  AND created_at < NOW() - INTERVAL '10 minutes';