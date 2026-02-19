-- ═══════════════════════════════════════════════════════════════════
-- Migration: Fix "record 'new' has no field 'type'" error
-- 
-- Problem: A trigger on messages and/or posts tables references
--          NEW.type, but neither table has a "type" column.
--          This blocks ALL inserts (messages, voice, files, posts).
--
-- Solution: Find and drop all trigger functions that reference
--           NEW.type, then recreate clean notification triggers.
-- ═══════════════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════════════
-- STEP 1: Diagnostic — Find ALL triggers on messages and posts
-- (This SELECT won't break anything, just helps debug)
-- ═══════════════════════════════════════════════════════════════════
DO $$
DECLARE
    trigger_record RECORD;
    func_source TEXT;
BEGIN
    RAISE NOTICE '=== Triggers on public.messages ===';
    FOR trigger_record IN
        SELECT t.tgname, p.proname, pg_get_functiondef(p.oid) AS func_def
        FROM pg_trigger t
        JOIN pg_proc p ON t.tgfoid = p.oid
        WHERE t.tgrelid = 'public.messages'::regclass
        AND NOT t.tgisinternal
    LOOP
        RAISE NOTICE 'Trigger: %, Function: %', trigger_record.tgname, trigger_record.proname;
        IF trigger_record.func_def ILIKE '%NEW.type%' THEN
            RAISE NOTICE '  >>> FOUND NEW.type in function: %', trigger_record.proname;
        END IF;
    END LOOP;

    RAISE NOTICE '=== Triggers on public.posts ===';
    FOR trigger_record IN
        SELECT t.tgname, p.proname, pg_get_functiondef(p.oid) AS func_def
        FROM pg_trigger t
        JOIN pg_proc p ON t.tgfoid = p.oid
        WHERE t.tgrelid = 'public.posts'::regclass
        AND NOT t.tgisinternal
    LOOP
        RAISE NOTICE 'Trigger: %, Function: %', trigger_record.tgname, trigger_record.proname;
        IF trigger_record.func_def ILIKE '%NEW.type%' THEN
            RAISE NOTICE '  >>> FOUND NEW.type in function: %', trigger_record.proname;
        END IF;
    END LOOP;
END $$;

-- ═══════════════════════════════════════════════════════════════════
-- STEP 2: Drop ANY trigger function that references NEW.type
--         on the messages or posts tables
-- ═══════════════════════════════════════════════════════════════════
DO $$
DECLARE
    trigger_record RECORD;
    func_source TEXT;
BEGIN
    -- Fix triggers on messages table
    FOR trigger_record IN
        SELECT t.tgname, p.proname, p.oid AS func_oid
        FROM pg_trigger t
        JOIN pg_proc p ON t.tgfoid = p.oid
        WHERE t.tgrelid = 'public.messages'::regclass
        AND NOT t.tgisinternal
    LOOP
        func_source := pg_get_functiondef(trigger_record.func_oid);
        IF func_source ILIKE '%NEW.type%' THEN
            RAISE NOTICE 'Dropping trigger % on messages (function % has NEW.type)', 
                trigger_record.tgname, trigger_record.proname;
            EXECUTE format('DROP TRIGGER IF EXISTS %I ON public.messages', trigger_record.tgname);
            EXECUTE format('DROP FUNCTION IF EXISTS %I() CASCADE', trigger_record.proname);
        END IF;
    END LOOP;

    -- Fix triggers on posts table
    FOR trigger_record IN
        SELECT t.tgname, p.proname, p.oid AS func_oid
        FROM pg_trigger t
        JOIN pg_proc p ON t.tgfoid = p.oid
        WHERE t.tgrelid = 'public.posts'::regclass
        AND NOT t.tgisinternal
    LOOP
        func_source := pg_get_functiondef(trigger_record.func_oid);
        IF func_source ILIKE '%NEW.type%' THEN
            RAISE NOTICE 'Dropping trigger % on posts (function % has NEW.type)', 
                trigger_record.tgname, trigger_record.proname;
            EXECUTE format('DROP TRIGGER IF EXISTS %I ON public.posts', trigger_record.tgname);
            EXECUTE format('DROP FUNCTION IF EXISTS %I() CASCADE', trigger_record.proname);
        END IF;
    END LOOP;
END $$;

-- ═══════════════════════════════════════════════════════════════════
-- STEP 3: Also check for any trigger functions on comments, 
--         notifications, or other tables that might reference NEW.type
-- ═══════════════════════════════════════════════════════════════════
DO $$
DECLARE
    trigger_record RECORD;
    func_source TEXT;
BEGIN
    FOR trigger_record IN
        SELECT DISTINCT t.tgname, p.proname, p.oid AS func_oid, c.relname AS table_name
        FROM pg_trigger t
        JOIN pg_proc p ON t.tgfoid = p.oid
        JOIN pg_class c ON t.tgrelid = c.oid
        JOIN pg_namespace n ON c.relnamespace = n.oid
        WHERE n.nspname = 'public'
        AND NOT t.tgisinternal
    LOOP
        func_source := pg_get_functiondef(trigger_record.func_oid);
        IF func_source ILIKE '%NEW.type%' THEN
            RAISE NOTICE 'ALSO FOUND NEW.type in trigger % on table % (function %)', 
                trigger_record.tgname, trigger_record.table_name, trigger_record.proname;
            -- Drop it
            EXECUTE format('DROP TRIGGER IF EXISTS %I ON public.%I', 
                trigger_record.tgname, trigger_record.table_name);
        END IF;
    END LOOP;
END $$;

-- ═══════════════════════════════════════════════════════════════════
-- STEP 4: Recreate clean notification triggers for messages
-- ═══════════════════════════════════════════════════════════════════

-- Drop and recreate cleanly
DROP TRIGGER IF EXISTS on_new_message_notify ON public.messages;
DROP TRIGGER IF EXISTS on_message_notify ON public.messages;
DROP FUNCTION IF EXISTS notify_on_new_message() CASCADE;
DROP FUNCTION IF EXISTS trigger_notify_on_message() CASCADE;

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
  SELECT COALESCE(username, first_name, 'Someone') INTO sender_name
  FROM public.profiles 
  WHERE id = NEW.sender_id;

  -- Set channel and title based on room type (NOT message type)
  IF room_rec.is_group THEN
    notif_channel := 'group_message';
    notif_title := COALESCE(room_rec.name, 'Group Chat');
  ELSE
    notif_channel := 'direct_message';
    notif_title := sender_name;
  END IF;

  -- Build notification body based on media_type (column that EXISTS)
  -- Note: messages table has media_type, NOT type
  INSERT INTO public.notifications (user_id, title, body, channel, room_id, sender_id)
  SELECT 
    rm.user_id,
    notif_title,
    CASE 
      WHEN NEW.media_type = 'voice' THEN '🎤 Voice message'
      WHEN NEW.media_type = 'image' THEN '📷 Image'
      WHEN NEW.media_type = 'file' THEN '📎 File'
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

CREATE TRIGGER on_new_message_notify
  AFTER INSERT ON public.messages
  FOR EACH ROW
  EXECUTE FUNCTION notify_on_new_message();

-- ═══════════════════════════════════════════════════════════════════
-- STEP 5: Recreate clean notification triggers for posts
-- ═══════════════════════════════════════════════════════════════════

DROP TRIGGER IF EXISTS on_post_notify ON public.posts;
DROP TRIGGER IF EXISTS trigger_notify_on_new_post ON public.posts;
DROP FUNCTION IF EXISTS trigger_notify_on_post() CASCADE;

CREATE OR REPLACE FUNCTION trigger_notify_on_post()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  author_name TEXT;
BEGIN
  -- Get author info
  SELECT COALESCE(username, first_name, 'Someone') INTO author_name
  FROM public.profiles
  WHERE id = NEW.user_id;

  -- Notify all other non-banned users about the new post
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

CREATE TRIGGER on_post_notify
  AFTER INSERT ON public.posts
  FOR EACH ROW
  EXECUTE FUNCTION trigger_notify_on_post();

-- Also keep the feed notification trigger  
DROP TRIGGER IF EXISTS trigger_notify_on_new_post ON public.posts;

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
      COALESCE(NEW.title, 'Check it out!'),
      'feed',
      NEW.id,
      NEW.user_id,
      false
    );
  END LOOP;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- NOTE: We only create ONE post notification trigger to avoid duplicates
-- on_post_notify already handles this, so we don't re-add trigger_notify_on_new_post

-- ═══════════════════════════════════════════════════════════════════
-- STEP 6: Ensure essential message triggers still exist
-- ═══════════════════════════════════════════════════════════════════

-- Re-add core triggers if they were accidentally dropped
DO $$
BEGIN
  -- update_last_seen
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

  -- update_room_on_message
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

  -- broadcast_message_insert
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

  -- broadcast_message_update
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

-- ═══════════════════════════════════════════════════════════════════
-- STEP 7: Final verification
-- ═══════════════════════════════════════════════════════════════════
DO $$
DECLARE
    trigger_record RECORD;
    func_source TEXT;
    found_bad BOOLEAN := false;
BEGIN
    RAISE NOTICE '=== FINAL VERIFICATION ===';
    
    FOR trigger_record IN
        SELECT t.tgname, p.proname, p.oid AS func_oid, c.relname AS table_name
        FROM pg_trigger t
        JOIN pg_proc p ON t.tgfoid = p.oid
        JOIN pg_class c ON t.tgrelid = c.oid
        JOIN pg_namespace n ON c.relnamespace = n.oid
        WHERE n.nspname = 'public'
        AND c.relname IN ('messages', 'posts')
        AND NOT t.tgisinternal
    LOOP
        func_source := pg_get_functiondef(trigger_record.func_oid);
        IF func_source ILIKE '%NEW.type%' THEN
            RAISE WARNING 'STILL FOUND NEW.type in trigger % on % (function %)', 
                trigger_record.tgname, trigger_record.table_name, trigger_record.proname;
            found_bad := true;
        ELSE
            RAISE NOTICE 'OK: % on % (function %)', 
                trigger_record.tgname, trigger_record.table_name, trigger_record.proname;
        END IF;
    END LOOP;

    IF NOT found_bad THEN
        RAISE NOTICE '✅ All triggers clean — no NEW.type references found!';
    END IF;
END $$;
