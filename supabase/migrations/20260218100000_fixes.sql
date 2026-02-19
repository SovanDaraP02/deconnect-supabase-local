-- ========================================================
-- DeConnect Fixes Migration
-- Date: 2026-02-18
-- ========================================================

-- 1. Fix chat-media bucket: make public + increase size
UPDATE storage.buckets
SET public = true,
    file_size_limit = 52428800,
    allowed_mime_types = ARRAY[
      'image/jpeg','image/png','image/gif','image/webp','image/bmp',
      'video/mp4','video/quicktime','video/webm',
      'audio/mp4','audio/mpeg','audio/wav','audio/ogg','audio/aac',
      'application/pdf','application/octet-stream',
      'text/plain','text/csv'
    ]
WHERE id = 'chat-media';

-- 2. Add 'verbose' to system_logs level constraint
ALTER TABLE public.system_logs DROP CONSTRAINT IF EXISTS system_logs_level_check;
ALTER TABLE public.system_logs ADD CONSTRAINT system_logs_level_check
  CHECK (level = ANY (ARRAY['error','warn','info','http','verbose','debug','trace']));

-- 3. Add performance indexes
CREATE INDEX IF NOT EXISTS idx_messages_room_created
  ON public.messages(room_id, created_at DESC)
  WHERE is_deleted = false;

CREATE INDEX IF NOT EXISTS idx_notifications_user_unread
  ON public.notifications(user_id, is_read)
  WHERE is_read = false;
