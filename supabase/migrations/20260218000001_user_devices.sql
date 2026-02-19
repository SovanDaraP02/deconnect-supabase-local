-- ═══════════════════════════════════════════════════════════════════
-- Migration: Create user_devices table
-- ═══════════════════════════════════════════════════════════════════
-- Supports multiple devices per user (phone + tablet).
-- Each device has its own FCM token and tracks which room the user
-- is currently viewing (to suppress duplicate notifications).
-- ═══════════════════════════════════════════════════════════════════

-- 1. Create the table
CREATE TABLE IF NOT EXISTS public.user_devices (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  device_id text NOT NULL,                -- Unique per physical device (from Flutter)
  fcm_token text,                         -- Firebase Cloud Messaging token
  push_enabled boolean NOT NULL DEFAULT true,
  current_room_id uuid REFERENCES public.chat_rooms(id) ON DELETE SET NULL,
  platform text,                          -- 'android', 'ios'
  app_version text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),

  -- One row per user + device combination
  CONSTRAINT user_devices_user_device_unique UNIQUE (user_id, device_id)
);

-- 2. Enable RLS
ALTER TABLE public.user_devices ENABLE ROW LEVEL SECURITY;

-- 3. RLS Policies
CREATE POLICY "Users can view own devices"
  ON public.user_devices FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can register own devices"
  ON public.user_devices FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own devices"
  ON public.user_devices FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own devices"
  ON public.user_devices FOR DELETE
  USING (auth.uid() = user_id);

-- Service role needs full access (for edge functions)
CREATE POLICY "Service role full access on user_devices"
  ON public.user_devices FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- 4. Indexes
CREATE INDEX idx_user_devices_user_id ON public.user_devices(user_id);
CREATE INDEX idx_user_devices_fcm_token ON public.user_devices(fcm_token) WHERE fcm_token IS NOT NULL;
CREATE INDEX idx_user_devices_current_room ON public.user_devices(current_room_id) WHERE current_room_id IS NOT NULL;

-- 5. Auto-update updated_at
CREATE OR REPLACE FUNCTION update_user_devices_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER user_devices_updated_at
  BEFORE UPDATE ON public.user_devices
  FOR EACH ROW
  EXECUTE FUNCTION update_user_devices_updated_at();

-- 6. RPC: Register or update a device (upsert)
--    Call from Flutter: supabase.rpc('register_device', { ... })
CREATE OR REPLACE FUNCTION register_device(
  p_device_id text,
  p_fcm_token text DEFAULT NULL,
  p_platform text DEFAULT NULL,
  p_app_version text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_device_row_id uuid;
BEGIN
  INSERT INTO public.user_devices (user_id, device_id, fcm_token, platform, app_version)
  VALUES (auth.uid(), p_device_id, p_fcm_token, p_platform, p_app_version)
  ON CONFLICT (user_id, device_id) DO UPDATE SET
    fcm_token = COALESCE(EXCLUDED.fcm_token, user_devices.fcm_token),
    platform = COALESCE(EXCLUDED.platform, user_devices.platform),
    app_version = COALESCE(EXCLUDED.app_version, user_devices.app_version),
    updated_at = now()
  RETURNING id INTO v_device_row_id;

  RETURN v_device_row_id;
END;
$$;

-- 7. RPC: Set current room (call when user opens/closes a chat)
--    Call from Flutter: supabase.rpc('set_current_room', { p_device_id: '...', p_room_id: '...' })
--    Pass p_room_id = null when user leaves the chat screen
CREATE OR REPLACE FUNCTION set_current_room(
  p_device_id text,
  p_room_id uuid DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.user_devices
  SET current_room_id = p_room_id,
      updated_at = now()
  WHERE user_id = auth.uid()
    AND device_id = p_device_id;
END;
$$;

-- 8. Enable realtime (so Flutter can listen for device changes if needed)
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE user_devices;
EXCEPTION WHEN duplicate_object THEN
  RAISE NOTICE 'user_devices already in supabase_realtime publication';
END $$;

ALTER TABLE public.user_devices REPLICA IDENTITY FULL;


-- Run this in Supabase SQL Editor (http://127.0.0.1:54323)
ALTER TABLE public.comments ADD COLUMN IF NOT EXISTS mentions uuid[] DEFAULT '{}';
