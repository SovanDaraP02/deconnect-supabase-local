-- Migration: Add post and comment notification triggers
-- Run this in Supabase SQL Editor

-- ═══════════════════════════════════════════════════════════════════
-- 1. Create notification for new posts (notify followers)
-- ═══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION notify_followers_on_new_post()
RETURNS TRIGGER AS $$
DECLARE
    author_name TEXT;
    follower_record RECORD;
BEGIN
    -- Get author's name
    SELECT COALESCE(username, first_name, 'Someone') INTO author_name
    FROM profiles
    WHERE id = NEW.user_id;

    -- If you have a followers table, notify all followers
    -- For now, we'll skip this since followers table may not exist
    -- You can uncomment this if you have a followers table:
    
    /*
    FOR follower_record IN 
        SELECT follower_id FROM followers WHERE following_id = NEW.user_id
    LOOP
        INSERT INTO notifications (
            user_id,
            title,
            body,
            channel,
            post_id,
            sender_id,
            is_read
        ) VALUES (
            follower_record.follower_id,
            author_name || ' posted something new',
            COALESCE(NEW.title, 'Check it out!'),
            'post',
            NEW.id,
            NEW.user_id,
            false
        );
    END LOOP;
    */

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger (disabled by default - enable if you have followers table)
-- DROP TRIGGER IF EXISTS trigger_notify_followers_on_post ON posts;
-- CREATE TRIGGER trigger_notify_followers_on_post
--     AFTER INSERT ON posts
--     FOR EACH ROW
--     EXECUTE FUNCTION notify_followers_on_new_post();


-- ═══════════════════════════════════════════════════════════════════
-- 2. Create notification for new comments
-- ═══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION notify_on_new_comment()
RETURNS TRIGGER AS $$
DECLARE
    post_owner_id UUID;
    post_title TEXT;
    commenter_name TEXT;
    parent_comment_author_id UUID;
BEGIN
    -- Get the post owner and title
    SELECT user_id, COALESCE(title, 'your post') INTO post_owner_id, post_title
    FROM posts
    WHERE id = NEW.post_id;

    -- Get commenter's name
    SELECT COALESCE(username, first_name, 'Someone') INTO commenter_name
    FROM profiles
    WHERE id = NEW.user_id;

    -- Don't notify if commenting on own post
    IF post_owner_id IS NOT NULL AND post_owner_id != NEW.user_id THEN
        INSERT INTO notifications (
            user_id,
            title,
            body,
            channel,
            post_id,
            sender_id,
            is_read
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

    -- If this is a reply to another comment, notify that comment's author
    IF NEW.parent_id IS NOT NULL THEN
        SELECT user_id INTO parent_comment_author_id
        FROM comments
        WHERE id = NEW.parent_id;

        -- Don't notify if replying to own comment or if same as post owner (already notified)
        IF parent_comment_author_id IS NOT NULL 
           AND parent_comment_author_id != NEW.user_id 
           AND parent_comment_author_id != post_owner_id THEN
            INSERT INTO notifications (
                user_id,
                title,
                body,
                channel,
                post_id,
                sender_id,
                is_read
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

-- Create trigger for comments
DROP TRIGGER IF EXISTS trigger_notify_on_comment ON comments;
CREATE TRIGGER trigger_notify_on_comment
    AFTER INSERT ON comments
    FOR EACH ROW
    EXECUTE FUNCTION notify_on_new_comment();


-- ═══════════════════════════════════════════════════════════════════
-- 3. Create notification for likes (optional)
-- ═══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION notify_on_post_like()
RETURNS TRIGGER AS $$
DECLARE
    post_owner_id UUID;
    post_title TEXT;
    liker_name TEXT;
BEGIN
    -- Get the post owner
    SELECT user_id, COALESCE(title, 'your post') INTO post_owner_id, post_title
    FROM posts
    WHERE id = NEW.post_id;

    -- Get liker's name
    SELECT COALESCE(username, first_name, 'Someone') INTO liker_name
    FROM profiles
    WHERE id = NEW.user_id;

    -- Don't notify if liking own post
    IF post_owner_id IS NOT NULL AND post_owner_id != NEW.user_id THEN
        -- Check if we recently sent a like notification to avoid spam
        -- Only notify once per user per post per hour
        IF NOT EXISTS (
            SELECT 1 FROM notifications
            WHERE user_id = post_owner_id
              AND post_id = NEW.post_id
              AND sender_id = NEW.user_id
              AND channel = 'like'
              AND created_at > NOW() - INTERVAL '1 hour'
        ) THEN
            INSERT INTO notifications (
                user_id,
                title,
                body,
                channel,
                post_id,
                sender_id,
                is_read
            ) VALUES (
                post_owner_id,
                liker_name || ' liked your post',
                LEFT(post_title, 50),
                'like',
                NEW.post_id,
                NEW.user_id,
                false
            );
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for likes (if you have a likes/post_likes table)
-- Uncomment if you have a likes table:
/*
DROP TRIGGER IF EXISTS trigger_notify_on_like ON post_likes;
CREATE TRIGGER trigger_notify_on_like
    AFTER INSERT ON post_likes
    FOR EACH ROW
    EXECUTE FUNCTION notify_on_post_like();
*/


-- ═══════════════════════════════════════════════════════════════════
-- 4. Add post_id column to notifications if not exists
-- ═══════════════════════════════════════════════════════════════════

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'notifications' AND column_name = 'post_id'
    ) THEN
        ALTER TABLE notifications ADD COLUMN post_id UUID REFERENCES posts(id) ON DELETE CASCADE;
        CREATE INDEX idx_notifications_post_id ON notifications(post_id) WHERE post_id IS NOT NULL;
    END IF;
END $$;


-- ═══════════════════════════════════════════════════════════════════
-- 5. Verify triggers are working
-- ═══════════════════════════════════════════════════════════════════

-- Check existing triggers
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement
FROM information_schema.triggers
WHERE trigger_schema = 'public'
ORDER BY event_object_table, trigger_name;