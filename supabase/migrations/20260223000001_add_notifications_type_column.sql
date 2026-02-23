-- Migration: Add missing 'type' column to notifications table
-- This fixes the "record 'old' has no field 'type'" error when deleting posts
-- The log_notification_deleted trigger references OLD.type but the column was missing

ALTER TABLE notifications ADD COLUMN IF NOT EXISTS type TEXT;

-- Add comment for documentation
COMMENT ON COLUMN notifications.type IS 'Notification type (e.g., post, comment, like, follow, mention, etc.)';
