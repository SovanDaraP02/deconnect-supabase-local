-- ============================================================
-- Migration 010: Push Notification Support
-- ============================================================

-- 1. Add fcm_token column to profiles
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS fcm_token text;

-- 2. Create notifications table (no FK to chatrooms - use app-level validation)
CREATE TABLE IF NOT EXISTS public.notifications (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  title text,
  body text NOT NULL,
  channel text NOT NULL DEFAULT 'general'
    CHECK (channel IN ('direct_message', 'group_message', 'buy_channel', 'general')),
  room_id uuid,
  sender_id uuid,
  data jsonb DEFAULT '{}'::jsonb,
  is_read boolean NOT NULL DEFAULT false
);

-- 3. Add foreign keys only if tables exist
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'chatrooms') THEN
    ALTER TABLE public.notifications
      ADD CONSTRAINT notifications_room_id_fkey
      FOREIGN KEY (room_id) REFERENCES public.chatrooms(id) ON DELETE SET NULL;
  END IF;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Could not add chatrooms FK: %', SQLERRM;
END $$;

DO $$
BEGIN
  ALTER TABLE public.notifications
    ADD CONSTRAINT notifications_sender_id_fkey
    FOREIGN KEY (sender_id) REFERENCES auth.users(id) ON DELETE SET NULL;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Could not add sender FK: %', SQLERRM;
END $$;

-- 4. Indexes
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON public.notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_channel ON public.notifications(channel);
CREATE INDEX IF NOT EXISTS idx_profiles_fcm_token ON public.profiles(fcm_token) WHERE fcm_token IS NOT NULL;

-- 5. Enable RLS
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- 6. RLS Policies
CREATE POLICY "Users can view own notifications"
  ON public.notifications FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Authenticated users can insert notifications"
  ON public.notifications FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Users can update own notifications"
  ON public.notifications FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own notifications"
  ON public.notifications FOR DELETE
  USING (auth.uid() = user_id);
