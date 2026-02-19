# Changelog

All notable changes to the DeConnect Supabase backend.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## [0.7.0] -- 2026-02-19

### Added
- **`action_analytics` table** -- Tracks feature/action usage counters per user per day. Auto-populated from `log_detailed()` calls.
- `track_action()` RPC -- Increment action counter (called automatically from `log_detailed`)
- `get_feature_usage_stats(p_days)` RPC -- Admin dashboard: feature + action usage from analytics table
- **Invite code expiry** -- `chat_rooms.invite_expires_at` column. `regenerate_invite_code()` and `regenerate_invite_link()` now default to 48-hour expiry. `get_invite_info()` returns `is_expired` and `expires_at`.
- **`comments.mentions`** column -- `uuid[]` array for @-mentioning users in comments
- **`success` log level** -- Added to `system_logs` constraint (now 8 levels: error, warn, success, info, http, verbose, debug, trace)
- Migration 016: `20260218000002_fix_type_field_triggers.sql` -- Fixes NEW.type trigger errors
- Migration 017: `20260218100000_fixes.sql` -- chat-media bucket public + 50MB + MIME types, verbose log level, performance indexes
- Migration 018: `20260218200000_comprehensive_fixes.sql` -- Invite expiry, action_analytics, track_action, feature_usage_stats
- Performance indexes: `idx_messages_room_created`, `idx_notifications_user_unread`

### Changed
- **`chat-media` bucket** -- Now public, 50 MiB limit, supports 16 MIME types (images, video, audio, PDF, text)
- **`log_detailed()` RPC** -- Now auto-tracks action analytics for info+ log levels
- **Notification channels** -- Expanded to 9 types: direct_message, group_message, post, comment, like, follow, mention, feed, general
- Documentation fully updated (README, ARCHITECTURE, SETUP_GUIDE, CHANGELOG)

### Fixed
- **NEW.type trigger errors** -- Migration 016 auto-finds and drops trigger functions referencing NEW.type on messages/posts, then re-adds essential triggers

### Current Stats
- Tables: 16 (+1 action_analytics)
- Migrations: 19 (+4)
- Edge Functions: 8
- RPC Functions: 50+
- Trigger/Helper Functions: 85+
- RLS Policies: 60+
- Log Levels: 8

---

## [0.6.0] -- 2026-02-18

### Added
- **`user_devices` table** -- Multi-device push notification support. Each user can have multiple devices (phone + tablet), each with its own FCM token and `current_room_id` to suppress duplicate notifications when the user is already viewing a chat.
- `register_device()` RPC -- Upsert device on app startup (device_id, fcm_token, platform, app_version)
- `set_current_room()` RPC -- Set which room the user is viewing (pass null when leaving)
- Migration: `20260218000001_user_devices.sql`

### Changed
- **`send-push-notification` edge function** -- Now queries `user_devices` table instead of `profiles.fcm_token`. Sends to ALL eligible devices per user. Skips devices where `current_room_id` matches the notification's room. Clears stale tokens per-device.

### Current Stats
- Tables: 15 (+1 user_devices)
- Migrations: 15
- Edge Functions: 8

---

## [0.5.0] -- 2026-02-17

### Added
- **Push notification system** -- Migrations 010, 011 for `notifications` table, FCM token on profiles, message notification triggers
- **Enhanced logging system** -- Migration 013 with 42 log functions, 29 automatic triggers, analytics dashboard RPCs
- **Post/comment notification triggers** -- Comment replies and new post notifications
- **Consolidated notification fixes** -- Clean triggers for push via pg_net, comment notifications with reply support
- `post_likes` table for like tracking with logging
- `comments.parent_id` column for threaded comment replies

### Changed
- **Shared modules** (`_shared/`) -- Added `supabase.ts` and `helpers.ts` alongside `cors.ts`
- **Security hardened** -- Firebase credentials moved to env var, service role JWT to `current_setting()`

### Removed
- `add.sql` -- duplicated migration SQL
- `fix_notifications_and_logging.sql` -- overlapping fixes

### Current Stats
- Tables: 14
- RLS Policies: 56+
- Trigger/Helper Functions: 80+
- RPC Functions: 45+
- Edge Functions: 8
- Migrations: 14

---

## [0.4.0] -- 2026-02-11

### Changed
- Restructured documentation for production use
- Removed redundant documentation files (COMMANDS.md, 8 docs in docs/)

### Removed
- `COMMANDS.md`, `docs/DATABASE_SCHEMA.md`, `docs/RPC_FUNCTIONS.md`, `docs/RLS_POLICIES.md`, `docs/EDGE_FUNCTIONS.md`, `docs/MIGRATION_GUIDE.md`, `docs/RUNNING_LOCALLY_GUIDE.md`, `docs/QUICK_CHEAT_SHEET.md`, `docs/GITHUB_GUIDE.md`
- `fix_duplicates.sh`, `deduplicate_policies.py`, `reorganize_project.sh`

---

## [0.3.1] -- 2026-02-10

### Added
- Migration 008: `post_image_deletions` table and trigger
- Migration 009: `image_path` column on `posts`
- `create-post` edge function

---

## [0.3.0] -- 2026-02-10

### Fixed
- Added RLS + 4 policies for `call_participants`

### Added
- `supabase/config.toml` for local dev
- Seed data (`supabase/seed.sql`)

---

## [0.2.0] -- 2026-02-09

### Added
- Split monolithic migration into 7 files (001-007)
- 8 edge functions
- Shared CORS module
- RLS on all tables
- Documentation suite

---

## [0.1.0] -- 2026-02-08

### Added
- Initial schema export from remote Supabase project
