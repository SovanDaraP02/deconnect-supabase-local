-- ═══════════════════════════════════════════════════════════════════
-- Migration 014: Consolidated notification fixes
-- Replaces: add.sql + fix_notifications_and_logging.sql
-- ═══════════════════════════════════════════════════════════════════

-- ─── 1. Fix notifications channel constraint ─────────────────────
-- Add all valid channel types in one place
ALTER TABLE public.notifications
  DROP CONSTRAINT IF EXISTS notifications_channel_check;

-- Clean up any legacy channel values
UPDATE public.notifications
SET channel = 'general'
WHERE channel NOT IN (
  'direct_message', 'group_message', 'post', 'comment',
  'like', 'follow', 'mention', 'feed', 'general'
);

ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_channel_check
  CHECK (channel IN (
    'direct_message',
    'group_message',
    'post',
    'comment',
    'like',
    'follow',
    'mention',
    'feed',
    'general'
  ));

-- ─── 2. Add post_id column if missing ────────────────────────────
ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS post_id uuid;

-- ─── 3. Push notification trigger (DB → Edge Function) ──────────
-- Uses pg_net to call the send-push-notification edge function
-- when a new row is inserted into the notifications table.
--
-- NOTE: The service_role JWT below is the LOCAL DEV key.
-- For production, use Vault secrets or app.settings instead.
DROP TRIGGER IF EXISTS send_push_on_notification ON public.notifications;
DROP FUNCTION IF EXISTS trigger_send_push_notification();

CREATE OR REPLACE FUNCTION trigger_send_push_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  request_id bigint;
  _service_key text;
BEGIN
  -- Read the service role key from database settings
  -- Set via: ALTER DATABASE postgres SET app.settings.service_role_key = 'your-key';
  _service_key := current_setting('app.settings.service_role_key', true);

  -- Fallback to local dev key if not configured
  IF _service_key IS NULL OR _service_key = '' THEN
    _service_key := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU';
  END IF;

  SELECT net.http_post(
    url := 'http://host.docker.internal:54321/functions/v1/send-push-notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || _service_key
    ),
    body := jsonb_build_object(
      'user_id', NEW.user_id,
      'title', NEW.title,
      'body', NEW.body,
      'channel', NEW.channel,
      'room_id', NEW.room_id,
      'post_id', NEW.post_id,
      'sender_id', NEW.sender_id,
      'id', NEW.id
    )
  ) INTO request_id;

  RETURN NEW;
END;
$$;

CREATE TRIGGER send_push_on_notification
  AFTER INSERT ON public.notifications
  FOR EACH ROW
  EXECUTE FUNCTION trigger_send_push_notification();

-- ─── 4. Comment notification trigger ─────────────────────────────
-- Notifies post owner when someone comments.
-- Notifies parent comment author when someone replies.
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

  SELECT COALESCE(username, first_name, 'Someone')
  INTO commenter_name
  FROM profiles WHERE id = NEW.user_id;

  -- Notify post owner (skip if commenting on own post)
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

  -- Notify parent comment author (for replies)
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

DROP TRIGGER IF EXISTS trigger_notify_on_comment ON comments;
CREATE TRIGGER trigger_notify_on_comment
  AFTER INSERT ON comments
  FOR EACH ROW
  EXECUTE FUNCTION notify_on_new_comment();

-- ─── 5. Post notification trigger ────────────────────────────────
-- Notifies all other (non-banned) users when a new post is created.
CREATE OR REPLACE FUNCTION notify_on_new_post()
RETURNS TRIGGER AS $$
DECLARE
  author_name TEXT;
  other_user RECORD;
BEGIN
  SELECT COALESCE(username, first_name, 'Someone') INTO author_name
  FROM profiles WHERE id = NEW.user_id;

  FOR other_user IN
    SELECT id FROM profiles
    WHERE id != NEW.user_id AND is_banned = false
  LOOP
    INSERT INTO notifications (
      user_id, title, body, channel, post_id, sender_id, is_read
    ) VALUES (
      other_user.id,
      author_name || ' posted something new',
      COALESCE(LEFT(NEW.title, 100), 'Check it out!'),
      'post',
      NEW.id,
      NEW.user_id,
      false
    );
  END LOOP;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_notify_on_new_post ON posts;
DROP TRIGGER IF EXISTS trigger_notify_followers_on_post ON posts;
CREATE TRIGGER trigger_notify_on_new_post
  AFTER INSERT ON posts
  FOR EACH ROW
  EXECUTE FUNCTION notify_on_new_post();

-- ─── 6. Enable realtime for notifications ────────────────────────
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
EXCEPTION WHEN duplicate_object THEN
  RAISE NOTICE 'notifications already in supabase_realtime publication';
END $$;

ALTER TABLE notifications REPLICA IDENTITY FULL;
