-- ========================
-- STORAGE BUCKETS
-- ========================
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types) VALUES
(
  'chat-files',
  'chat-files',
  true,
  157286400,
  ARRAY['image/jpeg','image/png','image/gif','image/webp','image/svg+xml','image/bmp','application/pdf','application/msword','application/vnd.openxmlformats-officedocument.wordprocessingml.document','application/vnd.ms-excel','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet','application/vnd.ms-powerpoint','application/vnd.openxmlformats-officedocument.presentationml.presentation','text/plain','text/csv','text/html','application/zip','application/x-rar-compressed','application/x-7z-compressed','audio/mpeg','audio/wav','audio/ogg','video/mp4','video/webm','video/quicktime']
),
(
  'chat-images',
  'chat-images',
  true,
  157286400,
  ARRAY['image/jpeg','image/png','image/gif','image/webp','image/svg+xml','image/bmp','application/pdf','application/msword','application/vnd.openxmlformats-officedocument.wordprocessingml.document','application/vnd.ms-excel','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet','application/vnd.ms-powerpoint','application/vnd.openxmlformats-officedocument.presentationml.presentation','text/plain','text/csv','text/html','application/zip','application/x-rar-compressed','application/x-7z-compressed','application/octet-stream','audio/mpeg','audio/wav','audio/ogg','audio/mp4','video/mp4','video/webm','video/quicktime']
),
(
  'chat-media',
  'chat-media',
  false,
  12582912,
  NULL
),
(
  'post-images',
  'post-images',
  true,
  8388608,
  NULL
),
(
  'avatars',
  'avatars',
  true,
  5242880,
  NULL
)
ON CONFLICT (id) DO NOTHING;

--- ========================
-- STORAGE BUCKETS
-- ========================
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types) VALUES
(
  'chat-files', 'chat-files', true, 157286400,
  ARRAY['image/jpeg','image/png','image/gif','image/webp','image/svg+xml','image/bmp','application/pdf','application/msword','application/vnd.openxmlformats-officedocument.wordprocessingml.document','application/vnd.ms-excel','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet','application/vnd.ms-powerpoint','application/vnd.openxmlformats-officedocument.presentationml.presentation','text/plain','text/csv','text/html','application/zip','application/x-rar-compressed','application/x-7z-compressed','audio/mpeg','audio/wav','audio/ogg','video/mp4','video/webm','video/quicktime']
),
(
  'chat-images', 'chat-images', true, 157286400,
  ARRAY['image/jpeg','image/png','image/gif','image/webp','image/svg+xml','image/bmp','application/pdf','application/msword','application/vnd.openxmlformats-officedocument.wordprocessingml.document','application/vnd.ms-excel','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet','application/vnd.ms-powerpoint','application/vnd.openxmlformats-officedocument.presentationml.presentation','text/plain','text/csv','text/html','application/zip','application/x-rar-compressed','application/x-7z-compressed','application/octet-stream','audio/mpeg','audio/wav','audio/ogg','audio/mp4','video/mp4','video/webm','video/quicktime']
),
( 'chat-media', 'chat-media', false, 12582912, NULL ),
( 'post-images', 'post-images', true, 8388608, NULL ),
( 'avatars', 'avatars', true, 5242880, NULL )
ON CONFLICT (id) DO NOTHING;

-- ========================
-- AUTH USERS
-- ========================
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change, email_change_token_new, email_change_token_current
) VALUES
(
  '00000000-0000-0000-0000-000000000000',
  'a1111111-1111-1111-1111-111111111111'::uuid,
  'authenticated', 'authenticated', 'vathanak@test.com',
  crypt('password123', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  '{"username":"vathanak"}', now(), now(), '', '', '', '', ''
),
(
  '00000000-0000-0000-0000-000000000000',
  'b2222222-2222-2222-2222-222222222222'::uuid,
  'authenticated', 'authenticated', 'Sak@test.com',
  crypt('password123', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  '{"username":"Sak"}', now(), now(), '', '', '', '', ''
),
(
  '00000000-0000-0000-0000-000000000000',
  'c3333333-3333-3333-3333-333333333333'::uuid,
  'authenticated', 'authenticated', 'dara@test.com',
  crypt('password123', gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}',
  '{"username":"sovandara"}', now(), now(), '', '', '', '', ''
);

-- ========================
-- PROFILES (insert directly, works whether trigger fires or not)
-- ========================
INSERT INTO public.profiles (id, username, email, role) VALUES
  ('a1111111-1111-1111-1111-111111111111', 'vathanak', 'vathanak@test.com', 'user'),
  ('b2222222-2222-2222-2222-222222222222', 'Sak', 'Sak@test.com', 'user'),
  ('c3333333-3333-3333-3333-333333333333', 'sovandara', 'dara@test.com', 'admin')
ON CONFLICT (id) DO UPDATE SET
  username = EXCLUDED.username,
  email = EXCLUDED.email,
  role = EXCLUDED.role;

-- ========================
-- TEST GROUP CHAT
-- ========================
INSERT INTO public.chat_rooms (id, name, is_group, created_by) VALUES
  ('d4444444-4444-4444-4444-444444444444', 'Team Chat', true, 'a1111111-1111-1111-1111-111111111111');

INSERT INTO public.room_members (room_id, user_id, is_admin) VALUES
  ('d4444444-4444-4444-4444-444444444444', 'a1111111-1111-1111-1111-111111111111', true),
  ('d4444444-4444-4444-4444-444444444444', 'b2222222-2222-2222-2222-222222222222', false),
  ('d4444444-4444-4444-4444-444444444444', 'c3333333-3333-3333-3333-333333333333', false);

INSERT INTO public.messages (room_id, sender_id, content) VALUES
  ('d4444444-4444-4444-4444-444444444444', 'a1111111-1111-1111-1111-111111111111', 'Hello team!'),
  ('d4444444-4444-4444-4444-444444444444', 'b2222222-2222-2222-2222-222222222222', 'Hi vathanak!'),
  ('d4444444-4444-4444-4444-444444444444', 'c3333333-3333-3333-3333-333333333333', 'Good morning everyone!');

INSERT INTO public.posts (user_id, title, content) VALUES
  ('a1111111-1111-1111-1111-111111111111', 'Welcome Post', 'This is a test post for local development'),
  ('b2222222-2222-2222-2222-222222222222', 'Another Post', 'Testing the feed feature');

-- ========================
-- ADDITIONAL STORAGE BUCKETS
-- ========================
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types) VALUES
  ('post-media', 'post-media', true, 10485760, ARRAY['image/jpeg','image/png','image/gif','image/webp','video/mp4','video/quicktime']),
  ('group-avatars', 'group-avatars', true, 5242880, ARRAY['image/jpeg','image/png','image/gif','image/webp'])
ON CONFLICT (id) DO NOTHING;
